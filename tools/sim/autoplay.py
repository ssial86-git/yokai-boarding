#!/usr/bin/env python3
"""14일 자동 플레이 시뮬레이터 (docs/01 v3 6절, docs/08 재미 원칙 6).

data/csv 만 읽어 세 가지를 낸다:
  1. 케이던스 검사 — unlocks.csv 의 expected_day 를 실시간 분으로 펴서 "처음 보는 것 없는 30분" 이 없는지 (원칙 6).
  2. 위임 손익 교차점 — 텃밭 물주기를 요괴(효율 automation_efficiency)에게 넘겼을 때
     플레이어가 되찾는 스태미너로 채집해 얻는 가치 vs 잃는 수확·주방 산출. 목표: 6~8일차 (docs/01 v3 7절).
  3. 경제 곡선 — 하루 기대 수입 초안 (숙박비·손님·수확·채집 판매). 사람이 확정한다 (docs/08 9절).

모델 상수는 전부 tuning/crops/materials/rooms/items 에서 읽고, 여기 하드코딩된 것은 '가정' 으로 표에 적는다.
사용: python tools/sim/autoplay.py [--check] [--days 14]   (--check: 1·2 가 목표 밖이면 종료 코드 1 — CI 게이트)
"""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
CSV_DIR = ROOT / "data" / "csv"

CADENCE_WINDOW_MINUTES = 30.0
DELEGATION_TARGET_DAYS = (6, 8)
# 가정: 하루 중 시간대 시작 시각을 분으로 바꿀 때 쓰는 비율 (unlocks.timeband). any 는 하루 시작.
TIMEBAND_RATIO = {"any": 0.0, "morning": 0.0, "day": 0.2, "evening": 0.6, "night": 0.78}


def read_rows(name: str) -> list[dict[str, str]]:
    with (CSV_DIR / name).open(encoding="utf-8-sig", newline="") as fh:
        return [r for r in csv.DictReader(fh) if any((v or "").strip() for v in r.values())]


def tuning() -> dict[str, float | str]:
    result: dict[str, float | str] = {}
    for row in read_rows("tuning.csv"):
        kind = row["type"]
        raw = row["value"]
        result[row["key"]] = raw if kind in ("string", "bool") else float(raw)
    return result


def unlock_day(unlocks: list[dict[str, str]], unlock_id: str, default: int) -> int:
    for row in unlocks:
        if row["id"] == unlock_id:
            return int(row["expected_day"])
    return default


# ---------------------------------------------------------------- 1. 케이던스


def cadence_gaps(unlocks: list[dict[str, str]], day_minutes: float, days: int) -> tuple[list[tuple[float, str]], float, str]:
    """(시각(분), id) 목록과 최대 공백(분), 공백 설명."""
    moments: list[tuple[float, str]] = []
    for row in unlocks:
        day = int(row["expected_day"])
        if day > days:
            continue  # 검사 기간 밖의 뼈대 행(가을·겨울)은 다음 세션이 조밀하게 채운다
        minutes = (day - 1) * day_minutes + TIMEBAND_RATIO.get(row["timeband"], 0.0) * day_minutes
        moments.append((minutes, row["id"]))
    moments.sort()
    end = days * day_minutes
    worst = 0.0
    worst_text = ""
    previous = 0.0
    previous_id = "시작"
    for minutes, unlock_id in moments + [(end, f"{days}일차 끝")]:
        gap = minutes - previous
        if gap > worst:
            worst = gap
            worst_text = f"{previous_id} → {unlock_id} ({previous:.0f}분 → {minutes:.0f}분)"
        previous, previous_id = minutes, unlock_id
    return moments, worst, worst_text


# ---------------------------------------------------------------- 2. 위임 손익


def average_crop_value_per_day(crops: list[dict[str, str]], items: dict[str, dict[str, str]]) -> float:
    """이승 작물 한 칸이 하루에 만드는 기대 가치 (수확물 값 × 평균 수확량 / 성장일)."""
    values = []
    for crop in crops:
        if crop["realm"] != "mortal":
            continue
        harvest = items[crop["harvest_item"]]
        avg_yield = (int(crop["yield_min"]) + int(crop["yield_max"])) / 2.0
        values.append(int(harvest["base_value"]) * avg_yield / max(int(crop["grow_days"]), 1))
    return sum(values) / len(values) if values else 0.0


def average_gather_value(regions: list[dict[str, str]], materials: dict[str, dict[str, str]], items: dict[str, dict[str, str]]) -> float:
    """뒷산 채집 풀의 도구 없이 캘 수 있는 재료 평균 값."""
    pool = next((r["gather_pool"] for r in regions if r["id"] == "r_back_hill"), "")
    values = []
    for material_id in filter(None, pool.split(";")):
        material = materials.get(material_id)
        if material is None or material["tool_kind"] != "none":
            continue
        values.append(int(items[material_id]["base_value"]))
    return sum(values) / len(values) if values else 0.0


def delegation_table(tune: dict, unlocks, crops, materials, items, regions, rooms, days: int) -> tuple[list[dict], int | None]:
    efficiency = float(tune["automation_efficiency"])
    farm_cost = float(tune["stamina_farm_cost"])
    gather_cost = float(tune["stamina_gather_cost"])
    plots_initial = int(tune["farm_plots_initial"])
    plots_max = int(tune["farm_plots_max"])
    expand_day = unlock_day(unlocks, "u_farm_plots_12", 8)
    automation_day = unlock_day(unlocks, "u_automation", 7)
    crop_value = average_crop_value_per_day(crops, items)
    gather_value = average_gather_value(regions, materials, items)
    kitchen = next((r for r in rooms if r["id"] == "kitchen"), None)
    kitchen_value = int(kitchen["output_amount"]) * int(items[kitchen["output_item"]]["base_value"]) if kitchen else 0.0

    table: list[dict] = []
    crossover: int | None = None
    for day in range(1, days + 1):
        plots = plots_max if day >= expand_day else plots_initial
        freed_stamina = plots * farm_cost
        freed_value = freed_stamina / gather_cost * gather_value if gather_cost > 0 else 0.0
        lost_harvest = plots * crop_value * (1.0 - efficiency)
        net = freed_value - lost_harvest - kitchen_value
        available = day >= automation_day
        if crossover is None and available and net > 0:
            crossover = day
        table.append({"day": day, "plots": plots, "freed": freed_value, "lost_harvest": lost_harvest,
                      "kitchen": kitchen_value, "net": net, "available": available})
    return table, crossover


# ---------------------------------------------------------------- 3. 경제 곡선


def economy_curve(tune: dict, unlocks, crops, items, materials, regions, species, days: int) -> list[dict]:
    money = float(tune["start_money"])
    visitor_chance = float(tune["visitor_chance"])
    guest_rent = sum(int(s["rent_money"]) for s in species) / max(len(species), 1)
    crop_value = average_crop_value_per_day(crops, items)
    gather_value = average_gather_value(regions, materials, items)
    hill = next((r for r in regions if r["id"] == "r_back_hill"), None)
    gather_points = int(hill["gather_point_count"]) if hill else 0
    hill_day = unlock_day(unlocks, "u_back_hill", 2)
    plots_initial = int(tune["farm_plots_initial"])
    plots_max = int(tune["farm_plots_max"])
    expand_day = unlock_day(unlocks, "u_farm_plots_12", 8)
    # 회색 시장 (P2-S3): 열린 뒤로는 채집물을 시세 배율(market_prices.csv 재료 행 평균)로 판다고 가정
    market_day = unlock_day(unlocks, "u_gray_market", 13)
    market_rows = [r for r in read_rows("market_prices.csv") if r["item_id"].startswith("m_") and r["shop"] == "gray"]
    market_mult = (sum(float(r["sell_mult"]) for r in market_rows) / len(market_rows)) if market_rows else 1.0
    curve: list[dict] = []
    for day in range(1, days + 1):
        plots = plots_max if day >= expand_day else plots_initial
        income_guest = visitor_chance * guest_rent
        income_farm = plots * crop_value
        income_gather = gather_points * gather_value if day >= hill_day else 0.0
        if day >= market_day:
            income_gather *= market_mult
        money += income_guest + income_farm + income_gather
        curve.append({"day": day, "guest": income_guest, "farm": income_farm, "gather": income_gather, "money": money})
    return curve


# ---------------------------------------------------------------- main


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="자동 플레이 시뮬레이터 (기본 112일 = 4절기 한 해, P3-S3)")
    parser.add_argument("--check", action="store_true", help="케이던스·위임 교차점이 목표 밖이면 종료 코드 1")
    parser.add_argument("--days", type=int, default=112)
    args = parser.parse_args(argv)

    tune = tuning()
    unlocks = read_rows("unlocks.csv")
    crops = read_rows("crops.csv")
    items = {r["id"]: r for r in read_rows("items.csv")}
    materials = {r["id"]: r for r in read_rows("materials.csv")}
    regions = read_rows("regions.csv")
    rooms = read_rows("rooms.csv")
    species = read_rows("guest_species.csv")
    day_minutes = float(tune["day_length_seconds"]) / 60.0
    failures: list[str] = []

    print(f"[sim] 하루 = {day_minutes:.0f}분 × {args.days}일 = {day_minutes * args.days:.0f}분")
    print()
    print("== 1. 케이던스 (unlocks.csv, 원칙 6: 어느 30분에도 처음 보는 것 1개) ==")
    moments, worst, worst_text = cadence_gaps(unlocks, day_minutes, args.days)
    per_day: dict[int, int] = {}
    for minutes, _ in moments:
        per_day[int(minutes // day_minutes) + 1] = per_day.get(int(minutes // day_minutes) + 1, 0) + 1
    print("  일차별 해금 수: " + ", ".join(f"{d}일 {per_day.get(d, 0)}" for d in range(1, args.days + 1)))
    print(f"  최대 공백: {worst:.0f}분 — {worst_text}")
    if worst > CADENCE_WINDOW_MINUTES:
        failures.append(f"케이던스: 해금 없는 구간 {worst:.0f}분 > {CADENCE_WINDOW_MINUTES:.0f}분 ({worst_text})")
        print("  판정: FAIL")
    else:
        print("  판정: PASS")

    print()
    print("== 2. 위임 손익 교차점 (텃밭 물주기를 요괴에게 넘길 때, 목표 6~8일차) ==")
    table, crossover = delegation_table(tune, unlocks, crops, materials, items, regions, rooms, args.days)
    print("  가정: 되찾은 스태미너는 전부 뒷산 채집(도구 불필요 재료 평균값)에 쓰고, 위임한 요괴는 주방에서 빠진다")
    print("  day  plots  되찾은가치  잃는수확  주방손실   순이익  위임가능")
    for row in table:
        print(f"  {row['day']:>3}  {row['plots']:>5}  {row['freed']:>9.1f}  {row['lost_harvest']:>8.1f}  {row['kitchen']:>8.1f}  {row['net']:>7.1f}  {'O' if row['available'] else '-'}")
    if crossover is None:
        failures.append("위임 교차점: 14일 안에 순이익이 양수가 되는 날이 없음 (automation_efficiency·farm_plots·stamina_* 조정)")
        print("  교차점: 없음 → FAIL")
    else:
        ok = DELEGATION_TARGET_DAYS[0] <= crossover <= DELEGATION_TARGET_DAYS[1]
        print(f"  교차점: {crossover}일차 → {'PASS' if ok else 'FAIL'} (목표 {DELEGATION_TARGET_DAYS[0]}~{DELEGATION_TARGET_DAYS[1]})")
        if not ok:
            failures.append(f"위임 교차점 {crossover}일차 (목표 {DELEGATION_TARGET_DAYS[0]}~{DELEGATION_TARGET_DAYS[1]}) — u_automation 날짜 또는 automation_efficiency 조정")

    print()
    print("== 3. 경제 곡선 초안 (기대 수입, 지출 없음 — 사람이 확정) ==")
    print("  day  손님   텃밭   채집    누적 돈")
    for row in economy_curve(tune, unlocks, crops, items, materials, regions, species, args.days):
        print(f"  {row['day']:>3}  {row['guest']:>5.1f}  {row['farm']:>5.1f}  {row['gather']:>5.1f}  {row['money']:>8.0f}")

    print()
    if failures:
        for text in failures:
            print(f"[sim] FAIL: {text}")
        return 1 if args.check else 0
    print("[sim] PASS: 케이던스·위임 교차점 모두 목표 안")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
