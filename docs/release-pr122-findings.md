# PR #122 Release Findings

Last updated: 2026-07-01 11:19 Europe/Amsterdam

This document is the running Codex release-captain findings log for the July 2
release pass. It is intentionally documentation-only: no gameplay source,
mission generation output, livehost config, or private credential is included
here.

## Current Verdict

NO-GO as a release claim until exact-build runtime evidence exists.

`origin/master` has advanced to the live command-center/AICOM line at
`311b9d93661f292eeac9337989da44fd9b9ed8f5`. A current-master `SERVER_DEBUG`
mission-folder artifact now exists, but it is still packaging/tooling proof
only. PR #124/r8 remains stale/conflicting by local merge analysis relative to
current master, so its artifacts no longer prove the current master state.
Release-ready wording still needs current Arma 2 OA evidence from the exact
chosen build, covering both Chernarus and Takistan plus server, client, late
join, and headless-client roles.

## Current Anchors

- Repository: `rayswaynl/a2waspwarfare`
- Base branch: `origin/master`
- Current `origin/master` head:
  `311b9d93661f292eeac9337989da44fd9b9ed8f5`
- Original PR #122 base head:
  `bd48a6dbe673ae47a88053dafdf948a29cb8dfe0`
- PR #122 branch: `origin/feat/qol-polish-pack`
- PR/scanner head: `4c66c3b6b1c20321163e732d6d06f5dacaeb4e5a`
- Mission-content head: `f5c41461508e117d13d0b6172cbd66698091a8eb`
- PR #124 r8 integration branch: `origin/release/2026-07-02-stackcheck-r8`
- PR #124 r8 head: `16bfe29eb326303848f6223bc5604b81260ca484`
- Comparison remote `Miksuu/a2waspwarfare`: `b8389e7482438edd00f420c5bb795ac0a642971f`
- Wiki head checked during the release loop:
  `e6a3d50dc309f4a3c3e72a1815cb58059eda8149`

GitHub currently reports PR #124 as open, draft, and `DIRTY`, while local
merge-tree analysis still shows conflict markers after the `origin/master`
command-center merge. The old r8 branch therefore needs conflict repair or
replacement before it can be a current release candidate.

Another draft lane, PR #125, exists for a broader command-center package. It is
open, draft, and currently reported clean at head
`0e2696f1cd831a36594836ccc7a395bd6637a0b4`. Treat it as a separate broad lane,
not as current-master runtime proof.

PR #126 also now exists as an open draft release-readiness/AICOM guardrail lane
at head `5868dc91346c0d9ede6059460a88e8b75c28f762`. GitHub currently reports
clean. It should still be reviewed as a separate focused AICOM/source-doc
candidate before any release artifact target is reset.

## R8 Integration Finding

PR #124, <https://github.com/rayswaynl/a2waspwarfare/pull/124>, is now the
release-stack candidate to evaluate in addition to the PR #122-only path. It
combines:

- PR #109 GUER improvised armor
- PR #120 GUER patrol variety and adaptive air-defense loadout
- latest PR #122
- Takistan regeneration commit `16bfe29e`

Independent Codex validation on 2026-07-01 09:49 found:

- r8 diff over PR #122 is exactly 10 files, all in the GUER armor/air-defense
  surface across Chernarus and Takistan.
- `git diff --check origin/master...HEAD` passes.
- Added-line scans found no watched A2/OA-incompatible tokens:
  `params`, `pushBack`, `isEqualTo`, `isEqualType`, `getPosVisual`,
  `remoteExec`, `BIS_fnc_MP`.
- Added-line scan found no `count` comparison in `&&` / `||` chains.
- The five r8 GUER file pairs hash-identically between Chernarus and Takistan:
  `Root_GUE.sqf`, `Common_CreateVehicle.sqf`, `Common_GuerArmor.sqf`,
  `Init_CommonConstants.sqf`, and `Server_GuerAirDef.sqf`.
- LoadoutManager reaches `CHERNARUS DONE` and `TAKISTAN DONE`, then stops only
  at the known local missing-`7za` packaging boundary.
- Synthetic two-terrain release scanner fixture passes with
  `-RequireServerDebug -RequirePr122Markers -RequireAicomTelemetry
  -RequireHcRegistry -RequireBothTerrains`.

Important risk: r8 still defaults GUER light air defense to `Ka137_MG_PMC`.
That means the ASR / Ka-137 stop-condition concern below still applies to r8
until exact runtime evidence proves it clean or an explicit mitigation is
accepted.

## R8 Exact Artifact

An exact r8 `SERVER_DEBUG` mission-folder artifact now exists for runtime
collection:

- artifact: `outputs/a2waspwarfare-r8-16bfe29e-server-debug-missions.7z`
- r8 source head: `16bfe29eb326303848f6223bc5604b81260ca484`
- SHA256: `4F8EE6A025405F1B777F28DFF20A290942F110E0E511A2D64CF98CA216D6B47A`
- size: `7078199` bytes
- archive test: pass
- extracted top-level folders:
  - `[55-2hc]warfarev2_073v48co.chernarus`
  - `[61-2hc]warfarev2_073v48co.takistan`
- extracted contents: `1692` files, `23363902` bytes
- both extracted `version.sqf` files have `WF_LOG_CONTENT` enabled with
  `WF_DEBUG` commented out

This artifact is not runtime proof. It only gives the release loop an exact r8
payload to launch and collect RPTs from.

## R8 Folder Smoke Kit

A portable r8 folder-smoke kit now exists for collecting runtime proof from the
exact PR #124 payload:

- kit: `outputs/a2waspwarfare-r8-16bfe29e-folder-smoke-kit.7z`
- SHA256: `ADD2F064BEFE31DD8ACE0F47DDA5A18CAA0C2F86E96C1C5153FF962F3C4F8711`
- size: `7107094` bytes
- source artifact SHA256:
  `4F8EE6A025405F1B777F28DFF20A290942F110E0E511A2D64CF98CA216D6B47A`
- archive contents: `165` folders, `1704` files, `23421204` uncompressed bytes
- included mission folders:
  - `MPMissions/[55-2hc]warfarev2_073v48co.chernarus`
  - `MPMissions/[61-2hc]warfarev2_073v48co.takistan`

Validation performed:

- 7-Zip archive integrity test: pass
- all six folder-smoke PowerShell scripts parse successfully
- staging install rehearsal and preflight pass for both missions
- archive extract validation pass
- extracted-kit install rehearsal and preflight pass
- synthetic release-gate scanner rehearsal passes with both terrains,
  server/client/latejoin/hc1/hc2 role names, HC registry markers, AICOM
  telemetry, and zero stop-condition matches
- extracted-kit evidence package validator accepts the final kit SHA with
  `passed = true` and `failed_count = 0`

This kit is still not runtime proof. It is a repeatable packaging and evidence
collection tool for the exact r8 candidate. Final release proof still requires
fresh real Arma 2 OA RPTs and human smoke notes from this exact kit.

## Current Master / r9 Reconciliation

After fresh remote refreshes on 2026-07-01 10:33, 10:48, and 11:04
Europe/Amsterdam:

- `origin/master` is `311b9d93661f292eeac9337989da44fd9b9ed8f5`.
- PR #124/r8 is open draft; GitHub reports `DIRTY`, and local merge-tree
  analysis still shows conflicts.
- PR #125/command-center advanced to
  `0e2696f1cd831a36594836ccc7a395bd6637a0b4` and is now reported clean, but
  remains a separate broad draft lane.
- PR #126/release-readiness exists at
  `5868dc91346c0d9ede6059460a88e8b75c28f762` and is reported clean, but
  remains a separate focused AICOM/source-doc lane.
- The wiki advanced to `e6a3d50dc309f4a3c3e72a1815cb58059eda8149`.

Non-destructive merge analysis found r8 conflicts mirrored across both maps in:

- `Client/Functions/Client_FNC_Special.sqf`
- `Client/Init/Init_Client.sqf`
- `Common/Init/Init_CommonConstants.sqf`
- `Server/Functions/Server_HandleSpecial.sqf`
- `Server/Init/Init_Server.sqf`
- `Server/server_heli_terrain_guard.sqf`

A broad local transplant attempt was rejected because it reverted current
command-center/AICOM constants and vehicle behavior while adding GUER armor. It
was not pushed and should not be used as release evidence.

A narrower local r9 candidate now exists:

- branch: `release/2026-07-02-stackcheck-r9-narrow`
- base: `origin/master` `6cbf6f6a5dc633601be39615fbb2248a8b5a1120`
- local commit: `719379909f8301de28ada3d93f1f1de52ddd5f87`
- scope: 6 files, 224 insertions, 0 deletions
- artifact: `outputs/a2waspwarfare-r9-71937990-server-debug-missions.7z`
- SHA256: `96CD026F76E0828F584F243FEC2358C1D319CDEFAE5E69868B7394C89FC77171`
- size: `7183855` bytes

r9-narrow validation:

- `git diff --check origin/master..HEAD`: pass
- added-line watched-token scan: pass
- added-line `count` boolean-chain scan: pass
- touched Chernarus/Takistan files hash-match
- LoadoutManager reaches `CHERNARUS DONE` and `TAKISTAN DONE`
- archive integrity and extraction pass
- extracted folders are Chernarus and Takistan
- extracted `version.sqf` files have `WF_DEBUG` commented out and
  `WF_LOG_CONTENT` enabled

This r9 artifact is not runtime proof and has not been pushed. It is the current
best local source/artifact candidate from the 10:33 master if GUER improvised
armor is still wanted, but after `origin/master` advanced to `311b9d936` it is
now behind by four commits. If r9-narrow is chosen, rebase/rebuild it on the
current master before using it as a proof target.

## Current Master Exact Artifact

An exact current-master `SERVER_DEBUG` mission-folder artifact now exists:

- source head: `311b9d93661f292eeac9337989da44fd9b9ed8f5`
- artifact: `outputs/a2waspwarfare-master-311b9d93-server-debug-missions.7z`
- SHA256: `789165EE6A434E16E2602A13CA2582334EBE3994E0D59D45D2B128E0CA3186C5`
- size: `7137204` bytes
- manifest: `outputs/a2waspwarfare-master-server-debug-artifact-2026-07-01-1104.md`

Build/validation:

- `dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj -c SERVER_DEBUG`
  exited `0`
- reached `CHERNARUS DONE`
- reached `TAKISTAN DONE`
- `ZipManager` auto-detected `C:\Program Files\7-Zip\7z.exe`
- archive integrity test passed with 160 folders, 1717 files, 24034355
  uncompressed bytes
- extraction produced exactly the Chernarus and Takistan mission folders
- extracted `version.sqf` files have `WF_DEBUG` commented out and
  `WF_LOG_CONTENT` enabled
- generator aftermath in the isolated worktree is the known line-ending/status
  noise only; `git diff --stat`, `git diff --numstat`, and `git diff --check`
  found no real content changes

This artifact supersedes the 10:48 `54d0b8e7` artifact as the freshest exact
current-master payload for proof collection if current `origin/master` is chosen
as the release target. It is still not runtime proof.

## Current Master Folder Smoke Kit

A portable current-master folder-smoke kit now exists for collecting runtime
proof from the exact `311b9d93661f292eeac9337989da44fd9b9ed8f5` master
payload:

- kit: `outputs/a2waspwarfare-master-311b9d93-folder-smoke-kit.7z`
- SHA256: `9CDC5BB7E12C34D58B8AEF2738A0F35F4E8C5E303D4A178BA47E5E9A5FB09E1C`
- size: `7165632` bytes
- source artifact SHA256:
  `789165EE6A434E16E2602A13CA2582334EBE3994E0D59D45D2B128E0CA3186C5`
- manifest:
  `outputs/a2waspwarfare-master-folder-smoke-kit-manifest-2026-07-01-1119.md`

Validation performed:

- 7-Zip archive integrity test: pass
- extracted archive structure and file count: pass
- all six folder-smoke PowerShell scripts parse successfully
- extracted-kit install rehearsal and preflight pass for both missions
- smoke evidence template generation pass
- synthetic release-gate scanner/package rehearsal passes with both terrains,
  server/client/latejoin/hc1/hc2 role names, AICOM telemetry, HC registry
  markers, content logging markers, zero stop-condition matches, and
  `failed_count = 0`

This kit is still not runtime proof. It is the current best portable collection
path if `origin/master` is selected as the proof target.

## Evidence Already Strong

- The real AICOM implementation for this release path lives in current
  `rayswaynl/a2waspwarfare` PR #122 mission files, not old Miksuu master.
- Chernarus remains the source mission and Takistan is generated from it.
- Checked AICOM/HC files match between maintained Chernarus and generated
  Takistan in the current PR #122 release slice.
- LoadoutManager reaches `CHERNARUS DONE` and `TAKISTAN DONE` for the PR #122
  mission-content head.
- The release scanner has gates for server debug/content logging, PR #122 guard
  markers, both terrain windows, HC registry proof, and stronger AICOM
  telemetry.
- The exact mission-folder artifact and portable folder-smoke kit were built
  locally during the release loop and hash-checked:
  - mission artifact SHA256:
    `CB67EC13696FC97C9C497884B7808A79D02422B79F6A82D23BA81E18EE65ED49`
  - folder-smoke kit SHA256:
    `1F1588001C69BDE3514C53A23E91E30C455846E41BFF39CDE720892C19B41E93`
- Wiki wording has been kept runtime-pending rather than calling PR #122
  release-ready without RPT evidence.

## Main Runtime Gaps

The release still needs exact-build evidence for:

- Chernarus server RPT
- Takistan server RPT
- hosted/client RPT
- late-join client RPT
- HC1 RPT
- HC2 RPT, unless the topology is explicitly changed and documented
- scanner PASS with:
  - `-RequireServerDebug`
  - `-RequirePr122Markers`
  - `-RequireAicomTelemetry`
  - `-RequireHcRegistry`
  - `-RequireBothTerrains`
- human smoke notes for factory slope behavior, JIP flags, corpse guard, TAGS
  toggle, JIP/deadspawn guards, HC registry behavior, AICOM team founding, and
  Takistan flow.

Current livehost RPTs are useful baseline health evidence only. They are not
proof of PR #122 because they are not tied to the exact mission-content artifact
and do not satisfy the release scanner gates.

## Livehost Findings

Read-only probes found the active livehost config shape still using
`cmdcon30aicom` mission template names:

- active Chernarus resolves to a same-name live PBO
- active Takistan does not resolve to a same-name PBO or folder in active
  `MPMissions`
- a parked Takistan candidate exists outside active `MPMissions`, but it is not
  active release proof

No livehost writes, deploys, config edits, or restarts were performed by Codex
during this findings pass.

## ASR / Ka-137 Stop-Condition Finding

The newest baseline Chernarus server RPT showed 10 release-gating
stop-condition matches. Follow-up triage connected the visible failing
expression/error-position pairs to the external ASR AI fired/gunshot-hearing
handler:

- external path: `x\asr_ai\addons\sys_aiskill\fnc_fired.sqf`
- error shape includes `nearEntities [["CAManBase","StaticWeapon"], ...]`
- error text includes `Bad conversion: array` and
  `Error 0 elements provided, 3 expected`
- the failure window correlates with GUER `Ka137_MG_PMC` air-defense activity

The current PR #122 mission content still defaults GUER light air defense to
`Ka137_MG_PMC`. A mission-local ASR mitigation candidate was validated in an
isolated disposable worktree only:

```sqf
class asr_ai {
	class sys_aiskill {
		gunshothearing = 0;
	};
};
```

That candidate touched only the two maintained `description.ext` files and
regenerated through Chernarus/Takistan validation. It has not been applied to
PR #122, has not been pushed, and is not runtime-proven. Accepting it would
invalidate the current artifacts and require a fresh rebuild plus exact-build
ASR-enabled RPT proof.

## Recommended Next Path

1. Decide whether the release proof target is current `origin/master` as-is,
   PR #126 after review/integration, old r8/PR #124 after conflict repair, or
   local r9-narrow.
2. Do not use old PR #122 or r8 artifacts to prove current `origin/master`.
3. If current `origin/master` is chosen, use artifact SHA256
   `789165EE6A434E16E2602A13CA2582334EBE3994E0D59D45D2B128E0CA3186C5` and
   folder-smoke kit SHA256
   `9CDC5BB7E12C34D58B8AEF2738A0F35F4E8C5E303D4A178BA47E5E9A5FB09E1C`.
4. If r9-narrow is chosen, first rebase/rebuild it on current `origin/master`,
   then push/open or update a source PR and publish a fresh artifact/hash. The
   older r9 artifact SHA256
   `96CD026F76E0828F584F243FEC2358C1D319CDEFAE5E69868B7394C89FC77171` no longer
   proves the latest master.
5. Run the exact chosen artifact through folder-smoke or a controlled dedicated
   proof environment with content logging enabled.
6. Collect both-map server/client/latejoin/HC evidence.
7. Run the release scanner with all required gates.
8. Attach human smoke notes.
9. Only then update release notes/wiki wording from runtime-pending to
   release-proven.

If the ASR/Ka-137 stop-condition errors recur on the exact proof runtime,
choose one explicit mitigation path:

- keep current artifact and prove on a non-failing ASR-compatible stack
- apply the narrow mission-local ASR `gunshothearing = 0` override and rebuild
- make GUER Ka-137 air defense opt-in/off and rebuild
- approve an ASR userconfig/addon-side fix outside this mission PR

Every source-changing mitigation resets the artifact hashes and evidence clock.
