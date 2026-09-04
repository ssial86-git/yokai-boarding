#!/usr/bin/env python3
"""아트 매니페스트 동기화: data/csv/art_assets.csv 에 게임이 아는 모든 논리 키의 행을 만든다.

- 키 목록은 콘텐츠 CSV(yokai·guest_species·enemies·spirits·rooms·regions)에서 뽑는다.
- 이미 있는 행은 건드리지 않고(사람이 고른 파일·프레임 유지), 없는 키만 자리표시(assets/art_generated) 또는 빈 파일로 추가한다.
- --prune: 콘텐츠에서 사라진 키의 행을 지운다.
- 웹 Asset Studio(tools/art/studio) 가 저장할 때도 이 스크립트의 규칙으로 행을 만든다.

사용: python tools/art/manifest_sync.py [--prune] [--check]
"""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CSV_DIR = ROOT / "data" / "csv"
MANIFEST = CSV_DIR / "art_assets.csv"
COLUMNS = ["key", "track", "file", "frame_w", "frame_h", "anims", "parallax", "repeat", "note"]
GENERATED = "res://assets/art_generated/"
PROP_KEYS = [
    "prop.gather_point", "prop.farm_plot", "prop.door", "prop.water", "prop.merchant",
    # 하숙집 뼈대 (HouseBackdrop): 지붕 64x32 / 기둥 16x48 / 주춧돌 64x16
    "prop.house_roof", "prop.house_pillar", "prop.house_base",
]
UI_KEYS = ["ui.panel", "ui.chip", "ui.button"]
REGION_LAYERS = ["sky", "far", "ground"]

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def read_rows(name: str) -> list[dict[str, str]]:
    with (CSV_DIR / name).open(encoding="utf-8-sig", newline="") as fh:
        return [r for r in csv.DictReader(fh) if any((v or "").strip() for v in r.values())]


def exists_res(res_path: str) -> bool:
    return (ROOT / res_path.replace("res://", "")).exists()


def default_row(key: str) -> dict[str, str]:
    """키에 맞는 기본 행: 자리표시가 있으면 그 파일, 없으면 빈 파일(폴백/코드 그림)."""
    track = "illust" if key.startswith("illust.") else ("ui" if key.startswith("ui.") else "pixel")
    file = ""
    if key.startswith("char.") and key != "char.player":
        file = GENERATED + f"yokai_{key[5:]}.png"
    elif key == "char.player":
        file = GENERATED + "player.png"
    elif key.startswith("guest."):
        file = GENERATED + f"guest_{key[6:]}.png"
    elif key.startswith("room."):
        file = GENERATED + f"room_{key[5:]}.png"
    elif key.startswith("illust."):
        file = GENERATED + f"illust_{key[7:]}.png"
    if file and not exists_res(file):
        file = ""
    return {"key": key, "track": track, "file": file, "frame_w": "0", "frame_h": "0", "anims": "",
            "parallax": "1.0" if not key.endswith(".sky") else "0.0", "repeat": "true" if key.endswith((".far", ".ground")) else "false",
            "note": ""}


def wanted_keys() -> list[str]:
    keys: list[str] = ["char.player"]
    for r in read_rows("yokai.csv"):
        keys.append(f"char.{r['id']}")
        keys.append(f"illust.{r['id']}")
    for r in read_rows("guest_species.csv"):
        keys.append(f"guest.{r['id']}")
    for r in read_rows("enemies.csv"):
        keys.append(f"enemy.{r['id']}")
    for r in read_rows("spirits.csv"):
        keys.append(f"npc.{r['id']}")
        keys.append(f"illust.{r['id']}")
    for r in read_rows("rooms.csv"):
        keys.append(f"room.{r['id']}")
    for r in read_rows("regions.csv"):
        # 하숙집(r_house)도 배경 3레이어를 가진다 — HouseBackdrop 이 그린다
        for layer in REGION_LAYERS:
            keys.append(f"region.{r['id']}.{layer}")
    keys.extend(PROP_KEYS)
    keys.extend(UI_KEYS)
    return keys


def load_manifest() -> list[dict[str, str]]:
    if not MANIFEST.exists():
        return []
    with MANIFEST.open(encoding="utf-8-sig", newline="") as fh:
        return [dict(r) for r in csv.DictReader(fh)]


def save_manifest(rows: list[dict[str, str]]) -> None:
    with MANIFEST.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=COLUMNS, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({c: row.get(c, "") for c in COLUMNS})


def sync(prune: bool) -> tuple[list[dict[str, str]], int, int]:
    rows = load_manifest()
    by_key = {r["key"]: r for r in rows}
    wanted = wanted_keys()
    added = 0
    for key in wanted:
        if key not in by_key:
            by_key[key] = default_row(key)
            added += 1
    removed = 0
    if prune:
        for key in list(by_key):
            if key not in wanted:
                del by_key[key]
                removed += 1
    ordered = [by_key[k] for k in wanted] + [by_key[k] for k in by_key if k not in wanted]
    return ordered, added, removed


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="아트 매니페스트 동기화")
    parser.add_argument("--prune", action="store_true", help="콘텐츠에 없는 키의 행을 지운다")
    parser.add_argument("--check", action="store_true", help="쓰지 않고 빠진 키만 보고 (종료 코드 1)")
    args = parser.parse_args(argv)
    rows, added, removed = sync(args.prune)
    if args.check:
        print(f"[manifest_sync] 빠진 키 {added}개, 남는 키 {removed}개")
        return 1 if added else 0
    save_manifest(rows)
    print(f"[manifest_sync] {len(rows)}행 (추가 {added}, 삭제 {removed}) -> {MANIFEST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
