# JOURNAL — a2waspwarfare-experital

## 2026-07-01 — AICOM movement root follow-up [RELEASE LOOP]

Ported the narrow movement-root fixes from the overnight scout without merging
the broader overnight branch. `WaypointsAdd` now makes the first waypoint in
each newly-added batch current even after `WaypointsRemove` leaves a residual
engine waypoint, so relaid commander routes actually start moving. The assault
arrival latch now honors `WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS` as the outer gate
while keeping the tighter SAD/depot capture behavior inside the phase. Also
replaced the AICOM grade dwell boolean `!=` comparison with an A2-safe explicit
boolean change test.

Static smoke asserts the first-batch waypoint current call, widened arrival
gate and A2-safe grade comparison across both maintained terrains. Runtime,
SSH, RPT collection, upload, restart, cache-clear and deployment remain
explicit-approval gated.

## 2026-07-01 — AICOM lifecycle shape guards [RELEASE LOOP]

Tightened a few malformed-state edges around AICOM team lifecycle cleanup. The
transport refund path now validates unit-data shape before reading
`QUERYUNITPRICE`, pending-token consumption refuses a corrupted non-array token
store, and `WFBE_ACTIVE_AICOM_TEAMS` pruning now validates active-list entry
unit/team types before reading them. The active AICOM marker list itself is now
reset to an empty array if corrupted before created/ended/heading handlers
iterate it, and the created duplicate scan validates slot 3 as a group before
comparing it. Static smoke asserts these lifecycle shape guards together with
the existing refund authority checks.

Runtime, SSH, RPT collection, upload, restart, cache-clear and deployment remain
explicit-approval gated.

## 2026-07-01 — AICOM feed request PV guard [RELEASE LOOP]

Hardened the `WFBE_ReqAicomFeed` marker/status replay request path used by
late or racing clients to recover AICOM and patrol map feeds. The server-side
handler now rejects malformed payloads, non-player/dead/null request objects
and invalid owners before targeted `publicVariableClient` replies, and adds a
per-player `WFBE_C_AICOM_FEED_REQ_MIN_INTERVAL` throttle so repeated marker
replay requests cannot spam the server/client feed path.

Static smoke now asserts the guard and throttle across both maintained terrains.
LoadoutManager mirrored the Chernarus source changes to Takistan and rebuilt
`_MISSIONS.7z`. Runtime, SSH, RPT collection, upload, restart, cache-clear and
deployment remain explicit-approval gated.

## 2026-07-01 — AICOM arrival gate SAD-ring follow-up [RELEASE LOOP]

Closed a small follow-up on the capture-stall guardrails. The assault arrival
latch now uses the larger of `WFBE_C_TOWNS_CAPTURE_RANGE` and
`WFBE_C_AICOM_ASSAULT_SAD`, plus the existing 20m buffer, so squads running the
tighter SAD assault radius can enter the local capture behavior from the same
ring they are about to fight inside. Static smoke now asserts the arrival gate
uses both tunables.

The teammate marker comment was also clarified to match the A2-safe
`mil_arrow2` marker choice. Runtime, SSH, RPT collection, upload, restart,
cache-clear and deployment remain explicit-approval gated.

## 2026-07-01 — AICOM capture drain-wait and release marker guardrails [RELEASE LOOP]

Follow-up subagent review closed two P1s before publishing this lane. The
AllCamps camp push now installs the tight camp MOVE and optional SAD sweep as
one `WaypointsAdd` chain, so the SAD cannot asynchronously clear the 8m
presence waypoint. AssignTowns now evaluates `WFBE_C_AICOM_STALL_ADVANCE_SECS`
as an independent same-target age guard before the older far-from-target stuck
branch, and no longer refreshes `wfbe_aicom_goto_since` merely because a team is
in contact or making breadcrumb progress. Static smoke now asserts these capture
stall guardrails across Chernarus and generated Takistan.

The RPT marker sweep helper was also hardened after review: `-WindowMarker
MISSINIT` backs up to the current mission banner/release marker, expected
release markers stay literal even with `-Regex`, and the self-test now covers
stale-window rejection plus `-IncludeLineText` opt-in behavior.

Ported the narrow cmdcon37/cmdcon38 AICOM capture fixes onto the PR #125
release lane without merging the broader Build84/overnight branches. Camp-first
logic now keeps the no-progress bail disabled only in AllCamps mode, where the
depot cannot flip until every camp is owned, and actively prosecutes camp
garrisons while still bounded by `WFBE_C_AICOM_ASSAULT_HOLD`. Infantry and
pure-armour depot holds now wait for the town to actually flip, not merely for
nearby resistance to clear. AssignTowns also stamps `wfbe_aicom_goto_since` and
uses `WFBE_C_AICOM_STALL_ADVANCE_SECS` as a time-based retarget floor when a
team remains parked on the same unflipped town.

Also changed ungenerated release-marker fallbacks from stale
`build83-cmdcon35` strings to `candidate=unpackaged|git=missing-version`, and
added the redaction-safe `Tools/Monitor` RPT marker sweep helper plus self-test
for exact runtime-marker preflight. LoadoutManager mirrored the Chernarus edits
to Takistan and rebuilt `_MISSIONS.7z`; runtime, SSH, RPT collection, upload,
restart, cache-clear and deployment remain explicit-approval gated.

## 2026-07-01 — AICOM order sequence helper [RELEASE LOOP]

Closed another HC-order churn edge in the AI commander. Added
`WFBE_CO_FNC_AICOMNextOrderSeq` to centralize guarded reads of the public
`wfbe_aicom_order` array before bumping its sequence number. Commander reset,
assignment, execute, retreat, relief, wedge-release and HQ-strike writers now
use the helper instead of open-coded `select 0` reads that could fail if the
group variable was nil, empty or malformed after HC/JIP churn.

Static smoke now asserts the helper registration and scans commander files for
raw AICOM order sequence reads. Runtime, SSH, RPT collection, upload, restart,
cache-clear and deployment remain explicit-approval gated.

## 2026-07-01 — AICOM artillery config default guards [RELEASE LOOP]

Closed the next AI-commander artillery runtime-risk slice. The strategy and
player-requested artillery paths now read artillery enablement, timeout
intervals and per-side max-range arrays through guarded defaults, validate array
shape before selecting by artillery index, and clamp the artillery divisor to at
least 1 before computing range.

This prevents missing or malformed artillery config state from turning an AICOM
strategy tick or player fire-mission request into a select/divide runtime error.
Static smoke includes an `AICOM artillery config guards` check across Chernarus
and generated Takistan. LoadoutManager propagation refreshed `_MISSIONS.7z`;
the canonical package hash/size/entry tuple is recorded in the release package
manifest, PR body and wiki after the final post-commit proof. `Run-WaspFinalCheck.ps1`
passed: static smoke, Chernarus OA lint, Takistan OA lint, and high-only bug hunt.

Parallel scouts also identified two next release-loop candidates: harden
`wfbe_aicom_order` sequence reads, and close the explicit Jerry file 5420 /
`WarfareV2_073LiteCO.zip` source-comparison gap in the wiki. No runtime, SSH,
RPT collection, upload, restart, cache-clear or deploy action was performed.

## 2026-07-01 — SCUD and roster group-funds default hardening [RELEASE LOOP]

Closed the group-funds default-read blockers found by the read-only release
scout. The client SCUD action, server SCUD funds gate and JIP roster row builder
now resolve team treasuries through `WFBE_CO_FNC_GetTeamFunds` instead of raw
group `getVariable [name, default]` reads. `Common_ChangeTeamFunds.sqf` now
uses the older plain-get plus `isNil` guard before adding the delta, so an unset
team treasury cannot turn a later credit/debit into `nil + amount`.

Static smoke now scans the SCUD and JIP roster paths for raw group `wfbe_funds`
default reads, including `(group _caller)`, `_playerTeam` and the `_x` roster
loop in `Server_OnPlayerConnected.sqf`. LoadoutManager mirrored the maintained
Chernarus edits to Takistan and rebuilt `_MISSIONS.7z`; direct static smoke and
`Run-WaspFinalCheck.ps1` passed with both terrain A2/OA lints at `FAIL 0 /
REVIEW 0` and BugHunt HIGH clean. No runtime, SSH, RPT collection, upload,
restart, cache-clear or deploy action was performed.

## 2026-07-01 — Command-menu group-default follow-up [RELEASE LOOP]

Closed the adjacent client command-menu group read found during the AICOM
default sweep. `GUI_Menu_Command.sqf` now resolves the displayed team objective
through `WFBE_CO_FNC_GroupGetValue`, avoiding the Arma 2 OA group
`getVariable [name, default]` unset-default trap for `wfbe_teamgoto` while
preserving the existing object/position display handling.

Static smoke now asserts the command-menu helper call and scans that GUI file
for future raw group default reads. LoadoutManager mirrored the Chernarus source
change to Takistan and rebuilt `_MISSIONS.7z`; direct static smoke passed. No
runtime, SSH, RPT collection, upload, restart or deploy action was performed.

## 2026-07-01 — AICOM pending-token and transport-refund authority [RELEASE LOOP]

Closed the next AICOM authority slice before runtime collection. HC team
dispatches now carry a server-minted `wfbe_aicom_pending_tokens` entry through
`delegate-aicom-team`; `aicom-team-created` consumes it when present, and a
`grpNull` `aicom-team-ended` creation-failure release must echo a real token
before it can decrement `wfbe_aicom_pending`. Tokenless null-team releases now
log as unauthenticated instead of freeing a pending slot.

Transport fly-off refunds are now object-bound instead of cost-string-bound.
The HC stamps each AICOM transport with side/team/type metadata, sends the live
transport object to the server before deletion, and the server verifies the
object is a live off-map AICOM transport with the expected side, team, type and
driver before computing the refund from mission unit data. The transport object
is latched with `wfbe_aicom_transport_refunded` before treasury credit so replay
messages cannot double-credit.

LoadoutManager mirrored Chernarus to Takistan and rebuilt `_MISSIONS.7z`.
`Test-WaspStaticSmoke.ps1` and `Run-WaspFinalCheck.ps1` passed with both
terrain A2/OA lints at `FAIL 0 / REVIEW 0` and BugHunt HIGH clean. No runtime,
SSH, RPT collection, upload, restart or deploy action was performed.

## 2026-07-01 — AICOM commander group-default sweep [RELEASE LOOP]

Closed the next AICOM-safe read slice in the maintained Chernarus source. Added
`WFBE_CO_FNC_GroupGetValue` for non-boolean group variables so strings, arrays,
objects, positions and counters keep their intended default when unset on an
Arma 2 OA group receiver. The existing `WFBE_CO_FNC_GroupGetBool` remains the
bool-specific path.

Converted the remaining commander `_team getVariable [name, default]` reads in
`AI_Commander_Snapshot.sqf`, `AI_Commander_AssignTypes.sqf`,
`AI_Commander_AssignTowns.sqf`, `AI_Commander_Produce.sqf` and
`AI_Commander_DisbandLowTier.sqf`. Static smoke now scans commander scripts for
raw group default reads so future AICOM edits fail before packaging. Takistan
propagation and release gates passed in the WP12 validation loop; runtime,
deploy and SSH collection remain explicit-approval gated.

## 2026-07-01 — AICOM air-factory scan lint review cleared [RELEASE LOOP]

Tightened the last known A2/OA lint review in `AI_Commander_Teams.sqf`.
The heli air-tier waive still detects a live Aircraft Factory from
`WFBE_<SIDE>STRUCTURES` / `WFBE_<SIDE>STRUCTURENAMES`, but now uses an explicit
indexed loop instead of the A2-legal array `find "Aircraft"` form that the
release linter could not distinguish from Arma 3 string-find. LoadoutManager
mirrored the change to Takistan and rebuilt `_MISSIONS.7z`.

Direct `Lint-A2Compat.ps1` runs now pass with `FAIL 0 / REVIEW 0` for both
Chernarus and Takistan. Runtime/deploy gates remain unchanged and still require
explicit approval plus the exact ten-file RPT packet.

## 2026-07-01 — AICOM lifecycle/refund authority guard [RELEASE LOOP]

Closed the next bounded commander-hardening slice for both maintained terrains.
HC-founded AICOM teams now stamp a public `wfbe_aicom_sideid` binding when the
group is created, and `Server_HandleSpecial.sqf` uses that alongside the
OA-safe `WFBE_CO_FNC_GroupGetBool` helper to reject untrusted
`aicom-team-created`, `aicom-team-ended`, `aicom-team-heading` and
`aicom-heli-refunded` payloads before they can mutate side team lists, marker
feeds, pending counters or the AI-commander treasury.

The heli fly-off refund sender now includes the originating team and transport
class, and the server only credits a registered AICOM team when the submitted
cost is scalar, positive and capped by the mission unit price for that class.
Team-end handling also rejects duplicate/unregistered/live-team lifecycle
messages before cleanup. LoadoutManager mirrored the source change to Takistan
and rebuilt `_MISSIONS.7z`; `Test-WaspStaticSmoke.ps1` and
`Run-WaspFinalCheck.ps1` both pass.

## 2026-07-01 — AICOM/PVF static hardening and Build 83 merge-gate [RELEASE LOOP]

Closed the next static release-hardening slice without touching runtime, SSH or
deployment. Server and client PVF dispatchers now reject nil, non-array, short
or non-string handler payloads before any `select` or allowlist lookup can throw.
`Server_HandleSpecial.sqf` also rejects malformed command payloads before the
main switch, and the stale `aicom-focus`, `aicom-defend` and `aicom-reinforce`
cases now require the same human-commander requester/team validation used by the
live command-console actions.

Replaced the remaining active AICOM group receiver reads that used the Arma 2 OA
unsafe `getVariable [name, default]` form with the existing
`WFBE_CO_FNC_GroupGetBool` helper in the supervisor reset paths, AICOM allocation,
spearhead/relief/HQ-strike strategy, team counting and CMDRSTAT team-type
classification. Static smoke now also asserts the PVF shape guard and the extra
AICOM command-case gates. `Run-WaspFinalCheck.ps1` passed after LoadoutManager
mirrored the Chernarus source to Takistan and rebuilt `_MISSIONS.7z`.

Merge-gate note superseded: current `origin/master` Build 83/cmdcon35 is already
an ancestor of this release branch. Keep future broad branch intake explicit and
source-reviewed, but PR #125 is no longer blocked on that older local merge
simulation.

## 2026-07-01 — HCTopUp draft worker excluded from release package [RELEASE LOOP]

Removed the uncompiled `AI_Commander_HCTopUp.DRAFT.sqf` worker from the
maintained Chernarus mission source and dropped the inert supervisor call,
default-off HC top-up/merge constants and unused client `aicom-team-merge`
consumer that only existed for that draft path. The live stranded-survivor
merge constants and production logic remain intact.

Static smoke now treats the HCTopUp draft tokens as release-forbidden across
both generated mission outputs, so future package refreshes cannot silently
ship the half-wired worker surface again. Follow-up hygiene also removes the
stale private declarations left behind by the supervisor-block deletion and
adds extra HCTopUp/HC-merge log/config tokens to the release-forbidden smoke
coverage.

## 2026-07-01 — AI commander command-console requester guard [RELEASE LOOP]

Hardened the player-facing AI commander command console request path before
runtime collection. Client command-menu actions now include the requester
object and requester group when sending AICOM posture, field-order, direct
AI-command, artillery, priority-unit and disband requests. The server-side
`Server_HandleSpecial.sqf` path now validates the requester object, live player
state, group binding and side match before accepting those AICOM control
requests, with commander-only actions requiring the requester to be the current
human commander.

This closes another payload-forgery surface in the AICOM support UI. It still
requires LoadoutManager propagation to Takistan, package refresh and the normal
runtime RPT matrix before release wording can move from runtime-pending.

## 2026-07-01 — AI commander donation authority guard [RELEASE LOOP]

Hardened the live `RequestAIComDonate.sqf` PVF before the runtime RPT pass.
The handler now validates payload shape and types before selecting fields,
requires a live player donor still in the submitted team, rejects unsupported
non-WEST/EAST sides and disabled-AICOM configurations, reads donor funds through
the common team-funds helper, and uses the common team-funds debit helper before
crediting the AI commander wallet. The transfer menu now only offers the AI
Commander donation row for WEST/EAST sides while AICOM is enabled.

Static smoke gained an `AI commander donation authority guard` to keep the
six-part contract visible across Chernarus and generated Takistan. LoadoutManager
must propagate this Chernarus source slice before package provenance is refreshed.

## 2026-07-01 — HC reconnect/drop AICOM audit tokens [RELEASE LOOP]

Ported the source-only part of `f20ddfc83` into the PR #125 release branch for
both maintained terrains. HC reconnect now stamps `wfbe_aicom_last_heading_t`
on touched AICOM HC groups and emits delayed `HCRECON_AICOM_AUDIT` telemetry.
HC disconnect now emits immediate and delayed `HCDROP_AICOM_AUDIT` telemetry
with side, team, live-leader, owner and heading-freshness counts.

Also tightened the late-JIP `WFBE_ReqAicomFeed` retry path. When a client asks
for the missing AICOM marker feed, the server now rebroadcasts the side-keyed
`WFBE_AICOM_*_<side>` intent/objective/status variables to that requester in
addition to the active AICOM team and patrol arrays. Static smoke now asserts
the retry-path `aiStatus` token plus HC reconnect/drop audit emitters.

This is diagnostic instrumentation for runtime proof collection; it does not
change AI commander target selection, team production or delegation decisions.
`Run-WaspFinalCheck.ps1` kept Chernarus/Takistan A2/OA lint clean and HIGH
BugHunt clean. The local static smoke still reports the known active stress
overlay/RHUD proof prerequisites as missing in this workspace, so runtime RPT
evidence and deployment remain approval-gated.

## 2026-07-01 — Upgrade client/server payment contract alignment [RELEASE LOOP]

Aligned the direct player upgrade GUI path with the hardened
`RequestUpgrade.sqf` contract. The upgrade menu now sends the requester object
and requester team, no longer performs local funds/supply debits before server
acceptance, and presents the action as a request until the server confirms the
upgrade-started event. `Client_FNC_Special.sqf` now guards commander-team reads
before awarding upgrade score and owns the client-side upgrade-sync timer from
the accepted server notification path. LoadoutManager propagated the Chernarus
client contract and the Takistan server parity cleanup.

`Run-WaspFinalCheck.ps1` passed after the contract alignment: static smoke clean
including the updated `Upgrade request authority guard`, Chernarus and Takistan
A2/OA lint `FAIL: 0` / `REVIEW: 0`, and whole-mission HIGH BugHunt clean.
Runtime RPT evidence and deployment remain approval-gated.

## 2026-07-01 — Upgrade request and AICOM group-var guards [RELEASE LOOP]

Closed another bounded release-readiness slice without touching runtime/SSH.
`RequestUpgrade.sqf` now rejects malformed payloads, wrong payload types,
non-player upgrade flags, invalid side logic, already-running upgrades, disabled
or out-of-range upgrade ids, stale/skipped levels, missing config arrays and
unmet dependency links before spawning the existing upgrade timer worker. The
direct player upgrade path now binds the request to the player object and group
sent by the client and rechecks commander-team ownership server-side before any
upgrade worker starts.

The AICOM executor and capture retry loop now route the remaining release-risk
group default reads through `WFBE_CO_FNC_GroupGetBool`, avoiding the Arma 2 OA
group `getVariable [name, default]` unset-value trap for direct war-room orders
and the `wfbe_aicom_cappasses` anti-stall counter. LoadoutManager propagated the
Chernarus source edits to maintained Takistan and rebuilt `_MISSIONS.7z`.

Validation passed via `Run-WaspFinalCheck.ps1`: static smoke clean including the
new `Upgrade request authority guard` and `AICOM group variable default guards`,
Chernarus and Takistan A2/OA lint `FAIL: 0` / `REVIEW: 0`, and whole-mission
HIGH BugHunt clean. Package provenance must be regenerated after the final
journaled source commit so PR/wiki can bind to the final commit hash and archive
SHA.

## 2026-07-01 — Side-supply temp-channel authority guard [RELEASE LOOP]

Closed the small side-supply authority gap left after the earlier arithmetic
floor fix. `Server_ChangeSideSupply.sqf` now routes west/resistance/east temp
publicVariable handlers through one shared server helper, rejects malformed
payloads, rejects side/channel mismatches, requires scalar amounts, preserves
valid positive rewards and negative spend deltas, and keeps the authoritative
result clamped to `0..WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT`.

The Chernarus source edit was propagated to maintained Takistan with
`Tools\LoadoutManager`. Static validation passed via `Run-WaspFinalCheck.ps1`,
including the new `Side-supply channel authority guard` smoke check, Chernarus
and Takistan A2/OA lint `FAIL: 0` / `REVIEW: 0`, and whole-mission HIGH
BugHunt clean. Package provenance now passes for head `fd55c9f2c1` with
archive SHA256 `0CCA1F3804D250873A2D70F7733304FAE4F4EEE589BBF0DBBA7FCEC4CBB2AE2E`.
Runtime RPT collection and deployment remain approval-gated.

## 2026-07-01 — Placement preview flat-check split [RELEASE LOOP]

Absorbed the safe source part of PR #131 into the command-center release lane.
The player placement preview flat-ground check in `Init_Client.sqf` is now split
out into a local `_flatSpots` assignment instead of a dense inline
`count ((position _preview) isFlatEmpty ...)` expression. This preserves the
existing water/base-area/HQ exemption behavior, keeps the check gated by
`WFBE_C_STRUCTURES_FLAT_CHECK`, and makes the placement preview gate easier to
lint and review.

The Chernarus source edit was propagated to maintained Takistan with
`Tools\LoadoutManager`. Focused review found no Arma 2 OA SQF blocker, and
`Run-WaspFinalCheck.ps1` passed after the change. Runtime RPT collection and
deployment remain approval-gated.

## 2026-07-01 — PVF dispatcher registered-handler allowlist [RELEASE LOOP]

Closed the next bounded server-authority hardening lane from the wiki backlog.
The generic server and client PVF dispatchers now reject payload-selected
handler names unless they are in the registered `SRVFNC*` / `CLTFNC*`
allowlists exported by `Init_PublicVariables.sqf`; registered names still
resolve through `missionNamespace getVariable` and must be `CODE` before
spawning. The out-of-band GUER VBIED bounty client receiver is explicitly
added to the client allowlist at its existing manual registration point.

`Tools\LoadoutManager` propagated the Chernarus source edit to maintained
Takistan and rebuilt `_MISSIONS.7z`. Static validation passed: direct
`Test-WaspStaticSmoke.ps1`, `Run-WaspFinalCheck.ps1`, Chernarus and Takistan
A2/OA lint `FAIL: 0` / `REVIEW: 0`, and whole-mission HIGH BugHunt clean.
Runtime RPT collection and deployment remain approval-gated.

## 2026-07-01 — Handoff stale-archive negative self-test [RELEASE LOOP]

Added release handoff self-test fixtures for the package-race failure mode seen
during the automated release loop: generate a manifest, mutate `_MISSIONS.7z`
without changing its length, then repeat with a length-changing mutation. Both
run `New-WaspReleaseHandoff.ps1` in a child PowerShell process and assert that
it exits nonzero while still writing a diagnostic handoff packet with
`needs_package_or_marker_fix`; the same-length case proves
`archive-sha256-match=fail`, and the length-changing case proves both archive
freshness gates fail.

This does not change release packaging behavior; it makes the existing
hash-mismatch gate harder to regress before the runtime RPT handoff.

## 2026-07-01 — AICOM guardrail cleanup and PR #125 doc routing [RELEASE LOOP]

Folded two read-only scout findings into the release branch without changing
valid mission behavior. The low-pop AICOM banking valve now clamps
`WFBE_C_AICOM_LOWPOP_EXTRA_BY_TIER` before selecting by population tier, so
short or temporarily malformed tuning arrays cannot break the commander
supervisor. Command-console artillery requests now validate `[x,y]` scalar
positions at the server stamp point and again in both player/autonomous
artillery resolvers before any `nearEntities` call consumes the request.

LoadoutManager propagated the Chernarus source edit to maintained Takistan and
rebuilt `_MISSIONS.7z`. Repo release notes now record that the wiki source
intake map is already discoverable, with remaining work narrowed to
per-source cards. The public wiki release workflow was also re-routed so PR
#125 is the current packaged RPT gate and PR #126 is only a folded companion
guardrail/source-notes lane unless a new package is explicitly cut.

Runtime RPT collection and deployment remain approval-gated.

## 2026-07-01 — AICOM runtime scorer side-proof hardening [RELEASE LOOP]

Tightened the release RPT scorer's no-human AICOM gate so both WEST and EAST
must now show `TEAM_FOUNDED` plus at least one side-specific autonomous
action/progress token (`ASSAULT_DISPATCH`, `COMBATSTAT`, `FRONT`, `POSTURE` or
`SNAP`). The per-terrain self-test now includes a negative fixture that omits
EAST founding/progress and verifies the gate stays missing instead of passing on
WEST-only commander work.

Focused validation passed:
`Tools\PrTestHarness\Rpt\Test-WaspReleaseRptEvidence.PerTerrainSelfTest.ps1`
and `Tools\PrTestHarness\Rpt\Test-WaspRuntimeRptPacket.SelfTest.ps1`.
Runtime RPT collection and deployment remain approval-gated.

## 2026-07-01 — Group-cap diagnostic debounce [RELEASE LOOP]

Adapted the remaining bounded release-readiness source candidate:
group-cap diagnostics are now latched/throttled instead of repeating every
scan while the server stays near the Arma 2 OA side group cap. `GRPBUDGET|WARN`
now fires on the near-cap edge and emits `GRPBUDGET|RECOVER` when the count
drops below the threshold again; AI Commander founding cap warnings are limited
to once per side every 15 minutes while capped; lower-level create-group and
create-team failures are debounced per side/machine every five minutes.

This is source-only log-pressure reduction. It does not change caps, spawning
policy, runtime approval status, or deploy gates.

## 2026-07-01 — Final-check whole-root A2 lint gate [RELEASE LOOP]

Strengthened `Tools/PrTestHarness/Run-WaspFinalCheck.ps1` so the one-command
pre-test gate now runs the static smoke suite, whole-root A2/OA compatibility
lint for both maintained terrains, and whole-mission HIGH BugHunt before
returning success. This makes Chernarus/Takistan string-find or A3-only command
regressions fail the release gate before runtime RPT collection.
The static smoke dialect scan itself now checks changed files in both maintained
mission roots when running from the default repo layout, so direct
`Test-WaspStaticSmoke.ps1` runs do not stay Chernarus-only for dialect hazards.

Also folded the current AICOM/JIP seed patch into the same release checkpoint:
late-joining WEST/EAST clients now receive the current `WFBE_PopTier` and
side-keyed primitive AICOM intent/objective/status variables from
`Server_OnPlayerConnected.sqf`, reducing the chance that command-console/RHUD
objective state stays stale until the next strategic publish. The patch is
present in Chernarus and the maintained Takistan mirror.

The updated gate passed locally after the GUER armor classifier cleanup:
Chernarus lint `FAIL: 0` / `REVIEW: 0`, Takistan lint `FAIL: 0` /
`REVIEW: 0`, static smoke clean, and BugHunt HIGH clean. Runtime RPT collection
and deployment remain approval-gated; no local Arma launch, SSH, upload,
restart, cache clear or deployment action was performed.

## 2026-07-01 — Town AI HC fallback liveness guard [RELEASE LOOP]

Closed a source-only town-AI delegation gap found by the AICOM scout. In
`server_town_ai.sqf`, delegation mode 2 now counts only non-null HC registry
groups with non-null, alive leaders before suppressing server-side town-unit
creation. A stale `WFBE_HEADLESSCLIENTS_ID` entry can no longer make the town
FSM call HC delegation, drop every group inside `Server_DelegateAITownHeadless`,
and skip the server fallback for that activation.

The Chernarus source edit was propagated to maintained Takistan with
`Tools\LoadoutManager`, and the strengthened final pre-test gate passed:
static smoke clean, Chernarus/Takistan A2/OA lint `FAIL: 0` / `REVIEW: 0`,
and whole-mission HIGH BugHunt clean. Runtime RPT evidence is still pending and
approval-gated.

## 2026-07-01 — PR #126 guardrail intake into command-center lane [RELEASE LOOP]

Folded the low-risk release-readiness guardrails from the narrower PR #126 lane
into PR #125's command-center/package branch. The AI Commander supervisor now
uses per-side owner generations on the initial spawn and watchdog restart path;
the watchdog terminates the stored stale script handle before starting a
replacement, and old supervisors exit if they ever resume after being superseded.
The heartbeat proof token stays `AICOMHB|v1|` so the existing RPT scorer contract
does not drift.

Hardened AI Commander production/founding cap lookups against short or empty
`WFBE_C_TOTAL_AI_MAX_BY_TIER` arrays and normalized the retreat/refit order mode
to lowercase `"defense"`, matching the team-driver dialect. Also tightened town
and base static-defense HC delegation gates: stale `WFBE_HEADLESSCLIENTS_ID`
registry entries no longer suppress or delay the server-side gunner fallback
unless a live HC group leader is present.

Public wiki release-readiness docs are being realigned to PR #125 and its exact
runtime evidence matrix. Runtime RPT collection remains approval-gated; no local
Arma launch, SSH collection, live upload, restart, deploy, or rollback has been
performed in this loop.

## 2026-07-01 — AICOM lint cleanup and runtime-token source contract [RELEASE LOOP]

Tightened the PR #125 static release gate in two small ways. First,
`AI_Commander_Base.sqf` no longer uses literal `_names find "..."` scaffold
lookups for CBRadar/Bank/Reserve/ArtilleryRadar; it now uses a local
A2-safe index helper with the same first-match/-1 behavior. This removes the
last four `Lint-A2Compat.ps1` REVIEW items from both Chernarus and Takistan.

Second, `Test-WaspStaticSmoke.ps1` now has a
`Release runtime-proof token emitters` source contract across both maintained
terrains. It verifies that the mission still contains the AICOM, HC/delegation,
town cleanup, group-budget, supply, artillery and Takistan WEST fallback emitter
strings required later by the runtime RPT scorer. This is not runtime proof; it
keeps the package/static gate from going green after a cleanup accidentally
renames or removes the evidence emitters needed for the ten-file RPT matrix.

Also synced the Takistan in-game Help menu to the redesigned controller while
using Takistan-specific airfield/unlock text (`Loy Manara`, `Rasman AF`) and
current economy/bank/patrol values.

## 2026-07-01 — AICOM Strategy snapshot town-cache reuse [PR LOOP]

Reduced duplicate AICOM Strategy town scans in both maintained terrains. The
strategy supervisor already refreshes `wfbe_aicom2_snap` immediately before
`AI_Commander_Strategy.sqf`; Strategy now consumes the snapshot's owned-town
and capturable-town arrays for its town census, spearhead scorer/debug, and
optional artillery support-town guard, with the old live `towns` scan kept as a
fallback for direct/manual calls.

This is behavior-neutral: candidate sets and nearest-front calculations still
come from the same town ownership state for the strategy tick, but repeated
full-town rescans inside candidate scoring are avoided. Regenerated Takistan
through `Tools\LoadoutManager` and kept release proof runtime-pending.

## 2026-07-01 — PR #125 master merge gate decision [PR LOOP]

`origin/master` currently adds PR #121's editor-slot empty-group reaper in
`Server/Init/Init_Server.sqf` for both maintained terrains. The command-center
release branch intentionally keeps that behavior out because the cmdcon30
deadspawn investigation removed the editor-slot reaper and returned to
audit/tag-only handling for JIP-selectable player-slot groups.

The PR conflict should therefore be resolved by marking `origin/master` as
reviewed/merged while preserving the release branch tree for the two
`Init_Server.sqf` files. Runtime group-budget evidence can revisit this later,
but it should not be reintroduced blindly during final release gating.

## 2026-07-01 — Codex multi-agent release task opened [PR LOOP]

Opened the Codex release-readiness loop for the command-center candidate. Four
read-only scouts covered AICOM, release/RPT gates, wiki/source discipline, and
branch intake. The useful findings are now summarized in
`docs/release-readiness/2026-07-01-command-center.md` and will be mirrored into
the PR thread.

Historical package/handoff proof after the role-proof emitter commit:
candidate identity was `2bdf79f398`, package SHA256
`1B9D4FF61DBD7A1BA0BE01C31DEE394586AC1F11238EA75CB343992DFC01E4FA`,
1882 archive entries, and local handoff status remains
`ready_for_runtime_collection`.

Corrected the static smoke wording around the command-dialect gate:
`allMissionObjects` is an Arma 2 OA command per BI docs, so the gate now calls
its list forbidden/project-blocked rather than purely A3-only. The project still
blocks it in this release path because the current A2/OA compatibility gate is
conservative and source-bound.

## 2026-07-01 — Release runtime role-proof emitters [RELEASE LOOP]

Scout review found the round40 package could be package-clean but still fail the
runtime packet client-role proof: release `version.sqf` leaves `WF_LOG_CONTENT`
disabled, while the runtime checker expected client startup strings previously
emitted only through `WFBE_CO_FNC_LogContent`.

Added raw `diag_log` startup proof lines for the existing HC/client proof
strings in Chernarus and regenerated Takistan. This preserves quiet release
logging while keeping the exact ten-file runtime RPT packet provable. Added a
static smoke guard so both maintained terrains must keep those unconditional
role-proof emitters.

## 2026-07-01 — AICOM wildcard A2 dialect fix [RELEASE LOOP]

Removed project-blocked `allMissionObjects` usage from the retired W10 lucky
salvage wildcard branch. The sweep now uses `allDead`, matching the eligibility
proxy already documented earlier in `AI_Commander_Wildcard.sqf`, and
LoadoutManager propagated the fix from Chernarus into Takistan.

Reworded one help-menu sentence from "Unlocks apply..." to "Unlocks are..." so
the static smoke checker no longer false-positives on the A3-only `apply` token
inside a UI text line. After regen, `Run-WaspFinalCheck.ps1` passed: static
smoke clean and whole-mission high bug-hunt clean.

## 2026-07-01 — Package payload HEAD binding [RELEASE LOOP]

Tightened `Tools/PrTestHarness/Package/Test-WaspReleasePackage.ps1` so package
provenance now checks the complete archived Chernarus/Takistan mission payload
against `git` `HEAD`. The archive may contain the two generated ignored
`version.sqf` files, but every other mission file must be tracked under the
matching source mission root and hash back to the `HEAD` blob.

Added `Test-WaspReleasePackage.SelfTest.ps1`. The fixture runs the current
package as the happy path, then mutates temporary archive copies to add a stray
untracked mission file and to replace a tracked file with stale content. Both
must fail the new `git-tracked-mission-payload` gate.

## 2026-07-01 — Runtime handoff checklist identity coverage [RELEASE LOOP]

Tightened the generated release handoff checklist so operators see the same
release identity contract that the tooling now enforces: the private
`runtime-rpt-source-map.json`, generated `release-run-ledger.json`, packet
manifest and summary must agree on candidate, git and package archive SHA before
runtime proof can be accepted.

Extended `Test-WaspReleaseHandoff.SelfTest.ps1` to assert that the runtime
packet validator command itself carries `-ExpectedCandidate`, `-ExpectedGit` and
`-ExpectedArchiveSha256`, and that both generated source-map and run-ledger
templates contain the expected candidate/git/archive tuple.

Closed the adjacent summary-proof gap from the same pass: `New-WaspReleaseRptSummary.ps1`
now requires `runtime-rpt-packet-manifest.json` to include the packet validator's
core gates exactly once with `status=pass`, not only a scalar
`validation.overall=pass`. The per-terrain self-test now proves a forged/minimal
manifest with matching release identity, exact ten copied labels and no
validation gates still keeps the release summary red.

Follow-up in the same proof-chain pass: the summary also binds the packet
manifest's `rptRootHash` and per-file `copiedRptSha256` values to the single
scored `-RptDirectory`. A valid manifest from a different packet, or a manifest
with stale copied-file hashes, can no longer be paired with another scored
folder when producing release wording. The per-terrain self-test now includes
mismatched-root and stale-hash manifest fixtures.

## 2026-07-01 — Release handoff contract self-test [RELEASE LOOP]

Added `Tools/PrTestHarness/Release/Test-WaspReleaseHandoff.SelfTest.ps1` so the
runtime handoff packet now has a local synthetic contract test. The fixture
builds a fake `_MISSIONS.7z` plus package manifest, runs
`New-WaspReleaseHandoff.ps1 -AllowNonHeadReleaseGit`, and asserts the pending
runtime/deployment approval gates, package-manifest copy, runtime packet
builder/checker commands, runtime summary candidate/git/archive binding and the
ten-record source-map/run-ledger templates.

This keeps the release approval boundary testable without SSH, live server
access, local Arma launch or raw RPT collection.

Closed the adjacent runtime packet identity gap as well:
`New-WaspRuntimeRptPacket.ps1` now treats source-map `release.*` values as
defaults only when the command-line expectation is blank, and it fails if a
private source map disagrees with `-ExpectedCandidate`, `-ExpectedGit` or
`-ExpectedArchiveSha256`. `Test-WaspRuntimeRptPacket.ps1` now requires non-empty
matching run-ledger `release.candidate` and `release.git` whenever those
expected identity flags are supplied. The runtime packet self-test covers stale
source-map candidate drift plus blank ledger candidate/git/archive identity.

## 2026-07-01 — Runtime summary manifest release binding [RELEASE LOOP]

Tightened `New-WaspReleaseRptSummary.ps1` one step further: when a runtime packet
manifest is supplied for release handoff, the summary can require it and validate
the manifest's release candidate, git marker and package archive SHA before the
portable summary can pass. It also validates the actual copied packet labels for
`chernarus/{server,HC1,HC2,start-client,late-JIP}.rpt` and
`takistan/{server,HC1,HC2,start-client,late-JIP}.rpt`, not only the manifest's
file count and validation status.

The per-terrain self-test now includes malformed manifest fixtures for ten files
with the wrong Takistan HC2 copied path, a stale release git, and a missing
required manifest. The handoff generator now emits the bound summary command with
`-ExpectedCandidate`, `-ExpectedGit`, `-ExpectedArchiveSha256` and
`-RequireRuntimePacketManifest`, plus an explicit pending runtime-approval gate
before any local Arma launch/RPT collection.

## 2026-07-01 — Runtime packet self-test committed [RELEASE LOOP]

Added `Tools/PrTestHarness/Rpt/Test-WaspRuntimeRptPacket.SelfTest.ps1` so the
runtime packet builder/checker gates are reproducible instead of only recorded
as ad hoc round evidence. The fixture builds a synthetic ten-RPT packet from a
private-style source map, validates the happy path through
`New-WaspRuntimeRptPacket.ps1 -Validate`, then proves the checker rejects
duplicate RPT content, wrong client/HC role proof and a missing run-ledger
archive SHA. This keeps the runtime proof path stricter while live Chernarus and
Takistan RPT collection remains pending approval.

Also bound `New-WaspReleaseRptSummary.ps1` to the runtime packet proof path:
when `-RuntimePacketManifestPath` is supplied, the portable summary now requires
the packet builder manifest to have `validation.requested=true` and
`validation.overall=pass` with the exact ten copied RPT files. The handoff
summary command passes the manifest path, so a green release summary can no
longer be detached from the ten-file packet matrix, run-ledger, archive-SHA,
source/copy hash, freshness and role-proof validation.

## 2026-07-01 — Takistan WEST fallback runtime scorer gate [RELEASE LOOP]

The release RPT scorer now makes the round32 Takistan WEST infantry-starvation
fix mechanically provable instead of wiki-only: `Test-WaspReleaseRptEvidence.ps1`
tracks `AICOMGATE|WEST|infFallback` as `aicomWestInfFallback` and adds the
`takistan-west-aicom-infantry-fallback` gate against Takistan per-terrain token
counts. Generic `TEAM_FOUNDED`/`CMDRSTAT`/progress evidence can no longer pass
the release scorer if the exact-build Takistan WEST fallback marker is absent.

Updated the per-terrain self-test so a mirrored Chernarus/Takistan semantic
packet without the fallback marker fails only that new gate, then passes after
adding the Takistan WEST fallback line. The summary packet and handoff checklist
now surface the fallback token as a first-class runtime requirement.

## 2026-07-01 — AICOM infantry founding fallback integrated [RELEASE LOOP]

Cherry-picked `8de3c4a60` into the release command-center branch as
`b4df22ede`: when the founding eligibility strip leaves a side with no
stored-type-0 infantry template, `AI_Commander_Teams.sqf` now admits the
cheapest infantry template and logs `AICOMGATE|<side>|infFallback|...`.

This targets the Takistan WEST founding-0 starvation where upgrade-0 gating
could strip all BIS_US infantry templates because their base team leader is
upgrade tier 1, leaving only expensive armour candidates. The previous
cmdcon30 HC re-grab theory is now downgraded to supporting telemetry; runtime
proof still needs exact-build Takistan WEST evidence showing fallback fire,
`TEAM_FOUNDED`, `CMDRSTAT`, and AICOM progress without SQF/runtime errors.

Static status for the intake: `git diff --check` clean; full Chernarus and
Takistan `Lint-A2Compat.ps1` pass with four pre-existing array-`find` review
items in `AI_Commander_Base.sqf`; `Run-WaspFinalCheck.ps1` still reports the
known broad changed-file `A2 OA command dialect` smoke warning while BugHunt
has no HIGH suspects.

## 2026-07-01 — Per-terrain runtime evidence gate [RELEASE LOOP]

The release RPT scorer now splits runtime token counts by the RPT window's
resolved terrain and adds `per-terrain-runtime-evidence`. The existing aggregate
gates still report continuity, but the release cannot pass if only Chernarus (or
only Takistan) carries the AICOM, JIP, HC registry/delegation, town cleanup,
WDDM/static/artillery and supply token families. Each scored RPT must also
resolve to exactly one runtime terrain before those counts are accepted.

Added `Tools\PrTestHarness\Rpt\Test-WaspReleaseRptEvidence.PerTerrainSelfTest.ps1`.
It builds a synthetic ten-RPT packet where Chernarus has all semantic evidence
and Takistan has only marker/startup proof, verifies that the new gate fails,
then mirrors the evidence into Takistan and verifies the scorer passes.

## 2026-07-01 — Stronger AICOM runtime scorer gate [RELEASE LOOP]

The active release RPT scorer now carries the latest PR #122 scanner guardrail
forward into `Tools\PrTestHarness`: the no-human AICOM gate cannot pass on
heartbeat/tick/status lines alone. It now also requires `AICOMSTAT` event proof,
`TEAM_FOUNDED`, `CMDRSTAT` and at least one autonomous action/progress token such
as `ASSAULT_DISPATCH`, `COMBATSTAT`, `FRONT`, `POSTURE` or `SNAP`.
This matches the July 2 source-drift intent while keeping the release branch's
newer redaction-safe scorer and exact dual-terrain packet flow.

Follow-up in the same release loop: the final-check wrapper and BugHunt console
text were made ASCII-safe so the gate parses under both Windows PowerShell 5.1
and `pwsh`; logic is unchanged.

## 2026-07-01 — Release runtime packet builder and role-proof gate [RELEASE LOOP]

The release command-center tooling now has a source-map driven runtime RPT packet builder:
`Tools\PrTestHarness\Rpt\New-WaspRuntimeRptPacket.ps1`. Runtime operators fill a private
`runtime-rpt-source-map.json`, then the helper copies the exact ten Chernarus/Takistan role
RPTs, writes `release-run-ledger.json`, emits a redaction-safe `runtime-rpt-packet-manifest.json`
and can immediately call `Test-WaspRuntimeRptPacket.ps1`.

The packet validator now hardens role proof beyond "server vs non-server": HC files must show
HC-local startup tokens, player-client files must show client-local startup tokens, and the private
ledger must carry exact `roleProof` plus `joinPhase` for `start-client`/`late-JIP`. The release
handoff generator writes `runtime-rpt-source-map.template.json`, includes the builder command and
passes `-ExpectedCandidate` explicitly to the packet checker.

## 2026-06-28 — PR #119 low-id CIV HC slot magnet [PR]

PR #119 now layers the static lobby-slot experiment on top of the runtime HC CIV hardening. The two
plain CIV HC slots were moved to the lowest object ids (`0`, `1`) and `forceHeadlessClient=1` was
removed so A2-OA's `-client` auto-seat has normal playable CIV slots to choose before WEST id `229`.
The displaced non-playable LOGIC objects formerly using ids `0` and `1` were moved to unused high ids
`9007` and `9008`; they had no `synchronizations[]` back-references.

Smoke verdict still needs the live engine: success is both HCs logging `HCSIDE|v1|preseat|...|engineSide=CIV`.
If preseat remains WEST, the static lobby-label fix is refuted, but the runtime reseat/owner-keyed
registration from PR #118 still protects gameplay-side behavior.

## 2026-06-28 — HC CIV slotting hardening [PR]

Root cause is no longer "missing CIV HC slots": `origin/master` already has two CIV `forceHeadlessClient=1`
slots plus the B761/B762/B763 enrollment/vote fixes. The remaining failure surface is boot/restart timing:
HC-local reseat used mission `time`/`sleep`, server registration gave owner resolution only 3 seconds, and
the HC registry was keyed by UID even though A2 HCs may report empty/colliding UIDs.

Patch on `codex/hc-civ-slotting-live`:
- `Headless/Init/Init_HC.sqf`: use `diag_tickTime`/`uiSleep` for reseat deadlines, mark the pre-reseat
  magnet group, and briefly reannounce `connected-hc` after cold start.
- `Server/Functions/Server_HandleSpecial.sqf`: wait longer for owner, require server-observed CIV before
  registry capture, key/de-dupe HCs by owner ID, and prune HC magnet groups even when UID is empty.
- `Server/Functions/Server_OnPlayerDisconnected.sqf`: clean HC registry by owner for UID-empty HCs before
  the human disconnect path.

Verification: `dotnet run` in `Tools/LoadoutManager` regenerated Takistan and packed `_MISSIONS.7z`;
the touched Chernarus/Takistan files hash-match; `git diff --check` has no whitespace errors beyond the
repo's existing CRLF warnings.

## 2026-06-20 — JOIN SAGA: definitive root causes + fixes (B54/B56) [INCIDENT / POSTMORTEM — CORRECTS THE B49 ENTRY BELOW]

**READ THIS FIRST — it supersedes the 2026-06-19 B49 entry below.** The 2026-06-19 postmortem credited
a "45s fade watchdog" (B49) with fixing the join. **It did not.** That watchdog SILENTLY FAILED, and the
all-day black-screen-on-join was actually a **STACK of four distinct bugs**, each of which had to be peeled
off in order. The de-slot (#1 below) was necessary but not sufficient; the build kept failing the join
even after it. Here is the full, corrected record.

### The bug stack (fixed in order)

1. **Null-player "shell" slots in `mission.sqm` (the trap the B49 entry found).** The GUER 27→14 de-slot
   left 26 dead slots (13 WEST + 13 EAST) — `deleteVehicle this` leftovers — still listed in the
   `LocationLogicOwnerWest` / `LocationLogicOwnerEast` (ids 255/256) `synchronizations[]` rosters. In
   Warfare the units synced to the Owner logic *are* the side's playable roster, so the lobby kept offering
   all 27 slots/side. A JIP client that landed on a shell slot ran `deleteVehicle this` → **`player == objNull`**
   → stuck. **Fix:** de-slot them (drop the 26 ids from the two Owner-logic `synchronizations[]` lists and
   clear the shells' own back-reference sync). NECESSARY but NOT SUFFICIENT — the join still failed after this.

2. **JIP network DELIVERY stall — `basic.cfg` `MaxSizeGuaranteed`.** `MaxSizeGuaranteed=1024` fragmented
   guaranteed JIP messages above the MTU → the join state never landed; the server reported **199,511
   "pending" messages**. **Fix:** lower `MaxSizeGuaranteed` to **512** so guaranteed JIP messages fit a
   single datagram. CRITICAL: `basic.cfg` is **box-only and unversioned** — it lives on the server, not in
   the repo. *This is why every git rollback "never helped":* the network-delivery half of the failure was
   not in source control and no commit could touch it.

3. **The `sleep`-vs-`uiSleep` trap (why the B49/B52/B53 watchdogs silently failed).** The B49 "45s fade
   watchdog" and the B52/B53 fade-clear retries all gated on `sleep` / `waitUntil` / mission-`time`. **All
   three are PAUSED while a client sits on the loading screen** (the sim clock does not advance for a client
   still receiving the mission), so the watchdog's gate never opened and the screen-clear **never ran — with
   no error, hence "silently failed."** The B49 entry below credited a fix that physically could not execute
   on the stuck client. **Fix (B54):** clear the black fade layer **12452** with an **ungated `uiSleep`**
   loop — `uiSleep` runs on real wall-clock time and ticks even while the sim is paused. Necessary, still
   not sufficient on its own.

4. **THE definitive cause — un-timed `waitUntil` on JIP-synced team data in client bootstrap (B56).** Found
   only by reading the **joining player's CLIENT RPT** (not the server RPT). `initJIPCompatible.sqf` client-init
   Part II ran, for **every** side in `WFBE_PRESENTSIDES`, an **un-timed**
   `waitUntil {!isNil {_logik getVariable "wfbe_teams"}}` **BEFORE** `execVM "Client\Init\Init_Client.sqf"`
   (which holds the fade-clear). With GUER playable, the harass-only resistance side's logic **never resolves
   `wfbe_teams` on a JIP client**: `Init_Server` registers teams only for `[east, west]`; GUER is a separate
   gated block keyed on `WFBE_L_GUE`, and the rest of the codebase already excludes resistance everywhere via
   the `WFBE_PRESENTSIDES - [resistance]` idiom. So once GUER was a present side, **every JIP joiner blocked
   on that `waitUntil` forever** → `Init_Client.sqf` (and its fade-clear) **never ran** → permanent black.
   This is why #1–#3 each looked like progress but the join still died. **Fix (B56):** bound those waits with
   `uiSleep`-counter timeouts so client init **always** reaches `Init_Client` even if a side's teams never
   resolve. In `Missions\[55-2hc]warfarev2_073v48co.chernarus\initJIPCompatible.sqf` (~lines 265–287):
   - `while {(isNil "WFBE_PRESENTSIDES") && (_w < 80)} do { uiSleep 0.25; _w = _w + 1; };` (≤20s)
   - per-side `while {(isNil {_logik getVariable "wfbe_teams"}) && (_ws < 120)} do { uiSleep 0.25; _ws = _ws + 1; };` (≤30s)
   - falls through to `execVM "Client\Init\Init_Client.sqf";` unconditionally, with a `[WFBE][B56 JIP-FIX]`
     diag_log if `WFBE_PRESENTSIDES` was never set in time.

### Delivery
Shipped as a **fresh-named single `.pbo`** — both a cache-bust (returning players re-download cleanly instead
of reusing a stale local copy) and a clean transfer to the box.

### Lessons (the expensive ones)
- **Server boot-smoke is structurally BLIND to the JIP client path.** HCs are box-local with no real network
  hop, so they don't exercise guaranteed-message fragmentation or the client-side `waitUntil`. The server RPT
  looked healthy the whole time. **Only the joining player's CLIENT RPT revealed bug #4.** Always pull the
  failing client's RPT for a join failure — the server's is not enough.
- **A2 LESSON (permanent-black landmine):** *any* un-timed `waitUntil` on JIP-synced data in the client
  bootstrap is a permanent-black trap. **Bound it with a `uiSleep` counter.** `sleep` / `waitUntil` /
  mission-`time` are **paused on the loading screen**; only `uiSleep` (real wall-clock) ticks while the sim
  is paused — so any "rescue/watchdog" timer in the client bootstrap MUST use `uiSleep`, never `sleep`/`time`.
- **Part of the failure lived OUTSIDE git** (`basic.cfg`, box-only). When git rollbacks "do nothing,"
  suspect unversioned box-side config, not just stale source.
- The 2026-06-19 entry's lesson "roll FORWARD to the fix" was directionally right, but the specific fix it
  named (B49 watchdog) was a no-op on the stuck client. The real fixes were B54 (`uiSleep` fade-clear) and
  **B56** (bounded client-bootstrap waits) plus the box-side `basic.cfg` change.

Touched/relevant files: `Missions\[55-2hc]warfarev2_073v48co.chernarus\initJIPCompatible.sqf` (B56 bounded
waits, ~265–287), `...\Client\Init\Init_Client.sqf` + the 12452 layer (B54 `uiSleep` fade-clear),
`...\mission.sqm` (#1 de-slot of the 26 shell slots), and the **box-only** `basic.cfg` (`MaxSizeGuaranteed
1024→512`, not in repo).

---

## 2026-06-20 — B57 — AICOM massive update [WORKING STATE / DEPLOYED]

**Deployed as `[55-2hc]warfarev2_073v48co_b57.chernarus` (Chernarus).** Boot-smoke clean; runtime-confirmed:
founding-pad logs *"B57 padded infantry team to floor (8 units)"*, **0 runtime errors**, **FPS 47 @ AI=84**.
Server-side only; A2-OA-1.64-safe throughout (no `pushBack`/`isEqualType`/`isEqualTo`; `+_template` copies,
`getDir`, `typeName ==`). Towns kept HARD by design — the AI overcomes them via **bigger + more concentrated
teams**, not softened garrison/capture rates.

### Centrepiece: LARGER AI-commander groups (the "thin team" fix)
- **Root cause.** Live teams are HC-founded at raw template size (3–6) and **never refilled**:
  `AI_Commander_Produce.sqf` (~line 63) skips `wfbe_aicom_hc` teams — which are **100% of live teams**
  (`CMDRSTAT srvTeams=0`). So the `WFBE_C_AICOM_TEAM_SIZE_MIN=8` floor and the deficit-fill logic inside
  Produce are on a **DEAD path** (they only fire for server-local teams, of which there are none in this build).
- **Fix.** Pad infantry/mixed templates up to the floor (8–12) **AT FOUNDING**, in
  `AI_Commander_Teams.sqf` (~lines 279–306, right after the template pick): find the team's `"Man"` class,
  `_template = +_template` (copy so the shared template isn't mutated), then append that class until
  `count _template >= WFBE_C_AICOM_TEAM_SIZE_MIN`. **Skips MBT and attack-heli templates** (the vehicle is the
  punch; no infantry floor). Logs `B57 padded infantry team to floor (N units)`.

### Constants (`Common\Init\Init_CommonConstants.sqf`)
- `WFBE_C_AICOM_TEAMS_PC_LOW` **5 → 10** (line ~139) — max HQ teams/side at low pop; pairs with the
  founding-pad so ~10 teams found at 8–12 each. ~10×8=80/side, under `TOTAL_AI_MAX` 130 (watch server FPS).
- `WFBE_C_AICOM_CONCENTRATION` **4 → 6** (line ~198) — more teams massed on the primary spearhead.
- `WFBE_C_AICOM_ASSAULT_REACH_FOOT` **3500 → 3000** (line ~335) — keeps thin foot teams on adjacent reachable
  towns; cuts long death-marches, tighter contiguous front.
- `WFBE_C_ECONOMY_SUPPLY_INCOME_MULT = 0.35` (line ~364) — throttles long-term town SUPPLY income (buildings/
  upgrades pace). Applied at `Server\FSM\updateresources.sqf` line ~76 (only when `_currency_system == 0`).
  **Cash/funds and the starting-supply seed are UNCHANGED** (Ray's split: cash = units, supply = buildings+upgrades).
- (Note: the inline rationale comment on `TEAMS_PC_LOW` references "CONCENTRATION=4" in its prose — stale
  comment text; the **active** value is 6.)

### Adopted from `feat/aicom-fleet-improvements` (commit `cc5090be`), graded for legacy-fit + A2-safe
- **Retreat-and-Reform** — `AI_Commander_Produce.sqf`.
- **Last-Stand + HQ-strike → 8-towns gate + persisted `wfbe_aicom_strat_mode`** — `AI_Commander_Strategy.sqf`.
  **DELETED** the branch's call to the non-existent `WFBE_CO_FNC_RadioMessage` (would have errored on legacy).
- **HC cold-start retry** — `Server_HandleSpecial`.
- **Town-defender skill spread** — `Common_CreateTownUnits`.
- **Snappier team loop** — `Common_RunCommanderTeam`: arrival = capture-range; poll **20s → 8s**.
- **Dead-patrol-marker scrub** — `server_side_patrols`.
- **`[AICOM BOOT]` / `[BRIEF]` telemetry** — `AI_Commander.sqf`.

### Deliberately SKIPPED from that branch (would regress legacy)
- Its `initJIPCompatible` + `Init_Towns` (carry the `sleep`-trap — see the join saga above; legacy already
  has the `uiSleep`-bounded B56 version).
- `Client_HandlePVF` / `Server_HandlePVF` (deployed already has the CODE-guarded version).
- `Init_CommonConstants` color change (would clobber the GUER 3-branch colors).

### Other B57 changes
- **Player map-marker direction fix** — `Client\FSM\updateteamsmarkers.sqf` (~line 208): the team marker used
  the **velocity vector** (direction of *travel*), so the arrow pointed wrong when a unit strafed/slid. Now
  `_dir = getDir _leaderVehicle` (`vehicle _leader`), correct on foot **and** mounted; matches the patrol/AICOM
  arrow loops. A2-OA-safe.
- **Lobby slot reorder** — grouped by **real role** per side. Classnames are misleading (`*_TL`/`*_CO` are
  Engineers/Support per the slot *description*, not team-leaders/commanders). New order:
  **Medic → Engineer → Support → Rifleman → Sniper**. Verified a **pure permutation** (ids, syncs, items,
  braces all unchanged); the HC-parking CIV slots stay pinned.
- **HQ start-variety** — `WFBE_C_BASE_STARTING_MODE` is already `2` (random) (line ~287), but A2's `random`
  is **deterministic on a fresh dedicated-server process** → the same start every match. Fixed with a
  per-match RNG perturbation in `Init_Server` (inside the `_use_random` block), seeded by a
  `profileNamespace` counter so each match seeds differently.

### Touched files
`Server\AI\Commander\AI_Commander_Teams.sqf` (founding-pad), `...\AI_Commander_Produce.sqf` (Retreat-and-Reform),
`...\AI_Commander_Strategy.sqf` (Last-Stand / HQ-strike / strat_mode), `...\AI_Commander.sqf` (telemetry),
`Common\Init\Init_CommonConstants.sqf` (constants), `Server\FSM\updateresources.sqf` (supply mult),
`Client\FSM\updateteamsmarkers.sqf` (marker dir), `Server\Init\Init_Server.sqf` (start-variety RNG),
`Server_HandleSpecial` / `Common_CreateTownUnits` / `Common_RunCommanderTeam` / `server_side_patrols`
(adopted helpers), `mission.sqm` (slot reorder).

---

## 2026-06-19 — Join failure ("Receiving mission") — root cause + fixes [INCIDENT / POSTMORTEM]
> **SUPERSEDED — see the 2026-06-20 "JOIN SAGA" entry above.** This entry's central claim (that the B49
> "45s fade watchdog" fixed the join) is WRONG: that watchdog gated on `sleep`/`time`, which are paused on
> the loading screen, so it silently never ran. The de-slot below was necessary but not sufficient; the
> definitive fixes were B54 (`uiSleep` fade-clear), B56 (bounded client-bootstrap `waitUntil`s), and a
> box-only `basic.cfg` `MaxSizeGuaranteed` 1024→512. Kept verbatim below for the historical record.

**SYMPTOM.** Multiple players could not join the live Chernarus server: clients hung on
"Receiving mission" / a permanent black screen and never finished loading. **Not load-related** —
the server had been running fine under heavy AI (had soaked at ~600 AI without trouble). The failure
was state/slot/timing dependent (it got more likely as lobby slots churned over a session), not
correlated with player count or AI count.

**ROOT CAUSE (high confidence — multi-agent RCA, confirmed in code + git).** Two things combined:

1. **The deployed build was PRE-B49** and therefore lacked the join-robustness null-guard.
2. **The Chernarus `mission.sqm` still offered ~26 dead "shell" lobby slots** (13 WEST + 13 EAST) —
   leftovers of the GUER 27→14 de-slot (`sqm_cut.py`). That script removed `player="PLAY CDG"` from
   13 units/side and appended `removeAllWeapons this; deleteVehicle this` to each, **but left all 27
   ids/side synchronized to `LocationLogicOwnerWest/East`.** In Warfare, the units synced to the Owner
   logic *are* the side's playable roster, so the lobby kept offering all 27 slots/side.

   A JIP client that landed on one of these shell slots ran `deleteVehicle this` → **`player == objNull`**.
   In the pre-B49 `Init_Client.sqf`, the very first real statement (`sideJoined = side player;`) on a
   null player silently broke the entire client init. That meant the **BLACK FADED fade** opened in
   `initJIPCompatible.sqf` (`12452 cutText [..., "BLACK FADED", 50000];`, ~50000s ≈ 13.9h) was **never
   cleared** by the normal "BLACK IN" at the end of `Init_Client` → permanent black / stuck on
   "Receiving mission."

**FIX (shipped).** Two layers, both now on `claude/deslot-shellslots` (HEAD `b27c5c9e`):

- **Roll FORWARD to the B49 join-robustness** (commit `f4308e6d`), which the bad build predated:
  - `Client/Init/Init_Client.sqf`: a **45s fade watchdog** — `waitUntil { clientInitComplete ||
    (time - _t0 > 45) }`, then `12452 cutText ["", "BLACK IN", 1]` so a stalled client clears the
    screen instead of staring at black; **plus** `if (isNull player) exitWith {...}` *before* the
    `side player` call, so a null-player join bails gracefully instead of breaking init.
  - `Server/Functions/Server_OnPlayerConnected.sqf`: `!isNull _x` guard in the team-lookup loop.
  - **Deployed commit `1e023fa0`** (`Revert "feat(B50): server-ready gate…"`) as the live HEAD —
    it contains the B49 robustness without the B50 gate (see lessons).
- **Proper hardening — remove the trap at the source** (commit `b27c5c9e`): drop the 26 shell ids
  (13W+13E) from the two Owner LOGIC `synchronizations[]` lists (27→14 ids each) and clear the shells'
  own back-reference sync. The empty self-deleting groups are left in place (no Unit class removed, no
  `items=` recount → low-risk, no renumber), but the engine no longer enumerates them as side slots,
  so **the lobby never offers a null-player trap again.**

**WRONG TURNS / REFUTED HYPOTHESES (the "other stuff found").** Before the real cause was nailed,
several theories were chased and then **disproven**:
- mission name / cache collision,
- heavy-AI JIP overload,
- a ~10× server restart loop,
- object-ID exhaustion,
- convoy-truck (vehicle) leaks,
- the B50 server-ready gate.

Several of these came from a **stale / secondhand server log that did not match the live RPT** — the
live RPT was actually healthy. Time was lost analyzing the wrong window.

**LESSONS (read before debugging the next join failure):**
1. **Triage on the failing-window RPT, not a stale or secondhand one.** A healthy live RPT next to a
   scary old log = the old log is the red herring. Confirm the timestamps match the incident window.
2. **When the failure is a recently-FIXED regression, roll FORWARD to the fix — do NOT roll back to an
   older "known-good" that predates it.** Repeatedly restoring pre-B49 builds *made it worse* (each
   restore re-introduced the missing null-guard).
3. **Deploy a single coherent commit, not ad-hoc overlays onto stale on-disk files.** The live HEAD is
   `1e023fa0`; know exactly what commit is running.
4. **Don't hold client init behind a server-ready gate.** The B50 server-ready gate (`ede75180`)
   caused deadspawn deaths and was reverted (`1e023fa0`). Client init must not block on server state.
5. **Don't rename the live public mission.** Renaming invalidates the local cache of every returning
   player (they re-download → look like new "Receiving mission" stalls). Keep the public mission name stable.
6. **The box has scheduled tasks that can auto-redeploy / rename the mission** — these were disabled
   during the incident so they couldn't silently overwrite the fix or churn the mission name. Re-check
   them before declaring the box stable.

Touched/relevant files: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf`,
`.../initJIPCompatible.sqf`, `.../Server/Functions/Server_OnPlayerConnected.sqf`, `.../mission.sqm`.
Key commits: `f4308e6d` (B49 robustness), `ede75180`→`1e023fa0` (B50 gate added then reverted, = deployed HEAD),
`b27c5c9e` (de-slot the 26 shell slots).

---

## 2026-06-15 — Group-budget hygiene: 3 code extras (slot cut CANCELLED) [WORKING STATE]

**Decision (Steff, 2026-06-15): SKIP the 27→21 editor player-slot cut.** Reason: the deep research
concluded the cut buys **zero FPS** (empty persistent slot-groups cost nothing on the hot path) and
only frees headroom on WEST/EAST — which sit at ~42-45/144 even at full pop and are nowhere near the
cap. The real budget pressure is GUER's dynamic groups, which the slot cut does not touch. The
mission.sqm surgery (delete + renumber 100+ items across Chernarus AND Takistan) is high-risk for no
gain. **mission.sqm left UNTOUCHED** (Chernarus Groups.items stays 129; HEAD `80e38a423`).

Proceeding with the 3 genuinely-useful code extras (Chernarus source; Takistan inherits via the
`SERVER_DEBUG` regen at deploy time — do NOT hand-edit Takistan):

1. **[~] Cap aicom extra teams at 2** — `Common/Init/Init_CommonConstants.sqf` add
   `WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA = 2;` after line 122. Confirmed `AI_Commander_Teams.sqf:60`
   reads this var with an inline fallback of 4; the constant did not exist in Init_CommonConstants.
   Caps late-game dynamic AI teams at base+2 (=6) instead of base+4 (=8) → saves up to 2 groups/side.
2. **[~] GUER group monitor** — `Server/FSM/server_groupsGC.sqf`. GUER's real ceiling is the SOFT cap
   `WFBE_C_GUER_GROUPS_MAX` (=60, recently 90→60), NOT 144 — at the soft cap `server_town_ai.sqf:62`
   DEFERS garrisons (town defense degrades). Add (a) a `GUERCAP|v1|count|max|pct` telemetry line at
   the 60s GCSTAT cadence for the dashboard gauge, and (b) a debounced (5-min) WARNING when
   `_cntGuer >= 90% of WFBE_C_GUER_GROUPS_MAX`. Distinct from the existing 130/144 engine-cap warning.
3. **[~] Untagged-leak diagnostic** — `server_groupsGC.sqf` audit loop. Now that editor slots are
   tagged `editor-player-slot` and all wrapper spawns are tagged, a NON-empty `untagged` group =
   a raw createGroup that bypassed the wrapper = real leak. Fold into the existing forEach allGroups
   audit loop (no extra pass): count non-empty untagged groups per side where side != sideEmpty,
   emit `UNTAGLEAK|v1|west|east|guer|samples` + debounced WARNING (warmup >600s).

**Also (Steff 2026-06-15): GUER soft cap raised 60 → 80** (`WFBE_C_GUER_GROUPS_MAX`) — more garrison
headroom above the ~73 peak, still well under 144; the new monitor watches it.

**STATUS: all 4 changes implemented + verified.** The three `[~]` above are DONE plus the GUER-cap bump.
- **Lint-A2Compat: PASS** (0 FAIL; the 4 REVIEWs are pre-existing find-quote in `AI_Commander_Base.sqf`).
- **Adversarial review (3 lenses: A2-runtime / logic+false-positive / integration): PASS** — 0 runtime
  blockers, 0 logic blockers. Two non-blocking fixes applied: (a) `server_groupsGC.sqf:304` dropped a
  redundant `str` (samples already strings — was double-quoting); (b) `SkinSelector_Apply.sqf:83` tag
  now broadcasts (`,true`) so the server audit can actually see `skin-swap`. The lone "blocker" was the
  known Takistan regen step (`dotnet run` syncs the stale Takistan copies), already in the deploy checklist.
- Touched files: `Init_CommonConstants.sqf` (2 lines), `server_groupsGC.sqf`, `SkinSelector_Apply.sqf`.

Remaining: commit to `deploy/2026-06-12-aicom-experital` (**hold push for Steff's consent**).

### Discovered issues (off-scope) — Workstream B (dashboard, box-side)
- **EMPTYGRP telemetry is silently dead in the dashboard.** `server_groupsGC.sqf` emits `EMPTYGRP|v1|`
  but `C:\WASP\Update-PublicStats.ps1` parses for `GRPEMPTY|v1|` (prefix mismatch). Pre-existing, not
  from this diff. One-line regex fix on the box. Same pass could teach the parser the new `GUERCAP|v1|`
  (GUER soft-cap gauge) and `UNTAGLEAK|v1|` (leak counter) lines — the "deeper per-faction info" Steff asked for.

---

## 2026-06-15 — Staged-deployment items (Discord deploy thread)

Source: OCD deploy-planning thread (Marty / Zwanon / Net_2). Scope = 4 items + a Miksuu-site dashboard view.

### Findings (verified 2026-06-15)
- **Group GC suite ALREADY on this branch** and committed: `server_groupsGC.sqf` (full + throttled),
  `Client/Functions/Client_GroupsGC.sqf` per-HC sweep wired at `Headless/Init/Init_HC.sqf:139`,
  `Common/Functions/Common_CreateGroup.sqf` registered at `Common/Init/Init_Common.sqf:111`.
- **Deploy branch is NEWER than Marty's live box** (`a2wasp-grpleak/_boxlive`): branch adds `GCSTAT|v1`
  per-pass line + D2 audit-every-N server-FPS throttle (`WFBE_C_GROUPAUDIT_EVERY`) + persistent-empty
  tracking. Box has a `dgEmpty` (defense-gunners) sub-metric the branch lacks. → DO NOT overwrite with
  box (would drop the throttle). Optional: graft the `dgEmpty` sub-metric only.
- **logcontent**: `LOG_CONTENT_STATE` is driven by `#define WF_LOG_CONTENT` in `version.sqf`
  (`initJIPCompatible.sqf:4-13`). `version.sqf` is absent from source (build-generated) → currently
  "NOT ACTIVATED" for server/clients; HCs force ACTIVATED at runtime (`initJIPCompatible.sqf:60`).
- **No client→server FPS telemetry** exists. `Common_PerformanceAudit.sqf` logs each machine's own
  `diag_fps` to its own RPT only (gated by `WFBE_C_PERFORMANCE_AUDIT_ENABLED`).

### Plan / progress
- [x] **FPS telemetry** (Chernarus). New `Client/Functions/Client_FpsReport.sqf` (player-only sampler,
      avg+min over 5×1s, staggered, self-gated on `WFBE_C_CLIENT_FPS_REPORT`); spawned from
      `Client/Init/Init_Client.sqf` tail; server PV receiver `WFBE_FPS_REPORT` in `Server/Init/Init_Server.sqf`
      (after Group-GC spawn) → `diag_log "FPSREPORT|v1|uid|fps|fpsMin|players|dnMode|daytime|sun|srvFps|t|name"`;
      two lobby params in `Rsc/Parameters.hpp` (`WFBE_C_CLIENT_FPS_REPORT` 0/1 def 0, `..._INTERVAL` def 60s).
      Lint-A2Compat: **PASS, 0 FAIL** (4 pre-existing REVIEWs in AI_Commander_Base, not mine).
- [x] **logcontent (#4)** = BUILD CONFIG, not a source edit. `version.sqf` is gitignored + generated by
      LoadoutManager; `BaseTerrain.cs:386` emits active `#define WF_LOG_CONTENT` for `SERVER_DEBUG`/
      `AIRWAR_SERVER_DEBUG`. → **Pack the staged release with `dotnet run -c SERVER_DEBUG`** (from
      `Tools/LoadoutManager`) and logcontent is ON for every map. No committable file. (Marty's own note
      at `BaseTerrain.cs:343`: changing the value alone does nothing — the line must be uncommented, which
      the SERVER_DEBUG config does.)
- [x] **Group GC (#1/#2)** already on branch + AHEAD of Marty's box (server throttle). Per-HC reaper present.
      Did NOT re-port (would regress). Optional `dgEmpty` graft: SKIPPED (don't destabilise throttled audit).
- [~] **Takistan / modded maps**: DEFERRED to deploy build. Takistan on this branch is STALE vs Chernarus
      (missing per-HC GC exec, deadspawn-safety, PickLeastLoadedHC, egress gate, restart/dashboard/playerstat
      emitters, FPS-profiling, empty-veh-timeout tune — all unrelated to this work). `SERVER_DEBUG` regen
      reproduces ALL of it from Chernarus at build time. Do NOT hand-mirror; do NOT sweep a catch-up regen
      into this feature commit.
- [ ] Commit Chernarus on `deploy/2026-06-12-aicom-experital` — **hold push for Steff's consent**.

### Discovered issues (off-scope)
- Takistan (`Missions_Vanilla/[61-2hc]...takistan`) is well behind Chernarus on this branch — needs a full
  `SERVER_DEBUG` regen before any release cut, independent of the FPS work.

### Workstream B (Hetzner live-stats dashboard) — CORRECTED TARGET + ACCESS
- **NOT the Miksuu Next.js site, NOT dashboard-v4.** It's the bespoke live-stats SPA at
  **http://78.46.107.142:8080/** ("Miksuu's Warfare — Live Server Stats"), served from the **Hetzner box**.
- **Access**: box = Windows, SSH/RDP as `Administrator` (Posh-SSH password auth from Main PC; key auth NOT
  set up). Scratch = `C:\WASP`. (pw in [[miksuu-hetzner-test-server]] memory.)
- **Source (box-only, NOT in any repo)** — pulled to `C:\Users\Steff\miksuu-dashboard-work\`:
  - `Serve-PublicStats.ps1` — HttpListener :8080 (http.sys → PID 4 System); serves whitelist from `C:\WASP\web`:
    index.html, stats.json, next-stats.json, next-changelog.json. Scheduled task `WaspStatsWeb` (ONSTART, SYSTEM).
  - `Update-PublicStats.ps1` (85 KB) — RPT parser + `stats.json` generator (parses AICOMSTAT/ORBATSTAT/DELEGSTAT/
    `group audit`/WASPSTAT). `-MissionLabel WASP|NEXT`.
  - `C:\WASP\web\index.html` (80 KB) — the front-end (tabs + JS), fed by `stats.json` (135 KB aggregate).
- **"the NEXT page" = the `NEXT / V2` tab** (dev diagnostic for the V2 branch; currently DOWN/NaN).
  index.html anchors: nav btn L185, panel `#tab-nextv2` L364-448, JS L1061-1229, `renderTab` L1254,
  fetches `/next-stats.json` + `/next-changelog.json`.
- **Plan (FULL, approved)**:
  1. Remove NEXT/V2 tab (nav+panel+JS+polling); drop `renderTab` nextv2 branch.
  2. Add "Force & Group Health" to Overview (after Order of Battle L255): per-side W/E/G group **n/144**
     cap gauge (amber≥130 red≥144) + empty/leaked groups (`GRPEMPTY`) + delegation% — the group-limitation
     analysis made public. Data already partly present (`c.groups.west/east/guer`, L843); add a
     `groupHealth` object to `Update-PublicStats.ps1` from `group audit [SIDE] N/144` + `GRPEMPTY|` parsing.
  3. Visuals/perf: favicon 404 fix; faction-gauge styling; audit Benchmarks/Balance/Top Players tabs.
  4. Later: surface client `FPSREPORT` (Workstream A) as a day-vs-night panel once it deploys.
- **Deploy**: zero game impact (web task only); back up index.html + Update-PublicStats.ps1 on box (.bak),
  push, restart `WaspStatsWeb`, verify live via browser. Respect [[hetzner-deploy-consent-policy]].
- **DEPLOYED & LIVE 2026-06-15** on the box (`C:\WASP\web\index.html` + `C:\WASP\Update-PublicStats.ps1`,
  `.bak-claude-*`/`.bak-v2pre-*` kept). NEXT/V2 tab removed; "Force & Group Health" live with real data
  (W/E/G n/144 gauges + GC footer reaped/emptyFound from `GCSTAT|v1|` 60s). Generator parse-checked +
  unit-tested; front-end validated headless (0 console errors). NOTE the ~2-min publish-delay buffer:
  a freshly-deployed field reads null for ~2-3 min before the buffer catches up (not a bug). Source +
  access documented in [[miksuu-live-stats-dashboard]] memory. Local working copy: `miksuu-dashboard-work/`.
- **STILL OPEN (part of "full plan")**: visuals/perf pass on the Benchmarks / Balance / Top Players tabs
  (only Overview + favicon done so far); and surfacing the Workstream-A client `FPSREPORT` as a
  day-vs-night panel once that mission build deploys to the live server.

---

## 2026-06-12 — Artillery Radar + Reserve buildable structures (WDDM integration)

Two new commander-buildable structures, mirroring the CBR/Bank pattern (cfc1fb93):

- **ArtilleryRadar** — `USMC_/RU_WarfareBArtilleryRadar` (CO) / `US_/TK_..._EP1` (OA).
  Cost 2400, MediumSite, dis 21, dir 90. Gate `WFBE_C_STRUCTURES_ARTILLERYRADAR = 1`.
- **Reserve** — `Land_Mil_Barracks_i` (CO) / `Land_Mil_Barracks_i_EP1` (OA — intact model
  inferred safe from the `Land_Mil_Barracks_i_ruins_EP1` WFBE_C_STRUCTURES_RUINS precedent).
  Cost 2000, MediumSite, dis 30 (walls reach ±24 m). Gate `WFBE_C_STRUCTURES_RESERVE = 1`.

Both use **MediumSite** → the standard phased construction animation path
(LocationLogicStart / WFBE_B_Completion), same as the factories — NOT preplaced.
Auto-walls fire from Construction_MediumSite (exclusion list untouched), pulling the
CHOSEN WDDM designs added to Init_Defenses.sqf:

- `WFBE_NEURODEF_ARTILLERYRADAR_WALLS` — "walled boom-gate checkpoint": HESCO 5x ring,
  3 m front gap, cones + danger sign; boom gate `Land_BarGate2` on A2/CO, jersey-block
  chicane fallback on OA standalone (BarGate is A2 content).
- `WFBE_NEURODEF_RESERVE_WALLS` — "floodlit walled yard": HESCO 10x yard, corner
  watchtowers (`Land_Fort_Watchtower[_EP1]` per content set), `Land_Ind_IlluminantTower`
  over the bays (confirmed both content sets via Core_CIV/Core_TKCIV).

Plumbing: RequestStructure allowed-list +2, marker labels ("AR"/"RES"),
Client_FNC_Special build-started cases, stringtable `RB_Artillery_Radar`/`RB_Reserve`,
shorthand vars `<side>ARTRAD`/`<side>RES`. Per-design intent: the Artillery Radar takes
fortifications only (walls, no gun defenses) — its template contains zero crewed weapons.

LoadoutManager run synced Takistan (7za pack step fails — documented-ignorable). NOTE:
the generator clobbers owner hand-edits in `EASA_Init.sqf` (re-adds stripped defaults,
54ad0732) and `Sounds\description.ext` (volumes 1→7) on the CHERNARUS side — those four
generated-file changes were reverted before commit; Takistan committed state already
matches generator output. Needs an in-engine build test of both structures.

---

## Task 28 — Port Patrols v2 at upgrade index 23 (2026-06-10)

WFBE_UP_PATROLS = 23 (CBR = 22 stays). All faction arrays grow to 24 entries.

PR #25 dependency check: server_side_patrols.sqf only needs WFBE_HEADLESSCLIENTS_ID
and HandleSpecial/RequestSpecial — both already present in experital pre-#25. No PR #25
symbols needed.

Old system retired: Init_Towns random flagging + server_town_ai spawn gate removed.
server_patrols.sqf / Server_GetTownPatrol.sqf left as dead code (same as master).

Group A (21 entries→24): RU, USMC, CDF, INS, OA_TKGUE, OA_US — add UNITCOST+CBR+Patrols padding
Group B (22 entries→24): OA_TKA — add CBR+Patrols padding
Group C (23 entries→24): CO_GUE, GUE, CO_RU, CO_US — add Patrols only

---

## 2026-06-10 — Investigation: BuyUnits dropdown forEach over `[objNull]` (GUI_Menu_BuyUnits.sqf)

**Question:** Did commit `c8071eeb` (airfield capture / Task 12) introduce a regression where the
factory-dropdown `forEach _sorted` at ~line 282 iterates `[objNull]` when no depot/airport is in range?

**Verdict: pre-existing since the original WFBE import — NO new regression.**

Evidence:
- `git log -L 250,290` on the file: the `_sorted = [[...] Call WFBE_CL_FNC_GetClosestDepot];`
  wrapping is unchanged context in `c8071eeb`; the commit only ADDED `_closest = _sorted select 0;`.
- Initial import `96809ac3` already has the identical wrap + the same `forEach _sorted`, and the
  Depot/Airport branches never set `_closest` (file-top init `_closest = objNull;`, line 8).
- `_sorted` was never carried over from the `default` factory branch — every switch branch always
  assigned it, including in the original code.
- `Client_GetClosestDepot.sqf` / `Client_GetClosestAirport.sqf` always return objNull-or-entity
  (init `_closest = objNull`, returned as last expression) — never nil, so the wrap is always a
  1-element array and `select 0` is safe.
- With `_x = objNull`: `Common_GetClosestEntity.sqf` returns objNull harmlessly (`distance` vs a
  null object = 1e10, never `< 100000`), then `objNull getVariable 'name'` → nil → the `_txt`
  concatenation on line 280 errors → broken/missing dropdown entry + RPT "Undefined variable"
  spam. Same behavior before and after `c8071eeb`.
- `c8071eeb` actually FIXED a real carry-over bug: before it, on Depot/Airport tabs `_closest`
  kept its stale value (objNull init, last factory from the `default` branch, or the dropdown
  handler at line 191), so the queue display at line 290 could read the wrong object's "queu".
  Downstream is objNull-tolerant (`isNil '_queu'` guard, `getVariable` on objNull → nil).

### Discovered Issues (off-scope, optional hardening)
- Cosmetic, since 2010: opening the Depot/Airport tab with none in purchase range puts one broken
  entry / RPT error in the 12018 dropdown. Cheap fix if ever wanted:
  `if !(isNull (_sorted select 0)) then { ...forEach _sorted... }` around the lbClear/forEach
  block (or `lbAdd [12018, localize 'STR_...none-in-range']` in the else).
