# A-Life v2 (interaction/spectacle/frequency) + Doctrine Personalities + Commander Tactics
Ray (2026-07-02): wants players RUNNING INTO a-life often, interaction + spectacle; improve the existing
ambient layer too; doctrine personalities written out; commander ideas = unit behavior/compositions/tactics.

## A. Improve the EXISTING ambient layer (encounter-rate first)
1. **Wire AITownPatrol + garrison sorties** — AITownPatrol is compiled but has NO live caller (wiki-verified
   dead). Give every active garrison a rotating 4-man sortie on a 300-800m loop around its town. Players meet
   defenders BEFORE the town, towns feel alive. (S)
2. **Road-biased patrols** — the upgrade-tier patrols path randomly; re-route them along ROADS between owned
   towns and the front (players drive roads → constant chance encounters + running vehicle fights). (S)
3. **Convoys made huntable** — W17 supply convoys get a light escort + a fuzzy rumor-radio ping ("convoy
   sighted on the coast road") so players can intercept; escort = a real firefight, not free loot. (S-M)
4. **Front you can SEE** — longer-burning/smoking wrecks + AA tracers at range + garrison flares on night
   contact. Smoke columns become wayfinding: players navigate TOWARD the war. (S)

## B. New A-Life (high-contact, interactive, spectacular)
1. **Road checkpoints** — GUER/enemy checkpoints spawn at chokepoints between towns (sandbags + technical +
   4-6 men; flare/searchlight feel at night). Constant driving encounters; clearing one pays + triggers a
   hunter response team. Despawns when the area is safely owned. (M — reuses camp/garrison spawn idioms)
2. **Road ambush events** — the server watches player road travel; ahead of a moving player (~1km), chance-roll
   a hasty AT ambush, TELEGRAPHED (drone flyover / radio crackle 10s before). STALKER "the road is dangerous". (M)
3. **Downed-pilot races** — every AI aircraft kill ejects a live pilot; both sides + players get a rumor ping →
   race to capture/rescue for funds/intel. Aircraft die often → frequent emergent mini-events. (M)
4. **Mortar harassment pits** — small GUER mortar camps near the front lob occasional inaccurate rounds at
   contested towns (audible WHUMP + impacts = spectacle); hunt the pit by sound/flash = interaction. (M)
5. **Wreck scavengers** — GUER teams path to the existing husk-collector registry (wfbe_aicom_abandoned) and
   strip wrecks; players stumble on them working battle aftermath; killing them pays salvage. Mid-map contact
   generator using data we ALREADY track. (M)
6. **VBIED-in-traffic tension** — rare civilian car among refugee traffic is a GUER VBIED (system exists);
   stop-or-shoot tension per car. (S, gated/dialable)

## C. DOCTRINE PERSONALITIES — written out (Ray asked)
**Roll:** at match start each AI side independently rolls a persona (server-side, before workers read
constants). Announce in the briefing + side radio: "Intel: enemy commander VORON — 'The Steamroller'."
Persona = a named table of ~8-12 overrides to EXISTING constants + a flavored taunt set. Lobby param:
random / force-specific / off. All existing flags — zero new mechanics, pure identity.

- **BLITZ "Steamroller"** — FIST_TOWNS 2→1, CONCENTRATION 6→8, LF doctrine bias, shorter stall-advance,
  earlier HQ-strike gates, MHQ advances aggressively. *Feels like:* one massive spearhead rolling the town
  chain; beat it by flanking the empty map half. Radio: "Your line breaks at dawn."
- **FORTRESS "The Wall"** — garrisons+1, HOLD_SECS 180→400, relief cap 2, base defenses maxed, attacks only
  with a big strength edge, econ banks into upgrades → late deathball. *Feels like:* a siege you must crack;
  beware the one counter-punch. Radio: "Come. Bleed on my walls."
- **AIR BARON "Vulture"** — AIR_MAX_LATE 7→9, heli share 0.55→0.7, WFBE_UP_AIR researched EARLY (fixes the
  air-research gap as a persona trait), fewer tanks, aggressive CAS + the EASA-for-AI kits once unlocked.
  *Feels like:* skies full of gunships; AA becomes the meta. Radio: "Look up."
- **RAIDER "Ghost"** — team size 8→6 but target+2 teams, YELLOW default march, breaks off earlier, weights
  rear/econ objectives (oilfield/banks/convoys), night bias. *Feels like:* nothing is safe behind you.
  Radio: "Check your fuel depots."
Implementation: one roll + a switch of setVariable overrides in AI_Commander boot + briefing/taunt tables. (S)

## D. Commander UNIT tactics/compositions (Ray's actual ask)
1. **Assault choreography at the staging point** (extends wave-2 staging-mass): armor forms an overwatch line
   ~300m out, infantry dismounts + bounds in first, 2-3 artillery prep rounds land on the town during staging,
   THEN release. All primitives exist (stage rally, arty worker, dismount). (M)
2. **Smoke discipline** — leaders pop smoke on break-off (the new rally lane) and on the assault approach axis
   (createVehicle SmokeShell idiom). Cheap, transforms the look of fights. (S)
3. **Armor overwatch during capture** — wiki sketch exists (armor-screen-while-infantry-captures): hulls screen
   OUTWARD beyond the 40m ring instead of parking on the flag. (S-M)
4. **Target-aware compositions** — garrison-heavy town → AT/MG-heavy squad + armor support; open village →
   mech infantry; persona biases stack on top. Replaces pure price-weighted draws. (M)
5. **Convoy/MHQ escorts** — relocations and supply runs get a shadow escort team (reuse the relief picker). (M)
6. **Recon screen** — one cheap scout car per side roams the front (players meet it; its spotting feeds the
   commander's target choice → the omniscience finally has a visible in-world justification). (S-M)
7. **Feints** — occasionally send a small loud team at town A while massing on B; taunt radio sells the lie. (M)
8. **Night discipline** — flares on contact, NVG elite teams for RAIDER, slower cautious night marches. (S-M)

Recommended first wave (post-cmdcon41): C personas + D1/D2/D3 + A1/A2 + B1 checkpoints — that set maximizes
"players constantly encounter a living, theatrical war" per effort.

## ▶ RAY'S PICKS (2026-07-02, wave-3)
1. YES — wire AITownPatrol + garrison sortie loops. 2. YES — road-biased patrols. 3. SKIP personalities for now.
4. YES — D2 smoke discipline. 5. Carriers: the MIDDLE one keeps/gets the SCUD as-is (single hull); the TWO OUTER
carriers become TWIN-HULL SUPER-CARRIERS (second full LHD alongside, deck-bridged).
