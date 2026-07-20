# Approved-wave integration manifest

Branch: `update/wave-20260720`
Base: `origin/master` @ `80c690257f9dacc013110ce7be14768c4b3f3c4f`
Integration worktree: `C:\tmp\fixwt\update`

## Integrated PRs

- #1192 — CAPGATE telemetry throttle/debounce and self-protect reason priority; head `2f1ee9fd91e2b7833abaeadf04eeb5a5246a6799`; Sol/adversarial: APPROVE-WITH-NITS (2 minor); Kimi: APPROVED.
- #1193 — crew-seat restoration, player reward-radius correction, and council roster tuning; head `229b254a6b06f9058c78945f86120cf9a5c9f3d7`; Sol/adversarial: REQUEST-CHANGES (1 blocker, 1 minor); Kimi: APPROVED.
- #1194 — shared mounted classifier, CapLock protection, and gated/progress-qualified HighClimb pulse; head `69ed01c281047120e59b84de3da8b77a22284bd8`; Sol/adversarial: REQUEST-CHANGES (2 blockers, 2 majors); Kimi: APPROVED.
- #1164 — count only live camp logics to prevent deleted-camp capture deadlock; head `176aafd502f44415f1132632dcd7bee2ed49318f`; Sol: not separately recorded in supplied review; Kimi/owner: APPROVED for this integration.

## Merge commits

- #1192 merge: `b1d1d194a36f28a4b5a95b5f2251cabb0b9a99a1`
- #1193 merge: `10608bc3fd490bb770fea44c63aaf4ed9792413c`
- #1194 merge: `7353750fa01774675ed866c0e7768b58b1e466f8`
- #1164 merge: `b1ea40278447755229c3eaeed1d327f47620fda9`

## Combined changed files vs origin/master

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/PVFunctions/CampCaptured.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMTeamMounted.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOM_HighClimb.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GetTotalCamps.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GetTotalCampsOnSide.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Common.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/PVFunctions/CampCaptured.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_AICOMTeamMounted.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_AICOM_HighClimb.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_GetTotalCamps.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_GetTotalCampsOnSide.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_RunCommanderTeam.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_Common.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Allocate.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_AssignTowns.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/server_town.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/PVFunctions/CampCaptured.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_AICOMTeamMounted.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_AICOM_HighClimb.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_GetTotalCamps.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_GetTotalCampsOnSide.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_RunCommanderTeam.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_Common.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_CommonConstants.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Allocate.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_AssignTowns.sqf
Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/FSM/server_town.sqf
Tools/Lint/test_camp_null_count.py
```

## Verification

- `check_sqf.py --select ...`: 33 SQF files scanned; 0 findings.
- `Tools/Lint/test_camp_null_count.py`: 5 tests, all passed.
- `git diff --check origin/master..HEAD`: passed.
- Chernarus/Takistan/Zargabad `git hash-object` comparison: 11 mirrored file classes, all byte-identical.
- Merge conflict markers: none.


## Roster-council expansion

- Commit `12387970479d13b1c9f463c55305ff0fc4c8fdf7` - `roster-free-wins`: contractor/T-55/AA roster closures.
- Commit `b4427c20d4c0d3ed0258e79d0669f2fb0108ebf4` - `groups-to-10`: larger registered infantry and mounted AICOM complements.
- Commit `c51d379d689dc3faa866e5e6849c7d50ad525d25` - `garrison-variety`: additive US/TKA/TKGUE garrison variants.
- Commit `1883a4989a38cb007ae22e61f0f738235841c02f` - `faction-rares`: map-branched TKA/NAPA rare rolls and no-artillery vehicle sprinkles.
- Commit `943646728595a1038a8c4a474b32080d4c9c7cbd` - `air-pack`: dark-by-default council air templates, owner gunner flip retained, and lift-majority bucket guard.
- Commit `2e19d707f1060f03962297d83215b5b493bcad60` - `patrol-sweep`: shared roster-key patrol entries and GUER wildcard foot-roster use.
- Chat relay (`chat-tap`): SKIPPED. The OA 1.64 mission sources and verified command/event inventory provide no safe, documented server-side chat hook; `HandleChatMessage`/A3 mission-event forms are not used without OA proof. No flag or misleading partial relay was shipped.

### Additional changed file classes in the roster expansion

```text
Common/Config/Core_Root/Root_GUE.sqf
Common/Config/Core_Root/Root_RU.sqf
Common/Config/Core_Root/Root_TKA.sqf
Common/Config/Core_Root/Root_TKGUE.sqf
Common/Config/Core_Root/Root_US.sqf
Common/Config/Core_Squads/Squad_OA_US.sqf
Common/Config/Core_Squads/Squad_RU.sqf
Common/Config/Groups/Groups_TKA.sqf
Common/Config/Groups/Groups_TKGUE.sqf
Common/Config/Groups/Groups_US.sqf
Common/Functions/Common_RunSidePatrol.sqf
Common/Init/Init_CommonConstants.sqf
Server/AI/Commander/AI_Commander_AssignTypes.sqf
Server/AI/Commander/AI_Commander_Teams.sqf
Server/Functions/AI_Commander_Wildcard_GUER.sqf
Server/Functions/Server_GetTownGroups.sqf
Server/Functions/Server_GetTownGroupsDefender.sqf
```

The 17 paths above are touched identically in Chernarus, Takistan, and Zargabad; the existing integrated-wave paths remain listed in the prior section.
