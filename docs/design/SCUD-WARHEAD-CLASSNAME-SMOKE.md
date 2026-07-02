# SCUD Warhead Classname Smoke Reference

Date: 2026-07-02
Lane: fleet lane 167, docs-only
Base checked: `origin/claude/build84-cmdcon36` at `6f2fc4bd`

## Scope

This page records the current SCUD warhead class-name evidence and the runtime
smoke checks to use before changing those names. It does not change mission SQF,
mission SQM, lobby parameters, generated artifacts, or packaged output.

The source still carries a `NEEDS REVIEW` marker for the SCUD payload classes in
both maintained roots. This lane turns that marker into a repeatable review map:
where the names are defined, where they are consumed, and which log lines should
appear when the carrier SCUD and land TEL paths are exercised.

## Constants Under Review

The three carrier/TEL warhead constants are mirrored in:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1654-1658`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf:1654-1658`

| Constant | Current class | Static evidence | Primary consumers |
| --- | --- | --- | --- |
| `WFBE_C_SCUD_WARHEAD_HE` | `Sh_125_HE` | Comment says the class is confirmed in A2/OA artillery configs. | Carrier HE area bursts, TEL destroy secondary, TEL SATURATION, TEL RECON flash, TEL STEEL RAIN. |
| `WFBE_C_SCUD_WARHEAD_SADARM` | `Bo_GBU12_LGB` | Comment says the class is confirmed through the existing drone-strike path. | Carrier top-attack anti-armor drops, TEL SATURATION SADARM drops, TEL BUNKER BUSTER. |
| `WFBE_C_SCUD_WARHEAD_WP` | `SmokeShellWhite` | Used in-tree for smoke and SCUD effects. | Carrier smoke/final burn layer, carrier deck backblast, TEL SATURATION WP pass, TEL launch/FASCAM garnish smoke. |

The FASCAM classes are separate placed-mine classes, not SCUD warheads:

- `WFBE_C_ICBM_TEL_FASCAM_MINE_W = "MineMine"` at `Init_CommonConstants.sqf:901`
- `WFBE_C_ICBM_TEL_FASCAM_MINE_E = "MineMineE"` at `Init_CommonConstants.sqf:902`

The producible SCUD/TEL hull is also a separate vehicle class:

- `WFBE_C_TK_SCUD_HF_TYPE = "MAZ_543_SCUD_TK_EP1"` at `Init_CommonConstants.sqf:920`
- Core unit anchors: `Units_OA_TKA.sqf:97` and `Units_OA_US.sqf:183`

## Consumer Map

Carrier SCUD saturation strike:

- `Server/Support/Support_ScudStrike.sqf:11-14` documents the HE/SADARM/WP mix.
- `Server/Support/Support_ScudStrike.sqf:31-33` reads all three warhead constants.
- `Server/Support/Support_ScudStrike.sqf:98` creates the smoke backblast with `SmokeShellWhite`.
- `Server/Support/Support_ScudStrike.sqf:178` logs `saturation delivered` after the MIRV pass.

Land ICBM/TEL:

- `Server/Init/Init_IcbmTel.sqf:123` reads `WFBE_C_SCUD_WARHEAD_HE` for the destroy secondary.
- `Server/Init/Init_IcbmTel.sqf:606-608` reads the HE/SADARM/WP mix for TEL SATURATION.
- `Server/Init/Init_IcbmTel.sqf:667` creates the RECON airburst with the HE class.
- `Server/Init/Init_IcbmTel.sqf:752-754` reads the FASCAM placed-mine classes.
- `Server/Init/Init_IcbmTel.sqf:769` creates FASCAM impact smoke with `SmokeShellWhite`.
- `Server/Init/Init_IcbmTel.sqf:818` reads the HE class for STEEL RAIN.
- `Server/Init/Init_IcbmTel.sqf:874` reads the SADARM class for BUNKER BUSTER.
- `Server/Init/Init_IcbmTel.sqf:1183` creates the bought SCUD hull from `WFBE_C_TK_SCUD_HF_TYPE`.

The same anchors exist in both the Chernarus root and the maintained Takistan
root on the checked base.

## Runtime Smoke Checklist

Use this checklist for the next live SCUD smoke. It is intentionally phrased as
runtime evidence to gather; this docs lane only performed static source review.

- Start from A2 OA 1.64 and the current mission source. Do not test against
  repacked or live-server artifacts unless the package under test is explicitly
  named in the worklog.
- Confirm the three constants still exist in both maintained roots before launch.
- Fire the carrier SCUD path and look for `Support_ScudStrike.sqf : [side] team
  [team] SCUD request at ...`, then `Support_ScudStrike.sqf : saturation
  delivered at ...`.
- During the carrier run, check the RPT for no `Cannot create non-ai vehicle`,
  missing config, undefined variable, or class-not-found errors for `Sh_125_HE`,
  `Bo_GBU12_LGB`, or `SmokeShellWhite`.
- Spawn or unlock the land TEL and verify an `ICBMTEL|v1|SPAWN|...` line.
- Fire TEL SATURATION and check for the launch-authorized line plus no class
  creation/config errors for the HE/SADARM/WP mix.
- Fire TEL RECON and check `ICBMTEL|v1|RECON|...`; the HE airburst should not
  emit class/config errors.
- Fire TEL FASCAM and check `ICBMTEL|v1|FASCAM|...`, then
  `ICBMTEL|v1|FASCAM-CLEAR|...` after cleanup. Mine classes should be
  `MineMine`/`MineMineE`, not loadout magazine names.
- Fire TEL STEEL RAIN and check `ICBMTEL|v1|STEELRAIN|...`; the HE airbursts
  should not emit class/config errors.
- Fire TEL BUNKER BUSTER and check either `ICBMTEL|v1|BUSTER|...` or
  `ICBMTEL|v1|BUSTER_NO_TARGET|...`; the SADARM class should not emit class or
  config errors.
- Destroy the TEL during a NUKE countdown and check
  `ICBMTEL|v1|CANCEL-ON-DESTROY|...`; the HE destroy secondary should not emit
  class/config errors.
- Repeat the source-anchor check on the maintained Takistan root before changing
  class names, because Takistan is the SCUD-heavy map and mirrors the same TEL
  implementation.

## Change Guardrails

If any class name changes later:

- Keep the Chernarus and Takistan maintained roots mirrored.
- Use `Tools/LoadoutManager` for mission-source changes so generated mission
  roots stay in sync.
- Record exact RPT evidence for every SCUD/TEL path exercised.
- Keep the change off live deployment and package artifacts unless a separate
  release lane explicitly asks for that.
- Do not replace these class names with classes only verified in a different
  engine or game generation; this repo target is A2 OA 1.64.
