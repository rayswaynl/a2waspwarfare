# Arma 2 OA Compatibility Audit

This page records a documentation audit for accidental Arma 3 assumptions. It exists so future humans, Codex, Claude and other LLM agents can distinguish intentional "do not use Arma 3 here" guardrails from unsafe advice.

Audit date: 2026-06-02

Latest refresh: 2026-06-02T14:00:39+02:00

Scope:

- `docs/wiki/*.md`
- `docs/wiki/*.json`
- `docs/wiki/*.jsonl`
- `docs/wiki/*.txt`

## Search Patterns

These searches were run against the repo docs mirror:

```powershell
rg -n -i "\bArma ?3\b|\bA3\b|Arma3|remoteExec(Call)?|BIS_fnc_MP|addMissionEventHandler|isRemoteExecuted|remoteExecutedOwner|CfgFunctions|CBA|ACE|Eden Editor" docs\wiki --glob '*.md'
rg -n -i "remoteExec|remoteExecCall|BIS_fnc_MP|addMissionEventHandler|isRemoteExecuted|remoteExecutedOwner|CfgFunctions|Eden Editor|parseSimpleArray|RVExtensionArgs" docs\wiki --glob '*.{md,json,jsonl,txt}'
rg -n -i "\bCBA\b|\bACE\b|Eden" docs\wiki --glob '*.{md,json,jsonl,txt}'
```

Broad searches for `params` and `A3` are intentionally avoided as primary tests because this mission legitimately uses Arma 2 mission `Params` / `paramsArray`, and short tokens produce false positives inside unrelated words or identifiers.

## Classification

| Term or pattern | Result | Action |
| --- | --- | --- |
| `Arma 3` / `Arma3` | Present as compatibility warnings and agent guardrails. | Keep. These references warn agents away from Arma 3 assumptions. |
| `remoteExec` / `remoteExecCall` | Present as invalid drop-in examples. | Keep as warnings only. The live mission uses OA-era public variables, PVEHs and wrapper functions. |
| `BIS_fnc_MP` | Present only in future-agent checklist text as an Arma 3/modernization hazard. | Keep as warning text; do not use it as implementation guidance. |
| `remoteExecutedOwner` | Present in deep-review evidence to contrast Arma 2 OA PVEHs with Arma 3 ownership APIs. | Keep. It explains why sender authority must be reconstructed from payload/server state. |
| `parseSimpleArray` | Present as an explicit non-option for Arma 2 OA extension hardening. | Keep. The docs correctly say defensive validation is the A2-correct path. |
| `RVExtensionArgs` | Present as an A3 extension ABI that does not exist here. | Keep as caveat in extension review evidence. |
| `CfgFunctions` | Present as a "do not assume CfgFunctions auto-init" warning. | Keep. `Lifecycle-Wait-Chain.md` documents the mission's hand-rolled init barriers. |
| `CBA` / `ACE` | Only appears in a checklist warning not to introduce CBA helpers. | Keep as a dependency guardrail. |
| `Eden` / `eden` | Present as a modded terrain/folder name, not Eden Editor workflow advice. | Keep. Do not reinterpret the mission folder as an Arma 3 editor assumption. |

## Current Result

No incorrect Arma 3 implementation advice was found in the current docs mirror. The explicit Arma 3 references are guardrails, contrast notes or compatibility warnings.

The docs now route agents to this audit before accepting or adding engine-version-sensitive claims. Future changes should update this page if an Arma 3-style term is added intentionally.

## Safe Wording For Future Agents

Prefer:

- "Use Bohemia Interactive Arma 2 OA / Combined Operations command support as the baseline."
- "This is an OA-era publicVariable/PVEH flow, not a `remoteExec` flow."
- "Validate the command against OA 1.64 support before proposing it."
- "Do not add CBA/ACE helpers unless the mission owner accepts a new dependency."
- "`Params` / `paramsArray` are the mission parameter system here; do not confuse them with newer SQF `params` command style."
- "`Modded_Missions/eden` is a terrain/fork folder name, not evidence of an Eden Editor workflow."

Avoid:

- "Use `remoteExec` for this RPC."
- "Move this into CfgFunctions preInit/postInit" without an explicit OA-compatible migration plan.
- "Use `parseSimpleArray` to harden extension output."
- "Use Arma 3 BattlEye examples as proof that this repo ships those filters."

## Follow-Up Check

Run this lightweight audit after future documentation passes:

```powershell
rg -n -i "\bArma ?3\b|Arma3|remoteExec(Call)?|BIS_fnc_MP|remoteExecutedOwner|parseSimpleArray|RVExtensionArgs|CfgFunctions|Eden Editor|\bCBA\b|\bACE\b" docs\wiki --glob '*.{md,json,jsonl,txt}'
```

## Current Scan Snapshot

This refresh includes the newer AntiStack, integration-trust, release-readiness and source-propagation pages.

| Pattern | Hit count | Current classification |
| --- | ---: | --- |
| `Arma 3` / `Arma3` | 64 | Guardrails, contrast notes and agent instructions. |
| `remoteExec` / `remoteExecCall` | 27 | Invalid-drop-in warnings for the OA-era PV/PVEH model. |
| `BIS_fnc_MP` | 11 | Modernization hazard warning; not implementation advice. |
| `remoteExecutedOwner` / `isRemoteExecuted` | 14 | Evidence contrast for missing OA sender identity. |
| `parseSimpleArray` | 19 | Explicit non-option for AntiStack/extension hardening in OA. |
| `RVExtensionArgs` | 10 | Explicit non-option for the in-repo extension ABI. |
| `CfgFunctions` | 14 | Warning against assuming automatic preInit/postInit lifecycle. |
| `CBA` / `ACE` | 10 | Dependency guardrail. |
| `Eden Editor` | 11 | Folder-name caveat and audit text; not editor workflow advice. |

Representative pages intentionally containing risky terms:

- [AI assistant developer guide](AI-Assistant-Developer-Guide) and [LLM agent entry pack](LLM-Agent-Entry-Pack): tell agents to avoid Arma 3 assumptions.
- [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook): lists `isEqualTo`, `params`, `remoteExec`, `BIS_fnc_MP` and CBA helpers as things not to introduce without OA proof.
- [Deep-review findings](Deep-Review-Findings): uses `remoteExecutedOwner`, `parseSimpleArray` and `RVExtensionArgs` only as contrast with Arma 2 OA behavior.
- [AntiStack database extension audit](AntiStack-Database-Extension-Audit), [Integration trust boundary audit](Integration-Trust-Boundary-Audit) and [External integrations](External-Integrations): explicitly reject Arma 3 parser advice for `A2WaspDatabase` hardening.
- `agent-context.json`, `agent-knowledge.jsonl`, `agent-hardening-backlog.jsonl` and `agent-events.jsonl`: mirror the same classifications for machine readers.

Each hit should be one of:

- intentional guardrail
- explicit non-option
- evidence quote / deep-review caveat
- terrain or folder name
- item requiring correction

## Agent Decision Procedure

When a future prompt, report or patch proposes a risky term:

1. Check whether the term is already classified in [`agent-compatibility-audit.json`](agent-compatibility-audit.json).
2. If the term is only a warning, leave it as warning text and do not turn it into an implementation step.
3. If the term is proposed as implementation advice, require a Bohemia Interactive Arma 2 OA / Combined Operations source proving support.
4. If OA support is not proven, replace the advice with the existing mission pattern: public variables/PVEHs, hand-rolled init barriers, defensive `call compile` shape validation or local helper functions.
5. If the term is added intentionally, update this page and the JSON audit with its classification and representative pages.

## Corrections Needed Now

No incorrect Arma 3 implementation advice was found in the current docs mirror during the 2026-06-02T14:00:39+02:00 refresh.

The main maintenance need is not deletion; it is keeping the warnings clearly marked as warnings. The highest-risk places are future AntiStack hardening, PVF/server-authority work and lifecycle refactors, because those are where modern Arma APIs look tempting but would be wrong for OA unless independently proven.

## Continue Reading

Previous: [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) | Next: [AI assistant developer guide](AI-Assistant-Developer-Guide)

Main map: [Home](Home) | LLM entry: [LLM agent entry pack](LLM-Agent-Entry-Pack) | Agent file: [`agent-context.json`](agent-context.json)
