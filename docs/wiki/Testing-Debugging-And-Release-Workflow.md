# Testing Debugging And Release Workflow

This page is the quick validation checklist for docs, source-review and future code patches. It is intentionally shorter than [Tools and build workflow](Tools-And-Build-Workflow), but it names the gates future agents should actually run.

## Baseline Docs Gates

Run these from `C:\Users\Steff\a2waspwarfare-docs` after meaningful wiki or machine-context edits:

```powershell
powershell -ExecutionPolicy Bypass -File docs\validate-wiki.ps1
```

This validator includes Markdown link checks, machine-reference checks, full wiki JSON/JSONL parse checks, stale false-patched wording checks and the Arma 2 OA compatibility guardrail scan. Use a standalone JSON parse snippet only when isolating a parse failure.

```powershell
git diff --check
```

Mirror check after syncing `docs/wiki` to `C:\Users\Steff\_wasp_wiki_tmp`:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\TestWikiParity.ps1 -WikiPath C:\Users\Steff\_wasp_wiki_tmp
powershell -ExecutionPolicy Bypass -File .\Tools\ValidateWiki.ps1 -WikiPath C:\Users\Steff\_wasp_wiki_tmp -SkipGitDiffCheck
```

Expected warning today: `git diff --check` and the wiki validator can emit CRLF conversion warnings for many touched wiki files. Treat those as warnings, not failures, when the command exits 0.

## Arma 2 OA Compatibility Gate

`docs\validate-wiki.ps1` now includes a guardrail scan for high-traffic onboarding/current-state files: modern Arma 3/SQF terms must be framed as warnings, caveats or OA-safe alternatives.

For docs or patches that mention scripting commands, also run the [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) checklist:

- no `remoteExec` or `remoteExecCall`;
- no SQF `params` syntax;
- no `isEqualTo`, `isEqualType`, `parseSimpleArray` or `private _var = value`;
- no `BIS_fnc_MP`, CBA/ACE helpers, Eden-editor assumptions, `remoteExecutedOwner`, `isRemoteExecuted`, `allPlayers` or Arma 3 JIP/locality claims without OA 1.64/source proof;
- use source-local publicVariable/PVF patterns unless a BI OA page proves another primitive is valid.

## Source-Only Review Gates

Use source-only review to prove file presence, call paths, registration lists, generated-mission drift and documentation claims. Source-only review does **not** prove Arma runtime behavior.

| Review type | Useful checks |
| --- | --- |
| Current disputed cleanup status | Re-check [Current source status snapshot](Current-Source-Status-Snapshot) evidence before saying a lane is patched. |
| Networking/PVF | Inspect `Common/Init/Init_PublicVariables.sqf`, `Server/Functions/Server_HandlePVF.sqf`, `Client/Functions/Client_HandlePVF.sqf` and the relevant PVF/direct-PV handler. |
| Generated Vanilla | Use [Tools and build workflow](Tools-And-Build-Workflow) for LoadoutManager skip-list rules before claiming Chernarus changes reached Takistan. |
| Machine context | Keep `agent-context.json`, `agent-status.json`, `agent-hardening-backlog.jsonl`, `agent-feature-status.jsonl`, `agent-knowledge.jsonl`, `agent-events.jsonl` and `llms.txt` aligned when high-level truth changes. |

## Mission-Code Patch Gates

When gameplay code work is explicitly requested later:

1. Patch `Missions/[55-2hc]warfarev2_073v48co.chernarus` first.
2. Run or deliberately defer `Tools/LoadoutManager` propagation; hand-mirror skip-listed files when the generator cannot copy them.
3. Inspect generated Vanilla Takistan diffs before publishing.
4. Update owner pages, feature-status/backlog JSONL and worklog/event surfaces.
5. Run the docs gates above after documentation/machine updates.

Runtime smoke still matters. Hosted/listen, dedicated, JIP, HC and BattlEye behavior cannot be claimed from source review alone. Record exact Arma 2 OA runtime evidence before marking smoke done.

## Continue Reading

Tool details: [Tools and build workflow](Tools-And-Build-Workflow) | First ten minutes: [Quickstart](Quickstart-For-Humans-And-Agents) | OA guardrails: [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit)
