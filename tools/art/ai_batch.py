#!/usr/bin/env python3
"""OpenAI 이미지 API(gpt-image-1) 로 아트 매니페스트 키를 채운다.

흐름: tools/art/ai_prompts.py 의 항목 → 컨셉 레퍼런스(assets/art/concepts) + 프롬프트로 생성
     → 원본은 assets/art/ai_raw/<key>.webp (재현·후보정용) → 규격 축소·팔레트 양자화 → assets/art_generated/ai/
     → art_assets.csv 의 그 키에 꽂는다 (빌드는 따로: python tools/data/build_resources.py).
일러스트(illust.*)는 팔레트 양자화 없이 1024 정사각으로 assets/art/illust/ai_<id>.png.

키: 환경변수 OPENAI_API_KEY (없으면 Windows 사용자 환경변수에서 읽는다). 키를 코드·로그에 남기지 않는다.
비용: quality medium 1024x1024 ≈ $0.04/장. --dry-run 으로 장수를 먼저 센다. 이미 ai_raw 에 있는 키는 건너뛴다 (--force 로 재생성).

사용:
  python tools/art/ai_batch.py --dry-run
  python tools/art/ai_batch.py --kind sprite --keys char.player,char.y01_ttukttagi
  python tools/art/ai_batch.py --kind room
  python tools/art/ai_batch.py            # 전부
AI 산출물은 docs/asset_licenses.md 에 "AI 생성 (OpenAI gpt-image-1)" 으로 기록되어 있다 (CLAUDE.md 8절).
"""
from __future__ import annotations

import argparse
import base64
import csv
import os
import sys
import time
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ai_prompts as P  # noqa: E402
import import_free_packs as ifp  # noqa: E402
from palette_quantize import load_palette, quantize  # noqa: E402

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
CONCEPTS = ROOT / "assets" / "art" / "concepts"
RAW = ROOT / "assets" / "art" / "ai_raw"
OUT = ROOT / "assets" / "art_generated" / "ai"
ILLUST_OUT = ROOT / "assets" / "art" / "illust"
MANIFEST = ROOT / "data" / "csv" / "art_assets.csv"
RES_OUT = "res://assets/art_generated/ai/"
RES_ILLUST = "res://assets/art/illust/"
MODEL = "gpt-image-1"
PALETTE = load_palette()
ALPHA_CUT = 100


# ---------------------------------------------------------------- API
def load_key() -> None:
    if os.environ.get("OPENAI_API_KEY"):
        return
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
            os.environ["OPENAI_API_KEY"] = winreg.QueryValueEx(k, "OPENAI_API_KEY")[0]
    except OSError:
        raise SystemExit("OPENAI_API_KEY 가 없다. 사용자 환경변수로 등록할 것")


def generate(client, prompt: str, refs: list[str], size: str, transparent: bool, quality: str) -> Image.Image:
    kwargs = dict(model=MODEL, prompt=prompt, size=size, quality=quality, n=1)
    if transparent:
        kwargs.update(background="transparent", output_format="png")
    for attempt in range(3):
        try:
            if refs:
                files = [open(CONCEPTS / r, "rb") for r in refs]
                try:
                    result = client.images.edit(image=files, **kwargs)
                finally:
                    for f in files:
                        f.close()
            else:
                result = client.images.generate(**kwargs)
            data = base64.b64decode(result.data[0].b64_json)
            from io import BytesIO

            return Image.open(BytesIO(data)).convert("RGBA")
        except Exception as e:  # 429/5xx 는 잠시 쉬고 재시도
            print(f"    재시도 {attempt + 1}: {type(e).__name__} {str(e)[:120]}")
            time.sleep(5 * (attempt + 1))
    raise RuntimeError("생성 실패")


# ---------------------------------------------------------------- 후처리
def strip_background(im: Image.Image) -> Image.Image:
    """투명 출력이 안 됐을 때: 네 귀퉁이 색과 가까운, 테두리에 연결된 영역을 투명으로 (flood fill)."""
    if im.getextrema()[3][0] < 255:  # 이미 알파가 있다
        return im
    px = im.load()
    w, h = im.size
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    seen = bytearray(w * h)
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    tol = 40
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        r, g, b, _ = px[x, y]
        if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > tol * 3:
            continue
        seen[y * w + x] = 1
        px[x, y] = (r, g, b, 0)
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def crop_aspect(im: Image.Image, w: int, h: int, anchor: str = "center") -> Image.Image:
    target = w / h
    if abs(im.width / im.height - target) < 0.01:
        return im
    if im.width / im.height > target:
        nw = int(im.height * target)
        x0 = (im.width - nw) // 2
        return im.crop((x0, 0, x0 + nw, im.height))
    nh = int(im.width / target)
    y0 = {"top": 0, "bottom": im.height - nh}.get(anchor, (im.height - nh) // 2)
    return im.crop((0, y0, im.width, y0 + nh))


def content_box(im: Image.Image) -> Image.Image:
    box = im.getbbox()
    return im.crop(box) if box else im


def shrink(im: Image.Image, w: int, h: int) -> Image.Image:
    small = im.resize((w, h), Image.BOX)
    # 반투명 가장자리 정리
    px = small.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= ALPHA_CUT else 0)
    return quantize(small, PALETTE)


def make_tileable(im: Image.Image, overlap_ratio: float = 0.12) -> Image.Image:
    """가로 반복용: 왼쪽 끝을 오른쪽 끝에 교차 혼합."""
    ov = max(2, int(im.width * overlap_ratio))
    core = im.crop((ov, 0, im.width, im.height))
    left = im.crop((0, 0, ov, im.height)).convert("RGBA")
    right = core.crop((core.width - ov, 0, core.width, core.height)).convert("RGBA")
    blended = Image.new("RGBA", (ov, im.height))
    for x in range(ov):
        t = (x + 1) / (ov + 1)
        col = Image.blend(right.crop((x, 0, x + 1, im.height)), left.crop((x, 0, x + 1, im.height)), t)
        blended.paste(col, (x, 0))
    core.paste(blended, (core.width - ov, 0))
    return core


def sprite_frame(im: Image.Image, size: int) -> Image.Image:
    im = content_box(strip_background(im))
    # 정사각 캔버스에 발 아래 가운데 (큰 쪽을 size 에 맞춘다)
    scale = size / max(im.width, im.height)
    small = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.BOX)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(small, ((size - small.width) // 2, size - small.height))
    px = canvas.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= ALPHA_CUT else 0)
    return quantize(canvas, PALETTE)


# ---------------------------------------------------------------- 작업 목록
def jobs(kind_filter: str, keys_filter: set[str]) -> list[dict]:
    out: list[dict] = []

    def add(**j) -> None:
        if kind_filter and j["kind"] != kind_filter:
            return
        if keys_filter and j["key"] not in keys_filter:
            return
        out.append(j)

    for key, desc in P.CHARACTERS.items():
        add(key=key, kind="sprite", prompt=P.STYLE_SPRITE + desc, refs=[P.SHEET, P.HOUSE], size="1024x1024", transparent=True)
    for key, desc in P.ROOMS.items():
        add(key=key, kind="room", prompt=P.STYLE_ROOM + desc, refs=[P.HOUSE, P.KITCHEN], size="1536x1024", transparent=False)
    for key, desc in P.ILLUSTS.items():
        add(key=key, kind="illust", prompt=P.STYLE_ILLUST + desc, refs=[P.SHEET, P.DINNER], size="1024x1024", transparent=False)
    for rid, (sky, far, ground) in P.REGIONS.items():
        add(key=f"region.{rid}.sky", kind="sky", prompt=P.STYLE_LAYER + "A wide sky-only background: " + sky + ". Nothing but sky, no horizon, no ground.", refs=[P.DINNER], size="1536x1024", transparent=False)
        add(key=f"region.{rid}.far", kind="far", prompt=P.STYLE_LAYER + "A wide distant-background layer for a side-scrolling game: " + far + ". The scenery sits on the bottom edge and everything above the skyline is TRANSPARENT. Seamless horizontally: the left and right edges must continue into each other.", refs=[P.DINNER, P.HOUSE], size="1536x1024", transparent=True)
        add(key=f"region.{rid}.ground", kind="ground", prompt=P.STYLE_LAYER + "A square ground tile for a side-view game: " + ground + ". The ground surface line runs horizontally through the exact middle of the square; below it is earth, above it is TRANSPARENT except for the surface edge. Seamless horizontally.", refs=[P.HOUSE], size="1024x1024", transparent=True)
    for key, (fsize, frames, anims) in P.PROPS.items():
        for i, desc in enumerate(frames):
            add(key=key, kind="prop", frame=i, frame_count=len(frames), fsize=fsize, anims=anims, prompt=P.STYLE_LAYER + desc + ". Single object centered, transparent background, no ground shadow.", refs=[P.HOUSE], size="1536x1024" if fsize[0] > fsize[1] * 2 else "1024x1024", transparent=True)
    for key, (fsize, desc) in P.STRIPS.items():
        add(key=key, kind="strip", fsize=fsize, prompt=P.STYLE_LAYER + desc + ".", refs=[P.HOUSE], size="1536x1024" if fsize[0] > fsize[1] else "1024x1536", transparent=True)
    return out


def raw_path(job: dict) -> Path:
    suffix = f"_{job['frame']}" if "frame" in job else ""
    return RAW / f"{job['key'].replace('.', '_')}{suffix}.webp"


# ---------------------------------------------------------------- 키별 완성
def finish(job: dict, rows: dict[str, dict[str, str]], raw_frames: list[Image.Image]) -> None:
    key = job["key"]
    kind = job["kind"]
    name = key.replace(".", "_")
    row = rows.get(key)
    if row is None:
        print(f"    매니페스트에 키 없음: {key}")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    if kind == "sprite":
        size = int(row.get("frame_w") or 32) or 32
        base = sprite_frame(raw_frames[0], size)
        sheet = ifp.strip(ifp.char_frames(base))
        sheet.save(OUT / f"{name}.png")
        row.update(file=RES_OUT + f"{name}.png", frame_w=str(size), frame_h=str(size), anims=P.CHAR_ANIMS)
    elif kind == "room":
        im = crop_aspect(raw_frames[0], 64, 48)
        shrink(im, 64, 48).save(OUT / f"{name}.png")
        row.update(file=RES_OUT + f"{name}.png", frame_w="0", frame_h="0", anims="")
    elif kind == "illust":
        ILLUST_OUT.mkdir(parents=True, exist_ok=True)
        im = crop_aspect(raw_frames[0], 1, 1).resize((1024, 1024), Image.LANCZOS).convert("RGB")
        # 256색 팔레트 PNG: 대화창은 96px 로 축소 표시라 화질 손실이 안 보이고 용량은 1/5
        im.quantize(256, method=Image.Quantize.MEDIANCUT).save(ILLUST_OUT / f"ai_{name}.png", optimize=True)
        row.update(file=RES_ILLUST + f"ai_{name}.png", frame_w="0", frame_h="0", anims="")
    elif kind == "sky":
        rid = key.split(".")[1]
        tint = P.SKY_TINT.get(rid)
        im = crop_aspect(raw_frames[0], 320, 192).resize((320, 192), Image.BOX)
        if tint:
            from palette_quantize import parse_hex
            im = quantize(im, PALETTE, parse_hex(tint[0]), tint[1])
        else:
            im = quantize(im, PALETTE)
        im.save(OUT / f"{name}.png")
        row.update(file=RES_OUT + f"{name}.png", frame_w="0", frame_h="0", anims="", repeat="false")
    elif kind == "far":
        im = strip_background(raw_frames[0])
        box = im.getbbox() or (0, 0, im.width, im.height)
        im = im.crop((0, box[1], im.width, im.height))  # 위 빈 부분 제거, 아래는 그대로
        im = crop_aspect(im, 544, 160, anchor="bottom")
        shrink(make_tileable(im), 544, 160).save(OUT / f"{name}.png")
        row.update(file=RES_OUT + f"{name}.png", frame_w="0", frame_h="0", anims="", repeat="true")
    elif kind == "ground":
        im = strip_background(raw_frames[0])
        shrink(make_tileable(im), 32, 32).save(OUT / f"{name}.png")
        row.update(file=RES_OUT + f"{name}.png", frame_w="0", frame_h="0", anims="", repeat="true")
    elif kind == "prop":
        fw, fh = job["fsize"]
        frames = []
        for raw in raw_frames:
            im = content_box(strip_background(raw))
            scale = min(fw / im.width, fh / im.height)
            small = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.BOX)
            canvas = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
            canvas.alpha_composite(small, ((fw - small.width) // 2, fh - small.height))
            frames.append(shrink(canvas, fw, fh))
        if key == "prop.water" and len(frames) == 1:
            # 물결 2프레임: 같은 그림을 8px 밀어 만든다 (AI 가 프레임 간 일관성을 못 지킨다)
            f0 = frames[0]
            f1 = Image.new("RGBA", f0.size)
            f1.paste(f0.crop((8, 0, fw, fh)), (0, 0))
            f1.paste(f0.crop((0, 0, 8, fh)), (fw - 8, 0))
            frames.append(f1)
        ifp.strip(frames).save(OUT / f"{name}.png")
        row.update(file=RES_OUT + f"{name}.png", frame_w=str(fw), frame_h=str(fh), anims=job["anims"])
    elif kind == "strip":
        fw, fh = job["fsize"]
        im = content_box(strip_background(raw_frames[0]))
        im = crop_aspect(im, fw, fh)
        if fw > fh:
            im = make_tileable(im)
        shrink(im, fw, fh).save(OUT / f"{name}.png")
        row.update(file=RES_OUT + f"{name}.png", frame_w=str(fw), frame_h=str(fh), anims="")
    print(f"    -> {row['file']}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--kind", default="", help="sprite/room/illust/sky/far/ground/prop/strip")
    parser.add_argument("--keys", default="", help="쉼표로 구분한 키 목록")
    parser.add_argument("--quality", default="medium", choices=["low", "medium", "high"])
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true", help="ai_raw 에 있어도 다시 생성")
    parser.add_argument("--no-generate", action="store_true", help="생성 없이 ai_raw 의 원본만 다시 후처리")
    args = parser.parse_args()

    keys = {k.strip() for k in args.keys.split(",") if k.strip()}
    todo = jobs(args.kind, keys)
    need = [j for j in todo if args.force or not raw_path(j).exists()]
    print(f"[ai_batch] 작업 {len(todo)} (생성 필요 {len(need)}) · quality={args.quality} · 예상 비용 ≈ ${len(need) * {'low': 0.011, 'medium': 0.042, 'high': 0.167}[args.quality]:.2f}")
    if args.dry_run:
        for j in todo:
            print(f"  {'GEN ' if j in need else 'skip'} {j['key']}{'#' + str(j['frame']) if 'frame' in j else ''} [{j['kind']}] {j['size']}")
        return 0

    client = None
    if not args.no_generate and need:
        load_key()
        from openai import OpenAI

        client = OpenAI()
    RAW.mkdir(parents=True, exist_ok=True)

    with open(MANIFEST, encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        fields = list(reader.fieldnames or [])
        manifest = list(reader)
    rows = {r["key"]: r for r in manifest}

    # 키별로 프레임을 모아 완성한다
    by_key: dict[str, list[dict]] = {}
    for j in todo:
        by_key.setdefault(j["key"], []).append(j)
    done = 0
    for key, group in by_key.items():
        print(f"[{done + 1}/{len(by_key)}] {key}")
        raws: list[Image.Image] = []
        ok = True
        for j in group:
            p = raw_path(j)
            if (args.force or not p.exists()) and not args.no_generate:
                try:
                    im = generate(client, j["prompt"], j["refs"], j["size"], j["transparent"], args.quality)
                except Exception as e:
                    print(f"    실패: {e}")
                    ok = False
                    break
                im.save(p, "WEBP", quality=90, lossless=j["transparent"])
            if not p.exists():
                ok = False
                break
            raws.append(Image.open(p).convert("RGBA"))
        if ok:
            finish(group[0], rows, raws)
            done += 1
            # 진행 중 중단돼도 매니페스트가 남도록 매번 저장
            with open(MANIFEST, "w", encoding="utf-8", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=fields)
                writer.writeheader()
                writer.writerows(manifest)
    print(f"[ai_batch] 완료 {done}/{len(by_key)} · 다음: python tools/data/build_resources.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
