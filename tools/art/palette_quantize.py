#!/usr/bin/env python3
"""팔레트 양자화: 이미지의 불투명 픽셀 색을 data/palette.hex 의 가장 가까운 색으로 바꾼다.

validate_assets.py 가 픽셀 트랙 파일에 공통 팔레트를 강제하므로(CLAUDE.md 5.6), 에셋팩·AI 산출물은
이 도구를 거쳐 assets/art_generated/ 로 들어간다. 원본(assets/art/packs/)은 손대지 않는다.

- 알파는 128 기준으로 0/255 로 이진화한다 (픽셀 아트의 반투명 가장자리 제거).
- 거리는 사람 눈 가중 RGB (r 0.30, g 0.59, b 0.11 의 제곱근 가중) — 저채도 팔레트에서 색상 이동을 줄인다.
- `--tint RRGGBB[:strength]` 로 양자화 전에 색을 곱해 마계·밤 변형을 만든다.

사용: python tools/art/palette_quantize.py <in.png> <out.png> [--tint 6b6b8a:0.7] [--palette data/palette.hex]
"""
from __future__ import annotations

import argparse
import re
import sys
from functools import lru_cache
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PALETTE_PATH = ROOT / "data" / "palette.hex"
ALPHA_CUT = 128
WEIGHTS = (0.30, 0.59, 0.11)


def load_palette(path: Path = PALETTE_PATH) -> list[tuple[int, int, int]]:
    colors: list[tuple[int, int, int]] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        if not re.fullmatch(r"[0-9a-fA-F]{6}", line):
            raise ValueError(f"palette.hex 형식 오류: {raw!r}")
        colors.append((int(line[0:2], 16), int(line[2:4], 16), int(line[4:6], 16)))
    return colors


def parse_hex(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


def nearest_factory(palette: list[tuple[int, int, int]]):
    @lru_cache(maxsize=None)
    def nearest(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
        best = palette[0]
        best_d = float("inf")
        for c in palette:
            d = (
                WEIGHTS[0] * (c[0] - rgb[0]) ** 2
                + WEIGHTS[1] * (c[1] - rgb[1]) ** 2
                + WEIGHTS[2] * (c[2] - rgb[2]) ** 2
            )
            if d < best_d:
                best_d = d
                best = c
        return best

    return nearest


def quantize(
    img: Image.Image,
    palette: list[tuple[int, int, int]] | None = None,
    tint: tuple[int, int, int] | None = None,
    tint_strength: float = 1.0,
) -> Image.Image:
    palette = palette or load_palette()
    nearest = nearest_factory(palette)
    src = img.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    src_px = src.load()
    out_px = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src_px[x, y]
            if a < ALPHA_CUT:
                continue
            if tint is not None:
                r = int(r * (1 - tint_strength) + r * tint[0] / 255 * tint_strength)
                g = int(g * (1 - tint_strength) + g * tint[1] / 255 * tint_strength)
                b = int(b * (1 - tint_strength) + b * tint[2] / 255 * tint_strength)
            out_px[x, y] = nearest((r, g, b)) + (255,)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("src")
    parser.add_argument("dst")
    parser.add_argument("--palette", default=str(PALETTE_PATH))
    parser.add_argument("--tint", default="", help="RRGGBB[:strength]")
    args = parser.parse_args()
    tint = None
    strength = 1.0
    if args.tint:
        head, _, tail = args.tint.partition(":")
        tint = parse_hex(head)
        strength = float(tail) if tail else 1.0
    with Image.open(args.src) as img:
        result = quantize(img, load_palette(Path(args.palette)), tint, strength)
    Path(args.dst).parent.mkdir(parents=True, exist_ok=True)
    result.save(args.dst)
    print(f"[palette_quantize] {args.src} -> {args.dst} ({result.width}x{result.height})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
