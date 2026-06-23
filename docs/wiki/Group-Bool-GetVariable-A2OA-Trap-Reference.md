# Group Bool getVariable — A2-OA Engine Trap Reference (WFBE_CO_FNC_GroupGetBool)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`WFBE_CO_FNC_GroupGetBool` is the platform-layer safe accessor for reading a boolean (or any defaulted) variable off a **group** receiver. It exists to work around a specific Arma 2 OA 1.64 engine quirk where the convenient 2-arg `getVariable [name, default]` form does not behave as documented on groups. This page documents the trap, the fix, where it is registered, and every call site that depends on it.

---

## 1. The engine trap (what breaks, why groups specifically)

The function header states the quirk and its class label ("G1") directly. Header comment `Common/Functions/Common_GroupGetBool.sqf:1-9` (the block's Params/Returns lines `:11-12` are shown separately in §2; the comment closes at `:13`):

```sqf
/*
	WFBE_CO_FNC_GroupGetBool — safe boolean getVariable for GROUP receivers.

	A2 OA 1.64 trap (the "G1" class): the 2-arg `group getVariable [name, default]`
	form returns nil (NOT the default) when the var is UNSET on a GROUP. Reading a
	bool that way and using it (`nil || {..}`, `if (nil)`, `nil != x`, ...) throws
	"Type Nothing". Side logics / objects / namespaces do NOT have this quirk — only
	groups — so route GROUP bool reads through this helper. It restores the intended
	default-on-missing semantics using the safe 1-arg form + isNil.
*/
```

The failure mode: code reads a flag that has never been `setVariable`'d on a particular group (the common case — most groups are never marked HC, founded, persistent, etc.), expects the supplied `default`, but instead gets `nil`. The moment that `nil` is consumed by a boolean operator (`!x`, `x || {..}`, `if (x)`), the engine throws `Type Nothing` and the surrounding script aborts. Because the heaviest readers are the per-frame AI Commander loop and the base-GC FSM, an unguarded read here would intermittently break commander tasking and group garbage collection — exactly the symptom the "B66" fix annotations across the call sites refer to.

The quirk is **receiver-specific**: objects, side logics, and namespaces all honour the 2-arg default form, so only group reads must be routed through this helper (`Common/Functions/Common_GroupGetBool.sqf:7-8`).

---

## 2. The safe implementation

The body takes a 3-element array, reads via the safe **1-arg** form, and substitutes the default itself when the result is nil. Full body `Common/Functions/Common_GroupGetBool.sqf:14-19`:

```sqf
private ["_grp","_name","_default","_v"];
_grp     = _this select 0;
_name    = _this select 1;
_default = _this select 2;
_v = _grp getVariable _name;
if (isNil "_v") then {_default} else {_v}
```

Contract (`Common/Functions/Common_GroupGetBool.sqf:11-12`):

- **Params:** `[ group, varName (string), default ]`
- **Returns:** the stored value, or `default` when the var is unset/nil.

Key detail: the read uses the 1-arg `_grp getVariable _name` (`Common/Functions/Common_GroupGetBool.sqf:18`), which is the form the engine does NOT corrupt; the `isNil "_v"` guard (`:19`) then performs the default substitution in script rather than trusting the engine. The default need not be a boolean — element 0 of an array default works the same way (see the `wfbe_aicom_order` reader in §4).

---

## 3. Registration

Compiled into `missionNamespace` during common init alongside the other `WFBE_CO_FNC_*` helpers. `Common/Init/Init_Common.sqf:114`:

```sqf
WFBE_CO_FNC_GroupGetBool = Compile preprocessFileLineNumbers "Common\Functions\Common_GroupGetBool.sqf"; //--- G1: safe bool getVariable for GROUP receivers (A2 OA unset->nil trap)
```

It is registered just after `WFBE_CO_FNC_CreateGroup` (`Common/Init/Init_Common.sqf:113`) and before the unit/vehicle factory helpers (`Common/Init/Init_Common.sqf:115-118`), so it is available to every server-side AI and FSM consumer.

---

## 4. Call-site taxonomy

Grepping the whole worktree, `Call WFBE_CO_FNC_GroupGetBool` resolves to **21 call occurrences on 15 lines** across **4 files** — several lines invoke it 2–3× inside one `||` chain (e.g. `server_groupsGC.sqf:209` ORs three flag reads, and `AI_Commander.sqf:305`/`:354` each OR two):

| File | Calls | On lines |
|------|------:|----------|
| `Server/FSM/server_groupsGC.sqf` | 10 | `:75`(×2), `:117`, `:118`(×2), `:122`, `:154`, `:209`(×3) |
| `Server/AI/Commander/AI_Commander.sqf` | 6 | `:305`(×2), `:354`(×2), `:446`, `:447` |
| `Server/AI/Commander/AI_Commander_Produce.sqf` | 4 | `:69`, `:138`, `:196`, `:331` |
| `Server/AI/Commander/AI_Commander_Execute.sqf` | 1 | `:55` |

(`AI_Commander_Produce.sqf:66` and `AI_Commander_MHQReloc.sqf:191` only mention the helper in comments and are not calls.) The call sites carry `//--- B66` / `//--- G1` annotations marking them as the A2-OA-safe group-bool conversion (e.g. `AI_Commander_Produce.sqf:196`, `:331`).

The group-state flags read through it:

| Flag | Default | Meaning | Representative read | Setter |
|------|---------|---------|---------------------|--------|
| `wfbe_aicom_hc` | `false` | Group is an HC (headless-client) commanded team; brain must not Produce/waypoint it directly. | `Server/AI/Commander/AI_Commander_Produce.sqf:69` | `Common/Functions/Common_RunCommanderTeam.sqf:66` (broadcast) |
| `wfbe_aicom_founded` | `false` | Server-local team re-adopted/founded by the base-GC; eligible for refill at a factory. | `Server/AI/Commander/AI_Commander.sqf:447` | `Server/AI/Commander/AI_Commander_Teams.sqf:602`; `Server/FSM/server_groupsGC.sqf:158` |
| `wfbe_aicom_refit` | `false` | Team is marked to top-up at base once home (B61). | `Server/AI/Commander/AI_Commander_Produce.sqf:196` | `Server/AI/Commander/AI_Commander_Produce.sqf:176` (set true), `:332` (clear) |
| `wfbe_aicom_order` | `[-1]` | Current order tuple `[seq, mode, pos, ...]`; read defaulted then `select 0` for the sequence number. | `Server/FSM/server_groupsGC.sqf:154` | `Server/AI/Commander/AI_Commander_Execute.sqf:61`; `Server/AI/Commander/AI_Commander_AssignTowns.sqf:151`; `Server/AI/Commander/AI_Commander_Strategy.sqf:397` |
| `wfbe_persistent` | `false` | Group is a persistent garrison/defense team; base-GC must not reap it. | `Server/FSM/server_groupsGC.sqf:117` | `Server/AI/Commander/AI_Commander_Teams.sqf:605`; `Server/Init/Init_Server.sqf:717`; many others |
| `WFBE_SidePatrol` | `false` | Group is a side-patrol; must not be re-adopted/re-tasked by the base-GC. | `Server/FSM/server_groupsGC.sqf:122` | `Common/Functions/Common_RunSidePatrol.sqf:63` (broadcast) |

Notes:

- The `wfbe_aicom_order` case proves the helper is not boolean-only: it is read with a non-bool default `[-1]` and immediately `select 0`'d for the sequence (`Server/FSM/server_groupsGC.sqf:154`). Without the helper, an unset order on a group would return `nil`, and `(nil) select 0` would throw.
- `wfbe_aicom_hc` and `WFBE_SidePatrol` setters broadcast (`setVariable [..., true]`) so the server can read them on groups it does not own — `Common/Functions/Common_RunCommanderTeam.sqf:66` and `Common/Functions/Common_RunSidePatrol.sqf:63`. The server-side comment at `Server/FSM/server_groupsGC.sqf:119-121` documents this dependency.
- Every flag above has at least one setter; no read-without-setter (dead flag) was found among the call args.

---

## 5. When to use / guidance

- **Reading a boolean (or defaulted) variable off a GROUP → always route through `WFBE_CO_FNC_GroupGetBool`.** The 2-arg `group getVariable [name, default]` form is unreliable for unset vars on a group in A2 OA 1.64 (`Common/Functions/Common_GroupGetBool.sqf:4-9`).
- **Reading off an OBJECT, SIDE LOGIC, or NAMESPACE → the plain 2-arg `obj getVariable [name, default]` is fine** — those receivers honour the default and do not exhibit the trap (`Common/Functions/Common_GroupGetBool.sqf:7-8`). Do not wrap object reads in this helper; it would just add overhead.
- If you must read a group var inline without the helper, use the safe **1-arg** form plus an `isNil` guard — i.e. exactly what the helper does (`Common/Functions/Common_GroupGetBool.sqf:18-19`) — never the 2-arg default form on a group.
- When adding a new group-state flag, broadcast the setter (`setVariable [name, value, true]`) if the server reads it on groups owned by an HC, matching the `wfbe_aicom_hc` / `WFBE_SidePatrol` pattern.

---

## See also

- [Namespace Profile And Diagnostic Utility Reference](Namespace-Profile-And-Diagnostic-Utility-Reference) — sibling platform-layer accessor/diagnostic utility.
- [AI Commander Execution Loop Reference](AI-Commander-Execution-Loop-Reference) — the heaviest consumer cluster; `wfbe_aicom_hc`, `wfbe_aicom_founded`, `wfbe_aicom_refit` and the `wfbe_aicom_order` tuple are all routed through the helper across its produce/tasking files (e.g. `AI_Commander_Execute.sqf:55` reads `wfbe_aicom_hc`).
- [Networking And Public Variables](Networking-And-Public-Variables) — the broadcast (`setVariable [..., true]`) semantics that let the server read HC-owned group flags.
