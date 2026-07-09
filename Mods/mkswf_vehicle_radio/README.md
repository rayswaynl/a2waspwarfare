# @mkswf_vehicle_radio — WASP Vehicle Radio (streaming addon)

Ships the client-side pieces for the in-vehicle radio feature: a native `callExtension` DLL
that streams internet radio (music.miksuu.com) straight into the player's own speakers via
[BASS](https://www.un4seen.com/), plus the tiny addon PBO that declares the mod itself.
**No music files ship in this addon or the mission PBO** — audio is fetched live from the
stream, so this costs ~0 against both the modpack size and the mission's JIP transfer.

This replaces the earlier `CfgMusic`/`playMusic` version of this addon (see git history if you
need the old bundled-.ogg approach) — that design was rejected because bundling even a handful
of tracks would have added 50-150MB+ permanently to the modpack, which the owner explicitly
didn't want.

## What's in here
- `config.cpp` / `CfgPatches.hpp` → the addon's PBO identity (`Mkswf_VehicleRadio`). No
  `CfgMusic`/`CfgSounds` classes anymore — there is nothing left for the engine's own config
  tree to declare; playback happens entirely through the extension below.
- `a2waspwarfare_Extension.dll` → the client build of this repo's own extension
  (`Extension/`, see `Extension/src/BaseExtensionClass/Implementations/RADIO.cs`), same
  `_RVExtension@12` ABI the server already uses for `GLOBALGAMESTATS` — this is just a second,
  client-side copy of the same assembly, dispatching on the `RADIO` command instead.
  `ManagedBass.dll` / `Newtonsoft.Json.dll` are its managed dependencies.
- `bass.dll` → the native BASS audio engine (Un4seen Developments) the extension P/Invokes
  into for the actual MP3 stream decode/playback. Free for non-commercial use — see
  `bass-LICENSE.txt`. Get a one-line registration/confirmation from un4seen before a public
  release; not required for testing.
- `$PBOPREFIX$.txt` → sets the PBO logical path to `mkswf_vehicle_radio` (still needed for the
  now much smaller `CfgPatches`-only PBO).

## Where each piece installs (important — two different locations)

1. **The PBO** (`config.cpp` + `CfgPatches.hpp`, packed as `mkswf_vehicle_radio.pbo`) installs
   the normal addon way: `@mkswf_vehicle_radio\addons\mkswf_vehicle_radio.pbo`, same as before.
2. **`a2waspwarfare_Extension.dll` + `ManagedBass.dll` + `Newtonsoft.Json.dll` + `bass.dll`**
   are loose native/managed files, not PBO content — BIS's `callExtension` loads them via the
   OS's own DLL search, not the engine's virtual file system, so they most likely need to sit
   directly in the Arma 2 OA install root (next to `arma2oa.exe`), not inside `@mkswf_vehicle_radio\`.
   **Open test-plan item**: confirm in-game whether `callExtension` can also resolve them from
   inside an active `-mod=` addon folder — if so, step 2 simplifies to "same folder as the PBO."
   Until that's confirmed on a box smoke, ship install instructions for the root-folder path.

## Packing + distributing
There is no PBO build pipeline in this repo (addons are kept as loose source). To ship:
1. Pack `config.cpp` + `CfgPatches.hpp` (+ `$PBOPREFIX$.txt`) into `mkswf_vehicle_radio.pbo`
   with a tool that honours `$PBOPREFIX$` (Mikero `makepbo`/`pboProject`, or BI Addon Builder).
2. Place the PBO at `@mkswf_vehicle_radio\addons\mkswf_vehicle_radio.pbo`, and the 4 loose
   extension files per the install location above, then add both to the **Google Drive modpack
   zip** the miksuu.com guide links to (and to the server `-mod=` line for the PBO half — the
   extension DLL is client-only, the dedicated server doesn't need it).
3. Release notes should say plainly that this adds internet radio streaming and requires
   outbound internet access from the player's own PC to `music.miksuu.com` — see the design
   doc's trust/AV-friction notes before a public rollout (unsigned DLL, first client-side
   extension this project has ever shipped).

## How the mission uses it
The mission adds a single **Radio** action to every vehicle (occupant-only), client-side, in
`Common\Init\Init_Unit.sqf`, opening a station/volume/off sub-menu (`WASP\Radio\Radio_Menu.sqf`).
A single per-client loop (`WASP\Radio\Radio_Manager.sqf`) calls
`"a2waspwarfare_Extension" callExtension "RADIO,PLAY,<url>"` / `"RADIO,STOP"` for the selected
vehicle's station (`WASP\Radio\Radio_Config.sqf`'s `WASP_RADIO_STATIONS`); volume maps to
`"RADIO,VOLUME,<0-100>"`. If the extension DLL isn't present/loadable, `callExtension` just
returns an empty string — the mission fails closed (no sound, no error, no RPT spam), same as
the old "addon not loaded" behaviour.

To disable the whole feature: set `WASP_RADIO_MODE = 0` (in `WASP\Radio\Radio_Config.sqf`), or
via the existing Radio Tower buildable / `WFBE_C_STRUCTURES_RADIOTOWER` lobby toggle, unchanged
from before.
