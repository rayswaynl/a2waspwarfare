{
  "summary": "Research how great spectator/observer systems compose shots; distill into WASP director rules",
  "agentCount": 4,
  "logs": [],
  "result": {
    "synthesis": "# Arma 2 Warfare Auto-Director v6 — Prioritized Rule Set\n\nRanked by expected viewer impact. Each rule: **[CHEAP]** = constant tweak / small logic change to existing scorer-orbiter, **[BUILD]** = new mechanism/state machine. Numbers are starting points, tune against your existing min/max dwell values.\n\n## TIER 1 — Directly fixes the four named complaints\n\n1. **[BUILD] Hard eligibility gate before scoring, not after.** A POI/unit is not a candidate at all unless it has ≥1 live contact event (shots fired, hit taken, or enemy-proximity contact) inside the last 15s, OR it is part of the mandatory rotating establish-shot slot. Fixes \"focuses idle units/empty bases\" at the source — idle units currently reach the scorer and win on proximity alone; they should never enter the candidate pool. Source: Source SDK's own visibility/distance-band gate exists *before* importance scoring runs.\n2. **[CHEAP] Default POI shot type = orbit-with-push-in, not chase.** Chase cam is only selected when a single unit is moving fast (>~4 m/s) in the open with no other units within your existing proximity-contact radius. Any POI with 2+ contacts defaults to orbit. This directly targets \"laggy chase cams instead of orbit.\"\n3. **[BUILD] Fire-event lock: once a unit/POI starts firing or taking fire, it gets an unconditional 6–8s minimum-hold lock that no ordinary priority comparison can preempt.** Only a strictly higher-tier event (kill, objective capture) can break the lock, and even then only after the lock's own 2s \"let it breathe\" tail (see #7) has elapsed. Fixes \"pans away when a unit starts shooting\" — this is your single highest-leverage fix; the esports research is unanimous that active combat = the floor case for premature cuts.\n4. **[CHEAP] FOV/zoom ceiling gated by contact count, not by target size alone.** Tightest allowed FOV (max zoom-in) only unlocks when contact_count ≥ 2 AND at least one is actively firing within the last 5s. Solo/idle targets are capped at your widest FOV band regardless of distance. Fixes \"over-zoomed shots\" — over-zoom is almost always zooming in on a single idle unit because the scorer had nothing better to rank.\n5. **[CHEAP] Re-derive \"idle\" honestly: idle-dwell cap (3s) should trigger a hard cut-away, not just a dwell ceiling.** Currently a 3s cap that still lets an idle shot get selected repeatedly (re-rolled) produces exactly the flicker-back-to-empty-base behavior owners complain about. Add: once a shot hits its idle cap, that POI is cooled down (ineligible) for 60s before it can be re-selected. [CHEAP if you already have a per-POI last-shown timestamp; BUILD if you don't.]\n6. **[CHEAP] Re-scope \"establish-shot floor 120s\" as a *cooldown between establishing shots*, not a shot duration.** If it's currently being read as \"hold an establishing shot for up to 120s,\" that alone would produce both the idle-focus and laggy-cam complaints. Establishing shots themselves should be 2–4s (see #14); 120s should gate how often you're allowed to insert one.\n\n## TIER 2 — Cut/dwell pacing constants\n\n7. **[CHEAP] Let-it-breathe: after any scored event (kill, hit, objective tick) is chosen as the cut target, refuse to re-evaluate for a further 2.0s past the event tick**, even if a higher-priority event fires in that window (queue it instead of interrupting). Source: HLTV `m_nNextShotTick = event + 2.0s`.\n8. **[CHEAP] Absolute minimum shot length = 4.0s, target/default = 6.0s, soft maximum = 8.0s before a re-evaluation is even attempted (not forced).** If the current best-alternative's priority doesn't clear the \"cut threshold ratio\" in rule #10 by the time 8s is reached, extend rather than force a cut — extension is silent (no visible re-cut), just a continued hold.\n9. **[CHEAP] Refuse-not-defer rule: if remaining time before a scheduled/forced interrupt is <4.0s, do not start a new shot at all — ride out the current one.** This is the concrete anti-flash-cut mechanism; it prevents sub-4s shots from ever being shown, which is a stronger guarantee than just \"try to make shots ≥4s.\"\n10. **[CHEAP] Cut threshold ratio, not absolute priority compare: only cut away from the current shot if candidate_priority ≥ current_shot_priority × 1.5** (tune 1.3–2.0). A pure `>` compare is what produces jittery cutting between near-equal engagements; a ratio margin is what the \"don't run two cameras on the same thing\" broadcast guidance implies structurally.\n11. **[CHEAP] Absolute floor on ANY shot regardless of type: 3.0s (viewer-comprehension floor).** Never let dwell/max-dwell tuning push a shot below this even for \"boring\" filler shots.\n12. **[CHEAP] Sports-pace target band for active-engagement shots: 4–8s hold, not film-pacing (<2s).** Explicitly do not tune toward cinematic quick-cut rates; broadcast/sports precedent (avg replay shot 6.8s) is the right reference class for a war-game director, not action-movie editing.\n13. **[BUILD] Stale-shot ceiling: if a held POI produces zero new contact/damage events for 6–8s, force a re-evaluation even if nothing else has scored higher yet** — fall through to filler-shot logic (#19) rather than let the shot go dead. This is the counterpart to #7/#9: don't cut too fast, but also don't let a shot rot once the action there has actually stopped.\n14. **[CHEAP] Establishing shots (new POI, new front, new phase): 2–4s hold, fixed/wide framing, before any push-in/orbit begins.** Long establishing holds waste screen time and are a likely contributor to the \"idle/empty\" complaint if establish-shot logic is currently over-long.\n\n## TIER 3 — Scoring weights (ratios, not absolutes)\n\n15. **[CHEAP] POI score = contact_count_term × 3 + recency_term × 2 + spread_term × 1, roughly** — i.e. weight *how many units are actively engaged* roughly 3x proximity/count-alone, and weight \"an event happened in the last N seconds\" roughly 2x static distance-based scoring. Your current proximity-contact-count scorer likely conflates \"contacts nearby\" with \"contacts fighting\"; separate the two and weight the fighting signal higher.\n16. **[CHEAP] Underdog/lopsided-fight bias: apply a ×1.2–1.3 multiplier when the ratio of attacking-to-defending units at a POI is ≥2:1**, favoring the outnumbered side's camera framing over the numerically favored side. Matches human-observer practice (favor the clutch/underdog storyline) and is a one-line multiplier on an existing score.\n17. **[CHEAP] Structural beats (mission phase change, objective capture/loss, HC-triggered event) always force a fixed/establishing camera regardless of in-progress engagement score** — but respect the fire-event lock (#3): if a firefight is mid-lock, queue the structural beat for the lock's release rather than interrupting.\n18. **[BUILD] Two-second lead-bucket bias: when picking among near-equal-scoring imminent-event candidates, prefer the one whose action is 2–4s out over the one that's already peaked \"right now.\"** Cheap to approximate without a prediction model: if you can detect \"unit has started firing at a target but no hit yet,\" that's already a decent proxy for the Source engine's anticipatory bucket — treat it as scoring higher than a same-priority event that already resolved.\n19. **[CHEAP] Weighted filler-shot fallback when nothing clears the cut threshold: ~70% chase/orbit on best-ranked eligible POI, ~30% static/establishing, randomized selection order each pass** (not fixed iteration order). Prevents both monotonous camera behavior and the \"always same base\" staleness complaint.\n\n## TIER 4 — Zoom vs. cut policy\n\n20. **[CHEAP] Zoom (push-in) is for escalation of the SAME engagement; cut is reserved for a genuinely different POI/subject.** Never zoom into an unrelated unit to \"fill\" a shot — if nothing at the current POI is escalating, that's a cut-eligible condition (#13), not a zoom trigger.\n21. **[CHEAP] Large spatial jumps (new POI far from current) are always a hard cut, never a fast pan.** A pan across empty terrain to reach a new POI reads as blurry/disorienting per broadcast guidance — jump straight to the new orbit, no transit pan.\n22. **[CHEAP] Angular-change floor for cuts on the SAME POI: only issue a discrete cut to a new orbit angle if the angle changes ≥30° from the current camera bearing.** If the desired reframe is <30° away, treat it as a continuous orbit adjustment (smooth camera-object rotation), not a cut. This is the concrete fix for \"laggy\" reads if your current system is hard-cutting between near-identical orbit angles.\n23. **[BUILD] Axis-of-action consistency per engagement: once an orbit sequence establishes which faction is \"screen-left\" vs \"screen-right\" for a given POI/engagement, subsequent cuts on that same engagement stay on the same side of that line** until an explicit wide/transitional shot crosses it. Prevents disorienting side-flips mid-fight; moderate build cost (track one bearing/side flag per active engagement).\n24. **[CHEAP] Reserve tight zoom-in (near your FOV floor) for kill/decisive moments only** — gate it the same way rule #4 gates zoom generally, but specifically bias it toward the moment a unit dies/objective flips, not toward routine exchanges of fire.\n\n## TIER 5 — Action-preemption policy\n\n25. **[BUILD] Two-tier camera: primary orbit camera committed to current highest-priority POI (governed by rules 3/7/9/10), plus a lightweight secondary scan pass every tick that only evaluates NEW candidate POIs against the cut-threshold ratio — it never re-scores the currently-locked POI.** This is the structural fix that lets \"action started elsewhere\" get detected without the primary camera's own logic causing self-interruption jitter.\n26. **[CHEAP] A newly-detected engagement can only preempt the primary camera if its score clears the ratio in #10 AND the primary POI is not inside its fire-event lock (#3) AND not inside its let-it-breathe tail (#7).** All three conditions, not \"any one.\"\n27. **[CHEAP] Decisive/high-tier events (unit killed, objective captured/lost) bypass the ratio comparison in #10 entirely and force an immediate cut** — but still respect the ≥3.0s absolute floor (#11) on whatever shot is currently running only if that shot itself started <1s ago; otherwise cut now. This is your explicit \"climax exception\" to the smooth-cut discipline.\n28. **[CHEAP] While the primary camera holds a locked engagement, DO NOT run the secondary scan's output through the same priority number as ordinary filler candidates** — decisive events use rule #27's bypass, non-decisive elsewhen-action just accumulates score and waits its turn. Keeps two logics from fighting over one int comparison.\n\n## TIER 6 — Variety / anti-monotony\n\n29. **[CHEAP] Track last-N (suggest N=5) POIs shown and apply a small negative bias (−10 to −15%) to a POI's score if it was one of the last 2 shown**, to stop rapid back-and-forth between the same two hot spots.\n30. **[CHEAP] Randomize orbit direction (CW/CCW) and starting bearing per new shot on a POI** rather than always orbiting the same way — cheap variety win, avoids the \"laggy/samey\" perceptual complaint even when the underlying logic is sound.\n31. **[CHEAP] Don't always take the killer's-eye or fixed 3rd-person offset — randomize left/right orbit offset ±15–20° per shot** so consecutive engagements on the same POI don't look identical.\n32. **[BUILD, optional/lower priority] Camera bookmarking for HC-triggered \"big moment\" shots** (save a good angle when a notable event starts, snap back to it on a related follow-up event within the same engagement) — nice-to-have, not required to fix the current complaints.\n\n## TIER 7 — Composition/framing hygiene\n\n33. **[CHEAP] Pitch clamp ±85° and altitude/distance ceiling on orbit radius consistent with your existing radius/height ranges** — verify these are actually enforced; gimbal-flip or over-high orbit reads as \"laggy\" even when timing logic is correct.\n34. **[CHEAP] Target the unit's torso/head position for orbit look-at, not bounding-box center**, and commit any target-position change over a short ~0.3–0.5s eased window rather than snapping — reduces perceived jitter on moving-unit orbits, addresses \"laggy\" complaint independently of cut-timing fixes.\n35. **[CHEAP] Cap orbit radius/height bands tighter for single-unit POIs than for multi-unit engagements** — a lone rifleman doesn't need (and looks worse with) the same wide sweeping orbit radius as a squad-level firefight; tie radius band selection to contact_count like the FOV rule (#4).\n\n## What NOT to do\n\n36. **[CHEAP] Do not let the idle-dwell cap (3s) function as a re-roll invitation** — a POI that hits its idle cap must cool down (#5), not just get re-scored immediately; re-scoring immediately after a forced cut is very likely your current root cause for \"keeps coming back to empty bases.\"\n37. **[CHEAP] Do not cut on a pure `>` priority compare with no margin (#10) and no minimum-hold guarantee (#8/#9)** — this combination is mechanically what produces both flash-cuts and pan-away-mid-firefight; if v5 has one without the other, that's the bug.\n38. **[CHEAP] Do not use fast pans to reach distant POIs, and do not treat \"camera is currently near a target\" as sufficient candidacy on its own** — proximity without a live-contact check is the direct mechanism behind idle-unit focus; eligibility (#1) must run before scoring, not as a tiebreaker after.\n39. **[CHEAP] Do not zoom tight on a target chosen only because it's the best of a bad (idle) candidate pool** — if the entire candidate pool is idle after eligibility gating (#1), fall through to a wide establishing/filler shot (#19) instead of tight-framing whatever's left; over-zoom on nothing is worse than a wide dead shot.\n40. **[CHEAP] Do not let structural/establish-shot logic hold for anywhere near 120s of actual screen time** — if that constant is currently a duration rather than a cooldown (#6), this single mislabeling is plausibly responsible for a large share of all four complaints simultaneously (idle focus, laggy feel, missed action-starts) and should be the first thing verified in code before any other change is made.",
    "sources": [
      "esports-directors",
      "arma-spectators",
      "broadcast-language"
    ]
  },
  "workflowProgress": [
    {
      "type": "workflow_phase",
      "index": 1,
      "title": "Research"
    },
    {
      "type": "workflow_phase",
      "index": 2,
      "title": "Synthesize"
    },
    {
      "type": "workflow_agent",
      "index": 1,
      "label": "research:esports-directors",
      "phaseIndex": 1,
      "phaseTitle": "Research",
      "agentId": "a7022ccdba7ca1799",
      "model": "claude-sonnet-5",
      "state": "done",
      "startedAt": 1785569548302,
      "queuedAt": 1785569548279,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "esports-directors",
      "promptPreview": "Research (WebSearch + WebFetch) how automated esports observer/director systems pick and compose shots: Dota 2 auto-spectate/director and its fight-prediction weighting, CS:GO/CS2 auto-observer (e.g. how casters and auto-directors weight kills-imminent, utility, man-advantage), and any published postmortems/talks on auto-directing. Extract CONCRETE, implementable rules: how they score candidate ta…",
      "lastProgressAt": 1785570142629,
      "tokens": 158609,
      "toolCalls": 66,
      "durationMs": 594327,
      "resultPreview": "{\"topic\":\"esports-directors\",\"rules\":[{\"rule\":\"Game events are assigned a discrete priority 0-10 (or -1 = ignore) at the moment they fire, and only events above the current best-in-window priority are kept as 'best event' candidates. Nothing more elaborate than an int compare drives the moment-to-moment 'is this worth showing' decision.\",\"why\":\"Cheap, deterministic scoring that server code can run…"
    },
    {
      "type": "workflow_agent",
      "index": 2,
      "label": "research:arma-spectators",
      "phaseIndex": 1,
      "phaseTitle": "Research",
      "agentId": "aa7d6503a2512e0d5",
      "model": "claude-sonnet-5",
      "state": "done",
      "startedAt": 1785569548304,
      "queuedAt": 1785569548279,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "arma-spectators",
      "promptPreview": "Research (WebSearch + WebFetch) the best Arma-series spectator implementations: BIS End Game Spectator (Arma 3), ACE Spectator, community casting tools used for Arma events (e.g. King of the Hill/Zeus TvT casting practice). Extract camera-control design: how their free-cams handle speed ramping/momentum/mouse smoothing, their target-camera framing (orbit? follow distance? FOV), UI layout for caste…",
      "lastProgressAt": 1785569910592,
      "tokens": 97632,
      "toolCalls": 41,
      "durationMs": 362288,
      "resultPreview": "{\"topic\":\"arma-spectators\",\"rules\":[{\"rule\":\"Model spectator camera as several discrete, switchable modes rather than one universal camera: Free (unrestricted flight), Follow/orbit (camera moves relative to a focused unit, keeps distance), First-Person (embedded in unit's eyes), and optionally Shoulder (3rd-person over-shoulder with configurable offset), Topdown (bird's-eye tracking) and Orbit (ci…"
    },
    {
      "type": "workflow_agent",
      "index": 3,
      "label": "research:broadcast-language",
      "phaseIndex": 1,
      "phaseTitle": "Research",
      "agentId": "afa3cd8c9f3dfc516",
      "model": "claude-sonnet-5",
      "state": "done",
      "startedAt": 1785569548305,
      "queuedAt": 1785569548279,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "broadcast-language",
      "promptPreview": "Research (WebSearch as needed) real sports/broadcast camera language applicable to a war-game auto-director: establishing-shot discipline, when to push in (slow zoom) vs cut, the 30-degree rule, screen direction/180 rule, how long a viewer tolerates an uneventful shot, how live sports handle \"action started elsewhere\" (cut immediately vs replay). Extract rules directly translatable to: orbit-over-…",
      "lastProgressAt": 1785569667739,
      "tokens": 69529,
      "toolCalls": 12,
      "durationMs": 119434,
      "resultPreview": "{\"topic\":\"broadcast-language\",\"rules\":[{\"rule\":\"30-degree rule: when cutting between two shots of the same subject/POI, the camera angle must change by at least 30 degrees, or the cut reads as a disorienting 'jump cut.' If you can't move 30°+, don't cut — hold, pan, or go wide instead.\",\"why\":\"Directly maps to orbit-over-POI logic: an auto-director should never hard-cut between two orbit angles on…"
    },
    {
      "type": "workflow_agent",
      "index": 4,
      "label": "synthesize",
      "phaseIndex": 2,
      "phaseTitle": "Synthesize",
      "agentId": "ac501eb4f37ecc027",
      "model": "claude-sonnet-5",
      "state": "done",
      "startedAt": 1785570142638,
      "queuedAt": 1785570142637,
      "attempt": 1,
      "promptPreview": "You are designing v6 of an Arma 2 warfare-mission auto-director (SQF, engine: orbit cameras around targets, FOV zoom, cut dwell timers, candidate pool scored by proximity-contact counts; existing constants: per-shot radius/height/FOV ranges, min/max dwell, idle-dwell cap 3s, establish-shot floor 120s). Current owner complaints: focuses idle units/empty bases, laggy chase cams instead of orbit-over…",
      "lastProgressAt": 1785570234616,
      "tokens": 64878,
      "toolCalls": 0,
      "durationMs": 91978,
      "resultPreview": "# Arma 2 Warfare Auto-Director v6 — Prioritized Rule Set\n\nRanked by expected viewer impact. Each rule: **[CHEAP]** = constant tweak / small logic change to existing scorer-orbiter, **[BUILD]** = new mechanism/state machine. Numbers are starting points, tune against your existing min/max dwell values.\n\n## TIER 1 — Directly fixes the four named complaints\n\n1. **[BUILD] Hard eligibility gate before s…"
    }
  ],
  "totalTokens": 390648,
  "totalToolCalls": 119
}