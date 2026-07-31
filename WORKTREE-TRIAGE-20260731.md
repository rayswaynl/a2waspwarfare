# Worktree Triage — 2026-07-31

Follow-up to the morning prune (96 clean+merged+old worktrees removed). This pass triaged the
remaining registrations: dirty worktrees (Job 1) and unmerged branches (Job 2).

Paths are sanitized: `~` = the dev-machine user profile.

## Snapshot

| | count |
|---|---|
| Registrations at sweep start (incl. main checkout) | 438 |
| Skipped — modified <48h (fresh commits/edits/index) | 179 |
| Skipped — protected names (grand-reconcile, deploy-m0730i, caster-slot, cc-sell, broadcast-hud, spectator-v3-director ×2, salvage-recut) | 8 |
| In triage scope (older than 48h, unprotected) | 250 |
| **Removed this pass** (junk-only / dup-of-master / EOL-noise-only, HEAD merged) | **76** |
| Real uncommitted work — owner decision (Job 1 b) | 111 |
| Unmerged branches analyzed (Job 2) | 98 |
| Registrations after this pass | 363 (fleet spawned 1 new lane mid-run) |

## Method

- Read-only sweep first: per-worktree `git status --porcelain`, HEAD, `merge-base --is-ancestor origin/master`, dirty-file mtimes. Nothing was touched in worktrees with any activity in the last 48h.
- **Dirt was tested with a filter-aware `git diff HEAD`** — this repo has a massive line-ending-churn artifact (see Discovered Issues) that makes ~120 lanes *look* dirty when their content is byte-identical after CRLF normalization.
- Every non-junk dirty file was blob-compared against `origin/master` (normalized hash vs `origin/master:<path>`).
- Removal criteria (all required): HEAD is an ancestor of `origin/master`, AND every dirty entry is proven junk (owner's junk list), a duplicate of master's current file state, or pure EOL noise (empty filter-aware diff). Removed via `git worktree remove [--force]` only — no raw deletes, no stash, ever. Live re-verification before each removal (still registered, no nested registered worktree, still ancestor, status unchanged since sweep).
- Unmerged branches: `git log origin/master..HEAD`, diffstat, `git cherry` patch-equivalence, plus the authoritative signal — **GitHub PR state per branch** (`gh pr list --head`).

---

## Actions taken

**76 worktrees removed** (3 junk-only cleaned then removed; 73 removed with `--force`, each documented in Appendix A):

- 3× junk-only (a): single agent dropping (`.pr_body.md` / `RESULT.md` / `result-b.md`) deleted individually, worktree then clean+merged → removed.
- 73× (c)-class: dirt was exclusively junk droppings, blob-identical duplicates of master, and/or EOL-only noise; HEAD merged. Per-worktree breakdown in Appendix A.

**Not removed:** every worktree with any real uncommitted content (tables below), everything unmerged (Job 2 is report-only), everything recent or protected.

Note: worktree removal never deletes branches. The 76 removed worktrees' branches (all merged ancestors) still exist locally; cleanup one-liner in the follow-ups section.

---

## Job 1 (b) — real uncommitted work (owner decision)

### B1 — tracked content edits (48 worktrees)

`dirt` = real-changed tracked files (T) / real untracked files (U) after junk+dup+EOL filtering, with sample file names. Branch state includes PR state where one exists.

| worktree | branch | branch state | dirt (sample) | diffstat | best guess |
|---|---|---|---|---|---|
| `C:/tmp/claudewt/bmp2-at5-muzzle-20260727` | `codex/main-07270548-2-bmp2-at5-muzzle` | merged | 6T/1U: Common_RearmVehicle.sqf,Init_Common.sqf,Common_RearmVehicle.sqf | 6 files 36+ 24- | main 07270548 2 bmp2 at5 muzzle |
| `C:/tmp/claudewt/carrier-heli-20260727` | `fable/carrier-heli-deckspawn-20260727` | merged | 1T/0U: Server_BuyUnit.sqf | 1 file 32+ 1- | carrier heli deckspawn |
| `C:/tmp/claudewt/fob-v1-engineer-20260728` | `codex/fob-v1-engineer-20260728` | unmerged, PR 1543 OPEN | 1T/0U: JOURNAL.md |  | fob v1 engineer |
| `C:/tmp/claudewt/integ-20260727` | `deploy/morning-20260727` | unmerged, no PR | 10T/0U: Init_CommonConstants.sqf,Parameters.hpp,initJIPCompatible.sqf | 10 files 44+ 44- | morning |
| `C:/tmp/claudewt/update-4hc-20260726` | `fable/realplayersnear-slash-koth-colors-20260726` | merged | 6T/0U: Parameters.hpp,initJIPCompatible.sqf,Parameters.hpp | 6 files 24+ 24- | realplayersnear slash koth colors |
| `C:/tmp/codexwt/wasp-teamsfound-chunking-20260728` | `codex/aicom-teamsfound-chunking-20260728` | merged | 3T/1U: AI_Commander_Teams.sqf,AI_Commander_Teams.sqf,AI_Commander_Teams.sqf | 3 files 42+ 3- | aicom teamsfound chunking |
| `C:/tmp/fixwt/aicom-arty-husk-attribution` | `fix/aicom-arty-husk-attribution` | merged | 6T/0U: Construction_StationaryDefense.sqf,RequestOnUnitKilled.sqf,Construction_StationaryDefense.sqf | 6 files 135+ 33- | aicom arty husk attribution |
| `~/.codex-worktrees/fleet-lane-scratch/codex-main-07270715-2-decap-gate-maprelative-20260728` | `codex/main-07270715-2-decap-gate-maprelative-20260728` | merged | 6T/1U: Init_CommonConstants.sqf,AI_Commander_Decapitate.sqf,Init_CommonConstants.sqf | 6 files 27+ 3- | main 07270715 2 decap gate maprelative |
| `~/.config/superpowers/worktrees/a2waspwarfare/codex-gdir-capability-20260719` | `codex/071919-gdir-capability` | unmerged, no PR | 12T/1U: GUI_Menu_GuerCommissar.sqf,HandleSpecial.sqf,Init_PublicVariables.sqf | 12 files 759+ 105- | gdir capability |
| `~/.config/superpowers/worktrees/a2waspwarfare/codex-main-07260818-ap1-bmp2-at5-muzzle` | `codex/main-07260818-ap1-bmp2-at5-muzzle` | merged | 6T/1U: Common_RearmVehicle.sqf,Init_Common.sqf,Common_RearmVehicle.sqf | 6 files 33+ 24- | main 07260818 ap1 bmp2 at5 muzzle |
| `~/.config/superpowers/worktrees/a2waspwarfare/codex-main-07270548-2-perf-antistack-aicom-cleaner-round2` | `codex/main-07270548-2-perf-antistack-aicom-cleaner-round2` | unmerged, no PR | 2T/0U: AI_Commander_Teams.sqf,test_perf_round2_scheduler_slices.py | 2 files 20+ 3- | main 07270548 2 perf antistack aicom cleaner round2 |
| `~/_wasp-aicom-dyn` | `fable/aicom-dyntimeout-press` | merged | 1T/1U: JOURNAL.md | 1 file 31+ 608- | aicom dyntimeout press |
| `~/_wasp-dblbom-gate` | `fable/lint-dblbom-gate` | unmerged, PR 834 MERGED | 1T/0U: JOURNAL.md | 1 file 22+ | lint dblbom gate |
| `~/_wasp-deploy-cc46` | `DETACHED` | merged | 1T/0U: AGENT-HANDBOOK.md | 1 file 14+ | DETACHED |
| `~/_wasp-gdir-p56` | `fable/gdir-p5-p6` | merged | 6T/0U: Init_CommonConstants.sqf,Server_GuerDirector.sqf,Init_CommonConstants.sqf | 6 files 516+ 6- | gdir p5 p6 |
| `~/_wasp-native-lab` | `codex/native-lab-x86-boundary` | merged | 16T/0U: .gitattributes,.gitignore,ABI-SAFETY-AND-FALLBACK.md | 16 files (NativeLab tree) | native lab x86 boundary |
| `~/_wasp-soak-scratch` | `DETACHED` | merged | 1T/0U: README.md | 1 file | DETACHED |
| `~/_wt-townsviz` | `codex/towns-garrison-viz` | merged | 9T/0U: GUI_Menu.sqf,Init_CommonConstants.sqf,Dialogs.hpp | 10 files 277+ 21- | towns garrison viz |
| `~/a2wasp-consol` | `claude/build84-cmdcon36` | merged | 5T/0U: JOURNAL.md,AICOM-V2-FAILURE-CATALOG.md,AICOM-V2-HC-CONTRACT.md | 5 files 106+ 336- | build84 cmdcon36 |
| `~/a2wasp-experital-deploy` | `deploy/2026-06-12-aicom-experital` | unmerged, PR 35 CLOSED | 9T/10U: JOURNAL.md,Client_FNC_Special.sqf,Upgrades_CO_RU.sqf | 9 files 301+ 16- | 2026 06 12 aicom experital |
| `~/a2wasp-fix744` | `fable/skin-flavor-names` | merged | 5T/0U: Client_TipRotation.sqf,Init_TownMode.sqf,AI_Commander_Strategy.sqf | 5 files 24+ 5- | skin flavor names |
| `~/a2wasp-navalhvt` | `feat/naval-hvt-objectives` | merged | 28T/6U: EASA_Init.sqf,EASA_Init.sqf,Core_GUE.sqf | 29 files 1107+ 208- | naval hvt objectives |
| `~/a2wasp-pressfix` | `fable/aicom-v2-l1-press-fix` | merged | 2T/0U: version.sqf.template,version.sqf.template | 2 files 2+ 2- | aicom v2 l1 press fix |
| `~/a2wasp-smlfix` | `release/wasp-aicom-recovery-20260727` | merged | 3T/0U: coin_interface.sqf,coin_interface.sqf,coin_interface.sqf | 3 files 39+ 6- | wasp aicom recovery |
| `~/a2wasp-tp21` | `fable/tp21-team-menu-v2` | merged | 4T/0U: updateavailableactions.fsm,Common_FireArtillery.sqf,Server_ChangeSideSupply.sqf | 4 files 19+ 4- | tp21 team menu v2 |
| `~/a2waspwarfare/.claude/worktrees/release-command-center` | `codex/release-command-center-20260630` | unmerged, PR 125 CLOSED | 1T/416U: render.py | 1 file 82+ 88- | release command center |
| `~/a2waspwarfare/.claude/worktrees/release-merge-scratch` | `DETACHED` | detached snapshot | 1T/0U: CLAUDE.md | 1 file 67+ 22- | DETACHED |
| `~/a2waspwarfare-deploy` | `DETACHED` | merged | 1T/0U: GUI_Menu.sqf | 1 file 9+ 1- | DETACHED |
| `~/a2waspwarfare-docs` | `docs/developer-wiki-claude` | unmerged, PR 3 CLOSED | 42T/4U: AI-Assistant-Developer-Guide.md,AI-Assistant-Guide.md,AI-Headless-And-Performance.md | 42 files 2122+ 1265- | developer wiki claude |
| `~/a2waspwarfare-guerpanel-docs` | `codex/docs-guer-commissar-panel` | merged | 1T/1U: JOURNAL.md | 1 file 8+ | docs guer commissar panel |
| `~/a2waspwarfare-junepatch` | `release/2026-06-patch-test` | merged | 1T/0U: GUI_Menu.sqf | 1 file 9+ 1- | 2026 06 patch test |
| `~/a2waspwarfare-positions` | `feat/commander-positions` | merged | 19T/5U: coin_interface.sqf,HandleSpecial.sqf,Init_PublicVariables.sqf | 19 files 305+ 124- | commander positions |
| `~/a2waspwarfare-pr-builds/PR8-JuneFeatureBundle` | `DETACHED` | merged | 127T/152U: Preferences.cs,ProgramRuntime.cs,Client_UpdateRHUD.sqf | 148 files 2514+ 2865- | DETACHED |
| `~/a2waspwarfare-worktrees/lab-0g-8ed4004c` | `lab/deleg-on-master-DO-NOT-MERGE` | unmerged, no PR | 3T/2U: ProvingGround_PreInit.sqf,ProvingGround_Server.sqf,scenarios.json | 3 files 949+ 457- | deleg on master DO NOT MERGE |
| `~/a2waspwarfare-zargabad` | `feat/zargabad-buildout` | unmerged, no PR | 1T/0U: Claude_Fortifications.sqf | 1 file 44+ 52- | zargabad buildout |
| `~/build0725/client-qol` | `claude/u3-client-qol-20260725` | merged | 16T/0U: updateteamsmarkers.sqf,Client_QOL_Advisor.sqf,GUI_Menu_Command.sqf | 16 files 355+ 19- | u3 client qol |
| `~/build0725/naval-rumor` | `claude/u3-naval-rumor-20260725` | merged | 12T/3U: Init_Common.sqf,Init_CommonConstants.sqf,Init_NavalHVT.sqf | 12 files 57+ 3- | u3 naval rumor |
| `~/build0725/territorial-hud` | `claude/u3-territorial-hud-20260725` | merged | 6T/0U: Client_UpdateRHUD.sqf,Init_CommonConstants.sqf,Client_UpdateRHUD.sqf | 6 files 171+ 6- | u3 territorial hud |
| `~/codex-fleet-20260702/wt-cx-190` | `fable/lane190-patrol-contested` | unmerged, PR 524 CLOSED | 4T/0U: version.sqf.template,Init_CommonConstants.sqf,server_town_patrol.sqf | 4 files 38+ 12- | lane190 patrol contested |
| `~/codex-fleet-20260702/wt-cx-191` | `fable/lane191-aa-gate` | unmerged, PR 525 CLOSED | 5T/0U: version.sqf.template,Init_CommonConstants.sqf,Server_GetTownGroups.sqf | 5 files 12+ 11- | lane191 aa gate |
| `~/codex-fleet-20260702/wt-cx-196` | `fable/lane196-scud-reachability` | unmerged, PR 519 CLOSED | 2T/0U: version.sqf.template,version.sqf.template | 2 files 9+ 9- | lane196 scud reachability |
| `~/codex-fleet-20260702/wt-cx-202` | `fable/lane202-arty-cooldown` | unmerged, PR 534 CLOSED | 2T/0U: version.sqf.template,version.sqf.template | 2 files 2+ 2- | lane202 arty cooldown |
| `~/Documents/Codex/2026-06-05/wasp-rpt-afk-bool-comparison/work/a2waspwarfare-pr8-afk` | `fix/pr8-afk-bool` | merged | 54T/5U: monitorAFK.sqf,Client_UpdateRHUD.sqf,updateteamsmarkers.sqf | 66 files 778+ 888- | pr8 afk bool |
| `~/Documents/Codex/2026-07-13/lo/work/a2waspwarfare-hc-observe-review` | `codex/hc-observe-offline-review-20260715` | merged | 18T/8U: Init_CommonConstants.sqf,HC_StatLoop.sqf,Init_HC.sqf | 18 files 261+ 6- | hc observe offline review |
| `~/Documents/Codex/2026-07-13/lo/work/a2waspwarfare-hetzner-installer` | `codex/hetzner-72h-installer` | unmerged, PR 1102 CLOSED | 1T/0U: DEPLOY-V2-CHANGELOG.md | 1 file 19+ | hetzner 72h installer |
| `~/fleet-lane-scratch/wasp-roster-pr-a-20260720` | `codex/0719013513-r-roster-pr-a-20260720` | merged | 12T/0U: Groups_GUE.sqf,Groups_TKA.sqf,Groups_TKGUE.sqf | 12 files 165+ | r roster pr a |
| `~/wasp-deploy-prep-20260717` | `deploy-prep/bundle-20260717` | merged | 6T/201U: Init_CommonConstants.sqf,Parameters.hpp,Init_CommonConstants.sqf | 6 files 9+ 9- | bundle |
| `~/wasp-fixwave-20260717` | `fix/wave-20260717` | merged | 11T/1U: Action_VehicleSell.sqf,Root_GUE.sqf,Root_TKGUE.sqf | 11 files 114+ 20- | wave |

Highlights worth a look before anything else:

- `~/a2wasp-navalhvt` (`feat/naval-hvt-objectives`, merged): 28 tracked files, 1107+/208- — a big uncommitted delta on top of the landed naval work. Largest genuine (b) item.
- `C:/tmp/claudewt/bmp2-at5-muzzle-20260727` and `~/.config/superpowers/.../codex-main-07260818-ap1-bmp2-at5-muzzle`: two sibling uncommitted rewrites of `Common_RearmVehicle.sqf` (turret-path rearm). The BMP2-AT5 muzzle fix landed via another lane — these look like the fuller turret-magazine rewrite that never shipped.
- `C:/tmp/claudewt/carrier-heli-20260727` (`fable/carrier-heli-deckspawn-20260727`, merged): uncommitted `Server_BuyUnit.sqf` widen `isKindOf "Plane"` → `"Air"` so carrier-bought helis get deck-height Z. Reads like a finished, unshipped correctness fix.
- `~/_wasp-gdir-p56` (`fable/gdir-p5-p6`, merged): 516+ lines of GUER Director P5/P6 work, uncommitted.
- `~/a2waspwarfare-positions` (`feat/commander-positions`, merged): 19 files, 305+/124- — WDDM commander-positions follow-on.
- `~/_wt-townsviz` (`codex/towns-garrison-viz`, merged): 277+ lines towns/garrison visualization GUI.
- `~/build0725/client-qol`, `~/build0725/territorial-hud`, `~/build0725/naval-rumor`: the July-25 U3 wave leftovers — each carries a substantial uncommitted feature pass.

### B2 — untracked content files only (13 worktrees)

| worktree | branch | branch state | untracked real files (sample) | guess |
|---|---|---|---|---|
| `~/.config/superpowers/worktrees/a2waspwarfare/codex-command-menu-crash-20260718` | `codex/command-menu-crash-20260718` | merged | 1U: Tools/Lint/test_command_order_queue.py | command menu crash |
| `~/.config/superpowers/worktrees/a2waspwarfare/codex-match-report-overhaul-20260720` | `codex/match-report-overhaul-20260720` | unmerged, PR 1195 MERGED | 1U: Tools/MatchReport/zargabad_control_map_smoke.png | match report overhaul |
| `~/_wasp-aibehavior` | `fable/ai-behavior-loop` | merged | 8U: docs/design/outputs/A47-LEDGER-ENTRY.txt,docs/design/outputs/A47-TERRAIN-OSI-VIABILITY.md,docs/design/outputs/A48-LEDGER-ENTRY.txt | ai behavior loop |
| `~/_wasp-fob-v1` | `codex/wasp-fob-build-v1` | unmerged, PR 1121 CLOSED | 3U: Tools/Temp/fob_patch.py,Tools/Temp/fob_patch2.py,Tools/Temp/fob_write_new.py | wasp fob build v1 |
| `~/_wasp-ka137` | `fable/fix-ka137-crewwipe` | merged | 1U: Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_GuerAirDef.sqf.fable-fix.diff | fix ka137 crewwipe |
| `~/_wasp-tow` | `fable/fix-balance-tow-side` | merged | 3U: Tools/LoadoutManager/Data/Vehicles/BaseVehicle.cs.bak,Tools/LoadoutManager/Data/Vehicles/BaseVehicle.cs.bak2,Tools/LoadoutManager/Data/Vehicles/GroundVehicles/Implementations/BLUFOR/HeavyFactory/M2A2EP1.cs.bak | fix balance tow side |
| `~/_wasp-town-init-waits-remaining-20260713` | `codex/town-init-waits-remaining-20260713` | unmerged, PR 1091 MERGED | 1U: docs/superpowers/plans/2026-07-13-town-init-waits-remaining.md | town init waits remaining |
| `~/_wasp-usv` | `fable/usv-flotilla` | merged | 2U: Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Server_USVFlotilla.sqf,Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Server_USVFlotilla.sqf | usv flotilla |
| `~/a2wasp-ctl-build` | `fable/ctl-impl-v1` | merged | 1U: docs/design/v2/SCUD-SCOUT-INVESTIGATION-2026-07-07.md | ctl impl v1 |
| `~/a2wasp-mrv2` | `claude/match-report-video` | unmerged, PR 115 CLOSED | 1U: Tools/MatchReport/matchdata.py.orig | match report video |
| `~/codex-fleet-20260702/wt-c` | `codex/24-vote-qa-delta` | merged | 1U: docs/design/LANE24-VOTE-SYSTEM-QA.md | 24 vote qa delta |
| `~/codex-fleet-20260702/wt-deploy` | `DETACHED` | merged | 8U: docs/design/v2/AGENTS-GUIDE-REV-STAGED-DIFF.md,docs/design/v2/FLAG-CENSUS.md,docs/design/v2/PR-QUEUE-TRIAGE.md | DETACHED |
| `~/Documents/Codex/worktrees/a2wasp-map-clarity-local-toggles-20260718` | `codex/07180826-1-map-clarity-toggles` | unmerged, no PR | 1U: Tools/PrTestHarness/Client/Test-MapClarityToggleContract.ps1 | 1 map clarity toggles |

Note: `~/_wasp-usv` carries `Server_USVFlotilla.sqf` for takistan+zargabad as untracked files — if the USV flotilla only landed for chernarus, these are the missing mission variants.

### B3 — droppings-only "real" dirt (36 worktrees) — recommend discard

Dirt survived the junk filter on a technicality (review logs, staged PBOs, `.bak` files, fleet prompts, lint captures, deploy staging). Nothing here looks like mission source. Recommend treating all 36 as junk; each would then be removable by the same (a)/(c) rules (24 have merged HEADs; 12 are also Job-2 branches).

<details><summary>36 rows</summary>

| worktree | branch | branch state | untracked files (sample) |
|---|---|---|---|
| `C:/tmp/claudewt/deadfeature-20260722` | `claude/orphan-cleanup-20260722` | merged | 2U: edit_pr1.py,edit_pr2.py |
| `C:/tmp/prwt/pr1151` | `review/pr1151` | merged | 1U: lint_full.txt |
| `~/_deploy-v2` | `DETACHED` | detached snapshot | 10U: .deploy-stage/[55-2hc]warfarev2_073v48co_v2-20260716.chernarus.pbo,box-complete.ps1,box-deploy-v2-final.ps1 |
| `~/_release-wave0722` | `release/wave0722` | unmerged, no PR | 3U: CHANGELOG-wave0722b.md,_out/_hash.txt,_out/wave0722b.takistan.pbo |
| `~/_wasp-n10` | `fable/fix-skin-jip-funds-clobber` | merged | 34U: packages/Newtonsoft.Json.13.0.3/.signature.p7s,packages/Newtonsoft.Json.13.0.3/lib/net20/Newtonsoft.Json.dll,packages/Newtonsoft.Json.13.0.3/lib/net20/Newtonsoft.Json.xml |
| `~/_wt-deploy0724b` | `DETACHED` | merged | 202U: .deploy-stage/wave0724a-live.pbo,.deploy-stage/x0724a/briefing.html,.deploy-stage/x0724a/briefing.sqf |
| `~/_wt-sideleak` | `claude/fix-side-leak-team-registration-20260724` | unmerged, no PR | 2U: codex_review_section.txt,lint_baseline_master.txt |
| `~/_wt-sideleak-review` | `DETACHED` | merged | 2U: lint_full.txt,wait_and_create_pr.sh |
| `~/_wt-victorytype` | `claude/fix-victory-announce-stacked-1329-20260724` | unmerged, no PR | 1U: pr-body-victorytype.md |
| `~/a2wasp-aicom-review` | `feat/client-fps` | unmerged, PR 40 CLOSED | 12U: _review/changed-files.txt,_review/CONSOLIDATED-REVIEW.md,_review/deploy-changed-since-mb.txt |
| `~/a2wasp-cutover` | `fable/v2-cutover` | merged | 2U: _scripts/patch_strategy_decap_gate.py,_scripts/resolve_aicommander_conflict.py |
| `~/a2wasp-fable-push` | `fable/377-flags-on` | merged | 200U: ..a2wasp-matchfam/.git,..a2wasp-matchfam/.gitattributes,..a2wasp-matchfam/.github/FUNDING.yml |
| `~/a2wasp-grpleak` | `test/group-leak-ultimate` | merged | 36U: _boxlive/arm-grpleak.ps1,_boxlive/boxscripts/deploy-when-empty.ps1,_boxlive/boxscripts/nightly_restart.ps1 |
| `~/a2waspwarfare/.claude/worktrees/agent-a0958abb56d1908a6` | `fable/aicom-air-bombs-20260726` | merged | 20U: .agent_tmp/.gitignore_note_only,.agent_tmp/body_ch_cc.txt,.agent_tmp/body_ch_rct.txt |
| `~/a2waspwarfare/.claude/worktrees/commander-qol-fixes` | `worktree-commander-qol-fixes` | unmerged, no PR | 1U: COMMANDER-QOL-BACKLOG.md |
| `~/a2waspwarfare/.claude/worktrees/release-command-center-b4a-merge` | `codex/release-command-center-b4a-merge` | unmerged, no PR | 2U: wasp-release-package-manifest/release-package-manifest.json,wasp-release-package-manifest/release-package-manifest.md |
| `~/a2waspwarfare/.claude/worktrees/release-package-c8ab` | `DETACHED` | detached snapshot | 8U: wasp-release-handoff-c8ab-current/release-handoff.json,wasp-release-handoff-c8ab-current/release-handoff.md,wasp-release-handoff-c8ab-current/release-package-manifest.json |
| `~/a2waspwarfare-42cfold` | `claude/cmdcon42c-fold` | unmerged, no PR | 5U: _pbo_out/cc42c-ch.pbo,_pbo_out/cc42c-tk.pbo,_verify/Test-WaspReleasePackage.ps1 |
| `~/a2waspwarfare-upgrade-queue` | `feat/upgrade-queue` | merged | 1U: tmp_old.sqf |
| `~/codex-fleet-20260702/wt-cx-178` | `fable/lane178-spectator-teams` | unmerged, PR 531 CLOSED | 3U: check_anchors.py,patch_lane178.py,verify_lane178.py |
| `~/codex-fleet-v2-20260703/wt-N1` | `codex/v2-n1` | merged | 2U: FLEET-ROSTER.md,prompt-N1.md |
| `~/codex-fleet-v2-20260703/wt-N2` | `codex/v2-n2` | merged | 2U: FLEET-ROSTER.md,prompt-N2.md |
| `~/codex-fleet-v2-20260703/wt-N3` | `codex/v2-n3` | merged | 2U: FLEET-ROSTER.md,prompt-N3.md |
| `~/codex-fleet-v2-20260703/wt-N4` | `codex/v2-n4` | unmerged, PR 703 CLOSED | 2U: FLEET-ROSTER.md,prompt-N4.md |
| `~/codex-fleet-v2-20260703/wt-N5N7` | `codex/v2-n5n7` | merged | 2U: FLEET-ROSTER.md,prompt-N5N7.md |
| `~/codex-fleet-v2-20260703/wt-N6N8` | `codex/v2-n6n8` | merged | 2U: FLEET-ROSTER.md,prompt-N6N8.md |
| `~/council-0725/grok-ideas` | `DETACHED` | merged | 4U: GROK-IDEAS-2.md,GROK-IDEAS.md,TASK-GROK-IDEAS-2.md |
| `~/council-0725/kimi-review` | `DETACHED` | merged | 6U: REVIEW-RESULTS-KIMI-2.md,REVIEW-RESULTS-KIMI-SEC.md,REVIEW-RESULTS-KIMI.md |
| `~/Documents/Codex/2026-07-02/c-users-game-codex-fleet-prompt-7/work/a2waspwarfare-lane178-unit-camera-ai-teams` | `codex/lane191-aa-active-air-gate` | merged | 3U: open-prs-all.json,open-prs-build84.json,open-prs-current.json |
| `~/fleet-lane-scratch/match-report-grok-run-20260720` | `DETACHED` | merged | 36U: _run/match-3324.waspstat,_run/match-3429.waspstat,_run/verify/primary-takistan-3324_frame0000.png |
| `~/wasp-aicom-review` | `review/aicom-deploy` | unmerged, PR 39 CLOSED | 12U: REVIEW-JOURNAL.md,review-findings/A-ai-commander.md,review-findings/B-economy.md |
| `~/wasp-armflags-wt` | `wasp/arm-flags-20260717` | merged | 1U: [55-2hc]warfarev2_073v48co_v2armed-20260717.chernarus.pbo |
| `~/wasp-staging-20260727` | `staging/update-20260727` | merged | 1U: pr-body.md |
| `~/wasp-tonight-fix-20260717` | `wasp-tonight-fix-20260717` | merged | 1U: _staged-pbo/[55-2hc]warfarev2_073v48co_v2fix-20260717.chernarus.pbo |
| `~/wave-0725` | `update/wave-20260725` | merged | 3U: .deploy-stage/[55-2hc]warfarev2_073v48co_wave0725a.chernarus.pbo,fold-driver.sh,fold-pr.sh |
| `~/worktrees/a2waspwarfare-codex-main-07260818-ap1-hc-topup` | `codex/codex-main-07260818-ap1-hc-topup` | merged | 5U: .hc-final-focused.log,.hc-topup-lint-final.log,.hc-topup-lint-final2.log |

</details>

### B4 — gutted scratch clones (13 worktrees) — recommend batch removal (owner sign-off)

Old fleet-lane scratch worktrees under a retired session scratchpad (`~/AppData/Local/Temp/claude/C--/5a728ab6.../scratchpad/`) plus `~/fleet-lane-scratch/.wt-deeppr-1547`. Fingerprint: 3,600–4,700 dirty entries each, **deletions only** (working trees were mass-gutted to reclaim space; ~500k lines "deleted" per clone), zero additions anywhere, HEADs merged. There is nothing salvageable — a deleted-files working tree carries no new content — but mass-deletion dirt did not meet this pass's strict (c) criteria, so they were left registered. One `git worktree remove --force` each once the owner confirms.

| worktree | branch | branch state | dirt (sample) | diffstat | lane topic |
|---|---|---|---|---|---|
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/a2wasp-rebase` | `codex/lane297-wikilink-buildref` | merged | 486T/0U: AGENTS.md,kick.docx,publicvariable.txt | 4681 files 526677- | lane297 wikilink buildref |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-d-396` | `codex/lane184-coastal-utility-boats` | merged | 487T/0U: AGENTS.md,kick.docx,publicvariable.txt | 4694 files 535010- | lane184 coastal utility boats |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-d-399` | `codex/lane138-request-commander-vote-shape-guard` | merged | 485T/0U: AGENTS.md,kick.docx,publicvariable.txt | 4503 files 504150- | lane138 request commander vote shape guard |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-d-443` | `codex/wiki-link-checker-exit-zero` | merged | 485T/0U: AGENTS.md,kick.docx,publicvariable.txt | 4504 files 504149- | wiki link checker exit zero |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-d-477` | `codex/lane193-unitqueue-respawn-reset` | merged | 485T/0U: AGENTS.md,kick.docx,publicvariable.txt | 4503 files 503754- | lane193 unitqueue respawn reset |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-d-546` | `codex/lane306-matchreport-production-gap-trace` | merged | 486T/0U: AGENTS.md,kick.docx,publicvariable.txt | 4530 files 509559- | lane306 matchreport production gap trace |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-d-616` | `codex/lane341-cannon-nudge-hostile-filter` | merged | 486T/0U: AGENTS.md,kick.docx,publicvariable.txt | 4532 files 511701- | lane341 cannon nudge hostile filter |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-d-664` | `codex/lane289-loadoutmanager-help-mirror` | merged | 486T/0U: AGENTS.md,kick.docx,publicvariable.txt | 4532 files 511743- | lane289 loadoutmanager help mirror |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-d-738` | `fable/attackwave-jip-nilguards` | merged | 486T/0U: AGENTS.md,kick.docx,publicvariable.txt | 4686 files 529272- | attackwave jip nilguards |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-lane295` | `codex/lane295-soak-cmdcon43-events` | merged | 486T/0U: AGENTS.md,kick.docx,publicvariable.txt | 4529 files 510860- | lane295 soak cmdcon43 events |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-lane30` | `codex/lane30-performance-probe-extensions` | merged | 642T/0U: SetTask.sqf,SetVehicleLock.sqf,AGENTS.md | 3618 files 393554- | lane30 performance probe extensions |
| `~/AppData/Local/Temp/claude/C--/5a728ab6-3b08-452a-b3f4-c40b5ed671cc/scratchpad/wt-lane49` | `codex/lane49-client-rpt-error-family-audit` | merged | 949T/0U: LINGOR.cs,NAPF.cs,AGENTS.md | 3619 files 393637- | lane49 client rpt error family audit |
| `~/fleet-lane-scratch/.wt-deeppr-1547` | `DETACHED` | unmerged, PR -	- | 490T/80U: AGENTS.md,BE-SETUP.md,kick.docx |  | DETACHED |

---

## Job 2 — unmerged branches (98 worktrees, HEAD not an ancestor of origin/master)

The ~29 estimate undercounted: 98 old worktrees sit on unmerged HEADs. Master churns fast enough
(squash merges, ~78 folds/day) that file-state comparison alone cannot tell "superseded" from
"valuable", so each branch was resolved against its **GitHub PR history**:

| PR state | count | meaning |
|---|---|---|
| OPEN | 21 | already in the merge-wave pipeline — do not fold from here |
| MERGED | 6 | shipped via squash; worktree+branch are leftovers |
| CLOSED (unmerged) | 46 | explicitly rejected or superseded by a re-cut |
| no PR ever | 19 | the real fold-candidate pool |
| detached HEAD | 6 | snapshots/assemblies, no branch to fold |

### Ranked fold candidates (no PR ever opened — never proposed, content not in master)

1. **`worktree-commander-qol-fixes`** (`~/a2waspwarfare/.claude/worktrees/commander-qol-fixes`, 2 ahead) — five commander-menu QoL fixes: dead Tasks tab, paratroop cooldown, dead loops, build count. One of two commits already patch-equivalent upstream; the other is not. Small, user-visible, low-risk. **Fold first.**
2. **`claude/fix-victory-announce-stacked-1329-20260724`** (`~/_wt-victorytype`, 1 ahead, +2 lines ×3 missions) — guard against stacked victory announcements (`server_victory_threeway.sqf`). Tiny targeted live-bug fix.
3. **`claude/fix-side-leak-team-registration-20260724`** (`~/_wt-sideleak`, 1 ahead, 3× `Init_Server.sqf`) — side-leak fix in team registration. Tiny, targeted.
4. **`claude/fix-hc-local-corpse-gc-20260724`** (`~/_wt-hcgc`) + **`codex/07241020-1-hc-corpse-gc`** (`~/a2waspwarfare/.worktrees/07241020-1-hc-corpse-gc`) — sibling HC corpse-GC lanes (TrashObject/HandleSpecial vs constants+lint test). Master has since landed the 014EFCF4 seated-corpse trash lineage — **compare against that lineage first**; these may be part of the still-unswept ~23-site cleanup, in which case they're valuable.
5. **`codex/main-07270548-2-perf-antistack-aicom-cleaner-round2`** (superpowers worktrees, 1 ahead, 20+/3-) — AntiStack mainLoop + Commander_Teams + droppeditems-cleaner chunking round 2, with a scheduler-slice test. Perf lane, small.
6. **`fable/lane194-victory-pack`** (`~/codex-fleet-20260702/wt-cx-194`, 3 ahead) — territorial hold-ticks + HQ-loss winner derivation + round-end stats flush, flag-gated (HOLDTICKS default 0), with review-fix commit. Sibling lanes from that pack landed; this one never got a PR.
7. **`codex/attackwave-reject-release-gameplay-20260725`** (`~/council-0725/lanes/attackwave-recut`, 1 ahead, 7 files) — attack-wave reject/release gameplay tweak; the u2-harden attackwave lanes are OPEN PRs, this recut is the gameplay half. Check overlap with #1399/#1401 before folding.
8. **`codex/pr119-hc-civ`** (Documents/Codex 06-28, 3 ahead, 1 cherry-equiv) — HC-on-CIV work predating merged/open HC-CIV lanes (#1596 open). Likely mostly superseded; skim for residue.
9. **`codex/07180826-1-map-clarity-toggles`** (1 ahead) — map-clarity client toggles + PR-harness test. Small, unclear demand.
10. **`codex/main-07260818-ap1-decap-strike-20260727`** (1 ahead, 15 files) — DECAP strike variant; the map-relative decap **gate** is OPEN as #1548. Verify the strike half isn't already inside #1548's lineage.

### Keep as-is (deliberate)

- **`feat/zargabad-buildout`** (`~/a2waspwarfare-zargabad`, 14 ahead, 813 files) — major WIP: Zargabad WDDM fortifications, per-side FOB doctrine, Bazaar-intel/power-grid proposals. Not a fold candidate; it's an active feature lane that needs its own release decision.
- **`lab/deleg-on-master-DO-NOT-MERGE`** — proving-ground soak recipes, explicitly never to merge.

### Superseded / abandoned process constructs (recommend discard, no fold)

- Release/deploy assemblies (content came *from* other branches): `deploy/morning-20260727` (integ-20260727), detached `wave0722e` bundle, `release/wave0722` (its unique lint bits — BAREEXIT — are verified present in master's `check_sqf.py`), `claude/cmdcon42c-fold`, `_deploy-v2` + `_wt-deploy0724b` staging snapshots.
- The June "release command center" saga: `codex/release-command-center-20260630` (PR #125 CLOSED, 140 ahead), `codex/release-command-center-b4a-merge` (99 ahead), detached `release-merge-scratch` (53 ahead) and `release-package-c8ab` (125 ahead). Superseded by the current merge-wave + release-materials process.
- `codex/071919-gdir-capability` (63 ahead, July 19) — pre-V2 GUER Director capability work; GDIR was rebuilt and shipped since. Salvage-skim only.
- Review scratchpads: `review/aicom-deploy` (PR #39 closed), `feat/client-fps` (PR #40 closed), `pr-1320-review`, `.wt-deeppr-1547`, `review-wasp-khesanh-seam-20260718`, `fable/hc4-box-provision` (PR #1462 MERGED — shipped).

### Open PRs (21) — in the pipeline, hands off

| PR | branch | ahead | title | worktree |
|---|---|---|---|---|
| #1536 | `claude/earplugs-full-sfx-20260728` | 1 | fix(earplugs): duck all effect SFX and restore effects volume on toggle-off | `C:/tmp/claudewt/earplugs-full-sfx-20260728` |
| #1543 | `codex/fob-v1-engineer-20260728` | 1 | feat(fob): forward operating base v1 - engineer/repair-truck built FOB [flag WFBE_C_STRUCTURES_FOB default 1] | `C:/tmp/claudewt/fob-v1-engineer-20260728` |
| #1596 | `fable/hc-civ-magnet-20260729` | 1 | fix(hc): seat headless clients on CIV natively - swap HC slots to the lowest playable ids | `C:/tmp/claudewt/hc-civ-magnet-20260729` |
| #1598 | `fable/teams-epilogue-nilguard-20260729` | 2 | fix(aicom): seed _eligible/_pick epilogue reads on the server-local founding path (live RPT x47 pairs) | `C:/tmp/claudewt/teams-epilogue-20260729` |
| #1597 | `fable/townscan-dynrange-nilguard-20260729` | 3 | fix(townscan): nil-guard wfbe_active*/wfbe_active_air reads killing _dynRange (live RPT spam x169k) | `C:/tmp/claudewt/townscan-dynrange-20260729` |
| #1545 | `codex/main-07270715-2-usv-aa-role-refill-20260728` | 2 | fix(usv): refill missing flotilla role | `~/.codex-worktrees/fleet-lane-scratch/codex-main-07270715-2-usv-aa-role-refill-20260728` |
| #1547 | `codex/guer-airdef-slice-chernarus-20260728` | 1 | fix(airdef): bound enemy-air scan slices | `~/.codex-worktrees/fleet-lane-scratch/codex-main-07270840-2-guer-airdef-slice-chernarus-20260728` |
| #1544 | `codex/main-07280026-2-fortif-unbuildable` | 1 | fix: preserve fortification preview color | `~/.config/superpowers/worktrees/a2waspwarfare/codex-main-07280026-2-fortif-unbuildable` |
| #1399 | `claude/u2-harden-attackwave-details-20260725` | 1 | fix(security): bind ATTACK_WAVE_DETAILS activation to requester's own side | `~/build0725/harden-attackwave-details` |
| #1401 | `claude/u2-harden-attackwave-init-20260725` | 1 | fix(security): re-derive ATTACK_WAVE_INIT discount input from server supply | `~/build0725/harden-attackwave-init` |
| #1395 | `claude/u2-harden-convoy-pay-20260725` | 1 | harden(sec): sidepatrol-convoy-stop requires a matching active-patrol record | `~/build0725/harden-convoy-pay` |
| #1404 | `claude/u2-harden-supplymission-20260725` | 2 | harden(economy): server-owned supply-mission payout, watcher cap, UID derivation | `~/build0725/harden-supplymission` |
| #1436 | `codex/sidepatrol-registry-authority-20260725` | 1 | fix: make side-patrol registry and convoy payout server-authoritative | `~/council-0725/lanes/fix1395` |
| #1464 | `fable/aicom-lategame-teleport-20260725` | 1 | feat(aicom): late-game teleport of base-idle AI teams to friendly frontline towns [flags, default 0] | `~/council-0725/lanes/lategame-tp` |
| #1548 | `codex/main-07260818-ap1-decap-gate-maprelative-20260728` | 1 | fix(aicom): map-scale DECAP enemy-town gate | `~/fleet-lane-scratch/.worktrees/codex-main-07260818-ap1-decap-gate-maprelative-20260728` |
| #1530 | `codex/main-07270840-1-usv-coastal-tag-init-race-20260727` | 1 | fix: wait for populated USV town roster | `~/fleet-lane-scratch/.worktrees/codex-main-07270840-1-usv-coastal-tag-init-race-20260727` |
| #1537 | `codex/main-07270548-1-manned-defences` | 1 | fix: preserve static-defense crew fallback at group cap | `~/worktrees/a2waspwarfare-codex-main-07270548-1-manned-defences` |
| #1540 | `codex/codex-main-07271028-1-teamsfound-chunking` | 1 | fix(aicom): chunk founding hot scans | `~/worktrees/a2waspwarfare-codex-main-07271028-1-teamsfound` |
| #1588 | `fable/airlift-v2` | 1 | feat(aicom): implement AICOM airlift LIFT at the in-loop delivery point [flag WFBE_C_AICOM_AIRLIFT_V2 default 0] | `~/wt-airlift-v2` |
| #1589 | `fable/air-quickstart-v2` | 1 | feat(aicom): HC-safe single-team air quickstart at founding [flag WFBE_C_AICOM_AIR_QUICKSTART default 0] | `~/wt-quickstart-v2` |
| #1584 | `fable/west-jet-templates` | 1 | feat(aicom): add WEST fixed-wing team templates to USMC roster [flag WFBE_C_AICOM_WEST_JETS default 0] | `~/wt-west-jets` |

### Merged PRs (6) — shipped; worktree + branch are leftovers

| PR | branch | ahead | title | worktree |
|---|---|---|---|---|
| #1195 | `codex/match-report-overhaul-20260720` | 1 | fix(report): repair Zargabad control map and faction layout | `~/.config/superpowers/worktrees/a2waspwarfare/codex-match-report-overhaul-20260720` |
| #1084 | `codex/agent-docs-lint-gate-sync` | 1 | fix(tooling): AGENTS.md lint-gate parity — add DBLBOM + TRAILCOMMA (AgentDocsSync) | `~/_wasp-agentdocs-sync` |
| #834 | `fable/lint-dblbom-gate` | 1 | feat(lint): DBLBOM gate for doubled/stray UTF-8 BOMs + #832 incident producer report | `~/_wasp-dblbom-gate` |
| #1091 | `codex/town-init-waits-remaining-20260713` | 1 | fix(town-init): bound remaining town initialization waits | `~/_wasp-town-init-waits-remaining-20260713` |
| #804 | `fable/trailcomma-lint` | 1 | feat(lint): TRAILCOMMA rule - trailing comma before ] in SQF array literals | `~/_wasp-trailcomma` |
| #1462 | `fable/hc4-box-provision` | 10 | feat(ops): 4-HC box provisioning bundle (stacked on #1456) | `~/a2waspwarfare/.worktrees/fable-hc34` |

### Closed PRs (46) — rejected or superseded by re-cuts

<details><summary>46 rows (PR, branch, commits ahead, title)</summary>

| PR | branch | ahead | title |
|---|---|---|---|
| #1292 | `codex/07221740-1-unstuck-escalation-gap-20260722` | 2 | fix(aicom): bridge repeated patrol wedges into recovery |
| #1121 | `codex/wasp-fob-build-v1` | 2 | feat(fob): forward FOB v1 - repair-truck built tent+antenna (CORRECTED 2026-07-17) [flag WFBE_C_STRUCTURES_FOB default 0] |
| #40 | `feat/client-fps` | 10 | Client FPS: WF-menu FPS button + adaptive VD picker, marker-loop map-gating, terrain-grid + hot-loop fixes |
| #35 | `deploy/2026-06-12-aicom-experital` | 3 | Deploy review (Claude lead): AICOM experital bundle → master |
| #115 | `claude/match-report-video` | 45 | Tools/MatchReport: data-driven post-match report video generator |
| #722 | `claude/tp8-ai-fuel` | 1 | feat(tp8): AICOM infinite-fuel — WFBE_C_AICOM_INF_FUEL (default 0) |
| #125 | `codex/release-command-center-20260630` | 140 | [codex] Prepare WASP release command center |
| #3 | `docs/developer-wiki-claude` | 70 | docs(wiki): Claude review — round 1 deepening + round 2 adversarial deep-review |
| #1349 | `codex/bughunt-town-defence-20260725` | 1 | fix(aicom): retain town holder under active attack |
| #1373 | `claude/u2-1350-wave-latch-20260725` | 2 | fix(aicom): prevent overlapping attack-wave timers [#1350 rework: latch release] |
| #1394 | `claude/u2-harden-teamupdate-20260725` | 1 | security(pvf): bind RequestTeamUpdate array form to requester side [flag WFBE_C_SEC_HARDENING default 0] |
| #195 | `fable/lane120-support-service` | 1 | [fable] Lane 120: Client_Support* service fixes (V5/V10) |
| #531 | `fable/lane178-spectator-teams` | 2 | [Lane 178] Add read-only AI Teams section to unit camera listbox |
| #539 | `fable/lane183-t34-relic` | 2 | feat(lane183): T-34 relic contested vehicle [WFBE_C_T34_RELIC default 0] |
| #527 | `fable/lane188-respawn-pack` | 4 | [lane188] Respawn-handler 4-pack: GUER fallback safe, SkinSelector nil-guard, gear-cost default, mode-1 denial |
| #524 | `fable/lane190-patrol-contested` | 1 | [Lane 190] Gate patrol->defense flip on contested towns (WFBE_C_TOWNS_PATROL_CONTESTED_ONLY) |
| #525 | `fable/lane191-aa-gate` | 1 | feat(191): invert AA gate - AA now spawns under air threat [WFBE_C_TOWN_AA_GATE_FIX default 1] |
| #522 | `fable/lane192-193-safety-pair` | 3 | [192+193] Safe dismiss-AI vehicle kill + respawn unitQueu reset |
| #519 | `fable/lane196-scud-reachability` | 1 | [Lane 196] feat: insert Air L4+L5 in AI_ORDER to make SCUD reachable |
| #520 | `fable/lane201-upgrade-guard` | 4 | [Lane 201] feat(201): Server_AI_Com_Upgrade enabled guard - skip disabled upgrade slots |
| #534 | `fable/lane202-arty-cooldown` | 3 | [Lane 202] feat: shared side arty cooldown (WFBE_C_ARTY_SHARED_COOLDOWN) |
| #538 | `fable/lane206-comms-relay` | 2 | [Lane 206] feat: comms-relay side objective — Land_Antenna mast + IcbmTelRecon sweep |
| #287 | `fable/aicom-recon-drone-wildcard` | 2 | [fable] AICOM recon-drone wildcard W25/W26 (Ka-137/Pchela, flag, default 0) |
| #275 | `fable/exploit-salvage-stealth` | 1 | [fable] Exploit fixes — salvage side-gate + stealth-flag broadcast (lanes 75/78) |
| #278 | `fable/pvf-build-repair-authority` | 1 | [fable] DR-6: build/repair PVF authority guards (RequestStructure/Defense/MHQRepair) |
| #289 | `fable/downed-pilot-race` | 3 | [fable] Downed-pilot rescue/capture race (flag, default 0) |
| #274 | `fable/pvf-input-hardening` | 1 | [fable] PVF input hardening — reject malformed/non-player payloads (lanes 136/140/141/142) |
| #229 | `fable/tier3-foundations` | 1 | [fable] Tier 3 foundations — perf/leak hygiene (gameplay-neutral by default) |
| #309 | `fable/tk-land-hvt-scud-site` | 3 | [fable] TK land-HVT: capturable SCUD-site objective (TK parity, default ON on Takistan) |
| #360 | `fable/ambient-traffic` | 3 | feat(civ-coastal-traffic): ambient civ boat + car spawner [WFBE_C_AMBIENT_TRAFFIC default 0] |
| #368 | `fable/guer-road-ambush` | 2 | feat(b2-road-ambush): GUER G3 Road Ambush - AT/MG team between contested towns |
| #365 | `fable/an2-smuggler` | 3 | feat(an2-smuggler): neutral AN-2 smuggler run with shoot-down bounty |
| #370 | `fable/arty-cache-objective` | 3 | feat(t34): Arty Cache - capturable neutral static-gun side-objective (Chernarus) |
| #373 | `fable/wf-clock-readout` | 2 | feat(wf-clock-readout): add RHUD time-of-day row (HH:MM + Dawn/Day/Dusk/Night) |
| #357 | `fable/wildcard-irondome` | 3 | feat(avenger-sam-wildcard): revive inert W14 Iron Dome wildcard card behind flag |
| #703 | `codex/v2-n4` | 1 | docs(v2): 427-434 Utes Invasion spec pack [Codex sprint] |
| #1439 | `codex/guerfob-reaper-exempt-20260725` | 1 | fix(guer): exempt FOB trucks from the empty-vehicle reaper so Build-FOB survives dismounting |
| #1453 | `codex/supply-stagnation-standalone-20260725` | 1 | fix(economy): exempt AI-commanded sides from supply stagnation — standalone re-cut of #1449 + #1450 |
| #118 | `codex/hc-civ-slotting-live` | 1 | [codex] harden HC civilian slot registration |
| #1102 | `codex/hetzner-72h-installer` | 1 | feat(ops): add transactional Hetzner installer controller |
| #1282 | `codex/07221740-1-antistack-db-extension` | 1 | fix(antistack): log database extension reachability at init |
| #1136 | `codex/khesanh-deck-seam-20260718` | 2 | fix(naval): close elongated Khe Sanh deck seam |
| #1150 | `codex/rc2-miksuu-radio-full-removal-20260719` | 50 | fix(radio): remove custom Miksuu radio and tower |
| #39 | `review/aicom-deploy` | 3 | A2 pre-merge review: runtime/logic/QoL fixes + structure-refund proposal |
| #1509 | `codex/main-07260818-ap1-guer-director-qrf-trigger-20260727` | 1 | fix(guer-director): fire QRF contracts on active towns |
| #1594 | `fable/spectator-v1` | 2 | feat(spectator): UID-allowlisted free-camera spectator overlay [flag WFBE_C_SPECTATOR default 1] |

</details>

---

## Discovered issues

1. **CRITICAL — corrupt ref breaks all fetches.** `refs/heads/fable/caster-civ-slot-20260731` points at a missing object (`a748b7e…`). Every `git fetch` in every worktree fails with *"bad object refs/heads/fable/caster-civ-slot-20260731 … did not send all necessary objects"*. This is the branch of the **protected** `caster-slot-20260731` lane, so nothing was touched — but the lane's tip may be unrecoverable locally. Owner: check that lane's state, run `git fsck --no-dangling`, and either restore the ref from the lane's reflog/remote or delete it once the lane is closed out. (This pass verified `origin/master` freshness via `ls-remote` instead.)
2. **EOL-churn epidemic.** ~120 lanes show ` M` on the generated LoadoutManager trio (`EASA_Init.sqf`, `Common_ReturnAircraftNameFromItsType.sqf`, `Common_BalanceInit.sqf`) across mission folders with an **empty filter-aware diff** — pure LF/CRLF churn. Every scan, PR harness, and human reading `git status` pays for this. Fix at the source: make the LoadoutManager generator emit the `.gitattributes`-normalized EOL (or add explicit `eol=` attributes for generated SQF), then one normalization commit.
3. **Nested worktree inside the main checkout.** `origin/release/wasp-aicom-recovery-20260727` — a registered worktree created *inside* the main repo under an untracked `origin/` directory (botched `worktree add` path resolution; 6,781 files). Left untouched (it is also the `release/wasp-aicom-recovery-20260727` checkout at `~/a2wasp-smlfix`'s sibling registration). Owner: relocate or remove deliberately; also the stray `~/a2waspwarfare/..a2wasp-matchfam`-style dot-dot-prefixed clones under other checkouts (one was removed this pass after verification).
4. **Registered worktrees inside disposable session scratchpads.** 20 registrations live under `~/AppData/Local/Temp/claude/<session>/scratchpad/` — temp dirs that outlive their sessions and now hold ~50 GB-scale gutted clones (B4 table). Future lanes should use durable worktree roots (`C:/tmp/claudewt`, `~/a2waspwarfare/.worktrees`).
5. **Orphaned Git Bash processes** from Jul 29/30 lane tooling were found still alive during the sweep (known pileup pattern); two stray `find` scans from this pass's own tooling were killed. Worth a periodic `ps -W | grep bash` cull.

## Suggested follow-ups (owner sign-off, one-liners)

```bash
# after reviewing B4: remove the 13 gutted scratch clones
# (git worktree remove --force <path> for each row in the B4 table)

# delete now-orphaned merged branches of the 76 removed worktrees
git for-each-ref refs/heads --format='%(refname:short)' | while read b; do
  git merge-base --is-ancestor "refs/heads/$b" origin/master 2>/dev/null && \
  [ -z "$(git worktree list --porcelain | grep -F "branch refs/heads/$b")" ] && echo "$b"
done   # review the list, then: git branch -d <each>

# prune any registrations whose dirs later disappear
git worktree prune -v
```

---

## Appendix A — the 73 documented (c)-class removals

Column key: `treal/tdup` = tracked files really-changed / duplicating master; `versq` = version.sqf churn; `ujunk/udup` = untracked junk / untracked duplicates of master; `eolnoise` = status-dirty files with empty filter-aware diff.

<details><summary>73 rows</summary>

| worktree | branch | dirt breakdown |
|---|---|---|
</details>
