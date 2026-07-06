---
name: a2oa-verify-command
description: Load whenever you are not CERTAIN a scripting command or language semantic exists and behaves as expected on Arma 2 OA 1.64 — verification ladder from wiki reference to offline engine probe.
---
<!-- source: Agent-Guide GUIDE-REV GR-2026-07-06a -->

# a2oa-verify-command

The engine is A2 OA 1.64 (EOL). Most online SQF documentation is Arma 3 and WILL lie to
you. Verify before writing; never "it's probably fine".

## Verification ladder (stop at the first rung that settles it)

1. **Repo wiki first**:
   [Arma-2-OA-Command-Version-Reference](https://github.com/rayswaynl/a2waspwarfare/wiki/Arma-2-OA-Command-Version-Reference)
   — previously engine-verified commands and semantics live here. Trust it.
2. **BI wiki, OA category ONLY**: the command page must list an introduction version
   ≤ Arma 2 OA 1.64 and appear under
   https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands.
   An A3-era "since Arma 3 X.XX" note = banned. Ignore all Arma 3 pages.
3. **In-source precedent is a LEAD, not proof.** An "A2-safe" comment or existing usage
   in the tree does not verify anything — `getPosVisual` shipped behind exactly such a
   comment and was A3-only. Rung 1 or 2 (or 4) must still confirm.
4. **Disputed SEMANTICS get an offline engine probe.** Existence is rung 2; behavior
   (return values, scope rules, nil handling, type coercion) is only settled by running
   it on an offline OA 1.64 rig: a minimal test mission whose `init.sqf` exercises the
   disputed construct and writes a tagged verdict line to the RPT via `diag_log`, then
   read the RPT. Probe pattern: one construct per probe, log
   `"XWT|<probe-id>|<expression>|" + str(<result>)` so results grep cleanly. Do not
   hardcode machine-specific paths in anything committed.
5. **Record results back.** Engine-verified outcomes (either way) go onto the wiki
   Arma-2-OA-Command-Version-Reference page so the next agent stops at rung 1.

## Known engine-verified semantics (do not re-litigate; details on the wiki)

- A no-match `switch` returns the SWITCH VALUE itself, not nil.
- Set-nil variables ignore 2-arg `getVariable` defaults; assigning Void UNDEFINES a var.
- `exitWith` in `then{}`/`else{}` exits only that block (falls through); a top-scope
  `if (...) exitWith {v}` inside a `call` RETURNS v.
- `if (0)` is truthy — numeric flags need `> 0`.

## Quick static screen

Before any probe, run the lint gate — it already knows the common A3 traps:

```powershell
python Tools/Lint/check_sqf.py --select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BOOLCMP,BRACKET,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV --no-classname-index
```

The gate reports ~447 pre-existing findings; only new findings in your edited files matter.
A clean lint does NOT prove an unlisted command exists — the select list is a known-trap
screen, not an OA dictionary. Unlisted + uncertain = climb the ladder.

### Per-line suppression (noqa)

Silence a specific finding on a line with `// noqa: CODE` (e.g. `// noqa: A3CMD`); bare
`// noqa` silences all codes on that line. Stale suppressions that no longer match any
finding are reported as `DEADNOQA` — remove rather than accumulate. `A3PRIVATE` was
restored to the gate list by PR #741; check for `// noqa: A3PRIVATE` annotations left
over from its earlier absence and remove them if the inline `private _x =` trap is fixed.
