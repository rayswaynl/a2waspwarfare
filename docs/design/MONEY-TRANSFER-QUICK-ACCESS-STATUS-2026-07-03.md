# Money-Transfer Quick Access Status - 2026-07-03

Scope: fleet lane 162, source audit only. The prompt asks for a quick-access
path to `WFBE_TransferMenu` because opening it through the deeper WF menu/team
menu path is slow for frequent transfers.

## Verdict

Lane 162 is already implemented on `origin/claude/build84-cmdcon36`
(`b1608b096eb4a02d7c213d794e22b8bc59df8df0`) in all maintained roots. No
additional GUI/Menu source change is needed for the prompt as written.

The current player scroll-wheel helper registers two actions:

- the existing blue WF menu action, still routed to `Action_Menu.sqf`;
- a green direct transfer action, routed to `Action_TransferMenu.sqf`.

The direct action opens the same `WFBE_TransferMenu` dialog as the older Team
menu button, so it does not fork transfer behavior or duplicate server calls.

## Source Evidence

- `Client/Functions/Client_AddWFMenuAction.sqf:17` registers the normal WF menu
  scroll action.
- `Client/Functions/Client_AddWFMenuAction.sqf:20-25` stores and refreshes
  `WFBE_TransferMenu_Action`, then adds a direct action using
  `STR_WF_TEAM_TransferButton`, `Client\Action\Action_TransferMenu.sqf`, and
  the condition `_target in [player] && alive player && !(dialog)`.
- `Client/Action/Action_TransferMenu.sqf:4` opens `createDialog
  "WFBE_TransferMenu"`.
- `Client/Functions/Client_PreRespawnHandler.sqf:9` calls
  `WFBE_CL_FNC_AddWFMenuAction`, so the direct action is restored on the new
  player unit after respawn.
- Grep confirms the same direct action exists in Chernarus, generated Takistan,
  and generated Zargabad.

## Follow-Up Notes

No code change is recommended without runtime evidence that the current action
fails to appear. The only small hygiene note is that `Client_OnKilled.sqf`
explicitly removes the stored main WF menu action from the old body, while the
direct transfer action relies on its addAction condition to stay unusable when
the target is not the live player or a dialog is already open. That is not a
lane-162 blocker; it is only worth touching if an action-count or corpse-action
RPT investigation shows stale actions matter.

## Verification

- Brain and GitHub were checked for active/open lane-162 work before this pass.
- Source anchors above were read from `origin/claude/build84-cmdcon36`.
- No mission source, generated mirror, package artifact, live server, or
  LoadoutManager output is changed by this audit.
