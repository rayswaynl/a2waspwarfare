# GUER Improvised Armor Status - 2026-07-03

## Scope

Lane 170 asks to revive GUER improvised armor behind the existing default-off flag. This pass is
documentation-only because the current target source already contains the constants, damage
handler, and vehicle creation hook across the maintained mission copies.

No mission SQF, generated mirror, packaging, or live runtime settings are changed here. Adjacent
open armor work, such as PR #285's AICOM armor-screen behavior, remains separate and does not
touch this GUER player/damage-handler path.

## Current Source State

The tuning constants are present in all maintained `Init_CommonConstants.sqf` copies. The base
reduction defaults to zero, so the feature is fully inert until explicitly enabled:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:92`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:93`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:94`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:95`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:96`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

`Common_GuerArmor.sqf` is the dedicated handler. It reads the base reduction, exits unchanged
when that value is zero, scales by `WFBE_GUER_VEHICLE_TIER`, applies a cap, adds a mobility bonus
for drivetrain selections, logs the effective reduction, and registers a `HandleDamage` handler:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GuerArmor.sqf:2`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GuerArmor.sqf:38`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GuerArmor.sqf:39`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GuerArmor.sqf:40`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GuerArmor.sqf:41`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GuerArmor.sqf:42`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GuerArmor.sqf:85`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GuerArmor.sqf:98`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GuerArmor.sqf:103`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

`Common_CreateVehicle.sqf` wires the handler at vehicle creation time. The gate requires the base
flag to be above zero, the created side to be GUER, and excludes Tank, APC, and Air classes:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateVehicle.sqf:36`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateVehicle.sqf:38`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateVehicle.sqf:39`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateVehicle.sqf:40`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

## Status

No source follow-up is needed for the core lane 170 ask on the current target branch. The useful
remaining proof is runtime smoke with `WFBE_C_GUER_IMPROVISED_ARMOR` raised above zero: spawn a
GUER technical, apply non-AT bullet damage and AT/HEAT damage, and confirm only the non-AT path
logs the expected `Common_GuerArmor` reduction.

## Verification

- Confirmed the default-off constants in Chernarus, Takistan, and Zargabad.
- Confirmed the dedicated `Common_GuerArmor.sqf` handler, off-switch, tier scaling, mobility
  bonus, diagnostic log, and `HandleDamage` registration in all maintained mission copies.
- Confirmed the `Common_CreateVehicle.sqf` hook gates on the flag, GUER side, and non-Tank/non-APC/non-Air vehicle classes in all maintained mission copies.
- Confirmed the maintained `Common_GuerArmor.sqf` files share one SHA-256 hash and the maintained
  `Common_CreateVehicle.sqf` files share one SHA-256 hash.
- Kept this pass documentation-only; LoadoutManager was not required because no mission source
  or generated mirror files changed.
