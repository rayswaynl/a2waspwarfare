# UI HUD And Dialogs

This page is a navigation alias. The current canonical UI docs are:

- [Client UI, HUD and menus](Client-UI-HUD-And-Menus) for the quick-reference gateway.
- [Player UI workflow map](Player-UI-Workflow-Map) for the player-clickable workflow tour.
- [Client UI systems atlas](Client-UI-Systems-Atlas) for the source-backed dialog, title, HUD, marker and controller map.
- [UI IDD collision repair](UI-IDD-Collision-Repair) for duplicate dialog/title IDDs and display-handle cleanup.

Use those pages instead of adding new UI findings here. This alias exists so humans and agents who search for "UI HUD and dialogs" land on the maintained UI documentation instead of relying on the sidebar.

## Current UI Cautions

- Live upgrades use `WFBE_UpgradeMenu` and `Client/GUI/GUI_UpgradeMenu.sqf`; the older `RscMenu_Upgrade` path is stale and points at missing `Client/GUI/GUI_Menu_Upgrade.sqf`. Use [Abandoned feature revival](Abandoned-Feature-Revival-Review#old-upgrade-dialog-review) before deleting or replacing it.
- `RscMenu_EASA` and `RscMenu_Economy` both use `idd = 23000`; `RscOverlay` and `OptionsAvailable` both use `idd = 10200`. Use [UI IDD collision repair](UI-IDD-Collision-Repair) before adding `findDisplay`-based UI automation.
- `RscClickableText.soundPush[]` is malformed in `Rsc/Ressources.hpp:556` (`{, 0.2, 1}`); the valid empty-sound pattern is `{"", 0.2, 1}` at `Ressources.hpp:92`. Use [Client UI systems atlas](Client-UI-Systems-Atlas#known-ui-risks-and-partial-work) before deriving new clickable controls.
- Gear template helpers live under `Client/Functions`, not `Client/GUI`.

## Continue Reading

Next: [Client UI, HUD and menus](Client-UI-HUD-And-Menus)

Related: [Feature status](Feature-Status-Register) | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) | [Testing workflow](Testing-Debugging-And-Release-Workflow)
