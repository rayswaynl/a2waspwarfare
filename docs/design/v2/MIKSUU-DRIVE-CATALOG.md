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

## Known Drive Shape

Existing repo research reports:

- The Drive mirror is a flat classic Armaholic / armedassault.info addon catalog.
- It contains about 4,210 `*_WithPW.7z` entries.
- Password for outer archives: `armedassault`.
- The outer archive wraps one inner archive, usually `.zip`, `.rar`, or `.7z`.
- No raw Drive tree is committed to this repo.

## Completion Procedure

Run on the Main PC with `E:\arma2-cache`:

```powershell
$root = 'E:\arma2-cache'
$out = 'C:\tmp\miksuu-drive-catalog.csv'
Get-ChildItem -LiteralPath $root -Recurse -File |
  Select-Object FullName,Name,Length,LastWriteTimeUtc,Extension |
  Export-Csv $out -NoTypeInformation
```

Then classify each row:

- `duplicate`: already in repo/wiki or already cataloged in `docs/design/ARCHIVE-MINING.md`.
- `complementary`: new version/map/config angle on an already known system.
- `novel`: not represented in repo/wiki and potentially useful as design input.

Novel rows need a 1-3 sentence design-value note. Unit packs, weapon packs, terrain-only archives, ACE total conversion content, and ACR content should be marked `skip-content` unless they contain mission scripts or docs.

## Seed Catalog

| Item | Tag | Description | Design value |
| --- | --- | --- | --- |
| Oden Warfare Pack 1.05h | novel | Warfare16 BE 1.6-era missions across multiple maps/faction reskins. | Island-index air assault and old commander economy stubs are strong clean-room V2 references. |
| `crcti_mpmissions_WithPW.7z` | complementary | crCTI Warfare missions for Chernarus/Utes. | Contrasts BE with crCTI town-win timer and group-order UI. |
| `mcti_r9_40vs40.Chernarus_WithPW.7z` | complementary | Compact MCTI mission with single-file AI commander. | Build narration idea; avoid its JIP-unsafe `SetVehicleInit` pattern. |
| `DAC_V3_WithPW.7z` | complementary | Dynamic AI Creator with readable configs and demos. | Terrain-aware waypoint and behavior-table reference for patrol/garrison tuning. |
| `R3F_Arty_and_Log_1.3_WithPW.7z` | novel-license-caution | Mission-script artillery/logistics package. | Object load/tow/lift logistics idea; GPLv3 means owner approval required before any code adoption. |
| `asr_ai-1.15.1_WithPW.7z` | duplicate | Older ASR AI package. | Already live via `@adwasp`; use only as settings reference. |
| `@zeu_cfg_core_ai_skills_v1.04_WithPW.7z` | complementary | Config-only AI skill/spotting/sensor package. | Skill curve reference; would need server plus both HCs if ever deployed. |
| `VFAI_ProjectV26_WithPW.7z` | complementary | Infantry smoke/equipment/drop-empty behavior package. | Smoke-when-hit and drop-empty are ideas; equipment scavenging overlaps ASR. |
| `RUG_DSAI_WithPW.7z` | complementary | AI voice/shout package. | Cosmetic only and large; low priority. |
| `TPW_AI_LOS_102_WithPW.7z` | skip-content | LOS/foliage detection script. | Borders on sim/detection gating; do not port under owner rules. |
| `glt_dynamic_ai_1.4_WithPW.7z` | complementary | Dynamic AI patrol director docs/package. | Lower priority than DAC. |
| PROPER FPS-reduction suite | novel | Client-side vegetation/clutter/shader reductions. | Optional-client FPS pack candidate; opt-in only due visual parity impact. |
| `@IHUD_WithPW.7z` | novel | Infantry HUD overlay. | Optional client QoL candidate after compatibility test. |
| `@unafov_WithPW.7z` | novel | FOV adjustment. | Optional client QoL candidate. |
| `AircraftHUD_v4_WithPW.7z` | novel | Aircraft HUD overlay. | Optional aircraft QoL candidate. |
| ACE/ACEX archives | skip-content | Total conversion content. | Out of scope for WASP V2. |
| Unit/weapon/island packs | skip-content | Bulk content archive rows. | Skip unless they contain mission scripts/config docs directly relevant to WASP. |

## Required Final Output Shape

When the Main PC sweep is complete, replace or extend the seed catalog with:

| Path | Tag | One-line description | Existing cross-reference | Novel value |
| --- | --- | --- | --- | --- |

Every distinct file/folder must have one row.

## Cross-References

- `docs/design/ARCHIVE-MINING.md`
- Wiki: `Archive-Script-Mining-V2`
- Wiki: `Miksuu-Upstream-Wiki-Import`
- Wiki: `Developer-History-And-Upstream-Lessons`
