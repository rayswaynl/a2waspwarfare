/* =============================================================================
 * engine.js — the simulation. Owns all game state and the fixed update step.
 * Rendering and input live elsewhere; they only read state + call commands.
 * ========================================================================== */

function createGame(opts) {
  "use strict";
  const { FACTIONS, ROSTER, UNIT_BY_ID, STRUCT_BY_ID, STRUCTURES, MAP, WORLD, DIFFICULTY, RULES } = DATA;

  const playerFac = opts.faction;                       // "USMC" | "RU"
  const enemyFac  = playerFac === "USMC" ? "RU" : "USMC";
  const diff      = DIFFICULTY[opts.difficulty] || DIFFICULTY.veteran;
  const rng       = U.makeRng(opts.seed || 1337);

  let nextId = 1;

  /* ---- per-side state --------------------------------------------------- */
  function makeSide(facId, isPlayer) {
    const fac = FACTIONS[facId];
    return {
      fac: facId, isPlayer, color: fac.color,
      funds: diff.startFunds,
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

  /* ---- spawn helpers ---------------------------------------------------- */
  function spawnUnit(facId, def, x, y, opt) {
    opt = opt || {};
    const u = {
      id: nextId++, kind: "unit", fac: facId, def,
      x, y, hp: def.hp, maxHp: def.hp,
      cd: rng() * 0.5, alive: true,
      order: { type: opt.order || "guard", x: null, y: null, target: null },
      target: null,          // current acquired enemy
      home: opt.home || null,
      muzzle: 0, hitFlash: 0, supplyBoost: 0,
      heading: opt.heading != null ? opt.heading : (facId === playerFac ? -Math.PI / 2 : Math.PI / 2),
    };
    units.push(u);
    return u;
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
    let dmg = src.def.dmg * (src.def.vs[cls] || 1);
    const armor = tgt.kind === "hq" ? 4 : (tgt.def.armor || 0);
    dmg = Math.max(1, dmg - armor);
    // air is slippery vs unguided small arms
    if (tgt.def && tgt.def.air && cls === "air" && src.def.cat === "inf" && !src.def.vs.air) dmg *= 0.4;
    tgt.hp -= dmg;
    tgt.hitFlash = 0.18;
    if (tgt.kind === "hq") tgt.lastHit = 0;
    src.muzzle = 0.09;
    // visual tracer + occasional float
    fx.push({ kind: src.def.arty ? "arty" : "tracer", x: src.x, y: src.y, tx: tgt.x, ty: tgt.y,
      t: 0, life: src.def.arty ? 0.5 : 0.12, col: src.fac === "GARRISON" ? "#cfcf9a" : FACTIONS[src.fac].color });
    if (src.def.arty) fx.push({ kind: "blast", x: tgt.x, y: tgt.y, t: 0, life: 0.45, r: 36 });
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
    for (const o of units) {
      if (!o.alive || !isEnemySides(u.fac, o.fac)) continue;
      const d = U.dist2(u.x, u.y, o.x, o.y);
      if (d < bestD) { bestD = d; best = o; }
    }
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

    if (u.def.heal) healAround(u, dt);

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

    // Default guard/hold behaviour: engage nearby, otherwise idle near post.
    if (enemy) {
      const dd = U.dist2(u.x, u.y, enemy.x, enemy.y);
      if (dd < (u.def.range) ** 2) {
        applyDamage(u, enemy, dt);
      } else if (ord.type !== "hold") {
        // chase a little, but don't wander across the map
        const leashOk = !u.home || U.dist2(u.x, u.y, u.home.x, u.home.y) < 380 * 380;
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
    for (const o of units) {
      if (!o.alive || o.fac === hq.fac) continue;
      const d = U.dist2(o.x, o.y, hq.x, hq.y);
      if (d < bestD) { bestD = d; best = o; }
    }
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
    for (const u of units) {
      if (!u.alive) continue;
      if (U.dist2(u.x, u.y, t.x, t.y) > RULES.captureRange ** 2) continue;
      const w = u.def.air ? 0.5 : (u.def.cat === "inf" ? 1 : 1.5);
      if (u.fac === playerFac) pc += w;
      else if (u.fac === enemyFac) ec += w;
      else gc += w;
    }
    t.garrisonLeft = gc;
    t.contested = (pc > 0 && ec > 0) || (gc > 0 && (pc > 0 || ec > 0));
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
      let mult = facId === enemyFac ? diff.aiFunds : 1;
      sides[facId].income = inc * mult;
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
    // base ceiling + supply depots + a small bonus for each town you hold,
    // so taking ground also expands the army you can field.
    return sides[facId].supplyCap + sides[facId].depots * 6 + townsOwned(facId) * 2;
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
    s.queue.push({ kind: "unit", def, timeLeft: def.build, total: def.build });
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
        if (facId === playerFac) log(`${b.struct.name} online`, "good");
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
        fx.push({ kind: "blast", x: u.x, y: u.y, t: 0, life: 0.4, r: u.def.cat === "inf" ? 14 : 26 });
        if (u.fac === playerFac || u.fac === enemyFac) {
          sides[u.fac].losses++;
          const killerSide = u.fac === playerFac ? enemyFac : playerFac;
          sides[killerSide].kills++;
        }
        units.splice(i, 1);
      }
    }
  }

  function checkEnd() {
    if (over) return;
    if (sides[playerFac].hq.hp <= 0) over = { winner: enemyFac, reason: "Your HQ was overrun." };
    else if (sides[enemyFac].hq.hp <= 0) over = { winner: playerFac, reason: "Enemy HQ destroyed." };
    else if (towns.every((t) => t.owner === playerFac)) over = { winner: playerFac, reason: "Total territorial control." };
    else if (towns.every((t) => t.owner === enemyFac)) over = { winner: enemyFac, reason: "The enemy holds every town." };
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

  /* ---- log -------------------------------------------------------------- */
  const logs = [];
  function log(msg, type) {
    logs.push({ msg, type: type || "info", t: clock });
    if (logs.length > 60) logs.shift();
    if (game.onLog) game.onLog(msg, type || "info");
  }

  /* ---- main step -------------------------------------------------------- */
  let clock = 0;
  function update(dt) {
    if (over) return;
    clock += dt;
    for (const u of units) if (u.alive) updateUnit(u, dt);
    updateHQ(sides[playerFac].hq, dt);
    updateHQ(sides[enemyFac].hq, dt);
    for (const t of towns) updateTown(t, dt);
    tickEconomy(dt);
    advanceProduction(playerFac, dt);
    advanceProduction(enemyFac, dt);
    if (game.ai) game.ai.update(dt);
    cleanup();
    updateFx(dt);
    checkEnd();
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

  const game = {
    // identity
    playerFac, enemyFac, diff, FAC: FACTIONS,
    // state
    sides, units, towns, townById, fx, floats, logs, MAP, WORLD,
    get clock() { return clock; },
    get over() { return over; },
    // queries
    supplyUsed, supplyCap, hasStructure, catUnlocked, unitsOfSide, townsOwned,
    // commands
    queueUnit, queueStructure, issueMove, issueAttack, issueStop,
    setRally(facId, x, y) { sides[facId].rally = { x, y }; },
    // lifecycle
    update,
    spawnUnit,
    onLog: null,
    log,
  };
  return game;
}
