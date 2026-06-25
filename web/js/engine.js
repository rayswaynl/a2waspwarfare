/* =============================================================================
 * engine.js — the simulation. Owns all game state and the fixed update step.
 * Rendering and input live elsewhere; they only read state + call commands.
 * ========================================================================== */

function createGame(opts) {
  "use strict";
  const { FACTIONS, ROSTER, UNIT_BY_ID, STRUCT_BY_ID, STRUCTURES, MAPS, DIFFICULTY, RULES,
          POWERS, DEFENSES, DEFENSE_BY_ID, UPGRADES, UPGRADE_BY_ID, OUTPOST_DEF, WIN_CONDITIONS,
          WEATHER, POINT_TYPES } = DATA;

  const playerFac = opts.faction;                       // "USMC" | "RU"
  const enemyFac  = playerFac === "USMC" ? "RU" : "USMC";
  const diff      = DIFFICULTY[opts.difficulty] || DIFFICULTY.veteran;
  const MAP       = MAPS[opts.map] || MAPS.chernarus;
  const WORLD     = MAP.world;
  const winCond   = WIN_CONDITIONS[opts.winCond] || WIN_CONDITIONS.conquest;
  const fogEnabled = opts.fog !== false;                 // skirmish toggle
  const rng       = U.makeRng(opts.seed || 1337);

  // Weather: explicit choice, or "auto" → biome-appropriate roll.
  function pickWeather() {
    if (opts.weather && opts.weather !== "auto" && WEATHER[opts.weather]) return WEATHER[opts.weather];
    const roll = rng();
    if (MAP.biome === "desert") return roll < 0.4 ? WEATHER.sandstorm : roll < 0.7 ? WEATHER.clear : WEATHER.overcast;
    return roll < 0.38 ? WEATHER.rain : roll < 0.68 ? WEATHER.overcast : WEATHER.clear;
  }
  const weather = pickWeather();

  let nextId = 1;

  /* ---- per-side state --------------------------------------------------- */
  function makeSide(facId, isPlayer) {
    const fac = FACTIONS[facId];
    return {
      fac: facId, isPlayer, color: fac.color,
      funds: opts.startFunds || diff.startFunds,
      supplyCap: RULES.baseSupplyCap,
      structures: new Set(RULES.startStructures),
      queue: [],            // {kind:'unit', def, timeLeft, total}
      building: [],         // {kind:'struct', struct, timeLeft, total}
      depots: 0,
      hq: null,             // set below
      income: 0,            // last computed funds/sec (display)
      kills: 0, losses: 0, spent: 0,
    };
  }

  const sides = {
    [playerFac]: makeSide(playerFac, true),
    [enemyFac]:  makeSide(enemyFac, false),
  };

  /* ---- entities --------------------------------------------------------- */
  const units = [];
  const fx = [];            // transient visual effects (tracers, blasts)
  const floats = [];        // floating combat text
  const parts = [];         // particles (smoke, dust, sparks, craters)

  /* ---- spatial hash: keeps acquisition/area queries near O(n) ----------- */
  const GRID_CELL = 160;
  const grid = {
    cols: Math.ceil(WORLD.w / GRID_CELL), rows: Math.ceil(WORLD.h / GRID_CELL),
    cells: null,
    key(cx, cy) { return cy * this.cols + cx; },
    build(list) {
      this.cells = new Map();
      for (const u of list) {
        if (!u.alive) continue;
        const cx = U.clamp((u.x / GRID_CELL) | 0, 0, this.cols - 1);
        const cy = U.clamp((u.y / GRID_CELL) | 0, 0, this.rows - 1);
        const k = this.key(cx, cy);
        let b = this.cells.get(k); if (!b) this.cells.set(k, (b = []));
        b.push(u);
      }
    },
    forEachInRadius(x, y, r, fn) {
      const minx = U.clamp(((x - r) / GRID_CELL) | 0, 0, this.cols - 1);
      const maxx = U.clamp(((x + r) / GRID_CELL) | 0, 0, this.cols - 1);
      const miny = U.clamp(((y - r) / GRID_CELL) | 0, 0, this.rows - 1);
      const maxy = U.clamp(((y + r) / GRID_CELL) | 0, 0, this.rows - 1);
      for (let cy = miny; cy <= maxy; cy++)
        for (let cx = minx; cx <= maxx; cx++) {
          const b = this.cells.get(this.key(cx, cy));
          if (b) for (const u of b) fn(u);
        }
    },
  };

  function makeHQ(facId) {
    const p = MAP.hq[facId];
    return {
      id: nextId++, kind: "hq", fac: facId,
      x: p.x, y: p.y, hp: RULES.hqHp, maxHp: RULES.hqHp,
      range: 300, dmg: 26, rof: 1.4, cd: 0, sight: 360,
      lastHit: 999,
    };
  }
  sides[playerFac].hq = makeHQ(playerFac);
  sides[enemyFac].hq  = makeHQ(enemyFac);

  /* ---- towns ------------------------------------------------------------ */
  const towns = MAP.towns.map((t) => ({
    def: t, id: t.id, name: t.name, x: t.x, y: t.y, sv: t.sv,
    owner: null,            // facId | null
    cap: 0,                 // 0..100 hold strength for current owner / capturer
    capturer: null,         // facId currently pushing cap up when owner null
    contested: false,
    garrisonLeft: t.garrison,
  }));
  const townById = {};
  towns.forEach((t) => (townById[t.id] = t));

  /* ---- strategic points (radar / oil / repair) -------------------------- */
  const points = (MAP.points || []).map((p) => ({
    def: p, id: p.id, name: p.name, type: p.type, x: p.x, y: p.y,
    owner: null, cap: 0, contested: false,
  }));

  /* ---- smoke screens (vision-blocking, damage-reducing clouds) ----------- */
  const smokes = [];   // { x, y, r, t, life }
  function inSmoke(x, y) {
    for (const s of smokes) if (U.dist2(x, y, s.x, s.y) < s.r * s.r) return true;
    return false;
  }

  /* ---- spawn helpers ---------------------------------------------------- */
  function spawnUnit(facId, def, x, y, opt) {
    opt = opt || {};
    const hm = (facId === playerFac || facId === enemyFac) ? hpMult(facId) : 1;
    const maxHp = Math.round(def.hp * hm);
    const u = {
      id: nextId++, kind: "unit", fac: facId, def,
      x, y, hp: maxHp, maxHp,
      cd: rng() * 0.5, alive: true,
      order: { type: opt.order || "guard", x: null, y: null, target: null },
      target: null,          // current acquired enemy
      home: opt.home || null,
      muzzle: 0, hitFlash: 0, supplyBoost: 0,
      kills: 0, rank: 0,     // veterancy
      stance: def.cat === "inf" || def.cat === "light" || def.cat === "heavy" || def.air ? "aggressive" : "hold",
      emplacement: !!def.emplacement,
      heading: opt.heading != null ? opt.heading : (facId === playerFac ? -Math.PI / 2 : Math.PI / 2),
    };
    units.push(u);
    return u;
  }

  // Veterancy thresholds → rank 1/2/3. Higher rank = more damage + more HP.
  const VET_KILLS = [3, 8, 16];
  function creditKill(killer) {
    if (!killer || killer.fac === "GARRISON" || !killer.def) return;
    killer.kills++;
    let nr = 0;
    for (let i = 0; i < VET_KILLS.length; i++) if (killer.kills >= VET_KILLS[i]) nr = i + 1;
    if (nr > killer.rank) {
      killer.rank = nr;
      const boost = 1 + 0.10 * nr;
      const ratio = killer.hp / killer.maxHp;
      killer.maxHp = Math.round(killer.def.hp * boost);
      killer.hp = Math.min(killer.maxHp, killer.maxHp * ratio + killer.def.hp * 0.15);
      floats.push({ txt: "PROMOTED", x: killer.x, y: killer.y - 14, t: 0, col: "#e3c14a" });
    }
  }

  // Each side opens holding the towns nearest its HQ — this bootstraps the
  // economy and forms a natural front line in the contested middle towns.
  function assignStartingTowns() {
    const taken = new Set();
    const give = (facId, count) => {
      const hq = MAP.hq[facId];
      const ranked = towns
        .filter((t) => !taken.has(t.id))
        .sort((a, b) => U.dist2(a.x, a.y, hq.x, hq.y) - U.dist2(b.x, b.y, hq.x, hq.y));
      for (let i = 0; i < count && i < ranked.length; i++) {
        const t = ranked[i];
        t.owner = facId; t.cap = 100; t.garrisonLeft = 0; taken.add(t.id);
      }
    };
    give(playerFac, 2);
    give(enemyFac, 2);
  }
  assignStartingTowns();

  // Neutral garrisons defend the still-unclaimed (middle) towns. Side "GARRISON".
  function seedGarrisons() {
    for (const t of towns) {
      if (t.owner) continue; // owned towns start undefended/secured
      const baseDefs = ROSTER[playerFac].filter((d) => d.cat === "inf" && !d.heal);
      for (let i = 0; i < t.def.garrison; i++) {
        const def = i === 0 ? baseDefs.find((d) => d.id.includes("ar")) || baseDefs[0]
                            : baseDefs[i % baseDefs.length];
        const ang = rng() * Math.PI * 2, r = 20 + rng() * 45;
        const g = spawnUnit("GARRISON", def, t.x + Math.cos(ang) * r, t.y + Math.sin(ang) * r,
          { order: "hold", home: { x: t.x, y: t.y } });
        g.garrison = true;
      }
    }
  }

  // Opening forces so the field isn't empty.
  function seedStarters() {
    for (const facId of [playerFac, enemyFac]) {
      const hq = sides[facId].hq;
      const roster = ROSTER[facId];
      const starters = ["rifle", "rifle", "ar", "lat"];
      starters.forEach((tag, i) => {
        const def = roster.find((d) => d.id.endsWith(tag)) || roster[0];
        const ang = facId === playerFac ? -Math.PI / 2 : Math.PI / 2;
        spawnUnit(facId, def, hq.x + (i - 1.5) * 34, hq.y + (facId === playerFac ? -50 : 50),
          { heading: ang });
      });
    }
  }
  seedGarrisons();
  seedStarters();

  /* ---- classification helpers ------------------------------------------ */
  const targetClass = (u) => (u.def.air ? "air" : (u.def.cat === "inf" ? "inf" : "veh"));

  // Throttled "HQ under attack" alert.
  function maybeAlertHQ(hq) {
    if (hq.fac !== playerFac) return;
    if ((clock - (hq._alertT || -99)) < 12) return;
    hq._alertT = clock;
    emitSfx("alert", { x: hq.x, y: hq.y, msg: "Your HQ is under attack!" });
  }
  const isEnemySides = (a, b) => {
    if (a === b) return false;
    if (a === "GARRISON" || b === "GARRISON") return true; // garrison fights everyone
    return true;
  };

  /* ---- combat ----------------------------------------------------------- */
  function applyDamage(src, tgt, dt) {
    if (!src.def || src.def.rof <= 0 || src.def.range <= 0) return;
    src.cd -= dt;
    if (src.cd > 0) return;
    src.cd += 1 / src.def.rof;
    const cls = tgt.kind === "hq" ? "veh" : targetClass(tgt);
    let dmg = src.def.dmg * (src.def.vs[cls] || 1) * (1 + 0.12 * (src.rank || 0)) * dmgMult(src.fac);
    const armor = tgt.kind === "hq" ? 4 : (tgt.def.armor || 0);
    dmg = Math.max(1, dmg - armor) * (1 - 0.06 * (tgt.rank || 0));
    // air is slippery vs unguided small arms
    if (tgt.def && tgt.def.air && cls === "air" && src.def.cat === "inf" && !src.def.vs.air) dmg *= 0.4;
    // forest cover: dug-in infantry take less fire
    if (tgt.def && tgt.def.cat === "inf" && !tgt.emplacement && inForest(tgt.x, tgt.y)) dmg *= 0.6;
    // weather degrades aim; smoke screens cut incoming fire
    dmg *= weather.accuracy;
    if (smokes.length && (inSmoke(tgt.x, tgt.y) || inSmoke(src.x, src.y))) dmg *= 0.5;
    tgt.hp -= dmg;
    tgt.hitFlash = 0.18;
    if (tgt.hp <= 0 && !tgt._killer) tgt._killer = src;
    if (tgt.kind === "hq") { tgt.lastHit = 0; maybeAlertHQ(tgt); }
    src.muzzle = 0.09;
    // impact spark
    if (rng() < 0.5) particle({ kind: "spark", x: tgt.x, y: tgt.y, vx: (rng() - 0.5) * 40,
      vy: -10 - rng() * 30, t: 0, life: 0.3, r: 1.5, col: "rgba(255,210,120," });
    // visual tracer + occasional float
    fx.push({ kind: src.def.arty ? "arty" : "tracer", x: src.x, y: src.y, tx: tgt.x, ty: tgt.y,
      t: 0, life: src.def.arty ? 0.5 : 0.12, col: src.fac === "GARRISON" ? "#cfcf9a" : FACTIONS[src.fac].color });
    if (src.def.arty) { fx.push({ kind: "blast", x: tgt.x, y: tgt.y, t: 0, life: 0.45, r: 36 }); smokeAt(tgt.x, tgt.y, 2); }
  }

  function healAround(medic, dt) {
    for (const u of units) {
      if (u === medic || u.fac !== medic.fac || !u.alive) continue;
      if (U.dist2(u.x, u.y, medic.x, medic.y) < 90 * 90 && u.hp < u.maxHp) {
        u.hp = Math.min(u.maxHp, u.hp + medic.def.heal * dt);
      }
    }
  }

  /* ---- acquisition ------------------------------------------------------ */
  function acquire(u) {
    // keep current target if still valid + in sight
    const sightR = u.def.sight;
    if (u.target && u.target.alive !== false && (u.target.hp > 0) &&
        U.dist2(u.x, u.y, u.target.x, u.target.y) < (sightR * 1.25) ** 2) return u.target;
    let best = null, bestD = (sightR) ** 2;
    grid.forEachInRadius(u.x, u.y, sightR, (o) => {
      if (!o.alive || !isEnemySides(u.fac, o.fac)) return;
      const d = U.dist2(u.x, u.y, o.x, o.y);
      // concealed infantry in forest are only spotted up close
      if (o.def.cat === "inf" && !o.emplacement && inForest(o.x, o.y) && d > (sightR * 0.5) ** 2) return;
      // smoke conceals targets beyond short range
      if (smokes.length && inSmoke(o.x, o.y) && d > (sightR * 0.35) ** 2) return;
      if (d < bestD) { bestD = d; best = o; }
    });
    // HQ as target if very close and we belong to the other side
    for (const facId of Object.keys(sides)) {
      if (facId === u.fac) continue;
      const hq = sides[facId].hq;
      if (hq.hp > 0) {
        const d = U.dist2(u.x, u.y, hq.x, hq.y);
        if (d < bestD && d < (sightR * 1.1) ** 2) { bestD = d; best = hq; }
      }
    }
    u.target = best;
    return best;
  }

  /* ---- movement --------------------------------------------------------- */
  function moveToward(u, tx, ty, dt, stopDist) {
    const dx = tx - u.x, dy = ty - u.y;
    const d = Math.hypot(dx, dy);
    if (d <= (stopDist || 2)) return true;
    const sp = u.def.speed * dt;
    const nx = dx / d, ny = dy / d;
    u.x += nx * Math.min(sp, d);
    u.y += ny * Math.min(sp, d);
    u.x = U.clamp(u.x, 8, WORLD.w - 8);
    u.y = U.clamp(u.y, 8, WORLD.h - 8);
    u.heading = Math.atan2(ny, nx);
    return false;
  }

  function updateUnit(u, dt) {
    if (u.hitFlash > 0) u.hitFlash -= dt;
    if (u.muzzle > 0) u.muzzle -= dt;
    if (u._para > 0) u._para -= dt;

    if (u.def.heal) healAround(u, dt);
    if (u.def.repair) repairAround(u, dt);
    // emplacements / outposts never move — engage only, then bail
    if (u.emplacement || u.outpost) {
      if (u.def.range > 0) {
        const e = acquire(u);
        if (e && U.dist2(u.x, u.y, e.x, e.y) < u.def.range ** 2) applyDamage(u, e, dt);
      }
      return;
    }

    const enemy = acquire(u);
    const ord = u.order;

    // Garrison: leash to home, defend.
    if (u.garrison) {
      if (enemy && U.dist2(u.x, u.y, enemy.x, enemy.y) < (u.def.range * 1.1) ** 2) {
        applyDamage(u, enemy, dt);
      } else if (enemy && U.dist2(u.x, u.y, u.home.x, u.home.y) < 160 * 160) {
        moveToward(u, enemy.x, enemy.y, dt, u.def.range * 0.8);
      } else {
        moveToward(u, u.home.x, u.home.y, dt, 6);
      }
      return;
    }

    // Explicit move/attack-move order.
    if (ord.type === "move" || ord.type === "attackmove") {
      // attack-move: pause to engage things in range, else keep walking.
      if (ord.type === "attackmove" && enemy &&
          U.dist2(u.x, u.y, enemy.x, enemy.y) < (u.def.range) ** 2) {
        applyDamage(u, enemy, dt);
        return;
      }
      const arrived = moveToward(u, ord.x, ord.y, dt, 6);
      // still shoot while moving if something is point-blank
      if (enemy && u.def.range > 0 &&
          U.dist2(u.x, u.y, enemy.x, enemy.y) < (u.def.range * 0.85) ** 2) applyDamage(u, enemy, dt);
      if (arrived) u.order = { type: "guard", x: u.x, y: u.y, target: null };
      return;
    }

    if (ord.type === "attack" && ord.target && ord.target.hp > 0 && ord.target.alive !== false) {
      const t = ord.target;
      if (U.dist2(u.x, u.y, t.x, t.y) < (u.def.range) ** 2) applyDamage(u, t, dt);
      else moveToward(u, t.x, t.y, dt, u.def.range * 0.85);
      return;
    }

    // Default behaviour shaped by stance:
    //   aggressive — engage and chase within a leash
    //   defensive  — engage in range, never chase
    //   hold       — hold ground, engage in range
    //   holdfire   — hold ground, do not fire (ambush / sneak)
    const canFire = u.stance !== "holdfire";
    if (enemy) {
      const dd = U.dist2(u.x, u.y, enemy.x, enemy.y);
      if (dd < (u.def.range) ** 2) {
        if (canFire) applyDamage(u, enemy, dt);
      } else if (u.stance === "aggressive" && ord.type !== "hold") {
        const leashOk = !u.home || U.dist2(u.x, u.y, u.home.x, u.home.y) < 420 * 420;
        if (leashOk) moveToward(u, enemy.x, enemy.y, dt, u.def.range * 0.85);
      }
    }
  }

  /* ---- HQ behaviour ----------------------------------------------------- */
  function updateHQ(hq, dt) {
    hq.lastHit += dt;
    if (hq.lastHit > 3 && hq.hp < hq.maxHp) hq.hp = Math.min(hq.maxHp, hq.hp + RULES.hqRepair * dt);
    // auto turret
    hq.cd -= dt;
    let best = null, bestD = hq.range ** 2;
    grid.forEachInRadius(hq.x, hq.y, hq.range, (o) => {
      if (!o.alive || o.fac === hq.fac) return;
      const d = U.dist2(o.x, o.y, hq.x, hq.y);
      if (d < bestD) { bestD = d; best = o; }
    });
    if (best && hq.cd <= 0) {
      hq.cd += 1 / hq.rof;
      const cls = targetClass(best);
      let dmg = Math.max(1, hq.dmg * (cls === "air" ? 1.4 : 1) - (best.def.armor || 0));
      best.hp -= dmg; best.hitFlash = 0.18;
      fx.push({ kind: "tracer", x: hq.x, y: hq.y - 20, tx: best.x, ty: best.y, t: 0, life: 0.12,
        col: FACTIONS[hq.fac].color });
    }
  }

  /* ---- towns / capture -------------------------------------------------- */
  function updateTown(t, dt) {
    let pc = 0, ec = 0, gc = 0; // player, enemy, garrison counts (weighted)
    grid.forEachInRadius(t.x, t.y, RULES.captureRange, (u) => {
      if (!u.alive) return;
      if (u.emplacement) return; // static defenses don't capture
      if (U.dist2(u.x, u.y, t.x, t.y) > RULES.captureRange ** 2) return;
      const w = u.def.air ? 0.5 : (u.def.cat === "inf" ? 1 : 1.5);
      if (u.fac === playerFac) pc += w;
      else if (u.fac === enemyFac) ec += w;
      else gc += w;
    });
    t.garrisonLeft = gc;
    t.contested = (pc > 0 && ec > 0) || (gc > 0 && (pc > 0 || ec > 0));
    // Alert the player when one of their towns comes under enemy pressure.
    if (t.owner === playerFac && ec > 0 && (clock - (t._alertT || -99)) > 14) {
      t._alertT = clock;
      emitSfx("alert", { x: t.x, y: t.y, msg: `${t.name} is under attack!` });
    }
    // Garrison blocks capture entirely while alive & present.
    if (gc > 0.5) { t._ca = pc; t._ea = ec; return; }

    const attackerFac = pc > ec ? playerFac : ec > pc ? enemyFac : null;
    const attackerCount = Math.max(pc, ec), defenderCount = Math.min(pc, ec);

    if (!attackerFac) return; // nobody, or perfectly contested -> frozen

    if (t.owner === attackerFac) {
      t.cap = Math.min(100, t.cap + RULES.captureRate * dt); // consolidate
    } else {
      const push = RULES.captureRate * dt * (1 + 0.25 * (attackerCount - defenderCount));
      t.cap -= push;
      if (t.cap <= 0) {
        const flipped = t.owner != null;
        t.owner = attackerFac;
        t.cap = 0.01;
        const s = sides[attackerFac];
        s.funds += t.sv * RULES.captureFundsBonus;
        log(`${FACTIONS[attackerFac].name} ${flipped ? "seized" : "secured"} ${t.name} (+${t.sv * RULES.captureFundsBonus} funds)`,
          attackerFac === playerFac ? "good" : "bad");
        emitSfx("capture", { good: attackerFac === playerFac, x: t.x, y: t.y });
      }
    }
  }

  /* ---- strategic points (no garrison; fast capture; passive effects) ---- */
  function updatePoints(dt) {
    for (const p of points) {
      let pc = 0, ec = 0;
      grid.forEachInRadius(p.x, p.y, RULES.pointCaptureRange, (u) => {
        if (!u.alive || u.emplacement || u.outpost) return;
        if (U.dist2(u.x, u.y, p.x, p.y) > RULES.pointCaptureRange ** 2) return;
        const w = u.def.air ? 0.5 : 1;
        if (u.fac === playerFac) pc += w; else if (u.fac === enemyFac) ec += w;
      });
      p.contested = pc > 0 && ec > 0;
      const att = pc > ec ? playerFac : ec > pc ? enemyFac : null;
      if (att) {
        if (p.owner === att) p.cap = Math.min(100, p.cap + RULES.pointCaptureRate * dt);
        else {
          p.cap -= RULES.pointCaptureRate * dt;
          if (p.cap <= 0) {
            p.owner = att; p.cap = 0.01;
            log(`${FACTIONS[att].name} captured the ${p.name}`, att === playerFac ? "good" : "bad");
            emitSfx("capture", { good: att === playerFac, x: p.x, y: p.y });
          }
        }
      }
      // repair depot heal aura for the owner
      if (p.type === "repair" && p.owner) {
        grid.forEachInRadius(p.x, p.y, 150, (o) => {
          if (o.alive && o.fac === p.owner && o.hp < o.maxHp && U.dist2(o.x, o.y, p.x, p.y) < 150 * 150)
            o.hp = Math.min(o.maxHp, o.hp + RULES.pointRepairRate * dt);
        });
      }
    }
  }

  /* ---- economy ---------------------------------------------------------- */
  let incomeTimer = 0;
  function tickEconomy(dt) {
    // compute display income/sec
    for (const facId of [playerFac, enemyFac]) {
      let inc = 0;
      for (const t of towns) if (t.owner === facId) inc += t.sv * RULES.incomePerSV;
      let mult = (facId === enemyFac ? diff.aiFunds : 1) * incomeMult(facId);
      let oil = 0;
      for (const p of points) if (p.owner === facId && p.type === "oil") oil += RULES.oilIncome;
      sides[facId].income = inc * mult + oil;
    }
    incomeTimer += dt;
    if (incomeTimer >= RULES.incomeInterval) {
      incomeTimer -= RULES.incomeInterval;
      for (const facId of [playerFac, enemyFac]) {
        sides[facId].funds += sides[facId].income * RULES.incomeInterval;
      }
    }
  }

  /* ---- production ------------------------------------------------------- */
  function supplyUsed(facId) {
    let s = 0;
    for (const u of units) if (u.alive && u.fac === facId) s += u.def.sup;
    for (const q of sides[facId].queue) s += q.def.sup;
    return s;
  }
  function supplyCap(facId) {
    // base ceiling + supply depots + per-town bonus + outposts + logistics upgrade,
    // so taking ground and deploying outposts expands the army you can field.
    let outposts = 0;
    for (const u of units) if (u.alive && u.fac === facId && u.outpost && !u.building) outposts++;
    return sides[facId].supplyCap + sides[facId].depots * 6 + townsOwned(facId) * 2
      + outposts * 5 + upgSupply(facId);
  }
  function hasStructure(facId, id) { return sides[facId].structures.has(id); }

  // A unit category is unlocked when a built structure unlocks it
  // (e.g. category "inf" is unlocked by the "barracks" structure).
  function catUnlocked(facId, cat) {
    for (const sid of sides[facId].structures) {
      const st = STRUCT_BY_ID[sid];
      if (st && st.unlocks === cat) return true;
    }
    return false;
  }

  function queueUnit(facId, unitId) {
    const def = UNIT_BY_ID[unitId];
    const s = sides[facId];
    if (!def) return { ok: false, reason: "unknown" };
    if (!catUnlocked(facId, def.cat)) return { ok: false, reason: "Need " + structName(def.cat) };
    if (s.funds < def.cost) return { ok: false, reason: "Not enough funds" };
    if (supplyUsed(facId) + def.sup > supplyCap(facId)) return { ok: false, reason: "Supply full" };
    s.funds -= def.cost; s.spent += def.cost;
    const bt = def.build * buildMult(facId);
    s.queue.push({ kind: "unit", def, timeLeft: bt, total: bt });
    return { ok: true };
  }

  function queueStructure(facId, structId) {
    const st = STRUCT_BY_ID[structId];
    const s = sides[facId];
    if (!st) return { ok: false, reason: "unknown" };
    if (s.structures.has(structId) && structId !== "depot") return { ok: false, reason: "Already built" };
    if (s.building.some((b) => b.struct.id === structId) && structId !== "depot")
      return { ok: false, reason: "In progress" };
    // structures cost SUPPLY (logistics), as in the source mission
    if (supplyCap(facId) - supplyUsed(facId) < 0) { /* allow */ }
    if (s.funds < st.cost) return { ok: false, reason: "Not enough funds" };
    s.funds -= st.cost; s.spent += st.cost;
    s.building.push({ kind: "struct", struct: st, timeLeft: st.build, total: st.build });
    return { ok: true };
  }

  function structName(cat) {
    const s = STRUCTURES.find((x) => x.unlocks === cat);
    return s ? s.name : cat;
  }

  function advanceProduction(facId, dt) {
    const s = sides[facId];
    // units
    if (s.queue.length) {
      const head = s.queue[0];
      head.timeLeft -= dt;
      if (head.timeLeft <= 0) {
        s.queue.shift();
        const hq = s.hq;
        const ang = facId === playerFac ? -Math.PI / 2 : Math.PI / 2;
        const off = (rng() - 0.5) * 70;
        const u = spawnUnit(facId, head.def,
          hq.x + off, hq.y + (facId === playerFac ? -64 : 64), { heading: ang });
        // player rally point
        if (s.rally) u.order = { type: "attackmove", x: s.rally.x, y: s.rally.y, target: null };
      }
    }
    // structures
    if (s.building.length) {
      const b = s.building[0];
      b.timeLeft -= dt;
      if (b.timeLeft <= 0) {
        s.building.shift();
        if (b.struct.id === "depot") s.depots++;
        else s.structures.add(b.struct.id);
        if (facId === playerFac) { log(`${b.struct.name} online`, "good"); emitSfx("build", {}); }
      }
    }
  }

  /* ---- cleanup / win-lose ---------------------------------------------- */
  let over = null; // {winner, reason}
  function cleanup() {
    for (let i = units.length - 1; i >= 0; i--) {
      const u = units[i];
      if (u.hp <= 0) {
        u.alive = false;
        const big = u.def.cat !== "inf";
        fx.push({ kind: "blast", x: u.x, y: u.y, t: 0, life: 0.4, r: big ? 26 : 14 });
        emitSfx("explosion", { x: u.x, y: u.y, size: big ? 1 : 0.5 });
        // wreckage: crater + smoke + sparks
        if (big || u.emplacement || u.outpost) {
          particle({ kind: "crater", x: u.x, y: u.y, vx: 0, vy: 0, t: 0, life: 18, r: 9 + rng() * 5, col: "rgba(20,16,12," });
          smokeAt(u.x, u.y, 5);
          for (let k = 0; k < 6; k++) particle({ kind: "spark", x: u.x, y: u.y,
            vx: (rng() - 0.5) * 90, vy: -20 - rng() * 60, t: 0, life: 0.4 + rng() * 0.3, r: 1.5, col: "rgba(255,180,80," });
        } else smokeAt(u.x, u.y, 1);
        if (u.fac === playerFac || u.fac === enemyFac) {
          sides[u.fac].losses++;
          const killerSide = u.fac === playerFac ? enemyFac : playerFac;
          sides[killerSide].kills++;
        }
        // credit the unit that landed the kill (veterancy)
        if (u._killer && u._killer.alive && u._killer.fac !== u.fac) creditKill(u._killer);
        units.splice(i, 1);
      }
    }
  }

  const domTimer = { [playerFac]: 0, [enemyFac]: 0 };
  function checkEnd(dt) {
    if (over) return;
    if (sides[playerFac].hq.hp <= 0) { over = { winner: enemyFac, reason: "Your HQ was overrun." }; return; }
    if (sides[enemyFac].hq.hp <= 0) { over = { winner: playerFac, reason: "Enemy HQ destroyed." }; return; }
    if (towns.every((t) => t.owner === playerFac)) { over = { winner: playerFac, reason: "Total territorial control." }; return; }
    if (towns.every((t) => t.owner === enemyFac)) { over = { winner: enemyFac, reason: "The enemy holds every town." }; return; }
    if (winCond.id === "domination") {
      const need = Math.ceil(towns.length / 2) + 1;
      for (const f of [playerFac, enemyFac]) {
        if (townsOwned(f) >= need) domTimer[f] += dt || 0; else domTimer[f] = 0;
        if (domTimer[f] >= RULES.dominationHold) {
          over = { winner: f, reason: `${FACTIONS[f].name} dominated the region.` }; return;
        }
      }
    }
  }
  function domProgress(facId) {
    if (winCond.id !== "domination") return null;
    return U.clamp(domTimer[facId] / RULES.dominationHold, 0, 1);
  }

  /* ---- effects ---------------------------------------------------------- */
  function updateFx(dt) {
    for (let i = fx.length - 1; i >= 0; i--) {
      fx[i].t += dt;
      if (fx[i].t >= fx[i].life) fx.splice(i, 1);
    }
    for (let i = floats.length - 1; i >= 0; i--) {
      floats[i].t += dt; floats[i].y -= 14 * dt;
      if (floats[i].t > 1.1) floats.splice(i, 1);
    }
  }

  /* ---- log + sfx -------------------------------------------------------- */
  const logs = [];
  function log(msg, type) {
    logs.push({ msg, type: type || "info", t: clock });
    if (logs.length > 60) logs.shift();
    if (game.onLog) game.onLog(msg, type || "info");
  }
  function emitSfx(type, data) { if (game.onSfx) game.onSfx(type, data || {}); }

  /* ---- delayed-action scheduler (for support powers) -------------------- */
  const scheduled = [];
  function schedule(delay, fn) { scheduled.push({ at: clock + delay, fn }); }
  function runScheduled() {
    for (let i = scheduled.length - 1; i >= 0; i--) {
      if (clock >= scheduled[i].at) { const a = scheduled[i]; scheduled.splice(i, 1); a.fn(); }
    }
  }

  // Area damage that spares the casting side (keeps support powers fun).
  function damageArea(casterFac, x, y, radius, dmg) {
    grid.forEachInRadius(x, y, radius, (u) => {
      if (!u.alive || u.fac === casterFac) return;
      const d = U.dist(u.x, u.y, x, y);
      if (d <= radius) {
        const fall = 1 - 0.5 * (d / radius);
        u.hp -= Math.max(2, dmg * fall - (u.def.armor || 0) * 0.4);
        u.hitFlash = 0.2;
        if (u.hp <= 0 && !u._killer) u._killer = null; // power kills credit no unit
      }
    });
    // also chip the enemy HQ if in blast
    for (const fid of Object.keys(sides)) {
      if (fid === casterFac) continue;
      const hq = sides[fid].hq;
      if (U.dist(hq.x, hq.y, x, y) <= radius) { hq.hp -= dmg * 0.5; hq.lastHit = 0; maybeAlertHQ(hq); }
    }
  }

  /* ---- commander support powers ----------------------------------------- */
  function powerState(facId, id) {
    const s = sides[facId];
    if (!s.powers) s.powers = {};
    if (!s.powers[id]) s.powers[id] = { cd: 0 };
    return s.powers[id];
  }
  function powerReady(facId, id) {
    const def = POWERS.find((p) => p.id === id);
    const ps = powerState(facId, id);
    return ps.cd <= 0 && sides[facId].funds >= def.cost;
  }
  function usePower(facId, id, x, y) {
    const def = POWERS.find((p) => p.id === id);
    if (!def) return { ok: false, reason: "unknown" };
    const ps = powerState(facId, id);
    if (ps.cd > 0) return { ok: false, reason: "On cooldown" };
    if (sides[facId].funds < def.cost) return { ok: false, reason: "Not enough funds" };
    sides[facId].funds -= def.cost; sides[facId].spent += def.cost;
    ps.cd = def.cd;
    x = U.clamp(x, 10, WORLD.w - 10); y = U.clamp(y, 10, WORLD.h - 10);
    if (facId === playerFac) emitSfx("power", { x, y, msg: def.name + " inbound" });

    if (id === "artillery") {
      for (let i = 0; i < 8; i++) {
        const a = rng() * Math.PI * 2, r = rng() * 80;
        const bx = x + Math.cos(a) * r, by = y + Math.sin(a) * r;
        schedule(0.6 + i * 0.22, () => {
          fx.push({ kind: "blast", x: bx, y: by, t: 0, life: 0.5, r: 40 });
          damageArea(facId, bx, by, 60, 90);
          emitSfx("explosion", { x: bx, y: by, size: 1.2 });
        });
      }
    } else if (id === "airstrike") {
      const hq = sides[facId].hq;
      const ang = Math.atan2(y - hq.y, x - hq.x);
      const dx = Math.cos(ang), dy = Math.sin(ang);
      for (let i = -3; i <= 3; i++) {
        const bx = x + dx * i * 55, by = y + dy * i * 55;
        schedule(0.5 + (i + 3) * 0.12, () => {
          fx.push({ kind: "blast", x: bx, y: by, t: 0, life: 0.45, r: 34 });
          fx.push({ kind: "tracer", x: bx - dx * 40, y: by - dy * 40, tx: bx, ty: by, t: 0, life: 0.18, col: "#ffd27a" });
          damageArea(facId, bx, by, 48, 75);
          emitSfx("explosion", { x: bx, y: by, size: 1 });
        });
      }
    } else if (id === "paradrop") {
      const roster = ROSTER[facId];
      const squad = ["ar", "rifle", "rifle", "lat", "rifle"];
      squad.forEach((tag, i) => {
        const ud = roster.find((d) => d.id.endsWith("_" + tag)) || roster[0];
        schedule(0.3 + i * 0.15, () => {
          const a = rng() * Math.PI * 2, r = rng() * 40;
          const u = spawnUnit(facId, ud, x + Math.cos(a) * r, y + Math.sin(a) * r, { order: "guard" });
          u._para = 0.8; // render parachute briefly
          fx.push({ kind: "blast", x: u.x, y: u.y, t: 0, life: 0.3, r: 14 });
        });
      });
    } else if (id === "smoke") {
      // lay a few overlapping smoke pots that linger
      for (let i = 0; i < 4; i++) {
        const a = rng() * Math.PI * 2, r = rng() * 70;
        smokes.push({ x: x + Math.cos(a) * r, y: y + Math.sin(a) * r, r: 95, t: 0, life: 16 });
      }
      for (let i = 0; i < 16; i++) smokeAt(x + (rng() - 0.5) * 120, y + (rng() - 0.5) * 120, 1, "rgba(150,150,150,");
    }
    return { ok: true };
  }
  function tickSmoke(dt) {
    for (let i = smokes.length - 1; i >= 0; i--) {
      const s = smokes[i]; s.t += dt;
      if (s.t > s.life) { smokes.splice(i, 1); continue; }
      // keep the cloud puffing while it lives
      if (rng() < dt * 2.5) smokeAt(s.x + (rng() - 0.5) * s.r, s.y + (rng() - 0.5) * s.r, 1, "rgba(150,150,150,");
    }
  }
  function tickPowers(dt) {
    for (const fid of [playerFac, enemyFac]) {
      const s = sides[fid]; if (!s.powers) continue;
      for (const id in s.powers) if (s.powers[id].cd > 0) s.powers[id].cd -= dt;
    }
  }

  /* ---- defensive emplacements ------------------------------------------- */
  function canPlaceDefense(facId, x, y) {
    // must be near owned territory (a held town or the HQ)
    const hq = sides[facId].hq;
    if (U.dist2(x, y, hq.x, hq.y) < 300 * 300) return true;
    for (const t of towns) if (t.owner === facId && U.dist2(x, y, t.x, t.y) < 240 * 240) return true;
    return false;
  }
  function buildDefense(facId, defId, x, y) {
    const def = DEFENSE_BY_ID[defId];
    const s = sides[facId];
    if (!def) return { ok: false, reason: "unknown" };
    if (!canPlaceDefense(facId, x, y)) return { ok: false, reason: "Must be near your HQ or a held town" };
    if (s.funds < def.cost) return { ok: false, reason: "Not enough funds" };
    if (supplyUsed(facId) + def.sup > supplyCap(facId)) return { ok: false, reason: "Supply full" };
    s.funds -= def.cost; s.spent += def.cost;
    // spawn as a stationary, building emplacement
    const u = spawnUnit(facId, def, x, y, { order: "hold", home: { x, y } });
    u.building = def.build; u.hp = Math.max(1, def.hp * 0.25); // weak while building, ramps up
    if (facId === playerFac) emitSfx("build", {});
    return { ok: true };
  }
  // ramp emplacement HP while "building"
  function tickDefenses(dt) {
    for (const u of units) {
      if (!u.alive || !u.emplacement || !u.building) continue;
      u.building -= dt;
      u.hp = Math.min(u.maxHp, u.hp + (u.maxHp * 0.75 / DEFENSE_BY_ID[u.def.id].build) * dt);
      if (u.building <= 0) { u.building = 0; u.hp = u.maxHp; }
    }
  }

  /* ====================================================================== *
   * COMMANDER UPGRADES — persistent, escalating-cost multipliers.
   * ==================================================================== */
  function upgLevel(facId, id) {
    const s = sides[facId]; const u = s && s.upgrades; return (u && u[id]) || 0;
  }
  function upgInfo(facId, id) {
    const def = UPGRADE_BY_ID[id]; const lvl = upgLevel(facId, id);
    const next = lvl < def.levels ? Math.round(def.baseCost * Math.pow(def.costMult, lvl)) : null;
    return { def, lvl, max: def.levels, cost: next };
  }
  function buyUpgrade(facId, id) {
    const info = upgInfo(facId, id); const s = sides[facId];
    if (info.lvl >= info.max) return { ok: false, reason: "Maxed" };
    if (s.funds < info.cost) return { ok: false, reason: "Not enough funds" };
    s.funds -= info.cost; s.spent += info.cost;
    if (!s.upgrades) s.upgrades = {};
    s.upgrades[id] = info.lvl + 1;
    if (facId === playerFac) { emitSfx("build", {}); log(`${info.def.name} upgraded to L${info.lvl + 1}`, "good"); }
    return { ok: true };
  }
  function dmgMult(f)    { return 1 + 0.14 * upgLevel(f, "weapons"); }
  function hpMult(f)     { return 1 + 0.14 * upgLevel(f, "armor"); }
  function incomeMult(f) { return 1 + 0.22 * upgLevel(f, "economy"); }
  function buildMult(f)  { return Math.max(0.4, 1 - 0.16 * upgLevel(f, "production")); }
  function upgSupply(f)  { return 6 * upgLevel(f, "logistics"); }

  /* ====================================================================== *
   * DAY / NIGHT — drives render tint and night vision penalty.
   * ==================================================================== */
  function daylight() {
    // ~260s full cycle; ranges roughly 0.12 (night) .. 1.0 (midday). Starts at day.
    return 0.56 + 0.44 * Math.sin(clock / 41.3 + Math.PI / 2);
  }

  /* ====================================================================== *
   * FOG OF WAR — coarse visible/explored grid for the player side.
   * ==================================================================== */
  const VCELL = 88;
  const vcols = Math.ceil(WORLD.w / VCELL), vrows = Math.ceil(WORLD.h / VCELL);
  const visible = new Uint8Array(vcols * vrows);
  const explored = new Uint8Array(vcols * vrows);
  function markVis(x, y, r) {
    const minx = U.clamp(((x - r) / VCELL) | 0, 0, vcols - 1);
    const maxx = U.clamp(((x + r) / VCELL) | 0, 0, vcols - 1);
    const miny = U.clamp(((y - r) / VCELL) | 0, 0, vrows - 1);
    const maxy = U.clamp(((y + r) / VCELL) | 0, 0, vrows - 1);
    const r2 = r * r;
    for (let cy = miny; cy <= maxy; cy++)
      for (let cx = minx; cx <= maxx; cx++) {
        const px = cx * VCELL + VCELL / 2, py = cy * VCELL + VCELL / 2;
        if (U.dist2(px, py, x, y) <= r2) { const i = cy * vcols + cx; visible[i] = 1; explored[i] = 1; }
      }
  }
  if (!fogEnabled) { visible.fill(1); explored.fill(1); }
  function updateVision() {
    if (!fogEnabled) { visible.fill(1); return; }
    visible.fill(0);
    // sight scaled by night + weather
    const sightK = (0.55 + 0.45 * daylight()) * weather.vision;
    for (const u of units) {
      if (!u.alive || u.fac !== playerFac) continue;
      markVis(u.x, u.y, u.def.sight * sightK * (u.def.scout ? 1.25 : 1));
    }
    for (const t of towns) if (t.owner === playerFac) markVis(t.x, t.y, 240);
    // held radar stations punch through the fog regardless of weather
    for (const p of points) if (p.owner === playerFac && p.type === "radar") markVis(p.x, p.y, RULES.radarRadius);
    for (const p of points) if (p.owner === playerFac) markVis(p.x, p.y, 150);
    const hq = sides[playerFac].hq; markVis(hq.x, hq.y, 360);
  }
  function vidx(x, y) {
    const cx = U.clamp((x / VCELL) | 0, 0, vcols - 1), cy = U.clamp((y / VCELL) | 0, 0, vrows - 1);
    return cy * vcols + cx;
  }
  const isVisible = (x, y) => !fogEnabled || !!visible[vidx(x, y)];
  const isExplored = (x, y) => !fogEnabled || !!explored[vidx(x, y)];

  /* ====================================================================== *
   * TERRAIN — forests give infantry cover and conceal them a little.
   * ==================================================================== */
  function inForest(x, y) {
    const F = MAP.forests || [];
    for (const f of F) if (U.dist2(x, y, f.x, f.y) < f.r * f.r) return true;
    return false;
  }

  /* ====================================================================== *
   * PARTICLES — smoke, dust, sparks, craters (purely cosmetic).
   * ==================================================================== */
  function particle(p) { if (parts.length < 900) parts.push(p); }
  function smokeAt(x, y, n, col) {
    for (let i = 0; i < n; i++)
      particle({ kind: "smoke", x: x + (rng() - 0.5) * 8, y: y + (rng() - 0.5) * 8,
        vx: (rng() - 0.5) * 6, vy: -8 - rng() * 10, t: 0, life: 1.2 + rng() * 1.4,
        r: 4 + rng() * 5, col: col || "rgba(40,40,40," });
  }
  function updateParticles(dt) {
    for (let i = parts.length - 1; i >= 0; i--) {
      const p = parts[i]; p.t += dt;
      if (p.t >= p.life) { parts.splice(i, 1); continue; }
      if (p.kind !== "crater") { p.x += p.vx * dt; p.y += p.vy * dt; }
      if (p.kind === "smoke") { p.vy *= (1 - 0.4 * dt); p.r += 6 * dt; }
      if (p.kind === "spark") { p.vy += 60 * dt; }
    }
    // burning wrecks / damaged vehicles emit smoke
    for (const u of units) {
      if (!u.alive) continue;
      if ((u.def.cat === "heavy" || u.def.cat === "light" || u.def.air) && u.hp < u.maxHp * 0.4) {
        if (rng() < dt * 6) smokeAt(u.x, u.y, 1);
      }
    }
  }

  /* ====================================================================== *
   * FORWARD OUTPOSTS — a supply truck deploys into a forward base:
   * vision + heal aura + supply-cap bonus + production rally anchor.
   * ==================================================================== */
  function deployOutpost(truck) {
    if (!truck || !truck.def.supplyTruck || truck.fac !== playerFac && truck.fac !== enemyFac) return { ok: false };
    const facId = truck.fac;
    truck.hp = -1;            // consume the truck
    const u = spawnUnit(facId, OUTPOST_DEF, truck.x, truck.y, { order: "hold", home: { x: truck.x, y: truck.y } });
    u.outpost = true; u.building = OUTPOST_DEF.build; u.hp = OUTPOST_DEF.hp * 0.3;
    if (facId === playerFac) { log("Forward outpost deploying", "good"); emitSfx("build", {}); }
    return { ok: true };
  }
  function tickOutposts(dt) {
    for (const u of units) {
      if (!u.alive || !u.outpost) continue;
      if (u.building) {
        u.building -= dt; u.hp = Math.min(u.maxHp, u.hp + (u.maxHp * 0.7 / OUTPOST_DEF.build) * dt);
        if (u.building <= 0) { u.building = 0; u.hp = u.maxHp; }
      }
      // heal aura
      grid.forEachInRadius(u.x, u.y, 120, (o) => {
        if (o.alive && o.fac === u.fac && o !== u && o.hp < o.maxHp && U.dist2(o.x, o.y, u.x, u.y) < 120 * 120)
          o.hp = Math.min(o.maxHp, o.hp + 6 * dt);
      });
    }
  }

  /* ====================================================================== *
   * ENGINEER REPAIR — repairs friendly vehicles, emplacements, outposts.
   * ==================================================================== */
  function repairAround(eng, dt) {
    grid.forEachInRadius(eng.x, eng.y, 90, (o) => {
      if (!o.alive || o.fac !== eng.fac || o === eng) return;
      const mech = o.def.cat !== "inf" || o.emplacement || o.outpost;
      if (mech && o.hp < o.maxHp && U.dist2(o.x, o.y, eng.x, eng.y) < 90 * 90)
        o.hp = Math.min(o.maxHp, o.hp + eng.def.repair * dt);
    });
  }

  /* ---- main step -------------------------------------------------------- */
  let clock = 0;
  function update(dt) {
    if (over) return;
    clock += dt;
    grid.build(units);                       // rebuild spatial hash once per step
    for (const u of units) if (u.alive) updateUnit(u, dt);
    updateHQ(sides[playerFac].hq, dt);
    updateHQ(sides[enemyFac].hq, dt);
    for (const t of towns) updateTown(t, dt);
    updatePoints(dt);
    tickEconomy(dt);
    advanceProduction(playerFac, dt);
    advanceProduction(enemyFac, dt);
    tickPowers(dt);
    tickDefenses(dt);
    tickOutposts(dt);
    tickSmoke(dt);
    runScheduled();
    updateVision(dt);                        // fog of war
    updateParticles(dt);
    if (game.ai) game.ai.update(dt);
    cleanup();
    updateFx(dt);
    checkEnd(dt);
  }

  /* ---- command API (used by UI) ---------------------------------------- */
  function unitsOfSide(facId) { return units.filter((u) => u.alive && u.fac === facId); }
  function townsOwned(facId) { return towns.filter((t) => t.owner === facId).length; }

  function issueMove(sel, x, y, attackMove) {
    // simple formation: spread around the click
    const n = sel.length;
    const cols = Math.ceil(Math.sqrt(n));
    sel.forEach((u, i) => {
      if (u.garrison) return;
      const gx = (i % cols) - (cols - 1) / 2;
      const gy = Math.floor(i / cols) - (Math.ceil(n / cols) - 1) / 2;
      u.order = { type: attackMove ? "attackmove" : "move",
        x: x + gx * 30, y: y + gy * 30, target: null };
      u.target = null;
    });
  }
  function issueAttack(sel, target) {
    sel.forEach((u) => { if (!u.garrison) { u.order = { type: "attack", target }; u.target = target; } });
  }
  function issueStop(sel) {
    sel.forEach((u) => { u.order = { type: "hold", x: u.x, y: u.y, target: null }; u.target = null; });
  }
  function setStance(sel, stance) {
    sel.forEach((u) => { if (!u.garrison && !u.emplacement && !u.outpost) u.stance = stance; });
  }
  function deployOutposts(sel) {
    let n = 0;
    sel.forEach((u) => { if (u.alive && u.def.supplyTruck) { const r = deployOutpost(u); if (r.ok) n++; } });
    return n;
  }

  const game = {
    // identity
    playerFac, enemyFac, diff, FAC: FACTIONS, winCond, weather, fogEnabled,
    // state
    sides, units, towns, townById, points, smokes, fx, floats, logs, parts, MAP, WORLD,
    get clock() { return clock; },
    get over() { return over; },
    get daylight() { return daylight(); },
    domProgress,
    // fog of war
    vision: { cell: VCELL, cols: vcols, rows: vrows, visible, explored },
    isVisible, isExplored, inForest, inSmoke,
    // queries
    supplyUsed, supplyCap, hasStructure, catUnlocked, unitsOfSide, townsOwned,
    powerReady, powerState, canPlaceDefense,
    upgLevel, upgInfo, buyUpgrade,
    // commands
    queueUnit, queueStructure, issueMove, issueAttack, issueStop, setStance, deployOutposts,
    usePower, buildDefense,
    setRally(facId, x, y) { sides[facId].rally = { x, y }; },
    // lifecycle
    update,
    spawnUnit,
    onLog: null,
    onSfx: null,
    log,
  };
  return game;
}
