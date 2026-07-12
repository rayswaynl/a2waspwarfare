# Boundary: `setGroupOwner` / `groupOwner` / `joinGroup` are banned (Arma-3-only)

**Status:** Enforced. Formalizes owner ruling d020 (2026-07-12). Applies to all SQF in this repository.

## The rule

Do not use `setGroupOwner`, `groupOwner`, or `joinGroup` anywhere in this codebase's mission SQF.

## Why — engine incompatibility (not an HC-policy choice)

WASP Warfare targets the **Arma 2: Operation Arrowhead 1.64** engine. `setGroupOwner`, `groupOwner`, and `joinGroup` are **Arma-3-only commands** — they do not exist in the A2 OA 1.64 SQF engine. On A2 OA the parser/runtime hits an unknown command and **silently corrupts or errors the script** (the same failure class as `params`, `pushBack`, `findIf`, `remoteExec`, `distance2D`). They sit with the other A3-only "hard-stop traps," not with legitimate A2 commands.

> **Correction to the d020 premise.** The ruling described this as an "HC ownership model / side-resolution hazard." That is not the operative reason. On A2 OA there is **no player- or script-facing group-ownership-transfer API at all**, so there is nothing to transfer and no runtime hazard to guard against — the commands are simply absent from the engine. Headless-client group locality on A2 OA is set implicitly at group creation (by *where* `createGroup`/the spawn executes) and is managed by the engine; it is not reassigned by a `setGroupOwner`-style call. The ban is therefore an **engine-compatibility boundary**, engine-scoped to A2 OA 1.64.

## Where enforcement lives (current master `1270b0a0e`)

- **Automated gate — SQF linter:** [`Tools/Lint/check_sqf.py:39`](../../Tools/Lint/check_sqf.py) lists `setGroupOwner`, `groupOwner`, and `joinGroup` in the `A3_TRAPS` tuple; the linter flags any occurrence in `.sqf` / `.fsm` / `.hpp` / `.ext` / `.sqm`.
- **Contributor & agent instructions:** `AGENTS.md:61` and `CLAUDE.md:61`, under **"## A2 OA hard-stop traps"** ("A3-only … will silently corrupt or crash on A2 OA 1.64").
- **Edit-guard skill:** `.claude/skills/sqf-edit-guard/SKILL.md:17`.
- **Bug-hunt harness:** `Tools/PrTestHarness/BugHunt/Find-WaspBugHunt.ps1:107`.
- **Program instructions:** `docs/project-management/FABLE_ULTRACODE_MASTER_INSTRUCTIONS_V2_2026-07-05.md:659` (listed among "Arma 3-only helpers").

Verification: the MEGACHOP batch-3 dormant-review (2026-07-12, verified + adversarially checked) confirmed the source enforces the ban and that no live `setGroupOwner` call exists in mission SQF.

## What to do instead

- **Add a unit to a group** (the usual reason to reach for `joinGroup`): use the A2-valid `join` / `joinSilent` — e.g. `[_unit] joinSilent _group;`. `joinGroup` is only the A3 spelling of the same operation.
- **Choose which HC/host owns a group:** do not try to reassign ownership after the fact. On A2 OA, group locality follows the machine that **creates** the group — create the group on the intended owner (or via the mission's existing HC group-assignment path) rather than transferring it afterward.
- **Read which machine owns a group** (the reason to reach for `groupOwner`): there is no A2 OA equivalent — design so locality is known by construction rather than queried at runtime.

## Scope

Docs-only formalization of an already-enforced rule; it changes no code and no runtime behavior. The boundary is engine-scoped to A2 OA 1.64 — if a different engine target (e.g. an Arma 3 port) is ever adopted, this doc must be revisited.
