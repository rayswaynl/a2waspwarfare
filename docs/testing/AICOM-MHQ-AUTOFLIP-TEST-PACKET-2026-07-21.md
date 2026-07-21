# AICOM MHQ auto-flip - verification record and runtime test packet

Date: 2026-07-21
Change: `Common/Functions/Common_AICOM_AutoFlip.sqf` (CH source + TK/ZG mirrors), PR #1231
Flag: `WFBE_C_AICOM_AUTOFLIP` (existing, default 1 - `Common/Init/Init_CommonConstants.sqf:1071`)
Owner directive: AI comm/HQ vehicles should recover automatically when flipped or stuck.

---

## 1. Coverage map - what was already covered, what was missing

The directive names two failure modes. Only one of them was an actual gap.

| Failure mode | Pre-existing coverage | Status |
|---|---|---|
| MHQ **stuck** with an active move order (no progress while relocating) | `Server/AI/Commander/AI_Commander_MHQReloc.sqf:390-399` unstuck NUDGE (`setVelocity [0,0,0]` + optional `setDir` turn + re-`doMove`, rate-limited by `_nudgeSecs`); `:401-419` harder tier `STUCK_TELEPORT` to `_destPos`, gated on no player within `_safeDist` and `!surfaceIsWater` | Already implemented - **not duplicated** |
| MHQ **flipped** (rolled onto roof/side) | none - the AICOM AutoFlip manager only enumerated `wfbe_teams` group hulls; `Common_AICOM_HighClimb.sqf` is likewise `wfbe_teams`-only; `Client/Module/AutoFlip/AutoFlip.sqf` is client-side and watches the player's own vehicle/group | **Gap - closed by this change** |

A `vectorUp` search across the Chernarus tree returns only `Common_AICOM_AutoFlip.sqf`,
`Client/Module/AutoFlip/AutoFlip.sqf` and `Common_AICOM_HighClimb.sqf` - none of which
referenced `wfbe_hq` before this change. No pre-existing file rights a flipped HQ.

The directive's own definition of stuck ("speed ~0 for N seconds **WITH an active move
order**") is exactly the MHQReloc case, which already has a ladder. A mobilized MHQ with no
move order is parked, not stuck, so it is deliberately left alone. This is the "extend the
current one, do NOT build a parallel loop" instruction taken literally.

## 2. Why the mobilized HQ needed an explicit candidate path

The AutoFlip manager discovers hulls through `vehicle _x` over `units _team` for each group in
the side logic's `wfbe_teams` array. The side HQ is not in `wfbe_teams`; it is stored on the
side logic as `wfbe_hq`, with `wfbe_hq_deployed` distinguishing the two states:

- deployed -> `wfbe_hq` is a **static structure** (`Server/Construction/Construction_HQSite.sqf:29-30`)
- mobilized -> `wfbe_hq` is the **driveable MHQ vehicle** (`Construction_HQSite.sqf:94-95`,
  `Server/Init/Init_Server.sqf:762-763` at boot, `Server/Functions/Server_MHQRepair.sqf:41,46`,
  `Server/Functions/Server_OnHQKilled.sqf:49-50`)

All six write sites use the 3-argument broadcast form, so the pair replicates to headless
clients. The mobilized MHQ itself is **server-local** in every path
(`AI_Commander_MHQReloc.sqf:339` - "Server-local here (AICOM MHQ is server-owned)"), so the
`local _veh` guard means the new branch only ever acts on the server instance of the manager.

MHQ classnames per side are wheeled ground vehicles, so the existing
`isKindOf "Motorcycle" / "Air" / "Ship"` guard does not filter them out:

| Side | Classname | Source |
|---|---|---|
| West | `LAV25_HQ` | `Common/Config/Core_Structures/Structures_CO_US.sqf:6` |
| East | `BTR90_HQ` | `Common/Config/Core_Structures/Structures_CO_RU.sqf:6` |
| Resistance | `BRDM2_HQ_Gue` / `BRDM2_HQ_TK_GUE_EP1` | `Structures_CO_GUE.sqf:6` / `Structures_OA_TKGUE.sqf:6` |

GUER never receives an HQ: the boot loop covers west/east only
(`Init_Server.sqf:916`) and the commander supervisor excludes resistance
(`Init_Server.sqf:1381`). So `wfbe_hq_deployed` is permanently nil on `WFBE_L_GUE`.

### Deliberate deviation: the nil default

The new guard reads `_logik getVariable ["wfbe_hq_deployed", true]`, i.e. **default true =
treat as deployed = do not touch**. The codebase's canonical accessor
`Common/Functions/Common_GetSideHQDeployStatus.sqf:8-10` defaults to `false`. The deviation is
intentional and fail-closed: an unset flag must never be read as "mobilized" and hand a static
HQ structure to vehicle recovery. For resistance (the only permanently-nil case) both defaults
end in no action anyway, because `wfbe_hq` is `objNull` there and the `isNull` guard catches it.

## 3. Recovery behaviour and thresholds (unchanged from the existing manager)

All five conditions must hold, re-checked on each 5 s pass; any one unmet clears the timer:

- tilt: `(vectorUp _veh) select 2 < 0.35`
- slow: `|velocity| < 2` m/s
- grounded: `(getPos _veh select 2) < 3`
- dry: `!surfaceIsWater (getPos _veh)`
- off cooldown: `now - lastFlip > 45` s

Sustained for >= 10 continuous seconds -> `setVectorUp [0,0,1]`, `setPos` z=0.5 lift,
`setVelocity [0,0,-0.5]` settle.

Unlike the `wfbe_teams` path (which reaches hulls only through `units _team` and therefore
misses crewless wrecks), the HQ branch passes the MHQ regardless of crew, so an **empty**
flipped MHQ is also recovered.

## 4. Player proximity

Per the directive, nearby players do **not** suppress recovery for comm units; the count is
logged for tuning only. The added counter uses the same idiom already used server-side in
`Server/Construction/Construction_SmallSite.sqf:224`, `Construction_MediumSite.sqf:258` and
`AI_Commander_MHQReloc.sqf:408-409`.

## 5. RPT lines to look for

Because the MHQ branch only fires where the hull is local, an MHQ righting lands in the
**server** RPT (`arma2oaserver.RPT`), not the HC RPT that carries delegated AICOM team logs.

```
AICOMSTAT|v1|EVENT|true|<min>|AUTOFLIP|righted=<class>|playersNear=<n>
AICOMSTAT|v1|EVENT|<isServer>|<min>|AUTOFLIP_HB|machine=<SERVER|HC>|localVeh=<n>|tilted=<n>
```

The heartbeat is rate-limited to 120 s and distinguishes idle (localVeh>0, never tilted) from a
wiring fault (localVeh=0).

## 6. Runtime acceptance procedure (owner-run, test server only)

Not executed by the implementing lane - no server was deployed or restarted. Steps:

1. Start a test server on any of the three terrains. Confirm boot line
   `Common_AICOM_AutoFlip.sqf: AICOM auto-unflip manager started (SERVER).`
2. Keep the side's HQ **mobilized** (do not deploy it), or mobilize it from the deployed state.
3. Server-exec, on flat dry ground, clear of water:
   ```sqf
   _hq = west Call WFBE_CO_FNC_GetSideHQ;
   _hq setVectorUp [0,1,0];
   _hq setVelocity [0,0,0];
   ```
4. Wait >= 15 s (10 s sustain + up to one 5 s tick).
5. PASS = the MHQ is upright again and the server RPT carries
   `AUTOFLIP|righted=LAV25_HQ|playersNear=<n>`.
6. Negative control: deploy the HQ, repeat step 3 against
   `WFBE_L_BLU getVariable "wfbe_hq"`. Expect **no** `AUTOFLIP|righted=` line - a deployed
   static HQ must never enter vehicle recovery.
7. Cooldown control: immediately re-flip a righted MHQ. Expect no second righting within 45 s.

## 7. Static verification performed (2026-07-21, main PC)

| Check | Result |
|---|---|
| `python Tools/Lint/test_aicom_autoflip.py` | 3 tests, OK |
| Full required `check_sqf.py --select ... --no-classname-index` | 168 pre-existing baseline findings tree-wide, **0 in the changed AutoFlip copies**; gate exits 1 because the baseline is non-empty |
| CH/TK/ZG AutoFlip SHA-256 parity | identical - `9bf44a3dd7c35d27faab7e9cb2cbdf1014bbac8758e2e9915f4e389e87ca3419` |
| Bracket delta per edited file | `{`/`}` 44/44, `[`/`]` 36/36 - net zero |
| Line endings | CRLF preserved |
| Every CI-listed test suite, post master merge | all OK except `test_fpv_purchase_authority.py` (pre-existing, see below) |

## 8. Discovered issues (out of scope for this change, flagged for the owner)

1. **`Tools/Lint/test_fpv_purchase_authority.py` fails on master.**
   `test_client_result_handles_denial_and_authoritative_stamp` asserts
   `_fpvDrone == playerFPV` is present in the client PV handler; the string is absent.
   Reproduced on a clean `origin/master` worktree at `a7d954258c`, so it predates this branch.
2. **A failing test in the "Python unit tests" CI step does not fail the job.**
   The pwsh step reports only the last command's exit code, so intermediate suite failures are
   logged and ignored - run 29820266429 recorded step 5 as *success* while the FPV suite failed
   inside it. Verified by replicating the GitHub pwsh invocation locally. Making that step
   fail-fast would immediately turn CI red on issue 1, so it is left as an owner decision.
3. **Branch staleness broke an unrelated contract test.** CI run 29820266429 also failed
   `test_cmd_v2_nudge.py::FlagContractTests::test_every_master_flag_is_registered_default_zero`
   because `WFBE_C_CMD_POSTURE_GARRISON` landed on master after the branch point. Fixed here by
   merging current master into the branch; the suite passes post-merge (48 tests, OK).
