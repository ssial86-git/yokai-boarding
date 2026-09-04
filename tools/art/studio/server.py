#!/usr/bin/env python3
"""웹 Asset Studio 로컬 서버 (docs/02 아트 트랙 · 2026-09-04).

브라우저(index.html)가 프로젝트 폴더를 읽고 쓰려면 로컬 서버가 필요하다. 이 서버는
  GET  /                      → tools/art/studio/index.html (앱)
  GET  /repo/<path>           → 저장소 파일 (assets/, data/ 등) 읽기 전용
  GET  /api/state             → 매니페스트·콘텐츠 CSV·에셋 목록(크기)·팔레트·튜닝 한 번에
  POST /api/manifest          → {rows:[...]} 를 data/csv/art_assets.csv 에 쓰고 build_resources.py 실행
  POST /api/upload            → {name, folder(pixel|illust), data(base64 png), source, license, ai} → assets/art/<folder>/<name> 저장 + docs/asset_licenses.md 에 한 줄
  POST /api/validate          → tools/art/validate_assets.py 실행 결과
를 제공한다. 외부 공개용이 아니라 127.0.0.1 에만 묶는다.

사용: python tools/art/studio/server.py [--port 8765]  → http://127.0.0.1:8765
"""
from __future__ import annotations

import argparse
import base64
import csv
import json
import subprocess
import sys
import datetime
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[3]
STUDIO_DIR = Path(__file__).resolve().parent
CSV_DIR = ROOT / "data" / "csv"
ASSET_DIRS = [ROOT / "assets" / "art" / "pixel", ROOT / "assets" / "art" / "illust", ROOT / "assets" / "art_generated"]
LICENSES = ROOT / "docs" / "asset_licenses.md"
sys.path.insert(0, str(ROOT / "tools" / "art"))
import manifest_sync  # noqa: E402

CONTENT_CSVS = ["yokai", "guest_species", "rooms", "regions", "enemies", "spirits", "materials", "items"]

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def read_csv(name: str) -> list[dict[str, str]]:
    path = CSV_DIR / f"{name}.csv"
    if not path.exists():
        return []
    with path.open(encoding="utf-8-sig", newline="") as fh:
        return [r for r in csv.DictReader(fh) if any((v or "").strip() for v in r.values())]


def tuning_dict() -> dict[str, str]:
    return {r["key"]: r["value"] for r in read_csv("tuning")}


def palette() -> list[str]:
    path = ROOT / "data" / "palette.hex"
    if not path.exists():
        return []
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith(";")]


def asset_list() -> list[dict]:
    try:
        from PIL import Image
    except ImportError:
        Image = None
    result = []
    for directory in ASSET_DIRS:
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*.png")):
            entry = {"path": "res://" + path.relative_to(ROOT).as_posix(), "name": path.name, "w": 0, "h": 0}
            if Image is not None:
                with Image.open(path) as img:
                    entry["w"], entry["h"] = img.size
            result.append(entry)
    return result


def run_tool(args: list[str]) -> dict:
    proc = subprocess.run([sys.executable, *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return {"code": proc.returncode, "stdout": proc.stdout[-4000:], "stderr": proc.stderr[-4000:]}


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:  # 조용히
        pass

    def _json(self, payload: dict, status: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _file(self, path: Path) -> None:
        if not path.exists() or not path.is_file():
            self.send_error(404)
            return
        ctype = "text/html; charset=utf-8" if path.suffix == ".html" else (
            "application/javascript" if path.suffix == ".js" else ("image/png" if path.suffix == ".png" else "text/plain; charset=utf-8"))
        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        url = urlparse(self.path)
        route = unquote(url.path)
        if route in ("/", "/index.html"):
            return self._file(STUDIO_DIR / "index.html")
        if route.startswith("/repo/"):
            target = (ROOT / route[len("/repo/"):]).resolve()
            if ROOT not in target.parents and target != ROOT:
                return self.send_error(403)
            return self._file(target)
        if route == "/api/state":
            return self._json({
                "manifest": manifest_sync.load_manifest(),
                "csv": {name: read_csv(name) for name in CONTENT_CSVS},
                "tuning": tuning_dict(),
                "palette": palette(),
                "assets": asset_list(),
                "wanted_keys": manifest_sync.wanted_keys(),
            })
        return self._file(STUDIO_DIR / route.lstrip("/"))

    def do_POST(self) -> None:
        route = urlparse(self.path).path
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
        if route == "/api/manifest":
            rows = payload.get("rows", [])
            manifest_sync.save_manifest(rows)
            synced, added, removed = manifest_sync.sync(False)
            manifest_sync.save_manifest(synced)
            build = run_tool(["tools/data/build_resources.py"])
            return self._json({"saved": len(synced), "added": added, "build": build})
        if route == "/api/upload":
            name = str(payload.get("name", "")).strip()
            folder = payload.get("folder", "pixel")
            if folder not in ("pixel", "illust") or not name.endswith(".png") or "/" in name or "\\" in name:
                return self._json({"error": "이름은 <snake_case>.png, folder 는 pixel|illust"}, 400)
            target = ROOT / "assets" / "art" / folder / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(base64.b64decode(payload.get("data", "")))
            self._append_license(target, payload)
            return self._json({"path": "res://" + target.relative_to(ROOT).as_posix()})
        if route == "/api/validate":
            return self._json(run_tool(["tools/art/validate_assets.py"]))
        return self.send_error(404)

    def _append_license(self, target: Path, payload: dict) -> None:
        today = datetime.date.today().isoformat()
        line = "| `{}` | {} | {} | {} | {} | {} | {} |\n".format(
            target.relative_to(ROOT).as_posix(), payload.get("kind", "그림"), payload.get("source", "미기재"),
            payload.get("license", "미기재"), today, "예" if payload.get("ai") else "아니오", payload.get("note", "Asset Studio 업로드"))
        with LICENSES.open("a", encoding="utf-8") as fh:
            fh.write(line)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="웹 Asset Studio 서버")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args(argv)
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"[studio] http://127.0.0.1:{args.port}  (Ctrl+C 로 종료)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
