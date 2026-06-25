/* =============================================================================
 * main.js — boot: briefing menu, canvas sizing, the rAF game loop, end screen.
 * ========================================================================== */

(function () {
  "use strict";
  const { FACTIONS, DIFFICULTY } = DATA;

  const $ = (id) => document.getElementById(id);

  /* ---------- menu: faction + difficulty pickers ------------------------- */
  let chosenFac = "USMC";
  let chosenDiff = "veteran";

  function buildFactionPick() {
    const wrap = $("factionPick");
    wrap.innerHTML = "";
    for (const id of ["USMC", "RU"]) {
      const f = FACTIONS[id];
      const el = document.createElement("button");
      el.className = "pick-card" + (chosenFac === id ? " sel" : "");
      el.style.setProperty("--c", f.color);
      el.innerHTML = `
        <span class="pick-flag" style="color:${f.color}">${f.flag}</span>
        <span class="pick-name">${f.name}</span>
        <span class="pick-sub">${f.long}</span>`;
      el.onclick = () => { chosenFac = id; buildFactionPick(); };
      wrap.appendChild(el);
    }
  }

  function buildDiffPick() {
    const wrap = $("diffPick");
    wrap.innerHTML = "";
    for (const id of ["recruit", "veteran", "elite"]) {
      const d = DIFFICULTY[id];
      const el = document.createElement("button");
      el.className = "pick-card pick-diff" + (chosenDiff === id ? " sel" : "");
      el.innerHTML = `
        <span class="pick-name">${d.name}</span>
        <span class="pick-sub">${d.desc}</span>`;
      el.onclick = () => { chosenDiff = id; buildDiffPick(); };
      wrap.appendChild(el);
    }
  }

  buildFactionPick();
  buildDiffPick();

  /* ---------- canvas sizing ---------------------------------------------- */
  const board = $("board");
  const mini = $("minimap");
  const ctx = board.getContext("2d");
  const mctx = mini.getContext("2d");

  function sizeCanvas() {
    const stage = $("stage");
    const r = stage.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    board.width = Math.floor(r.width * dpr);
    board.height = Math.floor(r.height * dpr);
    board.style.width = r.width + "px";
    board.style.height = r.height + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (UI) UI.cam.setView(r.width, r.height);
  }
  window.addEventListener("resize", () => { if (running) sizeCanvas(); });

  /* ---------- game lifecycle --------------------------------------------- */
  let game = null, UI = null, running = false, raf = 0, last = 0;

  function startGame() {
    $("menu").classList.add("hidden");
    $("game").classList.remove("hidden");
    $("endScreen").classList.add("hidden");

    game = createGame({ faction: chosenFac, difficulty: chosenDiff, seed: 1337 });
    game.ai = createAI(game);

    // HUD faction chrome
    const f = FACTIONS[chosenFac];
    $("hudSide").textContent = f.name;
    $("hudFlag").textContent = f.flag;
    $("hudFlag").style.color = f.color;
    document.documentElement.style.setProperty("--side", f.color);
    document.documentElement.style.setProperty("--enemy", FACTIONS[game.enemyFac].color);

    const refs = {
      board, minimap: mini,
      panelTabs: $("panelTabs"), panelBody: $("panelBody"), queueList: $("queueList"),
      statFunds: $("statFunds"), statIncome: $("statIncome"), statSupply: $("statSupply"),
      statTowns: $("statTowns"), statUnits: $("statUnits"), hudClock: $("hudClock"),
      ticker: $("ticker"), selInfo: $("selInfo"),
      pauseBtn: $("pauseBtn"), speedBtn: $("speedBtn"),
    };

    sizeCanvas();
    UI = createUI(game, refs);
    sizeCanvas(); // re-apply view now UI/cam exists

    game.log(`${f.long} deployed to Chernarus. Secure the towns, commander.`, "good");

    // debug/testing handle (harmless in normal play)
    window.WASP = { game, get ui() { return UI; } };

    running = true; last = performance.now();
    cancelAnimationFrame(raf);
    raf = requestAnimationFrame(loop);
  }

  function loop(now) {
    if (!running) return;
    let realDt = (now - last) / 1000;
    last = now;
    realDt = Math.min(realDt, 0.05); // clamp big frame gaps

    const speed = UI.speed;
    const simDt = UI.paused ? 0 : realDt * speed;

    if (simDt > 0) {
      // step the sim in sub-steps for stability at high speed
      let remaining = simDt;
      const STEP = 1 / 30;
      while (remaining > 1e-4) {
        const d = Math.min(STEP, remaining);
        game.update(d);
        remaining -= d;
      }
    }

    UI.tick(simDt, realDt);

    const view = { w: board.clientWidth, h: board.clientHeight };
    Render.drawBoard(ctx, game, UI.cam, view, UI.uiState());
    UI.drawPings(ctx);
    Render.drawMinimap(mctx, game, UI.cam, view, mini.width, mini.height);

    if (game.over) return endGame();

    raf = requestAnimationFrame(loop);
  }

  function endGame() {
    running = false;
    const won = game.over.winner === game.playerFac;
    const es = $("endScreen");
    es.classList.remove("hidden");
    const title = $("endTitle");
    title.textContent = won ? "VICTORY" : "DEFEAT";
    title.className = won ? "win" : "lose";
    $("endText").textContent = game.over.reason;

    const me = game.sides[game.playerFac], foe = game.sides[game.enemyFac];
    $("endStats").innerHTML = `
      <div class="es-row"><span>Time</span><b>${U.fmtTime(game.clock)}</b></div>
      <div class="es-row"><span>Towns held</span><b>${game.townsOwned(game.playerFac)} / ${game.towns.length}</b></div>
      <div class="es-row"><span>Kills</span><b>${me.kills}</b></div>
      <div class="es-row"><span>Losses</span><b>${me.losses}</b></div>
      <div class="es-row"><span>Funds spent</span><b>$${U.fmtNum(me.spent)}</b></div>
      <div class="es-row"><span>Enemy kills</span><b>${foe.kills}</b></div>`;
  }

  /* ---------- buttons ----------------------------------------------------- */
  $("startBtn").onclick = startGame;
  $("endBtn").onclick = () => {
    $("endScreen").classList.add("hidden");
    $("game").classList.add("hidden");
    $("menu").classList.remove("hidden");
    running = false;
    cancelAnimationFrame(raf);
  };
  $("quitBtn").onclick = () => {
    if (!game) return;
    game.over || (game.update(0), null);
    // force resign
    game.sides[game.playerFac].hq.hp = 0;
    game.update(0.001);
    endGame();
  };

  // allow Enter to deploy from the menu
  window.addEventListener("keydown", (e) => {
    if (!running && e.key === "Enter" && !$("menu").classList.contains("hidden")) startGame();
  });
})();
