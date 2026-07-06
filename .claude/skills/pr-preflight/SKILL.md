---
name: pr-preflight
description: Load BEFORE any `git push` or `gh pr create` in this repo — claim/duplication checks, shelved-work registry, flag-policy audit, full lint gates, draft-PR mechanics and required body fields, and evidence-wording rules.
---
<!-- source: Agent-Guide GUIDE-REV GR-2026-07-06a -->

# pr-preflight

Canonical rules: wiki [AI-Assistant-Developer-Guide](https://github.com/rayswaynl/a2waspwarfare/wiki/AI-Assistant-Developer-Guide)
and [Agent-Worklog](https://github.com/rayswaynl/a2waspwarfare/wiki/Agent-Worklog). This
checklist condenses; the wiki wins on conflict.

## 1. Claim pre-flight (the lane-456 lesson: check the TOPIC, not just the files)

- `agent-status.json` (fleet runtime artifact; may be absent — then use the wiki
  [Agent-Worklog](https://github.com/rayswaynl/a2waspwarfare/wiki/Agent-Worklog)).
- Open PRs touching the same files OR the same topic:
  ```powershell
  gh pr list --state open --limit 100
  ```
- Remote branches already claiming the topic:
  ```powershell
  git ls-remote --heads origin | Select-String -Pattern '<topic-keyword>'
  ```
- If a target file is in an in-flight PR: base on that PR's HEAD and declare
  "stacked on #NNN" in the body. One active claim per lane.

## 2. Shelved / owner-rejected check

Shelved PRs (wiki `Shelved-PR-*` pages, e.g.
[Shelved-PR-Registry](https://github.com/rayswaynl/a2waspwarfare/wiki/Shelved-PR-Registry))
are CLOSED proposals — never re-open or duplicate. Owner-rejected forever: sim/distance
gating (`WFBE_C_SIM_GATING`), antistack changes, TPWCAS, AI supply trucks, satchel AI,
EMP/WP/DECOY SCUD, doctrine personalities, GUER caps/nerfs.

## 3. Flag-policy audit (feature PRs)

- New behavior gated behind a new `WFBE_C_*` flag, default `0`, APPENDED to
  `Common/Init/Init_CommonConstants.sqf`. Never change an existing default.
- With the flag at 0 the mission is byte-identical to HEAD — state WHY in the body.
- Numeric flag reads guarded `> 0`, never bare `if (flag)`.
- Correctness fixes (crash/nil/idempotency) ship unflagged.

## 4. Gates (all must pass — see sqf-edit-guard and mirror-regen for detail)

1. `python Tools/Lint/check_sqf.py --select A3CMD,A3MARKER,A3REVEAL,A3SELECT,A3SORT,A3STRING,GROUPGETVAR,BRACKET,NSSETVAR3 --no-classname-index` → 0 findings.
2. Per changed file: net `{}` and `[]` delta vs merge-base = 0.
3. Mirror ran (`dotnet run -c RELEASE`, `A2WASP_SKIP_ZIP=1`), `-- --check` clean,
   TK/ZG `version.sqf.template` restored to merge-base.
4. Nothing staged from: `_MISSIONS.7z`, `nul`, line-ending-churn files.

## 5. PR mechanics

```powershell
gh pr create --draft --base claude/build84-cmdcon36
```

- DRAFT only; never target `master`. Commit format:
  `feat(<lane>): <summary> [flag <FLAG> default 0]` — NO `Co-Authored-By` trailer.
- Body required fields: Feature; flag + default; why flag-off is inert; test plan;
  mirrors confirmed (CH→TK→ZG); GUIDE-REV stamp; "stacked on #NNN" if applicable.
- New classnames: in-tree, or cite the CfgVehicles config-reference proof.

## 6. Evidence wording (hard rules)

- Never "shipped" / "fixed" / "release-ready" without branch + commit hash.
- Never claim runtime-verified from static work. Static validation only; runtime
  evidence (RPT tokens from a box smoke) stays an OPEN item — say so in the test plan.
- Runtime claims require quoted RPT tokens windowed to the current MISSINIT
  (see rpt-triage).
