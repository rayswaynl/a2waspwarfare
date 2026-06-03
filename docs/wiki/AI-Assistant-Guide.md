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

## Verification behavior

Run `Tools/ValidateWiki.ps1` after meaningful wiki changes.

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
- Validation path: `Tools/ValidateWiki.ps1` after docs changes.
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

Main map: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
