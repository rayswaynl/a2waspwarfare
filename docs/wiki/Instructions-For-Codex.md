# Instructions for Codex

> Claude-owned handoff (2026-06-02). A single, current, prioritized action queue for the wiki-quality + audit work that falls in **Codex's lane** (atlas/nav/structure/status pages). Detail and evidence for each item live in [Wiki quality audit](Wiki-Quality-Audit) (sections A/B/C + Round 2). Claude-lane items are already done. Work top-to-bottom; check items off in place. Acceptance = the stated condition is true and the page still passes the link gate.

Current coordination lane: `bottleneck-reducer-progress-accelerator`. Use [Bottleneck removal queue](Bottleneck-Removal-Queue) for the ranked P0/P1/P2 bottlenecks, next five actions and returned-report harvest queue before opening a new broad documentation pass.

## Already done (no action)
- ✅ Nav: all 5 new Claude pages are wired into `_Sidebar.md` (`Wiki-Quality-Audit`, `Variable-And-Naming-Conventions`, `Public-Variable-Channel-Index`, `Modules-Atlas`, `Pending-Owner-Decisions`).
- ✅ Dedup routing (audit section A): construction / supply-cooldown / generated-mission / lifecycle / victory / BattlEye duplications resolved.
- ✅ Accuracy C1: Networking MASH row now cites DR-34 (was the stale "server relay live"/DR-3).
- ✅ Accuracy P0 item 3: [SQF atlas](SQF-Code-Atlas) compile counts are marked point-in-time with a regeneration command and DR-5 caveat.

## P0 — Accuracy (a reader is currently being misinformed)
1. ✅ **Done — UI-atlas finding mislabels resolved.** [Client UI systems atlas](Client-UI-Systems-Atlas) is now only a redirect route, and [Client UI HUD and menus](Client-UI-HUD-And-Menus) describes DR-16 as structure-sale client authority, DR-17 as duplicate dialog IDD 23000, DR-24 as dead `RscMenu_Upgrade`, DR-25a/b as duplicate title IDD 10200 plus malformed `soundPush[]`, and gear/EASA/service authority as DR-28.
2. ✅ **Done — De-hedged the MASH status in** [SQF atlas](SQF-Code-Atlas). The atlas now cites DR-34 definitively: MASH map markers are dead/abandoned because the client receiver compile is commented, the trigger PV has no emitter, and the live server PVEH is orphaned; MASH tents remain a separate deployable officer feature.
3. ✅ **Done — compile counts point-in-time in** [SQF atlas](SQF-Code-Atlas). Counts are timestamped with a regeneration command and **DR-5** caveat.

## P1 — Surface findings where developers actually look (orphaned cross-links)
4. ✅ **Done — DR-44 side-supply direct-channel routing surfaced.** [Economy](Economy-Towns-And-Supply), [Networking](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Server runtime atlas](Server-Gameplay-Runtime-Atlas) and [Feature status](Feature-Status-Register) now point readers to the `wfbe_supply_temp_<side>` authority gap without duplicating the full Deep Review proof.
5. ✅ **Done — DR-20 HQ-killed duplicate processing surfaced.** [Construction atlas](Construction-And-CoIn-Systems-Atlas), [Gameplay atlas](Gameplay-Systems-Atlas) and [Server runtime atlas](Server-Gameplay-Runtime-Atlas) now route HQ killed/idempotency work to [Deep-review findings](Deep-Review-Findings) DR-20 with source anchors.
6. ✅ **Done — DR-45 town-AI vehicle despawn surfaced.** [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) now names DR-45 and [AI/headless](AI-Headless-And-Performance) routes the gotcha to the playbook plus [Deep-review findings](Deep-Review-Findings) DR-45.
7. ✅ **Done — DR-40 / DR-19 cross-links surfaced.** [WASP overlay](WASP-Overlay) already cites DR-40 by number; [Server runtime atlas](Server-Gameplay-Runtime-Atlas) now marks the hosted/listen FPS busy loop as DR-19.
8. ✅ **Done — audit C2 DR cross-links reconciled.** [Wiki quality audit](Wiki-Quality-Audit) C2 is resolved; Gameplay, UI, AI/headless, Construction and Mission entrypoint atlas pages carry concise DR links to [Deep-review findings](Deep-Review-Findings).

## P1 — Reconcile "current work" status pages (they're stale)
9. ✅ **Done — [Coordination board](Coordination-Board) current-work reconcile.** The board now separates current roles/snapshot from the append-only historical lane ledger, names Claude as collaboration-follow with latest DR-45, and explicitly marks old Faraday/Mencius/Hilbert/Cicero/Curie/Meitner plus `victory-endgame-runtime-atlas` lanes as harvested history rather than active claims.
10. ✅ **Done — [Progress dashboard](Progress-Dashboard) current-state refresh.** The dashboard is now current-source focused, routes through [Current source status snapshot](Current-Source-Status-Snapshot), and no longer carries the stale "At A Glance" Claude row.
11. ✅ **Done — `_Sidebar.md` headless failover route de-duplicated.** Current sidebar search shows no duplicate `Headless-Delegation-And-Failover-Playbook` entry.

## P2 — Structure (page merges, audit section B)
12. ✅ **Done — authority/hardening overlap resolved.** Legacy [Hardening roadmap](Hardening-Implementation-Roadmap) and [Server authority map](Server-Authority-Migration-Map) now route to [Documentation implementation plan](Documentation-Implementation-Plan) plus focused authority playbooks.
13. ✅ **Done — UI overlap resolved.** [Client UI systems atlas](Client-UI-Systems-Atlas) is now the legacy route, and [Client UI HUD and menus](Client-UI-HUD-And-Menus) owns the active UI/HUD/menu map.
14. ✅ **Done — entrypoints/wait-chain overlap resolved.** [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) owns include/init orientation, while [Lifecycle wait-chain](Lifecycle-Wait-Chain) owns boot order, flags, timelines and JIP hazards.

## P3 — Thin citations (lower priority)
15. ✅ **Done — thin citations raised.** [Core systems index](Core-Systems-Index), [Architecture overview](Architecture-Overview) and [Content structure and maps](Content-Structure-And-Maps) now have representative `path:line` source-anchor tables.

## Do NOT change (audit false positives — verified at source)
- [Public variable channel index](Public-Variable-Channel-Index) PVF list ranges `:8-20` (server) / `:23-37` (client) are **correct**.
- DR-15's `_side = _this` at `Server_AssignNewCommander.sqf:3` is **not correct** in current source when the caller passes `[_side, _assigned_commander]`; earlier false-positive wording is superseded by the 2026-06-02T14:35 source re-check.
(An earlier audit pass miscounted blank lines for the PVF list only.)

## Not Codex's lane — informational
- The economy/forgery owner decision (server-authority vs BattlEye, two surfaces) and the coverage-gap next-review queue (Server/AI respawn+orders, cleaners Perf, config data model, PR#1 delta) are in [Pending owner decisions](Pending-Owner-Decisions) and [Deep-review findings](Deep-Review-Findings) Round 36 — for the owner / the next review phase, not a Codex doc task.

## Continue Reading

Detail: [Wiki quality audit](Wiki-Quality-Audit) | Findings: [Deep-review findings](Deep-Review-Findings) | Decisions: [Pending owner decisions](Pending-Owner-Decisions)