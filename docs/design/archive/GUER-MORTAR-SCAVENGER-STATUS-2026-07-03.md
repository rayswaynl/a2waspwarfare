# GUER Mortar Pit + Scavenger Status (Lane 16)

Lane 16 originally covered two A-Life v2 ideas from `docs/design/ALIFE-V2-AND-DOCTRINES.md:24-27`:

- GUER mortar harassment pits near the front.
- GUER wreck scavengers using the abandoned-husk registry.

Current source state is intentionally split. The mortar-pit half is shelved by owner direction. The wreck-scavenger half already exists as the G5 GUER Scavenger Team wildcard, gated off by default.

## Current Status

### G4 mortar pit

Status: shelved. Do not revive without a fresh owner decision.

Evidence:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Parameters.hpp:643` says the G4 GUER Mortar Pit wildcard card is shelved by Ray on 2026-07-02 and that its lobby toggles were removed.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard_GUER.sqf:22` repeats the shelved note and points at the wiki shelf page.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard_GUER.sqf:96-97` documents that G4 was removed from the draw deck. The active weight setup only initializes G1, G2, and G5.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard_GUER.sqf:420-423` announces only G1 Car Bomb, G2 Pop-up Checkpoint, and G5 Scavenger Team.

This means there is no default-off dormant G4 path to test. The safe follow-up is design re-approval first, then a new source lane if the mortar-pit concept is unshelved.

### G5 scavenger team

Status: implemented, default off.

Evidence:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Parameters.hpp:644-668` defines the G5 Scavenger Team flag and tuning params:
  - `WFBE_C_GUER_SCAV` default `0`.
  - `WFBE_C_GUER_SCAV_REWARD` default `300`.
  - `WFBE_C_GUER_SCAV_PLAYER_BONUS` default `150`.
  - `WFBE_C_GUER_SCAV_TTL` default `300`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard_GUER.sqf:101-106` makes G5 eligible only when the flag is on, GUER has a soldier class and at least one owned town, and at least two abandoned wrecks are present.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard_GUER.sqf:317-333` rescans abandoned vehicles and chooses a spawn anchor near the wreck cluster.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard_GUER.sqf:349-353` records spawn detail and starts the watcher.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard_GUER.sqf:361-393` moves the team to each surviving abandoned wreck, waits 30 seconds, pays `GuerVbiedBounty`, deletes the wreck, and logs `GUERSCAV_WRECK`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard_GUER.sqf:423` includes the Scavenger Team broadcast text.

## Abandoned-Husk Registry

The G5 path depends on the existing AICOM abandoned-vehicle markers:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:2143-2149` sets `wfbe_aicom_abandoned` on dismounted abandoned hulls and calls `aicom-vehicle-abandoned`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:2180-2188` performs the same once-per-hull enrollment for another abandoned-vehicle path.

That matches the A-Life design note: scavengers are meant to use data the commander already tracks.

## Maintained Copy Check

The same anchors are present in the maintained Chernarus, Takistan, and Zargabad copies:

- `Rsc/Parameters.hpp:643-668` has the G4 shelved note and G5 default-off parameters.
- `Server/Functions/AI_Commander_Wildcard_GUER.sqf:22-29` documents the G4/G5 split.
- `Server/Functions/AI_Commander_Wildcard_GUER.sqf:96-106` removes G4 from the deck and gates G5 by flag plus abandoned wreck count.
- `Server/Functions/AI_Commander_Wildcard_GUER.sqf:317-423` implements the G5 watcher, reward/delete flow, log event, and broadcast label.
- `Common/Functions/Common_RunCommanderTeam.sqf:2143-2188` enrolls abandoned hulls into the registry used by G5.

No mission source change is needed for this status pass, and no LoadoutManager mirror or package artifact is expected.

## Recommended Next Test

If we want to prove the live G5 path, run a controlled server smoke with `WFBE_C_GUER_SCAV` set to `1`, produce at least two `wfbe_aicom_abandoned` vehicles, and watch for:

- `AICOMSTAT|v2|EVENT|GUER|...|GUERWILDCARD_G5|...`.
- `AICOMSTAT|v2|EVENT|GUER|...|GUERSCAV_WRECK|reward=...`.
- `GuerVbiedBounty` client payout.
- Deleted scavenged wrecks.
- Crew cleanup on TTL expiry or team wipe.

Do not use that smoke to reintroduce G4 mortar pits. That remains a separate design decision.
