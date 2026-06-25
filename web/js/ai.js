/* =============================================================================
 * ai.js — the enemy commander. Macro (economy/build order) + tactics (orders).
 * Reads/writes game state through the public engine API only.
 * ========================================================================== */

function createAI(game) {
  "use strict";
  const { ROSTER, STRUCT_BY_ID } = DATA;
  const fac = game.enemyFac;
  const side = game.sides[fac];
  const aggro = game.diff.aiAggro;
  const roster = ROSTER[fac];
  const rng = U.makeRng(0xA15 ^ (fac === "USMC" ? 1 : 2));

  // Build order of structures by priority (depot interleaved for supply).
  const buildOrder = ["light", "depot", "heavy", "depot", "air", "depot"];

  // Desired unit mix per economic phase. Picked by tag suffix on unit ids.
  function phaseWants() {
    const owned = game.townsOwned(fac);
    if (!side.structures.has("heavy")) {
      return ["rifle", "ar", "lat", "rifle", side.structures.has("light") ? "btr" : "ar",
              side.structures.has("light") ? "uaz" : "rifle", "lat"];
    }
    if (!side.structures.has("air")) {
      return ["abrams", "t72", "bmp", "lav", "hat", "aa", "ar", "tow", "vodnik"];
    }
    return ["abrams", "t72", "tusk", "t90", "apache", "ka52", "hat", "aa", "cobra", "hind", "harrier", "su25"];
  }

  function pickUnit(tags) {
    // shuffle-ish by rng, find first affordable & unlockable
    const order = tags.slice().sort(() => rng() - 0.5);
    for (const tag of order) {
      const def = roster.find((d) => d.id.endsWith("_" + tag) || d.id.endsWith(tag));
      if (!def) continue;
      if (!game.catUnlocked(fac, def.cat)) continue;
      if (side.funds < def.cost) continue;
      if (game.supplyUsed(fac) + def.sup > game.supplyCap(fac)) continue;
      return def.id;
    }
    return null;
  }

  let macroT = 0, microT = 0;

  function macro(dt) {
    macroT -= dt;
    if (macroT > 0) return;
    macroT = 1.6 / aggro;

    // 1) Structures: build the next missing one in the order when we can afford it
    //    (keep a funds buffer so we still buy units).
    for (const sid of buildOrder) {
      const st = STRUCT_BY_ID[sid];
      const alreadyBuilding = side.building.length > 0;
      const has = sid === "depot" ? side.depots >= 1 + Math.floor(game.clock / 180)
                                  : side.structures.has(sid);
      if (!has && !alreadyBuilding && side.funds > st.cost + 300) {
        // need supply headroom? build depot if near cap
        if (game.supplyCap(fac) - game.supplyUsed(fac) <= 2 && sid !== "depot") {
          game.queueStructure(fac, "depot");
        } else {
          game.queueStructure(fac, sid);
        }
        break;
      }
    }

    // 2) Spend down funds on units, keeping the queue shallow.
    let guard = 0;
    while (side.queue.length < 3 && guard++ < 4) {
      // top up supply with a depot if capped
      if (game.supplyCap(fac) - game.supplyUsed(fac) <= 1 && side.funds > 320) {
        game.queueStructure(fac, "depot");
        break;
      }
      const id = pickUnit(phaseWants());
      if (!id) break;
      const r = game.queueUnit(fac, id);
      if (!r.ok) break;
    }
  }

  function micro(dt) {
    microT -= dt;
    if (microT > 0) return;
    microT = 2.4;

    const my = game.unitsOfSide(fac).filter((u) => !u.garrison);
    if (!my.length) return;

    // Units that are idle (guarding with nothing to do) get a fresh objective.
    const idle = my.filter((u) => u.order.type === "guard" || u.order.type === "hold" ||
      (u.order.type === "attackmove" && reached(u)));

    // Choose objectives: prefer capturing towns; escalate to HQ when strong.
    const enemyHQ = game.sides[game.playerFac].hq;
    const myStrength = my.length;
    const pushHQ = myStrength > 12 + 6 / aggro && game.clock > 120;

    // Rank towns by desirability for the AI: not owned by us, weakest contest.
    const targets = game.towns
      .filter((t) => t.owner !== fac)
      .map((t) => ({ t, score: townScore(t) }))
      .sort((a, b) => a.score - b.score);

    if (!idle.length) return;

    // Send the bulk to the best 1-2 towns; peel a strike group to the HQ if pushing.
    const groups = [];
    if (pushHQ) groups.push({ x: enemyHQ.x, y: enemyHQ.y, share: 0.45 });
    targets.slice(0, 2).forEach((o, i) => groups.push({ x: o.t.x, y: o.t.y, share: i === 0 ? 0.4 : 0.25 }));
    if (!groups.length) groups.push({ x: enemyHQ.x, y: enemyHQ.y, share: 1 });

    let idx = 0;
    for (const g of groups) {
      const cnt = Math.max(1, Math.round(idle.length * g.share));
      const slice = idle.slice(idx, idx + cnt);
      idx += cnt;
      if (slice.length) game.issueMove(slice, g.x + (rng() - 0.5) * 60, g.y + (rng() - 0.5) * 60, true);
    }
    // leftovers -> best town
    if (idx < idle.length && targets[0]) {
      game.issueMove(idle.slice(idx), targets[0].t.x, targets[0].t.y, true);
    }
  }

  function reached(u) {
    return U.dist2(u.x, u.y, u.order.x, u.order.y) < 60 * 60;
  }

  function townScore(t) {
    // lower = more attractive. distance from our HQ + ownership penalty.
    const hq = side.hq;
    let s = U.dist(t.x, t.y, hq.x, hq.y) * 0.01;
    if (t.owner === game.playerFac) s -= 30;   // contesting enemy towns is valuable
    if (t.owner == null) s -= 50;              // neutral towns are easiest wins
    s -= t.sv * 0.6;                           // richer towns preferred
    if (t.garrisonLeft > 0.5) s += 25;         // garrison makes it harder
    return s;
  }

  return {
    update(dt) {
      if (game.over) return;
      macro(dt);
      micro(dt);
    },
  };
}
