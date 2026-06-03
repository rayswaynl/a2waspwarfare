# Current Source Status Snapshot

This page is the fast guardrail for stale "patched", "propagated" and "release-ready" wording.

The original snapshot was created on 2026-06-02 after several false source-patched pulses. Since then, multiple branches and wiki batches have moved. Treat this page as a **branch-aware routing page**, not as proof that a gameplay fix is currently shipped.

## Rule For Agents

Before saying a fix is live, prove all of these:

1. Name the branch or commit checked.
2. Check source Chernarus under `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.
3. Check maintained Vanilla Takistan under `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/` when propagation matters.
4. Separate `origin/master`, docs/source branches, release branches and PR branches.
5. Keep Arma 2 OA runtime smoke separate from static source evidence.

If any item is missing, use `patch-ready`, `branch-local`, `propagated-smoke-pending` or `source-unverified`, not `shipped`.

## High-Risk Status Checks

| Lane | What to verify before changing wording | Owning page |
| --- | --- | --- |
| Commander reassignment DR-15 | `RequestNewCommander.sqf` payload shape versus `Server_AssignNewCommander.sqf` unpacking, plus duplicate notification behavior. | [Commander reassignment call shape](Commander-Reassignment-Call-Shape) |
| Factory queue cleanup DR-33 | `Client_BuildUnit.sqf` queue token identity, empty-vehicle early exit and local queue decrement. | [Factory queue counter token cleanup](Factory-Queue-Counter-Token-Cleanup) |
| Paratrooper marker revival | Sender, handler file and `HandleParatrooperMarkerCreation` client PVF registration in each maintained mission. | [Paratrooper marker revival](Paratrooper-Marker-Revival) |
| Duplicate client `Skill_Init` | Number and order of `Skill_Init.sqf` calls before `WFBE_SK_FNC_Apply`. | [Client skill init idempotency](Client-Skill-Init-Idempotency) |
| Hosted server FPS loop | Dedicated/non-dedicated guard shape in both server FPS publisher scripts. | [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) |
| Supply mission command-center scan | Whether the 80-meter command-center scan is class-filtered to `Base_WarfareBUAVterminal`; keep the nearby-player/object scan separate. | [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) |
| WASP marker wait cleanup | Whether the display-54 wait is throttled like the display-12 sibling. | [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) |
| Source/Vanilla propagation | Whether Chernarus, maintained Vanilla and skipped/generated files all carry the same intended behavior. | [Source fix propagation queue](Source-Fix-Propagation-Queue) |

## Current Interpretation

- `origin/master` is the stable baseline unless a page explicitly names another branch.
- Branch-local or release-branch code changes are not shipped on `origin/master` until source evidence proves that branch was merged.
- "Propagated" means source Chernarus and maintained Vanilla Takistan both carry the change; it does not mean Arma 2 OA runtime smoke passed.
- Old worklog/event/knowledge lines are append-only history. Newer source-checked pages and explicit supersession records beat old timestamps.

## Continue Reading

Previous: [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) | Next: [Feature status register](Feature-Status-Register)

Main map: [Home](Home) | Fast path: [LLM agent entry pack](LLM-Agent-Entry-Pack) | Agent file: [`agent-context.json`](agent-context.json)
