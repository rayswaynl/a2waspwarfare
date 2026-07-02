# server-config — live server / headless-client configuration (source of truth)

These files are the **live WASP server + headless-client configuration**, captured from the
production box (the live host, `C:\WASP\`) on 2026-07-02. They are versioned here so a
box rebuild, migration, or wipe can restore the exact working setup instead of falling back to
Arma 2 OA defaults.

> **Secrets are redacted.** `server-pr8.cfg`'s `passwordAdmin` is replaced with
> `__REDACTED_SET_ON_BOX__`. The real value lives ONLY on the box — never commit it. Restore it
> by hand on deploy. No other secret fields are present in these files.

## Files

| File | Box path | Purpose |
| --- | --- | --- |
| `basic.cfg` | `C:\WASP\profiles-pr8\basic.cfg` | Network tuning (`-cfg`) |
| `server-pr8.cfg` | `C:\WASP\profiles-pr8\server-pr8.cfg` | Server config (`-config`) — **passwordAdmin redacted** |
| `hc_launch.cmd` | `C:\WASP\hc_launch.cmd` | Headless client 1 launcher |
| `hc2_launch.cmd` | `C:\WASP\hc2_launch.cmd` | Headless client 2 launcher (Sandboxie-isolated 2nd Steam) |

## Why this matters — the load-bearing settings

- **`MaxSizeGuaranteed = 512`** in `basic.cfg` is the fix for the permanent-black
  "Receiving mission" JIP failure (a prior value of 1024 caused JIP message fragmentation). If a
  rebuild reverts this to the engine default, the black-screen-on-join incident returns. This is
  the single most important line to preserve.
- Companion network values: `MaxMsgSend = 512`, `MaxSizeNonguaranteed = 512`,
  `MinBandwidth = 131072`, `MaxBandwidth = 104857600`, `MinErrorToSend = 0.005`,
  `MaxCustomFileSize = 0`.
- **HC launch lines** carry `-mod=...;@CBA_CO;@adwasp;@admkswf` — `@adwasp` bundles ASR AI, which
  is locality-scoped, so AICOM combat teams (100% HC-local) only get ASR AI behavior because the
  HC mod line includes it. Do not drop `@adwasp` from the HC line. CBA must precede `@adwasp`.
- HC allocator: `-malloc=tbb4malloc_bi` (the DLL is present in `…\Arma 2 OA\Dll\`); the dedicated
  server itself runs `-malloc=mimalloc`. Both custom allocators are engaged.
- `headlessClients[] = {"127.0.0.1"}` + `localClient[] = {"127.0.0.1"}` register the two local
  HCs. `verifySignatures = 0` and `BattlEye = 0` are intentional (optional client mods permitted).

## Not versioned here (box-only)

`hc-profile\hc-video.cfg`, the Sandboxie box definition for HC2, Steam credentials, and the
`min*_launch.cmd` variants. The mission PBOs are produced by `Tools/LoadoutManager`, not stored here.
