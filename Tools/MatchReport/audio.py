"""
audio.py — procedural cinematic audio bed for the post-match report.

Short-form social video lives or dies on sound, but we ship no licensed music.
This synthesizes a dark "military trailer" bed — sub drone + heartbeat pulse,
a riser into the winner reveal, an impact that resolves to a warm major chord —
timed to the render's scene plan. It is sound-DESIGN, not melody (drones, pulse,
riser, impact, resolve), which synthesizes convincingly and stays on-brand
(tense, tactical) without sounding like a cheap MIDI tune.

Override: drop a real track at assets/music.(wav|mp3|m4a|ogg) and the mux step in
render_report.py uses that instead — same "drop a file to override the procedural
look" philosophy as the diffusion art in assets.py. Fully offline, deterministic.
"""
import numpy as np, wave, os

SR = 44100

def _sine(freq, t, phase=0.0):
    return np.sin(2*np.pi*freq*t + phase)

def _seg_env(t, t0, t1, attack, release):
    """1.0 inside [t0,t1] with linear attack in / release out, 0 elsewhere."""
    e = np.zeros_like(t)
    inside = (t >= t0) & (t <= t1)
    e[inside] = 1.0
    a = (t >= t0) & (t < t0+attack)
    e[a] = (t[a]-t0)/max(attack,1e-6)
    r = (t > t1-release) & (t <= t1)
    e[r] = np.clip((t1-t[r])/max(release,1e-6), 0, 1)
    return e

def _lowpass(x, k=64):
    """cheap vectorised box low-pass (smooths white noise into a wind/rumble)."""
    if k <= 1: return x
    ker = np.ones(k)/k
    return np.convolve(x, ker, mode="same")

def _place(buf, sig, at_sec):
    i = int(at_sec*SR)
    j = min(len(buf), i+len(sig))
    if i < len(buf) and j > i:
        buf[i:j] += sig[:j-i]

def _kick(amp=0.9, f0=120, f1=44, dur=0.30):
    n = int(dur*SR); t = np.arange(n)/SR
    sweep = f1 + (f0-f1)*np.exp(-t/0.045)              # punchy downward pitch sweep
    ph = 2*np.pi*np.cumsum(sweep)/SR
    body = np.sin(ph)*np.exp(-t/0.16)
    click = (np.random.default_rng(1).standard_normal(n))*np.exp(-t/0.006)*0.4
    return amp*(body+click)

def _impact(dur=4.6):
    n = int(dur*SR); t = np.arange(n)/SR
    # deep boom (sub sweep, long tail)
    sweep = 30 + 40*np.exp(-t/0.10)
    boom = np.sin(2*np.pi*np.cumsum(sweep)/SR)*np.exp(-t/0.9)*1.0
    # bright noise burst that decays (cymbal/air)
    rng = np.random.default_rng(7)
    air = _lowpass(rng.standard_normal(n), 6)*np.exp(-t/0.7)*0.5
    return boom+air

def _riser(dur=2.7):
    n = int(dur*SR); t = np.arange(n)/SR
    rng = np.random.default_rng(9)
    # rising filtered noise
    noise = _lowpass(rng.standard_normal(n), 24)
    swell = (t/dur)**2.2
    # rising tone sweeping up an octave+
    f = 180*(2.0**(2.4*t/dur))
    tone = np.sin(2*np.pi*np.cumsum(f)/SR)*0.25
    return (noise*0.7 + tone)*swell

# Tasteful low roots (A1/G1/A#1/C2/F1) — seed picks one so different matches sit in different
# keys/tempos and a feed of reports never sounds like the same loop.
ROOTS = [55.00, 48.99, 58.27, 65.41, 43.65]

def build_bed(total_sec, climax_sec, fps=30, seed=0, winner="west"):
    """Return a float32 stereo array [N,2] in [-1,1] for the given timeline.
    seed varies the key (root) and tempo per match; winner is reserved for future mood tweaks."""
    N = int(total_sec*SR)
    t = np.arange(N)/SR
    out = np.zeros(N, np.float32)
    root = ROOTS[abs(int(seed)) % len(ROOTS)]

    intro_end = min(1.8, climax_sec*0.2)
    # --- sub drone: power chord (root+fifth+octave) under the whole match, swelling to climax ---
    swell = 0.5 + 0.5*np.clip((t-intro_end)/max(climax_sec-intro_end,1e-6),0,1)
    drone_env = _seg_env(t, 0.0, climax_sec+0.15, intro_end*0.9, 0.25)*swell
    drone = (_sine(root,t)*0.55 + _sine(root*1.5,t)*0.32 + _sine(root*2,t)*0.20)
    drone *= (0.9+0.1*_sine(0.13,t))                  # slow breathing LFO
    out += drone*drone_env*0.34

    # --- wind / rumble texture (very low) ---
    wind = _lowpass(np.random.default_rng(11).standard_normal(N), 200)
    wind /= (np.max(np.abs(wind))+1e-9)
    out += wind*_seg_env(t,0,total_sec,1.0,1.2)*0.05

    # --- heartbeat pulse from end-of-intro to the climax; intensifies over time ---
    bpm = 78.0 + (abs(int(seed)) % 7)*2.0; step = 60.0/bpm   # 78–90 BPM, seed-varied
    beat = intro_end
    while beat < climax_sec-0.05:
        frac = (beat-intro_end)/max(climax_sec-intro_end,1e-6)
        _place(out, _kick(amp=0.55+0.5*frac), beat)
        # offbeat tick during the busy combat third
        if frac > 0.55 and frac < 0.95:
            _place(out, _kick(amp=0.18, f0=180, f1=120, dur=0.10), beat+step/2)
        beat += step

    # --- riser into the winner reveal ---
    _place(out, _riser(2.7), max(0.0, climax_sec-2.7))

    # --- impact + warm MAJOR-chord resolve held to the end ---
    _place(out, _impact(min(4.8, total_sec-climax_sec+0.3)), climax_sec)
    res_n = N-int(climax_sec*SR); rt = np.arange(res_n)/SR
    r2 = root*2; third = r2*(2**(4/12)); fifth = r2*(2**(7/12))    # major triad on the octave
    chord = (_sine(root,rt)*0.5 + _sine(r2,rt)*0.4 + _sine(third,rt)*0.3 +
             _sine(fifth,rt)*0.3 + _sine(r2*2,rt)*0.15)            # warm, key follows the seed
    cenv = np.clip(rt/0.25,0,1)*np.clip((total_sec-climax_sec-rt)/0.9+1,0,1)
    res = np.zeros(N, np.float32); res[int(climax_sec*SR):] = chord*cenv*0.30
    out += res

    # --- master: soft-clip + global fades, light stereo widening ---
    out = np.tanh(out*1.15)
    out *= _seg_env(t,0,total_sec,0.25,1.1)
    peak = np.max(np.abs(out))+1e-9
    out = (out/peak)*0.92
    # gentle width: delay one channel a hair + tiny gain diff
    d = int(0.008*SR)
    right = np.concatenate([np.zeros(d,np.float32), out[:-d]]) if d < N else out
    stereo = np.stack([out, right*0.97], axis=1).astype(np.float32)
    return stereo

def write_wav(path, stereo, sr=SR):
    data = np.clip(stereo, -1, 1)
    pcm = (data*32767).astype("<i2")
    with wave.open(path, "w") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    return path

def find_track(base_dir):
    """Return a user-dropped real music track that should override the synth, if any."""
    for sub, name in [("assets","music")]:
        for ext in (".wav",".mp3",".m4a",".ogg",".flac"):
            p = os.path.join(base_dir, sub, name+ext)
            if os.path.exists(p): return p
    return None
