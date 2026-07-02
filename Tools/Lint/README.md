# WASP SQF lint tooling

`check_sqf.py` is a lightweight static checker for fleet PRs. It has no third-party dependencies and can scan changed files or whole mission roots.

## Usage

```powershell
python Tools\Lint\check_sqf.py Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\GUI\GUI_Menu_Tactical.sqf
python Tools\Lint\check_sqf.py --no-classname-index Missions\[55-2hc]warfarev2_073v48co.chernarus
python Tools\Lint\test_check_sqf.py
python Tools\Lint\check_sqf.py --select A3CMD,BRACKET --no-classname-index
python Tools\Lint\check_sqf.py --ignore BOOLCMP,CLASSREF Missions\[55-2hc]warfarev2_073v48co.chernarus
```

With no paths, the checker scans both maintained mission roots.

Use `--select` for focused gates, such as an Arma 3 command-trap pass that should not fail on broad legacy `BOOLCMP` review findings. Use `--ignore` when you want the normal checker minus one or more noisy codes. Both options take comma-separated finding codes.

## Checks

- `A3CMD`: common Arma 3 command traps from the fleet prompt.
- `A3MARKER`: A3 NATO marker types such as `b_inf`.
- `A3REVEAL`: array-form `reveal` usage.
- `A3SELECT`: `select [start,count]` slice syntax.
- `A3SORT`: sort-by-code syntax.
- `A3STRING`: string `find` syntax.
- `BOOLCMP`: `==` or `!=` inside `if`, `while`, or `waitUntil` expressions for review.
- `BRACKET`: comment/string-aware bracket balance.
- `CLASSREF`: quoted classname-like token appears only in the edited file.
- `DISABLESER`: UI control helpers appear without `disableSerialization`.
- `GROUPGETVAR`: two-argument `getVariable` on group-like expressions.

The output is `path:line:column: code: message`, suitable for PR comments or CI logs.
