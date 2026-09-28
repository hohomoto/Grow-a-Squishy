"""Synthesizes the game's sound effects into assets/sounds/*.ogg.

Every sound is generated from scratch (sine waves, filtered noise, envelopes),
so they are original and free to use. Tweak the recipes below and re-run:

    pip install numpy soundfile
    python tools/make_sounds.py

Then upload the .ogg files to Roblox and paste their IDs into
src/shared/Config/Sounds.luau (see README).
"""

from pathlib import Path

import numpy as np
import soundfile as sf

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
rng = np.random.default_rng(20260928)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(length, attack=0.005, decay=8.0):
    """Fast attack, exponential decay."""
    x = t(length)
    a = np.clip(x / attack, 0, 1)
    return a * np.exp(-decay * x)


def chirp(start_hz, end_hz, length, curve=1.0):
    """Sine sweeping from start_hz to end_hz (curve > 1 bends late)."""
    x = t(length)
    frac = (x / length) ** curve
    freq = start_hz + (end_hz - start_hz) * frac
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase)


def tone(hz, length, harmonics=(1.0, 0.3, 0.1)):
    x = t(length)
    out = np.zeros_like(x)
    for i, amp in enumerate(harmonics, start=1):
        out += amp * np.sin(2 * np.pi * hz * i * x)
    return out


def lowpass(signal, cutoff_start, cutoff_end=None):
    """One-pole low-pass with a cutoff that can glide over the sound."""
    cutoff_end = cutoff_start if cutoff_end is None else cutoff_end
    cutoffs = np.linspace(cutoff_start, cutoff_end, len(signal))
    alphas = 1 - np.exp(-2 * np.pi * cutoffs / RATE)
    out = np.empty_like(signal)
    y = 0.0
    for i, (sample, a) in enumerate(zip(signal, alphas)):
        y += a * (sample - y)
        out[i] = y
    return out


def noise(length):
    return rng.uniform(-1, 1, len(t(length)))


def mix(*parts):
    """Adds signals given as (start_seconds, signal) pairs."""
    end = max(int(start * RATE) + len(sig) for start, sig in parts)
    out = np.zeros(end)
    for start, sig in parts:
        i = int(start * RATE)
        out[i : i + len(sig)] += sig
    return out


def finish(signal, peak_db=-3.0):
    fade = min(len(signal), int(0.01 * RATE))
    signal[-fade:] *= np.linspace(1, 0, fade)
    peak = np.max(np.abs(signal)) or 1.0
    return signal / peak * (10 ** (peak_db / 20))


# --- Recipes ----------------------------------------------------------------


def squish():
    """Harvest: a soft, wet squeeze with a little bloop."""
    length = 0.32
    body = lowpass(noise(length), 2500, 250) * env(length, 0.01, 11)
    bloop = chirp(320, 140, length, 0.6) * env(length, 0.02, 14) * 0.8
    squeak = chirp(900, 1300, 0.08) * env(0.08, 0.005, 40) * 0.25
    return finish(mix((0, body), (0, bloop), (0.05, squeak)))


def pop():
    """Planting and pop-its: a quick rising bubble pop."""
    length = 0.09
    bubble = chirp(500, 1500, length, 0.5) * env(length, 0.002, 45)
    click = lowpass(noise(0.01), 6000) * np.linspace(1, 0, len(t(0.01))) * 0.4
    return finish(mix((0, click), (0.002, bubble)))


def coin():
    """Buying: two bright bell notes."""
    first = tone(988, 0.1) * env(0.1, 0.002, 30)
    second = tone(1319, 0.4) * env(0.4, 0.002, 7)
    return finish(mix((0, first), (0.07, second)))


def sell():
    """Selling: a cascade of coin tings."""
    notes = [1047, 1175, 1319, 1568, 1760, 2093]
    parts = [(i * 0.055, tone(hz, 0.35) * env(0.35, 0.002, 9) * (0.7 + 0.06 * i)) for i, hz in enumerate(notes)]
    return finish(mix(*parts))


def click():
    """UI buttons: a tiny soft tick."""
    tick = lowpass(noise(0.03), 5000, 1500) * env(0.03, 0.001, 120)
    body = tone(1800, 0.03, (1.0,)) * env(0.03, 0.001, 150) * 0.5
    return finish(mix((0, tick), (0, body)), -6.0)


def dig():
    """Shovel: a crunchy scrape with a low thump."""
    scrape = lowpass(noise(0.22), 1800, 600) * env(0.22, 0.01, 12)
    thump = chirp(140, 70, 0.15) * env(0.15, 0.003, 22)
    return finish(mix((0, scrape), (0, thump)))


def sparkle():
    """New mutation / rare moment: a shimmering rising arpeggio."""
    notes = [1047, 1319, 1568, 2093, 2637]
    parts = []
    for i, hz in enumerate(notes):
        x = t(0.6)
        vibrato = np.sin(2 * np.pi * hz * x + 0.004 * hz * np.sin(2 * np.pi * 6 * x))
        parts.append((i * 0.06, vibrato * env(0.6, 0.004, 6) * 0.6))
    return finish(mix(*parts))


def star():
    """Shooting star: a falling whoosh that lands with a chime."""
    whoosh = lowpass(noise(1.1), 300, 4000) * np.linspace(0.1, 1, len(t(1.1))) ** 2
    impact = sparkle() * 0.8
    thud = chirp(180, 60, 0.3) * env(0.3, 0.003, 12)
    return finish(mix((0, whoosh), (1.1, thud), (1.1, impact)))


def weather():
    """Weather starts: a soft chord swell."""
    length = 1.8
    x = t(length)
    swell = np.sin(np.pi * x / length) ** 2
    chord = sum(np.sin(2 * np.pi * hz * x) for hz in (523, 659, 784, 1047))
    shimmer = np.sin(2 * np.pi * 2093 * x) * 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * x))
    return finish((chord + shimmer) * swell, -6.0)


def error():
    """Can't do that: a soft low double bonk."""
    first = chirp(260, 200, 0.12) * env(0.12, 0.004, 18)
    second = chirp(220, 160, 0.16) * env(0.16, 0.004, 14)
    return finish(mix((0, first), (0.13, second)), -5.0)


RECIPES = {
    "squish": squish,
    "pop": pop,
    "coin": coin,
    "sell": sell,
    "click": click,
    "dig": dig,
    "sparkle": sparkle,
    "star": star,
    "weather": weather,
    "error": error,
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, recipe in RECIPES.items():
        audio = recipe().astype(np.float32)
        path = OUT / f"{name}.ogg"
        sf.write(path, audio, RATE, format="OGG", subtype="VORBIS")
        print(f"{path.relative_to(OUT.parent.parent)}  {len(audio) / RATE:.2f}s")


if __name__ == "__main__":
    main()
