#!/usr/bin/env python3
"""Original looping background music for WhoIsThere v1.4.3.
Seamless loops via wrap-add: render loop + tail, fold the tail back onto the
start so any note ringing past the loop point continues cleanly at bar 1.
"""
import numpy as np
import soundfile as sf
import os

SR = 44100
rng = np.random.default_rng(20260722)
MU = '/home/user/WhoIsThere/assets/sounds'

def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)

def exp_decay(n, tau):
    return np.exp(-(np.arange(n) / SR) / tau)

def onepole_lp(x, cutoff):
    dt = 1.0 / SR
    rc = 1.0 / (2 * np.pi * cutoff)
    a = dt / (rc + dt)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y

def normalize(x, peak_db=-3.5):
    p = np.max(np.abs(x)) + 1e-12
    return x * (10 ** (peak_db / 20.0) / p)

def softclip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


class Track:
    """Renders into a buffer that is `loop_len` long plus a `tail` overhang;
    at the end the tail is folded back onto the start for a seamless loop."""
    def __init__(self, loop_sec, tail_sec=2.5):
        self.loop = int(loop_sec * SR)
        self.tail = int(tail_sec * SR)
        self.buf = np.zeros(self.loop + self.tail)

    def add(self, start_sec, samples):
        s = int(start_sec * SR)
        e = s + len(samples)
        if e <= len(self.buf):
            self.buf[s:e] += samples
        else:
            # wrap the overflow to the beginning
            head = len(self.buf) - s
            self.buf[s:] += samples[:head]
            rem = samples[head:]
            self.buf[:len(rem)] += rem[:len(self.buf)]

    def finish(self):
        loop = self.buf[:self.loop].copy()
        loop[:self.tail] += self.buf[self.loop:self.loop + self.tail]
        return loop


# ---- instrument voices ----
def pluck(freq, dur, amp=1.0, kind='tri', bright=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    if kind == 'tri':
        w = np.zeros(n)
        for k, h in enumerate([1, 3, 5, 7]):
            w += ((-1) ** k) / (h * h) * np.sin(2 * np.pi * freq * h * t)
        w *= 8 / np.pi ** 2
    else:  # soft saw-ish
        w = np.zeros(n)
        for h in range(1, 8):
            w += (1.0 / h) * np.sin(2 * np.pi * freq * h * t) * (bright ** (h - 1))
        w *= 0.5
    env = np.exp(-t / (dur * 0.35))
    atk = int(0.004 * SR)
    env[:atk] *= np.linspace(0, 1, atk)
    return onepole_lp(w * env, 3200 * bright) * amp

def pad(freqs, dur, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    w = np.zeros(n)
    for f in freqs:
        w += np.sin(2 * np.pi * f * t)
        w += 0.35 * np.sin(2 * np.pi * f * 1.005 * t)  # gentle chorus
    w /= len(freqs) * 1.35
    a = int(dur * 0.25 * SR); r = int(dur * 0.35 * SR)
    env = np.ones(n)
    env[:a] = np.linspace(0, 1, a)
    env[-r:] = np.linspace(1, 0, r)
    return onepole_lp(w * env, 1500) * amp

def bass(freq, dur, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    w = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t)
    env = np.exp(-t / (dur * 0.5))
    atk = int(0.006 * SR)
    env[:atk] *= np.linspace(0, 1, atk)
    return onepole_lp(w * env, 700) * amp

def bell(freq, dur, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    w = np.zeros(n)
    for h, a, dec in [(1, 1, 1.0), (2.01, 0.5, 0.7), (3.02, 0.3, 0.5), (4.9, 0.15, 0.3)]:
        w += a * np.sin(2 * np.pi * freq * h * t) * np.exp(-t / (dur * dec * 0.45))
    return w / 2.0 * amp

def shaker(dur, amp=1.0):
    n = int(dur * SR)
    w = rng.uniform(-1, 1, n) * np.exp(-(np.arange(n) / SR) / (dur * 0.25))
    # high-pass-ish
    w = w - onepole_lp(w, 5000)
    return w * amp


def chord(root_midi, quality='maj'):
    if quality == 'maj':
        return [root_midi, root_midi + 4, root_midi + 7]
    if quality == 'min':
        return [root_midi, root_midi + 3, root_midi + 7]
    return [root_midi, root_midi + 4, root_midi + 7]


# =========================================================
# MENU  — calm, friendly, C major, ~92 BPM, 16 bars
# =========================================================
def make_menu():
    bpm = 92
    beat = 60.0 / bpm
    bar = 4 * beat
    prog = [  # (root midi, quality)
        (48, 'maj'), (55, 'maj'), (57, 'min'), (53, 'maj'),  # C G Am F
        (48, 'maj'), (55, 'maj'), (53, 'maj'), (55, 'maj'),  # C G F G
    ] * 2  # 16 bars
    T = Track(len(prog) * bar, tail_sec=bar)
    for i, (root, q) in enumerate(prog):
        t0 = i * bar
        notes = chord(root + 12, q)  # pad an octave up
        T.add(t0, pad([midi(x) for x in notes], bar * 1.05, amp=0.5))
        T.add(t0, bass(midi(root), beat * 1.6, amp=0.7))
        T.add(t0 + 2 * beat, bass(midi(root), beat * 1.6, amp=0.55))
        # gentle arpeggio, eighth notes
        arp = [notes[0], notes[1], notes[2], notes[1],
               notes[0] + 12, notes[2], notes[1], notes[2]]
        for j, m in enumerate(arp):
            T.add(t0 + j * (beat / 2),
                  pluck(midi(m + 12), beat * 0.55, amp=0.22, kind='tri'))
    x = T.finish()
    return softclip(normalize(x, -6.0), 0.9)

# =========================================================
# LOBBY — light, waiting, A minor, ~104 BPM, 12 bars
# =========================================================
def make_lobby():
    bpm = 104
    beat = 60.0 / bpm
    bar = 4 * beat
    prog = [(45, 'min'), (53, 'maj'), (48, 'maj'), (55, 'maj')] * 3  # Am F C G
    T = Track(len(prog) * bar, tail_sec=bar)
    for i, (root, q) in enumerate(prog):
        t0 = i * bar
        notes = chord(root + 12, q)
        # sparse pad
        T.add(t0, pad([midi(x) for x in notes], bar * 0.98, amp=0.32))
        T.add(t0, bass(midi(root), beat * 1.4, amp=0.6))
        # plucky 16th-ish arpeggio pattern, light
        pat = [0, 1, 2, 1, 2, 1, 0, 1]
        for j, idx in enumerate(pat):
            m = notes[idx % 3] + (12 if j % 4 == 2 else 0)
            T.add(t0 + j * (beat / 2),
                  pluck(midi(m + 12), beat * 0.4, amp=0.2, kind='saw', bright=0.55))
        # soft shaker pulse on the beat
        for b in range(4):
            T.add(t0 + b * beat, shaker(beat * 0.3, amp=0.05))
    x = T.finish()
    return softclip(normalize(x, -6.5), 0.9)

# =========================================================
# WIN — celebratory, bright, C major, ~120 BPM, 8 bars
# =========================================================
def make_win():
    bpm = 120
    beat = 60.0 / bpm
    bar = 4 * beat
    prog = [(53, 'maj'), (55, 'maj'), (48, 'maj'), (48, 'maj'),  # F G C C
            (57, 'min'), (53, 'maj'), (55, 'maj'), (48, 'maj')]  # Am F G C
    T = Track(len(prog) * bar, tail_sec=bar)
    melody = [  # (bar, beat, midi) triumphant top line
        (0, 0, 72), (0, 2, 76), (1, 0, 79), (1, 2, 81),
        (2, 0, 84), (2, 1.5, 79), (3, 0, 84), (3, 2, 84),
        (4, 0, 76), (4, 2, 79), (5, 0, 81), (5, 2, 77),
        (6, 0, 74), (6, 2, 79), (7, 0, 84), (7, 2, 84),
    ]
    for i, (root, q) in enumerate(prog):
        t0 = i * bar
        notes = chord(root + 12, q)
        T.add(t0, pad([midi(x) for x in notes], bar * 1.02, amp=0.42))
        # driving root-fifth bass on each beat
        for b in range(4):
            f = midi(root) if b % 2 == 0 else midi(root + 7)
            T.add(t0 + b * beat, bass(f, beat * 0.9, amp=0.6))
        # chord stabs on off-beats
        for b in (1, 3):
            for m in notes:
                T.add(t0 + b * beat, pluck(midi(m + 12), beat * 0.5, amp=0.16, kind='tri'))
    for b, bt, m in melody:
        T.add(b * bar + bt * beat, bell(midi(m), beat * 1.4, amp=0.5))
    x = T.finish()
    return softclip(normalize(x, -5.5), 0.95)


def save_mp3(name, x, peak_db=-3.5):
    x = normalize(np.asarray(x, dtype=np.float64), peak_db).astype(np.float32)
    path = os.path.join(MU, name)
    sf.write(path, x, SR, format='MP3', bitrate_mode='CONSTANT',
             compression_level=0.4)
    print(f'  {name:18s} {len(x)/SR:6.2f}s loop  {os.path.getsize(path)//1024:5d}KB')

print('MUSIC (assets/sounds/*.mp3):')
save_mp3('music_menu.mp3', make_menu(), -4.5)
save_mp3('music_lobby.mp3', make_lobby(), -5.0)
save_mp3('music_win.mp3', make_win(), -4.0)
print('MUSIC done.')

# --- seamless-loop self-check: energy continuity across the loop point ---
print('\nLoop continuity check (RMS of |end - start| over 20ms window):')
for name in ('music_menu.mp3', 'music_lobby.mp3', 'music_win.mp3'):
    data, _ = sf.read(os.path.join(MU, name))
    if data.ndim > 1:
        data = data.mean(axis=1)
    w = int(0.02 * SR)
    seam = np.sqrt(np.mean((data[-w:] - data[:w]) ** 2))
    overall = np.sqrt(np.mean(data ** 2))
    print(f'  {name:18s} seam_rms={seam:.4f}  track_rms={overall:.4f}  ratio={seam/overall:.2f}')
