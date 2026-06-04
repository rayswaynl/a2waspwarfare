# HC Upstream History And Lessons

This page captures older upstream headless-client history and previous agent notes. It is a narrow appendix for HC work: use it with [AI, headless and performance](AI-Headless-And-Performance) and [HC delegation/failover](Headless-Delegation-And-Failover-Playbook) before changing delegation code.

Research snapshot: 2026-06-04. GitHub issue/PR comment APIs did not return upstream comments matching `HC`, `headless`, `2hc` or delegation. The useful upstream "comments" are commit messages and branch history, especially `Miksuu/a2waspwarfare` branch `HeadlessClientMultithreading`.

## Bottom Line

Older HC work was not "send AI to any headless client". It split HCs by role, added typed registration, promoted wrong HC names to server errors, added RPT logging before multi-HC tests, filtered side-less HC client calls, and still left static-defense update-back/accounting as the weak path.

## Evidence Trail

| Evidence | Affected subsystem | What happened | Why it matters |
| --- | --- | --- | --- |
| [`a241ac75`](https://github.com/Miksuu/a2waspwarfare/commit/a241ac75) | mission slots, HC topology | "Chernarus Map Implementation for 4 headless clients"; `mission.sqm` added multiple `forceHeadlessClient=1` civilian slots with descriptions such as Town AI, AI and Static Defence AI. | Multi-HC design started as named role slots, not an interchangeable HC pool. |
| [`6760f1a3`](https://github.com/Miksuu/a2waspwarfare/commit/6760f1a3) | HC init, delegation routing | "Create SQF scripts for running the Headless Client Delegation for 4 cores (Chernarus)"; one `Init_HC.sqf` became separate AI, PVF, static-defence and town-AI init files. | Routing and compile surface were split by HC role. Preserve explicit capability routing when reviving this work. |
| [`bb01ebfc`](https://github.com/Miksuu/a2waspwarfare/commit/bb01ebfc) | generated/modded missions | "Run the changes to the modmaps (although it's not yet implemented inside to the mission.sqm)". | Map-copy HC state can be partial. Verify both scripts and `mission.sqm` slots per terrain. |
| [`1937ac40`](https://github.com/Miksuu/a2waspwarfare/commit/1937ac40) | server HC registration | "Change to error in serverside when the HC has wrong name"; unknown HC names became `ERROR` logs. | HC slot names are an operational contract, not cosmetic labels. Bad names should fail visibly. |
| [`f95609dd`](https://github.com/Miksuu/a2waspwarfare/commit/f95609dd) | HC diagnostics | "Add proper logging to the headless client functions before testing with multiple clients". | Multi-HC behavior was not trusted without RPT evidence. Keep selected HC, payload and callback logs visible during tests. |
| [`1d79ba2a`](https://github.com/Miksuu/a2waspwarfare/commit/1d79ba2a) | HC registry | "Store headless clients as array"; `connected-hc` changed from `[player]` to `[player, hcType]`; the server stored `[group _hc, _hcType]`. | Typed HC registry was introduced to route work by capability. Do not flatten it without a replacement routing rule. |
| [`6b90c872`](https://github.com/Miksuu/a2waspwarfare/commit/6b90c872) | static-defense routing | "For static defences select the correct headless client"; patch touched `Server_DelegateAITownHeadless.sqf` and selected `"staticDefenceAIdelegation"` for a `delegate-townai` send. | HC routing fixes can look plausible while crossing function/type names. Review path, message and HC type together. |
| [`89aec0a2`](https://github.com/Miksuu/a2waspwarfare/commit/89aec0a2), [`fc805377`](https://github.com/Miksuu/a2waspwarfare/commit/fc805377) | PVF compatibility | Removed then reverted "obsolete" `Common_SendToServer.sqf` used in Vanilla. | HC/PVF changes can break compatibility branches. Do not remove old send paths without Vanilla/OA tests. |
| [`f5e8fa47`](https://github.com/Miksuu/a2waspwarfare/commit/f5e8fa47) | side-targeted client calls | "Possibly fix a bug where the headless client with no side received a client call"; `Client_HandlePVF.sqf` added an HC check before accepting side-addressed PVF calls. | HCs are side-less enough to need explicit exclusion from player-side traffic. Test HC with side-targeted messages. |
| [`ec4086fc`](https://github.com/Miksuu/a2waspwarfare/commit/ec4086fc) | delegation diagnostics | "Place debug lines to the delegation scripts"; added argument/client debug logs in AI/static-defence delegation senders. | Delegation failures were debugged through payload shape and selected clients. Preserve that observability. |

## Previous Agent Notes To Preserve

| Record | Finding | Future use |
| --- | --- | --- |
| `agent-events.jsonl` DR-21 | Earlier "HC disconnect orphans units" wording was corrected: OA migrates HC-local AI to the server on disconnect. The real risk is server load spike plus no mission-level failover/redelegation. | Do not document lost/orphaned units as proven. Document load spike and no rebalance/failover. |
| `agent-events.jsonl` DR-42 | Static-defence HC update-back is commented out in `Client_DelegateAIStaticDefence.sqf`; town-AI reports vehicles back through `Client_DelegateTownAI.sqf`. | Static-defense HC is partial/fire-and-forget unless update-back and server accounting are restored. |
| `agent-events.jsonl` DR-40 | WASP overlay is JIP/HC-clean because live wiring runs per player from `Init_Client`; HCs skip player-local code. | Do not over-apply HC warnings to player-local WASP UI/action code. |

## Practical Lessons

| Lesson | What future developers and LLMs should do | Confidence |
| --- | --- | --- |
| Treat HC identity as a routing protocol. | Decide whether each HC can handle town AI, generic AI, static defence, PVF or all roles. Keep slot names, registration type and delegate message aligned. | confirmed |
| Keep side-less HC behavior explicit. | Include one HC with no normal player side in PVF/client-call smoke tests; verify side-targeted player traffic is ignored by HC. | confirmed |
| Static-defense HC remains the weak path. | Restore or intentionally document the static-defense update-back policy before claiming cleanup/accounting/redelegation correctness. | confirmed |
| HC disconnect is a performance/failover problem, not proven unit loss. | Design failover around future spawns and load spikes; do not use Arma 3 `setGroupOwner`/`groupOwner` as an OA solution. | confirmed |
| Generated mission copies can drift from HC slots. | Check Chernarus source, generated Vanilla/Takistan and modded mission copies for both scripts and `mission.sqm` slot metadata. | confirmed |
| Routing fixes need path-level review. | Review delegate sender file, special-message name, selected HC type, callback/update-back and RPT output together. | confirmed |

## LLM Review Checklist

- Does the patch change HC boot, registration, delegation senders, HC receivers or side-targeted PVF routing?
- Does each HC register a type/capability, or is the patch intentionally using a flat all-purpose HC pool?
- Does every delegated work type have a server update-back path or an explicit fire-and-forget policy?
- What happens if an HC connects late, has the wrong slot/name, disconnects during active work or reconnects?
- Were town AI and static-defense AI tested separately?
- Does a side-targeted client message get ignored by HC?
- Were generated mission copies checked for both scripts and `mission.sqm` HC slots?
- Do RPT/debug lines identify selected HC, payload type, town/defence/team and callback/update-back?

## Follow-Up Investigation

- Reproduce `f5e8fa47` in an OA HC session if future PVF work changes side routing.
- Decide whether branch-only `HeadlessClientMultithreading` role split should remain historical guidance or become a current implementation plan.
- If static-defense update-back is restored, define cleanup ownership, disconnect behavior and generated-mission propagation in the patch PR.

## Continue Reading

Runtime source router: [AI, headless and performance](AI-Headless-And-Performance) | Patch policy: [HC delegation/failover](Headless-Delegation-And-Failover-Playbook) | Wider history: [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) | Evidence index: [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel)
