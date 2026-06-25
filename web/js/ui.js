/* =============================================================================
 * ui.js — in-game HUD, build panel, selection + order input, camera control.
 * Owns no simulation state; issues commands through the engine API.
 * ========================================================================== */

function createUI(game, refs) {
  "use strict";
  const { CATEGORIES, STRUCTURES, ROSTER, FACTIONS } = DATA;
  const facId = game.playerFac;
  const fac = FACTIONS[facId];

  const cam = U.makeCamera(game.WORLD, { w: refs.board.width, h: refs.board.height });
  cam.centerOn(game.sides[facId].hq.x, game.sides[facId].hq.y);

  const state = {
    sel: new Set(),
    box: null,           // screen-space marquee while dragging
    rally: game.sides[facId].rally || null,
    hoverTown: null,
    tab: "inf",
    paused: false,
    speed: 1,
  };

  /* ---------- BUILD PANEL ------------------------------------------------- */
  function buildTabs() {
    refs.panelTabs.innerHTML = "";
    const tabs = CATEGORIES.map((c) => ({ id: c.id, label: c.tab, hot: c.hot }));
    tabs.push({ id: "base", label: "BASE", hot: "5" });
    for (const t of tabs) {
      const el = document.createElement("button");
      el.className = "ptab" + (state.tab === t.id ? " active" : "");
      el.innerHTML = `<span class="ptab-hot">${t.hot}</span>${t.label}`;
      el.onclick = () => { state.tab = t.id; renderPanel(); };
      refs.panelTabs.appendChild(el);
    }
  }

  function renderPanel() {
    buildTabs();
    refs.panelBody.innerHTML = "";
    const side = game.sides[facId];

    if (state.tab === "base") {
      for (const st of STRUCTURES) {
        const built = side.structures.has(st.id) && st.id !== "depot";
        const building = side.building.some((b) => b.struct.id === st.id);
        const afford = side.funds >= st.cost;
        const card = document.createElement("button");
        card.className = "bcard" + (built ? " built" : "") + (!afford && !built ? " poor" : "");
        card.disabled = built;
        const extra = st.id === "depot" ? `<span class="bsup">+6 cap</span>` :
          `<span class="bsup">unlock</span>`;
        card.innerHTML = `
          <span class="bglyph">${st.glyph}</span>
          <span class="bmain">
            <span class="bname">${st.name}</span>
            <span class="bdesc">${st.desc}</span>
          </span>
          <span class="bcost">
            <span class="bfunds">$${U.fmtNum(st.cost)}</span>
            <span class="btime">${built ? "BUILT" : building ? "…building" : st.build + "s"}</span>
          </span>`;
        card.onclick = () => {
          const r = game.queueStructure(facId, st.id);
          if (!r.ok) flash(r.reason);
          renderPanel();
        };
        refs.panelBody.appendChild(card);
      }
      return;
    }

    const list = ROSTER[facId].filter((u) => u.cat === state.tab);
    const unlocked = game.catUnlocked(facId, state.tab);
    if (!unlocked) {
      const sname = STRUCTURES.find((s) => s.unlocks === state.tab);
      const note = document.createElement("div");
      note.className = "panel-lock";
      note.innerHTML = `🔒 Build a <b>${sname ? sname.name : state.tab}</b> in the BASE tab to unlock these.`;
      refs.panelBody.appendChild(note);
    }
    for (const u of list) {
      const afford = side.funds >= u.cost;
      const supOk = game.supplyUsed(facId) + u.sup <= game.supplyCap(facId);
      const ok = unlocked && afford && supOk;
      const card = document.createElement("button");
      card.className = "bcard" + (ok ? "" : " poor");
      const role = roleTag(u);
      card.innerHTML = `
        <span class="bglyph ${u.def && u.def.air ? "" : ""}">${u.glyph.toUpperCase()}</span>
        <span class="bmain">
          <span class="bname">${u.name}</span>
          <span class="bdesc">${role} · ${u.hp} hp · ${u.sup} sup</span>
        </span>
        <span class="bcost">
          <span class="bfunds ${afford ? "" : "no"}">$${U.fmtNum(u.cost)}</span>
          <span class="btime">${u.build}s</span>
        </span>`;
      card.onclick = () => {
        const r = game.queueUnit(facId, u.id);
        if (!r.ok) flash(r.reason);
        renderPanel();
      };
      refs.panelBody.appendChild(card);
    }
  }

  function roleTag(u) {
    if (u.heal) return "Medic";
    if (u.supplyTruck) return "Logistics";
    if (u.arty) return "Artillery";
    if (u.vs.air >= 3) return "Anti-Air";
    if (u.vs.veh >= 2) return "Anti-Tank";
    if (u.def && u.def.air) return "Air";
    if (u.cat === "inf") return "Infantry";
    if (u.cat === "heavy") return "Armor";
    return "Vehicle";
  }

  function renderQueue() {
    const side = game.sides[facId];
    const items = [];
    side.building.forEach((b) =>
      items.push({ name: b.struct.name, glyph: b.struct.glyph, p: 1 - b.timeLeft / b.total, struct: true }));
    side.queue.forEach((q) =>
      items.push({ name: q.def.name, glyph: q.def.glyph.toUpperCase(), p: 1 - q.timeLeft / q.total }));
    if (!items.length) { refs.queueList.innerHTML = `<div class="queue-empty">— idle —</div>`; return; }
    refs.queueList.innerHTML = items.map((it) => `
      <div class="qitem ${it.struct ? "qstruct" : ""}">
        <span class="qglyph">${it.glyph}</span>
        <span class="qname">${it.name}</span>
        <span class="qbar"><i style="width:${Math.round(it.p * 100)}%"></i></span>
      </div>`).join("");
  }

  /* ---------- HUD --------------------------------------------------------- */
  function refreshHud() {
    const side = game.sides[facId];
    refs.statFunds.textContent = U.fmtNum(side.funds);
    refs.statIncome.textContent = "+" + U.fmtNum(Math.round(side.income * 60)) + "/min";
    refs.statSupply.textContent = game.supplyUsed(facId) + "/" + game.supplyCap(facId);
    refs.statTowns.textContent = game.townsOwned(facId) + "/" + game.towns.length;
    refs.statUnits.textContent = game.unitsOfSide(facId).length;
    refs.hudClock.textContent = U.fmtTime(game.clock);
    const supEl = refs.statSupply;
    supEl.style.color = game.supplyUsed(facId) >= game.supplyCap(facId) ? "#ff8a6a" : "";
  }

  /* ---------- selection readout ------------------------------------------ */
  function refreshSelInfo() {
    if (!state.sel.size) { refs.selInfo.classList.add("hidden"); return; }
    refs.selInfo.classList.remove("hidden");
    // group by unit def
    const counts = {};
    let hp = 0, maxhp = 0;
    for (const u of state.sel) {
      counts[u.def.name] = (counts[u.def.name] || 0) + 1;
      hp += u.hp; maxhp += u.maxHp;
    }
    const rows = Object.entries(counts)
      .sort((a, b) => b[1] - a[1])
      .map(([n, c]) => `<span class="seltag">${c}× ${n}</span>`).join("");
    refs.selInfo.innerHTML =
      `<div class="sel-head">${state.sel.size} SELECTED · ${Math.round(100 * hp / Math.max(1, maxhp))}% combat</div>
       <div class="sel-rows">${rows}</div>
       <div class="sel-hint">right-click to move / attack · S stop · A attack-move</div>`;
  }

  /* ---------- ticker ------------------------------------------------------ */
  function flash(msg, type) {
    const el = document.createElement("div");
    el.className = "tick-line " + (type || "warn");
    el.textContent = msg;
    refs.ticker.appendChild(el);
    setTimeout(() => el.classList.add("show"), 10);
    setTimeout(() => { el.classList.remove("show"); setTimeout(() => el.remove(), 400); }, 3600);
    while (refs.ticker.children.length > 5) refs.ticker.removeChild(refs.ticker.firstChild);
  }
  game.onLog = (msg, type) => flash(msg, type === "good" ? "good" : type === "bad" ? "bad" : "info");

  /* ---------- input: selection & orders ---------------------------------- */
  let dragging = null; // {sx,sy} screen start
  let panKeys = {};

  function boardPos(ev) {
    const r = refs.board.getBoundingClientRect();
    return { x: (ev.clientX - r.left) * (refs.board.width / r.width),
             y: (ev.clientY - r.top) * (refs.board.height / r.height) };
  }

  function unitAtScreen(sx, sy, factionOnly) {
    const w = cam.screenToWorld(sx, sy);
    let best = null, bestD = 1e9;
    for (const u of game.units) {
      if (!u.alive) continue;
      if (factionOnly && u.fac !== facId) continue;
      const size = (u.def.cat === "inf" ? 6 : 11) + 6;
      const d = U.dist2(w.x, w.y, u.x, u.y);
      if (d < (size / cam.zoom) ** 2 && d < bestD) { bestD = d; best = u; }
    }
    return best;
  }

  function enemyAtScreen(sx, sy) {
    const w = cam.screenToWorld(sx, sy);
    for (const u of game.units) {
      if (!u.alive || u.fac === facId) continue;
      const size = (u.def.cat === "inf" ? 7 : 12) + 5;
      if (U.dist2(w.x, w.y, u.x, u.y) < (size / cam.zoom) ** 2) return u;
    }
    // enemy HQ
    const ehq = game.sides[game.enemyFac].hq;
    if (U.dist2(w.x, w.y, ehq.x, ehq.y) < (40 / cam.zoom) ** 2) return ehq;
    return null;
  }

  refs.board.addEventListener("mousedown", (ev) => {
    if (ev.button === 1) { ev.preventDefault(); panState.mid = boardPos(ev); return; }
    if (ev.button !== 0) return;
    const p = boardPos(ev);
    dragging = { sx: p.x, sy: p.y, x: p.x, y: p.y, add: ev.shiftKey };
  });

  window.addEventListener("mousemove", (ev) => {
    if (panState.mid) {
      const p = boardPos(ev);
      cam.panBy((panState.mid.x - p.x) / cam.zoom, (panState.mid.y - p.y) / cam.zoom);
      panState.mid = p; return;
    }
    if (dragging) {
      const p = boardPos(ev);
      dragging.x = p.x; dragging.y = p.y;
      const x = Math.min(dragging.sx, p.x), y = Math.min(dragging.sy, p.y);
      const w = Math.abs(p.x - dragging.sx), h = Math.abs(p.y - dragging.sy);
      state.box = w > 4 || h > 4 ? { x, y, w, h } : null;
    }
    // hover town for capture-range hint
    const r = refs.board.getBoundingClientRect();
    if (ev.clientX >= r.left && ev.clientX <= r.right && ev.clientY >= r.top && ev.clientY <= r.bottom) {
      const p = boardPos(ev); const wpt = cam.screenToWorld(p.x, p.y);
      state.hoverTown = game.towns.find((t) => U.dist2(wpt.x, wpt.y, t.x, t.y) < 46 * 46) || null;
    }
  });

  window.addEventListener("mouseup", (ev) => {
    if (ev.button === 1) { panState.mid = null; return; }
    if (ev.button !== 0 || !dragging) { dragging = null; return; }
    const p = boardPos(ev);
    if (!dragging.add) state.sel.clear();
    if (state.box) {
      // marquee select player units
      const a = cam.screenToWorld(state.box.x, state.box.y);
      const b = cam.screenToWorld(state.box.x + state.box.w, state.box.y + state.box.h);
      for (const u of game.units) {
        if (!u.alive || u.fac !== facId || u.garrison) continue;
        if (u.x >= a.x && u.x <= b.x && u.y >= a.y && u.y <= b.y) state.sel.add(u);
      }
    } else {
      const u = unitAtScreen(p.x, p.y, true);
      if (u && !u.garrison) {
        if (ev.shiftKey && state.sel.has(u)) state.sel.delete(u);
        else state.sel.add(u);
      }
    }
    state.box = null; dragging = null;
    refreshSelInfo();
  });

  // right-click: orders
  refs.board.addEventListener("contextmenu", (ev) => {
    ev.preventDefault();
    const p = boardPos(ev);
    if (!state.sel.size) return;
    const enemy = enemyAtScreen(p.x, p.y);
    const sel = [...state.sel];
    if (enemy) {
      game.issueAttack(sel, enemy);
      pingAt(p.x, p.y, "#ff6a5a");
    } else {
      const w = cam.screenToWorld(p.x, p.y);
      game.issueMove(sel, w.x, w.y, ev.shiftKey);
      pingAt(p.x, p.y, "#7ef07e");
    }
  });

  // ping marker (screen-space, fades)
  const pings = [];
  function pingAt(sx, sy, col) {
    const w = cam.screenToWorld(sx, sy);
    pings.push({ x: w.x, y: w.y, col, t: 0 });
  }

  const panState = { mid: null };

  // wheel zoom
  refs.board.addEventListener("wheel", (ev) => {
    ev.preventDefault();
    const p = boardPos(ev);
    cam.zoomAt(p.x, p.y, ev.deltaY < 0 ? 1.12 : 1 / 1.12);
  }, { passive: false });

  // minimap navigation
  function minimapNav(ev) {
    const r = refs.minimap.getBoundingClientRect();
    const mx = (ev.clientX - r.left) / r.width * game.WORLD.w;
    const my = (ev.clientY - r.top) / r.height * game.WORLD.h;
    if (ev.button === 2 && state.sel.size) {
      const enemy = null; game.issueMove([...state.sel], mx, my, true);
    } else {
      cam.centerOn(mx, my);
    }
  }
  refs.minimap.addEventListener("mousedown", (ev) => { ev.preventDefault(); minimapNav(ev); });
  refs.minimap.addEventListener("contextmenu", (ev) => ev.preventDefault());

  /* ---------- keyboard ---------------------------------------------------- */
  window.addEventListener("keydown", (ev) => {
    const k = ev.key.toLowerCase();
    if (["w", "a", "s", "d", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(k)) panKeys[k] = true;
    if (k === " ") { ev.preventDefault(); togglePause(); }
    else if (k === "h") cam.centerOn(game.sides[facId].hq.x, game.sides[facId].hq.y);
    else if (k === "s" && state.sel.size) game.issueStop([...state.sel]);
    else if (k === "tab") { ev.preventDefault(); cycleIdle(); }
    else if (["1", "2", "3", "4", "5"].includes(k)) {
      const map = { "1": "inf", "2": "light", "3": "heavy", "4": "air", "5": "base" };
      state.tab = map[k]; renderPanel();
    } else if (k === "e" && state.sel.size) {
      // set rally to first selected (rally for new production)
    } else if (k === "f") {
      // toggle follow? skip
    } else if (k === "r") {
      // set rally point at HQ? not needed
    }
  });
  window.addEventListener("keyup", (ev) => { panKeys[ev.key.toLowerCase()] = false; });

  let idleIdx = 0;
  function cycleIdle() {
    const idle = game.unitsOfSide(facId).filter((u) => !u.garrison &&
      (u.order.type === "guard" || u.order.type === "hold"));
    if (!idle.length) return;
    idleIdx = (idleIdx + 1) % idle.length;
    const u = idle[idleIdx];
    state.sel.clear(); state.sel.add(u);
    cam.centerOn(u.x, u.y);
    refreshSelInfo();
  }

  function togglePause() {
    state.paused = !state.paused;
    refs.pauseBtn.textContent = state.paused ? "▶" : "❚❚";
    refs.pauseBtn.classList.toggle("on", state.paused);
  }

  // double-click empty board sets a production rally point
  refs.board.addEventListener("dblclick", (ev) => {
    const p = boardPos(ev);
    if (unitAtScreen(p.x, p.y, true)) {
      // double-click a unit => select all of same type on screen
      const u = unitAtScreen(p.x, p.y, true);
      state.sel.clear();
      for (const o of game.unitsOfSide(facId))
        if (o.def.id === u.def.id) state.sel.add(o);
      refreshSelInfo();
      return;
    }
    const w = cam.screenToWorld(p.x, p.y);
    game.setRally(facId, w.x, w.y);
    state.rally = { x: w.x, y: w.y };
    flash("Rally point set — new units will deploy here", "info");
  });

  /* ---------- HUD buttons ------------------------------------------------- */
  refs.pauseBtn.onclick = togglePause;
  refs.speedBtn.onclick = () => {
    state.speed = state.speed === 1 ? 2 : state.speed === 2 ? 3 : 1;
    refs.speedBtn.textContent = state.speed + "×";
  };

  /* ---------- camera edge/keys update ------------------------------------ */
  function updateCamera(dt) {
    const sp = 620 * dt / cam.zoom;
    if (panKeys["w"] || panKeys["arrowup"]) cam.panBy(0, -sp);
    if (panKeys["s"] || panKeys["arrowdown"]) cam.panBy(0, sp);
    if (panKeys["a"] || panKeys["arrowleft"]) cam.panBy(-sp, 0);
    if (panKeys["d"] || panKeys["arrowright"]) cam.panBy(sp, 0);
  }

  /* ---------- prune dead from selection ---------------------------------- */
  function pruneSel() {
    let changed = false;
    for (const u of [...state.sel]) if (!u.alive || u.hp <= 0) { state.sel.delete(u); changed = true; }
    if (changed) refreshSelInfo();
  }

  /* ---------- per-frame tick (called by main loop) ----------------------- */
  let hudT = 0, panelT = 0;
  function tick(dt, realDt) {
    updateCamera(realDt);
    pruneSel();
    // throttle DOM updates
    hudT += realDt;
    if (hudT > 0.12) { hudT = 0; refreshHud(); renderQueue(); }
    panelT += realDt;
    if (panelT > 0.4) { panelT = 0; renderPanelAffordability(); }
    // update pings
    for (let i = pings.length - 1; i >= 0; i--) { pings[i].t += realDt; if (pings[i].t > 0.6) pings.splice(i, 1); }
  }

  // lightweight affordability refresh without rebuilding the whole panel
  function renderPanelAffordability() {
    const side = game.sides[facId];
    const cards = refs.panelBody.querySelectorAll(".bcard");
    if (!cards.length) return;
    if (state.tab === "base") { renderPanel(); return; }
    const list = ROSTER[facId].filter((u) => u.cat === state.tab);
    const unlocked = game.catUnlocked(facId, state.tab);
    cards.forEach((card, i) => {
      const u = list[i]; if (!u) return;
      const afford = side.funds >= u.cost;
      const supOk = game.supplyUsed(facId) + u.sup <= game.supplyCap(facId);
      card.classList.toggle("poor", !(unlocked && afford && supOk));
      const f = card.querySelector(".bfunds");
      if (f) f.classList.toggle("no", !afford);
    });
  }

  function drawPings(ctx) {
    for (const p of pings) {
      const s = cam.worldToScreen(p.x, p.y);
      const k = p.t / 0.6;
      ctx.strokeStyle = p.col; ctx.globalAlpha = 1 - k; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(s.x, s.y, 4 + k * 18, 0, Math.PI * 2); ctx.stroke();
      ctx.globalAlpha = 1;
    }
  }

  renderPanel();
  refreshHud();

  return {
    state, cam, tick, drawPings,
    get paused() { return state.paused; },
    get speed() { return state.speed; },
    uiState() { return { sel: state.sel, box: state.box, rally: state.rally, hoverTown: state.hoverTown }; },
    renderPanel,
  };
}
