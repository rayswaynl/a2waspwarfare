/* =============================================================================
 * render.js — all canvas drawing for the main board + minimap.
 * Pure presentation: reads game state, never mutates it.
 * ========================================================================== */

const Render = (() => {
  "use strict";
  const { FACTIONS } = DATA;

  // Terrain decoration, rebuilt when the map changes. Gameplay forests (from the
  // map data, where infantry get cover) render as dense canopy; ambient blobs and
  // fields are cosmetic.
  let decor = null;
  function buildDecor(game) {
    const world = game.WORLD, M = game.MAP;
    const rng = U.makeRng(M.id.length * 131 + 7);
    const desert = M.biome === "desert";
    const forests = (M.forests || []).map((f) => ({ x: f.x, y: f.y, r: f.r, gameplay: true }));
    const ambient = [];
    for (let i = 0; i < 34; i++) ambient.push({
      x: rng() * world.w, y: rng() * world.h, r: 35 + rng() * 90, a: 0.03 + rng() * 0.05 });
    const fields = [];
    for (let i = 0; i < 26; i++) fields.push({
      x: rng() * world.w, y: rng() * world.h,
      w: 120 + rng() * 260, h: 80 + rng() * 180, a: 0.03 + rng() * 0.05, rot: rng() * 0.6 - 0.3 });
    decor = { key: M.id, forests, ambient, fields, desert };
  }

  function nodePos(game, id) {
    if (id === "hqW") return game.MAP.hq[game.playerFac === "USMC" ? "USMC" : (game.enemyFac === "USMC" ? "USMC" : "USMC")];
    if (id === "hqE") return game.MAP.hq[game.playerFac === "RU" ? "RU" : (game.enemyFac === "RU" ? "RU" : "RU")];
    return game.townById[id];
  }

  function drawBoard(ctx, game, cam, view, ui) {
    ctx.save();
    // --- background terrain ---
    ctx.fillStyle = "#10160e";
    ctx.fillRect(0, 0, view.w, view.h);

    if (!decor || decor.key !== game.MAP.id) buildDecor(game);
    const tint = game.MAP.tint;

    ctx.save();
    ctx.translate(-cam.x * cam.zoom, -cam.y * cam.zoom);
    ctx.scale(cam.zoom, cam.zoom);

    // base ground tint
    const g = ctx.createLinearGradient(0, 0, 0, game.WORLD.h);
    g.addColorStop(0, tint.top);
    g.addColorStop(1, tint.bot);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, game.WORLD.w, game.WORLD.h);

    // fields
    for (const f of decor.fields) {
      ctx.save();
      ctx.translate(f.x, f.y); ctx.rotate(f.rot);
      ctx.fillStyle = decor.desert ? `rgba(190,165,90,${f.a})` : `rgba(150,160,90,${f.a})`;
      ctx.fillRect(-f.w / 2, -f.h / 2, f.w, f.h);
      ctx.restore();
    }
    // ambient blobs
    for (const f of decor.ambient) {
      ctx.beginPath();
      ctx.fillStyle = tint.forest + (f.a + 0.03) + ")";
      ctx.arc(f.x, f.y, f.r, 0, Math.PI * 2); ctx.fill();
    }
    // gameplay forests (cover) — denser canopy with a soft edge
    for (const f of decor.forests) {
      ctx.beginPath(); ctx.fillStyle = tint.forest + "0.22)";
      ctx.arc(f.x, f.y, f.r, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.fillStyle = tint.forest + "0.18)";
      ctx.arc(f.x, f.y, f.r * 0.7, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = tint.forest + "0.3)"; ctx.lineWidth = 2 / cam.zoom;
      ctx.beginPath(); ctx.arc(f.x, f.y, f.r, 0, Math.PI * 2); ctx.stroke();
    }

    // craters (ground particles, under everything)
    for (const p of game.parts) if (p.kind === "crater") {
      ctx.globalAlpha = U.clamp(1 - p.t / p.life, 0, 0.6) * 0.7;
      ctx.fillStyle = p.col + "0.7)";
      ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill();
    }
    ctx.globalAlpha = 1;

    // grid
    ctx.strokeStyle = tint.grid;
    ctx.lineWidth = 1 / cam.zoom;
    const step = 200;
    for (let x = 0; x <= game.WORLD.w; x += step) {
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, game.WORLD.h); ctx.stroke();
    }
    for (let y = 0; y <= game.WORLD.h; y += step) {
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(game.WORLD.w, y); ctx.stroke();
    }

    // roads
    ctx.strokeStyle = "rgba(180,170,140,0.10)";
    ctx.lineWidth = 9 / 1;
    ctx.lineCap = "round";
    for (const [a, b] of game.MAP.roads) {
      const pa = nodePos(game, a), pb = nodePos(game, b);
      if (!pa || !pb) continue;
      ctx.beginPath(); ctx.moveTo(pa.x, pa.y); ctx.lineTo(pb.x, pb.y); ctx.stroke();
    }

    // towns
    for (const t of game.towns) drawTown(ctx, game, t, ui);

    // HQs
    drawHQ(ctx, game, game.sides[game.playerFac].hq, game.playerFac);
    drawHQ(ctx, game, game.sides[game.enemyFac].hq, game.enemyFac);

    // rally flag
    if (ui.rally) drawRally(ctx, ui.rally, game.sides[game.playerFac].color);

    // units
    for (const u of game.units) if (u.alive) drawUnit(ctx, game, u, ui);

    // fx on top
    for (const e of game.fx) drawFx(ctx, e);
    // airborne particles (smoke, sparks)
    for (const p of game.parts) {
      if (p.kind === "crater") continue;
      const k = p.t / p.life;
      if (p.kind === "smoke") {
        ctx.globalAlpha = (1 - k) * 0.5;
        ctx.fillStyle = p.col + "1)";
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill();
      } else if (p.kind === "spark") {
        ctx.globalAlpha = 1 - k;
        ctx.fillStyle = p.col + "1)";
        ctx.fillRect(p.x - p.r, p.y - p.r, p.r * 2, p.r * 2);
      }
    }
    ctx.globalAlpha = 1;
    for (const f of game.floats) {
      ctx.globalAlpha = U.clamp(1.1 - f.t, 0, 1);
      ctx.fillStyle = f.col; ctx.font = "bold 13px monospace";
      ctx.fillText(f.txt, f.x, f.y); ctx.globalAlpha = 1;
    }

    // ---- fog of war + day/night (world space) ----
    drawFog(ctx, game, cam, view);

    ctx.restore(); // world transform

    // selection marquee (screen space)
    if (ui.box) {
      const b = ui.box;
      ctx.strokeStyle = "rgba(150,230,140,0.9)";
      ctx.fillStyle = "rgba(150,230,140,0.10)";
      ctx.lineWidth = 1.5;
      ctx.fillRect(b.x, b.y, b.w, b.h);
      ctx.strokeRect(b.x, b.y, b.w, b.h);
    }
    ctx.restore();
  }

  function drawTown(ctx, game, t, ui) {
    const owner = t.owner;
    const oc = owner ? FACTIONS[owner].color : "#9aa0a6";
    // footprint
    ctx.beginPath();
    ctx.fillStyle = "rgba(60,60,55,0.5)";
    ctx.arc(t.x, t.y, 46, 0, Math.PI * 2); ctx.fill();
    // capture range hint when hovered/selected nearby
    if (ui.hoverTown === t) {
      ctx.beginPath(); ctx.strokeStyle = "rgba(255,255,255,0.18)";
      ctx.setLineDash([6, 8]); ctx.lineWidth = 1.5;
      ctx.arc(t.x, t.y, DATA.RULES.captureRange, 0, Math.PI * 2); ctx.stroke();
      ctx.setLineDash([]);
    }
    // control ring
    ctx.beginPath();
    ctx.strokeStyle = oc; ctx.lineWidth = 4;
    ctx.arc(t.x, t.y, 30, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (owner ? t.cap / 100 : 0.0));
    ctx.stroke();
    ctx.beginPath();
    ctx.strokeStyle = "rgba(255,255,255,0.12)"; ctx.lineWidth = 4;
    ctx.arc(t.x, t.y, 30, 0, Math.PI * 2); ctx.stroke();

    // flag pole
    ctx.fillStyle = "#2c2c2c"; ctx.fillRect(t.x - 1.5, t.y - 30, 3, 30);
    ctx.fillStyle = owner ? oc : "#777";
    ctx.beginPath();
    ctx.moveTo(t.x + 1.5, t.y - 30); ctx.lineTo(t.x + 22, t.y - 25);
    ctx.lineTo(t.x + 1.5, t.y - 20); ctx.closePath(); ctx.fill();

    // contested pulse
    if (t.contested) {
      const p = (Math.sin(game.clock * 6) + 1) / 2;
      ctx.beginPath(); ctx.strokeStyle = `rgba(255,210,60,${0.3 + 0.5 * p})`;
      ctx.lineWidth = 2; ctx.arc(t.x, t.y, 36, 0, Math.PI * 2); ctx.stroke();
    }

    // label
    ctx.font = "11px monospace"; ctx.textAlign = "center";
    ctx.fillStyle = "rgba(0,0,0,0.55)";
    ctx.fillText(t.name, t.x + 1, t.y + 50);
    ctx.fillStyle = "#d6dcc8";
    ctx.fillText(t.name, t.x, t.y + 49);
    ctx.fillStyle = "rgba(200,200,160,0.65)"; ctx.font = "9px monospace";
    ctx.fillText("SV " + t.sv + (t.garrisonLeft > 0.5 ? "  ⚔" : ""), t.x, t.y + 61);
    ctx.textAlign = "left";
  }

  function drawHQ(ctx, game, hq, facId) {
    const c = FACTIONS[facId].color;
    ctx.save();
    ctx.translate(hq.x, hq.y);
    // pad
    ctx.fillStyle = "rgba(20,20,18,0.8)";
    U.roundRect(ctx, -34, -28, 68, 56, 6); ctx.fill();
    ctx.strokeStyle = c; ctx.lineWidth = 3;
    U.roundRect(ctx, -34, -28, 68, 56, 6); ctx.stroke();
    // building glyph
    ctx.fillStyle = c; ctx.globalAlpha = 0.9;
    ctx.fillRect(-18, -14, 36, 26);
    ctx.fillStyle = "#10160e";
    ctx.font = "bold 20px monospace"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.fillText("HQ", 0, 0);
    ctx.globalAlpha = 1;
    // hp bar
    const w = 60, hp = U.clamp(hq.hp / hq.maxHp, 0, 1);
    ctx.fillStyle = "rgba(0,0,0,0.6)"; ctx.fillRect(-w / 2, -38, w, 6);
    ctx.fillStyle = hp > 0.5 ? "#5ad15a" : hp > 0.25 ? "#e0c14a" : "#e05050";
    ctx.fillRect(-w / 2, -38, w * hp, 6);
    ctx.textAlign = "left"; ctx.textBaseline = "alphabetic";
    ctx.restore();
  }

  function drawRally(ctx, r, col) {
    ctx.save(); ctx.translate(r.x, r.y); ctx.globalAlpha = 0.8;
    ctx.fillStyle = "#2c2c2c"; ctx.fillRect(-1, -22, 2, 22);
    ctx.fillStyle = col;
    ctx.beginPath(); ctx.moveTo(1, -22); ctx.lineTo(16, -17); ctx.lineTo(1, -12); ctx.closePath(); ctx.fill();
    ctx.restore();
  }

  function drawUnit(ctx, game, u, ui) {
    // fog of war: hide non-player units the player can't currently see
    if (u.fac !== game.playerFac && !game.isVisible(u.x, u.y)) return;
    const isSel = ui.sel && ui.sel.has(u);
    const c = u.fac === "GARRISON" ? "#b9b9a0" : FACTIONS[u.fac].color;
    const cat = u.def.cat;
    const size = u.outpost ? 13 : cat === "inf" ? 5 : cat === "light" ? 8 : cat === "heavy" ? 10 : 9;

    ctx.save();
    ctx.translate(u.x, u.y);

    // selection ring + order line
    if (isSel) {
      ctx.beginPath();
      ctx.strokeStyle = "rgba(160,240,150,0.95)"; ctx.lineWidth = 1.6;
      ctx.arc(0, 0, size + 6, 0, Math.PI * 2); ctx.stroke();
    }

    // shadow
    ctx.beginPath(); ctx.fillStyle = "rgba(0,0,0,0.35)";
    ctx.ellipse(0, size * 0.7, size + 1, (size + 1) * 0.5, 0, 0, Math.PI * 2); ctx.fill();

    // body by category, oriented to heading
    ctx.rotate(u.heading + Math.PI / 2);
    ctx.fillStyle = u.hitFlash > 0 ? "#fff" : c;
    ctx.strokeStyle = "rgba(0,0,0,0.5)"; ctx.lineWidth = 1;
    if (u.emplacement || u.outpost) {
      // sandbag strongpoint / outpost: ring + colored core (never rotates)
      ctx.rotate(-(u.heading + Math.PI / 2));
      ctx.fillStyle = "rgba(90,84,60,0.95)";
      U.roundRect(ctx, -size - 2, -size - 2, (size + 2) * 2, (size + 2) * 2, 3); ctx.fill();
      ctx.strokeStyle = "rgba(0,0,0,0.5)"; ctx.stroke();
      ctx.fillStyle = u.hitFlash > 0 ? "#fff" : c;
      U.roundRect(ctx, -size + 2, -size + 2, (size - 2) * 2, (size - 2) * 2, 2); ctx.fill();
      if (u.outpost) { // flag on the outpost
        ctx.fillStyle = "#2c2c2c"; ctx.fillRect(-1, -size - 12, 2, 12);
        ctx.fillStyle = c;
        ctx.beginPath(); ctx.moveTo(1, -size - 12); ctx.lineTo(11, -size - 8); ctx.lineTo(1, -size - 4); ctx.closePath(); ctx.fill();
      }
      if (u.building) { // under construction: scaffolding hatch
        ctx.strokeStyle = "rgba(255,210,90,0.8)"; ctx.lineWidth = 1.4;
        ctx.beginPath(); ctx.moveTo(-size, -size); ctx.lineTo(size, size);
        ctx.moveTo(size, -size); ctx.lineTo(-size, size); ctx.stroke();
      }
      ctx.rotate(u.heading + Math.PI / 2);
    } else if (u.def.air) {
      // helicopter / jet: diamond + rotor
      ctx.beginPath();
      ctx.moveTo(0, -size - 3); ctx.lineTo(size, 0); ctx.lineTo(0, size + 3); ctx.lineTo(-size, 0);
      ctx.closePath(); ctx.fill(); ctx.stroke();
      ctx.strokeStyle = "rgba(220,220,220,0.5)"; ctx.lineWidth = 1.4;
      const rot = (game.clock * 30) % (Math.PI * 2);
      ctx.beginPath(); ctx.moveTo(Math.cos(rot) * (size + 6), Math.sin(rot) * (size + 6));
      ctx.lineTo(-Math.cos(rot) * (size + 6), -Math.sin(rot) * (size + 6)); ctx.stroke();
    } else if (cat === "inf") {
      ctx.beginPath(); ctx.arc(0, 0, size, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      // facing nub
      ctx.fillStyle = "rgba(255,255,255,0.6)";
      ctx.fillRect(-1, -size - 2, 2, 4);
    } else {
      // vehicle: rounded rect hull + barrel
      U.roundRect(ctx, -size, -size - 1, size * 2, size * 2 + 2, 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = "rgba(0,0,0,0.55)";
      ctx.fillRect(-1.5, -size - 6, 3, size + 4);
    }

    // glyph
    ctx.rotate(-(u.heading + Math.PI / 2));
    ctx.fillStyle = "rgba(0,0,0,0.7)";
    ctx.font = `bold ${cat === "inf" ? 6 : 9}px monospace`;
    ctx.textAlign = "center"; ctx.textBaseline = "middle";
    if (cat !== "inf") ctx.fillText(u.def.glyph.toUpperCase(), 0, 0);

    // muzzle flash
    if (u.muzzle > 0) {
      ctx.fillStyle = "rgba(255,230,120,0.9)";
      ctx.beginPath();
      ctx.arc(Math.cos(u.heading) * (size + 4), Math.sin(u.heading) * (size + 4), 3, 0, Math.PI * 2);
      ctx.fill();
    }

    // hp bar when damaged
    if (u.hp < u.maxHp) {
      const w = size * 2 + 4, hp = U.clamp(u.hp / u.maxHp, 0, 1);
      ctx.fillStyle = "rgba(0,0,0,0.6)"; ctx.fillRect(-w / 2, -size - 8, w, 3);
      ctx.fillStyle = hp > 0.5 ? "#5ad15a" : hp > 0.25 ? "#e0c14a" : "#e05050";
      ctx.fillRect(-w / 2, -size - 8, w * hp, 3);
    }

    // veterancy chevrons
    if (u.rank > 0) {
      ctx.fillStyle = "#ffd24a"; ctx.strokeStyle = "rgba(0,0,0,0.6)"; ctx.lineWidth = 0.6;
      for (let i = 0; i < u.rank; i++) {
        const cy = size + 4 + i * 3;
        ctx.beginPath();
        ctx.moveTo(-3, cy + 2); ctx.lineTo(0, cy); ctx.lineTo(3, cy + 2);
        ctx.stroke();
      }
    }

    // parachute (just-dropped paratroopers)
    if (u._para > 0) {
      ctx.globalAlpha = U.clamp(u._para, 0, 1);
      ctx.fillStyle = "rgba(220,220,210,0.85)";
      ctx.beginPath(); ctx.arc(0, -size - 10, size + 4, Math.PI, 0); ctx.fill();
      ctx.strokeStyle = "rgba(220,220,210,0.6)"; ctx.lineWidth = 0.8;
      ctx.beginPath(); ctx.moveTo(-size - 4, -size - 10); ctx.lineTo(0, -size + 2);
      ctx.lineTo(size + 4, -size - 10); ctx.stroke();
      ctx.globalAlpha = 1;
    }
    ctx.textAlign = "left"; ctx.textBaseline = "alphabetic";
    ctx.restore();
  }

  function drawFx(ctx, e) {
    const k = e.t / e.life;
    if (e.kind === "tracer") {
      ctx.strokeStyle = e.col; ctx.globalAlpha = 1 - k; ctx.lineWidth = 1.6;
      ctx.beginPath(); ctx.moveTo(e.x, e.y); ctx.lineTo(e.tx, e.ty); ctx.stroke();
      ctx.globalAlpha = 1;
    } else if (e.kind === "arty") {
      ctx.strokeStyle = "rgba(255,180,90,0.8)"; ctx.globalAlpha = 1 - k; ctx.lineWidth = 2.4;
      ctx.setLineDash([5, 5]);
      ctx.beginPath(); ctx.moveTo(e.x, e.y); ctx.lineTo(e.tx, e.ty); ctx.stroke();
      ctx.setLineDash([]); ctx.globalAlpha = 1;
    } else if (e.kind === "blast") {
      ctx.globalAlpha = 1 - k;
      ctx.fillStyle = `rgba(255,${120 + 100 * (1 - k)},40,0.5)`;
      ctx.beginPath(); ctx.arc(e.x, e.y, e.r * (0.4 + k), 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = "rgba(255,220,120,0.8)"; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(e.x, e.y, e.r * (0.4 + k), 0, Math.PI * 2); ctx.stroke();
      ctx.globalAlpha = 1;
    }
  }

  /* ---- minimap ---------------------------------------------------------- */
  /* ---- fog of war (smooth, via a small offscreen buffer) + day/night ----- */
  let fogBuf = null, fogCtx = null, fogData = null, fogKey = "";
  function ensureFog(game) {
    const V = game.vision, key = V.cols + "x" + V.rows;
    if (fogKey !== key) {
      fogBuf = document.createElement("canvas");
      fogBuf.width = V.cols; fogBuf.height = V.rows;
      fogCtx = fogBuf.getContext("2d");
      fogData = fogCtx.createImageData(V.cols, V.rows);
      fogKey = key;
    }
  }
  function drawFog(ctx, game, cam, view) {
    const V = game.vision; ensureFog(game);
    const d = fogData.data, n = V.cols * V.rows;
    for (let i = 0; i < n; i++) {
      const o = i * 4; d[o] = 5; d[o + 1] = 8; d[o + 2] = 6;
      d[o + 3] = V.visible[i] ? 0 : (V.explored[i] ? 120 : 236);
    }
    fogCtx.putImageData(fogData, 0, 0);
    const sm = ctx.imageSmoothingEnabled; ctx.imageSmoothingEnabled = true;
    ctx.drawImage(fogBuf, 0, 0, game.WORLD.w, game.WORLD.h);
    ctx.imageSmoothingEnabled = sm;
    // day/night blue tint over the visible world rectangle
    const tl = cam.screenToWorld(0, 0), br = cam.screenToWorld(view.w, view.h);
    const nightA = U.clamp((0.7 - game.daylight) * 0.7, 0, 0.5);
    if (nightA > 0.01) {
      ctx.fillStyle = `rgba(14,22,46,${nightA})`;
      ctx.fillRect(tl.x, tl.y, br.x - tl.x, br.y - tl.y);
    }
  }

  function drawMinimap(ctx, game, cam, view, mmW, mmH) {
    ctx.clearRect(0, 0, mmW, mmH);
    ctx.fillStyle = "rgba(12,18,10,0.92)";
    ctx.fillRect(0, 0, mmW, mmH);
    const sx = mmW / game.WORLD.w, sy = mmH / game.WORLD.h;

    // towns
    for (const t of game.towns) {
      ctx.fillStyle = t.owner ? FACTIONS[t.owner].color : "#888";
      ctx.beginPath(); ctx.arc(t.x * sx, t.y * sy, 3.2, 0, Math.PI * 2); ctx.fill();
    }
    // HQs
    for (const fid of [game.playerFac, game.enemyFac]) {
      const hq = game.sides[fid].hq;
      ctx.fillStyle = FACTIONS[fid].color;
      ctx.fillRect(hq.x * sx - 3, hq.y * sy - 3, 6, 6);
    }
    // units (enemy/neutral only shown where the player has vision)
    for (const u of game.units) {
      if (!u.alive) continue;
      if (u.fac !== game.playerFac && !game.isVisible(u.x, u.y)) continue;
      ctx.fillStyle = u.fac === "GARRISON" ? "#b9b9a0" : FACTIONS[u.fac].color;
      ctx.fillRect(u.x * sx - 1, u.y * sy - 1, 2, 2);
    }
    // viewport rect
    const vw = view.w / cam.zoom, vh = view.h / cam.zoom;
    ctx.strokeStyle = "rgba(230,230,210,0.8)"; ctx.lineWidth = 1;
    ctx.strokeRect(cam.x * sx, cam.y * sy, vw * sx, vh * sy);
  }

  return { drawBoard, drawMinimap, buildDecor };
})();
