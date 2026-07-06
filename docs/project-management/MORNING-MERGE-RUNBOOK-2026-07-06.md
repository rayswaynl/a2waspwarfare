# Morning Merge Runbook — 2026-07-06

Prepared overnight (Agent A). **Plan only — nothing merged.** Execute batches in order; within a batch, only parallelize PRs touching independent files. All tonight's PRs are drafts — undraft before merge.

**Summary:** Morning merge runbook for 2026-07-06. 57 PRs total (49 triage candidates + 8 tonight-verified). All 8 tonight-verified a2waspwarfare PRs (#718/#719/#720/#721/#723/#728/#729/#730) confirmed MERGEABLE + CI SUCCESS — all are drafts, undraft each before merge. Two triage MERGE-CANDIDATEs went CONFLICTING since triage: #328 (perf probes) and #338 (client RPT errors) — both need rebase before landing. All other triage MERGE-CANDIDATEs with triage UNKNOWN mergeability are now confirmed MERGEABLE. Miksuu #60 and #61 both MERGEABLE + full CI green; #61 is stacked on #60. Plan is 10 ordered batches: B-01 (tooling/lint, lowest risk) through B-10 (Miksuu/main). Execute in sequence; do not merge in parallel within a batch unless files are confirmed independent.

## Batches (low-risk → high-risk)

| Batch | Theme | PRs | Mergeability note |
|---|---|---|---|
| B-01 | Tooling and lint | #312, #441, #621, #629, #632 | All MERGEABLE, no CI (tooling-only) or CI SUCCESS. Zero mission-file risk. #441 unlocks #633 (rebase after). Undraft all before merge. |
| B-02 | Docs and specs | #651, #661, #715, #707, #700, #712 | All MERGEABLE + CI SUCCESS. Docs/spec files only — no runtime impact. Merge #707 before #700 (authoritative AICOM inventory supersedes #700's partial copy). #715 GUER Director spec: merge now, answer D1+D2 as follow-up comments. #701 and #702 held pending owner questions (see Hold section). |
| B-03 | Client UI fixes | #341, #401, #549, #554, #560, #563, #623, #635 | All MERGEABLE, CI none (older) or SUCCESS. Client-side only; no server/AI commander dependency. Undraft all before merge. |
| B-03b | Tonight's UI batch | #719, #721, #730 | All MERGEABLE + CI SUCCESS. Tonight's verified. All drafts — undraft before merge. #730 is default-off flag. |
| B-04 | Server correctness fixes | #284, #288, #293, #336, #400, #567, #569, #660, #662 | All MERGEABLE. #284/#288/#293 have no CI (older PRs) — owner FOLD-89 tagged. Close #280 before merging #284. Undraft all before merge. |
| B-05 | Perf throttles and load-shedding | #319, #545, #558, #562, #572, #663, #720 | All MERGEABLE, CI none (older) or SUCCESS. Client + server perf constants; AI-commander-independent. #319: spot-check construction threshold preservation before merge. #720 tonight-verified (high-impact ZG error loop fix). Undraft all. |
| B-06 | Stacked server pairs (ordered) | #551, #573, #566, #589 | Two 2-PR dependency chains. Merge #551 first, then rebase #573 onto build84 and merge. Merge #566 first, then rebase #589 onto build84 and merge. Do not merge ② against old feature branch. |
| B-07 | Telemetry and soak instrumentation | #327, #556, #579, #718, #728 | All MERGEABLE. #327 no CI (older), others CI SUCCESS. Observation-only probes; no behavior change. #718 and #728 tonight-verified. After #579 merges, rebase #590 onto build84 and merge standalone. |
| B-08 | AI commander and gameplay fixes | #510, #513, #557, #575, #581, #582, #592, #595, #616 | All MERGEABLE + CI SUCCESS. Verify individually — touches AI logic. Close #553 before merging #557. After #575 merges: rebase #578. After #581 merges: rebase #584. |
| B-09 | Default-off gameplay features and content | #630, #664, #723, #729, #574 | #630/#664/#723/#729 all MERGEABLE + CI SUCCESS (undraft + merge). #723 and #729 tonight-verified. #574 HELD — stacked on #338 which is now CONFLICTING; rebase #338 first, then rebase #574 onto build84 and merge. |
| B-10 | Miksuu PRs (target: main, different repo) | #60, #61 | Both MERGEABLE + full CI SUCCESS (all 3 jobs: web/bot/dep-audit). Merge #60 first (fixes pre-existing main CI drift since 2026-07-04). Then rebase #61 onto main and undraft + merge. After #60 lands, Miksuu #49 (admin nav) is also unblocked and can merge immediately. |

## Close before merge / holds / conflicts

- **CONFLICTING (rebase first):** #328, #338, #713

"CLOSE BEFORE MERGE: #280 (close before #284), #553 (superseded by #557). HOLD / OWNER DECISION: #701 (confirm CH node count 43 vs 40+3 before treating as authoritative), #702 (verify movement/escalation specs against 2026-07-05 town-first ruling before merge), #713 (DECAPITATE doctrine conflict — needs owner ruling + rebase; do not merge). CONFLICT DETAIL: #328 and #338 were MERGEABLE at triage (2026-07-05) but are now DIRTY on build84-cmdcon36; both need rebase before landing. #338 conflict also blocks #574 (stacked). STACKED CHAIN REBASE QUEUE (execute immediately after parent merges): #441→#633, #551→#573, #566→#589, #575→#578, #579→#590, #581→#584, #338(post-rebase)→#574, Miksuu #60→#61+#49."