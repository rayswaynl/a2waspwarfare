# WaspB57Full - B59 06:00 CONSOLIDATION (daily). Ray 2026-06-21: the morning wrap - consolidate the
# overnight deep-debate cycles into THE single best improvement plan for all facets (B59-IMPROVEMENT-PLAN.md)
# + DM Ray the morning report. PROPOSE-ONLY. Runs a headless `claude -p`.
$ErrorActionPreference = 'Continue'
$repo = 'C:\Users\Game\a2waspwarfare'
$log  = 'C:\Users\Game\wasp-b57-full.log'
function L($m){ try{ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$m) }catch{} }

$env:BRAIN_AGENT = 'claude-gaming'
$env:Path = "C:\Users\Game\AppData\Local\Microsoft\WinGet\Links;C:\Program Files\Git\cmd;C:\Program Files\nodejs;C:\Users\Game\AppData\Roaming\npm;$env:Path"
$allowed = '--allowedTools=Bash(python:*),Bash(py:*),Bash(git:*),Bash(powershell:*),Bash(pwsh:*),Bash(cmd:*),Bash(ssh:*)'

$prompt = @'
You are claude-gaming on Ray's fleet, running the 06:00 CONSOLIDATION for the WASP B59 overnight soak + deep-debate. This is the morning plan Ray reviews when he wakes. English only. Be decisive; overcome any hurdle and still produce the plan + DM.

NON-NEGOTIABLE RULES:
1. PROPOSE-ONLY. NEVER deploy/restart/change the live server or mission. Box = READ-ONLY RPT reads over ssh. Writes allowed ONLY: (a) ONE Peach+ DM to Ray, (b) commits to `claude/b57-soak-proposals` in C:\Users\Game\a2waspwarfare, pushed. Do NOT merge. Do NOT deploy B60.
2. Peach+ DM: POST http://127.0.0.1:5001/api/peach/admin/dm, header X-Ops-Key = PEACH_OPS_API_KEY from C:\Users\Game\Complete-discord-bot\.env, JSON {"content":"..."}, OMIT user_id ENTIRELY (no user_id -> Ray 834428635896610886; any user_id mis-sends to his partner). NEVER print/echo/log the key. FORMAT the DM nicely for Discord and OUTPUT REAL EMOJI CHARACTERS (the POST body is UTF-8): lead with an emoji header, use emoji-led section bullets (server/computer for FPS/health, crossed-swords for the war, brain for AICOM, lightbulb for recommendations, warning sign for risks, chart for metrics, checkmark for what shipped), bold the labels, short sections + a clear ranked top-5 - informative + skimmable, never a wall of text.
3. USE SUB-AGENTS for the research so the main context stays lean.
4. A2-OA 1.64 for code-shaped ideas: no isEqualType/isEqualTo/findIf/selectRandom/pushBack/setRandomSeed/worldSize; no sim/distance-gating; never a frozen/idle AI; do NOT touch antistack.

CONTEXT: Live = B66 (own-side MARKER fix series; gameplay = same as B59-B61, unchanged). B63 fixed the OPFOR/JIP own TEAM arrows (publicVariable not JIP-replayed in A2-OA -> server now re-broadcasts the AICOM/patrol feeds + connect catch-up; CONFIRMED working by Ray). B66 adds: undeployed-HQ marker heal (HQ was never in wfbe_structures), player-own-arrow direction fix (B62 clientTeams rebind desynced updateteamsmarkers cache), + bounded clientInitComplete gates & diag_log instrumentation for the still-uncertain FACTORY markers (pending Ray RPT). Carries all B59-B62 gameplay (15 teams/side + spearhead re-pick + base-GC/re-adopt + refill + 2 spearheads; GUER Team_MG + air-def Ka137/Mi24 + PMC; MHQ reloc + heli cannon-nudge; Mi24_P fix; airfield-spawn filter). Markers are NOT the debate focus - debate AICOM/units/economy/FPS/spectacle as before. PROPOSE-ONLY: never deploy.

TASK (consolidate the morning plan):
The overnight 2-hourly deep-debate cycles have been refining C:\Users\Game\a2waspwarfare\B59-IMPROVEMENT-PLAN.md all night. CONSOLIDATE it into the single BEST improvement plan for ALL facets, validated against the whole night's evidence.
- Read B59-IMPROVEMENT-PLAN.md (the overnight-refined plan), the whole soak (C:\Users\Game\wasp-b57-soak\impressions.md + the live RPT across the night, per-round by MISSINIT), and B57-SOAK-PROPOSALS.md.
- Sanity-check EVERY top recommendation against the actual overnight evidence (did the front-stall / unitsPerTeam bleed / FPS / ASSAULT_STRANDED behave as the plan assumes?). Cut what the data doesn't support; promote what the night newly proved.
- Cover ALL facets: AI-commander strategy & front, AI-unit tactics & the bleed & the wedge, economy & balance (incl. 15 teams), performance/FPS, player spectacle & AI cinematics, bugs & telemetry, and the B60 go/no-go.

Then:
A) WRITE the consolidated plan as the FINAL morning form of C:\Users\Game\a2waspwarfare\B59-IMPROVEMENT-PLAN.md. Sections: Headline (state of B59 + the single biggest lever + the one risk); Top-10 ranked actions across all facets (each: what / why / impact / effort / verdict adopt-trial-reject / A2-OA file:line pointer); By-facet; B60 GO/NO-GO with the specific tuning you'd set; Open questions for Ray; What-NOT-to-touch (don't tune off blended unitsPerTeam, hands-off antistack, towns stay hard, no sim-gating/frozen-AI). Date the consolidation header. Stage ONLY B59-IMPROVEMENT-PLAN.md (and B57-SOAK-PROPOSALS.md if used); do NOT sweep JOURNAL.md / *.bak / publish-*.ps1. Commit + git push. Do NOT merge.
B) DM Ray's Peach+ (rule 2) the morning wrap: overnight headline (stability / FPS trend / war arc / rounds played), the TOP 5 ranked recommendations (one line each), the B60 go/no-go call, and a pointer that the full plan is B59-IMPROVEMENT-PLAN.md on the claude/b57-soak-proposals branch. This is the morning report DM - it can be longer than the 2h notes but keep it skimmable.

If the box is unreachable or a step fails, still DM what you have + note it; never go silent.
'@

L 'consolidation start'
Set-Location $repo
& claude -p --safe-mode --permission-mode bypassPermissions --dangerously-skip-permissions $allowed $prompt *>> $log
L ("consolidation end (exit {0})" -f $LASTEXITCODE)
