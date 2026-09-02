#!/usr/bin/env python3
"""CSV -> Godot .tres 빌더 (data/csv -> data/resources).

검증 순서: 필수 컬럼 존재 -> 타입 변환 -> 키 중복 -> 참조 무결성.
하나라도 실패하면 어느 파일의 어느 행이 문제인지 출력하고 종료 코드 1로 중단한다.
스키마는 docs/decisions/2026-09-02_csv_schema_v1.md 참조.

사용:  python tools/data/build_resources.py [--check]   (--check 는 검증만, 파일 미생성)
"""
from __future__ import annotations

import argparse
import csv
import re
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
CSV_DIR = ROOT / "data" / "csv"
OUT_DIR = ROOT / "data" / "resources"
SCRIPT_DIR = "res://src/core/resources/"

ENUMS: dict[str, set[str]] = {
    "item_kind": {"food", "material", "misc", "key"},
    "rent_type": {"money", "items", "errand", "buff", "info", "none"},
    "rarity": {"common", "uncommon", "rare"},
    "room_kind": {"lodging", "production", "service", "gate", "storage", "empty"},
    "tuning_type": {"int", "float", "bool", "string"},
    "sprite_size": {"16", "32"},
    "join_mode": {"start", "intake"},
    "visitor_kind": {"guest", "troublemaker", "erased"},
    "event_kind": {"tutorial", "story", "arrival"},
    "event_phase": {"morning", "day", "evening", "night", "any"},
}

# 대사 효과 문법: affinity:+1 / item:<id>:<±n> / flag:<name> / money:<±n>  (세미콜론으로 여러 개)
EFFECT_PATTERN = re.compile(r"^(affinity:[+-]?\d+|item:[a-z0-9_]+:[+-]?\d+|flag:[a-z0-9_]+|money:[+-]?\d+)$")
DIALOGUE_END = "end"
SPEAKER_PLAYER = "player"


def parse_rent_item(value: str) -> str:
    """빈 값, items.csv id, 또는 'kind:<item_kind>'(해당 종류에서 무작위)."""
    v = value.strip()
    if v.startswith("kind:"):
        parse_enum("item_kind")(v[len("kind:"):])
    return v


def parse_effects(value: str) -> str:
    v = value.strip()
    for part in filter(None, (p.strip() for p in v.split(";"))):
        if not EFFECT_PATTERN.match(part):
            raise ValueError(f"effect 문법 오류: {part!r}")
    return v


class BuildError(Exception):
    pass


def parse_bool(value: str) -> bool:
    v = value.strip().lower()
    if v in ("true", "1", "yes"):
        return True
    if v in ("false", "0", "no", ""):
        return False
    raise ValueError(f"bool 값이 아님: {value!r}")


def parse_enum(name: str) -> Callable[[str], str]:
    def _parse(value: str) -> str:
        v = value.strip()
        if v not in ENUMS[name]:
            raise ValueError(f"{name} 허용값 {sorted(ENUMS[name])} 밖: {value!r}")
        return v

    return _parse


def parse_sprite_size(value: str) -> int:
    return int(parse_enum("sprite_size")(value))


def parse_str(value: str) -> str:
    return value.strip()


@dataclass
class Column:
    name: str
    parse: Callable[[str], Any]
    ref: str | None = None  # 참조 대상 테이블 이름 (빈 값은 '참조 없음'으로 허용)


@dataclass
class Table:
    name: str
    csv_file: str
    columns: list[Column]
    script_class: str
    script_file: str
    key: str = "id"
    # "rows" = 행마다 .tres 하나, "dict" = 테이블 전체가 .tres 하나 (tuning, strings),
    # "grouped" = group_key 값마다 .tres 하나 (dialogue: 노드 여러 행이 대화 하나)
    mode: str = "rows"
    group_key: str = ""
    # dict 모드에서 행 -> 값 변환기. 검증 단계에서도 호출해 변환 오류를 잡는다.
    dict_value: Callable[[dict[str, Any]], Any] | None = None
    rows: list[dict[str, Any]] = field(default_factory=list)

    @property
    def required(self) -> list[str]:
        return [c.name for c in self.columns]

    def key_values(self) -> set[str]:
        """참조 무결성에서 '이 테이블의 키'로 쓰는 값. grouped 는 그룹 id."""
        if self.mode == "grouped":
            return {r[self.group_key] for r in self.rows}
        return {r[self.key] for r in self.rows}


TABLES: list[Table] = [
    Table(
        name="items",
        csv_file="items.csv",
        script_class="ItemData",
        script_file="item_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("kind", parse_enum("item_kind")),
            Column("base_value", int),
        ],
    ),
    Table(
        name="rooms",
        csv_file="rooms.csv",
        script_class="RoomData",
        script_file="room_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("kind", parse_enum("room_kind")),
            Column("build_cost", int),
            Column("capacity", int),
            Column("spirit_id", parse_str),  # spirits.csv 는 M3 — 아직 참조 검증 없음
            Column("quiet", parse_bool),
            Column("requires_room", parse_str, ref="rooms"),
            Column("output_item", parse_str, ref="items"),
            Column("output_amount", int),
        ],
    ),
    Table(
        name="yokai",
        csv_file="yokai.csv",
        script_class="YokaiData",
        script_file="yokai_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("species_ko", parse_str),
            Column("preferred_room", parse_str, ref="rooms"),
            Column("work_bonus", float),
            Column("noise", int),
            Column("night_worker", parse_bool),
            Column("rent_type", parse_enum("rent_type")),
            Column("rent_note_ko", parse_str),
            Column("rent_item", parse_rent_item),
            Column("rent_amount", int),
            Column("rent_interval_days", int),
            Column("join_mode", parse_enum("join_mode")),
            Column("join_day", int),
            Column("stat_strength", int),
            Column("stat_skill", int),
            Column("stat_sight", int),
            Column("stat_courage", int),
            Column("sprite_size", parse_sprite_size),
            Column("in_slice", parse_bool),
        ],
    ),
    Table(
        name="guest_species",
        csv_file="guest_species.csv",
        script_class="GuestSpeciesData",
        script_file="guest_species_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("rarity", parse_enum("rarity")),
            Column("flavor_ko", parse_str),
            Column("first_words_ko", parse_str),
            Column("rent_type", parse_enum("rent_type")),
            Column("rent_note_ko", parse_str),
            Column("rent_money", int),
            Column("rent_item", parse_str, ref="items"),
            Column("rent_amount", int),
            Column("omen", int),
            Column("appear_condition", parse_str),
            Column("weight", int),
            Column("promotable", parse_bool),
            Column("sprite_size", parse_sprite_size),
        ],
    ),
    Table(
        name="visitors",
        csv_file="visitors.csv",
        script_class="VisitorData",
        script_file="visitor_data.gd",
        columns=[
            Column("id", parse_str),
            Column("kind", parse_enum("visitor_kind")),
            Column("weight", int),
            Column("omen_min", int),
            Column("omen_max", int),
            Column("name_ko", parse_str),
            Column("intro_ko", parse_str),
            Column("mishap_money", int),
            Column("mishap_text_ko", parse_str),
        ],
    ),
    Table(
        name="spirits",
        csv_file="spirits.csv",
        script_class="SpiritData",
        script_file="spirit_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("role_ko", parse_str),
            Column("room_id", parse_str, ref="rooms"),
        ],
    ),
    Table(
        name="dialogue",
        csv_file="dialogue.csv",
        script_class="DialogueData",
        script_file="dialogue_data.gd",
        key="node",
        mode="grouped",
        group_key="dialogue_id",
        columns=[
            Column("dialogue_id", parse_str),
            Column("node", parse_str),
            Column("speaker", parse_str),  # yokai id / spirit id / player — 아래 check_dialogue 에서 검증
            Column("text_ko", parse_str),
            Column("portrait", parse_str),
            Column("next", parse_str),
            Column("option1_ko", parse_str),
            Column("option1_next", parse_str),
            Column("option2_ko", parse_str),
            Column("option2_next", parse_str),
            Column("effect", parse_effects),
        ],
    ),
    Table(
        name="events",
        csv_file="events.csv",
        script_class="EventData",
        script_file="event_data.gd",
        columns=[
            Column("id", parse_str),
            Column("kind", parse_enum("event_kind")),
            Column("yokai_id", parse_str, ref="yokai"),
            Column("phase", parse_enum("event_phase")),
            Column("day_min", int),
            Column("day_max", int),
            Column("min_affinity", int),
            Column("requires_item", parse_str, ref="items"),
            Column("requires_flag", parse_str),
            Column("once", parse_bool),
            Column("priority", int),
            Column("dialogue_id", parse_str, ref="dialogue"),
            Column("title_ko", parse_str),
        ],
    ),
    Table(
        name="tuning",
        csv_file="tuning.csv",
        script_class="TuningData",
        script_file="tuning_data.gd",
        key="key",
        mode="dict",
        dict_value=lambda row: convert_tuning_value(row),
        columns=[
            Column("key", parse_str),
            Column("value", parse_str),
            Column("type", parse_enum("tuning_type")),
            Column("description", parse_str),
        ],
    ),
    Table(
        name="strings_ko",
        csv_file="strings_ko.csv",
        script_class="StringTableData",
        script_file="string_table_data.gd",
        key="key",
        mode="dict",
        # CSV 셀 안의 리터럴 \n 을 줄바꿈으로 (여러 줄 툴팁용)
        dict_value=lambda row: row["text"].replace("\\n", "\n"),
        columns=[
            Column("key", parse_str),
            Column("text", parse_str),
        ],
    ),
]


# ---------------------------------------------------------------- 읽기·검증


def read_table(table: Table) -> None:
    path = CSV_DIR / table.csv_file
    if not path.exists():
        raise BuildError(f"{table.csv_file}: 파일 없음 ({path})")
    with path.open(encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        header = reader.fieldnames or []
        missing = [c for c in table.required if c not in header]
        if missing:
            raise BuildError(f"{table.csv_file}: 필수 컬럼 누락 {missing} (헤더: {header})")
        for line_no, raw in enumerate(reader, start=2):
            if not any((v or "").strip() for v in raw.values()):
                continue  # 빈 줄
            row: dict[str, Any] = {}
            for col in table.columns:
                raw_value = raw.get(col.name) or ""
                try:
                    row[col.name] = col.parse(raw_value)
                except (ValueError, TypeError) as exc:
                    raise BuildError(f"{table.csv_file} {line_no}행 컬럼 {col.name!r}: {exc}") from exc
            if not row[table.key]:
                raise BuildError(f"{table.csv_file} {line_no}행: {table.key} 가 비어 있음")
            row["_line"] = line_no
            table.rows.append(row)


def check_duplicates(table: Table) -> None:
    seen: dict[tuple[str, str], int] = {}
    for row in table.rows:
        group = row[table.group_key] if table.mode == "grouped" else ""
        key = (group, row[table.key])
        if key in seen:
            label = f"{table.group_key}={group!r} " if group else ""
            raise BuildError(
                f"{table.csv_file} {row['_line']}행: {label}{table.key}={key[1]!r} 중복 ({seen[key]}행과 동일)"
            )
        seen[key] = row["_line"]


def check_dialogue(tables: dict[str, Table]) -> None:
    """화자·초상은 yokai/spirits/player 중 하나, next 는 같은 대화의 node 또는 'end'."""
    dialogue = tables["dialogue"]
    speakers = tables["yokai"].key_values() | tables["spirits"].key_values() | {SPEAKER_PLAYER}
    nodes_by_group: dict[str, set[str]] = {}
    for row in dialogue.rows:
        nodes_by_group.setdefault(row["dialogue_id"], set()).add(row["node"])
    for row in dialogue.rows:
        line = row["_line"]
        if row["speaker"] not in speakers:
            raise BuildError(f"dialogue.csv {line}행: speaker {row['speaker']!r} 는 yokai/spirits/player 가 아님")
        if row["portrait"] and row["portrait"] not in speakers - {SPEAKER_PLAYER}:
            raise BuildError(f"dialogue.csv {line}행: portrait {row['portrait']!r} 는 yokai/spirits id 가 아님")
        targets = [row["next"], row["option1_next"], row["option2_next"]]
        has_options = bool(row["option1_ko"] or row["option2_ko"])
        if not has_options and not row["next"]:
            raise BuildError(f"dialogue.csv {line}행: next 가 비어 있고 선택지도 없음")
        for target in filter(None, targets):
            if target != DIALOGUE_END and target not in nodes_by_group[row["dialogue_id"]]:
                raise BuildError(f"dialogue.csv {line}행: 이동 대상 node {target!r} 가 {row['dialogue_id']} 에 없음")
        if (row["option1_ko"] and not row["option1_next"]) or (row["option2_ko"] and not row["option2_next"]):
            raise BuildError(f"dialogue.csv {line}행: 선택지 문구는 있는데 이동 대상이 없음")
    for group, nodes in nodes_by_group.items():
        if "start" not in nodes:
            raise BuildError(f"dialogue.csv: 대화 {group!r} 에 start 노드가 없음")


def check_references(tables: dict[str, Table]) -> None:
    keys = {name: t.key_values() for name, t in tables.items()}
    for table in tables.values():
        for col in table.columns:
            if col.ref is None:
                continue
            target = tables[col.ref]
            for row in table.rows:
                value = row[col.name]
                if value and value not in keys[col.ref]:
                    raise BuildError(
                        f"{table.csv_file} {row['_line']}행 컬럼 {col.name!r}: "
                        f"{value!r} 가 {target.csv_file} 의 {target.key} 에 없음"
                    )


def convert_tuning_value(row: dict[str, Any]) -> Any:
    kind, raw = row["type"], row["value"]
    try:
        if kind == "int":
            return int(raw)
        if kind == "float":
            return float(raw)
        if kind == "bool":
            return parse_bool(raw)
        return raw
    except ValueError as exc:
        raise BuildError(
            f"tuning.csv {row['_line']}행 key={row['key']!r}: {kind} 변환 실패 ({raw!r})"
        ) from exc


# ---------------------------------------------------------------- .tres 출력


def gd_literal(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        text = repr(value)
        return text if ("." in text or "e" in text) else text + ".0"
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{escaped}"'
    if isinstance(value, dict):
        items = ",\n".join(f"{gd_literal(k)}: {gd_literal(v)}" for k, v in value.items())
        return "{\n" + items + "\n}" if items else "{}"
    if isinstance(value, list):
        return "[" + ", ".join(gd_literal(v) for v in value) + "]"
    raise TypeError(f"직렬화 불가 타입: {type(value)}")


def tres_text(table: Table, props: dict[str, Any]) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="{table.script_class}" load_steps=2 format=3]',
        "",
        f'[ext_resource type="Script" path="{SCRIPT_DIR}{table.script_file}" id="1_script"]',
        "",
        "[resource]",
        'script = ExtResource("1_script")',
    ]
    for name, value in props.items():
        lines.append(f"{name} = {gd_literal(value)}")
    return "\n".join(lines) + "\n"


def write_outputs(tables: dict[str, Table]) -> list[Path]:
    written: list[Path] = []
    for table in tables.values():
        if table.mode == "rows":
            out_dir = OUT_DIR / table.name
            if out_dir.exists():
                shutil.rmtree(out_dir)
            out_dir.mkdir(parents=True)
            for row in table.rows:
                props = {c.name: row[c.name] for c in table.columns}
                path = out_dir / f"{row[table.key]}.tres"
                path.write_text(tres_text(table, props), encoding="utf-8", newline="\n")
                written.append(path)
        elif table.mode == "grouped":
            out_dir = OUT_DIR / table.name
            if out_dir.exists():
                shutil.rmtree(out_dir)
            out_dir.mkdir(parents=True)
            groups: dict[str, list[dict[str, Any]]] = {}
            for row in table.rows:
                node = {c.name: row[c.name] for c in table.columns if c.name != table.group_key}
                groups.setdefault(row[table.group_key], []).append(node)
            for group_id, nodes in groups.items():
                path = out_dir / f"{group_id}.tres"
                path.write_text(tres_text(table, {"id": group_id, "nodes": nodes}), encoding="utf-8", newline="\n")
                written.append(path)
        else:
            assert table.dict_value is not None, f"{table.name}: dict 모드에는 dict_value 가 필요"
            values = {row[table.key]: table.dict_value(row) for row in table.rows}
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            path = OUT_DIR / f"{table.name}.tres"
            path.write_text(tres_text(table, {"values": values}), encoding="utf-8", newline="\n")
            written.append(path)
    return written


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="CSV -> .tres 빌더")
    parser.add_argument("--check", action="store_true", help="검증만 수행하고 파일을 쓰지 않음")
    args = parser.parse_args(argv)

    tables = {t.name: t for t in TABLES}
    try:
        for table in tables.values():
            read_table(table)
            check_duplicates(table)
        check_references(tables)
        check_dialogue(tables)
        for table in tables.values():
            if table.dict_value is not None:
                for row in table.rows:
                    table.dict_value(row)
        summary = ", ".join(f"{t.name}={len(t.rows)}" for t in tables.values())
        print(f"[build_resources] 검증 통과: {summary}")
        if args.check:
            return 0
        written = write_outputs(tables)
        print(f"[build_resources] {len(written)}개 .tres 생성 -> {OUT_DIR.relative_to(ROOT)}")
        return 0
    except BuildError as exc:
        print(f"[build_resources] 실패: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
