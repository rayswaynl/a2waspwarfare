# Construction And CoIn Systems Atlas

This route is kept for older links. Current construction orientation lives in [Gameplay systems atlas](Gameplay-Systems-Atlas), with authority proof in [Deep-review findings](Deep-Review-Findings) DR-6.

For implementation order, use [Economy authority first cut](Economy-Authority-First-Cut) and [Documentation implementation plan](Documentation-Implementation-Plan).
HQ death is part of the construction/base lifecycle too: deployed HQs get a server-side killed EH at `Server/Construction/Construction_HQSite.sqf:36`, mobile HQs are re-created and broadcast to clients at `:72-91`, and JIP clients add their own owner-local killed EH from `Client/Init/Init_Client.sqf:500-503`. The server action in `Server/Functions/Server_OnHQKilled.sqf:46-81` currently has no processed-once guard before the duplicate score awards, so use [Deep-review findings](Deep-Review-Findings) DR-20 before touching HQ killed handling.

