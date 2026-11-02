"""Generate original, small offline demo sounds; no downloaded audio."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
RATE = 16000
random.seed(393)

def save(folder, name, sample, seconds=4):
    directory = ROOT / folder
    directory.mkdir(parents=True, exist_ok=True)
    values = []
    for index in range(RATE * seconds):
        time = index / RATE
        fade = min(1, time * 30, (seconds - time) * 30)
        value = max(-1, min(1, sample(time) * fade))
        values.append(struct.pack('<h', int(value * 24000)))
    with wave.open(str(directory / f'{name}.wav'), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b''.join(values))

def tone(frequency, time):
    return math.sin(math.tau * frequency * time)

# Chuông iPhone/Samsung/Huawei/Zalo/Messenger là file MP3 có sẵn, không tạo ở đây.
# Nếu tạo lại chuông cổ điển, chép thêm sang android/app/src/main/res/raw/ring_classic.wav.
save('ringtones', 'classic_ring', lambda t: (tone(480, t) + tone(620, t)) * 0.25 if t % 2 < 0.8 else 0)
save('backgrounds', 'rain', lambda t: random.uniform(-0.6, 0.6))
save('backgrounds', 'office', lambda t: random.uniform(-0.12, 0.12) + (random.uniform(-0.7, 0.7) * math.exp(-180 * (t % 0.13))))
save('backgrounds', 'traffic', lambda t: random.uniform(-0.15, 0.15) + ((tone(349, t) + tone(440, t)) * 0.25 if 0.8 < t % 3 < 1.1 else 0))
save('backgrounds', 'television', lambda t: (tone(170 + 30 * math.sin(t * 7), t) + tone(260, t)) * 0.15 * (0.5 + 0.5 * math.sin(t * 13)) + random.uniform(-0.08, 0.08))
save('backgrounds', 'cafe', lambda t: sum(tone(f, t) for f in [261.63, 329.63, 392]) * 0.15 * math.exp(-2 * (t % 1)) + random.uniform(-0.035, 0.035))
