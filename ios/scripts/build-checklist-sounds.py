#!/usr/bin/env python3
"""Generate the app's original, short UI cues (48 kHz, mono, PCM16)."""
import io
import math
from pathlib import Path
import struct
import sys
import wave

RATE = 48000
ROOT = Path(__file__).resolve().parents[1] / "Xunju/Resources/ChecklistSounds"


def samples(kind):
    duration = 0.29 if kind == "problem" else 0.34
    for index in range(round(RATE * duration)):
        time = index / RATE
        if kind == "problem":
            start = 0 if time < 0.145 else 0.145
            local = time - start
            envelope = max(0, min(1, local / 0.008, (0.105 - local) / 0.018))
            frequency = 440 if start == 0 else 370
            tone = math.sin(2 * math.pi * frequency * local)
            tone += 0.15 * math.sin(4 * math.pi * frequency * local)
            value = 0.23 * envelope * tone
        else:
            envelope = min(1, time / 0.003) * math.exp(-time / 0.075)
            envelope *= max(0, min(1, (duration - time) / 0.025))
            tone = math.sin(2 * math.pi * 1568 * time)
            tone += 0.26 * math.sin(2 * math.pi * 3136 * time) * math.exp(-time / 0.035)
            value = 0.24 * envelope * tone
        yield round(max(-1, min(1, value)) * 32767)


for kind in ("problem", "positive"):
    output = io.BytesIO()
    with wave.open(output, "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(b"".join(struct.pack("<h", value) for value in samples(kind)))
    path = ROOT / f"checklist-{kind}.wav"
    if "--check" in sys.argv:
        assert path.read_bytes() == output.getvalue(), f"Stale audio: {path}"
    else:
        ROOT.mkdir(parents=True, exist_ok=True)
        path.write_bytes(output.getvalue())
    print(f"{kind}: {len(output.getvalue())} bytes")
