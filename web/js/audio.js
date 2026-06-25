/* =============================================================================
 * audio.js — procedural sound via WebAudio. No asset files: every sound is
 * synthesised from oscillators + noise. Cheap, throttled, and fully optional.
 * ========================================================================== */

const Sound = (() => {
  "use strict";
  let ctx = null, master = null, enabled = true, volume = 0.6;
  let noiseBuf = null;
  let lastShot = 0, shotBudget = 0;

  function load() {
    try {
      const v = localStorage.getItem("wasp_vol");
      if (v != null) volume = Math.max(0, Math.min(1, parseFloat(v)));
      const e = localStorage.getItem("wasp_snd");
      if (e != null) enabled = e === "1";
    } catch (_) {}
  }
  load();

  function init() {
    if (ctx) return;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) { enabled = false; return; }
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = volume;
    master.connect(ctx.destination);
    // pre-bake a noise buffer
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 0.5, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  function resume() { if (ctx && ctx.state === "suspended") ctx.resume(); }

  const now = () => (ctx ? ctx.currentTime : 0);

  function noise(dur, gain, filterType, freq, q) {
    if (!ctx) return;
    const src = ctx.createBufferSource(); src.buffer = noiseBuf;
    const f = ctx.createBiquadFilter();
    f.type = filterType || "lowpass"; f.frequency.value = freq || 1000; f.Q.value = q || 1;
    const g = ctx.createGain();
    const t = now();
    g.gain.setValueAtTime(gain, t);
    g.gain.exponentialRampToValueAtTime(0.0008, t + dur);
    src.connect(f); f.connect(g); g.connect(master);
    src.start(t); src.stop(t + dur);
  }

  function tone(freq, dur, gain, type, slideTo) {
    if (!ctx) return;
    const o = ctx.createOscillator(); o.type = type || "sine";
    const g = ctx.createGain();
    const t = now();
    o.frequency.setValueAtTime(freq, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    g.gain.setValueAtTime(gain, t);
    g.gain.exponentialRampToValueAtTime(0.0008, t + dur);
    o.connect(g); g.connect(master);
    o.start(t); o.stop(t + dur);
  }

  // --- public sound effects -------------------------------------------------
  const api = {
    get enabled() { return enabled; },
    get volume() { return volume; },
    init, resume,

    setVolume(v) {
      volume = Math.max(0, Math.min(1, v));
      if (master) master.gain.value = enabled ? volume : 0;
      try { localStorage.setItem("wasp_vol", String(volume)); } catch (_) {}
    },
    setEnabled(on) {
      enabled = !!on;
      if (master) master.gain.value = enabled ? volume : 0;
      try { localStorage.setItem("wasp_snd", enabled ? "1" : "0"); } catch (_) {}
    },

    // gunfire — heavily throttled so 40 units don't blow out the mix
    shot(kind, t) {
      if (!enabled || !ctx) return;
      // refill a small budget over time
      shotBudget = Math.min(4, shotBudget + (t - lastShot) * 12);
      lastShot = t;
      if (shotBudget < 1) return;
      shotBudget -= 1;
      if (kind === "arty") { noise(0.18, 0.5, "lowpass", 600, 1); tone(120, 0.18, 0.25, "square", 60); }
      else if (kind === "cannon") { noise(0.14, 0.45, "lowpass", 900, 1); tone(90, 0.12, 0.3, "sawtooth", 50); }
      else noise(0.05, 0.22, "highpass", 1400, 0.7);
    },

    explosion(size) {
      if (!enabled || !ctx) return;
      const s = size || 1;
      noise(0.4 * s, 0.6, "lowpass", 380, 0.8);
      tone(70, 0.35 * s, 0.4, "sawtooth", 30);
    },

    capture(good) {
      if (!enabled || !ctx) return;
      const base = good ? 440 : 300;
      tone(base, 0.16, 0.3, "triangle");
      setTimeout(() => tone(good ? base * 1.5 : base * 0.7, 0.22, 0.3, "triangle"), 130);
    },

    build() { if (enabled && ctx) { tone(520, 0.1, 0.25, "square"); setTimeout(() => tone(780, 0.14, 0.22, "square"), 90); } },
    ui() { if (enabled && ctx) tone(660, 0.04, 0.12, "square"); },
    deny() { if (enabled && ctx) tone(180, 0.12, 0.2, "sawtooth", 120); },
    alert() {
      if (!enabled || !ctx) return;
      tone(880, 0.12, 0.28, "square"); setTimeout(() => tone(880, 0.12, 0.28, "square"), 180);
    },
    power() {
      if (!enabled || !ctx) return;
      tone(300, 0.25, 0.3, "sawtooth", 700);
    },
    win() { if (enabled && ctx) { [523, 659, 784, 1046].forEach((f, i) => setTimeout(() => tone(f, 0.3, 0.3, "triangle"), i * 150)); } },
    lose() { if (enabled && ctx) { [392, 330, 262, 196].forEach((f, i) => setTimeout(() => tone(f, 0.4, 0.3, "sawtooth"), i * 200)); } },
  };
  return api;
})();
