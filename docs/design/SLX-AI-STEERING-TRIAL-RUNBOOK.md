# SLX AI Steering Isolated-PBO Trial Runbook

Doc-only runbook for fleet lane 32. This does not install anything, change the live box, or change mission behavior.

## Decision Gate

Run this trial only after `docs/design/AI-MODS-AND-PATHFINDING.md` Action 0 is answered:

1. Read `C:\WASP\hc_launch.cmd` on the box.
2. Confirm whether both HCs load the same AI stack as the server: `@CBA_CO;@adwasp;@admkswf`.
3. If the HCs do not load `@adwasp`, fix that first and soak ASR-on-HC alone. Do not add SLX steering until the existing shipped AI mod is proven to reach HC-local AICOM teams.

## Why This One PBO

`SLX_AI_Steering` is the only mined A2-era AI component with a direct aircraft/vehicle handling claim: better driving/piloting with less crashing. It is also only an author claim, not controlled evidence.

Trial only the isolated steering PBO. Do not trial the full SLX/COSLX bundle: the mined analysis rejects the bundle because its group-link/tasking pieces can fight the commander driver, and community reports in the source doc say the bundle can harm helicopters/UAVs.

## Source Package

Authoritative provenance from `docs/design/AI-MODS-AND-PATHFINDING.md`:

- bIdentify entry: `/file/d44655a4-9538-4429-abe0-12be799e04bd`
- Archive name: `COSLX_Patch_v2.6.zip`
- Author: Gunter Severloh
- Date: 2013-09-19
- Note: listed as a patch and may require COSLX base plus patch #1 to recover the final file set.

Expected extracted payload:

- `slx_ai_steering.pbo`
- `slx_ai_steering.pbo.*.bisign`, if present

Hard allowlist: copy only those files. Do not copy `slx_gl3`, wounds, ragdoll, aircraft crash FX, group-link, suppression, or any other `slx_*.pbo`.

## Staging

Use a scratch folder first, never extract directly into the live mod chain.

```powershell
New-Item -ItemType Directory -Force C:\WASP\mod-staging\slx_steer | Out-Null
New-Item -ItemType Directory -Force C:\WASP\mods\@slx_steer\addons | Out-Null

& 'C:\Program Files\7-Zip\7z.exe' x C:\WASP\mod-staging\COSLX_Patch_v2.6.zip -oC:\WASP\mod-staging\slx_steer\patch2

Get-ChildItem C:\WASP\mod-staging\slx_steer -Recurse -Filter slx_ai_steering.pbo
Get-ChildItem C:\WASP\mod-staging\slx_steer -Recurse -Filter 'slx_ai_steering.pbo*.bisign'
```

If the steering PBO is not present in patch #2, extract the required COSLX base and patch #1 archives into separate scratch folders, then repeat the same `Get-ChildItem` checks. Use the newest `slx_ai_steering.pbo` by file timestamp among base, patch #1, and patch #2.

Copy only the allowlisted files:

```powershell
$steer = Get-ChildItem C:\WASP\mod-staging\slx_steer -Recurse -Filter slx_ai_steering.pbo |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if ($null -eq $steer) { throw 'slx_ai_steering.pbo not found in staged COSLX files' }

Copy-Item -LiteralPath $steer.FullName -Destination C:\WASP\mods\@slx_steer\addons\

Get-ChildItem -LiteralPath $steer.DirectoryName -Filter 'slx_ai_steering.pbo*.bisign' |
  ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination C:\WASP\mods\@slx_steer\addons\
  }

Get-ChildItem C:\WASP\mods\@slx_steer\addons
```

The final folder must contain no other PBOs.

## Install Lines

The live server currently uses one `-mod` chain, not `-serverMod`:

```text
"-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;@CBA_CO;@adwasp;@admkswf"
```

For the trial, append `@slx_steer` to the server mod chain:

```text
"-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;@CBA_CO;@adwasp;@admkswf;C:\WASP\mods\@slx_steer"
```

If a future launch line has both `-mod` and `-serverMod`, prefer `-serverMod=C:\WASP\mods\@slx_steer` for the dedicated server process and keep the normal content chain unchanged.

Headless clients must also load it because AICOM aircraft and vehicles are HC-local. Edit `C:\WASP\hc_launch.cmd` so both scheduled tasks (`MiksuuHC` and `MiksuuHC2`) launch with the same steering addon:

```text
-mod="C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;@CBA_CO;@adwasp;@admkswf;C:\WASP\mods\@slx_steer"
```

Keep `@CBA_CO` before `@adwasp`/`@admkswf` if those remain on the HC line. `SLX_AI_Steering` has no CBA dependency, but the existing WASP/ASR stack still needs the established order.

## Signature Posture

The current box is `verifySignatures=0`, `equalModRequired` absent, and BattlEye off. No key work is required for this trial.

If the box later moves to signature enforcement, install the matching SLX/COSLX `.bikey` and keep `equalModRequired` off. Do not use signature hardening as part of this trial; it would confound the aircraft result.

## Restart

Maintenance window sequence:

1. Stop `MiksuuHC` and `MiksuuHC2`.
2. Restart the `Arma2OA-PR8` server service.
3. Start `MiksuuHC`.
4. Start `MiksuuHC2`.
5. Confirm the RPT shows `@slx_steer` in the server expansion list and in both HC client startup logs.

Do not deploy a mission PBO for this trial. The mission code stays unchanged.

## Soak Plan

Run one AI-vs-AI match with the same mission build and comparable server conditions as the most recent pre-trial baseline.

Collect:

- Server RPT.
- Both HC RPTs.
- Existing match report output.
- Any soak analyzer output already used for Build 86 comparison.

Compare against the previous no-SLX baseline:

- AICOM aircraft founded, alive, destroyed, and refunded counts.
- Transport-heli insert starts vs successful unloads.
- Attack-heli terrain/impact crashes from RPT evidence.
- Fixed-wing crash/impact/despawn/refund evidence.
- AICOM team arrival rate and median dispatch to first objective contact.
- Recovery/unstuck noise: `UNSTUCK`, `ASSAULT_STRANDED`, abandoned hull, and forced recovery counts.
- Server FPS and HC FPS over match time.
- Script errors, unknown addon/class errors, missing signature/key noise, and any new RPT spam.

Keep the PBO only if there is a measured crash-rate or arrival-rate improvement without new RPT errors, FPS regression, or commander-driver tug-of-war symptoms.

Remove it if one full soak shows no aircraft benefit, if helicopters/UAVs get worse, if AI teams stop obeying commander orders, or if HC/server RPTs gain new errors.

## Rollback

Rollback is clean because the trial uses one isolated addon folder.

1. Stop `MiksuuHC` and `MiksuuHC2`.
2. Remove `C:\WASP\mods\@slx_steer` from the server launch line.
3. Remove `C:\WASP\mods\@slx_steer` from `C:\WASP\hc_launch.cmd`.
4. Restart `Arma2OA-PR8`.
5. Start both HC tasks.
6. Leave `C:\WASP\mods\@slx_steer` on disk only as disabled staging, or move it back under `C:\WASP\mod-staging`.

Post-rollback proof:

- Server and HC RPT startup lines no longer list `@slx_steer`.
- A short AI-vs-AI smoke reaches AICOM team founding with no missing addon errors.

## Non-Goals

- No full SLX/COSLX bundle.
- No GL3/group-link/tasking PBOs.
- No mission source changes.
- No signature-policy change.
- No live install from this PR.
- No claim that SLX steering is effective until a controlled soak proves it.
