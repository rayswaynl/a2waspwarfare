/* =============================================================================
 * ui.js — in-game HUD, build panel, selection + order input, camera control.
 * Owns no simulation state; issues commands through the engine API.
 * ========================================================================== */

function createUI(game, refs) {
  "use strict";
  const { CATEGORIES, STRUCTURES, ROSTER, FACTIONS, POWERS, DEFENSES } = DATA;
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
    groups: {},          // control groups: { "1": [units], ... }
    targeting: null,     // { kind:'power'|'defense', id, def } while aiming
    cursorW: { x: 0, y: 0 },
    _lastGroupKey: null, _lastGroupT: 0,
  };

  // map number key -> support power id (Z/X/C/V also bound below)
  const POWER_KEYS = { z: POWERS[0].id, x: POWERS[1].id, c: POWERS[2].id, v: POWERS[3] && POWERS[3].id };
  const POWER_HOTLABELS = ["Z", "X", "C", "V"];

  // Track event listeners so a restart can tear them down (no leaks/dupes).
  const _listeners = [];
  function on(target, type, fn, opts) {
    target.addEventListener(type, fn, opts);
    _listeners.push([target, type, fn, opts]);
  }

  /* ---------- BUILD PANEL ------------------------------------------------- */
  function buildTabs() {
    refs.panelTabs.innerHTML = "";
    const tabs = CATEGORIES.map((c) => ({ id: c.id, label: c.tab, hot: c.hot }));
    tabs.push({ id: "base", label: "BASE", hot: "T" });
    tabs.push({ id: "upgrade", label: "UPGRADE", hot: "Y" });
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
          if (!r.ok) { flash(r.reason); Sound.deny(); } else Sound.ui();
          renderPanel();
        };
        refs.panelBody.appendChild(card);
      }

      // --- Defensive emplacements (click to place near owned territory) ---
      const hdr = document.createElement("div");
      hdr.className = "panel-subhead";
      hdr.textContent = "DEFENSES — click then place near your lines";
      refs.panelBody.appendChild(hdr);
      for (const d of DEFENSES) {
        const afford = side.funds >= d.cost;
        const supOk = game.supplyUsed(facId) + d.sup <= game.supplyCap(facId);
        const ok = afford && supOk;
        const card = document.createElement("button");
        card.className = "bcard" + (ok ? "" : " poor") +
          (state.targeting && state.targeting.id === d.id ? " arming" : "");
        card.innerHTML = `
          <span class="bglyph def">${d.glyph}</span>
          <span class="bmain">
            <span class="bname">${d.name}</span>
            <span class="bdesc">${d.desc}</span>
          </span>
          <span class="bcost">
            <span class="bfunds ${afford ? "" : "no"}">$${U.fmtNum(d.cost)}</span>
            <span class="btime">${d.sup} sup</span>
          </span>`;
        card.onclick = () => { armTargeting("defense", d.id, d); };
        refs.panelBody.appendChild(card);
      }
      return;
    }

    if (state.tab === "upgrade") {
      const note = document.createElement("div");
      note.className = "panel-subhead"; note.style.borderTop = "none"; note.style.marginTop = "2px";
      note.textContent = "COMMANDER UPGRADES — permanent, army-wide";
      refs.panelBody.appendChild(note);
      for (const up of DATA.UPGRADES) {
        const info = game.upgInfo(facId, up.id);
        const maxed = info.lvl >= info.max;
        const afford = !maxed && side.funds >= info.cost;
        const card = document.createElement("button");
        card.className = "bcard" + (maxed ? " built" : afford ? "" : " poor");
        card.disabled = maxed;
        const pips = Array.from({ length: info.max }, (_, i) =>
          `<i class="pip${i < info.lvl ? " on" : ""}"></i>`).join("");
        card.innerHTML = `
          <span class="bglyph up">${up.glyph}</span>
          <span class="bmain">
            <span class="bname">${up.name} <span class="uppips">${pips}</span></span>
            <span class="bdesc">${up.desc}</span>
          </span>
          <span class="bcost">
            <span class="bfunds ${afford ? "" : "no"}">${maxed ? "MAX" : "$" + U.fmtNum(info.cost)}</span>
            <span class="btime">L${info.lvl}/${info.max}</span>
          </span>`;
        card.onclick = () => {
          const r = game.buyUpgrade(facId, up.id);
          if (!r.ok) { flash(r.reason); Sound.deny(); } else Sound.build();
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
        if (!r.ok) { flash(r.reason); Sound.deny(); } else Sound.ui();
        renderPanel();
      };
      refs.panelBody.appendChild(card);
    }
  }

  /* ---------- support power bar ------------------------------------------- */
  function renderPowers() {
    const side = game.sides[facId];
    refs.powerBar.innerHTML = "";
    POWERS.forEach((p, i) => {
      const ps = game.powerState(facId, p.id);
      const cdLeft = Math.max(0, ps.cd || 0);
      const ready = cdLeft <= 0 && side.funds >= p.cost;
      const el = document.createElement("button");
      el.className = "pwr" + (ready ? "" : " cooling") +
        (state.targeting && state.targeting.id === p.id ? " arming" : "");
      const pct = cdLeft > 0 ? Math.round(100 * cdLeft / p.cd) : 0;
      el.innerHTML = `
        <span class="pwr-key">${POWER_HOTLABELS[i] || ""}</span>
        <span class="pwr-glyph">${p.glyph}</span>
        <span class="pwr-name">${p.name.split(" ")[0]}</span>
        <span class="pwr-cost">$${p.cost}</span>
        ${cdLeft > 0 ? `<span class="pwr-cd" style="height:${pct}%"></span><span class="pwr-cdtxt">${Math.ceil(cdLeft)}s</span>` : ""}`;
      el.title = `${p.name} — ${p.desc} (cost $${p.cost}, cooldown ${p.cd}s)`;
      el.onclick = () => { if (ready) armTargeting("power", p.id, p); else Sound.deny(); };
      refs.powerBar.appendChild(el);
    });
  }

  /* ---------- targeting (powers + defenses) ------------------------------ */
  function armTargeting(kind, id, def) {
    if (state.targeting && state.targeting.id === id) { cancelTargeting(); return; }
    state.targeting = { kind, id, def };
    Sound.ui();
    refs.targetBanner.classList.remove("hidden");
    refs.targetBanner.innerHTML = kind === "power"
      ? `◎ <b>${def.name}</b> — left-click a target · right-click / Esc to cancel`
      : `▣ <b>${def.name}</b> — click to place near your HQ or a held town · Esc to cancel`;
    renderPanel(); renderPowers();
  }
  function cancelTargeting() {
    if (!state.targeting) return;
    state.targeting = null;
    refs.targetBanner.classList.add("hidden");
    renderPanel(); renderPowers();
  }
  function fireTargeting(wx, wy) {
    const t = state.targeting; if (!t) return false;
    let r;
    if (t.kind === "power") r = game.usePower(facId, t.id, wx, wy);
    else r = game.buildDefense(facId, t.id, wx, wy);
    if (!r.ok) { flash(r.reason); Sound.deny(); return true; } // stay armed on failure
    Sound.power();
    cancelTargeting();
    return true;
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
    // domination progress (if that win condition is active)
    const dp = game.domProgress && game.domProgress(facId);
    if (dp != null) {
      const ep = game.domProgress(game.enemyFac);
      refs.statTowns.textContent += `  ⏱${Math.round(dp * 100)}%`;
      refs.statTowns.style.color = dp > 0 ? "#7ef07e" : (ep > 0 ? "#ff8a6a" : "");
    }
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

    const sel = [...state.sel];
    const movable = sel.filter((u) => !u.emplacement && !u.outpost);
    const hasTruck = sel.some((u) => u.def.supplyTruck);
    // dominant stance among the selection
    let stance = movable.length ? movable[0].stance : null;
    for (const u of movable) if (u.stance !== stance) { stance = "mixed"; break; }
    const stances = [["aggressive", "AGGR"], ["defensive", "DEF"], ["hold", "HOLD"], ["holdfire", "FIRE✕"]];
    const stanceBtns = movable.length ? `<div class="cc-row">` +
      stances.map(([s, lbl]) =>
        `<button class="ccbtn${stance === s ? " on" : ""}" data-stance="${s}">${lbl}</button>`).join("") +
      `</div>` : "";
    const outpostBtn = hasTruck
      ? `<div class="cc-row"><button class="ccbtn wide" data-outpost="1">⛏ Deploy Outpost (O)</button></div>` : "";

    refs.selInfo.innerHTML =
      `<div class="sel-head">${state.sel.size} SELECTED · ${Math.round(100 * hp / Math.max(1, maxhp))}% combat</div>
       <div class="sel-rows">${rows}</div>
       ${stanceBtns}${outpostBtn}
       <div class="sel-hint">right-click move/attack · S stop · A attack-move</div>`;

    refs.selInfo.querySelectorAll("[data-stance]").forEach((b) =>
      b.onclick = () => { game.setStance([...state.sel], b.dataset.stance); Sound.ui(); refreshSelInfo(); });
    const ob = refs.selInfo.querySelector("[data-outpost]");
    if (ob) ob.onclick = () => doDeployOutpost();
  }

  function doDeployOutpost() {
    const n = game.deployOutposts([...state.sel]);
    if (n) { flash(`Deploying ${n} forward outpost${n > 1 ? "s" : ""}`, "good"); Sound.power(); refreshSelInfo(); }
    else { flash("Select a supply truck first", "warn"); Sound.deny(); }
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

  on(refs.board, "mousedown", (ev) => {
    if (ev.button === 1) { ev.preventDefault(); panState.mid = boardPos(ev); return; }
    if (ev.button !== 0) return;
    const p = boardPos(ev);
    // targeting mode consumes the left-click
    if (state.targeting) {
      const w = cam.screenToWorld(p.x, p.y);
      fireTargeting(w.x, w.y);
      return;
    }
    dragging = { sx: p.x, sy: p.y, x: p.x, y: p.y, add: ev.shiftKey };
  });

  on(window, "mousemove", (ev) => {
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
    // hover town for capture-range hint + track world cursor (targeting)
    const r = refs.board.getBoundingClientRect();
    if (ev.clientX >= r.left && ev.clientX <= r.right && ev.clientY >= r.top && ev.clientY <= r.bottom) {
      const p = boardPos(ev); const wpt = cam.screenToWorld(p.x, p.y);
      state.cursorW = wpt;
      state.hoverTown = game.towns.find((t) => U.dist2(wpt.x, wpt.y, t.x, t.y) < 46 * 46) || null;
    }
  });

  on(window, "mouseup", (ev) => {
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

  // right-click: orders (or cancel targeting)
  on(refs.board, "contextmenu", (ev) => {
    ev.preventDefault();
    if (state.targeting) { cancelTargeting(); return; }
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
  on(refs.board, "wheel", (ev) => {
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
  on(refs.minimap, "mousedown", (ev) => { ev.preventDefault(); minimapNav(ev); });
  on(refs.minimap, "contextmenu", (ev) => ev.preventDefault());

  /* ---------- keyboard ---------------------------------------------------- */
  const TAB_KEYS = { q: "inf", w: "light", e: "heavy", r: "air", t: "base", y: "upgrade" };
  on(window, "keydown", (ev) => {
    const k = ev.key.toLowerCase();
    if (["arrowup", "arrowdown", "arrowleft", "arrowright"].includes(k)) { panKeys[k] = true; return; }
    if (k === "escape") { cancelTargeting(); return; }
    if (k === " ") { ev.preventDefault(); togglePause(); return; }

    // control groups: Ctrl+N assign, N select (double-tap centers)
    if (/^[1-9]$/.test(k)) {
      if (ev.ctrlKey || ev.metaKey) { ev.preventDefault(); assignGroup(k); }
      else selectGroup(k);
      return;
    }
    if (k === "h") cam.centerOn(game.sides[facId].hq.x, game.sides[facId].hq.y);
    else if (k === "s" && state.sel.size) { game.issueStop([...state.sel]); Sound.ui(); }
    else if (k === "o" && state.sel.size) doDeployOutpost();
    else if (k === "tab") { ev.preventDefault(); cycleIdle(); }
    else if (k in TAB_KEYS) { state.tab = TAB_KEYS[k]; renderPanel(); Sound.ui(); }
    else if (k in POWER_KEYS) {
      const pid = POWER_KEYS[k];
      const p = POWERS.find((x) => x.id === pid);
      if (game.powerReady(facId, pid)) armTargeting("power", pid, p); else Sound.deny();
    }
  });
  on(window, "keyup", (ev) => { panKeys[ev.key.toLowerCase()] = false; });

  /* ---------- control groups --------------------------------------------- */
  function assignGroup(n) {
    state.groups[n] = [...state.sel].filter((u) => u.alive);
    flash(`Group ${n} set (${state.groups[n].length})`, "info");
    Sound.ui();
  }
  function selectGroup(n) {
    const g = (state.groups[n] || []).filter((u) => u.alive);
    if (!g.length) return;
    state.sel.clear(); g.forEach((u) => state.sel.add(u));
    refreshSelInfo();
    const t = game.clock;
    if (state._lastGroupKey === n && (t - state._lastGroupT) < 0.4) {
      // double-tap: center on the group
      let cx = 0, cy = 0; g.forEach((u) => { cx += u.x; cy += u.y; });
      cam.centerOn(cx / g.length, cy / g.length);
    }
    state._lastGroupKey = n; state._lastGroupT = t;
  }

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

  function togglePause(force) {
    state.paused = force != null ? force : !state.paused;
    refs.pauseBtn.textContent = state.paused ? "▶" : "❚❚";
    refs.pauseBtn.classList.toggle("on", state.paused);
    if (refs.pauseOverlay) refs.pauseOverlay.classList.toggle("hidden", !state.paused);
    if (state.paused) cancelTargeting();
  }
  function setSpeed(s) {
    state.speed = s;
    refs.speedBtn.textContent = state.speed + "×";
    if (refs.pauseSpeedBtn) refs.pauseSpeedBtn.textContent = state.speed + "×";
  }

  // double-click empty board sets a production rally point
  on(refs.board, "dblclick", (ev) => {
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

  /* ---------- HUD buttons + pause overlay -------------------------------- */
  const cycleSpeed = () => setSpeed(state.speed === 1 ? 2 : state.speed === 2 ? 3 : 1);
  refs.pauseBtn.onclick = () => togglePause();
  refs.speedBtn.onclick = cycleSpeed;
  if (refs.resumeBtn) refs.resumeBtn.onclick = () => togglePause(false);
  if (refs.pauseSpeedBtn) refs.pauseSpeedBtn.onclick = cycleSpeed;
  if (refs.volSlider) {
    refs.volSlider.value = Math.round(Sound.volume * 100);
    refs.volSlider.oninput = () => { Sound.setVolume(refs.volSlider.value / 100); Sound.ui(); };
  }
  if (refs.muteBtn) {
    const sync = () => { refs.muteBtn.textContent = Sound.enabled ? "ON" : "OFF";
      refs.muteBtn.classList.toggle("off", !Sound.enabled); };
    sync();
    refs.muteBtn.onclick = () => { Sound.setEnabled(!Sound.enabled); sync(); if (Sound.enabled) Sound.ui(); };
  }

  /* ---------- SFX + alert routing ---------------------------------------- */
  game.onSfx = (type, d) => {
    if (type === "explosion") Sound.explosion(d.size || 1);
    else if (type === "capture") { Sound.capture(d.good); }
    else if (type === "build") Sound.build();
    else if (type === "power") { Sound.power(); if (d.msg) flash(d.msg, "info"); }
    else if (type === "alert") {
      Sound.alert();
      if (d.msg) flash(d.msg, "bad");
      if (d.x != null) pings.push({ x: d.x, y: d.y, col: "#ff5a4d", t: 0, alert: true });
    }
  };

  /* ---------- camera keys update ----------------------------------------- */
  function updateCamera(dt) {
    const sp = 680 * dt / cam.zoom;
    if (panKeys["arrowup"]) cam.panBy(0, -sp);
    if (panKeys["arrowdown"]) cam.panBy(0, sp);
    if (panKeys["arrowleft"]) cam.panBy(-sp, 0);
    if (panKeys["arrowright"]) cam.panBy(sp, 0);
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
    playFxSounds();
    // throttle DOM updates
    hudT += realDt;
    if (hudT > 0.12) { hudT = 0; refreshHud(); renderQueue(); renderPowers(); }
    panelT += realDt;
    if (panelT > 0.4) { panelT = 0; renderPanelAffordability(); }
    // update pings (alert pings linger + pulse)
    for (let i = pings.length - 1; i >= 0; i--) {
      pings[i].t += realDt;
      if (pings[i].t > (pings[i].alert ? 1.8 : 0.6)) pings.splice(i, 1);
    }
  }

  // turn fresh tracer/arty effects into (throttled) gunfire sound
  function playFxSounds() {
    if (!Sound.enabled) return;
    const t = game.clock;
    for (const e of game.fx) {
      if (e._snd) continue;
      e._snd = true;
      if (e.kind === "arty") Sound.shot("arty", t);
      else if (e.kind === "tracer") Sound.shot("shot", t);
    }
  }

  // lightweight affordability refresh without rebuilding the whole panel
  function renderPanelAffordability() {
    const side = game.sides[facId];
    const cards = refs.panelBody.querySelectorAll(".bcard");
    if (!cards.length) return;
    if (state.tab === "base" || state.tab === "upgrade") { renderPanel(); return; }
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
      if (p.alert) {
        const k = (p.t % 0.6) / 0.6;
        ctx.strokeStyle = p.col; ctx.globalAlpha = (1 - k) * (p.t < 1.5 ? 1 : (1.8 - p.t) / 0.3);
        ctx.lineWidth = 2.5;
        ctx.beginPath(); ctx.arc(s.x, s.y, 6 + k * 26, 0, Math.PI * 2); ctx.stroke();
      } else {
        const k = p.t / 0.6;
        ctx.strokeStyle = p.col; ctx.globalAlpha = 1 - k; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(s.x, s.y, 4 + k * 18, 0, Math.PI * 2); ctx.stroke();
      }
      ctx.globalAlpha = 1;
    }
  }

  // draw the targeting reticle / placement validity (world space, called by render)
  function drawTargeting(ctx) {
    if (!state.targeting) return;
    const t = state.targeting;
    const c = state.cursorW;
    const s = cam.worldToScreen(c.x, c.y);
    ctx.save();
    if (t.kind === "power") {
      const rad = (t.id === "artillery" ? 90 : t.id === "airstrike" ? 180 : t.id === "smoke" ? 120 : 45) * cam.zoom;
      ctx.strokeStyle = "rgba(255,210,90,0.9)"; ctx.lineWidth = 2; ctx.setLineDash([6, 6]);
      ctx.beginPath(); ctx.arc(s.x, s.y, rad, 0, Math.PI * 2); ctx.stroke();
      ctx.setLineDash([]);
      ctx.beginPath(); ctx.moveTo(s.x - 14, s.y); ctx.lineTo(s.x + 14, s.y);
      ctx.moveTo(s.x, s.y - 14); ctx.lineTo(s.x, s.y + 14); ctx.stroke();
    } else {
      const valid = game.canPlaceDefense(facId, c.x, c.y);
      ctx.strokeStyle = valid ? "rgba(120,240,120,0.95)" : "rgba(255,90,80,0.95)";
      ctx.fillStyle = valid ? "rgba(120,240,120,0.12)" : "rgba(255,90,80,0.12)";
      ctx.lineWidth = 2;
      const r = 16 * cam.zoom;
      ctx.beginPath(); ctx.rect(s.x - r, s.y - r, r * 2, r * 2); ctx.fill(); ctx.stroke();
      const rng = (t.def.range || 0) * cam.zoom;
      if (rng) { ctx.setLineDash([4, 6]); ctx.globalAlpha = 0.5;
        ctx.beginPath(); ctx.arc(s.x, s.y, rng, 0, Math.PI * 2); ctx.stroke();
        ctx.setLineDash([]); ctx.globalAlpha = 1; }
    }
    ctx.restore();
  }

  renderPanel();
  renderPowers();
  refreshHud();
  setSpeed(state.speed); // sync HUD + overlay speed labels

  function destroy() {
    for (const [t, type, fn, opts] of _listeners) t.removeEventListener(type, fn, opts);
    _listeners.length = 0;
  }

  return {
    state, cam, tick, drawPings, drawTargeting, togglePause, setSpeed, destroy,
    restart: null, // assigned by main
    get paused() { return state.paused; },
    get speed() { return state.speed; },
    uiState() { return { sel: state.sel, box: state.box, rally: state.rally,
      hoverTown: state.hoverTown, targeting: state.targeting }; },
    renderPanel, renderPowers,
  };
}
