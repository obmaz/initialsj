#!/usr/bin/env python3
"""Bake every vehicle's own engine, boost and drift sounds. No third-party samples.

Each vehicle in scripts/vehicle_catalog.gd needs one entry in VEHICLES below, keyed by
its catalog "id". The bake writes, per vehicle, into assets/audio/vehicles/:

    <id>-engine.ogg       looping exhaust note; pitched by RPM and gear at run time
    <id>-boost.ogg        looping booster roar while nitro or a road boost is active
    <id>-boost-start.wav  one-shot ignition hit when a nitro shot begins
    <id>-drift.ogg        looping tyre noise while drifting (and, quietly, on puddles)

and assets/audio/web-loops.json (the three loops of every vehicle, base64, for Web Audio).
Everything is deterministic: the same table always bakes identical audio. Loops are
exactly periodic (two seconds, every tone an exact multiple of 0.5 Hz), so they repeat
without a seam. Levels are A-weighted and matched to the shared recordings this system
replaced, so the playback gains in scripts/vehicle_audio.gd keep their meaning.

Usage (see docs/VEHICLE_AUDIO.md):
    python3 tools/bake_vehicle_audio.py                  bake, then check distinctness
    python3 tools/bake_vehicle_audio.py --check          check the baked files only
    python3 tools/bake_vehicle_audio.py --preview DIR    also write in-game-mix demos
"""
from __future__ import annotations

import argparse
import base64
import json
import re
import subprocess
import sys
import wave
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
OUT = AUDIO / "vehicles"
CATALOG = ROOT / "scripts" / "vehicle_catalog.gd"
RATE = 44100
LOOP_SECONDS = 2.0
M = round(RATE * LOOP_SECONDS)
FREQ = np.fft.rfftfreq(M, 1 / RATE)  # 0.5 Hz bins
T = np.arange(M) / RATE

# A-weighted RMS targets, matched to the former shared engine/tyre recordings.
LEVEL = {"engine": 0.1124, "boost": 0.150, "drift": 0.1956, "start": 0.200}
PEAK = 0.90
# Two vehicles' same-layer sounds must differ by at least this much (mean dB
# difference of one-third-octave levels, over the bands where either one has
# audible energy) or the bake fails.
MIN_DISTANCE_DB = 4.0
AUDIBLE_DB = -35.0

# --------------------------------------------------------------------------
# Per-vehicle recipes. Edit numbers here, bake, and listen with --preview.
# --------------------------------------------------------------------------
# engine:  rpm        reference RPM of the loop; must be a multiple of 60
#          banks      exhaust banks; "fires" are (position in the 720 deg cycle 0..1, weight)
#                     "resonances" are (Hz, decay s, amplitude) pipe modes
#          boom       (Hz, decay s, amplitude) combustion thump
#          noise      (amplitude, decay s, low-pass Hz) exhaust hiss burst per firing
#          drive      saturation; timing_jitter_ms / amp_jitter roughen the firing
# boost:   bands      (centre Hz, Q, gain) of the flow noise
#          tones      (Hz, amplitude, vibrato Hz, vibrato depth Hz); Hz and vibrato in 0.5 Hz steps
#          flutter    (Hz, depth) amplitude modulation of the noise; drive saturation
# start:   seconds, thumps (Hz0, Hz1, pitch decay, amp decay, amp, delay),
#          noises (low Hz, high Hz, decay, amp, delay), chirps (Hz0, Hz1, amp, delay, seconds)
# drift:   bands, tones as above; slip (Hz, depth) stick-slip modulation; drive
FIRE_V8_A = [(d / 720, 1.0) for d in (0, 270, 450, 540)]
FIRE_V8_B = [(d / 720, 1.0) for d in (90, 180, 360, 630)]
VEHICLES = {
    # Light hatchback: buzzy, bright four-cylinder; whistling turbo flow; thin high squeal.
    "nimori": {
        "engine": {
            "rpm": 3300,
            "banks": [{
                "fires": [(0.0, 1.00), (0.25, 0.92), (0.5, 1.06), (0.75, 0.96)],
                "resonances": [(150, 0.018, 1.0), (410, 0.011, 0.75), (1180, 0.006, 0.5), (2700, 0.003, 0.3)],
            }],
            "boom": (62, 0.020, 0.55), "noise": (0.14, 0.004, 2500),
            "drive": 1.7, "timing_jitter_ms": 0.10, "amp_jitter": 0.07,
        },
        "boost": {
            "bands": [(1400, 1.2, 0.8), (3000, 1.2, 0.35), (500, 0.8, 0.25)],
            "tones": [(2800, 0.90, 6, 60), (5600, 0.22, 6, 120), (700, 0.15, 0, 0)],
            "flutter": (22, 0.18), "drive": 1.1,
        },
        "start": {
            "seconds": 0.55,
            "thumps": [(140, 90, 0.05, 0.07, 0.30, 0.0)],
            "noises": [(2000, 9000, 0.14, 0.9, 0.0)],
            "chirps": [(1200, 2600, 0.35, 0.0, 0.5)],
        },
        "drift": {
            "bands": [(1850, 16, 0.45), (3700, 8, 0.08)],
            "tones": [(1850, 0.75, 6, 28), (3700, 0.20, 6, 56), (925, 0.15, 0, 0)],
            "slip": (14, 0.30), "drive": 1.4,
        },
    },
    # Wedge exotic: smooth, high-revving V10 wail; roaring jet shots; wide raspy shriek.
    "veltrix": {
        "engine": {
            "rpm": 5400,
            "banks": [
                {"fires": [(i / 10, 1.0) for i in (0, 2, 4, 6, 8)],
                 "resonances": [(230, 0.014, 0.55), (920, 0.011, 0.8), (1850, 0.009, 0.95), (3500, 0.005, 0.65), (5200, 0.003, 0.35)]},
                {"fires": [(i / 10, 1.0) for i in (1, 3, 5, 7, 9)],
                 "resonances": [(240, 0.014, 0.55), (960, 0.011, 0.8), (1925, 0.009, 0.95), (3640, 0.005, 0.65), (5400, 0.003, 0.35)]},
            ],
            "boom": (95, 0.012, 0.30), "noise": (0.07, 0.002, 6000),
            "drive": 1.25, "timing_jitter_ms": 0.05, "amp_jitter": 0.04,
        },
        "boost": {
            "bands": [(700, 0.7, 1.0), (1700, 0.8, 1.0), (3600, 1.0, 0.55), (250, 0.7, 0.5)],
            "tones": [(70, 0.40, 0, 0)],
            "flutter": (38, 0.42), "drive": 1.8,
        },
        "start": {
            "seconds": 0.70,
            "thumps": [(140, 38, 0.09, 0.22, 1.0, 0.0)],
            "noises": [(1200, 12000, 0.05, 0.9, 0.0), (400, 1200, 0.25, 0.4, 0.02)],
            "chirps": [],
        },
        "drift": {
            "bands": [(1900, 1.2, 1.0), (3800, 1.0, 0.50), (1000, 1.4, 0.45)],
            "tones": [(2400, 0.22, 9, 60), (3100, 0.20, 11, 70)],
            "slip": (28, 0.40), "drive": 1.8,
        },
    },
    # Classic muscle: lumpy cross-plane V8 rumble; deep pulsing roar; low rubbery scrub.
    "ironvale": {
        "engine": {
            "rpm": 3000,
            "banks": [
                {"fires": FIRE_V8_A,
                 "resonances": [(68, 0.035, 1.15), (150, 0.030, 1.0), (330, 0.020, 0.8), (650, 0.012, 0.45), (1250, 0.006, 0.25)]},
                {"fires": FIRE_V8_B,
                 "resonances": [(74, 0.032, 1.05), (163, 0.027, 1.0), (360, 0.018, 0.85), (710, 0.011, 0.5), (1360, 0.006, 0.3)]},
            ],
            "boom": (46, 0.050, 1.10), "noise": (0.22, 0.007, 1400),
            "drive": 2.1, "timing_jitter_ms": 0.25, "amp_jitter": 0.13,
        },
        "boost": {
            "bands": [(180, 0.9, 1.0), (420, 0.9, 0.7), (950, 1.0, 0.2)],
            "tones": [(120, 0.5, 3, 12), (60, 0.5, 0, 0), (840, 0.12, 5, 60)],
            "flutter": (11, 0.50), "drive": 2.2,
        },
        "start": {
            "seconds": 0.80,
            "thumps": [(85, 30, 0.12, 0.30, 1.0, 0.0)],
            "noises": [(60, 1000, 0.18, 0.7, 0.0), (600, 2400, 0.02, 0.6, 0.16)],
            "chirps": [],
        },
        "drift": {
            "bands": [(650, 2.5, 0.9), (1500, 1.6, 0.35), (250, 1.6, 0.3)],
            "tones": [(620, 0.45, 5, 36), (1240, 0.20, 5, 70), (310, 0.25, 0, 0)],
            "slip": (9, 0.55), "drive": 2.3,
        },
    },
    # Rear-engine GT: rasping flat-six (two banks alternating every 120 deg);
    # twin-turbo rush with wastegate chatter; mid-pitched clean squeal.
    "straud": {
        "engine": {
            "rpm": 4200,
            "banks": [
                {"fires": [(0.0, 1.0), (1 / 3, 1.0), (2 / 3, 1.0)],
                 "resonances": [(180, 0.016, 0.6), (470, 0.012, 0.9), (980, 0.009, 0.85), (1650, 0.006, 0.6), (2900, 0.004, 0.35)]},
                {"fires": [(1 / 6, 1.0), (0.5, 1.0), (5 / 6, 1.0)],
                 "resonances": [(190, 0.016, 0.6), (500, 0.012, 0.9), (1030, 0.009, 0.85), (1740, 0.006, 0.6), (3050, 0.004, 0.35)]},
            ],
            "boom": (78, 0.018, 0.45), "noise": (0.10, 0.003, 4200),
            "drive": 1.6, "timing_jitter_ms": 0.07, "amp_jitter": 0.05,
        },
        "boost": {
            "bands": [(550, 1.6, 1.0), (1200, 1.4, 0.35)],
            "tones": [(1100, 0.80, 4, 20), (2200, 0.25, 4, 40)],
            "flutter": (16, 0.45), "drive": 1.4,
        },
        "start": {
            "seconds": 0.60,
            "thumps": [(110, 60, 0.06, 0.12, 0.6, 0.0)],
            "noises": [(1500, 8000, 0.09, 0.8, 0.02), (300, 1500, 0.05, 0.5, 0.0)],
            "chirps": [(2400, 1400, 0.25, 0.0, 0.3)],
        },
        "drift": {
            "bands": [(1100, 10, 0.45), (3300, 8, 0.10)],
            "tones": [(1100, 0.80, 7, 35), (3300, 0.20, 7, 90), (550, 0.15, 0, 0)],
            "slip": (20, 0.35), "drive": 1.6,
        },
    },
}


# --------------------------------------------------------------------------
# Signal helpers
# --------------------------------------------------------------------------
def seeded(vehicle: str, layer: str) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(f"{vehicle}:{layer}".encode()))


def a_weight(freq: np.ndarray) -> np.ndarray:
    f2 = np.maximum(freq, 1e-3) ** 2
    ra = (12194**2 * f2 * f2) / ((f2 + 20.6**2) * np.sqrt((f2 + 107.7**2) * (f2 + 737.9**2)) * (f2 + 12194**2))
    return ra * 1.2588966


def a_rms(x: np.ndarray) -> float:
    spectrum = np.fft.rfft(x)
    freq = np.fft.rfftfreq(len(x), 1 / RATE)
    return float(np.sqrt(2 * np.sum((np.abs(spectrum) * a_weight(freq)) ** 2)) / len(x))


def band(freq: np.ndarray, centre: float, q: float) -> np.ndarray:
    f = np.maximum(freq, 1e-3)
    return 1 / np.sqrt(1 + (q * (f / centre - centre / f)) ** 2)


def lowpass(freq: np.ndarray, corner: float, order: int = 2) -> np.ndarray:
    return 1 / np.sqrt(1 + (freq / corner) ** (2 * order))


def highpass(freq: np.ndarray, corner: float, order: int = 2) -> np.ndarray:
    return 1 / np.sqrt(1 + (corner / np.maximum(freq, 1e-3)) ** (2 * order))


def filtered_noise(rng: np.random.Generator, magnitude: np.ndarray, length: int) -> np.ndarray:
    """Noise with the given magnitude response. Periodic over `length` samples."""
    phase = rng.uniform(0, 2 * np.pi, len(magnitude))
    spectrum = magnitude * np.exp(1j * phase)
    spectrum[0] = 0
    x = np.fft.irfft(spectrum, length)
    return x / max(np.sqrt(np.mean(x**2)), 1e-12)


def normalize(x: np.ndarray, target: float) -> np.ndarray:
    x = x - x.mean()
    for _ in range(6):
        x = x * (target / a_rms(x))
        peak = np.abs(x).max()
        if peak <= PEAK:
            break
        x = PEAK * np.tanh(x / PEAK)
    return np.clip(x, -0.98, 0.98)


def saturate(x: np.ndarray, drive: float) -> np.ndarray:
    return np.tanh(drive * x / max(np.std(x), 1e-12))


def am(rate_hz: float, depth: float, phase: float = 0.0) -> np.ndarray:
    return 1 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * rate_hz * T + phase))


def tone(freq_hz: float, vibrato_hz: float, vibrato_depth: float) -> np.ndarray:
    index = vibrato_depth / vibrato_hz if vibrato_hz else 0.0
    return np.sin(2 * np.pi * freq_hz * T + index * np.sin(2 * np.pi * vibrato_hz * T))


# --------------------------------------------------------------------------
# Layers
# --------------------------------------------------------------------------
def impulse_response(resonances, boom, noise, rng: np.random.Generator) -> np.ndarray:
    n = int(0.30 * RATE)
    t = np.arange(n) / RATE
    h = np.zeros(n)
    for hz, decay, amp in resonances:
        h += amp * np.exp(-t / decay) * np.sin(2 * np.pi * hz * t)
    hz, decay, amp = boom
    h += amp * np.exp(-t / decay) * np.sin(2 * np.pi * hz * t) * (1 - np.exp(-t / 0.0015))
    amp, decay, corner = noise
    hiss = filtered_noise(rng, lowpass(np.fft.rfftfreq(n, 1 / RATE), corner), n)
    h += amp * np.exp(-t / decay) * hiss
    return h


def engine_loop(spec: dict, rng: np.random.Generator) -> np.ndarray:
    if spec["rpm"] % 60:
        raise SystemExit("engine rpm must be a multiple of 60 so whole cycles fit the loop")
    cycles = spec["rpm"] // 60
    per_cycle = M / cycles
    out = np.zeros(M)
    for bank in spec["banks"]:
        variants = [impulse_response(bank["resonances"], spec["boom"], spec["noise"], rng) for _ in range(3)]
        trains = [np.zeros(M) for _ in variants]
        for cycle in range(cycles):
            for position, weight in bank["fires"]:
                at = (cycle + position) * per_cycle + rng.normal(0, spec["timing_jitter_ms"] * RATE / 1000)
                amp = weight * (1 + rng.normal(0, spec["amp_jitter"]))
                index = int(np.floor(at))
                share = at - index
                train = trains[rng.integers(len(trains))]
                train[index % M] += amp * (1 - share)
                train[(index + 1) % M] += amp * share
        for train, h in zip(trains, variants):
            out += np.fft.irfft(np.fft.rfft(train) * np.fft.rfft(h, M), M)
    out = np.fft.irfft(np.fft.rfft(out) * highpass(FREQ, 28), M)
    return normalize(saturate(out, spec["drive"]), LEVEL["engine"])


def boost_loop(spec: dict, rng: np.random.Generator) -> np.ndarray:
    magnitude = sum(gain * band(FREQ, centre, q) for centre, q, gain in spec["bands"])
    flow = filtered_noise(rng, magnitude, M)
    hz, depth = spec["flutter"]
    flow = flow * am(hz, depth, rng.uniform(0, 2 * np.pi))
    out = flow
    for freq_hz, amp, vibrato_hz, vibrato_depth in spec["tones"]:
        out = out + amp * tone(freq_hz, vibrato_hz, vibrato_depth)
    return normalize(saturate(out, spec["drive"]), LEVEL["boost"])


def drift_loop(spec: dict, rng: np.random.Generator) -> np.ndarray:
    magnitude = sum(gain * band(FREQ, centre, q) for centre, q, gain in spec["bands"])
    scrub = filtered_noise(rng, magnitude, M)
    out = scrub * 0.8
    for freq_hz, amp, vibrato_hz, vibrato_depth in spec["tones"]:
        out = out + amp * tone(freq_hz, vibrato_hz, vibrato_depth)
    hz, depth = spec["slip"]
    out = out * am(hz, depth, rng.uniform(0, 2 * np.pi))
    return normalize(saturate(out, spec["drive"]), LEVEL["drift"])


def boost_start(spec: dict, rng: np.random.Generator) -> np.ndarray:
    n = round(spec["seconds"] * RATE)
    t = np.arange(n) / RATE
    freq = np.fft.rfftfreq(n, 1 / RATE)
    out = np.zeros(n)
    for hz0, hz1, pitch_decay, amp_decay, amp, delay in spec["thumps"]:
        local = np.maximum(t - delay, 0)
        inst = hz1 + (hz0 - hz1) * np.exp(-local / pitch_decay)
        phase = 2 * np.pi * np.cumsum(inst) / RATE
        out += amp * np.sin(phase) * np.exp(-local / amp_decay) * (t >= delay)
    for low, high, decay, amp, delay in spec["noises"]:
        shape = highpass(freq, low) * lowpass(freq, high)
        local = np.maximum(t - delay, 0)
        out += amp * filtered_noise(rng, shape, n) * np.exp(-local / decay) * (t >= delay)
    for hz0, hz1, amp, delay, seconds in spec["chirps"]:
        local = np.clip((t - delay) / seconds, 0, 1)
        inst = hz0 + (hz1 - hz0) * local
        phase = 2 * np.pi * np.cumsum(inst) / RATE
        out += amp * np.sin(phase) * np.sin(np.pi * local) ** 0.6 * ((t >= delay) & (local < 1))
    out *= np.minimum(t / 0.003, 1) * np.minimum((spec["seconds"] - t) / 0.06, 1)
    return normalize(saturate(out, 1.6), LEVEL["start"])


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------
def write_wav(path: Path, x: np.ndarray) -> None:
    with wave.open(str(path), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "NONE"))
        output.writeframes(np.round(np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def write_ogg(path: Path, x: np.ndarray) -> None:
    pcm = x.astype("<f4").tobytes()
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "4", "-fflags", "+bitexact", "-flags:a", "+bitexact", str(path)],
        input=pcm, capture_output=True)
    if result.returncode:
        raise SystemExit("ffmpeg could not encode " + path.name + ": " + result.stderr.decode())


def read_audio(path: Path) -> np.ndarray:
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"],
        capture_output=True, check=True)
    return np.frombuffer(result.stdout, dtype="<f4").astype(np.float64)


def catalog_ids() -> list[str]:
    return re.findall(r'"id":"(\w+)"', CATALOG.read_text(encoding="utf-8"))


def catalog_audio(vehicle: str) -> dict:
    """Numeric audio tuning of one vehicle from the catalog (used by --preview)."""
    for line in CATALOG.read_text(encoding="utf-8").splitlines():
        if f'"id":"{vehicle}"' in line:
            block = re.search(r'"audio":\{(.*?)\}', line).group(1)
            return {k: float(v) for k, v in re.findall(r'"(\w+)":(-?[\d.]+)', block)}
    raise SystemExit("vehicle not in catalog: " + vehicle)


def files_of(vehicle: str) -> dict[str, Path]:
    return {
        "engine": OUT / f"{vehicle}-engine.ogg",
        "boost": OUT / f"{vehicle}-boost.ogg",
        "start": OUT / f"{vehicle}-boost-start.wav",
        "drift": OUT / f"{vehicle}-drift.ogg",
    }


def bake() -> None:
    missing = sorted(set(catalog_ids()) - set(VEHICLES))
    extra = sorted(set(VEHICLES) - set(catalog_ids()))
    if missing or extra:
        raise SystemExit(f"VEHICLES must match the catalog ids. Missing recipes: {missing}; not in catalog: {extra}")
    OUT.mkdir(parents=True, exist_ok=True)
    web = {}
    for vehicle, recipe in VEHICLES.items():
        paths = files_of(vehicle)
        write_ogg(paths["engine"], engine_loop(recipe["engine"], seeded(vehicle, "engine")))
        write_ogg(paths["boost"], boost_loop(recipe["boost"], seeded(vehicle, "boost")))
        write_wav(paths["start"], boost_start(recipe["start"], seeded(vehicle, "start")))
        write_ogg(paths["drift"], drift_loop(recipe["drift"], seeded(vehicle, "drift")))
        for layer in ("engine", "boost", "drift"):
            web[f"{vehicle}-{layer}"] = base64.b64encode(paths[layer].read_bytes()).decode()
    (AUDIO / "web-loops.json").write_text(json.dumps(web, separators=(",", ":")) + "\n")


# --------------------------------------------------------------------------
# Checks and report
# --------------------------------------------------------------------------
def third_octave_db(x: np.ndarray) -> np.ndarray:
    spectrum = np.abs(np.fft.rfft(x)) ** 2
    freq = np.fft.rfftfreq(len(x), 1 / RATE)
    centres = 25 * 2 ** (np.arange(0, 28) / 3)
    levels = []
    for centre in centres:
        mask = (freq >= centre / 2 ** (1 / 6)) & (freq < centre * 2 ** (1 / 6))
        levels.append(spectrum[mask].sum() + 1e-12)
    levels = np.array(levels)
    return 10 * np.log10(levels / levels.sum())


def features(x: np.ndarray) -> dict:
    spectrum = np.abs(np.fft.rfft(x)) ** 2
    freq = np.fft.rfftfreq(len(x), 1 / RATE)
    return {"centroid_hz": float((freq * spectrum).sum() / spectrum.sum()), "peak": float(np.abs(x).max()), "a_rms": a_rms(x)}


def check() -> int:
    failures = 0
    for vehicle in sorted(set(catalog_ids()) ^ set(VEHICLES)):
        print("CATALOG/RECIPE MISMATCH: no matching entry for", vehicle)
        failures += 1
    loaded = {}
    for vehicle in VEHICLES:
        for layer, path in files_of(vehicle).items():
            if not path.is_file():
                print("MISSING", path.relative_to(ROOT))
                failures += 1
                continue
            loaded[(vehicle, layer)] = read_audio(path)
    if failures:
        return failures
    print(f"{'vehicle':9s} {'layer':7s} {'seconds':>7s} {'peak':>6s} {'A-rms':>7s} {'centroid':>9s}")
    for (vehicle, layer), x in loaded.items():
        f = features(x)
        print(f"{vehicle:9s} {layer:7s} {len(x) / RATE:7.2f} {f['peak']:6.3f} {f['a_rms']:7.4f} {f['centroid_hz']:8.0f}Hz")
        if f["peak"] > 0.99:
            print("CLIPPED", vehicle, layer)
            failures += 1
        if layer != "start" and abs(len(x) - M) > 2048:
            print("LOOP LENGTH", vehicle, layer, len(x))
            failures += 1
    names = list(VEHICLES)
    for layer in ("engine", "boost", "start", "drift"):
        for i, a in enumerate(names):
            for b in names[i + 1:]:
                first, second = third_octave_db(loaded[(a, layer)]), third_octave_db(loaded[(b, layer)])
                occupied = np.maximum(first, second) > AUDIBLE_DB
                distance = float(np.mean(np.abs(first - second)[occupied]))
                verdict = "ok" if distance >= MIN_DISTANCE_DB else "TOO SIMILAR"
                print(f"  {layer:7s} {a} vs {b}: {distance:5.1f} dB  {verdict}")
                if distance < MIN_DISTANCE_DB:
                    failures += 1
    web = json.loads((AUDIO / "web-loops.json").read_text())
    for vehicle in VEHICLES:
        for layer in ("engine", "boost", "drift"):
            if base64.b64decode(web.get(f"{vehicle}-{layer}", "")) != files_of(vehicle)[layer].read_bytes():
                print("web-loops.json is stale for", vehicle, layer)
                failures += 1
    print("PASS" if not failures else f"FAIL ({failures})")
    return failures


# --------------------------------------------------------------------------
# Preview: the game's own mix, so a vehicle can be judged by ear
# --------------------------------------------------------------------------
def play_rate(loop: np.ndarray, rates: np.ndarray) -> np.ndarray:
    position = np.cumsum(rates) * (len(loop) / len(loop))  # samples consumed
    index = position % len(loop)
    low = np.floor(index).astype(int)
    share = index - low
    return loop[low] * (1 - share) + loop[(low + 1) % len(loop)] * share


def preview(directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for vehicle in VEHICLES:
        tuning = catalog_audio(vehicle)
        sound = {layer: read_audio(path) for layer, path in files_of(vehicle).items()}
        seconds = 14
        n = seconds * RATE
        t = np.arange(n) / RATE
        # Four gears: rpm01 ramps 0..1 in each, as the game's rpm/gear mapping does.
        gear_len = 3.0
        gear = np.minimum((t // gear_len).astype(int), 3) + 1
        rpm01 = np.clip((t % gear_len) / gear_len, 0, 1)
        rpm01[t >= 4 * gear_len] = 1.0
        pitch = tuning["engine_pitch"] + rpm01 * tuning["engine_span"] + (gear - 1) * tuning["engine_gear"]
        mix = play_rate(sound["engine"], pitch) * 0.18 * tuning["engine_gain"]
        speed01 = np.clip(0.35 + 0.65 * t / seconds, 0, 1)
        # 6-9 s nitro (start hit + loop), 10-13 s drift.
        boost_on = ((t >= 6) & (t < 9)).astype(float)
        boost_gain = np.convolve(boost_on, np.ones(1500) / 1500, mode="same") * 0.17 * tuning["boost_gain"]
        mix += play_rate(sound["boost"], 1 + tuning["boost_rise"] * speed01) * boost_gain
        start = sound["start"] * 0.25 * tuning["start_gain"]
        s0 = 6 * RATE
        mix[s0:s0 + len(start)] += start
        drift_on = ((t >= 10) & (t < 13)).astype(float)
        drift_gain = np.convolve(drift_on, np.ones(1500) / 1500, mode="same") * 0.038 * tuning["drift_gain"]
        mix += play_rate(sound["drift"], tuning["drift_pitch"] * (0.94 + 0.12 * speed01)) * drift_gain
        write_wav(directory / f"{vehicle}-demo.wav", np.clip(mix * 3.0, -1, 1))  # +9.5 dB so quiet layers are audible
        print("wrote", (directory / f"{vehicle}-demo.wav"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="check existing files without baking")
    parser.add_argument("--preview", metavar="DIR", help="write per-vehicle in-game-mix demo WAVs")
    args = parser.parse_args()
    if not args.check:
        bake()
    failures = check()
    if args.preview and not failures:
        preview(Path(args.preview))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
