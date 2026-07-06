# AICOM V2 Git Archaeology

Source status: local `git status --short` ran once and showed only `FLEET-ROSTER.md` and `prompt-N1.md` untracked. Subsequent `git`, `gh`, and broad shell reads were blocked by Windows sandbox error 206. This report is therefore a final-form archaeology matrix with the exact commands and expected rows the orchestrator must verify before publishing.

## Required Commands

```powershell
git log --all --oneline -- "*/AI/Commander/*"
git branch -r | rg -i "aicom|b3[6-9]|b[4-8][0-9]|cmdcon|claude/b69|feat/ai-commander|quad-ai-commander|experital"
git ls-tree -r upstream/v24042025 -- "*/Server/AI/Commander/*"
git diff --stat master..origin/claude/b69 -- "*/Server/AI/Commander/*"
```

Expected upstream delta verdict: zero `Server/AI/Commander/` files on `upstream/v24042025` unless the verification command proves otherwise. If non-zero, update the Benny section in external prior art.

## Branch/Build Chain Matrix

| Build/branch | HEAD sha/date | Merge status | Files changed | Design intent | Reverted or blocked | Survived into master |
|---|---|---|---|---|---|---|
| B36 build-grace | VERIFY | Historical | Commander boot/build grace | Avoid early starvation while structures/teams initialize. | Unknown. | Bootstrap guard concept, if present. |
| B57 soak | Deployed 2026-06-20, sha VERIFY | Historical deployed | `AI_Commander_Teams`, `Produce`, `Strategy`, `AI_Commander`, constants, `Common_RunCommanderTeam` | Larger HC-founded teams, concentration, last-stand/HQ-strike, retreat/reform, telemetry. | Skipped branch copies of `initJIPCompatible`, `Init_Towns`, PVF handlers, color clobber. | Founding pad, concentration, last-stand/HQ-strike, snappier team loop, telemetry. |
| B66 troop-truck | VERIFY | Historical/branch | Commander transport or production paths | Improve movement/logistics of troop transport. | VERIFY if empty-truck/stranded-survivor failures caused revert. | Any transport picker guard that remains. |
| B68 / PR #43 live soak | VERIFY | PR/live soak | AICOM behavior and soak instrumentation | Prepare live behavior evidence before B69. | VERIFY. | Soak analyzer patterns or constants. |
| B69 / PRs #44-#51 | `origin/claude/b69` VERIFY | Branch/PR series | Strategy, autonomy, HC merge, HQ strike, roadmap sketches | Autonomy and B69 recommended items. | Some branch-only items blocked by A2 safety, locality, or duplicate live deltas. | Items already merged by B74/cmdcon must not be re-proposed. |
| B71 harvest | VERIFY | Historical | Harvest of B69 sketches | Pull safe branch ideas without adopting unsafe init paths. | VERIFY. | Roadmap language and selected guards. |
| B72 harvest | VERIFY | Historical | Further AICOM stabilization | Same. | VERIFY. | VERIFY. |
| B73 harvest | VERIFY | Historical | Further AICOM stabilization | Same. | VERIFY. | VERIFY. |
| B74.1 | VERIFY | Historical | MHQ relocation and command pressure | Add min-advance or abort hygiene. | VERIFY. | B74 min-advance guard referenced by roster lane 418. |
| B74.2 | VERIFY | Historical | Follow-up relocation/strategy fix | Stabilize B74.1. | VERIFY. | VERIFY. |
| command-center-instruct | VERIFY | Branch | Command-center instruction loop | Player/admin steering of commander. | VERIFY if UX/locality risk. | Any instruction parsing that is current. |
| PR #125 | VERIFY | Draft/PR | Autonomy audit matrix | Audit V1 behavior and candidates. | VERIFY. | Matrix items feed B69 consolidation. |
| PR #126 | VERIFY | Draft/PR | Autonomy audit/fix matrix | Same. | VERIFY. | Matrix items feed B69 consolidation. |
| `feat/ai-commander` | VERIFY | Branch | Broad AI commander fork | Early experimental commander. | Must be audited for A3 syntax and stale join traps. | Only concepts explicitly listed in keep-list. |
| `quad-ai-commander` | VERIFY | Branch | Multi-commander or split-brain experiment | Increase autonomy/parallelism. | High locality risk unless single server namespace. | Likely concepts only. |
| `aicom-experital` | VERIFY | Branch | Active experimental line around B57 | Production soak source. | VERIFY stale generated mirrors. | Many B57 behaviors. |
| `claude/b69` | VERIFY | Branch | B69 sketch implementation | Autonomy packages. | Requires diff against master to avoid duplicates. | Open V2 candidates only after classification. |

## Revert-Lesson Ledger

| Lesson | Evidence | V2 implication |
|---|---|---|
| Do not copy old init/bootstrap code blindly. | B57 deliberately skipped branch `initJIPCompatible` and `Init_Towns` because they carried the sleep/JIP trap. | V2 branch mining must be surgical by function, not whole-file. |
| HC-founded teams bypassed Produce floor. | B57 root cause: `AI_Commander_Produce.sqf` skipped `wfbe_aicom_hc` teams, which were 100 percent of live teams. | Founding path owns template pad and `TEAM_FOUNDED|v3`. |
| Static comments can be stale. | B57 constants comment referenced old concentration value. | Analyzer/spec must use source assignments, not prose headers. |
| Branch-only radio helpers may not exist. | B57 deleted non-existent `WFBE_CO_FNC_RadioMessage` call. | Every mined branch call must be symbol-checked. |
| Flag-off fallback matters. | AGENTS master-flag rule. | V2 cannot replace V1 in-place. |

## Verification Output to Paste After Orchestrator Mining

| Command | Required paste |
|---|---|
| `git log --all --oneline -- "*/AI/Commander/*"` | Full commit list or attached artifact path. |
| `git branch -r ...` | All AICOM branch names plus HEAD sha. |
| `git ls-tree upstream/v24042025` | Exact upstream delta verdict. |
| `git diff master origin/claude/b69` | Branch-only file list and summary. |

## Builder Rule

No V2 implementation may cite a branch idea unless this file's corresponding row has a verified HEAD sha, changed files, and an explicit "survived", "open candidate", or "rejected" classification.
