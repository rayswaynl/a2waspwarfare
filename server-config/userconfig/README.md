# Server userconfig — ASR AI tuning

This folder holds the version-controlled ASR AI settings used by the WASP Warfare modpack
(`@adwasp` bundles ASR AI 1.16.0.40). ASR AI reads everything from
`ASR_AI/asr_ai_settings.hpp`; the shipped `asr_ai_settings.pbo` only `#include`s it, so this
is a plain-text tune — no PBO repack, no signature change.

## Why this is server-side

ASR AI's behaviour scripts run wherever the AI units are *local*. In this CTI/Warfare mission
that is the **dedicated server and the headless client(s)** — not individual players. Tuning
therefore takes effect from the **server's** copy of this file. Shipping it in the player
modpack zip does almost nothing for server FPS (a player's copy only affects AI in their own
group).

## Current tune — Profile A (Conservative, 2026-06-09)

- `sys_airearming.feature = 1` — left at this install's stock value; rearming stays ON (not part of the tune).
- `sys_aiskill.radiorange = 300` (was 500) — smaller radio-net that shares enemy positions
  between AI groups (the cost that scales worst with group count).
- `sys_aiskill.buildingSearching = 0.5` (was 0.7) — AI clears buildings less often
  (expensive pathfinding).

Untouched on purpose (these help FPS or are init-only): `serverdvd`, `join_loners`,
`setskills`, the skill `sets`/`factions` blocks.

## Deploy

1. Copy `ASR_AI\asr_ai_settings.hpp` to the Arma 2 OA install on the **dedicated server** and
   each **headless client**, at: `<Arma 2 OA>\userconfig\ASR_AI\asr_ai_settings.hpp`.
2. Restart the server / HC.

> Production server host: _TODO — fill in once confirmed._

## Revert

Each install keeps a stock `asr_ai_settings.hpp.bak` beside the live file. To revert, copy the
`.bak` back over `asr_ai_settings.hpp` and restart.
