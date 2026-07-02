# Music Framework Plumbing

Fleet lane 51 adds default-off `playMusic` hooks for a future WASP soundtrack. It does not add audio binaries and does not change live behavior while `WFBE_C_MUSIC_ENABLE` remains `0`.

## Runtime Hooks

- Match start: `Client/Init/Init_Client.sqf` plays `WFBE_C_MUSIC_MATCH_START_TRACK` after client init reaches the existing old intro hook slot.
- Town capture: `Client/PVFunctions/TownCaptured.sqf` plays `WFBE_C_MUSIC_TOWN_CAPTURE_TRACK` for clients already receiving the town flip message, cooldowned by `WFBE_C_MUSIC_TOWN_CAPTURE_COOLDOWN`.
- Victory: `Client/Client_EndGame.sqf` plays `WFBE_C_MUSIC_VICTORY_TRACK` when the framework is enabled, otherwise it keeps the existing `wf_outro` fallback.

All hooks are client-local. No server loop, HC, AI, or stats path is touched.

## Track Classes

`Music/description.ext` registers these future `CfgMusic` classes:

| Class | Expected file |
| --- | --- |
| `wf_music_match_start` | `Music/wasp_match_start.ogg` |
| `wf_music_town_capture` | `Music/wasp_town_capture.ogg` |
| `wf_music_victory` | `Music/wasp_victory.ogg` |

The repo currently ships only the legacy `wf_outro` audio. Leave `WFBE_C_MUSIC_ENABLE=0` until the expected files are present in both maintained mission roots.

## Notes

- Use `CfgMusic` plus `playMusic` for soundtrack tracks. Do not route this through `CfgSounds` just to chase volume: A2 OA `playSound` volume is not reliably quieted by description.ext volume values in the way this lane needs.
- Keep the files mission-relative under `Music/` so LoadoutManager mirrors them to Takistan.
- Do not enable the framework in the same PR that adds plumbing. Audio choice, length, and live enablement are owner calls.
