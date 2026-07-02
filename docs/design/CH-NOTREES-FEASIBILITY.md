# Chernarus "No Trees" toggle — feasibility (Build 88 / cmdcon43-a)

**Ray's ask:** a server-side ON/OFF setting for Chernarus that gives everyone a
tree-free world. Client-side vegetation mods are banned on this server for fairness
(concealment asymmetry); a *server-wide* setting is fair because everyone sees the
same world.

**Author:** claude-gaming, 2026-07-02. Primary sources: BI wiki command version
boxes, the mission's own working map-object code, A2/OA-era community threads.

---

## VERDICT: (b) feasible only *partially*, and NOT recommended as-is.

The **visual** removal of Chernarus trees is achievable mission-side in A2-OA 1.64
(mechanism proven below). BUT in our engine version hiding a tree does **not** remove
it from the engine's AI-vision / ballistics geometry. So a "no trees" toggle makes the
world look clear while the AI still sees and shoots exactly as if the trees were there,
and bullets/vehicles still collide with invisible trunks. That is a *new* concealment
asymmetry — the very harm the client-mod ban exists to prevent — just moved from
"some players" to "players vs. the engine/AI".

Implemented in cmdcon43-a as an **explicitly experimental, default-OFF** toggle so Ray
can see it in the Build 88 menu and decide, with this caveat loud. The honest,
fully-fair route (a real tree-free Chernarus) is an **addon/map-variant**, documented
under "Alternatives" — not built here.

---

## Mechanism (what works, proven)

### Enumeration — `nearestObjects [pos, [], radius]`  ✅ available
- Introduced **A2-OA v1.50** (works in our 1.64 target).
- Passing an **empty class array `[]`** returns *classless* terrain objects — trees,
  bushes, stones — i.e. the WRP map vegetation. (`["All"]` would *exclude* them; the
  empty array is the key.)
- **Proof-of-mechanism already in our repo:** `Server\Functions\Server_SiteClearance.sqf`
  does exactly this today — `nearestObjects [_pos, [], 25]`, then filters
  `str _tree` for the Chernarus tree prefix `": t_"` (and legacy `": str_"`), then
  `setDamage 1`. The commander "Site Clearance" build action is this code shipping in prod.
- The tree/bush class-name heuristic on Chernarus: map trees stringify as
  `<id>: t_<species>.p3d`, bushes as `b_<...>`, small plants `t_<...>` too. We match
  `: t_` / `: b_` substrings (A2 has no `find` on strings — use a toArray sliding-window
  matcher; `Server_SiteClearance.sqf` ships one, reused here).

### Hiding — `hideObject`  ✅ available, ⚠️ LOCAL + geometry persists
- Introduced **A2-OA v1.50** (works in 1.64). Effect is **LOCAL** — each machine that
  should see the change must run the command itself (there is no global broadcast in 1.64).
- **Collision-disable on hide was only confirmed "as of Arma 3 v1.45."** In A2-OA 1.64
  the object's **Geometry + View-Geometry LODs persist** after `hideObject true`:
  the tree vanishes from *render* but still blocks bullets, still collides with vehicles,
  and — critically — **still occludes / is "seen" by AI**. (BI wiki notes the View-Geometry
  LOD is what AI occlusion uses; community reports confirm hidden/felled trees keep blocking
  AI vision.) This is the fairness landmine.

### Why NOT `nearestTerrainObjects` / `hideObjectGlobal`  ❌ Arma 3 only
- `nearestTerrainObjects` — **Arma 3 v1.54 ONLY**. Every "remove all trees" snippet you
  find online uses it; it **does not exist in A2-OA 1.64** and will parse-error / be
  undefined. We must use `nearestObjects [pos, [], r]` instead.
- `hideObjectGlobal` — **Arma 3 v1.12 ONLY**. Not in 1.64. Hence the per-client + JIP
  execution model (below), not a single server-side global call.

### Why not `setDamage 1` (felling)  ❌ worse on every axis
- Fallen trees **still block AI vision** (View-Geo LOD only re-orients, keeps blocking) and
  still provide cover — so it does not achieve "no trees" for gameplay either.
- **JIP desync:** a tree felled by `setDamage` reappears *standing* for any client that
  joins after it fell (does not re-sync). Fine for one-off base clearance (SiteClearance's
  own ENGINE NOTE flags this as deferred), unacceptable for a whole-map persistent toggle.
- Leaves visible stumps/logs everywhere — ugly, and changes concealment unpredictably.

So the only path to a *clean, JIP-consistent visual* is `hideObject`, per-client — which
brings the AI-vision caveat with it.

---

## Execution model (as implemented)

`hideObject` is local and there is no global variant in 1.64, so **every machine runs the
same pass**: server, every headless client (HC), and every player client — including JIP
joiners on connect. Running it on the server + HCs matters because AI groups are local to
whichever machine owns them; the render-hide itself is cosmetic there, but keeping the pass
uniform avoids per-machine divergence and documents intent. (It does NOT fix AI vision — see
caveat; the geometry persists on all machines.)

- Gate: `worldName == "Chernarus"` **and** `WFBE_C_CH_NOTREES == 1`.
- **Staged / chunked** so it never frame-spikes: the map is swept in a grid of cells
  (default 500 m), a bounded `nearestObjects [cellCentre, [], ~360]` per cell, hide the
  matched trees/bushes, then `uiSleep` a beat before the next cell. A single whole-map
  `nearestObjects` is a non-starter (see perf).
- JIP: hooked at the tail of `Client\Init\Init_Client.sqf` via the standard
  `spawn Compile preprocessFileLineNumbers` pattern, so it runs for fresh joiners too.

### Perf notes (why chunking is mandatory)
- Our own cleaners measure a **20 km-radius `nearestObjects` scan at ~230 ms/cycle** even
  deleting nothing (see `Server\FSM\cleaners\droppeditems_cleaner.sqf` header). The BI wiki
  warns **sorting ~7 000 objects ≈ 100 ms**. Chernarus has *tens of thousands* of trees.
- A single map-wide scan would hard-hitch every machine for seconds and risk the scheduler.
  The grid+sleep spreads the cost: each ~360 m-radius cell returns a few hundred objects
  (sub-10 ms), one cell per frame-ish, whole map over ~30–90 s of soft background work.
  Because `hideObject` is a one-shot flag, cost is paid once per client at join, not ongoing.

---

## ⚠️ FAIRNESS CAVEAT (the reason this is default-OFF / experimental)

Because the View-Geometry LOD persists in 1.64:

- **Players** see a clear field; **AI** still sees the trees and shoots through the "gap"
  a player thinks is open ground. A player breaking cover into a visually-empty area is
  actually still concealed *to the AI* — or exposed where they think they're hidden.
- **Bullets and vehicles** still hit / collide with the invisible trunks: shots "magically"
  stop mid-air, vehicles crunch to a halt on nothing.
- This is *uniform across all players* (so it is not player-vs-player unfair — everyone gets
  the same lie), but it is **player-vs-engine unfair and confusing**, and it re-introduces
  the exact concealment mismatch the client-mod ban was meant to kill.

**Bottom line for Ray:** the toggle delivers the *look* but not honest *no-trees gameplay*.
Ship it only as a novelty/visibility experiment with players told the AI still "sees" trees.

---

## Alternatives for a REAL tree-free Chernarus (documented, NOT built)

1. **Server-distributed terrain addon (best true fix).** A tiny PBO that ships a
   Chernarus config with the object/vegetation layers stripped or an empty clutter/forest
   set. Because it changes the actual terrain, AI vision + collision go away *for real* and
   it is byte-identical for everyone (server enforces the addon). Cost: it's a new required
   mod download and a signature-key/whitelist change — a deploy-pipeline item, not
   mission-side. This is the route if Ray wants genuine no-trees.

2. **Modded_Missions map-variant.** A `.chernarus`-family variant is not enough on its own
   (mission SQF can't strip WRP geometry), so this still needs option 1's addon underneath;
   the variant would just be the mission wired to require it. Keep in `Modded_Missions/`
   per the "modmaps kept" rule.

3. **Live with the visual toggle** (this build) as a cosmetic-only novelty, clearly labelled.

---

## Sources
- `nearestObjects` (empty-array terrain objects, A2-OA v1.50, ~100 ms/7 000 sort) —
  https://community.bistudio.com/wiki/nearestObjects
- `hideObject` (A2-OA v1.50, LOCAL, collision-disable only "as of A3 v1.45") —
  https://community.bistudio.com/wiki/hideObject
- `hideObjectGlobal` (Arma 3 v1.12 only) — https://community.bistudio.com/wiki/hideObjectGlobal
- `nearestTerrainObjects` (Arma 3 v1.54 only) —
  https://community.bistudio.com/wiki/nearestTerrainObjects
- AI vision uses View-Geometry LOD; felled/hidden hard objects keep blocking —
  https://armedassault.fandom.com/wiki/AI_Basics:_Detection
- In-repo proof-of-mechanism: `Server/Functions/Server_SiteClearance.sqf`,
  `Server/FSM/cleaners/droppeditems_cleaner.sqf` (perf), `Server/FSM/basearea.sqf`.
