# SPEC-BOX-RUNBOOK

Status: SPEC-READY. This is a docs-only consolidation. No deploy or box script was changed.

Guide rev for downstream PR bodies: GR-2026-07-03a.

## Scope

This runbook defines the box facts and deploy-claim protocol a later docs PR can add to AGENTS.md. It intentionally does not modify deploy scripts, scheduled tasks, mission PBOs, or live runtime settings.

## Box Topology

| Component | Current source of truth | Notes |
| --- | --- | --- |
| Live host | Hetzner Windows box | Public address in existing docs: `78.46.107.142`. |
| Server config root | `C:\WASP\profiles-pr8\` | Captured in `server-config/`. |
| Server network config | `basic.cfg` | `MaxSizeGuaranteed=512` is load-bearing for JIP. |
| Server cfg | `server-pr8.cfg` | `passwordAdmin` redacted in repo. |
| HC1 launch | `C:\WASP\hc_launch.cmd` | Contains `@CBA_CO;@adwasp;@admkswf`. |
| HC2 launch | `C:\WASP\hc2_launch.cmd` | Sandboxie-isolated second Steam. |
| Server allocator | `mimalloc` | Do not change during soak prep. |
| HC allocator | `tbb4malloc_bi` | DLL present in Arma 2 OA DLL folder. |
| RPT archive | Box-side / operator archive | Pull read-only; never truncate. |

## Critical Settings

From `server-config/README.md`:

- `MaxSizeGuaranteed = 512` prevents the permanent black "Receiving mission" JIP failure caused by 1024-byte guaranteed-message fragmentation.
- `MaxMsgSend = 512`, `MaxSizeNonguaranteed = 512`, `MinBandwidth = 131072`, `MaxBandwidth = 104857600`, `MinErrorToSend = 0.005`, `MaxCustomFileSize = 0`.
- `headlessClients[] = {"127.0.0.1"}` and `localClient[] = {"127.0.0.1"}` register local HCs.
- `@adwasp` must remain on both HC lines because AICOM combat teams are HC-local and only receive ASR AI behavior where the addon is loaded.
- `verifySignatures = 0` and `BattlEye = 0` are intentional for this deployment.

## Deploy Script Inventory

The sandbox did not expose `deploy44*.ps1` or `pbotool.py` in this worktree. Treat those as box-side/operator artifacts unless the orchestrator supplies them.

| Script | Status | Runbook treatment |
| --- | --- | --- |
| `deploy44f.ps1` | Reference from Agent-Worklog/roster only | Use as the deploy-candidate stamp producer model. Do not edit in prep PR. |
| `deploy44*.ps1` | Expected existing family | Future builder should inventory on the Game PC, not infer from repo. |
| `pbotool.py` | Referenced as template | Use only as packaging reference. Do not replace LoadoutManager flow. |
| `WaspMatchEndRotate` | Existing scheduled/live chain | Known dual-PBO ambiguity caveat; keep separate from soak farm. |
| `WaspMatchReport` | Not installed as of GR-2026-07-03a | Match-report docs say manual trigger only. |
| `WaspNightlySoakFarm` | Planned | New scheduled task from `SPEC-SOAK-FARM-NIGHTLY.md`. |

## PBO Pack Flow

Canonical build flow remains repo-side:

1. Edit Chernarus source only for SQF work.
2. Run `Tools\LoadoutManager` to mirror maintained terrains.
3. Restore TK/ZG `version.sqf.template` if generator drifted them.
4. Package candidate PBOs.
5. Operator copies exactly one active candidate PBO per terrain to `MPMissions`.
6. Operator or deploy script writes `.deploy-stamp.json`.

The soak farm starts only after step 6.

## Version Verify Snippet

Use marker sweep rather than raw RPT dumping:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\Monitor\Get-WaspRptMarkerSweep.ps1 `
  -RptDirectory C:\WASP\rpt-archive `
  -Latest 8 `
  -ExpectedCandidate cmdcon44f `
  -ExpectedGit <git> `
  -ExpectedTerrain zargabad `
  -RequireReleaseMarkers `
  -Json
```

When candidate git is unknown, require candidate and terrain markers and record `git=null` in the ledger.

## RPT Archive Procedure

1. Pull server RPT and HC RPT read-only with SCP.
2. Copy into `C:\Users\Game\a2waspwarfare-soak\rpt\<stampId>\`.
3. Compute SHA256 for copied files.
4. Run analyzer against the copies.
5. Keep the copied files until the ledger row and Discord verdict are posted.
6. Never delete, truncate, move, rotate, or compress the live RPT from the soak farm.

## AGENTS.md-Ready DEPLOY-CLAIM Protocol

Add this section under Claim protocol in a docs-only PR:

```markdown
## DEPLOY-CLAIM Protocol

Live-box deploy or soak ownership requires an explicit deploy claim before any operator action.

1. Create a visible worklog heading exactly named `DEPLOY-CLAIM: <candidate> <terrain> <purpose>` before copying, rotating, restarting, or scheduling any live-box action.
2. Include claimant, UTC timestamp, candidate/PBO name, terrain, expected duration, rollback path, and whether the action may affect players.
3. While a deploy claim is active, other agents must not touch deploy scripts, scheduled tasks, `MPMissions`, live RPT rotation, server config, HC launchers, or soak-farm stamp files unless the claim owner explicitly hands off.
4. Release the claim with a heading exactly named `DEPLOY-CLAIM RELEASED: <candidate> <terrain>` and summarize final state, active PBO count, server/HC process count, RPT marker verdict, and any follow-up.
5. If the claimant is unreachable and the box is player-impacting, owner/operator may break the claim; record `DEPLOY-CLAIM BROKEN:` with the reason and observed box state before taking over.
```

## Five Operating Rules

1. One deploy claim at a time per live box.
2. Soak farm is a reader, not a deployer.
3. Scheduled tasks are registered by the operator, not by autonomous agents.
4. Box config changes require explicit owner sign-off.
5. A PR body that changes deploy policy cites GUIDE-REV `GR-2026-07-03a`.

## AGENTS.md Addition Checklist

Future docs PR:

- Add only the `DEPLOY-CLAIM Protocol` section and a short soak-farm awareness sentence.
- Do not rewrite existing owner constraints.
- Do not weaken "Never deploy to the live server".
- Cite GUIDE-REV `GR-2026-07-03a` in the PR body.
- Verify AGENTS.md and CLAUDE.md stay identical if the repo expects them to mirror.

