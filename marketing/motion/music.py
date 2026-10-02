"""Soundtrack for the QuiX motion piece: 15 s at 120 BPM, every hit on the picture's beats.

0 – 4.5   tension: the 3 lands on 0.5, a ticking pulse under the running timecode, the wall flies in,
          the music drops out for the scan, three pings for the three moments, a riser
4.5 – 12.5 the drop: four-on-the-floor, offbeat chord stabs, bass; every UI event has its sound,
          pitched on the chord of the moment and sent through the same room
12.5 – 15 the resolve: one big hit on C, the chord rings out under the end card

Synthesised with numpy alone.   python3 music.py → music.wav (48 kHz stereo)
"""
import numpy as np, wave, pathlib

SR, DUR = 48000, 15.0
N = int(SR * DUR)
rng = np.random.default_rng(11)
T = np.arange(N) / SR

def hz(m): return 440.0 * 2 ** ((m - 69) / 12)
def at(t): return int(round(t * SR))
def tt(d): return np.arange(int(d * SR)) / SR

def filt(x, lo=0.0, hi=None, slope=2.0):
    n = 1 << int(np.ceil(np.log2(len(x) + 1)))
    X = np.fft.rfft(x, n); f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo: g *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * slope))
    if hi: g *= 1 / np.sqrt(1 + (f / hi) ** (2 * slope))
    return np.fft.irfft(X * g, n)[:len(x)]

BUS = {k: np.zeros((2, N)) for k in ("music", "drums", "fx", "send")}
def add(sig, t0, gain=1.0, pan=0.0, send=0.0, bus="fx"):
    i = at(t0); j = min(N, i + len(sig))
    if t0 < 0 or i >= N or j <= i: return
    s = sig[: j - i] * gain
    gl, gr = np.cos((pan + 1) * np.pi / 4) * 1.414, np.sin((pan + 1) * np.pi / 4) * 1.414
    BUS[bus][0, i:j] += s * gl; BUS[bus][1, i:j] += s * gr
    if send:
        BUS["send"][0, i:j] += s * send * gl; BUS["send"][1, i:j] += s * send * gr

# Harmony: Am pedal for the tension, then Am F C G from the drop, C for the end card.
CH = [(0, "Am"), (4.5, "Am"), (6.5, "F"), (8.5, "C"), (10.5, "G"), (12.5, "C")]
VO = {"Am": (45, [57, 60, 64, 69]), "F": (41, [53, 57, 60, 65]), "C": (48, [55, 60, 64, 67]), "G": (43, [55, 59, 62, 67])}
def chord(t):
    n = CH[0][1]
    for s, c in CH:
        if t >= s: n = c
    return n

def saw(f, d, h=10, roll=1.5):
    x = tt(d)
    return sum(np.sin(2 * np.pi * f * k * x + k) / k ** roll for k in range(1, h + 1))

# ── sound design
def impact(t, g=1.0, big=False):
    d = 1.6 if big else 0.9; x = tt(d)
    f = 50 + 90 * np.exp(-x / 0.05)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x / (0.32 if big else 0.18))
    nz = filt(rng.standard_normal(len(x)), lo=300, hi=9000) * np.exp(-x / 0.09)
    add(np.tanh(1.8 * sub) * 0.9 + nz * 0.35, t, 0.5 * g, send=0.25, bus="drums")
def riser(t_end, d, g=0.12):
    x = tt(d); k = x / d
    nz = rng.standard_normal(len(x))
    lo_b, hi_b = filt(nz, lo=300, hi=1500), filt(nz, lo=2500, hi=11000)
    sig = (lo_b * (1 - k) + hi_b * k) * k ** 2.2
    tone = np.sin(2 * np.pi * np.cumsum(220 * 2 ** (2.5 * k)) / SR) * k ** 3 * 0.25
    add(sig + tone, t_end - d, g, send=0.5)
def whoosh(t_c, d=0.45, g=0.1, up=True):
    x = tt(d); k = x / d
    nz = rng.standard_normal(len(x))
    a, b = filt(nz, lo=200, hi=1200), filt(nz, lo=1800, hi=8000)
    mix = (a * (1 - k) + b * k) if up else (a * k + b * (1 - k))
    env = np.sin(np.pi * k) ** 2
    add(mix * env, t_c - d / 2, g, pan=0.0, send=0.4)
def ping(t, m, g=0.14, d=0.9):
    x = tt(d)
    s = (np.sin(2 * np.pi * hz(m) * x) + 0.3 * np.sin(2 * np.pi * hz(m) * 2.01 * x) * np.exp(-x / 0.08)) * np.exp(-x / 0.22)
    add(s * np.minimum(1, x / 0.002), t, g, send=0.65)
def tick(t, g=0.06, f=2400):
    x = tt(0.03)
    add(np.sin(2 * np.pi * f * x) * np.exp(-x / 0.006), t, g, send=0.1)
def click(t, g=0.25):
    x = tt(0.04)
    add(filt(rng.standard_normal(len(x)), lo=1500, hi=9000) * np.exp(-x / 0.005), t, g, send=0.15)
    add(np.sin(2 * np.pi * 160 * x) * np.exp(-x / 0.012), t, g * 1.2)
def blip(t, m, g=0.1, d=0.35):
    x = tt(d)
    add((np.sin(2 * np.pi * hz(m) * x) + 0.15 * np.sin(4 * np.pi * hz(m) * x)) * np.exp(-x / 0.09) * np.minimum(1, x / 0.002), t, g, send=0.5)
def zip_(t, d=0.35, f0=300, f1=2400, g=0.06):
    x = tt(d); k = x / d
    f = f0 * (f1 / f0) ** k
    add(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * k) ** 2, t, g, send=0.3)
def chirp(t, g=0.08):
    x = tt(0.07); f = 1800 + 2600 * (x / 0.07)
    add(np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3 * np.exp(-x / 0.03), t, g, send=0.2)
def kick(t, g=0.32):
    x = tt(0.45); f = 46 + 80 * np.exp(-x / 0.03)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x / 0.18) + 0.25 * np.exp(-x / 0.003) * rng.standard_normal(len(x))
    add(np.tanh(1.6 * s), t, g, bus="drums")
def snare(t, g=0.16):
    x = tt(0.3)
    s = filt(rng.standard_normal(len(x)), lo=1000, hi=7000) * np.exp(-x / 0.08) + 0.6 * np.sin(2 * np.pi * 185 * x) * np.exp(-x / 0.04)
    add(s, t, g, send=0.35, bus="drums")
def hat(t, g=0.05, d=0.025, pan=0.25):
    x = tt(0.09)
    add(filt(rng.standard_normal(len(x)), lo=7500, hi=15000) * np.exp(-x / d), t, g, pan=pan, send=0.05, bus="drums")

# ── tension (0 – 4.5)
riser(0.5, 0.5, 0.16)
impact(0.5, 1.0)
for i in range(5): tick(0.5 + i * 0.05, 0.05, 1800 + 300 * i)          # H O U R S pop out
x = tt(4.6)
drone = (saw(hz(33), 4.6, h=12, roll=1.2) * 0.5 + saw(hz(45), 4.6, h=8) * 0.5)
drone = filt(drone, lo=70, hi=700) * np.minimum(1, x / 0.4) * np.clip((4.6 - x) / 0.3, 0, 1)
drone *= np.where(x < 3.1, 1, np.exp(-(x - 3.1) / 0.25) * 0.6 + 0.4)         # thins out for the scan
add(drone, 0.0, 0.035, send=0.3, bus="music")
for i in range(1, 6):                                                      # the pulse under the timecode
    for j in (0, 0.25):
        t = i * 0.5 + j
        if t >= 3.0: continue
        bx = tt(0.2); add(np.sin(2 * np.pi * hz(45) * bx) * np.exp(-bx / 0.08), t, 0.09, bus="music")
        hat(t + 0.125, 0.035)
for i in range(2, 12): tick(0.6 + i * 0.22, 0.025, 3200)                   # the timecode racing
whoosh(1.62, 0.35, 0.07)                                                   # of footage rises
whoosh(2.75, 0.7, 0.16)                                                    # the wall flies in
impact(3.0, 0.35)
zip_(3.12, 0.5, 400, 3000, 0.05)                                           # the scan
for k, m in enumerate((76, 81, 84)): ping(3.5 + 0.25 * k, m, 0.16)         # three moments
riser(4.5, 0.55, 0.18)

# ── the drop (4.5 – 12.5)
impact(4.5, 1.1)
duck = np.ones(N)
for i in range(16):
    t = 4.5 + i * 0.5
    kick(t)
    j = at(t); k2 = min(N, j + at(0.28)); duck[j:k2] = np.minimum(duck[j:k2], 1 - 0.55 * np.exp(-np.arange(k2 - j) / SR / 0.09))
    if i % 2: snare(t)
    hat(t + 0.25, 0.06); hat(t + 0.125, 0.025, pan=-0.3); hat(t + 0.375, 0.025, pan=-0.3)
    # offbeat chord stab
    c = VO[chord(t)][1]; sx = tt(0.22)
    stab = sum(saw(hz(m), 0.22, h=9) for m in c) * np.exp(-sx / 0.07) * np.minimum(1, sx / 0.004)
    add(filt(stab, lo=180, hi=4200), t + 0.25, 0.035, pan=0.2 if i % 2 else -0.2, send=0.35, bus="music")
for i in range(32):                                                        # bass on eighths
    t = 4.5 + i * 0.25
    r = VO[chord(t)][0] + (12 if i % 4 == 2 else 0); bx = tt(0.23)
    b = (np.sin(2 * np.pi * hz(r) * bx) + 0.3 * np.sin(4 * np.pi * hz(r) * bx) + 0.1 * np.sin(6 * np.pi * hz(r) * bx)) * np.exp(-bx / 0.12) * np.minimum(1, bx / 0.004)
    add(filt(b, hi=1100), t, 0.11, bus="music")
for s, e in ((4.5, 6.5), (6.5, 8.5), (8.5, 10.5), (10.5, 12.5)):          # pad under the drop
    d = e - s + 0.3; px = tt(d)
    pad = sum(saw(hz(m), d, h=8, roll=1.7) for m in VO[chord(s)][1][:3])
    add(filt(pad, hi=2600) * np.minimum(1, px / 0.2) * np.clip((d - px) / 0.3, 0, 1), s, 0.012, pan=0, send=0.6, bus="music")

# UI and picture events, pitched on the chord of the moment
click(5.5, 0.28); impact(5.5, 0.4); ping(5.5, 84, 0.12); ping(5.52, 88, 0.08)   # the side button, the shockwave
whoosh(5.9, 0.8, 0.06, up=False)
whoosh(6.55, 0.4, 0.17)                                                   # whip pan
zip_(6.5, 0.35, 200, 1600, 0.06)                                          # the cable plugs in
for i in range(6):                                                        # copy, verify, land in the folder
    c0 = 6.92 + i * 0.15
    tick(c0, 0.03, 2000); tick(c0 + 0.15, 0.05, 3000)
    land = c0 + 0.45
    blip(land, [69, 72, 76, 72, 77, 81][i] if i % 2 == 0 else [57, 60, 64, 60, 65, 69][i], 0.09)
whoosh(8.45, 0.4, 0.1)                                                    # the bar stretches into the file
for k, t in enumerate((8.95, 9.2, 9.45)): chirp(t, 0.07)                 # three seeks
for i in range(14): tick(8.97 + i * 0.045, 0.02, 2600 + 90 * i)          # the counter rolls to 34 KB
for k in range(3): ping(9.75 + 0.08 * k, [79, 84, 88][k], 0.07, 0.5)     # stars
whoosh(10.5, 0.45, 0.15)                                                  # the scene lifts, the menu bar falls
blip(10.75, 79, 0.08); blip(10.9, 84, 0.07)                              # icon, popover
for k in range(3): tick(11.0 + 0.11 * k, 0.04, 2800)                     # counters
click(11.5, 0.2); whoosh(11.75, 0.4, 0.07)                               # Open highlights, the folder opens

# ── the resolve (12.5 – 15)
riser(12.5, 0.6, 0.14)
impact(12.5, 1.2, big=True)
d = 2.5; px = tt(d)
final = sum(saw(hz(m), d, h=9, roll=1.6) for m in [48, 55, 60, 64, 67])
add(filt(final, hi=3600) * np.exp(-px / 1.4) * np.minimum(1, px / 0.01), 12.5, 0.03, send=0.7, bus="music")
for k, m in enumerate((72, 76, 79, 84)): ping(12.75 + 0.23 * k, m, 0.08, 1.2)   # the words land
for i in range(4): hat(12.5 + i * 0.5 + 0.25, 0.03)

# ── mix: sidechain the music, room, master
room_n = int(1.8 * SR); rx = np.arange(room_n) / SR
irs = [filt(rng.standard_normal(room_n), lo=250, hi=6500) * np.exp(-rx / 0.38) for _ in range(2)]
irs = [ir / np.sqrt((ir ** 2).sum()) for ir in irs]
def conv(x, ir):
    n = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    return np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[:len(x)]
wet = np.stack([conv(BUS["send"][c], irs[c]) for c in range(2)])
mix = BUS["music"] * duck + BUS["drums"] + BUS["fx"] + wet * 0.32
mix = np.stack([filt(mix[c], lo=40, hi=17000) for c in range(2)])
mix *= np.clip((DUR - T) / 0.6, 0, 1) ** 1.3                               # ring out into the last frame
mix /= np.abs(mix).max()
mix = np.tanh(1.6 * mix) / np.tanh(1.6) * 0.89                             # soft limiter
out = (mix.T * 32767).astype(np.int16)
with wave.open(str(pathlib.Path(__file__).with_name("music.wav")), "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(out.tobytes())
print("music.wav", DUR, "s")
