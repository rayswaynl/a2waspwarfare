# Quartermaster Refit No-Change Evidence

Lane: 225

## Prompt Claim

The lane asks for a `QuartermasterRefit` stringtable key because the AI commander
top-up path sends `LocalizeMessage "QuartermasterRefit"` to a seated human
commander.

## Current Source Shape

The current maintained roots already treat `QuartermasterRefit` as a
passthrough message selector, not as a stringtable localization key:

- `Client/PVFunctions/LocalizeMessage.sqf` has:
  `case "QuartermasterRefit": {_txt = _this select 1; _commandChat = true;};`
- `Server/AI/Commander/AI_Commander_Produce.sqf` sends the selector with an
  already formatted message:
  `["QuartermasterRefit", Format ["Quartermaster: -%1 refit %2 (%3 men)", ...]]`

This shape is present in Chernarus, Takistan, and Zargabad.

## Verdict

No stringtable edit is needed. Adding a `QuartermasterRefit` key to
`stringtable.xml` would not be read by the current code path because the client
does not call `localize` for this selector. The selector is only used to route a
server-built command-chat line to the target commander UID.

## Validation

- `rg -n "QuartermasterRefit" Missions/[55-2hc]warfarev2_073v48co.chernarus Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad -S`
- Confirmed no `QuartermasterRefit` stringtable key exists, and that absence is
  intentional for the passthrough selector path.
- No mission source edits, no mirror run, no package artifact, and no deploy
  action.
