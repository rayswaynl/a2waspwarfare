# Council Quick-Wins Bundle Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship the consensus/trivial C1 A-Life and C2 capture-legibility fixes on top of `update/wave-next`, while proving or refuting the dead-camp gate claim without changing shared camp-count semantics unnecessarily.

**Architecture:** Chernarus remains the only edited source; LoadoutManager produces byte-identical Takistan/Zargabad mirrors. Correctness and telemetry changes ship directly, while any behavior addition uses an existing or new default-0 flag. The C2 pack remains client-read-only except for the narrowly audited capture-bar constant and client feedback.

**Tech Stack:** Arma 2 OA 1.64 SQF, mission config rosters, targeted CRLF-preserving Python edits, LoadoutManager, SQF lint and static structural checks.

---

### Task 1: Audit and verdict

- Read the exact council anchors and current source lines for every requested item.
- Compare `Common_GetTotalCamps*`, `server_town_camp.sqf`, and the mode-2 gate; record a REFUTED or FIXED verdict for (h) based on live/null/dead behavior.
- Verify all new classnames are already registered in the mission tree; skip any unverified proposal.

### Task 2: C1 roster, patrol, sortie, and telemetry

- Add one verified TKA infantry body to standard squad keys without introducing `TK_Soldier_AAR_EP1`.
- Repair crewless patrol pool entries using same-file registered infantry, preserving the shared roster-key design.
- Extend the EAST air-sortie allowlists at each verified consumer.
- Add debounced founding/produce-cap and relevant field-split/mean-size telemetry with no behavior changes.
- Correct the US sniper teams.

### Task 3: C1 hygiene

- Remove only dead constants/readers, add the empty-position exhaustion warning, introduce the dressing quiet timeout constant, fix quiet-timeout use, and align stale comments.
- Keep unrelated paratroop, DLC, HC, and behavior redesign proposals out of this bundle.

### Task 4: C2 capture legibility

- Make the capture bar show existing SV detail and client-only `Camps X/Y` using the null-safe live camp helpers.
- Correct client marker recoloring/Depot presentation and capture feedback copy without server state changes or client-to-server event additions.
- Apply the requested flag/default policy exactly where a behavior toggle is required.

### Task 5: Verify, mirror, and commit slices

- After each slice, run LoadoutManager from Chernarus and restore map-specific version templates.
- Run the required SQF lint on every touched SQF file, bracket deltas, CRLF checks, mirror hashes, and `git diff --check`.
- Commit each item-group separately, include the (h) verdict in its commit message, then push a draft PR targeting `update/wave-next`.
