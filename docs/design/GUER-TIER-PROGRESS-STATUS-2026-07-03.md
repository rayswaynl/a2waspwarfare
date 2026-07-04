# GUER Tier Progress Status - 2026-07-03

## Scope

Lane 154 asks for more durable GUER tier-progress visibility: a reliable unlock notification and
an RHUD "kills to next tier" row. This pass is documentation-only because the current target
source already carries both pieces across the maintained mission copies.

No mission SQF, generated mirror, packaging, or live runtime settings are changed here. This also
avoids touching the busy RHUD source surface while adjacent open PRs cover FOB RHUD status and
other RHUD/QoL rows.

## Current Source State

`Root_GUE_PlayerOverlay.sqf` starts a client-side unlock watcher for playable GUER. It seeds the
last seen unlock sequence from `WFBE_GUER_UNLOCK_MSG`, then only shows new unlocks earned after
the player has joined:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:118`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:124`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:128`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

When a new unlock message arrives, the client displays both a `titleText` toast and a richer
`hintSilent parseText` notification:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:130`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:131`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:130`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:130`

`Client_UpdateRHUD.sqf` reserves GUER-only rows for tech kills and FOB availability:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:243`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:246`
- The same line anchors are present in the Takistan and Zargabad maintained copies.

The RHUD progress helper reads `WFBE_GUER_PLAYER_KILLS`, compares it against the tier and M113
thresholds, and formats either the remaining kills to the next unlock or the max-tech state:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:283`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:285`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:287`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:288`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:289`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:290`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:302`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:304`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

The RHUD update loop only fills the GUER rows for playable resistance clients. It calls the
progress helper, writes the value into control pair 15/16, and keeps the FOB row beneath it:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:533`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:537`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:540`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:542`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

The GUER onboarding card also tells resistance players where to watch those rows:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:89`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:90`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

## Status

No source follow-up is needed for the core lane 154 ask on the current target branch. The useful
remaining work is runtime smoke: drive the GUER kill counter through each threshold and confirm
the one-shot unlock notification and the RHUD progress row update in-game.

## Verification

- Confirmed `Root_GUE_PlayerOverlay.sqf` unlock watcher, `titleText`, and `hintSilent` anchors in
  Chernarus, Takistan, and Zargabad.
- Confirmed `Client_UpdateRHUD.sqf` GUER progress helper, `Tech Kills` row, playable-resistance
  guard, and display write anchors in Chernarus, Takistan, and Zargabad.
- Confirmed the maintained overlay files share one SHA-256 hash and the maintained RHUD files
  share one SHA-256 hash.
- Confirmed the GUER onboarding text points players toward the RHUD `Tech Kills` and `FOB` rows.
- Kept this pass documentation-only; LoadoutManager was not required because no mission source
  or generated mirror files changed.
