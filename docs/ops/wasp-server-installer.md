# WASP Server Installer — design notes

## Goal

One easy, **config-driven** installer for the Miksuu MAIN Arma 2 OA WASP server so the owner can set:

- feature flags (meaningful WFBE set + plain language)
- HC count (server.cfg + launchers + firewall helper)
- telemetry mode (`on` / `off` / `stats-only`)
- rules / MOTD
- standing basics: **Veteran locked**, BE default off, mission template, ports, names; secrets prompted at Apply

…without inventing a fifth unrelated installer stack.

## Reconciliation map

```
wasp-server.json
       │
       ▼
Tools/WaspServerInstaller  ──render──►  installRoot/{profiles,launchers,flag-plan,basic.cfg.v1}
       │                                      │
       │                                      ├─► Deploy-Wasp.ps1     (mission PBO lifecycle)
       │                                      └─► HetznerInstaller    (PR #1102 fence/transaction)
       │
       └─► uses evidence from server-config/*, Set-WaspCpuAffinity.ps1, wiki perf pages, hosting corpus
```

| Existing | Role retained |
| --- | --- |
| PR #1102 `Tools/HetznerInstaller` | Transactional fenced Apply/Verify/Rollback; adapter-gated |
| `Tools/Ops/Deploy-Wasp.ps1` | Build/mirror/pack/repoint/restart/verify mission |
| `server-config/*` + PR #1081 | Proven basic.cfg / server.cfg baseline bytes |
| `Tools/Ops/Set-WaspCpuAffinity.ps1` | Post-boot affinity apply pattern |

This package **renders and stages config**. It does not replace Deploy-Wasp mission deploy or Hetzner transaction fencing.

## Flag layers

1. **lobby** — `Rsc/Parameters.hpp` `default=` wins at mission start.  
2. **script** — `Init_CommonConstants.sqf` `isNil` / assignments when not lobby-backed.

Installer always labels the layer in `flag-plan.json`. See ADMIN-INSTALL.md.

## Safety

- DryRun default for inspection; Apply only with explicit action.
- Refuses `C:\WASP\...` shaped roots unless `WASP_INSTALLER_ALLOW_LIVE_SHAPED=1`.
- `Save-WsiConfig` strips password fields.
- difficulty coerced/locked to Veteran.

## Test

`Tools/WaspServerInstaller/WaspServerInstaller.Tests.ps1` — scratch apply + diff + affinity disjointness + telemetry mapping + live-path refuse.
