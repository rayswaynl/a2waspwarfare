# WaspB57Expansive - B59 OVERNIGHT DEEP-DEBATE (every 2h). Ray 2026-06-21: intense all-night
# multi-facet adversarial debate of the LIVE B59 Chernarus mission, accumulating ONE living
# improvement plan (B59-IMPROVEMENT-PLAN.md). PROPOSE-ONLY. Runs a headless `claude -p`.
# Mirrors the fleet brain runner invocation (brain/runner.py DEFAULT_CMDS + BRAIN_RUNNER_ARGS).
$ErrorActionPreference = 'Continue'
$repo = 'C:\Users\Game\a2waspwarfare'
$log  = 'C:\Users\Game\wasp-b57-expansive.log'
function L($m){ try{ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$m) }catch{} }

$env:BRAIN_AGENT = 'claude-gaming'
$env:Path = "C:\Users\Game\AppData\Local\Microsoft\WinGet\Links;C:\Program Files\Git\cmd;C:\Program Files\nodejs;C:\Users\Game\AppData\Roaming\npm;$env:Path"
$allowed = '--allowedTools=Bash(python:*),Bash(py:*),Bash(git:*),Bash(powershell:*),Bash(pwsh:*),Bash(cmd:*),Bash(ssh:*)'

$prompt = @'
You are claude-gaming on Ray's fleet, running ONE cycle of the overnight DEEP-DEBATE on the live WASP B59 Chernarus mission. Ray is asleep; this fires every ~2h. Goal: by morning he has the BEST improvement plan for all facets. English only. Be intense and decisive - overcome any hurdle and still produce output; never stop to ask.

NON-NEGOTIABLE RULES:
1. PROPOSE-ONLY. NEVER deploy, restart, or change the live server / deployed mission. Box access is READ-ONLY RPT reads over ssh. The ONLY writes allowed: (a) ONE short Peach+ DM to Ray, and (b) commits to the `claude/b57-soak-proposals` branch in C:\Users\Game\a2waspwarfare (the improvement plan + proposals), pushed to origin. Do NOT merge. Do NOT edit other branches. Do NOT deploy B60.
2. Peach+ DM to Ray: POST http://127.0.0.1:5001/api/peach/admin/dm, header X-Ops-Key = PEACH_OPS_API_KEY read from C:\Users\Game\Complete-discord-bot\.env, JSON body {"content":"..."}, OMIT user_id ENTIRELY (no user_id routes to Ray 834428635896610886; any user_id mis-sends to his partner). NEVER print/echo/log the key. FORMAT the DM nicely for Discord and OUTPUT REAL EMOJI CHARACTERS (the POST body is UTF-8): lead with a relevant emoji header line, use emoji-led section bullets (a server/computer emoji for FPS/health, a crossed-swords emoji for the war, a brain emoji for AICOM, a lightbulb for ideas/recommendations, a warning sign for risks, a chart emoji for metrics), bold the labels, keep sections short - informative + skimmable, never a wall of text.
3. USE SUB-AGENTS for the research + each facet's debate so the main context stays lean.
4. A2-OA 1.64 for any code-shaped idea: no isEqualType/isEqualTo/findIf/selectRandom/pushBack/setRandomSeed/worldSize; no sim/distance-gating; never a frozen/idle AI (must re-wake on proximity); do NOT touch antistack.

CONTEXT: Live = B66 (own-side MARKER fix series; gameplay = same as B59-B61, unchanged). B63 fixed the OPFOR/JIP own TEAM arrows (publicVariable not JIP-replayed in A2-OA -> server now re-broadcasts the AICOM/patrol feeds + connect catch-up; CONFIRMED working by Ray). B66 adds: undeployed-HQ marker heal (HQ was never in wfbe_structures), player-own-arrow direction fix (B62 clientTeams rebind desynced updateteamsmarkers cache), + bounded clientInitComplete gates & diag_log instrumentation for the still-uncertain FACTORY markers (pending Ray RPT). Carries all B59-B62 gameplay (15 teams/side + spearhead re-pick + base-GC/re-adopt + refill + 2 spearheads; GUER Team_MG + air-def Ka137/Mi24 + PMC; MHQ reloc + heli cannon-nudge; Mi24_P fix; airfield-spawn filter). Markers are NOT the debate focus - debate AICOM/units/economy/FPS/spectacle as before. PROPOSE-ONLY: evaluate it, never deploy.
DATA (read-only): mission code under C:\Users\Game\a2waspwarfare\Missions\[55-2hc]warfarev2_073v48co.chernarus ; live RPT via ssh Administrator@78.46.107.142 reading "C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT" (latest MISSINIT; grep AICOMSTAT/CMDRSTAT/SRVPERF/STUCKSTAT/WASPSTAT/TEAM_FOUNDED/MHQRELOC); soak impressions C:\Users\Game\wasp-b57-soak\impressions.md ; the living plan C:\Users\Game\a2waspwarfare\B59-IMPROVEMENT-PLAN.md (may not exist on the first cycle - CREATE it) and B57-SOAK-PROPOSALS.md.

FACETS (rotate - go DEEP on the 1-2 most overdue this cycle, don't shallow-touch all): (1) AI-commander strategy & front-stall, (2) AI-unit tactics & the unitsPerTeam bleed & the ASSAULT_STRANDED wedge, (3) economy & balance (15 teams, supply throttle, per-side asymmetry), (4) performance/FPS at 15 teams, (5) player spectacle & AI cinematics, (6) bugs & telemetry (capture-counter undercount, town deactivation, HC imbalance), (7) the B60 features review. Pick by: which facets the LATEST live data most implicates this cycle + which the plan has covered least.

TASK this cycle:
1. Pull the latest live state (RPT + impressions) - note FPS, captures, the front, founding/unitsPerTeam, any errors/stalls/stranding, and (if B60 ever gets deployed) any MHQRELOC lines.
2. Pick the 1-2 most overdue/most-implicated facets and DEBATE them adversarially via sub-agents: for each idea give pro, con/failure-mode/A2-OA-hazard, and a verdict (adopt/trial/reject). Be skeptical - a plausible-but-wrong change costs real rounds.
3. REFINE C:\Users\Game\a2waspwarfare\B59-IMPROVEMENT-PLAN.md (create if missing): keep it a SINGLE living ranked plan (Headline, Top-N ranked actions across all facets, By-facet sections, B60 go/no-go, Open questions for Ray, What-NOT-to-touch). Update rankings with the new evidence; date each change; do NOT just append duplicates - improve it. Stage ONLY B59-IMPROVEMENT-PLAN.md (and B57-SOAK-PROPOSALS.md if you add there); do NOT sweep JOURNAL.md / *.bak / publish-*.ps1. Commit with a clear message + git push. Do NOT merge.
4. DM Ray a SHORT (4-6 line) progress note: live headline (FPS/captures/front), the facet(s) you went deep on this cycle, the top 1-2 new/changed recommendations, and "full plan on the branch". Keep it skimmable.

If the box is unreachable or a step fails, still DM that it happened, still update the plan with what you have, and exit 0 - never go silent.
'@

L 'deep-debate cycle start'
Set-Location $repo
& claude -p --safe-mode --permission-mode bypassPermissions --dangerously-skip-permissions $allowed $prompt *>> $log
L ("deep-debate cycle end (exit {0})" -f $LASTEXITCODE)
