# AICOM V2 Behaviour Spec 417: Build And Research

Status: final-form research/spec for later implementation. No gameplay code.
Scope: AI commander economy, production priorities, tech/research pacing, purchase timing, and composition intent.

## Doctrine Fit

Build and research in V2 must create pressure, adaptation, and readable escalation. The commander should not buy random units just because money exists. It should commit to a plan, tech toward a purpose, refuse fair fights by changing composition, remember what punished it, and keep production moving so the map never goes quiet.

This spec does not authorize new classnames. Every unit or equipment classname used by a later builder must already exist in the mission tree or include separate config proof in the PR, per `AGENTS.md`.

## Desired V2 Behaviour

1. Research has purpose:
   - Opening tech supports expansion and survivability.
   - Midgame tech answers observed threats or creates a pressure spike.
   - Late tech escalates force projection, defense breaking, or mobility.

2. Production follows intent:
   - Attack intent buys assault-capable teams.
   - Defense intent buys local reaction and anti-armor/anti-air as legitimately needed.
   - Interdiction intent buys mobile units.
   - Recovery intent replaces lost capability rather than repeating a failed exact mix.

3. The AI should adapt without being psychic:
   - Anti-armor response requires observed armor, vehicle losses, or known enemy tech state.
   - Anti-air response requires observed aircraft, air losses, or known air tech.
   - Static-heavy defense response requires known town/base contact, not hidden defenses.

4. The AI should avoid idle bank hoarding:
   - If a planned purchase is blocked too long, downgrade to a useful pressure purchase.
   - Keep a reserve only when saving for a declared tech or escalation step.

5. Research and build explain themselves:
   - Always-on transition line when switching build doctrine or research goal.
   - Verbose money, tech, and queue dumps only behind `WF_LOG_CONTENT`.

## V2 Layer Contract

- Strategic director chooses side-level pressure goal and phase.
- Build/research planner chooses tech goal, reserve policy, and composition profile.
- Existing purchase routines execute unit purchases.
- Memory layer records which compositions failed or succeeded against known threats.
- Explainability layer logs doctrine changes and blocked purchases.

## V1 Evidence To Keep

Use these anchors:

- `Common/Init/Init_CommonConstants.sqf`: append flags and tunables only here.
- `Client/GUI/GUI_Menu_BuyUnits.sqf`: known unit-purchase UI convention for player purchase flow.
- `Client/Functions/Client_BuildUnit.sqf`: known player build function path; do not conflate player UI purchases with AI commander purchase logic.
- `Server/Functions/Server_BuyUnit.sqf`: known AI team purchase anchor from `AGENTS.md`; later builders should inspect this before editing production execution.
- `version.sqf`: `WF_LOG_CONTENT` gates verbose logs.
- `Tools/Soak/README.md`: soak KPI source for economy and RPT validation.

Keep V1 strengths:

- Existing economy and tech rules remain authoritative.
- Existing purchase legality checks must stay in the executor path.
- Terrain mirrors must derive from Chernarus source via LoadoutManager after any future SQF edit.

## V1 Behaviour To Fix

- Repeating ineffective compositions after losses.
- Saving for tech while the map goes quiet.
- Buying fair-fight units into a known counter instead of flanking, teching, or adapting.
- Tech choices that do not connect to visible battlefield needs.
- No concise RPT explanation for research or production pivots.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_BUILD_RESEARCH = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_ECO_RESERVE_MIN`: minimum reserve for declared research.
- `WFBE_C_AICOM_V2_ECO_BLOCKED_SEC`: maximum time to wait for ideal purchase before fallback.
- `WFBE_C_AICOM_V2_COMP_MEMORY_SEC`: expiry for composition success/failure memory.
- `WFBE_C_AICOM_V2_TECH_REEVAL_SEC`: minimum interval between non-emergency research reevaluations.
- `WFBE_C_AICOM_V2_COUNTER_CONFIDENCE_MIN`: minimum legitimate evidence score before counter-teching.

Flag-off must be inert. Do not change existing defaults. Do not wire `WFBE_C_SIM_GATING`.

## Composition Profiles

The later implementation should define data-only profiles, not scattered conditionals:

- `expand`: cheap mobility and capture presence.
- `assault`: infantry and vehicles suited for taking defended towns.
- `hold`: defense, repair/rearm support if already present in V1, and local reaction.
- `counterArmor`: only after legitimate armor evidence.
- `counterAir`: only after legitimate air evidence.
- `interdict`: mobile pressure and route denial.
- `recover`: affordable replacement of lost role capability.

Profiles should include:

- Desired role mix.
- Minimum and maximum spend share.
- Required tech/research prerequisites.
- Fallback profile if blocked.
- Evidence requirements for counter profiles.

## Research Rules

Research selection should score:

- Current side phase.
- Declared pressure goal.
- Observed enemy capability.
- Recent friendly losses.
- Existing tech gaps.
- Cost and time to impact.

Research selection must not score hidden enemy units or unobserved future tech. If the mission has public enemy tech state already visible to commanders, builders may use it and must cite the exact V1 source in the PR.

## Soak Acceptance Checks

- AI commander has a declared research goal or logged reason for no research within the configured opening window.
- AI production queue does not stay blocked longer than `WFBE_C_AICOM_V2_ECO_BLOCKED_SEC` while funds and legal fallback purchases exist.
- After repeated losses to observed armor or air, composition profile changes once evidence threshold is met.
- With no evidence, the AI does not counter-tech perfectly against hidden enemy force.
- RPT contains concise doctrine/research transition lines and no high-volume money spam outside `WF_LOG_CONTENT`.
- No new classnames are introduced without proof.
- No A3-only lint failures or RPT script errors.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_BUILD_RESEARCH` default `0`, prove flag-off inertness, include one HC RPT example of a research/build doctrine change, and confirm mirrors.
