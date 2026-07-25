# RequestVehicleLock hardening result

- PR: [#1421](https://github.com/rayswaynl/a2waspwarfare/pull/1421), draft
- Branch: `codex/vehiclelock-harden-20260725`
- Commit: `b7d449ab02`
- Dependency: stacked on [PR #1409](https://github.com/rayswaynl/a2waspwarfare/pull/1409) for the reusable server-minted capability helper

## Files changed by this lane

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestVehicleLock.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_SpecOps.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/PVFunctions/HandleSpecial.sqf`
- Byte-identical copies of those three files under the maintained Takistan and Zargabad roots
- `Tools/Lint/test_vehicle_lock_hardening.py`
- `docs/superpowers/plans/2026-07-25-vehicle-lock-hardening.md`

## Honest callers traced

`Client/Module/Skill/Skill_SpecOps.sqf` is the only live caller. It unlocks the closest currently locked vehicle after the four-step lockpick animation and success roll; it sends `player` as the claimed actor. The older `WFBE_RequestVehicleLock`/`HandleSPVF` lines in that file are comments only. `Common/Init/Init_PublicVariables.sqf` registers the endpoint, and `Common_SendToServer.sqf` confirms the remote public-variable path carries no trusted sender identity.

## Guard behavior

When `WFBE_C_SEC_HARDENING > 0`, the server rejects:

- malformed actor, vehicle, or lock-state payloads;
- missing, dead, or non-player actor claims;
- lock requests (the honest skill only unlocks);
- null/dead vehicles;
- actor-to-vehicle distance over 12 m;
- vehicles whose authoritative `wfbe_side_id` (with the documented engine-side fallback) does not match the actor side;
- missing/malformed capability challenges or tokens;
- failed capability mint or failed atomic consume (including expired/mismatched/replayed tokens).

The first valid request mints a short-lived capability privately to the claimed actor's owning client. The client accepts it only when its pending challenge matches, then resubmits the exact vehicle. The server repeats validation and consumes the token before calling `lock`. All rejections are `WFBE_CO_FNC_LogContent` warnings; no chat/hint path was added.

When the flag is `0`, the client sends the existing `[vehicle, false, player]` payload and the handler executes the existing lock/broadcast path; the new capability receiver is unreachable.

## Verification

- LoadoutManager mirror: PASS with `A2WASP_SKIP_ZIP=1`; no package artifact.
- Generator `--check`: Takistan drift none; Zargabad drift none.
- `Test-WaspVersionTemplates.ps1`: PASS.
- Focused hardening/helper tests: 6 passed.
- Targeted SQF lint over all 9 changed terrain files: 0 findings.
- Bracket balance: zero net `{}` and `[]` delta in every changed terrain file.
- Changed files are byte-identical across Chernarus/Takistan/Zargabad; `WFBE_C_SEC_HARDENING` remains default `0` in all three.
- Full SQF lint still reports 168 pre-existing unrelated `A3MARKER` findings; none are in changed files.
- Full `python -m pytest Tools/Lint -q`: 362 passed, 1 pre-existing `test_handlespecial_cases.py` case-floor failure.

## Not closed

- No in-engine multiplayer/runtime test was possible or performed; the task forbids live deployment and this lane has no dedicated OA runtime harness.
- The repository-wide lint/test baseline remains nonzero for unrelated existing findings; this lane adds no finding in its changed files.
