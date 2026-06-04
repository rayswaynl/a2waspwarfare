# Agent Release Readiness Ledger

This is the human/MkDocs wrapper for [`agent-release-readiness.json`](agent-release-readiness.json). The JSON file is the canonical machine-readable ledger for tracked mission fixes, generated-target propagation and Arma 2 OA smoke gates.

Use this before release notes, generated mission propagation or any claim that a source fix is complete outside the Chernarus source mission.

## What It Tracks

| Section | Meaning |
| --- | --- |
| `toolingGate` | LoadoutManager root-discovery rule, skip-zip option and current local checkout status. |
| `sourceOnlyFixes` | Compatibility key for tracked fixes; entries now record source, Vanilla and smoke status independently. |
| `patchReadyNotSourcePatched` | Playbooks that are ready for implementation but are not current source patches. |
| `releaseGate` | Minimum validation needed before a lane can be called release-complete. |

## Current Canonical Flow

1. Read [Source fix propagation queue](Source-Fix-Propagation-Queue) for the human explanation.
2. Load [`agent-release-readiness.json`](agent-release-readiness.json) for machine status.
3. Run LoadoutManager from a checkout where root discovery succeeds; normal repo-root marker checkouts now work.
4. Inspect generated diffs.
5. Record Arma 2 OA smoke in the owning page and machine files.

## Continue Reading

Previous: [Source fix propagation queue](Source-Fix-Propagation-Queue) | Next: [Testing workflow](Testing-Debugging-And-Release-Workflow)

Main map: [Home](Home) | Machine ledger: [`agent-release-readiness.json`](agent-release-readiness.json) | Progress: [Progress dashboard](Progress-Dashboard)
