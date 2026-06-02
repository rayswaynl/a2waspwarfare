# Instructions for Codex

> Claude-owned handoff (2026-06-02). A single, current, prioritized action queue for the wiki-quality + audit work that falls in **Codex's lane** (atlas/nav/structure/status pages). Detail and evidence for each item live in [Wiki quality audit](Wiki-Quality-Audit) (sections A/B/C + Round 2). Claude-lane items are already done. Work top-to-bottom; check items off in place. Acceptance = the stated condition is true and the page still passes the link gate.

## Already done (no action)
- ✅ Nav: all 5 new Claude pages are wired into `_Sidebar.md` (`Wiki-Quality-Audit`, `Variable-And-Naming-Conventions`, `Public-Variable-Channel-Index`, `Modules-Atlas`, `Pending-Owner-Decisions`).
- ✅ Dedup routing (audit section A): construction / supply-cooldown / generated-mission / lifecycle / victory / BattlEye duplications resolved.
- ✅ Accuracy C1: Networking MASH row now cites DR-34 (was the stale "server relay live"/DR-3).

## P0 — Accuracy (a reader is currently being misinformed)
1. **Fix the UI-atlas finding mislabels** ([Client UI systems atlas](Client-UI-Systems-Atlas) line ~254 "Buy-gear authority" row, and the same in [Client UI HUD and menus](Client-UI-HUD-And-Menus)). The row lists "DR-16, DR-17, DR-24" under *gear/template* — but **DR-16 = structure-sale client-authority** (not gear), DR-17 = duplicate IDD 23000, DR-24 = dead `RscMenu_Upgrade`. And **DR-25a = duplicate title IDD 10200**, **DR-25b = malformed `soundPush[]`** (not "EASA/service authority" — that's **DR-28**). *Acceptance:* each DR is described as its actual finding; the gear/EASA authority risk links DR-28.
2. **De-hedge the MASH status in** [SQF atlas](SQF-Code-Atlas) — replace "MASH marker status requires careful source verification" with a definitive **DR-34** cite (dead both ends). *Acceptance:* no "requires verification" hedge for MASH.
3. **Mark the compile counts point-in-time in** [SQF atlas](SQF-Code-Atlas) — the "659/452/207" numbers need a timestamp + regeneration command + **DR-5** cite (DR-5 warned they go stale). *Acceptance:* counts labelled point-in-time with how to regenerate.

## P1 — Surface findings where developers actually look (orphaned cross-links)
4. **DR-44** (`wfbe_supply_temp_<side>` forgery) → add to [Economy](Economy-Towns-And-Supply) synthesis table, [Networking](Networking-And-Public-Variables) direct-channel section, [Server runtime atlas](Server-Gameplay-Runtime-Atlas).
5. **DR-20** (HQ-killed N-fold score exploit) → add to [Construction atlas](Construction-And-CoIn-Systems-Atlas), [Gameplay atlas](Gameplay-Systems-Atlas), [Server runtime atlas](Server-Gameplay-Runtime-Atlas).
6. **DR-45** (town-AI deletes player-occupied vehicles) → cross-link from `Town-AI-Vehicle-Despawn-Safety` and [AI/headless](AI-Headless-And-Performance).
7. Cite **DR-40** by number in [WASP overlay](WASP-Overlay) and **DR-19** in [Server runtime atlas](Server-Gameplay-Runtime-Atlas).
8. Add the missing DR cross-links called out in audit section C2 ([Gameplay atlas](Gameplay-Systems-Atlas): DR-6/14/11/22/23/15; UI atlases: DR-16/17/24/25; [AI/headless](AI-Headless-And-Performance): DR-21/42; [Construction atlas](Construction-And-CoIn-Systems-Atlas): DR-6; [Mission entrypoints](Mission-Entrypoints-And-Lifecycle): DR-37/43a).

## P1 — Reconcile "current work" status pages (they're stale)
9. **[Coordination board](Coordination-Board):** the "Active Lanes" + "Roles" tables are stale — sub-agent lanes (Faraday/Mencius/Hilbert/Cicero/Curie/Meitner) shown "Active" were harvested/closed in Wave F; `victory-endgame-runtime-atlas` shown "Active" is integrated; the Roles line says "Claude's latest reviews are DR-11..DR-15" but Claude is at **DR-45** and in collaboration-follow mode. *Acceptance:* tables reflect current state (closed lanes marked closed; Claude at DR-45).
10. **[Progress dashboard](Progress-Dashboard):** the "At A Glance" Claude row predates Phase-1 completion + the collaboration-follow operating mode; update to reflect that the coverage ledger's Map/Perf/JIP-HC columns are complete and only Auth/PV owner-decisions remain.
11. **`_Sidebar.md`:** `Headless-Delegation-And-Failover-Playbook` is listed twice (Gameplay + Ops) — de-duplicate.

## P2 — Structure (page merges, audit section B)
12. Merge [Hardening roadmap](Hardening-Implementation-Roadmap) + [Server authority map](Server-Authority-Migration-Map) (~70% overlap) — Migration-Map's *Authority Principles* + *Handler Validation Checklist* as preamble, Roadmap's *work packages* as body.
13. Reduce [Client UI HUD and menus](Client-UI-HUD-And-Menus) to a quick-ref/redirect into [Client UI systems atlas](Client-UI-Systems-Atlas) (it is a strict subset).
14. Trim [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) ↔ [Lifecycle wait-chain](Lifecycle-Wait-Chain) overlap (~50%): keep the `description.ext` include graph + mission-object init layer on entrypoints, the boot-timeline/flag-dependency graph on wait-chain, cross-link.

## P3 — Thin citations (lower priority)
15. Add representative `path:line` anchors to [Core systems index](Core-Systems-Index), [Architecture overview](Architecture-Overview), [Content structure and maps](Content-Structure-And-Maps).

## Do NOT change (audit false positives — verified at source)
- [Public variable channel index](Public-Variable-Channel-Index) PVF list ranges `:8-20` (server) / `:23-37` (client) are **correct**.
- DR-15's `_side = _this` at `Server_AssignNewCommander.sqf:3` is **correct**.
(An audit pass miscounted blank lines; leave both as-is.)

## Not Codex's lane — informational
- The economy/forgery owner decision (server-authority vs BattlEye, two surfaces) and the coverage-gap next-review queue (Server/AI respawn+orders, cleaners Perf, config data model, PR#1 delta) are in [Pending owner decisions](Pending-Owner-Decisions) and [Deep-review findings](Deep-Review-Findings) Round 36 — for the owner / the next review phase, not a Codex doc task.

## Continue Reading

Detail: [Wiki quality audit](Wiki-Quality-Audit) | Findings: [Deep-review findings](Deep-Review-Findings) | Decisions: [Pending owner decisions](Pending-Owner-Decisions)
