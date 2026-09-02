#!/usr/bin/env python3
"""임시 스프라이트 생성기: yokai.csv / guest_species.csv / rooms.csv -> assets/art_generated/*.png

- 요괴·손님: sprite_size(32 또는 16) 정사각 색 블록 + 눈 2개 + 2글자 라벨(3x5 도트 폰트, 영문 약자).
  파일명 yokai_<id>.png / guest_<id>.png (validate_assets.py 의 캐릭터 규칙 대상).
- 방: 방 1칸 = 64x48 (16px 격자 4x3 칸) 색 블록 + 테두리 + 영문 약자 라벨. 파일명 room_<id>.png
- 일러스트 자리표시: 요괴·가택신마다 1024x1024 색 블록 + 큰 눈 + 라벨. 파일명 illust_<id>.png (대화창·도감용 임시)
- 모든 색은 data/palette.hex 에서만 고른다 (팔레트 검증 통과 보장).

한글 라벨을 도트로 찍지 않는 이유: 32px 안에 한글 2글자를 판독 가능하게 넣을 수 없어 영문 약자를 쓴다.
사용: python tools/art/gen_placeholder.py
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

from PIL import Image, ImageDraw

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
CSV_DIR = ROOT / "data" / "csv"
OUT_DIR = ROOT / "assets" / "art_generated"
PALETTE_PATH = ROOT / "data" / "palette.hex"

GRID = 16
ROOM_W_CELLS, ROOM_H_CELLS = 4, 3

# 3x5 도트 폰트 (라벨용 영문 대문자·숫자 일부)
FONT: dict[str, list[str]] = {
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"],
    "G": ["011", "100", "101", "101", "011"],
    "I": ["111", "010", "010", "010", "111"],
    "K": ["101", "110", "100", "110", "101"],
    "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "N": ["110", "101", "101", "101", "101"],
    "O": ["111", "101", "101", "101", "111"],
    "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"],
    "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"],
    "W": ["101", "101", "111", "111", "101"],
    "?": ["111", "001", "011", "000", "010"],
}


def load_palette() -> list[tuple[int, int, int]]:
    colors: list[tuple[int, int, int]] = []
    for raw in PALETTE_PATH.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line and not line.startswith(";"):
            colors.append((int(line[0:2], 16), int(line[2:4], 16), int(line[4:6], 16)))
    return colors


PALETTE = load_palette()
DARK = PALETTE[0]  # 1a1620
LIGHT = PALETTE[5]  # ede6dc
OUTLINE = PALETTE[1]  # 2e2733
ROOM_FLOOR = PALETTE[8]  # 8c6247
ROOM_WALL = PALETTE[11]  # f0d9a8
# 요괴 식별색 풀 (팔레트 뒤쪽 10색) — id 순서대로 순환 배정
IDENT_COLORS = PALETTE[22:32]


def read_rows(name: str) -> list[dict[str, str]]:
    with (CSV_DIR / name).open(encoding="utf-8-sig", newline="") as fh:
        return [r for r in csv.DictReader(fh) if any(v.strip() for v in r.values())]


def label_from_id(entity_id: str) -> str:
    # y01_ttukttagi -> TT, g_mongdanggwi -> MO, workshop -> WO
    core = entity_id.split("_", 1)[1] if "_" in entity_id else entity_id
    letters = [c for c in core.upper() if c in FONT]
    return "".join(letters[:2]) or "??"


def draw_text(draw: ImageDraw.ImageDraw, text: str, x: int, y: int, color: tuple[int, int, int]) -> None:
    for ch in text:
        glyph = FONT.get(ch, FONT["?"])
        for row, bits in enumerate(glyph):
            for col, bit in enumerate(bits):
                if bit == "1":
                    draw.point((x + col, y + row), fill=color)
        x += 4


def make_character(size: int, color: tuple[int, int, int], label: str) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    margin = 2 if size >= 32 else 1
    body = (margin, margin + (size // 8), size - 1 - margin, size - 1 - margin)
    draw.rounded_rectangle(body, radius=size // 4, fill=color, outline=OUTLINE)
    eye_y = body[1] + (body[3] - body[1]) // 3
    eye_dx = size // 5
    eye_r = 1 if size >= 32 else 0
    cx = size // 2
    for ex in (cx - eye_dx, cx + eye_dx):
        draw.rectangle((ex - eye_r, eye_y - eye_r, ex + eye_r, eye_y + eye_r), fill=DARK)
    if size >= 32:
        draw_text(draw, label, cx - 3, body[3] - 8, DARK)
    return img


def make_room(color: tuple[int, int, int], label: str) -> Image.Image:
    w, h = ROOM_W_CELLS * GRID, ROOM_H_CELLS * GRID
    img = Image.new("RGBA", (w, h), ROOM_WALL + (255,))
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, w - 1, h - 1), outline=OUTLINE)
    draw.rectangle((0, h - GRID // 2, w - 1, h - 1), fill=ROOM_FLOOR)
    draw.rectangle((GRID, GRID // 2, w - GRID - 1, h - GRID), fill=color, outline=OUTLINE)
    draw_text(draw, label, w // 2 - 3, h // 2 - 4, LIGHT)
    return img


ILLUST_SIZE = 1024


def make_illust(color: tuple[int, int, int], label: str) -> Image.Image:
    img = Image.new("RGBA", (ILLUST_SIZE, ILLUST_SIZE), ROOM_WALL + (255,))
    draw = ImageDraw.Draw(img)
    margin = ILLUST_SIZE // 8
    draw.rounded_rectangle((margin, margin * 2, ILLUST_SIZE - margin, ILLUST_SIZE - margin), radius=ILLUST_SIZE // 5, fill=color, outline=OUTLINE, width=16)
    eye_y = ILLUST_SIZE // 2
    for ex in (ILLUST_SIZE * 3 // 8, ILLUST_SIZE * 5 // 8):
        draw.ellipse((ex - 40, eye_y - 56, ex + 40, eye_y + 56), fill=DARK)
    # 라벨은 3x5 도트 폰트를 32배로 확대
    scale = 32
    x0 = ILLUST_SIZE // 2 - len(label) * 2 * scale
    y0 = ILLUST_SIZE - margin * 2 - 5 * scale
    for ch in label:
        glyph = FONT.get(ch, FONT["?"])
        for row, bits in enumerate(glyph):
            for col, bit in enumerate(bits):
                if bit == "1":
                    draw.rectangle((x0 + col * scale, y0 + row * scale, x0 + (col + 1) * scale - 1, y0 + (row + 1) * scale - 1), fill=DARK)
        x0 += 4 * scale
    return img


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    for i, row in enumerate(read_rows("yokai.csv")):
        img = make_illust(IDENT_COLORS[i % len(IDENT_COLORS)], label_from_id(row["id"]))
        path = OUT_DIR / f"illust_{row['id']}.png"
        img.save(path)
        written.append(path)
    for i, row in enumerate(read_rows("spirits.csv")):
        img = make_illust(IDENT_COLORS[(i + 7) % len(IDENT_COLORS)], label_from_id(row["id"]))
        path = OUT_DIR / f"illust_{row['id']}.png"
        img.save(path)
        written.append(path)

    for i, row in enumerate(read_rows("yokai.csv")):
        color = IDENT_COLORS[i % len(IDENT_COLORS)]
        img = make_character(int(row["sprite_size"]), color, label_from_id(row["id"]))
        path = OUT_DIR / f"yokai_{row['id']}.png"
        img.save(path)
        written.append(path)

    for i, row in enumerate(read_rows("guest_species.csv")):
        color = IDENT_COLORS[(i + 5) % len(IDENT_COLORS)]
        img = make_character(int(row["sprite_size"]), color, label_from_id(row["id"]))
        path = OUT_DIR / f"guest_{row['id']}.png"
        img.save(path)
        written.append(path)

    for i, row in enumerate(read_rows("rooms.csv")):
        color = IDENT_COLORS[(i + 2) % len(IDENT_COLORS)]
        img = make_room(color, label_from_id(row["id"]))
        path = OUT_DIR / f"room_{row['id']}.png"
        img.save(path)
        written.append(path)

    for path in written:
        print(f"  {path.relative_to(ROOT)}")
    print(f"[gen_placeholder] {len(written)}개 생성")
    return 0


if __name__ == "__main__":
    sys.exit(main())
