# JIP Wait Chain Timeout Status - 2026-07-03

Docs-only status note for the current `claude/build84-cmdcon36` target. This
does not change `Init_Client.sqf`; the join/enrollment path is high-risk and
needs a dedicated source owner before any fail-soft behavior is changed.

## Current Target

`Client/Init/Init_Client.sqf` is byte-identical across the maintained roots:

| Root | SHA-256 |
| --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus` | `28EFC31FED3E0BE51709CDF91A9AD47369C0931003EFD0598F08C670A2C09315` |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` | `28EFC31FED3E0BE51709CDF91A9AD47369C0931003EFD0598F08C670A2C09315` |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad` | `28EFC31FED3E0BE51709CDF91A9AD47369C0931003EFD0598F08C670A2C09315` |

## What Is Already Bounded

The two explicit join ACK loops are no longer unbounded:

| Wait | Current evidence | Status |
| --- | --- | --- |
| `WFBE_P_CANJOIN` after `RequestJoin` | `Init_Client.sqf:927-949` keeps `_totalWait` and logs/proceeds after 120 seconds. | Bounded failover. |
| `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK` | `Init_Client.sqf:966-981` uses the same 120-second failover. | Bounded failover. |

This supersedes older notes that described those two handshake loops as only
30-second retry loops with no terminal timeout.

## Remaining Deadline-Free Waits

The later post-join replicated-state waits still have no deadline on the side
paths where they run. Several have civilian bailouts to avoid `objNull` logic
spins, and several are WEST/EAST-only because resistance has a separate branch,
but those guards are not a timeout/log policy for a playable side whose synced
state never arrives.

| Wait family | Current evidence | Risk if producer state never arrives |
| --- | --- | --- |
| `townInit` before town marker/capture FSMs | `Init_Client.sqf:866` and `:1160`. | Client-side town UI/FSM setup can stall silently. |
| Side structures and side supply | `Init_Client.sqf:874` and `:876` on the non-resistance path. | Available actions/resources startup can stall or miss diagnostics. |
| Commander state | `Init_Client.sqf:892`. | Commander update FSM never starts. |
| HQ radio object and topic id | `Init_Client.sqf:909` and `:912`. | Radio identity/topic setup can block client init progress. |
| Spawn/HQ state | `Init_Client.sqf:1010`, `:1013`, `:1014` on the WEST/EAST path. | Spawn resolution can stall after the join gate. |
| HQ deployed state and nested HQ killed-EH setup | `Init_Client.sqf:1042` and `:1055` on the WEST/EAST path. | CoIn/HQ setup or JIP HQ killed-handler setup can block. |
| Vote timer | `Init_Client.sqf:1355`. | Vote dialog initialization can block. |

## Recommendation

Do not patch this opportunistically in a mixed gameplay PR. A source owner
should decide the fail-soft behavior per wait family:

- which waits can safely log and continue with defaults;
- which waits should retry a targeted resend first;
- which dependent setup can be skipped and retried later;
- which warnings belong in client RPT versus player-visible UI.

The safest next implementation shape is a small helper or repeated idiom that
adds a deadline plus diagnostic log while preserving the existing happy path.
Run dedicated/JIP smoke after any source change, including a forced missing
producer-state test if practical.
