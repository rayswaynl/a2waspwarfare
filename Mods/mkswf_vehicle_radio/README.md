# @mkswf_vehicle_radio — WASP Vehicle Radio (audio addon)

Ships the music for the in-vehicle radio feature. The audio lives **here, in the modpack
addon — not in the mission PBO** — so it adds ~0 to the mission's JIP ("Receiving mission")
transfer. Players already download the modpack, so there's no extra friction.

## What's in here
- `config.cpp` → includes `CfgPatches` + `CfgMusic` + `CfgSounds`
- `CfgMusic.hpp` → 6 stations (`mkswf_radio_1`..`6`) used by 2D `playMusic` (the default mode)
- `CfgSounds.hpp` → the same 6 tracks, also declared for the reserved 3D `say3D` mode
- `sounds/radio_1.ogg`..`radio_6.ogg` → **PLACEHOLDERS** (~2s silence). Replace with real tracks.
- `$PBOPREFIX$.txt` → sets the PBO logical path to `mkswf_vehicle_radio`

## Adding the music (your job)
1. Drop your finished tracks into `sounds/` as `radio_1.ogg` … `radio_6.ogg`
   (OGG Vorbis; mono + ~64–96 kbps is plenty for a vehicle radio and keeps the modpack small).
   You can use fewer than 6 — just trim the playlist (next step) to match.
2. In the mission, edit `WASP\Radio\Radio_Config.sqf`:
   - `WASP_RADIO_PLAYLIST` → the station class names you're using (default = all 6).
   - `WASP_RADIO_DUR` → the **real length in seconds** of each track, in the same order.
     (playMusic has no end-event, so the manager advances the playlist by these durations.)

## Packing + distributing
There is no PBO build pipeline in this repo (addons are kept as loose source). To ship:
1. Pack this folder into `mkswf_vehicle_radio.pbo` with a tool that honours `$PBOPREFIX$`
   (Mikero `makepbo`/`pboProject`, or BI Addon Builder).
2. Place it at `@mkswf_vehicle_radio\addons\mkswf_vehicle_radio.pbo` and add that to the
   **Google Drive modpack zip** the miksuu.com guide links to (and to the server `-mod=` line).

## How the mission uses it
The mission adds **Radio: On / Off / Next station** actions to every vehicle (occupant-only),
client-side, in `Common\Init\Init_Unit.sqf`. A single per-client loop (`WASP\Radio\Radio_Manager.sqf`)
plays the current station via `playMusic`. If this addon isn't loaded, the mission detects the
missing `CfgMusic` class and silently skips — no errors.

To disable the whole feature: set `WASP_RADIO_MODE = 0` (in `WASP\Radio\Radio_Config.sqf`).
