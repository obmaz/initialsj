"""외부 녹음 없이 원거리 천둥을 오프라인 합성한다. 기존 음원은 --replace 때만 교체한다."""
from pathlib import Path
import argparse
import math
import random
import struct
import subprocess
import tempfile
import wave
ROOT = Path(__file__).resolve().parents[1]

def bake(replace=False):
    output = ROOT / 'assets/audio/distant-thunder.ogg'
    if output.exists() and (not replace):
        return
    rng = random.Random(4612)
    rate = 22050
    data = bytearray()
    low = 0.0
    for i in range(int(rate * 4.6)):
        t = i / rate
        low = low * 0.96 + rng.uniform(-1, 1) * 0.04
        envelope = (1 - math.exp(-t * 25)) * math.exp(-t * 0.95)
        sound = (low * 2.5 + math.sin(t * math.tau * 38) * 0.13 + math.sin(t * math.tau * 61) * 0.08) * envelope
        data.extend(struct.pack('<h', int(max(-0.95, min(0.95, sound)) * 32767)))
    with tempfile.TemporaryDirectory() as folder:
        source = Path(folder) / 'thunder.wav'
        with wave.open(str(source), 'wb') as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(rate)
            stream.writeframes(data)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-c:a', 'libvorbis', '-q:a', '4', str(output)], check=True)
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--replace', action='store_true')
    bake(parser.parse_args().replace)
