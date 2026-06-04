# Quad AI Commander Phase 0 Non-Runtime Readiness

This note separates #14 non-runtime readiness items from the in-engine Phase 0 smoke gate.

Runtime proof still decides whether the AI Commander execution substrate can feed Phase 1 logs. These items decide whether #14 is ready for normal review/merge hygiene once runtime proof exists.

## Target

```text
PR: #14 AI Commander + hybrid co-op command
Branch: feat/ai-commander
Source mission: Missions/[55-2hc]warfarev2_073v48co.chernarus
```

## 1. Takistan / Variant Regeneration

#14 currently changes the Chernarus mission source files only. Before ready review, regenerate or propagate the equivalent generated mission variant(s), especially Takistan, through the repo's normal LoadoutManager workflow.

Required evidence:

```text
Tool/workflow used:
Source commit:
Generated mission(s):
Files changed:
Manual conflicts:
```

Expected parity areas:

- `Common/Init/Init_CommonConstants.sqf`
- `Rsc/Parameters.hpp`
- `Server/Init/Init_Server.sqf`
- `Server/AI/Commander/AI_Commander.sqf`
- `Server/AI/Commander/AI_Commander_Execute.sqf`
- `Server/AI/Commander/AI_Commander_AssignTowns.sqf`
- `Server/AI/Commander/AI_Commander_AssignTypes.sqf`
- `Server/AI/Commander/AI_Commander_Produce.sqf`
- `Server/Functions/Server_AI_Com_Upgrade.sqf`

Pass when:

- Generated variant files contain the same AI Commander constants, compile hooks, supervisor spawn, workers, and upgrade-cost fixes as the Chernarus source.
- No generated-only merge conflict or stale old AI Commander behavior remains.
- The PR diff makes clear whether generated files were committed or intentionally deferred.

## 2. Command Center Label Rename Dependency

#14 references the existing Command Center Auto AI delegation path. Its PR body lists the PR8-L1 label rename as pending.

Do not rename blindly from memory. Resolve the exact desired label from the release bundle / PR #8 before editing #14.

Required evidence:

```text
Source of desired label:
Old label/string:
New label/string:
Files changed:
```

Pass when:

- #14 contains the same user-facing label text as the accepted release-bundle wording.
- Documentation and PR text still describe the delegation behavior accurately.
- No script variable such as `wfbe_autonomous` is renamed unless the release bundle explicitly requires it.

## 3. PR Body Hygiene

Before ready review, #14 should distinguish three categories:

- runtime evidence already collected
- runtime evidence still pending
- non-runtime hygiene still pending

Suggested final pending list if unresolved:

```text
- [ ] Phase 0 runtime checklist PASS: hybrid command bar, delegation, economy freeze, handoff, stopped.
- [ ] Takistan / generated mission parity completed or explicitly deferred.
- [ ] Command Center label rename from PR8-L1 propagated or explicitly deferred.
```

## Stop Conditions

Do not mark #14 ready if:

- Takistan/generated files are stale and expected in the release bundle
- the label rename source is unclear
- the label rename changes script variables instead of only user-facing text without explicit approval
- runtime smoke is missing but non-runtime hygiene is complete

## Relationship To Later Phases

#18 and #19 can remain draft scaffolds while these non-runtime #14 items are open, but they should not leave draft until #14 has both:

- runtime Phase 0 evidence
- an accepted decision on generated mission parity and label rename handling
