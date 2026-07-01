# Running Release Findings

Last updated: 2026-07-01 20:09 Europe/Amsterdam

This document is the running Codex release-captain findings log for the July 2
release pass. It is intentionally documentation-only: no gameplay source,
mission generation output, livehost config, or private credential is included
here.

## Current Verdict

NO-GO as a release claim. The newest `origin/master` package builds and
extracts, but the latest source delta currently fails the static whitespace
gate before runtime proof is even considered.

`origin/master` has advanced to
`b4a6350ca0f90c9b0316570473c05a5e790aea96`, the merge commit for PR #132
Build 83/cmdcon35. The merge itself is clean when checked from `7fd310c63`, and
the deleted root docs were not reintroduced in final master. However, latest
master still inherits the cmdcon33/cmdcon34 placement-preview whitespace/static
blocker when checked from the broader `5bf5f92385` range in both Chernarus and
Takistan `Client/Init/Init_Client.sqf`. The older `7fd310c63`, `b7241a35`,
`5bf5f923`, `311b9d93`, PR #127-only, r9, r8, PR #122, and PR #131 artifacts no
longer prove the current master state.
Release-ready wording still needs current Arma 2 OA evidence from the exact
chosen build, covering both Chernarus and Takistan plus server, client, late
join, and headless-client roles.

## Current Anchors

- Repository: `rayswaynl/a2waspwarfare`
- Base branch: `origin/master`
- Current `origin/master` head:
  `b4a6350ca0f90c9b0316570473c05a5e790aea96`
- Original PR #122 base head:
  `bd48a6dbe673ae47a88053dafdf948a29cb8dfe0`
- PR #122 branch: `origin/feat/qol-polish-pack`
- PR/scanner head: `4c66c3b6b1c20321163e732d6d06f5dacaeb4e5a`
- Mission-content head: `f5c41461508e117d13d0b6172cbd66698091a8eb`
- PR #124 r8 integration branch: `origin/release/2026-07-02-stackcheck-r8`
- PR #124 r8 head: `16bfe29eb326303848f6223bc5604b81260ca484`
- Comparison remote `Miksuu/a2waspwarfare`: `b8389e7482438edd00f420c5bb795ac0a642971f`
- Wiki head checked during the release loop:
  `f6cdfce`

PR #127, the curated release fold of selected legacy-fit changes from
PR #124/#125/#126, was merged at
`8db697c10a789fe4a495c91a967df927cceb7bbb`. It is now part of master, but a
series of cmdcon32, cmdcon33, and cmdcon34 follow-up fixes means the PR #127-only
artifact is stale relative to the latest master artifact.

PR #132 was merged at `b4a6350ca0f90c9b0316570473c05a5e790aea96`. It is now
current master source, but it is not release proof until exact current-build
artifacts and RPT evidence exist.

GitHub currently reports PR #124 as open and draft with unknown merge state.
The old r8 branch remains stale relative to current master and needs conflict
repair or replacement before it can be a current release candidate.

Another draft lane, PR #125, exists for a broader command-center package. It is
open, draft, and currently reported clean at head
`1d713bcf2b2daa6eea722bca5221f4e430bbe746`. Treat it as a separate broad lane,
not as current-master runtime proof. The earlier `b4628c35` package validation
is now stale because the branch advanced.

PR #126 is open again, draft, and GitHub reports it clean at
`607d6c59ca4268fd0938e94edc66619d008db673`. Its verified shippable pieces were
folded through PR #127; the latest head still needs fresh triage before release
selection.

PR #129 is an open draft release-readiness hub at
`72888f22851871c8ed967a0fd29402a0c410c0bd`. It is mission-affecting, not
docs-only, and overlaps PR #125 in shared AICOM commander files.

PR #131 is now closed without merge and stale after PR #132. PR #133 replaces
it as the focused draft fix for the latest master static blocker. PR #133 is
open, draft, and GitHub reports it clean at
`5f5eeedcbfd9f2b8da63451e155c3a252ded3bf0` on base
`b4a6350ca0f90c9b0316570473c05a5e790aea96`. It only touches the Chernarus and
generated Takistan placement-preview block in `Client/Init/Init_Client.sqf`,
splitting the dense flat-ground expression into a `_flatSpots` count check while
keeping the PR #132 GUER radio/client changes intact. Validation for PR #133:
`git diff --check origin/master..HEAD` pass; `git diff --check
5bf5f92385ef0218c5e20fb4273cf563a295e82d..HEAD` pass; LoadoutManager reached
`CHERNARUS DONE` and `TAKISTAN DONE` and packaged `_MISSIONS.7z` with local
7-Zip. PR #133 is source/static/generator proof only, not runtime proof.

PR #134 is a new Build84/cmdcon36 lane, open and non-draft at
`cc29feb2077e2ebc7e946847fbdef78ae0f3c5eb`. GitHub reports it clean, but it is
broad mission-affecting AICOM/client/start-spawn scope. Local package/static
triage found a raw current-master whitespace failure and release-marker identity
ambiguity, documented below.

PR #135 is a focused draft fix for PR #134, open against
`claude/build84-cmdcon36` at `203592daecf6444312076664ccad37471e663278`. It
fixes the PR #134 release identity/static blockers without changing gameplay
logic.

Exact PR #133 `SERVER_DEBUG` mission-folder artifact:

- artifact:
  `outputs/a2waspwarfare-pr133-5f5eeedc-server-debug-missions.7z`
- SHA256:
  `B626E746774B9B350B9431923A975C9E0087CF330B3D35808D650A254D379DFB`
- size: `7166613` bytes
- manifest:
  `outputs/a2waspwarfare-pr133-5f5eeedc-server-debug-artifact-2026-07-01-1910.md`
- archive test: pass, 160 folders, 1723 files, 24289101 uncompressed bytes
- extraction validation: pass
- extracted folders: Chernarus and Takistan mission folders
- both extracted `version.sqf` files have `WF_DEBUG` commented out,
  `WF_LOG_CONTENT` enabled, and `WF_RELEASE_MARKER` with `git=5f5eeedcbf`

This artifact is not runtime proof. It is the exact #133 bundle to launch for
real RPT collection if #133 is selected.

Exact PR #133 folder-smoke kit:

- kit:
  `outputs/a2waspwarfare-pr133-5f5eeedc-folder-smoke-kit.7z`
- SHA256:
  `A1359392F00141BD2502293F439123C7B6DDDD449C5DAAF2F5E38DE2015EBEC7`
- size: `7193922` bytes
- manifest:
  `outputs/a2waspwarfare-pr133-5f5eeedc-folder-smoke-kit-manifest-2026-07-01-1925.md`
- source artifact SHA256:
  `B626E746774B9B350B9431923A975C9E0087CF330B3D35808D650A254D379DFB`
- archive validation: pass, 165 folders, 1733 files, 24337576
  uncompressed bytes
- extracted-kit validation: pass, root contains `README.md`, `MPMissions`,
  `scripts`, `Tools`, and `docs`
- all folder-smoke PowerShell scripts parse successfully
- stale PR #131 identity scan over staged and extracted kits: pass
- staging and extracted install/preflight rehearsals pass for both missions
- smoke evidence template generation records PR #133 head
- synthetic release-gate collector/scanner/package rehearsal passes with ten
  synthetic RPT files covering `server`, `client`, `latejoin`, `hc1`, and
  `hc2` roles across both Chernarus and Takistan

This folder-smoke kit is still not runtime proof. It is the portable exact
#133 package to use for real RPT collection and human smoke notes.

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

## PR #125 Superseded Artifact

Fresh triage and packaging for PR #125 at 2026-07-01 19:46 Europe/Amsterdam:

- PR: <https://github.com/rayswaynl/a2waspwarfare/pull/125>
- branch: `codex/release-command-center-20260630`
- head: `b4628c35afeef15a1703021e6171706a949e5afa`
- base: `b4a6350ca0f90c9b0316570473c05a5e790aea96`
- artifact:
  `outputs/a2waspwarfare-pr125-b4628c35-server-debug-missions.7z`
- SHA256:
  `D0BD2405E5541130BCD98D2C98B1082666537863FDF6B02E3A79A09D240EE3F2`
- size: `7158727` bytes
- manifest:
  `outputs/a2waspwarfare-pr125-b4628c35-server-debug-artifact-2026-07-01-1946.md`

Validation:

- GitHub reports PR #125 open, draft, and clean/mergeable against current
  master.
- `git diff --check origin/master..HEAD`: pass.
- Added-line watched-token scan over maintained mission diff for A3-only tokens:
  no added executable hits.
- LoadoutManager `SERVER_DEBUG` exited `0` and reached `CHERNARUS DONE` and
  `TAKISTAN DONE`.
- Archive integrity and extraction validation pass with 160 folders, 1721 files,
  and 24272901 uncompressed bytes.
- Both extracted `version.sqf` files have `WF_DEBUG` commented out,
  `WF_LOG_CONTENT` enabled, and `WF_RELEASE_MARKER` with `git=b4628c35af`.
- Extracted package scan for `AI_Commander_HCTopUp` / `HCTopUp.DRAFT`: no hits.
- `Run-WaspFinalCheck.ps1` exits non-zero because the local active stress
  overlay/RHUD-stressProof environment is absent or misaligned. The code
  validation portions are mostly pass, with only the known manual
  `find "Aircraft"` review item in both terrain A2 OA lint passes.

This artifact is not runtime proof. It is a package/static validation result for
the broad command-center branch as it existed at `b4628c35`. It is now stale:
PR #125 advanced to `1d713bcf2b2daa6eea722bca5221f4e430bbe746` after this
artifact was built. Do not use the `b4628c35` / `D0BD2405...` tuple as current
PR #125 proof except as historical evidence.

## PR #134 Build84 Artifact

Fresh triage and packaging for PR #134 at 2026-07-01 19:54 Europe/Amsterdam:

- PR: <https://github.com/rayswaynl/a2waspwarfare/pull/134>
- branch: `claude/build84-cmdcon36`
- head: `cc29feb2077e2ebc7e946847fbdef78ae0f3c5eb`
- current master: `b4a6350ca0f90c9b0316570473c05a5e790aea96`
- merge base: `6ff7bad28003ec6781a9346e033afbc386894b6f`
- artifact:
  `outputs/a2waspwarfare-pr134-cc29feb-server-debug-missions.7z`
- SHA256:
  `F7768578727C7A16D865D31190EF72488FE0F8D21CF2ABCF670545D924122F3B`
- size: `7174919` bytes
- manifest:
  `outputs/a2waspwarfare-pr134-cc29feb-server-debug-artifact-2026-07-01-1954.md`

Validation:

- GitHub reports PR #134 open, non-draft, and clean/mergeable.
- True mission payload from merge base is 34 maintained mission files,
  `+1322/-56`.
- `git diff --check 6ff7bad28003ec6781a9346e033afbc386894b6f..HEAD`: pass.
- `git diff --check origin/master..HEAD`: fail on reintroduced
  `GUER_TECH.md` trailing whitespace at lines 33 and 45.
- Added-line watched-token scan over maintained mission diff for A3-only tokens:
  no added executable hits.
- `Tools/PrTestHarness/Run-WaspFinalCheck.ps1` is not present on this branch, so
  the newer final harness could not be run from the PR #134 checkout.
- LoadoutManager `SERVER_DEBUG` exited `0` and reached `CHERNARUS DONE` and
  `TAKISTAN DONE`.
- Archive integrity and extraction validation pass with 160 folders, 1727 files,
  and 24372987 uncompressed bytes.
- Both extracted `version.sqf` files have `WF_DEBUG` commented out,
  `WF_LOG_CONTENT` enabled, and `WF_RELEASE_MARKER` with `git=cc29feb207`.

Cautions:

- The extracted release marker says
  `candidate=release-command-center-20260630`, not Build84/cmdcon36.
- The branch re-adds `B57-SOAK-PROPOSALS.md` and `GUER_TECH.md` relative to
  current master; `GUER_TECH.md` fails whitespace.
- The package contains `AI_Commander_HCTopUp.DRAFT.sqf`, but that file and its
  guarded call site are inherited from current master, not introduced by PR
  #134.

This artifact is not runtime proof. It is an exact PR #134 package for further
runtime collection only after the source/static identity issues are resolved or
explicitly waived.

## PR #135 Build84 Identity Fix

Fresh fix and packaging for PR #135 at 2026-07-01 20:09 Europe/Amsterdam:

- PR: <https://github.com/rayswaynl/a2waspwarfare/pull/135>
- base PR: #134, <https://github.com/rayswaynl/a2waspwarfare/pull/134>
- branch: `codex/fix-pr134-release-identity`
- base branch: `claude/build84-cmdcon36`
- base head: `cc29feb2077e2ebc7e946847fbdef78ae0f3c5eb`
- fix head: `203592daecf6444312076664ccad37471e663278`
- artifact:
  `outputs/a2waspwarfare-pr134-release-identity-server-debug-missions.7z`
- SHA256:
  `EF2175B2CF00DB27A8F589350203F25A211BF6E427A4FA13A27E30DA31BE4FF0`
- size: `7175056` bytes
- manifest:
  `outputs/a2waspwarfare-pr135-pr134-release-identity-artifact-2026-07-01-2009.md`

Scope:

- Remove the two `GUER_TECH.md` trailing-whitespace failures.
- Change the LoadoutManager release candidate id to
  `build84-cmdcon36-20260701`.
- Update both terrain release marker templates and fallback startup markers.
- Update the LoadoutManager package-validation README expected candidate.

Validation:

- `git diff --check origin/master`: pass, with Windows line-ending warnings only.
- `git diff --check origin/claude/build84-cmdcon36`: pass, with Windows
  line-ending warnings only.
- `git diff --cached --check`: pass before commit.
- LoadoutManager `SERVER_DEBUG` exited `0` and reached `CHERNARUS DONE` and
  `TAKISTAN DONE`.
- Archive integrity and extraction validation pass with 160 folders, 1727 files,
  and 24372971 uncompressed bytes.
- Both extracted `version.sqf` files have `WF_DEBUG` commented out,
  `WF_LOG_CONTENT` enabled, and `WF_RELEASE_MARKER` with
  `candidate=build84-cmdcon36-20260701`, `git=cc29feb207`, and the correct
  terrain.

This artifact is not runtime proof. It proves the PR #134 package/static
identity blockers have a focused fix path, but final release proof still
requires real both-map Arma 2 OA RPT evidence and human smoke notes.

## Current Master / r9 Reconciliation

After fresh remote refreshes on 2026-07-01 10:33, 10:48, and 11:04
Europe/Amsterdam:

- `origin/master` is `311b9d93661f292eeac9337989da44fd9b9ed8f5`.
- PR #124/r8 is open draft; GitHub reports `DIRTY`, and local merge-tree
  analysis still shows conflicts.
- PR #125/command-center advanced to
  `0e2696f1cd831a36594836ccc7a395bd6637a0b4` and is now reported clean, but
  remains a separate broad draft lane. This entry is superseded by the 19:46
  `b4628c35afeef15a1703021e6171706a949e5afa` package validation above.
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

## Superseded b724 Master Exact Artifact

An exact `SERVER_DEBUG` mission-folder artifact was created for the now-stale
`b7241a35f0460e92cf8839cd315c95defaa6380b` master:

- source head: `b7241a35f0460e92cf8839cd315c95defaa6380b`
- artifact: `outputs/a2waspwarfare-master-b7241a35-server-debug-missions.7z`
- SHA256: `F2652CCDFF6085D73461C4FAADE4422D667F7FD245BE87556746A2CDA569545E`
- size: `7140187` bytes
- manifest:
  `outputs/a2waspwarfare-master-server-debug-artifact-2026-07-01-1306.md`

Build/validation:

- `dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj -c SERVER_DEBUG`
  exited `0`
- reached `CHERNARUS DONE`
- reached `TAKISTAN DONE`
- archive integrity test passed with 160 folders, 1719 files, 24061857
  uncompressed bytes
- extraction produced exactly the Chernarus and Takistan mission folders
- extracted `version.sqf` files have `WF_DEBUG` commented out,
  `WF_LOG_CONTENT` enabled, and `WF_RELEASE_MARKER` present for
  `git=b7241a35f0` on both terrains

Static gate:

- `git diff --check 5bf5f92385..origin/master` fails on space-before-tab
  indentation in both terrain copies of `Client/Init/Init_Client.sqf` at the
  cmdcon33/cmdcon34 placement preview lines.
- The added player placement flat-check line still uses a dense
  `count (...) == 0` expression inside the lazy boolean chain. Treat this as a
  source-review/runtime-RPT risk until the line is simplified or exact runtime
  evidence proves it clean.
- Old draft PR #131 validation at `2178b20d3d` passed `git diff --check
  origin/master..HEAD`, reached `CHERNARUS DONE` and `TAKISTAN DONE` in
  LoadoutManager `SERVER_DEBUG`, and kept the touched block mirrored between
  Chernarus and generated Takistan. This old branch/artifact is now superseded
  by the refreshed `bc297a63` PR #131 validation below.
- Superseded PR #131 artifact:
  `outputs/a2waspwarfare-pr131-2178b20d-server-debug-missions.7z`, SHA256
  `4B6E14D5528B5037C6387832B4A8A4DBF555EA251748E9D3A349BB83E93CD95D`,
  archive/extraction pass, 1719 files, and both extracted `version.sqf` files
  have `WF_RELEASE_MARKER` for `git=2178b20d3d`.
- Superseded PR #131 folder-smoke kit:
  `outputs/a2waspwarfare-pr131-2178b20d-folder-smoke-kit.7z`, SHA256
  `C70F3E26961FE6FEC477B77D0FE46C98046AC756780D550B3EA297FB955F1F8C`,
  archive/extraction pass, script parse pass, install rehearsal pass, evidence
  template generation pass, and synthetic release-gate package validation pass.

This artifact superseded the `5bf5f923`, `311b9d93`, and PR #127-only artifacts
at the time, but it is now stale relative to current master
`7fd310c63c23e2a723ca24de7349b8235631db9d`.

## Current PR #131 Exact Artifact And Kit

PR #131 has been refreshed onto current master
`7fd310c63c23e2a723ca24de7349b8235631db9d`:

- PR #131 head: `bc297a6323aa7eabaf6fd8ccdf5fefb555ad1583`
- Source diff over current master: exactly the two terrain copies of
  `Client/Init/Init_Client.sqf`
- `git diff --check origin/master..HEAD`: pass
- LoadoutManager `SERVER_DEBUG`: exit `0`
- LoadoutManager reached `CHERNARUS DONE`
- LoadoutManager reached `TAKISTAN DONE`

Exact artifact:

- artifact:
  `outputs/a2waspwarfare-pr131-bc297a63-server-debug-missions.7z`
- SHA256:
  `D2F3964F51A8A2647AD6A50D0BAD08016D3B35D513D41DB2A5CA931CFA483236`
- size: `7139836` bytes
- archive test: pass
- extraction validation: pass, 160 folders, 1719 files, 24061939 bytes
- both extracted `version.sqf` files have `WF_DEBUG` commented out,
  `WF_LOG_CONTENT` enabled, and `WF_RELEASE_MARKER` for `git=bc297a6323`

Exact folder-smoke kit:

- kit:
  `outputs/a2waspwarfare-pr131-bc297a63-folder-smoke-kit.7z`
- SHA256:
  `4FDCCAFE489802E4D2C6A31854F43452FCF333F766996A1E108889AFA9CE8687`
- size: `7167874` bytes
- archive test: pass, 165 folders, 1730 files, 24111675 bytes
- extracted-kit validation: pass
- six kit PowerShell scripts parse
- staging and extracted install rehearsals pass
- smoke evidence template generation pass
- synthetic release-gate collector/scanner/package rehearsal pass with
  `failed_count = 0`

This artifact and kit are still not runtime proof. They are the current exact
payload and tooling to use for real RPT collection if PR #131 is selected.

## Current Draft Lane Triage

Fresh triage at 2026-07-01 19:54 Europe/Amsterdam found:

- PR #134: new Build84/cmdcon36 lane, open non-draft and clean at
  `cc29feb2077e2ebc7e946847fbdef78ae0f3c5eb`. True mission payload from merge
  base is 34 maintained mission files and passes true-payload `git diff
  --check`; LoadoutManager `SERVER_DEBUG` reaches both maps and package
  archive/extraction validation passes with artifact SHA256
  `F7768578727C7A16D865D31190EF72488FE0F8D21CF2ABCF670545D924122F3B`.
  However raw current-master `git diff --check origin/master..HEAD` fails on
  reintroduced `GUER_TECH.md` trailing whitespace at lines 33 and 45, and the
  extracted release marker still says
  `candidate=release-command-center-20260630`. Treat it as broad and
  source/identity-pending, not runtime proof.
- PR #135: focused Build84 identity/static fix, open draft at
  `203592daecf6444312076664ccad37471e663278` against PR #134's branch. This
  clears the known `GUER_TECH.md` whitespace failure and produces a package with
  `candidate=build84-cmdcon36-20260701`.
- PR #133: focused placement-preview static fix, open draft and clean at
  `5f5eeedcbfd9f2b8da63451e155c3a252ded3bf0`. This is the current static
  unblocker for `origin/master` after PR #132 merged.
- PR #126: open draft, clean at
  `607d6c59ca4268fd0938e94edc66619d008db673`. This head advanced after the
  prior checkpoint and still needs fresh diff/static/runtime triage
  before release selection.
- PR #125: broad command-center/tooling lane at
  `1d713bcf2b2daa6eea722bca5221f4e430bbe746`. GitHub reports it `CLEAN`
  against merged #132 master. The prior `b4628c35` artifact SHA256
  `D0BD2405E5541130BCD98D2C98B1082666537863FDF6B02E3A79A09D240EE3F2` is now
  stale because this branch advanced.
- PR #129: release-readiness hub at
  `72888f22851871c8ed967a0fd29402a0c410c0bd`, 14 files and approximately
  `+188/-92`. It is mission-affecting in AICOM commander code, group GC,
  briefings, and release docs. Its docs mention older base context, so treat
  GitHub metadata and fresh local diff checks as authoritative.
- PR #132: merged into master at
  `b4a6350ca0f90c9b0316570473c05a5e790aea96`. Treat it as current source
  needing exact current-build artifact and runtime proof, not as proof by
  itself.

PR #125, PR #126, PR #129, and PR #134 are all mission-affecting AICOM/release
lanes. Do not combine them for Thursday without fresh conflict analysis,
LoadoutManager regeneration/validation, new artifacts, and fresh real RPT
proof.

## Superseded Latest Master Exact Artifact

An exact latest-master `SERVER_DEBUG` mission-folder artifact was previously
created for the now-stale `5bf5f92385ef0218c5e20fb4273cf563a295e82d` head:

- source head: `5bf5f92385ef0218c5e20fb4273cf563a295e82d`
- artifact: `outputs/a2waspwarfare-master-5bf5f923-server-debug-missions.7z`
- SHA256: `2E88777C983CCEF2ACFF798302C33708C2561C1835981A884CE94340B61D7FEC`
- size: `7140043` bytes
- manifest:
  `outputs/a2waspwarfare-master-server-debug-artifact-2026-07-01-1217.md`

Build/validation:

- `dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj -c SERVER_DEBUG`
  exited `0`
- reached `CHERNARUS DONE`
- reached `TAKISTAN DONE`
- `ZipManager` auto-detected `C:\Program Files\7-Zip\7z.exe`
- archive integrity test passed with 160 folders, 1719 files, 24057891
  uncompressed bytes
- extraction produced exactly the Chernarus and Takistan mission folders
- extracted `version.sqf` files have `WF_DEBUG` commented out,
  `WF_LOG_CONTENT` enabled, and `WF_RELEASE_MARKER` present for
  `git=5bf5f92385` on both terrains
- `git diff --check 311b9d936..5bf5f9238` passed
- added-line watched-token scan found no `params`, `pushBack`, `isEqualTo`,
  `isEqualType`, `getPosVisual`, `remoteExec`, or `BIS_fnc_MP`
- added-line scan still flags AICOM `count` expressions inside/near boolean
  logic; treat this as a source-review/runtime-RPT risk until real RPTs prove
  clean

This artifact superseded the `311b9d93` and PR #127-only artifacts at the time,
but it is now stale relative to
`b7241a35f0460e92cf8839cd315c95defaa6380b`. It should not be used as
current-master proof.

## Superseded Latest Master Folder Smoke Kit

A portable latest-master folder-smoke kit previously existed for collecting
runtime proof from the exact `5bf5f92385ef0218c5e20fb4273cf563a295e82d` master
payload:

- kit: `outputs/a2waspwarfare-master-5bf5f923-folder-smoke-kit.7z`
- SHA256: `173D16F30DF7E62AEC44E5A7354449F374894AAC3C8C8F6ADE9567E0487BD8B3`
- size: `7168763` bytes
- source artifact SHA256:
  `2E88777C983CCEF2ACFF798302C33708C2561C1835981A884CE94340B61D7FEC`
- manifest:
  `outputs/a2waspwarfare-master-folder-smoke-kit-manifest-2026-07-01-1230.md`

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

This kit is still not runtime proof, and it is now stale relative to
`b7241a35f0460e92cf8839cd315c95defaa6380b`. Build a fresh folder-smoke kit only
after the latest static gate is fixed or deliberately waived.

## Superseded Current Master Exact Artifact

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

This artifact superseded the 10:48 `54d0b8e7` artifact at the time, but it is
now stale relative to `5bf5f92385ef0218c5e20fb4273cf563a295e82d`. It should not
be used as current-master proof.

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

This kit is still not runtime proof, and it is now stale relative to
`5bf5f92385ef0218c5e20fb4273cf563a295e82d`. Rebuild the folder-smoke kit from
the `5bf5f923` artifact before using folder-smoke as the current proof path.

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

The newest read-only probe at 2026-07-01 18:44 Europe/Amsterdam found the
active livehost config shape has moved from the earlier `cmdcon30aicom` template
names to `cmdcon35aicom` template names:

- line 16: `[55-2hc]warfarev2_073v48co_cmdcon35aicom.chernarus`
- line 21: `[55-2hc]warfarev2_073v48co_cmdcon35aicom.chernarus`
- line 26: `[61-2hc]warfarev2_073v48co_cmdcon35aicom.takistan`

The checked active `MPMissions` listing shows a matching Chernarus PBO:

- `[55-2hc]warfarev2_073v48co_cmdcon35aicom.chernarus.pbo`, size `11149914`,
  last write `2026-07-01 09:13` livehost-local time

The checked active `MPMissions` listing did not show a matching
`[61-2hc]warfarev2_073v48co_cmdcon35aicom.takistan` PBO or folder, so active
Takistan still is not resolved by configured name from this probe.

Newest copied livehost server RPT:

- remote path: `C:\WASP\rpt-archive\arma2oaserver-deploy35-20260701-0917.RPT`
- local SHA256:
  `AD59D2DB41DAE2BF98BDBE6A6DD761459D18D89C1CEDDCB8675AED260F5F35F1`
- scanner summary:
  `work/live-probe-20260701-1844/deploy35-summary.json`

Strict release-gate scanner result over this single server RPT remains `FAIL`:

- Chernarus window: `1`
- Takistan window: `0`
- `LOG CONTENT : [NOT ACTIVATED]`: present
- stop-condition matches: `30`
- AICOM telemetry: pass
- HC registry gate: fail (`connect=14`, `group_civilian=0`,
  `register_true=0`, `connect_skip=0`)
- client/JIP evidence: absent, as expected from a single server RPT

Minipc remains non-proof: no selected Arma process JSON was returned, and the
checked `C:\Users\Chill\Documents\ArmA 2\MPMissions` and
`C:\Users\Chill\AppData\Local\ArmA 2 OA` paths are absent.

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

1. Treat PR #133 at `5f5eeedcbfd9f2b8da63451e155c3a252ded3bf0` as the current
   focused proof target for the static gate on top of merged #132, or merge
   #133 first and rebuild from the new `origin/master`.
2. Do not use old PR #122, r8, r9, `311b9d93`, or PR #127-only artifacts to
   prove latest `origin/master`.
3. If current `origin/master` is chosen without #133, record an explicit static
   gate waiver first. The current master artifact SHA256 is
   `F2652CCDFF6085D73461C4FAADE4422D667F7FD245BE87556746A2CDA569545E`, but the
   source static gate is failing.
4. If PR #133 is chosen, use artifact SHA256
   `B626E746774B9B350B9431923A975C9E0087CF330B3D35808D650A254D379DFB` and
   folder-smoke kit SHA256
   `A1359392F00141BD2502293F439123C7B6DDDD449C5DAAF2F5E38DE2015EBEC7`.
5. If the owner selects broad Build84/cmdcon36, merge or cherry-pick PR #135
   first so PR #134 no longer carries the `GUER_TECH.md` whitespace failure or
   `release-command-center-20260630` marker identity. The fixed package/static
   artifact SHA256 is
   `EF2175B2CF00DB27A8F589350203F25A211BF6E427A4FA13A27E30DA31BE4FF0`, but it
   is not release-ready proof.
6. Do not use the stale PR #125 body hash
   `77315B9AE6B43B087E024497A0877A1ADAC94F90461939A75D3E252946E55545` as the
   current command-center package identity. Also do not use the local
   `b4628c35` / `D0BD2405...` tuple as current PR #125 proof; PR #125 has
   advanced to `1d713bcf2b2daa6eea722bca5221f4e430bbe746` and needs a fresh
   package if selected.
7. If r9-narrow is chosen, first rebase/rebuild it on current `origin/master`,
   then push/open or update a source PR and publish a fresh artifact/hash. The
   older r9 artifact SHA256
   `96CD026F76E0828F584F243FEC2358C1D319CDEFAE5E69868B7394C89FC77171` no longer
   proves the latest master.
8. Run the exact chosen artifact through folder-smoke or a controlled dedicated
   proof environment with content logging enabled.
9. Collect both-map server/client/latejoin/HC evidence.
10. Run the release scanner with all required gates.
11. Attach human smoke notes.
12. Only then update release notes/wiki wording from runtime-pending to
   release-proven.

If the ASR/Ka-137 stop-condition errors recur on the exact proof runtime,
choose one explicit mitigation path:

- keep current artifact and prove on a non-failing ASR-compatible stack
- apply the narrow mission-local ASR `gunshothearing = 0` override and rebuild
- make GUER Ka-137 air defense opt-in/off and rebuild
- approve an ASR userconfig/addon-side fix outside this mission PR

Every source-changing mitigation resets the artifact hashes and evidence clock.
