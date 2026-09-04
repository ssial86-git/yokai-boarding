#!/usr/bin/env python3
"""무료(CC0) 에셋팩에서 게임 규격 시트를 조립해 art_assets.csv 를 채운다.

입력: assets/art/packs/<pack>/ (원본 시트 — 수정 금지, 라이선스 파일 동봉)
출력: assets/art_generated/packs/*.png (팔레트 양자화된 시트, 재생성 가능한 산출물)
갱신: data/csv/art_assets.csv 의 file/frame_w/frame_h/anims 열

규격 (docs/02, art_asset_data.gd):
- 캐릭터 시트 = 가로 한 줄 18프레임: idle 4 / walk 6 / work 4 / joy 2 / sad 2. 발이 프레임 아래 가운데.
  16px 원본을 32 크기 개체에 쓸 때는 2배 확대(최근접) — 화면 밀도를 통일하려는 임시 규칙.
- 방 그림 64x48 (16px 타일 4x3), 구역 배경 sky(늘림)/far(가로 반복)/ground(32x32, 바닥선 중앙), 소품은 프레임 인덱스 = 상태.
- 일러스트 1024x1024 는 스프라이트 확대 자리표시 (정식 일러스트가 오면 교체).

사용: python tools/art/import_free_packs.py
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from palette_quantize import load_palette, quantize  # noqa: E402

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
PACKS = ROOT / "assets" / "art" / "packs"
OUT = ROOT / "assets" / "art_generated" / "packs"
CSV_DIR = ROOT / "data" / "csv"
MANIFEST = CSV_DIR / "art_assets.csv"
RES_PREFIX = "res://assets/art_generated/packs/"
PALETTE = load_palette()

CHAR_ANIMS = "idle:0-3:6;walk:4-9:10;work:10-13:8;joy:14-15:4;sad:16-17:2"
ROOM_W, ROOM_H = 64, 48
TILE = 16
ILLUST = 1024


# ---------------------------------------------------------------- 시트 접근
class Sheet:
    def __init__(self, rel: str, tile: int, margin: int = 0, crop: int | None = None):
        self.img = Image.open(PACKS / rel).convert("RGBA")
        self.tile, self.margin, self.crop = tile, margin, crop
        self.cols = (self.img.width + margin) // (tile + margin)

    def __call__(self, index: int) -> Image.Image:
        c, r = index % self.cols, index // self.cols
        x, y = c * (self.tile + self.margin), r * (self.tile + self.margin)
        im = self.img.crop((x, y, x + self.tile, y + self.tile))
        if self.crop and self.crop < self.tile:
            off = (self.tile - self.crop) // 2
            im = im.crop((off, off, off + self.crop, off + self.crop))
        return im

    def cell(self, col: int, row: int, w: int, h: int) -> Image.Image:
        return self.img.crop((col * w, row * h, col * w + w, row * h + h))


TD = Sheet("kenney_tiny_dungeon/tilemap_packed.png", 16)
TT = Sheet("kenney_tiny_town/tilemap_packed.png", 16)
RL = Sheet("kenney_roguelike_indoors/roguelikeIndoor_transparent.png", 16, margin=1)
FARM = Sheet("kenney_pixel_platformer_farm/tilemap_packed.png", 18, crop=16)
COUNTRY = Sheet("ansimuz_country_platform/country-platform-tileset.png", 16)


def layer(pack: str, name: str) -> Image.Image:
    return Image.open(PACKS / pack / name).convert("RGBA")


# ---------------------------------------------------------------- 프레임 가공
def scale(im: Image.Image, factor: int) -> Image.Image:
    return im.resize((im.width * factor, im.height * factor), Image.NEAREST)


def fit(im: Image.Image, size: int) -> Image.Image:
    """내용의 경계 상자를 프레임 아래 가운데(발 기준)에 놓는다."""
    box = im.getbbox()
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if not box:
        return canvas
    content = im.crop(box)
    if content.width > size or content.height > size:
        content = content.crop((0, 0, min(content.width, size), min(content.height, size)))
    x = (size - content.width) // 2
    y = size - content.height
    canvas.alpha_composite(content, (x, y))
    return canvas


def shift(im: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (dx, dy))
    return out


def legs(im: Image.Image, dx: int) -> Image.Image:
    """아래 1/3 만 옆으로 밀어 걸음을 흉내 낸다."""
    cut = im.height * 2 // 3
    out = im.copy()
    bottom = im.crop((0, cut, im.width, im.height))
    out.paste(Image.new("RGBA", bottom.size, (0, 0, 0, 0)), (0, cut))
    out.paste(bottom, (dx, cut), bottom)
    return out


def squash(im: Image.Image) -> Image.Image:
    """위 1/3 을 1px 내려 풀 죽은 모양."""
    cut = im.height // 3
    out = im.copy()
    top = im.crop((0, 0, im.width, cut))
    out.paste(Image.new("RGBA", top.size, (0, 0, 0, 0)), (0, 0))
    out.paste(top, (0, 1), top)
    return out


def char_frames(base: Image.Image, alt: Image.Image | None = None) -> list[Image.Image]:
    up = shift(base, 0, -1)
    idle = [base, base, up, base]
    if alt is not None:
        walk = [base, alt, base, alt, base, alt]
    else:
        walk = [base, legs(base, -1), up, legs(base, 1), base, up]
    work = [base, shift(base, 1, 0), base, shift(base, -1, 0)]
    joy = [shift(base, 0, -2), base]
    sad = [squash(base), base]
    return idle + walk + work + joy + sad


def frames_from(idle: list[Image.Image], walk: list[Image.Image]) -> list[Image.Image]:
    def take(seq: list[Image.Image], n: int) -> list[Image.Image]:
        return [seq[i % len(seq)] for i in range(n)]

    base = idle[0]
    work = take(walk, 4)
    joy = [shift(base, 0, -2), base]
    sad = [squash(base), base]
    return take(idle, 4) + take(walk, 6) + work + joy + sad


def strip(frames: list[Image.Image]) -> Image.Image:
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * w, 0))
    return out


def save(name: str, im: Image.Image, tint=None, strength: float = 1.0) -> str:
    OUT.mkdir(parents=True, exist_ok=True)
    quantize(im, PALETTE, tint, strength).save(OUT / f"{name}.png")
    return RES_PREFIX + f"{name}.png"


# ---------------------------------------------------------------- 매핑
# 요괴·NPC·플레이어: Tiny Dungeon 타일 번호 (16px, 2배 확대해 32 로)
YOKAI_TILE = {
    "y01_ttukttagi": 109, "y02_eoduki": 121, "y03_dalgael": 108, "y04_bari": 123, "y05_geumjuri": 122,
    "y06_aheop": 99, "y07_museo": 124, "y08_ongi": 92, "y09_daltokki": 100, "y10_geuseundae": 110,
}
GUEST_TILE = {
    "g_mongdanggwi": ("td", 130), "g_ibulnang": ("td", 66), "g_usanson": ("td", 127), "g_geumjuri": ("td", 122),
    "g_ongi": ("tt", 107), "g_bobusang": ("td", 98), "g_baram": ("td", 108), "g_moon_rabbit": ("td", 100),
    "g_snow_child": ("td", 87), "g_ink_sprite": ("td", 121), "g_lantern_fish": ("td", 129), "g_stone_mireuk": ("td", 124),
}
NPC_TILE = {
    "seongju": 111, "jowang": 100, "mundori": 112, "gray_merchant": 84, "collector": 96,
    "village_grocer": 98, "herb_granny": 87,
}
PLAYER_TILE = 88
# 적: ("slime", 파일, 크기) 또는 ("td", 타일)
ENEMY_SRC = {
    "e_ash_wisp": ("slime", "Slime_Small_Red.png"), "e_cinder_hound": ("td", 123), "e_ash_warden": ("td", 96),
    "e_marsh_leech": ("slime", "Slime_Small_Green.png"), "e_bog_lantern": ("slime", "Slime_Small_Blue.png"),
    "e_marsh_wraith": ("td", 121), "e_marsh_mother": ("slime", "Slime_Medium_Green.png"),
    "e_clerk_shade": ("td", 84), "e_stamp_golem": ("td", 124), "e_ledger_wisp": ("slime", "Slime_Small_Blue.png"),
    "e_auditor": ("td", 97),
}
# 방: (벽 타일, 바닥 타일, [(타일, col, row), ...]) — Roguelike Indoors 번호. empty_lot 은 Tiny Town.
ROOM_WALL, ROOM_FLOOR = 363, 24
ROOMS = {
    "guest_room": [(12, 0, 1), (13, 1, 1), (39, 0, 2), (40, 1, 2), (19, 3, 1), (16, 3, 2)],
    "kitchen": [(268, 2, 1), (224, 0, 2), (97, 3, 2), (98, 1, 2), (43, 1, 1)],
    "workshop": [(266, 0, 2), (227, 1, 2), (237, 3, 1), (182, 2, 1), (265, 2, 2)],
    "gate": [(242, 1, 1), (242, 1, 2), (182, 2, 1), (238, 3, 1)],
    "storage": [(478, 0, 1), (479, 1, 1), (266, 0, 2), (267, 1, 2), (97, 2, 2), (98, 3, 2)],
    "study": [(478, 0, 1), (480, 1, 1), (224, 2, 2), (54, 3, 2), (19, 2, 1), (238, 3, 1)],
    "ondol_room": [(14, 0, 1), (15, 1, 1), (41, 0, 2), (42, 1, 2), (131, 2, 2), (259, 3, 2), (183, 3, 1)],
}
# 구역 배경: sky / far / ground / tint
DEMON_TINT = {
    "r_ash_field": ((150, 150, 165), 0.85), "r_ash_field_deep": ((120, 120, 140), 0.9),
    "r_archive_gate": ((125, 110, 175), 0.85), "r_moon_marsh": ((110, 135, 195), 0.8),
    "r_gray_market": ((175, 140, 195), 0.7), "r_well": ((120, 130, 160), 0.7),
}


# ---------------------------------------------------------------- 조립기
def build_char(name: str, base16: Image.Image, size: int) -> tuple[str, str]:
    base = fit(scale(base16, 2) if size == 32 else base16, size)
    return save(name, strip(char_frames(base))), CHAR_ANIMS


def build_slime(name: str, file: str, size: int) -> tuple[str, str]:
    im = layer("oga_slimes", file)
    cells = [im.crop((c * 32, r * 32, c * 32 + 32, r * 32 + 32)) for r in range(im.height // 32) for c in range(im.width // 32)]
    per_row = im.width // 32
    idle = [fit(f, size) for f in cells[0:per_row]]
    walk = [fit(f, size) for f in cells[per_row:per_row * 2]]
    return save(name, strip(frames_from(idle, walk))), CHAR_ANIMS


def build_room(room_id: str) -> str:
    im = Image.new("RGBA", (ROOM_W, ROOM_H), (0, 0, 0, 0))
    if room_id == "empty_lot":
        for c in range(4):
            im.alpha_composite(TT(0 if c % 2 else 1), (c * TILE, 0))
            im.alpha_composite(TT(13), (c * TILE, TILE))
            im.alpha_composite(TT(25), (c * TILE, TILE * 2))
        im.alpha_composite(TT(17), (2 * TILE, 2 * TILE))
        im.alpha_composite(TT(29), (0, 2 * TILE))
        return save(f"room_{room_id}", im)
    for c in range(4):
        im.alpha_composite(RL(ROOM_WALL), (c * TILE, 0))
        im.alpha_composite(RL(ROOM_FLOOR), (c * TILE, TILE))
        im.alpha_composite(RL(ROOM_FLOOR), (c * TILE, TILE * 2))
    for tile, c, r in ROOMS[room_id]:
        im.alpha_composite(RL(tile), (c * TILE, r * TILE))
    return save(f"room_{room_id}", im)


def gradient_sky(color: tuple[int, int, int], w: int = 320, h: int = 192) -> Image.Image:
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=tuple(int(c * (0.7 + 0.5 * t)) for c in color) + (255,))
    return im


def hex_rgb(s: str) -> tuple[int, int, int]:
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def far_forest() -> Image.Image:
    im = layer("ansimuz_parallax_forest", "parallax-forest-back-trees.png")
    im.alpha_composite(layer("ansimuz_parallax_forest", "parallax-forest-middle-trees.png"))
    return im


def far_mountain() -> Image.Image:
    far = layer("ansimuz_parallax_mountain", "parallax-mountain-montain-far.png")
    im = Image.new("RGBA", (544, 160), (0, 0, 0, 0))
    im.alpha_composite(far, (0, 0))
    im.alpha_composite(far, (272, 0))
    im.alpha_composite(layer("ansimuz_parallax_mountain", "parallax-mountain-mountains.png"))
    im.alpha_composite(layer("ansimuz_parallax_mountain", "parallax-mountain-trees.png"))
    return im


def far_wall() -> Image.Image:
    im = Image.new("RGBA", (96, 48), (0, 0, 0, 0))
    for r in range(3):
        for c in range(6):
            im.alpha_composite(TD(37 if (r + c) % 2 else 36), (c * TILE, r * TILE))
    return im


def far_town() -> Image.Image:
    im = Image.new("RGBA", (160, 64), (0, 0, 0, 0))
    house_a = [[52, 53, 54], [64, 65, 66], [72, 85, 73]]
    house_b = [[48, 49, 50], [60, 61, 62], [76, 84, 77]]
    for hx, house in ((0, house_a), (96, house_b)):
        for r, row in enumerate(house):
            for c, t in enumerate(row):
                im.alpha_composite(TT(t), (hx + c * TILE, TILE + r * TILE))
    im.alpha_composite(TT(4), (64, TILE))
    im.alpha_composite(TT(16), (64, TILE * 2))
    im.alpha_composite(TT(5), (144, TILE * 2))
    im.alpha_composite(TT(83), (144, TILE * 3))
    return im


def ground_tile(top: Image.Image, bottom: Image.Image) -> Image.Image:
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for c in range(2):
        im.alpha_composite(top, (c * TILE, 0))
        im.alpha_composite(bottom, (c * TILE, TILE))
    return im


def build_regions(regions: list[dict[str, str]], rows: dict[str, dict[str, str]]) -> None:
    grass = ground_tile(COUNTRY(80), COUNTRY(102))
    stone = ground_tile(TD(14), TD(13))
    market = ground_tile(TT(97), TT(109))
    for region in regions:
        rid = region["id"]
        if region["kind"] == "house":
            continue
        tint, strength = DEMON_TINT.get(rid, (None, 1.0))
        kind = region["kind"]
        # 하늘은 regions.csv 의 sky_color 그라데이션 — 시간대 색조는 게임이 곱한다 (팩의 보라 석양 하늘은 낮에 안 맞음)
        if rid in ("r_yard", "r_village"):
            sky, far, ground = gradient_sky(hex_rgb(region["sky_color"])), far_mountain(), grass
            if rid == "r_village":
                far = far_town()
        elif rid in ("r_back_hill", "r_stream"):
            sky, far, ground = gradient_sky(hex_rgb(region["sky_color"])), far_forest(), grass
        elif rid == "r_well":
            sky, far, ground = gradient_sky(hex_rgb(region["sky_color"])), far_wall(), stone
        elif rid == "r_gray_market":
            sky, far, ground = gradient_sky(hex_rgb(region["sky_color"])), far_town(), market
        elif rid == "r_moon_marsh":
            sky, far, ground = gradient_sky(hex_rgb(region["sky_color"])), far_forest(), grass
        else:  # 잿빛 들·심부·문서고 외곽
            sky, far, ground = gradient_sky(hex_rgb(region["sky_color"])), far_mountain(), stone
        for part, im in (("sky", sky), ("far", far), ("ground", ground)):
            key = f"region.{rid}.{part}"
            if key not in rows:
                continue
            rows[key]["file"] = save(f"region_{rid}_{part}", im, tint if part != "sky" else None, strength)
            rows[key]["frame_w"] = rows[key]["frame_h"] = "0"
            rows[key]["anims"] = ""
            rows[key]["repeat"] = "true" if part != "sky" else "false"


def water_frames() -> list[Image.Image]:
    frames = []
    for phase in range(2):
        im = Image.new("RGBA", (32, 16), (63, 92, 115, 255))
        d = ImageDraw.Draw(im)
        for x in range(0, 32, 8):
            d.line([(x + phase * 4, 2), (x + 3 + phase * 4, 2)], fill=(143, 176, 184, 255))
            d.line([(x + 4 - phase * 4, 9), (x + 7 - phase * 4, 9)], fill=(95, 128, 144, 255))
        frames.append(im)
    return frames


def build_props(rows: dict[str, dict[str, str]]) -> None:
    def put(key: str, name: str, frames: list[Image.Image], anims: str = "") -> None:
        if key not in rows:
            return
        w, h = frames[0].size
        rows[key].update(file=save(name, strip(frames)), frame_w=str(w), frame_h=str(h), anims=anims)

    put("prop.gather_point", "prop_gather_point", [fit(TT(43), 16), fit(TT(17), 16)])
    put("prop.farm_plot", "prop_farm_plot", [FARM(32), FARM(3), FARM(42), FARM(57)])
    put("prop.door", "prop_door", [fit(scale(TD(46), 2), 32), fit(scale(TD(45), 2), 32)])
    put("prop.water", "prop_water", water_frames(), "idle:0-1:2")
    put("prop.merchant", "prop_merchant", [fit(scale(TT(57), 2), 32)])


def build_ui(rows: dict[str, dict[str, str]]) -> None:
    for key, src in (("ui.panel", "brown"), ("ui.chip", "grey"), ("ui.button", "tan")):
        if key in rows:
            rows[key].update(file=save(f"ui_{src}", layer("kenney_pixel_ui", f"{src}.png")), frame_w="0", frame_h="0", anims="")


def build_illust(name: str, sprite32: Image.Image, seed: int) -> str:
    bg = PALETTE[16 + seed % 6]
    im = Image.new("RGBA", (ILLUST, ILLUST), bg + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle((32, 32, ILLUST - 33, ILLUST - 33), outline=PALETTE[5] + (255,), width=8)
    big = scale(sprite32, 24)
    im.alpha_composite(big, ((ILLUST - big.width) // 2, ILLUST - 96 - big.height))
    return save(name, im)


# ---------------------------------------------------------------- CSV
def read_csv(name: str) -> list[dict[str, str]]:
    with open(CSV_DIR / f"{name}.csv", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def main() -> int:
    with open(MANIFEST, encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        fields = list(reader.fieldnames or [])
        manifest = list(reader)
    rows = {r["key"]: r for r in manifest}

    def set_char(key: str, file: str, size: int, anims: str) -> None:
        if key in rows:
            rows[key].update(file=file, frame_w=str(size), frame_h=str(size), anims=anims)

    illust_sources: dict[str, Image.Image] = {}
    for y in read_csv("yokai"):
        size = int(y.get("sprite_size") or 32)
        file, anims = build_char(f"yokai_{y['id']}", TD(YOKAI_TILE[y["id"]]), size)
        set_char(f"char.{y['id']}", file, size, anims)
        illust_sources[y["id"]] = fit(scale(TD(YOKAI_TILE[y["id"]]), 2), 32)
    for g in read_csv("guest_species"):
        size = int(g.get("sprite_size") or 16)
        src, idx = GUEST_TILE[g["id"]]
        file, anims = build_char(f"guest_{g['id']}", (TD if src == "td" else TT)(idx), size)
        set_char(f"guest.{g['id']}", file, size, anims)
    for e in read_csv("enemies"):
        size = int(e.get("sprite_size") or 16)
        src, ref = ENEMY_SRC[e["id"]]
        if src == "slime":
            file, anims = build_slime(f"enemy_{e['id']}", ref, size)
        else:
            file, anims = build_char(f"enemy_{e['id']}", TD(ref), size)
        set_char(f"enemy.{e['id']}", file, size, anims)
    for s in read_csv("spirits"):
        file, anims = build_char(f"npc_{s['id']}", TD(NPC_TILE[s["id"]]), 32)
        set_char(f"npc.{s['id']}", file, 32, anims)
        illust_sources[s["id"]] = fit(scale(TD(NPC_TILE[s["id"]]), 2), 32)
    file, anims = build_char("player", TD(PLAYER_TILE), 32)
    set_char("char.player", file, 32, anims)
    for i, (ident, sprite) in enumerate(sorted(illust_sources.items())):
        key = f"illust.{ident}"
        if key in rows:
            rows[key].update(file=build_illust(f"illust_{ident}", sprite, i), frame_w="0", frame_h="0", anims="")
    for room in read_csv("rooms"):
        key = f"room.{room['id']}"
        if key in rows:
            rows[key].update(file=build_room(room["id"]), frame_w="0", frame_h="0", anims="")
    build_regions(read_csv("regions"), rows)
    build_props(rows)
    build_ui(rows)

    with open(MANIFEST, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(manifest)
    print(f"[import_free_packs] {len(list(OUT.glob('*.png')))}개 시트 생성 -> {OUT.relative_to(ROOT)}, 매니페스트 {len(manifest)}행 갱신")
    return 0


if __name__ == "__main__":
    sys.exit(main())
