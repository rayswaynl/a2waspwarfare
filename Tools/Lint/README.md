# WASP SQF lint tooling

`check_sqf.py` is a lightweight static checker for fleet PRs. `check_stringtable_refs.py` cross-references mission `STR_` references against `stringtable.xml`. Both tools have no third-party dependencies.

## Usage

```powershell
python Tools\Lint\check_sqf.py Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\GUI\GUI_Menu_Tactical.sqf
python Tools\Lint\check_sqf.py --no-classname-index Missions\[55-2hc]warfarev2_073v48co.chernarus
python Tools\Lint\check_stringtable_refs.py
python Tools\Lint\check_stringtable_refs.py --orphans
python Tools\Lint\check_stringtable_refs.py --exit-zero
```

With no paths, `check_sqf.py` scans both maintained mission roots.

With no paths, `check_stringtable_refs.py` scans the maintained Chernarus source mission and checks it against that mission's `stringtable.xml`. Pass explicit paths to scan a narrower file set or a per-map exception. BI/expansion keys such as `STR_EP1_`, `STR_DN_`, `STR_TASK*`, and input-display keys are ignored by default; use `--check-builtins` when you deliberately want to audit those too.

Use `--exit-zero` for report-only CI jobs that should print findings without failing the run.

## Checks

- `A3CMD`: common Arma 3 command traps from the fleet prompt.
- `BOOLCMP`: `==` or `!=` inside `if`, `while`, or `waitUntil` expressions for review.
- `BRACKET`: comment/string-aware bracket balance.
- `CLASSREF`: quoted classname-like token appears only in the edited file.
- `DISABLESER`: UI control helpers appear without `disableSerialization`.

## Stringtable Checks

- `STRMISSING`: referenced `STR_` key is not defined in the selected `stringtable.xml`.
- `STRDUP`: duplicate `Key ID` entry in the selected `stringtable.xml`.
- `STRORPHAN`: defined key is not referenced by scanned files; enabled only with `--orphans`.

The output is `path:line:column: code: message`, suitable for PR comments or CI logs.
