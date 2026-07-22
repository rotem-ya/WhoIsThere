#!/usr/bin/env python3
"""Original audio synthesis for WhoIsThere v1.4.3.
Generates 8 SFX (.ogg) + 3 looping music tracks (.mp3).
All content is procedurally generated from scratch -> no licensing concerns.
"""
import numpy as np
import soundfile as sf
import os

SR = 44100
rng = np.random.default_rng(1729)  # deterministic

UI = '/home/user/WhoIsThere/assets/sounds/ui'
MU = '/home/user/WhoIsThere/assets/sounds'

# ---------- helpers ----------
def sine(f, t, phase=0.0):
    return np.sin(2 * np.pi * f * t + phase)

def tri(f, t):
    # band-limited-ish triangle via a few odd harmonics
    y = np.zeros_like(t)
    for k, n in enumerate([1, 3, 5, 7, 9]):
        y += ((-1) ** k) / (n * n) * np.sin(2 * np.pi * f * n * t)
    return (8 / (np.pi ** 2)) * y

def env_adsr(n, a, d, s, r, sr=SR):
    a, d, r = int(a * sr), int(d * sr), int(r * sr)
    a = max(a, 1); d = max(d, 1); r = max(r, 1)
    sus = max(n - a - d - r, 0)
    e = np.concatenate([
        np.linspace(0, 1, a, endpoint=False),
        np.linspace(1, s, d, endpoint=False),
        np.full(sus, s),
        np.linspace(s, 0, r),
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]

def exp_decay(n, tau, sr=SR):
    t = np.arange(n) / sr
    return np.exp(-t / tau)

def noise(n):
    return rng.uniform(-1, 1, n)

def onepole_lp(x, cutoff, sr=SR):
    dt = 1.0 / sr
    rc = 1.0 / (2 * np.pi * cutoff)
    a = dt / (rc + dt)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y

def onepole_hp(x, cutoff, sr=SR):
    return x - onepole_lp(x, cutoff, sr)

def svf_bandpass(x, f0, q, sr=SR):
    # state-variable filter, f0 can be an array (sweep)
    f0 = np.atleast_1d(f0)
    if len(f0) == 1:
        f0 = np.full(len(x), f0[0])
    low = band = 0.0
    out = np.empty_like(x)
    for i in range(len(x)):
        fc = 2 * np.sin(np.pi * min(f0[i], sr * 0.45) / sr)
        high = x[i] - low - (1.0 / q) * band
        band = band + fc * high
        low = low + fc * band
        out[i] = band
    return out

def normalize(x, peak_db=-3.0):
    p = np.max(np.abs(x)) + 1e-12
    target = 10 ** (peak_db / 20.0)
    return x * (target / p)

def softclip(x):
    return np.tanh(x)

def fade_edges(x, ms=4):
    n = int(ms / 1000 * SR)
    n = min(n, len(x) // 2)
    if n > 0:
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    return x

def save_ogg(name, x, peak_db=-2.0):
    x = normalize(fade_edges(np.asarray(x, dtype=np.float64)), peak_db).astype(np.float32)
    path = os.path.join(UI, name)
    sf.write(path, x, SR, format='OGG', subtype='VORBIS')
    print(f'  {name:22s} {len(x)/SR:5.2f}s  {os.path.getsize(path):6d}B')

def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)

def tone(freq, dur, a=0.005, d=0.05, s=0.6, r=0.08, kind='sine', detune=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    if kind == 'sine':
        w = sine(freq, t)
        if detune:
            w = 0.6 * w + 0.4 * sine(freq * (1 + detune), t)
    elif kind == 'tri':
        w = tri(freq, t)
    elif kind == 'bell':
        w = np.zeros(n)
        for h, amp, dec in [(1, 1.0, 1.0), (2.01, 0.5, 0.7), (3.01, 0.28, 0.5),
                            (4.7, 0.18, 0.35), (5.4, 0.1, 0.25)]:
            w += amp * sine(freq * h, t) * exp_decay(n, dec * r * 4)
        w /= 2.0
    else:
        w = sine(freq, t)
    return w * env_adsr(n, a, d, s, r)


# =========================================================
# SFX
# =========================================================
def sfx_transition():
    # short flying whoosh: filtered noise, pitch sweep up then down
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    x = t / t[-1]
    sweep = 500 + 3500 * np.sin(np.pi * x)  # up then down
    nz = noise(n)
    bp = svf_bandpass(nz, sweep, q=6)
    body = bp * (np.sin(np.pi * x) ** 1.4)
    # a touch of airy sine following the sweep
    air = 0.25 * np.sin(2 * np.pi * np.cumsum(sweep) / SR) * (np.sin(np.pi * x) ** 2)
    return body * 0.9 + air

def sfx_streak():
    # rising ping, intensifying (3-note quick upward arpeggio + bright tail)
    dur = 0.3
    n = int(dur * SR)
    y = np.zeros(n)
    notes = [midi(72), midi(76), midi(79), midi(84)]
    for i, f in enumerate(notes):
        start = int(i * 0.045 * SR)
        seg = tone(f, dur - i * 0.045, a=0.002, d=0.03, s=0.4, r=0.12,
                   kind='bell') * (0.6 + 0.15 * i)
        y[start:start + len(seg)] += seg[:n - start]
    return y

def sfx_tile_flip():
    # card flip, v2: airy downward swish (the card turning over) landing on a
    # soft woody tap (the card settling). Self-contained RNG so it can be
    # regenerated in isolation without shifting the other effects' noise.
    lr = np.random.default_rng(4242)
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    x = t / t[-1]
    # airy swish: bandpass noise sweeping downward, smooth single hump
    sweep = 2800 * np.exp(-3.0 * x) + 750
    nz = lr.uniform(-1, 1, n)
    swish = svf_bandpass(nz, sweep, q=2.2)
    swish *= np.sin(np.pi * np.clip(x / 0.7, 0, 1)) ** 1.3
    swish = onepole_hp(swish, 450)
    # soft woody tap near the end (card lays down)
    ts = int(0.11 * SR)
    m = n - ts
    tt = np.arange(m) / SR
    click = lr.uniform(-1, 1, m) * exp_decay(m, 0.004)
    click = onepole_hp(click, 1800)
    wood = np.sin(2 * np.pi * 205 * tt) * exp_decay(m, 0.02)
    tap = onepole_lp(click, 6000) * 0.6 + onepole_lp(wood, 900) * 0.5
    y = swish * 0.7
    y[ts:] += tap
    return y

def sfx_coin_shower():
    # rich coin cascade: many bright metallic tings, dense then thinning.
    # v2: slower and more spread out (1.3s) so it breathes with the slower coin
    # fly. Own local RNG so it regenerates in isolation.
    lr = np.random.default_rng(9021)
    dur = 1.3
    n = int(dur * SR)
    y = np.zeros(n)
    count = 60
    for _ in range(count):
        # earlier = denser, but the tail lingers longer than before
        pos = lr.beta(1.5, 2.8)
        start = int(pos * (dur - 0.16) * SR)
        base = lr.uniform(1300, 2500)
        d = lr.uniform(0.06, 0.16)
        m = int(d * SR)
        tt = np.arange(m) / SR
        w = np.zeros(m)
        for h, a in [(1, 1.0), (2.76, 0.6), (5.4, 0.35), (8.2, 0.18)]:
            w += a * np.sin(2 * np.pi * base * h * tt)
        w *= exp_decay(m, d * 0.42)
        amp = lr.uniform(0.5, 1.0) * (1.0 - 0.30 * pos)
        end = min(start + m, n)
        y[start:end] += w[:end - start] * amp
    return softclip(y * 0.46)

def sfx_appear():
    # soft "pop" for something appearing (dialog / overlay). A gentle upward
    # blip, lowpassed and short, so it stays subtle when things pop in often.
    n = int(0.17 * SR)
    t = np.arange(n) / SR
    x = t / t[-1]
    pitch = 380 + 360 * np.clip(x / 0.6, 0, 1)  # rise then hold
    body = np.sin(2 * np.pi * np.cumsum(pitch) / SR)
    body += 0.3 * np.sin(2 * np.pi * 2 * np.cumsum(pitch) / SR)  # soft harmonic
    env = np.exp(-t / 0.06)
    atk = int(0.006 * SR)
    env[:atk] *= np.linspace(0, 1, atk)
    spark = 0.18 * np.sin(2 * np.pi * 1500 * t) * np.exp(-t / 0.03)
    return onepole_lp(body * env, 2600) * 0.9 + spark

def sfx_spin_tick():
    # single sharp ratchet tick
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    click = noise(n) * exp_decay(n, 0.006)
    click = onepole_hp(click, 2000)
    ping = 0.5 * sine(2400, t) * exp_decay(n, 0.012)
    return click + ping

def sfx_spin_land():
    # satisfying "thunk": low-mid thump + short click
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    x = t / t[-1]
    pitch = 220 * np.exp(-3.5 * x) + 90  # drop
    body = np.sin(2 * np.pi * np.cumsum(pitch) / SR) * exp_decay(n, 0.09)
    click = noise(n) * exp_decay(n, 0.004) * 0.5
    ring = 0.25 * sine(midi(64), t) * exp_decay(n, 0.12)
    return onepole_lp(body, 1200) + onepole_hp(click, 1500) + ring

def sfx_quest_complete():
    # cheerful short jingle: ascending major arpeggio + sparkle
    dur = 0.7
    n = int(dur * SR)
    y = np.zeros(n)
    notes = [(midi(67), 0.0), (midi(71), 0.09), (midi(74), 0.18), (midi(79), 0.27)]
    for f, st in notes:
        start = int(st * SR)
        seg = tone(f, dur - st, a=0.004, d=0.06, s=0.5, r=0.22, kind='bell')
        y[start:start + len(seg)] += seg[:n - start] * 0.9
    # final shimmer
    sh = tone(midi(86), 0.3, a=0.003, d=0.05, s=0.3, r=0.24, kind='bell')
    s0 = int(0.34 * SR)
    y[s0:s0 + len(sh)] += sh[:n - s0] * 0.4
    return y

def sfx_heartbeat():
    # single muffled lub-dub
    n = int(0.34 * SR)
    y = np.zeros(n)
    def thump(freq, tau, mlen):
        m = int(mlen * SR)
        t = np.arange(m) / SR
        x = t / t[-1]
        p = freq * np.exp(-6 * x) + freq * 0.6
        w = np.sin(2 * np.pi * np.cumsum(p) / SR) * exp_decay(m, tau)
        return onepole_lp(w, 260)
    lub = thump(75, 0.05, 0.16)
    dub = thump(62, 0.06, 0.18)
    y[:len(lub)] += lub
    s = int(0.15 * SR)
    y[s:s + len(dub)] += dub[:n - s] * 0.85
    return y


sfx = {
    'transition.ogg': sfx_transition,
    'streak.ogg': sfx_streak,
    'tile_flip.ogg': sfx_tile_flip,
    'coin_shower.ogg': sfx_coin_shower,
    'spin_tick.ogg': sfx_spin_tick,
    'spin_land.ogg': sfx_spin_land,
    'quest_complete.ogg': sfx_quest_complete,
    'heartbeat.ogg': sfx_heartbeat,
    'appear.ogg': sfx_appear,
}

peaks = {'coin_shower.ogg': -2.5, 'heartbeat.ogg': -4.0, 'spin_tick.ogg': -3.0,
         'tile_flip.ogg': -5.0, 'appear.ogg': -6.0}


def generate(only=None):
    """Write the SFX. Pass only={'tile_flip.ogg', ...} to regenerate a subset
    (each effect is deterministic in isolation for the noise-independent ones;
    tile_flip uses its own local RNG)."""
    print('SFX (assets/sounds/ui/*.ogg):')
    for name, fn in sfx.items():
        if only and name not in only:
            continue
        save_ogg(name, fn(), peak_db=peaks.get(name, -2.0))
    print('SFX done.')


if __name__ == '__main__':
    import sys
    generate(only=set(sys.argv[1:]) or None)
