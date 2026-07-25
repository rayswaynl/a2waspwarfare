# RequestVehicleLock Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `RequestVehicleLock` reject forged remote unlocks while preserving the existing lockpick caller when `WFBE_C_SEC_HARDENING` is off.

**Architecture:** Reuse the server-minted, privately delivered capability helper from PR #1409. The first hardening-enabled request validates the claimed live actor, vehicle reach, and authoritative vehicle side, then mints a short-lived one-shot token to that actor's owning client; the private reply triggers the honest caller's second request, where the token is atomically consumed before the unlock side effect. The legacy two-argument path remains unchanged while the flag is zero.

**Tech Stack:** Arma 2 OA 1.64 SQF, existing PVF transport, Python static regression checks, repository SQF lint and mirror tooling.

## Global Constraints

- Edit Chernarus first; mirror only files byte-identical in Takistan/Zargabad before the edit.
- Keep `WFBE_C_SEC_HARDENING` default `0`; flag-off behavior must remain byte-inert.
- Use A2/OA syntax only; no A3 commands or inline `private _x =` declarations.
- Do not deploy, merge, or touch the live server.
- Commit without a `Co-Authored-By` trailer and open a draft PR against `master`.

### Task 1: Trace and lock the contract

**Files:**
- Read: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestVehicleLock.sqf`
- Read: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_SpecOps.sqf`
- Read: PR #1409 capability helper and existing token precedents

- [ ] Verify the caller sends only an unlock request and identify all transport limitations.
- [ ] Verify the authoritative vehicle-side stamp and the exact side comparison idiom.
- [ ] Record the findings in `RESULT.md` after implementation.

### Task 2: Add the failing regression contract

**Files:**
- Create: `Tools/Lint/test_vehicle_lock_hardening.py`

- [ ] Assert the handler contains flag-gated mint/consume phases, live-player/range/side/lock rejection, private capability use, and a top-scope rejection exit.
- [ ] Assert the honest caller persists a challenge and the private client receiver validates the challenge before resubmitting the unlock.
- [ ] Run the focused test and confirm it fails because the new contract is absent.

### Task 3: Implement the guarded two-phase unlock

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestVehicleLock.sqf`
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_SpecOps.sqf`
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/PVFunctions/HandleSpecial.sqf`

- [ ] Keep the existing path intact when the flag is zero.
- [ ] On the first flag-on request, validate the actor, unlock-only action, non-null vehicle, 12 m range, and matching `wfbe_side_id`, then mint the private capability and stop.
- [ ] On the token request, re-run the same server-side validation, consume the purpose-bound token before `lock`, then broadcast the accepted unlock.
- [ ] Log every rejection with `WFBE_CO_FNC_LogContent` and no client chat/hint.
- [ ] Run the focused test and verify it passes.

### Task 4: Mirror and validate

**Files:**
- Mirror: matching changed mission files under `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/` and `.zargabad/`
- Create: `RESULT.md`

- [ ] Run `dotnet run -c RELEASE` from `Tools/LoadoutManager` with packaging suppressed.
- [ ] Restore/check terrain templates and run the generator `--check` plus version-template tests.
- [ ] Run the full required SQF lint selector and focused Python tests.
- [ ] Verify bracket deltas, mirror byte parity, flag-off baseline evidence, clean diff checks, and forbidden artifacts.

### Task 5: Deliver the draft PR

- [ ] Commit with `feat(vehlock): harden RequestVehicleLock [flag WFBE_C_SEC_HARDENING default 0]`.
- [ ] Push `codex/vehiclelock-harden-20260725` to `origin`.
- [ ] Open the required draft PR, stating that it is stacked on #1409 and including caller trace, inert proof, mirrors, tests, and residual risk.
- [ ] Verify the final branch, commit, PR number, and `RESULT.md` contents from fresh disk state.
