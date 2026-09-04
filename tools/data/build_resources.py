#!/usr/bin/env python3
"""CSV -> Godot .tres 빌더 (data/csv -> data/resources).

검증 순서: 필수 컬럼 존재 -> 타입 변환 -> 키 중복 -> 참조 무결성 -> 대화 그래프 -> 해금 조건 -> 사슬(용도 3칸).
하나라도 실패하면 어느 파일의 어느 행이 문제인지 출력하고 종료 코드 1로 중단한다.
스키마는 docs/decisions/2026-09-02_csv_schema_v1.md, P1 신설 스키마는 docs/decisions/2026-09-03_p1_s1_realtime_clock_and_schema.md 참조.

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
    "item_kind": {"food", "material", "misc", "key", "talisman", "seed", "crop", "fish"},
    "rent_type": {"money", "items", "errand", "buff", "info", "none"},
    "rarity": {"common", "uncommon", "rare"},
    "room_kind": {"lodging", "production", "service", "gate", "storage", "empty"},
    "tuning_type": {"int", "float", "bool", "string"},
    "sprite_size": {"16", "32"},
    "join_mode": {"start", "intake"},
    "visitor_kind": {"guest", "troublemaker", "erased", "promotion"},
    "event_kind": {"tutorial", "story", "arrival", "npc", "chapter"},
    "timeband": {"morning", "day", "evening", "night", "any"},
    # --- P1 신설 ---
    "realm": {"mortal", "demon", "both"},
    "material_source": {"gather", "chop", "mine", "drop", "fish", "farm", "craft"},
    "tool_kind": {"none", "hoe", "axe", "pickaxe", "rod"},
    "season": {"any", "spring", "summer", "autumn", "winter"},
    "yin_condition": {"any", "low", "high"},
    "fish_kind": {"fish", "junk"},
    "talisman_effect": {"throw", "gather", "return"},
    "region_kind": {"house", "yard", "wild", "gate", "expedition", "market"},
    "enemy_tier": {"normal", "boss"},
    "unlock_type": {"region", "tool", "talisman", "enemy", "yokai", "event", "crop", "material", "fish", "verb", "feature",
                    "season_event", "festival", "recipe"},
    "goal_tier": {"today", "season", "long"},
    "verb": {"walk", "gather", "farm", "cook", "fish", "craft", "talk", "intake", "assign", "build", "explore", "fight", "sleep"},
    "chain_content_type": {"material", "crop", "talisman", "fish", "recipe", "blessing"},
    "chain_use_kind": {"cook", "craft", "sell", "gift", "buff", "quest", "feed", "bait", "decor", "combat", "gather", "travel", "upgrade", "event", "farm"},
    "synergy_context": {"yokai", "talisman_effect", "crop_realm", "recipe_stat"},
    "metrics_category": {"session", "day", "house", "economy", "intake", "story", "save", "verb"},
    "buff_stat": {"none", "strength", "skill", "sight", "courage"},
    # --- P2 신설 ---
    "guest_realm": {"mortal", "demon"},
    "season_or_any": {"any", "spring", "summer", "autumn", "winter"},
}

# 대사 효과 문법: affinity:+1 / item:<id>:<±n> / flag:<name> / money:<±n>  (세미콜론으로 여러 개)
EFFECT_PATTERN = re.compile(r"^(affinity:[+-]?\d+|item:[a-z0-9_]+:[+-]?\d+|flag:[a-z0-9_]+|money:[+-]?\d+)$")
# 해금 조건 문법 (세미콜론 AND): flag:<name> / affinity:<yokai>>=<n> / unlock:<id> / resident:<yokai> / item:<id>>=<n>
CONDITION_PATTERN = re.compile(
    r"^(flag:[a-z0-9_]+|affinity:[a-z0-9_]+>=\d+|unlock:[a-z0-9_]+|resident:[a-z0-9_]+|item:[a-z0-9_]+>=\d+)$"
)
ID_PATTERN = re.compile(r"^[a-z0-9_]+$")
COST_PATTERN = re.compile(r"^[a-z0-9_]+:\d+$")
DIALOGUE_END = "end"
SPEAKER_PLAYER = "player"
LIST_SEPARATOR = ";"

# 해금 대상 타입 -> 참조 테이블. verb 는 ENUMS["verb"], feature 는 자유 id.
UNLOCK_REF_TABLES: dict[str, str] = {
    "region": "regions", "tool": "tools", "talisman": "talismans", "enemy": "enemies", "yokai": "yokai",
    "event": "events", "crop": "crops", "material": "materials", "fish": "fish",
    "season_event": "season_events", "festival": "festivals", "recipe": "recipes",
}
# 목표 조건 문법 (세미콜론 AND): 정량 절 <name>[:<target>]>=<n>, 불리언 절 resident:/unlock:/flag:
GOAL_CONDITION_PATTERN = re.compile(
    r"^((item|count|rooms|affinity|festival):[a-z0-9_.]+>=\d+|(ledger|species|residents|floors|beds|money|reputation)>=\d+"
    r"|(resident|unlock|flag):[a-z0-9_]+)$"
)


def parse_goal_condition(value: str) -> str:
    v = value.strip()
    for part in filter(None, (p.strip() for p in v.split(LIST_SEPARATOR))):
        if not GOAL_CONDITION_PATTERN.match(part):
            raise ValueError(f"goal condition 문법 오류: {part!r}")
    return v
# 사슬 대상 타입 -> 참조 테이블. recipes 테이블이 생기면 자동으로 검증 대상에 든다.
CHAIN_REF_TABLES: dict[str, str] = {
    "material": "materials", "crop": "crops", "talisman": "talismans", "fish": "fish", "recipe": "recipes",
    "blessing": "blessings",
}
# 사슬 행이 반드시 있어야 하는 콘텐츠 (docs/01 v3 5절: 재료·작물·요리·부적 + P2-S3 가호). fish 는 대상이 아니다.
CHAIN_COVERED_TYPES: tuple[str, ...] = ("material", "crop", "talisman", "recipe", "blessing")


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


def parse_condition(value: str) -> str:
    v = value.strip()
    for part in filter(None, (p.strip() for p in v.split(LIST_SEPARATOR))):
        if not CONDITION_PATTERN.match(part):
            raise ValueError(f"condition 문법 오류: {part!r} (flag:x / affinity:y>=n / unlock:u / resident:y / item:i>=n)")
    return v


def parse_id_list(value: str) -> list[str]:
    """세미콜론으로 나눈 id 목록. 빈 값은 빈 목록."""
    result: list[str] = []
    for part in filter(None, (p.strip() for p in value.split(LIST_SEPARATOR))):
        if not ID_PATTERN.match(part):
            raise ValueError(f"id 형식 오류: {part!r}")
        result.append(part)
    return result


def parse_cost_list(value: str) -> list[str]:
    """'item_id:n' 목록."""
    result: list[str] = []
    for part in filter(None, (p.strip() for p in value.split(LIST_SEPARATOR))):
        if not COST_PATTERN.match(part):
            raise ValueError(f"비용 형식 오류: {part!r} (item_id:n)")
        result.append(part)
    return result


def parse_use(value: str) -> str:
    """사슬 용도 'kind:detail'. 비어 있으면 빈 문자열 (3칸 검사는 check_chains 가 한다)."""
    v = value.strip()
    if not v:
        return v
    kind, sep, detail = v.partition(":")
    if not sep or kind not in ENUMS["chain_use_kind"] or not ID_PATTERN.match(detail):
        raise ValueError(f"use 형식 오류: {v!r} (kind:detail, kind ∈ {sorted(ENUMS['chain_use_kind'])})")
    return v


SEGMENT_PATTERN = re.compile(r"^\d+:\d+:-?\d+$")
DOOR_PATTERN = re.compile(r"^[a-z0-9_]+:\d+$")
SPAN_PATTERN = re.compile(r"^\d+:\d+$")


def parse_segment_list(value: str) -> list[str]:
    """바닥 구간 'x0:x1:y' 목록 (regions.ground). y 는 기준 바닥 0 에서의 오프셋(위가 음수)."""
    result: list[str] = []
    for part in filter(None, (p.strip() for p in value.split(LIST_SEPARATOR))):
        if not SEGMENT_PATTERN.match(part):
            raise ValueError(f"ground 형식 오류: {part!r} (x0:x1:y)")
        x0, x1, _ = (int(v) for v in part.split(":"))
        if x1 <= x0:
            raise ValueError(f"ground 구간 오류: {part!r} (x1 은 x0 보다 커야 함)")
        result.append(part)
    return result


def parse_door_list(value: str) -> list[str]:
    """문 'region_id:x' 목록 (regions.doors)."""
    result: list[str] = []
    for part in filter(None, (p.strip() for p in value.split(LIST_SEPARATOR))):
        if not DOOR_PATTERN.match(part):
            raise ValueError(f"doors 형식 오류: {part!r} (region_id:x)")
        result.append(part)
    return result


def parse_span(value: str) -> str:
    v = value.strip()
    if v and not SPAN_PATTERN.match(v):
        raise ValueError(f"span 형식 오류: {v!r} (x0:x1)")
    return v


def door_ids(value: list[str]) -> list[str]:
    return [part.split(":")[0] for part in value]


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


def cost_ids(value: list[str]) -> list[str]:
    return [part.split(":")[0] for part in value]


@dataclass
class Column:
    name: str
    parse: Callable[[str], Any]
    ref: str | None = None  # 참조 대상 테이블 이름 (빈 값은 '참조 없음'으로 허용)
    # 참조 검사에 쓸 id 를 파싱 값에서 뽑는다. 기본은 값 하나, 목록 컬럼은 목록 그대로, 비용 목록은 item 부분.
    ref_ids: Callable[[Any], list[str]] = lambda v: [v] if v else []


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
            Column("clarity_by_affinity", parse_bool),
            Column("in_slice", parse_bool),
        ],
    ),
    Table(
        name="hints",
        csv_file="hints.csv",
        script_class="HintData",
        script_file="hint_data.gd",
        columns=[
            Column("id", parse_str),
            Column("timeband", parse_enum("timeband")),
            Column("day_min", int),
            Column("day_max", int),
            Column("requires_flag", parse_str),
            Column("blocked_by_flag", parse_str),
            Column("priority", int),
            Column("text_ko", parse_str),
        ],
    ),
    Table(
        name="sfx",
        csv_file="sfx.csv",
        script_class="SfxData",
        script_file="sfx_data.gd",
        columns=[
            Column("id", parse_str),
            Column("file", parse_str),
            Column("volume_db", float),
            Column("loop", parse_bool),
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
            # 손님 만족 (P1-S3): 체크아웃 때 이 요리가 창고에 있으면 먹고 돈을 더 낸다
            Column("liked_recipe", parse_str, ref="recipes"),
            # 이승/마계 손님 갈래 — 날씨 음기 배율의 대상 (P2-S1)
            Column("realm", parse_enum("guest_realm")),
            # 승격(장기 계약)하면 이 하숙생이 된다 (P2-S4). promotable 인 종족만 뜻이 있다
            Column("promotes_to", parse_str, ref="yokai"),
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
            Column("timeband", parse_enum("timeband")),
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
    # ------------------------------------------------------------ P1 신설 (docs/01 v3 5절)
    Table(
        name="recipes",
        csv_file="recipes.csv",
        script_class="RecipeData",
        script_file="recipe_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("tier", int),
            Column("output_item", parse_str, ref="items"),
            Column("output_count", int),
            Column("ingredients", parse_cost_list, ref="items", ref_ids=cost_ids),
            Column("cook_seconds", float),
            Column("buff_stat", parse_enum("buff_stat")),
            Column("buff_amount", int),
        ],
    ),
    Table(
        name="materials",
        csv_file="materials.csv",
        script_class="MaterialData",
        script_file="material_data.gd",
        columns=[
            Column("id", parse_str, ref="items"),  # 인벤토리 공용이므로 items.csv 에도 있어야 한다
            Column("name_ko", parse_str),
            Column("realm", parse_enum("realm")),
            Column("source", parse_enum("material_source")),
            Column("tool_kind", parse_enum("tool_kind")),
            Column("min_tool_level", int),
            Column("season", parse_enum("season")),
            Column("yin_condition", parse_enum("yin_condition")),
            Column("rarity", parse_enum("rarity")),
        ],
    ),
    Table(
        name="crops",
        csv_file="crops.csv",
        script_class="CropData",
        script_file="crop_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("realm", parse_enum("realm")),
            Column("seed_item", parse_str, ref="items"),
            Column("harvest_item", parse_str, ref="items"),
            Column("grow_days", int),
            Column("water_per_day", int),
            Column("yield_min", int),
            Column("yield_max", int),
            Column("yin_growth_bonus", float),
            Column("season", parse_enum("season")),
        ],
    ),
    Table(
        name="fish",
        csv_file="fish.csv",
        script_class="FishData",
        script_file="fish_data.gd",
        columns=[
            Column("id", parse_str, ref="items"),
            Column("name_ko", parse_str),
            Column("kind", parse_enum("fish_kind")),
            Column("region_id", parse_str, ref="regions"),
            Column("weight", int),
            Column("timeband", parse_enum("timeband")),
            Column("min_rod_level", int),
            # 낚이면 아이템 대신 그날 밤 이 종족이 문을 두드린다 (P2-S3 우물 낚시 1% 손님). 비우면 보통 어종
            Column("visitor_species", parse_str, ref="guest_species"),
            # 절기 어종 (P3-S1). any 면 늘
            Column("season", parse_enum("season")),
        ],
    ),
    Table(
        name="talismans",
        csv_file="talismans.csv",
        script_class="TalismanData",
        script_file="talisman_data.gd",
        columns=[
            Column("id", parse_str, ref="items"),
            Column("name_ko", parse_str),
            Column("effect", parse_enum("talisman_effect")),
            Column("cooldown_seconds", float),
            Column("power", int),
            Column("range_px", int),
            Column("craft_cost", parse_cost_list, ref="items", ref_ids=cost_ids),
            Column("craft_seconds", float),
        ],
    ),
    Table(
        name="tools",
        csv_file="tools.csv",
        script_class="ToolData",
        script_file="tool_data.gd",
        columns=[
            Column("id", parse_str),
            Column("kind", parse_enum("tool_kind")),
            Column("level", int),
            Column("name_ko", parse_str),
            Column("stamina_cost", int),
            Column("power", int),
            Column("upgrade_cost", parse_cost_list, ref="items", ref_ids=cost_ids),
            Column("upgrade_from", parse_str, ref="tools"),
        ],
    ),
    Table(
        name="regions",
        csv_file="regions.csv",
        script_class="RegionData",
        script_file="region_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("realm", parse_enum("realm")),
            Column("kind", parse_enum("region_kind")),
            Column("parent_id", parse_str, ref="regions"),
            Column("gather_point_count", int),
            Column("gather_pool", parse_id_list, ref="materials", ref_ids=lambda v: v),
            Column("enemy_pool", parse_id_list, ref="enemies", ref_ids=lambda v: v),
            Column("boss_id", parse_str, ref="enemies"),
            Column("stamina_enter_cost", int),
            Column("in_p1", parse_bool),
            # --- 레이아웃 (P1-S2): 씬은 이 값으로 조립된다. house 는 방 그리드에서 계산하므로 비워 둔다
            Column("width_px", int),
            Column("ground", parse_segment_list),
            Column("doors", parse_door_list, ref="regions", ref_ids=door_ids),
            Column("gather_span", parse_span),
            Column("farm_x", int),
            Column("sky_color", parse_str),
            # 낚시 자리 x (0 = 없음). P1-S3
            Column("fishing_x", int),
            # 들어갈 때 enemy_pool 에서 뽑아 놓는 적 수 (탐험지). P1-S4
            Column("enemy_count", int),
            # 회색 장꾼 NPC 자리 x (0 = 없음). P2-S3
            Column("merchant_x", int),
            # 밤 변형 (P2-S4): 밤에 문을 지나면 이 풀·색으로 조립된 "<id>@night" 가 된다. 채집 풀이 비면 변형 없음
            Column("night_gather_pool", parse_id_list, ref="materials", ref_ids=lambda v: v),
            Column("night_enemy_pool", parse_id_list, ref="enemies", ref_ids=lambda v: v),
            Column("night_enemy_count", int),
            Column("night_sky_color", parse_str),
        ],
    ),
    Table(
        name="enemies",
        csv_file="enemies.csv",
        script_class="EnemyData",
        script_file="enemy_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("tier", parse_enum("enemy_tier")),
            Column("hp", int),
            Column("attack", int),
            Column("speed_px", float),
            Column("aggro_radius_px", int),
            Column("drop_material", parse_str, ref="materials"),
            Column("drop_chance", float),
            Column("sprite_size", parse_sprite_size),
        ],
    ),
    Table(
        name="unlocks",
        csv_file="unlocks.csv",
        script_class="UnlockData",
        script_file="unlock_data.gd",
        columns=[
            Column("id", parse_str),
            Column("day_min", int),
            Column("expected_day", int),
            Column("timeband", parse_enum("timeband")),
            Column("condition", parse_condition),
            Column("unlock_type", parse_enum("unlock_type")),
            Column("unlock_id", parse_str),  # 타입별 참조는 check_unlocks
            Column("hint_ko", parse_str),
        ],
    ),
    Table(
        name="chains",
        csv_file="chains.csv",
        script_class="ChainData",
        script_file="chain_data.gd",
        key="content_id",
        columns=[
            Column("content_type", parse_enum("chain_content_type")),
            Column("content_id", parse_str),  # 타입별 참조는 check_chains
            Column("use1", parse_use),
            Column("use2", parse_use),
            Column("use3", parse_use),
        ],
    ),
    Table(
        name="metrics_events",
        csv_file="metrics_events.csv",
        script_class="MetricsEventData",
        script_file="metrics_event_data.gd",
        columns=[
            Column("id", parse_str),
            Column("category", parse_enum("metrics_category")),
            Column("fields", parse_id_list),
            Column("description", parse_str),
        ],
    ),
    # ------------------------------------------------------------ P2 신설 (docs/04 P2-S1: 절기·음기 날씨)
    Table(
        name="seasons",
        csv_file="seasons.csv",
        script_class="SeasonData",
        script_file="season_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("order", int),
            Column("length_days", int),
            Column("next_id", parse_str, ref="seasons"),
        ],
    ),
    Table(
        name="weather",
        csv_file="weather.csv",
        script_class="WeatherData",
        script_file="weather_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("season", parse_enum("season_or_any")),
            Column("weight", int),
            Column("yin_min", int),
            Column("yin_max", int),
            Column("mortal_guest_multiplier", float),
            Column("demon_guest_multiplier", float),
            Column("crop_water_bonus", float),
        ],
    ),
    Table(
        name="season_events",
        csv_file="season_events.csv",
        script_class="SeasonEventData",
        script_file="season_event_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("season", parse_str, ref="seasons"),
            Column("day_of_season", int),
            Column("duration_days", int),
            Column("weather_override", parse_str, ref="weather"),
            Column("gather_multiplier", float),
            Column("demon_guest_multiplier", float),
            Column("hint_ko", parse_str),
        ],
    ),
    Table(
        name="goals",
        csv_file="goals.csv",
        script_class="GoalData",
        script_file="goal_data.gd",
        columns=[
            Column("id", parse_str),
            Column("tier", parse_enum("goal_tier")),
            Column("name_ko", parse_str),
            Column("condition", parse_goal_condition),  # 참조 대상은 check_goals
            Column("day_min", int),
            Column("day_max", int),
            Column("festival_id", parse_str, ref="festivals"),
            Column("reward_money", int),
            Column("reward_reputation", int),
            Column("hint_ko", parse_str),
        ],
    ),
    Table(
        name="festivals",
        csv_file="festivals.csv",
        script_class="FestivalData",
        script_file="festival_data.gd",
        columns=[
            Column("id", parse_str),
            Column("name_ko", parse_str),
            Column("season", parse_str, ref="seasons"),
            Column("day_of_season", int),
            Column("dish_recipe", parse_str, ref="recipes"),
            Column("dish_target", int),
            Column("guest_target", int),
            Column("goal_ids", parse_id_list, ref="goals", ref_ids=lambda v: v),
            Column("score_per_goal", int),
            Column("score_per_guest", int),
            Column("score_per_dish", int),
            Column("reward_money", int),
            Column("reward_reputation", int),
            Column("perfect_reward_reputation", int),
            Column("rare_guest_species", parse_str, ref="guest_species"),
            Column("decor_goal", parse_str, ref="goals"),
            Column("hint_ko", parse_str),
        ],
    ),
    # ------------------------------------------------------------ P2-S3: 가호·회색 시장
    Table(
        name="blessings",
        csv_file="blessings.csv",
        script_class="BlessingData",
        script_file="blessing_data.gd",
        columns=[
            Column("id", parse_str),
            Column("yokai_id", parse_str, ref="yokai"),
            Column("name_ko", parse_str),
            Column("short_ko", parse_str),
            Column("affinity_min", int),
            Column("seed_yield_bonus", int),
            Column("dish_buff_bonus", int),
            Column("talisman_power_bonus", int),
            Column("flavor_ko", parse_str),
        ],
    ),
    Table(
        name="synergies",
        csv_file="synergies.csv",
        script_class="SynergyData",
        script_file="synergy_data.gd",
        columns=[
            Column("id", parse_str),
            Column("blessing_id", parse_str, ref="blessings"),
            Column("context_kind", parse_enum("synergy_context")),
            Column("context_id", parse_str),  # 종류별 참조는 check_synergies
            Column("delta", int),
            Column("note_ko", parse_str),
        ],
    ),
    Table(
        name="market_prices",
        csv_file="market_prices.csv",
        script_class="MarketPriceData",
        script_file="market_price_data.gd",
        key="item_id",
        columns=[
            Column("item_id", parse_str, ref="items"),
            Column("sell_mult", float),
            Column("buy_mult", float),
            Column("swing", float),
            Column("stock", int),
            Column("note_ko", parse_str),
        ],
    ),
    # ------------------------------------------------------------ P2-S4: 챕터
    Table(
        name="chapters",
        csv_file="chapters.csv",
        script_class="ChapterData",
        script_file="chapter_data.gd",
        columns=[
            Column("id", parse_str),
            Column("order", int),
            Column("name_ko", parse_str),
            Column("gate_goals", parse_id_list, ref="goals", ref_ids=lambda v: v),
            Column("gate_required", int),
            Column("next_id", parse_str, ref="chapters"),
            Column("summary_ko", parse_str),
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
                for value in col.ref_ids(row[col.name]):
                    if value not in keys[col.ref]:
                        raise BuildError(
                            f"{table.csv_file} {row['_line']}행 컬럼 {col.name!r}: "
                            f"{value!r} 가 {target.csv_file} 의 {target.key} 에 없음"
                        )


def check_unlocks(tables: dict[str, Table]) -> None:
    """unlock_id 는 타입별 테이블에 있어야 하고, 조건이 가리키는 요괴·해금·아이템도 실재해야 한다."""
    unlocks = tables["unlocks"]
    keys = {name: t.key_values() for name, t in tables.items()}
    unlock_ids = unlocks.key_values()
    for row in unlocks.rows:
        line, kind, target = row["_line"], row["unlock_type"], row["unlock_id"]
        if not ID_PATTERN.match(target):
            raise BuildError(f"unlocks.csv {line}행: unlock_id {target!r} 형식 오류")
        if kind in UNLOCK_REF_TABLES:
            ref_table = tables[UNLOCK_REF_TABLES[kind]]
            if target not in keys[ref_table.name]:
                raise BuildError(f"unlocks.csv {line}행: {kind} {target!r} 가 {ref_table.csv_file} 에 없음")
        elif kind == "verb" and target not in ENUMS["verb"]:
            raise BuildError(f"unlocks.csv {line}행: verb {target!r} 는 허용값 {sorted(ENUMS['verb'])} 밖")
        if row["expected_day"] < row["day_min"]:
            raise BuildError(f"unlocks.csv {line}행: expected_day({row['expected_day']}) < day_min({row['day_min']})")
        for part in filter(None, (p.strip() for p in row["condition"].split(LIST_SEPARATOR))):
            name, _, rest = part.partition(":")
            ref_id = rest.split(">=")[0]
            if name in ("affinity", "resident") and ref_id not in keys["yokai"]:
                raise BuildError(f"unlocks.csv {line}행: 조건의 요괴 {ref_id!r} 가 yokai.csv 에 없음")
            if name == "unlock":
                if ref_id == row["id"]:
                    raise BuildError(f"unlocks.csv {line}행: 자기 자신을 조건으로 건다")
                if ref_id not in unlock_ids:
                    raise BuildError(f"unlocks.csv {line}행: 조건의 해금 {ref_id!r} 가 unlocks.csv 에 없음")
            if name == "item" and ref_id not in keys["items"]:
                raise BuildError(f"unlocks.csv {line}행: 조건의 아이템 {ref_id!r} 가 items.csv 에 없음")


def check_seasons(tables: dict[str, Table]) -> None:
    """음기 0~3, 절기 이벤트가 절기 길이 안에 들고, 절기 길이·순서가 양수인지."""
    seasons = {r["id"]: r for r in tables["seasons"].rows}
    for row in tables["seasons"].rows:
        if row["length_days"] <= 0 or row["order"] <= 0:
            raise BuildError(f"seasons.csv {row['_line']}행: length_days·order 는 1 이상")
    for row in tables["weather"].rows:
        for col in ("yin_min", "yin_max"):
            if not 0 <= row[col] <= 3:
                raise BuildError(f"weather.csv {row['_line']}행: {col}={row[col]} 은 0~3 이어야 함")
        if row["yin_min"] > row["yin_max"]:
            raise BuildError(f"weather.csv {row['_line']}행: yin_min > yin_max")
    for row in tables["season_events"].rows:
        length = seasons[row["season"]]["length_days"]
        if row["duration_days"] <= 0:
            raise BuildError(f"season_events.csv {row['_line']}행: duration_days 는 1 이상")
        if not 1 <= row["day_of_season"] <= length:
            raise BuildError(f"season_events.csv {row['_line']}행: day_of_season={row['day_of_season']} 이 절기 길이 {length} 밖")
        if row["day_of_season"] + row["duration_days"] - 1 > length:
            raise BuildError(f"season_events.csv {row['_line']}행: 이벤트가 절기 끝을 넘어감")


def check_goals(tables: dict[str, Table]) -> None:
    """목표 조건이 가리키는 아이템·방·요괴·해금·명절이 실재하고, 날 창이 뒤집히지 않았으며, 명절이 절기 길이 안인지."""
    keys = {name: t.key_values() for name, t in tables.items()}
    ref_by_name = {"item": "items", "rooms": "rooms", "affinity": "yokai", "resident": "yokai", "unlock": "unlocks",
                   "festival": "festivals"}
    for row in tables["goals"].rows:
        line = row["_line"]
        if row["day_max"] and row["day_max"] < row["day_min"]:
            raise BuildError(f"goals.csv {line}행: day_max({row['day_max']}) < day_min({row['day_min']})")
        for part in filter(None, (p.strip() for p in row["condition"].split(LIST_SEPARATOR))):
            name, _, rest = part.partition(":")
            if name in ref_by_name and rest:
                target = rest.split(">=")[0]
                if target not in keys[ref_by_name[name]]:
                    raise BuildError(f"goals.csv {line}행: 조건의 {name} {target!r} 가 {ref_by_name[name]}.csv 에 없음")
    seasons = {r["id"]: r for r in tables["seasons"].rows}
    for row in tables["festivals"].rows:
        length = seasons[row["season"]]["length_days"]
        if not 1 <= row["day_of_season"] <= length:
            raise BuildError(f"festivals.csv {row['_line']}행: day_of_season={row['day_of_season']} 이 절기 길이 {length} 밖")
        if row["decor_goal"] and row["decor_goal"] not in row["goal_ids"]:
            raise BuildError(f"festivals.csv {row['_line']}행: decor_goal 은 goal_ids 안에 있어야 함")


def check_synergies(tables: dict[str, Table]) -> None:
    """시너지 문맥 id 가 종류별 테이블·열거에 실재하는지, 시세 배율·흔들림이 음수가 아닌지."""
    keys = {name: t.key_values() for name, t in tables.items()}
    for row in tables["synergies"].rows:
        line, kind, target = row["_line"], row["context_kind"], row["context_id"]
        ok = {
            "yokai": target in keys["yokai"],
            "talisman_effect": target in ENUMS["talisman_effect"],
            "crop_realm": target in ENUMS["realm"],
            "recipe_stat": target in ENUMS["buff_stat"],
        }[kind]
        if not ok:
            raise BuildError(f"synergies.csv {line}행: {kind} 문맥의 {target!r} 가 없음")
        if row["delta"] == 0:
            raise BuildError(f"synergies.csv {line}행: delta 0 은 뜻이 없음")
    for row in tables["market_prices"].rows:
        if row["sell_mult"] < 0 or row["buy_mult"] < 0 or row["swing"] < 0 or row["stock"] < 0:
            raise BuildError(f"market_prices.csv {row['_line']}행: 음수 값")
        if row["swing"] >= 1.0:
            raise BuildError(f"market_prices.csv {row['_line']}행: swing 은 1 미만 (가격이 0 이 되지 않도록)")


def check_chapters(tables: dict[str, Table]) -> None:
    """게이트 필요 수가 목표 수를 넘지 않고, 다음 챕터가 있으면 게이트도 있어야 하며, 밤 변형은 하늘색을 가진다."""
    for row in tables["chapters"].rows:
        line = row["_line"]
        if row["gate_required"] > len(row["gate_goals"]):
            raise BuildError(f"chapters.csv {line}행: gate_required({row['gate_required']}) > 게이트 목표 수({len(row['gate_goals'])})")
        if row["next_id"] and (not row["gate_goals"] or row["gate_required"] <= 0):
            raise BuildError(f"chapters.csv {line}행: next_id 가 있으면 게이트 목표와 gate_required 가 필요")
        if row["next_id"] == row["id"]:
            raise BuildError(f"chapters.csv {line}행: 자기 자신을 다음 챕터로 건다")
    for row in tables["regions"].rows:
        if row["night_gather_pool"] and not row["night_sky_color"]:
            raise BuildError(f"regions.csv {row['_line']}행: 밤 변형에는 night_sky_color 가 필요")
        if row["night_enemy_pool"] and row["night_enemy_count"] <= 0:
            raise BuildError(f"regions.csv {row['_line']}행: night_enemy_pool 이 있으면 night_enemy_count 는 1 이상")


def check_chains(tables: dict[str, Table]) -> None:
    """재미 원칙 3 의 기계 강제: 용도 3칸이 전부 차야 하고(서로 다른 갈래), 대상 콘텐츠 전부가 사슬 행을 가져야 한다."""
    chains = tables["chains"]
    covered: dict[str, set[str]] = {}
    for row in chains.rows:
        line, kind, target = row["_line"], row["content_type"], row["content_id"]
        ref_name = CHAIN_REF_TABLES[kind]
        if ref_name not in tables:
            raise BuildError(f"chains.csv {line}행: content_type {kind!r} 의 테이블 {ref_name} 이 아직 없음")
        if target not in tables[ref_name].key_values():
            raise BuildError(f"chains.csv {line}행: {kind} {target!r} 가 {tables[ref_name].csv_file} 에 없음")
        uses = [row["use1"], row["use2"], row["use3"]]
        if any(not u for u in uses):
            raise BuildError(
                f"chains.csv {line}행: {kind} {target!r} 의 용도가 3칸 미달 ({sum(1 for u in uses if u)}/3) — "
                f"docs/08 재미 원칙 3: 어디에도 두 번 쓰이지 않는 콘텐츠는 넣지 않는다"
            )
        kinds = [u.split(":")[0] for u in uses]
        if len(set(kinds)) < 3:
            raise BuildError(f"chains.csv {line}행: {kind} {target!r} 의 용도 갈래가 서로 달라야 함 ({kinds})")
        covered.setdefault(kind, set()).add(target)
    for kind in CHAIN_COVERED_TYPES:
        ref_name = CHAIN_REF_TABLES[kind]
        if ref_name not in tables:
            continue  # recipes 테이블은 P1-S3 에서 생긴다
        missing = sorted(tables[ref_name].key_values() - covered.get(kind, set()))
        if missing:
            raise BuildError(
                f"chains.csv: {tables[ref_name].csv_file} 의 {missing} 에 사슬 행이 없음 — 용도 3칸을 채워야 빌드가 통과한다"
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
                # DataRegistry 는 id 로 찾으므로 키 컬럼 이름이 달라도(chains.content_id) id 를 함께 쓴다
                props = {"id": row[table.key]} if table.key != "id" else {}
                props.update({c.name: row[c.name] for c in table.columns})
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
        check_unlocks(tables)
        check_seasons(tables)
        check_goals(tables)
        check_synergies(tables)
        check_chapters(tables)
        check_chains(tables)
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
