# Result — heavy-attack supply trust follow-up

- PR: [#1423](https://github.com/rayswaynl/a2waspwarfare/pull/1423)
- Branch: `codex/attackwave-supply-trusted-20260725`
- Base: PR #1402 head `c2527a309d87adfdf0679861b666e7314b389bad`
- Commit: `ad4fadd022594308b980bc032590727f6da8427c`

## Defect verified

PR #1402 defaults the side-supply handler's outer `_trusted` argument to `false`.
The heavy-attack debit passed two outer arguments and a three-element payload, so
armed `WFBE_C_SEC_HARDENING` rejected it before applying the full-supply debit.

## Callers found

Fixed direct server-internal debit callers:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/AttackWave.sqf:73`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/AttackWave.sqf:73`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/PVFunctions/AttackWave.sqf:73`

Already-trusted direct calls from PR #1402:

- The three maintained `Common/Functions/Common_ChangeSideSupply.sqf:46` copies.

Audited public-variable event-handler registrations, unchanged:

- Each maintained `Server/Functions/Server_ChangeSideSupply.sqf` has west, resistance, and east registrations at lines 91, 97, and 101.
- `Tools/PerfTest/missions/WASP_PerfOFF_TEST.Chernarus/Server/Functions/Server_ChangeSideSupply.sqf` has the same three registrations at lines 54, 59, and 63.
- No matching handler/caller exists under `Modded_Missions/`.

## Verification

- Focused contract: PASS.
- Full SQF lint: 2,505 files scanned; 168 baseline findings; zero findings in edited AttackWave files.
- Exact normalized diff: only the trust argument changed; curly/square delimiter deltas are zero.
- LoadoutManager mirror generation: PASS; dry-run reports Takistan and Zargabad drift none.
- Version-template test: PASS.
- No deploy, live-server change, merge, or flag arming.

## Unresolved

No task blocker remains. The guide prose says TK/ZG `WF_MAXPLAYERS` should be 61,
while the canonical templates and version-template test currently pass with 31/33;
this pre-existing unrelated discrepancy was not changed.
