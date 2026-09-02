#!/usr/bin/env python3
"""플레이테스트 로그 집계: user://playtest/session_*.jsonl -> 세션별 지표 표 + Go/No-Go 자동 항목.

자동으로 판정할 수 있는 것만 계산한다 (docs/01 6절):
  2번 "증축 없이는 5일차 이후 막힘"  -> 빈 침대 0 인 저녁에 방문자가 왔는지, 객실을 지었는지
  (1·5·6번은 설문·관찰 시트에서 사람이 판정)
사용: python tools/playtest/summarize.py [로그 폴더]   (기본: %APPDATA%/Godot/app_userdata/yokai-boarding/playtest)
"""
from __future__ import annotations

import json
import os
import sys
from collections import Counter
from pathlib import Path

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

DEFAULT_DIR = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "yokai-boarding" / "playtest"
EODUKI = "y02_eoduki"


def load(path: Path) -> list[dict]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            rows.append(json.loads(line))
    return rows


def summarize(rows: list[dict]) -> dict:
    kinds = Counter(r["kind"] for r in rows)
    intake = Counter(r["data"].get("outcome", "") for r in rows if r["kind"] == "intake")
    # visitor 행 중 kind 가 빈 것은 "아무도 오지 않은 저녁" 이므로 침대 압박 계산에서 뺀다
    visitors_no_bed = sum(1 for r in rows if r["kind"] == "visitor" and r["data"].get("kind") and r["data"].get("free_beds", 1) <= 0)
    lodging_built = sum(1 for r in rows if r["kind"] == "room" and r["data"].get("room") == "guest_room")
    floors = kinds.get("floor", 0)
    max_day = max((r["day"] for r in rows), default=0)
    minutes = max((r["t"] for r in rows), default=0.0) / 60.0
    eoduki = max((r["data"].get("value", 0) for r in rows if r["kind"] == "affinity" and r["data"].get("yokai") == EODUKI), default=0)
    assignments_per_day = Counter(r["day"] for r in rows if r["kind"] == "assignment" and not r["data"].get("rest"))
    money_end = next((r["data"].get("money") for r in reversed(rows) if r["kind"] in ("session_end", "settled")), None)
    return {
        "minutes": round(minutes, 1),
        "max_day": max_day,
        "assignments": sum(assignments_per_day.values()),
        "days_with_assignment": len(assignments_per_day),
        "rooms_built": kinds.get("room", 0),
        "guest_rooms_built": lodging_built,
        "floors_added": floors,
        "intake_accepted": intake.get("ACCEPTED", 0),
        "intake_declined": intake.get("DECLINED", 0),
        "intake_no_bed": intake.get("NO_BED", 0),
        "visitors_when_full": visitors_no_bed,
        "dialogues": kinds.get("dialogue", 0),
        "eoduki_affinity_max": eoduki,
        "saves": kinds.get("save", 0),
        "money_end": money_end,
        # Go/No-Go 2번 자동 힌트: 침대가 꽉 찬 상태로 방문자를 맞은 적이 있고, 그 뒤 객실을 지었으면 증축 동기가 작동한 것
        "gonogo2_pressure_seen": visitors_no_bed > 0,
        "gonogo2_expanded": lodging_built > 0 or floors > 0,
    }


def main(argv: list[str]) -> int:
    log_dir = Path(argv[0]) if argv else DEFAULT_DIR
    files = sorted(log_dir.glob("session_*.jsonl"))
    if not files:
        print(f"[summarize] 로그 없음: {log_dir}")
        return 1
    columns = ["minutes", "max_day", "assignments", "days_with_assignment", "rooms_built", "guest_rooms_built",
               "floors_added", "intake_accepted", "intake_declined", "intake_no_bed", "visitors_when_full",
               "dialogues", "eoduki_affinity_max", "saves", "money_end", "gonogo2_pressure_seen", "gonogo2_expanded"]
    print("session\t" + "\t".join(columns))
    totals = []
    for path in files:
        summary = summarize(load(path))
        totals.append(summary)
        print(path.stem + "\t" + "\t".join(str(summary[c]) for c in columns))
    reached_day3 = sum(1 for s in totals if s["max_day"] >= 3)
    pressure = sum(1 for s in totals if s["gonogo2_pressure_seen"])
    expanded = sum(1 for s in totals if s["gonogo2_expanded"])
    print()
    print(f"세션 {len(totals)}개 · 3일차 도달 {reached_day3} · 침대 압박 경험 {pressure} · 증축 실행 {expanded}")
    print("Go/No-Go 1·5·6 은 설문/관찰 시트로 판정 (docs/playtest/questionnaire.md, observer_sheet.md)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
