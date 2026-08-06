# AI commander AIR doctrine deep dive

Investigated against `origin/master` at `bcd35dbb47f8e1aa3d01990b801bee1256935e9f` on 2026-07-26. This is Arma 2 community-game AI doctrine work; the box investigation was read-only and no live server was changed.

## Evidence window and scope

The supplied `dbg0726g` snapshot is a useful historical symptom: at 40 minutes, WEST was rich with a factory, spare air headroom, `eligAir=11`, and a final `bucket=inf`. It does not prove the current source has no air doctrine. Fresh read-only source tracing and the current server/HC `MISSINIT` windows show later air-doctrine work already exists. In the server window, the latest WEST record was an air founding at minute 543 with an airfield, Aircraft Factory, one retained transport, and `bucket=air`; HC tails also contain airmobile execution outcomes. The deployed window is an older wave than this source base, so deployed cap values are evidence of that round's configuration, not a source-default claim.

The verdicts below deliberately separate the old observation from verified current behavior. No speculative balance or transport change is shipped.

## 1. Air priority when rich

**Verdict: working as designed in current source; the old rich-snapshot premise is not enough to justify a balance fix.** Funds expand the commander target/capacity, but do not directly replace the bucket roll. Air is nevertheless deliberately late-weighted, capacity-gated, and observed being founded in the current server window.

### File evidence

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:637-668` blocks air below the established-town threshold unless an airfield/factory waiver applies, then applies the side air census and late-game cap rail.
- `.../AI_Commander_Teams.sqf:881-915` gives late air a helicopter-share rail and preserves lift-capable templates when the council pack is enabled.
- `.../AI_Commander_Teams.sqf:918-965` selects maturity weights for `[inf, light, heavy, air]`, applies doctrine and ground biases, then multiplies air by elapsed-match-time bias before empty buckets are zeroed.
- `.../AI_Commander_Teams.sqf:967-1040` performs the bounded weighted bucket/template draw. The template draw uses CfgVehicles effectiveness rather than the mission purchase price.
- `.../AI_Commander_Teams.sqf:1231-1259,1367-1375` sums the selected template price, rejects unaffordable templates, charges only after the gates, and emits founding telemetry.
- `Common/Init/Init_CommonConstants.sqf:479,505-512,555-556,1116` supplies the normal/late caps, retained air transport, vehicle-lift default, and the late air-bias ramp. `Server/AI/Commander/AI_Commander.sqf:716-718` records the existing rich-reinforcement state, which is target logic rather than an air-weight multiplier.

### Interpretation

The supplied `bucket=inf` means that cycle chose infantry; it is not a rejection reason or proof that air was unavailable. A rich commander can still choose another eligible bucket, but the current late mix and time multiplier make air a deliberate part of the doctrine. The fresh server evidence of repeated air teams, including a retained transport, contradicts a general claim that the commander never buys or uses air.

### Proposed change

Do not add a funds-forced air multiplier from this report. First reproduce the original symptom on the same terrain/configuration and collect a bounded sample of `TEAM_FOUNDED` and `AICOMAIR` records with funds, town count, cap, eligibility, and chosen bucket. If that demonstrates persistent late-game under-selection after the existing rail is applied, a separate default-`0` balance flag can modify only the air weight after the current time bias and before empty-bucket zeroing. `AI_Commander_Teams.sqf` overlaps open runway-placement work, so no source edit is safe on this branch.

## 2. TK-EASA variants

**Verdict: working as designed; the synthetic purchase tokens are player-facing, while AI EASA loadouts are already applied server-side.** The observed boot registrations prove catalog registration only; absence of a runtime `TKV_*` string does not prove that AI aircraft cannot receive an EASA kit.

### File evidence

- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_TKEasaRoster.sqf:3-17,42-52` defines `TKV_*` as non-`CfgVehicles` purchase keys and limits the roster to enabled Takistan use.
- `.../Client/Functions/Client_BuildUnit.sqf:576-611,793-799` resolves those keys to a base hull and applies the player-selected kit locally. Tokens therefore must not be placed directly in an AI classname template.
- `.../Common/Functions/Common_RunCommanderTeam.sqf:448-460` has a distinct AI path: after the team is created on its owning machine, it gates EASA kit application on `WFBE_C_AICOM_EASA_AI` and the side's researched EASA level.
- `.../Common_RunCommanderTeam.sqf:466-523` maps real airframe classnames to balanced kit rows, changes the local hull's weapons/magazines, and emits `AICOMSTAT|v2|...|EASA_AI_KIT` for each applied hull.

### Interpretation

`TKV_*` is player-catalog infrastructure, not the AI selection mechanism. AI selects real hull classes and the existing server/HC-local runner equips matching airframes after EASA research. The all-boot-time `TKV_*` RPT mentions from the observed round therefore only show that the catalog built; they neither require nor are the runtime proof of the AI kit path. Runtime proof is an `EASA_AI_KIT` line after an eligible airframe is founded with EASA researched.

### Proposed change

No token-wiring fix. A direct token injection into an AI template would be unsafe because the tokens are not vehicle classes. Run one controlled Takistan observation with EASA researched and retain the resulting `EASA_AI_KIT` telemetry; investigate only if that established path fails for a matching founded hull.

## 3. Air ferry / transport

**Verdict: working as designed in current source for both infantry and eligible vehicles.** The previously reported zero matches for the generic word `airlift` are not a test of this feature: it uses `AICOMAirLeg`, `VEHLIFT`, `VEHDROP`, and `AICOMAIR` telemetry instead.

### File evidence

- `Common/Init/Init_CommonConstants.sqf:505-512` enables retained AICOM transport, town-to-town airmobile legs over the configured distance, and one eligible vehicle lift per leg by default.
- `Common/Functions/Common_RunCommanderTeam.sqf:1369-1398,1423-1434` finds a live cargo-capable helicopter, invokes `AICOMAirLeg` for a long order, and keeps road movement as the fallback when the helper cannot launch.
- `Common/Functions/Common_AICOMAirLeg.sqf:44-80,98-140,309-390,453-460` validates the local transport/team, boards on-foot infantry, uses a hot/cold LZ decision, runs a bounded flight, returns passengers to ground movement, and returns the retained transport to base for the next order.
- `.../Common_AICOMAirLeg.sqf:174-226` selects at most one eligible team-owned ground vehicle and never lifts the team's only drivable ground transport. `:268-279` slings and logs the lift.
- `.../Common_AICOMAirLeg.sqf:391-449` completes the deep drop, restores the vehicle to ground control, orders its crew onward, and emits success/safety-release telemetry. `Server/Functions/Server_HandleEmptyVehicle.sqf:39-46` separately protects explicitly marked manual `wfbe_airlifted` cargo; the AICOM path owns its `wfbe_aicom_slung` lifecycle itself.

### Interpretation

The narrow first cut requested by the brief is already surpassed: AICOM retains a team transport, carries on-foot infantry on repeated long legs, and can sling an eligible extra ground vehicle without sacrificing the team's sole ground transport. `AI_Commander_AirResp.sqf` remains the wrong place for ferry work because it is a short-lived attack-response lifecycle, not a registered commander-team transport path.

### Proposed change

No duplicate ferry feature. For the next live check, search the current `MISSINIT` window for `AICOMAirLeg`, `VEHLIFT`, `VEHDROP`, `stage=airleg`, and `stage=vehlift` rather than only `airlift`. If field evidence shows the existing path does not launch despite a qualifying team/route, capture the helper's explicit terminal reason before changing its HC-local lifecycle or transport ownership.

## Delivery decision

No source fix is shipped in this PR. All three requested behaviors already have current, bounded implementations or the observed source token is deliberately not the relevant AI path. A balance change would be a new owner decision and must be measured against the existing late-air rails before it is flag-gated and proposed separately.

## Verification

- Fresh isolated worktree based on `origin/master` commit `bcd35dbb47f8e1aa3d01990b801bee1256935e9f`.
- Read-only server and HC RPT reads were limited to their latest `MISSINIT` boundaries; no deploy, restart, write, or configuration change was performed.
- The draft PR changes one Markdown report only; no SQF source, generated terrain mirror, or package is changed.
