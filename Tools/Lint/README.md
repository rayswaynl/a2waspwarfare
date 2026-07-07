# WASP SQF lint tooling

`check_sqf.py` is a lightweight static checker for fleet PRs. `check_stringtable_refs.py` cross-references mission `STR_` references against `stringtable.xml`. Both tools have no third-party dependencies.

## Usage

```powershell
python Tools\Lint\check_sqf.py Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\GUI\GUI_Menu_Tactical.sqf
python Tools\Lint\check_sqf.py --no-classname-index Missions\[55-2hc]warfarev2_073v48co.chernarus
python Tools\Lint\test_check_sqf.py
python Tools\Lint\check_sqf.py --select A3CMD,BRACKET --no-classname-index
python Tools\Lint\check_sqf.py --diff-from origin/claude/build84-cmdcon36 --select A3CMD,A3MARKER,A3REVEAL,A3SELECT,A3SORT,A3STRING,BOOLCMP,BRACKET,GROUPGETVAR,NSSETVAR3 --no-classname-index
python Tools\Lint\check_sqf.py --ignore BOOLCMP,CLASSREF Missions\[55-2hc]warfarev2_073v48co.chernarus
python Tools\Lint\check_stringtable_refs.py
python Tools\Lint\check_stringtable_refs.py --orphans
python Tools\Lint\check_stringtable_refs.py --ru-gaps --exit-zero
python Tools\Lint\check_stringtable_refs.py --languages Russian,Czech --exit-zero
python Tools\Lint\check_stringtable_refs.py --exit-zero
```

With no paths, `check_sqf.py` scans the maintained mission roots: source Chernarus plus the vanilla Takistan and Zargabad mirrors.

With no paths, `check_stringtable_refs.py` scans the maintained Chernarus source mission and checks it against that mission's `stringtable.xml`. Pass explicit paths to scan a narrower file set or a per-map exception. BI/expansion keys such as `STR_EP1_`, `STR_DN_`, `STR_TASK*`, and input-display keys are ignored by default; use `--check-builtins` when you deliberately want to audit those too.

Use `--ru-gaps` to report keys whose Russian stringtable column is missing or blank. Use `--languages` with a comma-separated list, or repeat it, when auditing other translation columns. Language gap reporting is opt-in so the default cross-reference scan remains compatible with existing lanes.

Use `--exit-zero` for report-only CI jobs that should print findings without failing the run.

Use `--select` for focused gates, such as an Arma 3 command-trap pass that should not fail on broad legacy `BOOLCMP` review findings. Use `--ignore` when you want the normal checker minus one or more noisy codes. Both options take comma-separated finding codes.

Use `--diff-from <ref>` to report only findings whose primary line was added since that Git ref. This is useful for fleet PR self-checks where the full mission still has legacy review findings, but the new diff must be clean. With no paths, diff mode scans changed files under the maintained default mission roots; pass explicit SQF/HPP/EXT/FSM/SQM files or directories for narrower mission checks.

## Checks

- `A3CMD`: common Arma 3 command traps from the fleet prompt.
- `A3BISFNC`: `call BIS_fnc_*` usage that depends on Arma 3 function-library helpers.
- `A3MARKER`: A3 NATO marker types such as `b_inf`.
- `A3NUMGATE`: numeric `getVariable` gates on string-typed constant names ending in `_TYPE`, `_CLASS`, or `_LAUNCHER`.
- `A3REVEAL`: array-form `reveal` usage.
- `A3SELECT`: `select [start,count]` slice syntax.
- `A3SORT`: sort-by-code syntax.
- `A3STRING`: string `find` syntax.
- `BOOLCMP`: `==` or `!=` inside `if`, `while`, or `waitUntil` expressions for review.
- `BRACKET`: comment/string-aware bracket balance.
- `CLASSREF`: quoted classname-like token appears only in the edited file.
- `DISABLESER`: UI control helpers appear without `disableSerialization`.
- `GROUPGETVAR`: two-argument `getVariable` on group-like expressions.
- `NSSETVAR3`: `missionNamespace`/`uiNamespace`/`profileNamespace` `setVariable` with three or more top-level elements. The public-flag form is Arma 3-only; A2/OA 1.64 throws `Error 3 elements provided, 2 expected` at runtime and leaves the variable unset (shipped in Build 87, hotfixed in cmdcon42b). Object and group `setVariable` with a public flag is valid on A2/OA and is not flagged.
- `TRAILCOMMA`: trailing comma immediately before a closing `]` in an array literal, allowing whitespace, newlines, and comments in between — the preprocessor strips comments, so `true],` followed by a `//---` comment and then `];` still fails to parse. Fatal `Error Missing [` at mission init on A2 OA 1.64 (PR #801 / `Init_Defenses.sqf` `WFBE_POSITION_TEMPLATE_MAP` incident, 2026-07-07, hotfixed in b517fd5e1). String contents never trigger it (`"a,]"` is safe).

## Stringtable Checks

- `STRMISSING`: referenced `STR_` key is not defined in the selected `stringtable.xml`.
- `STRDUP`: duplicate `Key ID` entry in the selected `stringtable.xml`.
- `STRORPHAN`: defined key is not referenced by scanned files; enabled only with `--orphans`.
- `STRLANG`: selected language column is missing or blank for a stringtable key; enabled only with `--ru-gaps` or `--languages`.

The output is `path:line:column: code: message`, suitable for PR comments or CI logs.
