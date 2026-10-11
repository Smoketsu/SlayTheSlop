"""Synthesizes the placeholder sound effects (task 055). Lane: client (Agent B).

Every sound is made from sine, square and triangle waves and from noise, by this script alone, so
the files are original to this repository: nothing is sampled, downloaded or copied. The output is
deterministic (the noise comes from a fixed-seed generator written here, not from `random`), so
running it again gives byte-identical files.

Usage, from the repository root:

    python3 -I assets/placeholder/source/make_sounds.py assets/placeholder/sounds

Needs only the Python 3 standard library (wave, math, struct). Writes one <kind>.wav per entry of
SOUNDS: 16-bit mono PCM at SAMPLE_RATE. The kinds match client/audio/sounds.gd FILES; a new sound
needs an entry in both, and a line in assets/placeholder/README.md "Sounds".
"""

import math
import struct
import sys
import wave

# SAMPLE_RATE: samples per second of every file. 22050 Hz keeps the files small and is plenty for
# short effects. Changed only by the client lane.
SAMPLE_RATE = 22050
# PEAK: the loudest sample any sound reaches, as a fraction of full scale (0..1), so no file clips
# and the set sounds about equally loud. Changed only by the client lane.
PEAK = 0.7
# FADE_SECONDS: length of the fade-out applied to the end of every sound, so none ends in a click.
FADE_SECONDS = 0.01
# NOISE_SEED: start value of the noise generator. Fixed so the output never changes between runs.
NOISE_SEED = 12345


class Noise:
    """White noise from a 32-bit linear congruential generator, deterministic for a seed."""

    def __init__(self, seed):
        # state: the generator's current 32-bit value.
        self.state = seed & 0xFFFFFFFF

    def next(self):
        """Returns the next noise sample, -1.0..1.0."""
        self.state = (self.state * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.state / 2147483648.0 - 1.0


def sine(phase):
    """Sine wave at phase (cycles; any float). Returns -1.0..1.0."""
    return math.sin(2.0 * math.pi * phase)


def square(phase):
    """Soft square wave at phase (cycles): a square with its corners rounded (sum of 3 odd
    harmonics), less harsh than a pure square. Returns about -1.0..1.0."""
    return (sine(phase) + sine(3 * phase) / 3.0 + sine(5 * phase) / 5.0) * 0.85


def triangle(phase):
    """Triangle wave at phase (cycles). Returns -1.0..1.0."""
    frac = phase - math.floor(phase)
    return 4.0 * abs(frac - 0.5) - 1.0


def tone(seconds, start_hz, end_hz, wave_fn, decay):
    """One tone whose pitch slides from start_hz to end_hz (exponentially) over its length, with an
    exponential decay envelope. seconds: length (> 0). start_hz, end_hz: pitch in Hz (> 0).
    wave_fn: sine, square or triangle. decay: how fast it fades, per second (0 = no fade).
    Returns a list of float samples, -1.0..1.0."""
    count = int(seconds * SAMPLE_RATE)
    samples = []
    phase = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        hz = start_hz * (end_hz / start_hz) ** (i / max(count - 1, 1))
        phase += hz / SAMPLE_RATE
        attack = min(1.0, t / 0.004)
        samples.append(wave_fn(phase) * attack * math.exp(-decay * t))
    return samples


def noise(seconds, decay, noise_gen, smooth):
    """A burst of noise with an exponential decay. seconds: length. decay: fade per second.
    noise_gen: a Noise. smooth: 0..1, how much each sample keeps of the last (a simple low-pass;
    higher is duller). Returns a list of float samples."""
    count = int(seconds * SAMPLE_RATE)
    samples = []
    last = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        last = last * smooth + noise_gen.next() * (1.0 - smooth)
        samples.append(last * math.exp(-decay * t))
    return samples


def mix(*parts):
    """Adds sounds sample by sample. parts: (start_seconds, gain, samples) tuples. Returns the sum,
    as long as the latest-ending part."""
    length = max(int(start * SAMPLE_RATE) + len(samples) for start, _gain, samples in parts)
    out = [0.0] * length
    for start, gain, samples in parts:
        offset = int(start * SAMPLE_RATE)
        for i, value in enumerate(samples):
            out[offset + i] += value * gain
    return out


def finish(samples):
    """Normalizes samples to PEAK and fades out the last FADE_SECONDS. Returns 16-bit ints."""
    loudest = max(abs(s) for s in samples) or 1.0
    fade = int(FADE_SECONDS * SAMPLE_RATE)
    out = []
    for i, value in enumerate(samples):
        left = len(samples) - i
        gain = min(1.0, left / fade) if fade > 0 else 1.0
        out.append(int(round(value / loudest * PEAK * gain * 32767)))
    return out


def card_played(n):
    """A quick swish: noise that brightens, over a soft low tick (a card slapped on a table)."""
    return mix((0.0, 0.8, noise(0.14, 22.0, n, 0.55)), (0.0, 0.5, tone(0.06, 300, 180, sine, 40.0)))


def hit(n):
    """A punchy thump: a sine dropping from 150 to 55 Hz under a short noise crack."""
    return mix((0.0, 1.0, tone(0.2, 150, 55, sine, 14.0)), (0.0, 0.6, noise(0.06, 60.0, n, 0.3)))


def blocked(n):
    """A dull clank: a few inharmonic partials that die fast (a punch on a shield)."""
    return mix(
        (0.0, 0.6, tone(0.22, 523, 515, sine, 18.0)),
        (0.0, 0.4, tone(0.22, 1231, 1220, sine, 26.0)),
        (0.0, 0.3, tone(0.22, 1873, 1860, sine, 34.0)),
        (0.0, 0.3, noise(0.03, 90.0, n, 0.2)),
    )


def guard(n):
    """Two rising soft-square blips (Guard going up)."""
    return mix((0.0, 0.6, tone(0.09, 440, 470, square, 12.0)), (0.08, 0.6, tone(0.14, 660, 700, square, 14.0)))


def enemy_death(n):
    """A falling 'bwomp' with a wobble: a triangle sliding from 420 to 70 Hz."""
    wobble = tone(0.45, 420, 70, triangle, 5.0)
    shaped = [s * (0.75 + 0.25 * sine(i * 9.0 / SAMPLE_RATE)) for i, s in enumerate(wobble)]
    return mix((0.0, 1.0, shaped), (0.0, 0.3, noise(0.1, 30.0, n, 0.7)))


def passed_out(n):
    """Three slow falling triangle notes, G4, E4, C4 (a sleepy 'oh no')."""
    return mix(
        (0.0, 0.7, tone(0.22, 392, 388, triangle, 6.0)),
        (0.2, 0.7, tone(0.22, 330, 326, triangle, 6.0)),
        (0.4, 0.8, tone(0.3, 262, 247, triangle, 5.0)),
    )


def click(n):
    """A very short tick for buttons."""
    return mix((0.0, 1.0, tone(0.035, 1500, 1200, sine, 120.0)), (0.0, 0.3, noise(0.01, 300.0, n, 0.1)))


def dolla_bills(n):
    """A two-note 'ching' (coins): E6 then A6 sines with a bright overtone."""
    return mix(
        (0.0, 0.6, tone(0.1, 1319, 1319, sine, 20.0)),
        (0.0, 0.2, tone(0.1, 2637, 2637, sine, 30.0)),
        (0.07, 0.6, tone(0.2, 1760, 1760, sine, 14.0)),
        (0.07, 0.2, tone(0.2, 3520, 3520, sine, 22.0)),
    )


def victory(n):
    """A rising C-major arpeggio, C5 E5 G5, ending on a held C6 (soft squares)."""
    notes = [(0.0, 523), (0.12, 659), (0.24, 784)]
    parts = [(start, 0.5, tone(0.14, hz, hz, square, 8.0)) for start, hz in notes]
    parts.append((0.36, 0.6, tone(0.42, 1047, 1047, square, 4.5)))
    return mix(*parts)


def defeat(n):
    """A falling 'wah wah': three triangle notes stepping down a semitone, the last bending flat."""
    return mix(
        (0.0, 0.7, tone(0.24, 311, 305, triangle, 4.0)),
        (0.24, 0.7, tone(0.24, 294, 288, triangle, 4.0)),
        (0.48, 0.8, tone(0.42, 277, 233, triangle, 3.0)),
    )


# SOUNDS: file kind -> the function making it. The keys are client/audio/sounds.gd kinds and the
# file names (<kind>.wav). Changed only by the client lane, together with sounds.gd FILES.
SOUNDS = {
    "card_played": card_played,
    "hit": hit,
    "blocked": blocked,
    "guard": guard,
    "enemy_death": enemy_death,
    "passed_out": passed_out,
    "click": click,
    "dolla_bills": dolla_bills,
    "victory": victory,
    "defeat": defeat,
}


def write_wav(path, samples):
    """Writes 16-bit mono PCM samples to path at SAMPLE_RATE."""
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SAMPLE_RATE)
        out.writeframes(struct.pack("<%dh" % len(samples), *samples))


def main(argv):
    """Writes every sound into the folder named by argv[1]. Returns the exit code."""
    if len(argv) != 2:
        print("usage: python3 -I make_sounds.py <out_dir>")
        return 2
    out_dir = argv[1]
    for kind in sorted(SOUNDS):
        # Each sound gets its own noise generator, so changing one sound never changes another.
        samples = finish(SOUNDS[kind](Noise(NOISE_SEED)))
        path = "%s/%s.wav" % (out_dir.rstrip("/"), kind)
        write_wav(path, samples)
        print("%s  %.2f s" % (path, len(samples) / SAMPLE_RATE))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
