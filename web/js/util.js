/* =============================================================================
 * util.js — math, camera, rng, small helpers. No game logic here.
 * ========================================================================== */

const U = (() => {
  "use strict";

  const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);
  const lerp = (a, b, t) => a + (b - a) * t;
  const dist2 = (ax, ay, bx, by) => {
    const dx = ax - bx, dy = ay - by;
    return dx * dx + dy * dy;
  };
  const dist = (ax, ay, bx, by) => Math.sqrt(dist2(ax, ay, bx, by));

  // Deterministic-ish RNG (mulberry32) so matches can be seeded if desired.
  function makeRng(seed) {
    let a = seed >>> 0;
    return function () {
      a |= 0; a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  const rngRange = (rng, lo, hi) => lo + rng() * (hi - lo);
  const pick = (rng, arr) => arr[Math.floor(rng() * arr.length)];

  function fmtTime(sec) {
    sec = Math.max(0, Math.floor(sec));
    const m = Math.floor(sec / 60), s = sec % 60;
    return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  }

  function fmtNum(n) {
    n = Math.floor(n);
    if (n >= 10000) return (n / 1000).toFixed(1).replace(/\.0$/, "") + "k";
    return n.toLocaleString("en-US");
  }

  /* Camera: maps world <-> screen with pan + zoom, clamped to world bounds. */
  function makeCamera(world, view) {
    return {
      x: 0, y: 0, zoom: 1, minZoom: 0.45, maxZoom: 1.8,
      world, view,
      setView(w, h) { this.view = { w, h }; this.clampPan(); },
      worldToScreen(wx, wy) {
        return { x: (wx - this.x) * this.zoom, y: (wy - this.y) * this.zoom };
      },
      screenToWorld(sx, sy) {
        return { x: sx / this.zoom + this.x, y: sy / this.zoom + this.y };
      },
      panBy(dx, dy) { this.x += dx; this.y += dy; this.clampPan(); },
      centerOn(wx, wy) {
        this.x = wx - this.view.w / (2 * this.zoom);
        this.y = wy - this.view.h / (2 * this.zoom);
        this.clampPan();
      },
      zoomAt(sx, sy, factor) {
        const before = this.screenToWorld(sx, sy);
        this.zoom = clamp(this.zoom * factor, this.minZoom, this.maxZoom);
        const after = this.screenToWorld(sx, sy);
        this.x += before.x - after.x;
        this.y += before.y - after.y;
        this.clampPan();
      },
      clampPan() {
        const vw = this.view.w / this.zoom, vh = this.view.h / this.zoom;
        if (vw >= this.world.w) this.x = (this.world.w - vw) / 2;
        else this.x = clamp(this.x, 0, this.world.w - vw);
        if (vh >= this.world.h) this.y = (this.world.h - vh) / 2;
        else this.y = clamp(this.y, 0, this.world.h - vh);
      },
    };
  }

  // Round-rect path helper.
  function roundRect(ctx, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  return { clamp, lerp, dist, dist2, makeRng, rngRange, pick, fmtTime, fmtNum, makeCamera, roundRect };
})();
