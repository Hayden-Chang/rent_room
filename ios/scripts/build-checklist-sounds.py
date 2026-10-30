#!/usr/bin/env python3
"""Generate the problem cue and validate the user-selected success cue (48 kHz, mono, PCM16)."""
import hashlib
import io
import math
from pathlib import Path
import struct
import sys
import wave

RATE = 48000
ROOT = Path(__file__).resolve().parents[1] / "Xunju/Resources/ChecklistSounds"


def samples():
    for index in range(round(RATE * 0.29)):
        time = index / RATE
        start = 0 if time < 0.145 else 0.145
        local = time - start
        envelope = max(0, min(1, local / 0.008, (0.105 - local) / 0.018))
        frequency = 440 if start == 0 else 370
        tone = math.sin(2 * math.pi * frequency * local)
        tone += 0.15 * math.sin(4 * math.pi * frequency * local)
        value = 0.23 * envelope * tone
        yield round(max(-1, min(1, value)) * 32767)


output = io.BytesIO()
with wave.open(output, "wb") as audio:
    audio.setnchannels(1)
    audio.setsampwidth(2)
    audio.setframerate(RATE)
    audio.writeframes(b"".join(struct.pack("<h", value) for value in samples()))
path = ROOT / "checklist-problem.wav"
if "--check" in sys.argv:
    assert path.read_bytes() == output.getvalue(), f"Stale audio: {path}"
else:
    ROOT.mkdir(parents=True, exist_ok=True)
    path.write_bytes(output.getvalue())
print(f"problem: {len(output.getvalue())} bytes")

# User-selected asset, intentionally not overwritten by the oscillator generator.
# Source, editing command and original checksum: docs/ios/CHECKLIST_SOUNDS.md.
positive = ROOT / "checklist-positive.wav"
assert hashlib.sha256(positive.read_bytes()).hexdigest() == \
    "49691766db58ec115cb02380b6a89c8dd802d16eeef19eb619ed8081e02d7b53", "Success bell has changed"
print(f"positive: {positive.stat().st_size} bytes (selected cue verified)")
