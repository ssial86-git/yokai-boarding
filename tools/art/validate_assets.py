#!/usr/bin/env python3
"""아트 규격 검증 (CLAUDE.md 5.6, docs/02).

트랙 P (픽셀): assets/art/pixel/**, assets/art_generated/**
  - 가로·세로가 16px 격자의 배수
  - 캐릭터 파일(yokai_*, guest_*)은 프레임 높이가 32 또는 16 (뜨내기 소형종)
  - 불투명 픽셀 색이 data/palette.hex 안에 있어야 함 (--no-palette 로 끔)
트랙 I (일러스트): assets/art/illust/**
  - 정확히 1024×1024
공통:
  - PNG 만 허용, 파일명은 소문자 snake_case (^[a-z0-9_]+\\.png$)

종료 코드: 0 통과 / 1 위반. 사용: python tools/art/validate_assets.py [--no-palette]
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from PIL import Image

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
PALETTE_PATH = ROOT / "data" / "palette.hex"
PIXEL_DIRS = [ROOT / "assets" / "art" / "pixel", ROOT / "assets" / "art_generated"]
ILLUST_DIRS = [ROOT / "assets" / "art" / "illust"]

GRID = 16
ILLUST_SIZE = 1024
CHARACTER_FRAME_SIZES = {32, 16}
CHARACTER_PREFIXES = ("yokai_", "guest_")
NAME_PATTERN = re.compile(r"^[a-z0-9_]+\.png$")
ALPHA_OPAQUE_MIN = 1


def load_palette(path: Path) -> set[tuple[int, int, int]]:
    colors: set[tuple[int, int, int]] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        if not re.fullmatch(r"[0-9a-fA-F]{6}", line):
            raise ValueError(f"palette.hex 형식 오류: {raw!r}")
        colors.add((int(line[0:2], 16), int(line[2:4], 16), int(line[4:6], 16)))
    return colors


def iter_images(dirs: list[Path]) -> list[Path]:
    files: list[Path] = []
    for base in dirs:
        if base.exists():
            files.extend(
                p for p in base.rglob("*")
                if p.is_file() and p.name != ".gitkeep" and p.suffix.lower() != ".import"
            )
    return sorted(files)


def check_common(path: Path, errors: list[str]) -> bool:
    if not NAME_PATTERN.match(path.name):
        errors.append(f"{path.relative_to(ROOT)}: 파일명 규칙 위반 (소문자 snake_case .png)")
        return False
    return True


def check_pixel(path: Path, palette: set[tuple[int, int, int]] | None, errors: list[str]) -> None:
    with Image.open(path) as img:
        w, h = img.size
        if w % GRID or h % GRID:
            errors.append(f"{path.relative_to(ROOT)}: {w}x{h} 는 {GRID}px 격자 배수가 아님")
        if path.name.startswith(CHARACTER_PREFIXES) and h not in CHARACTER_FRAME_SIZES:
            errors.append(
                f"{path.relative_to(ROOT)}: 캐릭터 프레임 높이 {h} — 허용 {sorted(CHARACTER_FRAME_SIZES)}"
            )
        if palette is None:
            return
        data = img.convert("RGBA").tobytes()
        offenders: set[tuple[int, int, int]] = set()
        for i in range(0, len(data), 4):
            r, g, b, a = data[i], data[i + 1], data[i + 2], data[i + 3]
            if a >= ALPHA_OPAQUE_MIN and (r, g, b) not in palette:
                offenders.add((r, g, b))
                if len(offenders) >= 5:
                    break
        if offenders:
            sample = ", ".join(f"#{r:02x}{g:02x}{b:02x}" for r, g, b in sorted(offenders))
            errors.append(f"{path.relative_to(ROOT)}: 팔레트 밖 색상 {sample}")


def check_illust(path: Path, errors: list[str]) -> None:
    with Image.open(path) as img:
        w, h = img.size
        if (w, h) != (ILLUST_SIZE, ILLUST_SIZE):
            errors.append(f"{path.relative_to(ROOT)}: {w}x{h} — 일러스트 원본은 {ILLUST_SIZE}x{ILLUST_SIZE}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="아트 규격 검증")
    parser.add_argument("--no-palette", action="store_true", help="팔레트 준수 검사를 생략")
    args = parser.parse_args(argv)

    palette = None if args.no_palette else load_palette(PALETTE_PATH)
    errors: list[str] = []
    pixel_files = iter_images(PIXEL_DIRS)
    illust_files = iter_images(ILLUST_DIRS)

    checked = 0
    for path in pixel_files:
        if check_common(path, errors):
            check_pixel(path, palette, errors)
            checked += 1
    for path in illust_files:
        if check_common(path, errors):
            check_illust(path, errors)
            checked += 1

    if errors:
        print(f"[validate_assets] 위반 {len(errors)}건:", file=sys.stderr)
        for line in errors:
            print("  - " + line, file=sys.stderr)
        return 1
    print(f"[validate_assets] 통과: 픽셀 {len(pixel_files)}개, 일러스트 {len(illust_files)}개 (검사 {checked})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
