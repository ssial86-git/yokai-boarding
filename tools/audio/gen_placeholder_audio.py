#!/usr/bin/env python3
"""임시 효과음 합성기: 외부 에셋 없이 표준 라이브러리만으로 짧은 WAV 를 만든다.

- 출력: assets/audio/generated/<id>.wav (16bit mono 22050Hz). 절차적 생성물이라 라이선스가 없다.
- data/csv/sfx.csv 의 file 컬럼과 이름을 맞춘다. 정식 사운드는 docs/02 소싱 전략에 따라 교체한다.
사용: python tools/audio/gen_placeholder_audio.py
"""
from __future__ import annotations

import math
import random
import struct
import sys
import wave
from pathlib import Path

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "audio" / "generated"
RATE = 22050


def tone(freq: float, seconds: float, volume: float = 0.6, decay: float = 8.0, shape: str = "sine") -> list[float]:
    samples = []
    n = int(RATE * seconds)
    for i in range(n):
        t = i / RATE
        env = math.exp(-decay * t)
        phase = 2 * math.pi * freq * t
        if shape == "square":
            value = 1.0 if math.sin(phase) >= 0 else -1.0
        elif shape == "tri":
            value = 2 / math.pi * math.asin(math.sin(phase))
        else:
            value = math.sin(phase)
        samples.append(value * env * volume)
    return samples


def sweep(f0: float, f1: float, seconds: float, volume: float = 0.6, decay: float = 10.0) -> list[float]:
    samples = []
    n = int(RATE * seconds)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        freq = f0 + (f1 - f0) * (i / n)
        phase += 2 * math.pi * freq / RATE
        samples.append(math.sin(phase) * math.exp(-decay * t) * volume)
    return samples


def noise(seconds: float, volume: float = 0.3, seed: int = 1, smooth: int = 4) -> list[float]:
    rng = random.Random(seed)
    raw = [rng.uniform(-1, 1) for _ in range(int(RATE * seconds))]
    out = []
    acc = 0.0
    for v in raw:  # 간단한 저역 통과로 빗소리 질감
        acc += (v - acc) / smooth
        out.append(acc * volume)
    return out


def concat(*parts: list[float]) -> list[float]:
    result: list[float] = []
    for part in parts:
        result.extend(part)
    return result


def silence(seconds: float) -> list[float]:
    return [0.0] * int(RATE * seconds)


def write(name: str, samples: list[float]) -> Path:
    path = OUT_DIR / name
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
        wav.writeframes(frames)
    return path


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    written = [
        write("click.wav", tone(880, 0.05, 0.5, 40)),
        write("drop.wav", sweep(320, 120, 0.12, 0.6, 12)),
        write("build.wav", concat(tone(392, 0.09, 0.5, 12, "tri"), tone(523, 0.09, 0.5, 12, "tri"), tone(659, 0.16, 0.5, 8, "tri"))),
        write("knock.wav", concat(sweep(160, 70, 0.08, 0.8, 25), silence(0.12), sweep(160, 70, 0.08, 0.8, 25))),
        write("blip.wav", tone(1200, 0.035, 0.35, 50, "square")),
        write("chime.wav", concat(tone(659, 0.12, 0.4, 6), tone(880, 0.12, 0.4, 6), tone(1319, 0.3, 0.4, 4))),
        write("coin.wav", concat(tone(1568, 0.06, 0.4, 20), tone(2093, 0.14, 0.4, 10))),
        write("error.wav", concat(tone(220, 0.08, 0.5, 15, "square"), tone(180, 0.14, 0.5, 10, "square"))),
        write("rain_loop.wav", noise(2.0, 0.35, seed=7, smooth=3)),
    ]
    for path in written:
        print(f"  {path.relative_to(ROOT)}")
    print(f"[gen_placeholder_audio] {len(written)}개 생성")
    return 0


if __name__ == "__main__":
    sys.exit(main())
