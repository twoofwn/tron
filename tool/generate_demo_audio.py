"""Generate synthetic Vietnamese demo clips on macOS; keep real recordings private."""

import math
import random
import struct
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VOICE = ROOT / "assets/audio/voice"
AMBIENT = ROOT / "assets/audio/ambient"

LINES = {
    "mother": [
        "Alo, con à?",
        "Ở nhà có việc gấp, con về ngay nhé.",
        "Không được, bố con đang mệt. Về liền đi.",
        "Nhanh lên nhé con.",
    ],
    "boss": [
        "Alo, em nghe máy được không?",
        "Server bên mình vừa gặp sự cố, cần em kiểm tra ngay.",
        "Em có thể về máy tính trong ít phút nữa không?",
        "Ừ, anh chờ em. Cảm ơn nhé.",
        "Có gì cập nhật thì gọi lại cho anh.",
    ],
    "landlord": [
        "Alo, cô gọi về tiền phòng tháng này.",
        "Con thu xếp về gặp cô hôm nay nhé.",
        "Cô cần nói chuyện trực tiếp một chút.",
        "Cô đợi con ở nhà trọ.",
    ],
    "friend": [
        "Ê, cậu ra ngoài gặp mình một lát được không?",
        "Mình đang có chuyện gấp muốn hỏi cậu.",
        "Ra chỗ cũ nhé, mình đợi.",
    ],
}


def make_voice() -> None:
    VOICE.mkdir(parents=True, exist_ok=True)
    for group, lines in LINES.items():
        for index, line in enumerate(lines, 1):
            wav = VOICE / f"{group}_{index}.wav"
            aiff = VOICE / f"{group}_{index}.aiff"
            subprocess.run(["say", "-v", "Linh", "-o", str(aiff), line], check=True)
            subprocess.run(
                ["afconvert", "-f", "WAVE", "-d", "LEI16", str(aiff), str(wav)],
                check=True,
            )
            aiff.unlink()
            with wave.open(str(wav), "rb") as audio:
                if audio.getnframes() == 0:
                    raise RuntimeError(f"Empty audio clip: {wav}")


def make_ambient() -> None:
    AMBIENT.mkdir(parents=True, exist_ok=True)
    rate = 16000
    seconds = 4
    random.seed(392)
    for name, base, hiss, pulse in [
        ("car", 72, 0.02, 2.0),
        ("television", 185, 0.025, 3.1),
        ("office", 120, 0.018, 1.4),
        ("rain", 0, 0.045, 0.0),
        ("dog", 240, 0.018, 0.7),
        ("cafe", 154, 0.025, 1.1),
    ]:
        with wave.open(str(AMBIENT / f"{name}.wav"), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(rate)
            frames = bytearray()
            for n in range(rate * seconds):
                t = n / rate
                tone = 0 if base == 0 else math.sin(2 * math.pi * base * t) * 0.03
                motion = math.sin(2 * math.pi * pulse * t) * 0.01
                noise = random.uniform(-hiss, hiss)
                sample = max(-1.0, min(1.0, tone + motion + noise))
                frames += struct.pack("<h", int(sample * 32767))
            audio.writeframes(frames)


if __name__ == "__main__":
    make_voice()
    make_ambient()
    print("Generated synthetic demo audio under assets/audio/")
