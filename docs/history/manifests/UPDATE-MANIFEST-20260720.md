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
- Commit `943646728595a1038a8c4a474b32080d4c9c7cbd` - `air-pack`: council air templates and lift-majority rail are both gated dark by default; owner gunner flip retained.
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

## Fable review round

- Fixed the patrol road-bias scanner to type-check and expand shared roster-key strings before iterating pool entries.
- Gated both lift-majority air rails with `WFBE_C_AICOM_AIR_COUNCIL_PACK` and corrected the manifest wording: templates and rail are both gated.
- Replaced the unarmed AICOM `AH6X_EP1` Scout Flight entry with a second `AH6J_EP1` attack helicopter.
- Cherry-picked only naval fallback commit `3816b82fa`; PR #1186 was not merged because its base included unrelated master changes.

## Fable-cleared fold-in backlog

- #1166 merged (master-based): `2b3a7c2a325edddb2bb181e18e895ded85175340`.
- #1168 cherry-picked unique commit: `96d5bf6e38a46b3002bc509019a181e6c66e25d6`.
- #1170 cherry-picked unique commit: `3cae7765a2806552c49d24ae2046dcaaff695818`.
- #1171 cherry-picked unique commit: `abd1fce9d31add5a5dc54f0f98f9ea07e2807640`.
- #1172 cherry-picked unique commit: `d66b3ee73bb8c608d62f83d27473cefe84ce0cde` (conflict resolved with existing refund logic retained).
- #1173 cherry-picked unique commit: `abfa636763c735e93f9f76ebcc623e74b098c04c`.
- #1174 cherry-picked unique commit: `3ffe48fdbc981d3a6c3d58457c411ec52d7ce6fd`.
- #1175 cherry-picked unique commit: `62cad3e66f26f884d88e3af216314ec685141770`.
- #1176 cherry-picked unique commit: `b299f3bb6e609771e9e034bd67b937c6201f81d9`.
- #1177 cherry-picked unique commit: `3c5d16198a8a409d004b2dd3862921a7bb6f1467`.
- #1178 cherry-picked unique commit: `ebf21ac741a83f3876b153ec81c98560d1cf6b27` (combined GDIR recovery with existing GUER group-cap logic).
- #1179 cherry-picked unique commit: `1e13845be28271e673a09f694dd1b3bc3ee25800` (conflict resolved with existing teardown retained).
- #1180 cherry-picked unique commit: `88929a9641a2ef810cd983da2648c559001a40f4`.
- #1181 cherry-picked unique commit: `62a6a5acb1b16742cf203c17dfa60de7ff17a14c`.
- #1182 cherry-picked unique commit: `a7255cf25a5d9ee7efab57d104bb749f55b0e84c`.
- #1183 cherry-picked unique commit: `f3e2e506023d4a49c799fb5368cc1ebdd8868fa1`.
- #1184 cherry-picked unique commit: `d705da4a2365e1af185ba23dacdcb16f73ebd50c`.
- #1185 cherry-picked unique commit: `8eb08e939064b1b8722f5c7b5a391434e68981bb`.
- #1187 cherry-picked unique commit: `40a22d8ee0ccb123999eb6fee2af3b5e9cab123c`.
- #1188 merged (master-based): `6b172b41617446bbb367b100c4421f0dde5b969d`.
- #1189 cherry-picked unique commit: `48d84ece4e2b27063bf2e6e896a437f726631f72`.
- #1190 merged (master-based): `9854b70c24546186f383783b3aadf425dc21c60d`.
- #1191 merged (master-based): `4bc43f55ece9574e3ab1bbb5e069cb9649de9bb7`.
- Excluded #1186: already cherry-picked as `dd6d103914e72790a4cf6451483707c58bd41f2a`; its PR still needs rebase.
- Excluded #1154-#1163: RC2 stack, intentionally not folded.
