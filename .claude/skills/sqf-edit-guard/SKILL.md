---
name: sqf-edit-guard
description: Load BEFORE creating or modifying any .sqf/.fsm/.hpp file under Missions/**. Banned A2-OA command checklist, engine-semantics traps, the mandatory targeted-Python CRLF editing workflow, and the post-edit lint + bracket gates.
---
<!-- source: Agent-Guide GUIDE-REV GR-2026-07-08a -->

# sqf-edit-guard

Target engine is **Arma 2 OA 1.64 only**. Canonical trap taxonomy lives on the wiki
([AI-Assistant-Developer-Guide](https://github.com/rayswaynl/a2waspwarfare/wiki/AI-Assistant-Developer-Guide));
this checklist condenses it — when in doubt, the wiki wins.

## 1. Banned commands (A3-only — silent corruption or crash on OA)

Never write: `isEqualType`, `isEqualTo`, `params`, `pushBack`, `findIf`,
`selectRandom` (command form), `apply`, `remoteExec`, `distance2D`,
`setGroupOwner`, `joinGroup`, `getPosVisual`, `worldSize`, `forceFollowRoad`,
array-form `reveal`, A3 string `find`, substring `select [a,b]`, sort-by-code.

- Append to an array with `_arr set [count _arr, _v]` — never `pushBack`.
- Declare locals with `private ["_x"]` — never inline `private _x =`.
- Unsure a command exists on OA 1.64? Load the **a2oa-verify-command** skill first.

## 2. Semantics traps

- **BOOLCMP**: never `==` / `!=` with Boolean operands — use `if (_flag)` / `if (!_flag)`.
- **Numeric flags**: guard with `> 0`; `if (0)` is TRUTHY on OA.
- **GROUPGETVAR**: never 2-arg `getVariable [name, default]` on a GROUP receiver —
  use `WFBE_CO_FNC_GroupGetBool` or 1-arg + `isNil`.
- **NSSETVAR3**: never `missionNamespace setVariable` with a third (public) argument.
- **exitWith scope**: never `exitWith` inside `forEach` to skip one iteration (use `if`
  nesting); `exitWith` in `then{}`/`else{}` exits only that block and FALLS THROUGH.
- **_x capture**: capture outer `_x` into a named local before any inner `forEach` —
  the inner loop permanently rebinds it.
- "Has launcher" = non-empty `secondaryWeapon _unit`, NOT `primaryWeapon`.
- Never `isKindOf` on weapon/magazine classnames — it walks `CfgVehicles`.
- Never reset `MenuAction` before the second click of a two-click confirm flow.
- Never `publicVariableServer` FROM the server — call the server callback directly.
- Valid OA syntax linters flag falsely (keep): `getDammage`/`setDammage`, `;;`,
  `&& {code}`, `|| {code}`, `isNil {block}`. Command casing is not significant.

## 3. Editing mechanics (mandatory)

NEVER use the Edit/Write tools on `.sqf` — the formatter reflows whole files. Use a
targeted Python script: read bytes, apply an exact replacement, write back, preserving
CRLF and indentation byte-for-byte outside the intended change. Pattern:

```powershell
python -c "p=r'Missions/[55-2hc]warfarev2_073v48co.chernarus/PATH/File.sqf'; d=open(p,'rb').read(); old=b'EXACT OLD BYTES'; new=b'EXACT NEW BYTES'; assert d.count(old)==1, d.count(old); open(p,'wb').write(d.replace(old,new))"
```

Edit ONLY under `Missions/[55-2hc]warfarev2_073v48co.chernarus/` — TK/ZG come from the
mirror (load **mirror-regen** after editing).

## 4. Post-edit gates (both must pass before staging)

```powershell
python Tools/Lint/check_sqf.py --select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BOOLCMP,BRACKET,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV --no-classname-index
```
The gate reports ~447 pre-existing findings across the tree; only NEW findings in files you
edited matter. Then per changed file, net `{}` and `[]` delta vs base must be zero:

```powershell
git diff origin/master -- "CHANGED_FILE.sqf" | python -c "import sys; L=sys.stdin.read().splitlines(); A=''.join(l[1:] for l in L if l.startswith('+') and not l.startswith('+++')); R=''.join(l[1:] for l in L if l.startswith('-') and not l.startswith('---')); print('curly', A.count('{')-A.count('}')-R.count('{')+R.count('}'), 'square', A.count('[')-A.count(']')-R.count('[')+R.count(']'))"
```
Both numbers must print 0.

### Per-line suppression (noqa)

Suppress a specific finding on one line with a trailing comment: `// noqa: CODE`
(e.g. `// noqa: A3CMD`). Bare `// noqa` silences ALL codes on that line.
Stale suppressions — where the annotated code no longer fires a finding on that line —
are themselves reported as `DEADNOQA`. Remove them rather than stacking suppressions.
`A3PRIVATE` was restored to the gate list (PR #741) after a period of exclusion; check
for any `// noqa: A3PRIVATE` annotations added during that window and remove them if
the underlying inline `private _x =` trap has already been corrected.

If the edit added/changed any `STR_` reference or touched `stringtable.xml`, also run:

```powershell
python Tools/Lint/check_stringtable_refs.py
```

(defaults to the Chernarus source mission; add `--orphans` to also list unused keys).

## 5. New classnames

Every new classname must already appear in the mission tree, OR be verified in the
config-reference repo [rayswaynl/arma2-co-config-reference](https://github.com/rayswaynl/arma2-co-config-reference)
(`Config/CfgVehicles.txt`; use a local checkout if your environment has one) with that
citation as config proof in the PR body.
