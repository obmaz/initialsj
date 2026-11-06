"""Bake short enveloped UI tones to PCM files; no sample generation runs in the game."""
from pathlib import Path
import base64
import json
import math
import struct
import wave
root = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
for name, frequency, duration in [('countdown', 660, .12), ('launch', 1320, .22), ('reward', 950, .18), ('lap', 1046.5, .30)]:
    rate = 44100
    count = round(rate * duration)
    phase = 0.0
    frames = bytearray()
    for i in range(count):
        fraction = i / count
        phase += (frequency + (fraction * 480 if name == 'reward' else 0)) / rate
        envelope = min(i / (rate * .008), 1) * (1 - fraction) ** 1.6
        sample = math.sin(phase * math.tau) * .55 * envelope
        frames.extend(struct.pack('<h', round(sample * 32767)))
    with wave.open(str(root / f'{name}.wav'), 'wb') as output:
        output.setparams((1, 2, rate, 0, 'NONE', 'NONE'))
        output.writeframes(frames)

# Keep original compressed recordings available to the Web Audio decoder inside the PCK.
(root / 'web-loops.json').write_text(json.dumps({
    'engine': base64.b64encode((root / 'engine-loop.ogg').read_bytes()).decode(),
    'tires': base64.b64encode((root / 'tire-squeal.ogg').read_bytes()).decode(),
}, separators=(',', ':')) + '\n')
