#!/usr/bin/env python3
"""AI 생성 이미지(ChatGPT 등) → 게임 규격 픽셀 이미지.

생성 모델은 정확한 픽셀 격자를 못 지키므로, 큰 그림을 목표 크기로 상자(box) 축소한 뒤 공통 팔레트로 양자화한다.
결과는 assets/art_generated/ai/ 에 두고, --key 를 주면 art_assets.csv 의 그 키에 바로 꽂는다 (빌드는 따로).

예:
  python tools/art/ai_to_pixel.py shot.png --size 640x360 --name mock_house_day          # 화면 목업 비교용
  python tools/art/ai_to_pixel.py sky.png --size 320x192 --key region.r_yard.sky        # 하늘 레이어로 사용
  python tools/art/ai_to_pixel.py far.png --size 544x160 --key region.r_yard.far --tint 8fb0b8:0.3
  python tools/art/ai_to_pixel.py room.png --size 64x48 --key room.kitchen
  python tools/art/ai_to_pixel.py sheet.png --size 576x32 --key char.y01_ttukttagi --anims "idle:0-3:6;walk:4-9:10"

AI 산출물은 docs/asset_licenses.md 에 "AI 생성" 으로 기록해야 한다 (CLAUDE.md 8절).
"""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from palette_quantize import load_palette, parse_hex, quantize  # noqa: E402

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art_generated" / "ai"
MANIFEST = ROOT / "data" / "csv" / "art_assets.csv"
RES_PREFIX = "res://assets/art_generated/ai/"
GRID = 16


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("src")
    parser.add_argument("--size", required=True, help="WxH (16 배수)")
    parser.add_argument("--name", default="", help="출력 파일명 (기본: 키 또는 원본 이름)")
    parser.add_argument("--key", default="", help="art_assets.csv 키에 꽂기")
    parser.add_argument("--anims", default="", help="키에 쓸 때 애니메이션 구간 (프레임은 정사각 = 높이)")
    parser.add_argument("--tint", default="", help="RRGGBB[:strength]")
    parser.add_argument("--crop", default="", help="축소 전 원본에서 자를 영역 L,T,R,B")
    args = parser.parse_args()

    w, h = (int(v) for v in args.size.lower().split("x"))
    # 격자 규칙은 매니페스트에 꽂는 에셋에만 (화면 목업 640x360 은 비교용이라 예외)
    if args.key and (w % GRID or h % GRID):
        print(f"[ai_to_pixel] {w}x{h} 는 {GRID}px 격자 배수가 아님 — 키에 꽂을 수 없다")
        return 1
    name = args.name or (args.key.replace(".", "_") if args.key else Path(args.src).stem.lower())
    tint, strength = None, 1.0
    if args.tint:
        head, _, tail = args.tint.partition(":")
        tint, strength = parse_hex(head), (float(tail) if tail else 1.0)

    with Image.open(args.src) as img:
        im = img.convert("RGBA")
        if args.crop:
            im = im.crop(tuple(int(v) for v in args.crop.split(",")))
        # 원본 비율이 다르면 목표 비율로 가운데 자르기 (늘리지 않는다)
        target = w / h
        if abs(im.width / im.height - target) > 0.01:
            if im.width / im.height > target:
                nw = int(im.height * target)
                im = im.crop(((im.width - nw) // 2, 0, (im.width - nw) // 2 + nw, im.height))
            else:
                nh = int(im.width / target)
                im = im.crop((0, (im.height - nh) // 2, im.width, (im.height - nh) // 2 + nh))
        small = im.resize((w, h), Image.BOX)
        result = quantize(small, load_palette(), tint, strength)

    OUT.mkdir(parents=True, exist_ok=True)
    dst = OUT / f"{name}.png"
    result.save(dst)
    print(f"[ai_to_pixel] {args.src} -> {dst.relative_to(ROOT)} ({w}x{h})")

    if args.key:
        with open(MANIFEST, encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            fields = list(reader.fieldnames or [])
            rows = list(reader)
        hit = [r for r in rows if r["key"] == args.key]
        if not hit:
            print(f"[ai_to_pixel] 매니페스트에 키가 없음: {args.key} (manifest_sync.py 먼저)")
            return 1
        frame = str(h) if args.anims else "0"
        hit[0].update(file=RES_PREFIX + f"{name}.png", frame_w=frame, frame_h=frame, anims=args.anims)
        with open(MANIFEST, "w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)
        print(f"[ai_to_pixel] {args.key} <- {hit[0]['file']} · 다음: python tools/data/build_resources.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
