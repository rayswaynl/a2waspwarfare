# Town Garrison Mass Preservation Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Preserve each original town-roster first-unit spawn guarantee while consolidating surviving town groups to the configured 9-10 unit target.

**Architecture:** Represent each packed town group as ordered source-roster segments. `Common_CreateTownUnits` invokes `CreateTeam` for every segment against one shared group. A new optional ninth `CreateTeam` argument disables the automatic first-unit guarantee for a continuation segment, retaining the exact original per-class probability while avoiding extra persistent groups.

**Tech Stack:** Arma 2 OA 1.64 SQF, Python `unittest`, LoadoutManager mirrors.

---

### Task 1: Lock the spawn-mass regression

**Files:**

- Modify: `Tools/Lint/test_town_group_packing.py`

1. Add a segment model for source roster splits at the group cap.
2. Assert 3x6 input packs to 10+8 while retaining each roster head's forced spawn and the original expected mass.
3. Run the test and observe failure until production code uses packed segments.

### Task 2: Preserve source roster semantics in packed groups

**Files:**

- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_GetTownGroups.sqf`
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_GetTownGroupsDefender.sqf`
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateTownUnits.sqf`
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateTeam.sqf`

1. Pack infantry as cap-bounded `[classnames, forceFirst]` segments; vehicles remain atomic.
2. Spawn each segment into the same supplied group.
3. Default old `CreateTeam` callers to forced-first behavior; only continuation segments disable it.

### Task 3: Mirror and validate

1. Run the packing contract red then green.
2. Regenerate mirrors with `A2WASP_SKIP_ZIP=1` and restore templates if needed.
3. Run targeted SQF lint, drift check, parity hashes, delimiter deltas, and independent review before Fleet completion.
