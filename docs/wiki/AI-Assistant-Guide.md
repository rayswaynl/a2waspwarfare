# AI Assistant Guide

Minimal first-touch page for humans and AI agents working on docs and orchestration in this repository.

## What this page is

- A compact bootstrap for discovery and safety.
- A map to the fastest trusted starting path before opening legacy code.
- A low-risk place to confirm source truth before touching legacy networking, lifecycle, or runtime assumptions.

## Where it lives

- Wiki: `docs/wiki/AI-Assistant-Guide.md`
- Machine source: [`agent-status.json`](agent-status.json), [`agent-events.jsonl`](agent-events.jsonl), [`agent-knowledge.jsonl`](agent-knowledge.jsonl)
- Runtime source: `Missions/[55-2hc]warfarev2_073v48co.chernarus`

## Read order (fastest path)

1. [Home](Home) for map and task lanes.
2. [AI-Assistant-Developer-Guide](AI-Assistant-Developer-Guide) for editing rules and safe edit constraints.
3. [Current source status snapshot](Current-Source-Status-Snapshot) for what is truly live.
4. [Networking and public variables](Networking-And-Public-Variables) if your task touches PVF, direct publicVariable, missionNamespace state, or JIP.
5. [Public Variable Channel Index](Public-Variable-Channel-Index) for sender/receiver mapping before proposing any network edit.
6. [Feature status register](Feature-Status-Register) for patch-risk context.
7. [SQF code atlas](SQF-Code-Atlas) if you need compile-owner/entrypoint checks.
8. [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) before reviving old branches, copying unmerged upstream work, or touching supply/JIP/town-AI/marker systems that have repeated historical fixes.

## Verification behavior

Run `powershell -ExecutionPolicy Bypass -File docs\validate-wiki.ps1` after meaningful wiki changes. The old `Tools\ValidateWiki.ps1` path is not present in the current checkout.

## What it depends on

- Current-source truth must be checked before any lane claim is trusted.
- Risk claims in this file route to:
  - [Deep-review findings](Deep-Review-Findings)
  - [Public Variable Channel Index](Public-Variable-Channel-Index)
  - [Feature status register](Feature-Status-Register)
  - [Networking and public variables](Networking-And-Public-Variables)

## Networking edit playbook (new or risky channels)

Use this checklist before adding a new networking channel:

1. **Choose primitive.**
   - Request action: `publicVariableServer`/PVF request command.
   - One-client reply: `publicVariableClient` only.
   - Shared state: `missionNamespace setVariable [name, value, true]`.
2. **List sender and receiver explicitly.**
   - Who sends first? client or server?
   - Who receives first? specific client, same-side clients, or everyone?
3. **Classify JIP behavior.**
   - Event only (no replay), latest-value state, or pull-based request/response.
4. **Decide authority owner.**
   - `Dispatch` is not authority.
   - Handler is the trust boundary. If authority is missing, flag as TODO and cross-link to playbook.
5. **Avoid dead/duplicate paths.**
   - Verify `Init_PublicVariables.sqf` has matching `SRVFNC*`/`CLTFNC*` compile and event-handler registration.
   - Verify client handler compiles are active in init flows.
6. **Document in index first.**
   - Update the command in [Public-Variable-Channel-Index](Public-Variable-Channel-Index) with sender, receiver, payload, authority, and JIP risk.

## Upstream-history guidance

- Treat upstream `master`, merged PRs and concrete commit/file evidence as stronger than branch names.
- Treat closed PRs, reverted commits and old branch families as negative knowledge until current-source testing proves they are safe to revive.
- For supply, attack-wave, town-AI, marker and JIP work, read [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) before proposing code. Those systems have repeated exploit, lifecycle, locality or performance follow-up fixes in Miksuu history.
- If citing an upstream lesson, include a PR number, commit hash, file path or short commit/PR wording, and label the confidence as confirmed, likely or speculative.
- For older upstream history, watch especially for `version.sqf` generation/copy debt, A3 syntax contamination, AntiStack RequestJoin/DB type assumptions, removed task-system code, and LLM/GPT-generated guide or code guesses. The deep-history addendum on [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) records concrete commits for each.
- When reading old branches, classify the branch family before trusting it: `oldMasterBranch` and `RevertedTo2018Version` are archaeology, `A3_*` is concept-only for OA, `Debug`/`Test` branches are probes, and AntiStack branches are generation-specific.
- Do not revive merged PR or branch code just because it merged once. Check later reverts such as HQ repair pricing (`346e3be8`), cheaper nukes (`31d8a06d`), bomb/debug work (`f10d5bd9`, `8d74c332`) and task/guerilla removals before writing implementation guidance.
- For UI, marker, JIP and performance helpers, preserve lifecycle contracts first: `clientInitComplete` placement, side-visible marker APIs, moving-marker position refresh, map-open FPS gating and public-variable payload shape all have old regression history.
- Second-wave PR research found no upstream PR comments/reviews for PR #1-#12; cite PR titles/bodies and later commit afterlife instead of inventing reviewer intent.
- Treat release tooling as a separate risk surface: current packaging is source Chernarus plus generated Vanilla/Takistan unless modded packaging is explicitly re-enabled; LoadoutManager needs `7za`, generated `version.sqf`, sound filename contracts and terrain-specific post-copy checks.
- For economy/ordnance work, branch names are especially dangerous: 75k nukes were live-test data, HQ repair escalation was reverted until server-owned, Mavericks-to-Spikes was not current truth, and bomb limits went through workaround/revert/re-add churn.
- For marker blinking or HC work, prefer current default-off/conservative behavior. Per-player blinking toggles need an event-handler ownership registry; multi-HC changes need typed routing plus server update-back accounting.
- For headless-client changes, read [HC upstream history and lessons](HC-Upstream-History-And-Lessons) before editing. The old branch evidence says to keep HC role names/capabilities explicit, test side-less HC PVF routing, preserve wrong-name/error logging, and verify generated mission slots as well as scripts.

## missionNamespace, player lifecycle, and JIP guidance

- `missionNamespace setVariable [var, value, true]` is for durable replicated state.
- `addPublicVariableEventHandler` only triggers behavior; it does not prove sender authenticity.
- `onPlayerConnected` / `onPlayerDisconnected` are implemented in:
  - `Server/Functions/Server_OnPlayerConnected.sqf`
  - `Server/Functions/Server_OnPlayerDisconnected.sqf`
- Treat connection flow and broadcast state as separate ownership lanes.
- For delayed UI updates, prefer pull models (`REQUEST_*` / `RECEIVED_*`) to avoid replay assumptions.

## What this page does NOT do

- It is not the source of protocol-specific implementation details.
- It does not authorize using Arma 3-only primitives in OA gameplay lanes.
- It does not replace `Deep-Review-Findings` / `Feature-Status-Register`; it is a bootstrap route.

## What it depends on / runs / risks

### Where it lives

- Wiki page: `AI-Assistant-Guide.md`
- Runtime source: `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- Machine records: `agent-status.json`, `agent-events.jsonl`, `agent-knowledge.jsonl`

### How this page runs

- Human/agent bootstrap path.
- Validation path: `powershell -ExecutionPolicy Bypass -File docs\validate-wiki.ps1` after docs changes.
- Runtime scope: networking edits require updating both the channel index and feature status risk pages.

### What is risky

- Starting directly at subsystem pages may skip active connection/state claims.
- Any new direct `publicVariable` channel must be documented with sender, receiver, authority, and JIP handling before merge.

### Where to go next

- [Progress dashboard](Progress-Dashboard) for lane state
- [Feature status register](Feature-Status-Register) for risk ranking
- [Current source status snapshot](Current-Source-Status-Snapshot)

## Continue reading

Previous: [Home](Home) | Next: [AI Assistant Developer Guide](AI-Assistant-Developer-Guide)

Main map: [Home](Home) | Risk triage: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
