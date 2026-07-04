# Miksuu Drive Mirror Catalog

Status: DRAFT, root drive observed but mirror folder not fully traversed due intermittent sandbox command failures  
Related roster lane: 447

## Observed Local Context

The archive root `E:\arma2-cache` exists and contains both raw archives and extracted trees. The roster identifies the Miksuu Drive mirror as mandatory and states that `docs/design/ARCHIVE-MINING.md` maps catalog IDs, borrow verdicts, and Drive ids.

During this pass, command execution became unreliable after the root listing. A complete tree walk of the Miksuu Drive mirror could not be finished in-session. This file records the catalog structure a follow-up builder/miner must fill, and the partial observed archive context.

## Required Catalog Fields

| Field | Meaning |
|---|---|
| Path | Full path under `E:\arma2-cache`. |
| Type | mission source, config, design note, changelog, LoadoutManager artifact, wiki export, unknown. |
| Duplicate status | duplicate, complementary, novel. |
| WASP relationship | Which current subsystem it informs. |
| Design value | 1-3 sentences for complementary/novel items. |
| Borrow verdict | borrow-as-design, context only, skip. |
| License risk | none observed, unknown, GPL/other review needed. |

## Initial Findings From Archive Root

| Item | Observed path | Tag | Design value |
|---|---|---|---|
| Archive reports | `E:\arma2-cache\reports\WASP-COMBINED-COOKBOOK.md` | complementary | Large prior mining report likely contains summarized snippets and ideas. Use as a cross-check, not as a replacement for source archive review. |
| Archive ideas report | `E:\arma2-cache\reports\WASP-IDEAS-REPORT.md` | complementary | Prior design extraction; reconcile with V2 commandments before reusing. |
| Mission mining findings | `E:\arma2-cache\reports\MISSION-MINING-FINDINGS.md` | complementary | Candidate index of previously mined mission mechanics. |
| Findings dataset | `E:\arma2-cache\reports\findings.csv` | complementary | Structured catalog likely useful for de-duplicating archive hits. |
| Archive indexes | `E:\arma2-cache\index.csv`, `triage.csv`, `jerry-available.csv` | complementary | Use to locate Drive mirror IDs and avoid re-cataloging prior Jerry work. |
| Extracted mission sources | `E:\arma2-cache\extracted\...` | novel/complementary | Must be filtered for CTI/Warfare only before design extraction. |

## Follow-Up Walk Procedure

1. Open `docs/design/ARCHIVE-MINING.md`.
2. Locate the Miksuu Drive mirror root and Drive ID mapping.
3. Walk every file/folder under that root.
4. Assign duplicate/complementary/novel status.
5. Expand novel items with design value.
6. Cross-reference `wiki:Miksuu-Upstream-Wiki-Import` and `wiki:Developer-History-And-Upstream-Lessons`.

## Completion Gap

This lane is not complete as a full tree catalog. It needs one uninterrupted filesystem pass over the Drive mirror.
