# ASR AI Server-FPS Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply a conservative, behavior-near-identical ASR AI tuning (Profile A) to claw back dedicated-server FPS in the June WASP Warfare modpack, version-control the previously-untracked config, document it, and add a forward-looking modpack-integration item to the waspwarfare-next backlog.

**Architecture:** ASR AI 1.16.0.40 reads every setting from a plaintext `#include` (`userconfig\ASR_AI\asr_ai_settings.hpp`); the shipped `.pbo` carries no defaults, so tuning is a two-value text edit — no PBO repack, no signature break. The config becomes version-controlled in the legacy repo (alongside `BattlEyeFilter/`), is deployed to the local Steam install, documented in the `miksuus-warfare` guides, and seeds a `Theme G` backlog item in the rebuild.

**Tech Stack:** Arma 2 OA addon config (`.hpp`), MDX docs (Next.js content), Markdown backlog. No build/test toolchain — verification is text assertions + the rebuild's two PowerShell validators.

**Spec:** `a2waspwarfare/docs/superpowers/specs/2026-06-09-asr-ai-server-fps-tuning-design.md`

**Profile A (locked):** `radiorange 500→300`, `buildingSearching 0.7→0.5`. Everything else unchanged. Keep-list (do NOT touch): `serverdvd=1`, `join_loners=1`, `setskills=1`, `sys_airearming.feature=0`, all debug flags `0`, the `sets`/`factions` blocks.

**Commit policy:** Files are written but **NOT committed** until Steff approves (global rule). All commit commands are gathered in Task 6 and must wait for explicit go-ahead. The rebuild repo (`a2waspwarfare-next`) has its own binding protocol — see Task 5/6.

---

## File Structure

| Path | Repo / target | Responsibility |
|------|---------------|----------------|
| `<a2waspwarfare>\server-config\userconfig\ASR_AI\asr_ai_settings.hpp` | legacy repo (`master`) — **create** | Canonical, version-controlled tuned config (source of truth) |
| `<a2waspwarfare>\server-config\userconfig\README.md` | legacy repo — **create** | Deploy/revert instructions + server-not-client rationale |
| `C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\userconfig\ASR_AI\asr_ai_settings.hpp` | local Steam install — **overwrite** | Deployed copy for local playtests (`.bak` beside it is untouched) |
| `<miksuus-warfare>\web\content\guides\performance.mdx` | miksuus-warfare — **modify** | Add "ASR AI tuning (server-side)" section |
| `<miksuus-warfare>\web\content\guides\mods-and-modpack.mdx` | miksuus-warfare — **modify** | Add server-side tuning pointer |
| `<a2waspwarfare-next>\docs\codex-work-order.md` | rebuild repo (`main`) — **modify** | Add `Theme G` / `G1` modpack-integration backlog item |

---

### Task 1: Create the canonical version-controlled config (with Profile A applied)

**Files:**
- Create: `<a2waspwarfare>\server-config\userconfig\ASR_AI\asr_ai_settings.hpp`
- Source: `C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\userconfig\ASR_AI\asr_ai_settings.hpp`

- [ ] **Step 1: Copy the current live config into the repo as an exact baseline**

```powershell
$src = "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\userconfig\ASR_AI\asr_ai_settings.hpp"
$dst = "<a2waspwarfare>\server-config\userconfig\ASR_AI\asr_ai_settings.hpp"
New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
Copy-Item -Path $src -Destination $dst -Force
```

- [ ] **Step 2: Verify the baseline copy is byte-identical to the source**

```powershell
if ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash) { "MATCH" } else { "MISMATCH" }
```
Expected: `MATCH`

- [ ] **Step 3: Confirm the pre-change values (sanity before editing)**

```powershell
Select-String -Path $dst -Pattern 'radiorange = 500;','buildingSearching = 0.7;','sys_airearming','feature = 0;' | Select-Object LineNumber, Line
```
Expected: shows `radiorange = 500;`, `buildingSearching = 0.7;`, and the existing `feature = 0;` (rearming already off). If `radiorange` is not 500 or `buildingSearching` not 0.7, STOP — the live file already diverged; reconcile with Steff before proceeding.

- [ ] **Step 4: Edit value 1 — `radiorange` 500 → 300** (use the Edit tool on the repo copy `$dst`)

old_string:
```
radiorange = 500;              // Maximum range for radios
```
new_string:
```
radiorange = 300;              // Maximum range for radios  [WASP perf 2026-06-09] 500->300: shrink radio-net fan-out (group-count-scaling cost)
```

- [ ] **Step 5: Edit value 2 — `buildingSearching` 0.7 → 0.5** (Edit tool on `$dst`)

old_string:
```
buildingSearching = 0.7;       // Chance the AI group will search nearby buildings when in combat mode (0 to 1 values, 0 will disable the feature)
```
new_string:
```
buildingSearching = 0.5;       // Chance the AI group will search nearby buildings when in combat mode (0 to 1 values, 0 will disable the feature)  [WASP perf 2026-06-09] 0.7->0.5: reduce CQB pathfinding
```

- [ ] **Step 6: Add a provenance comment block** (Edit tool on `$dst`)

old_string:
```
class asr_ai {
```
new_string:
```
/*
 WASP Warfare perf tuning — Profile A (Conservative), 2026-06-09:
   sys_airearming.feature = 0       (AI rearming scan loop off; pre-existing)
   sys_aiskill.radiorange = 300     (was 500; shrink radio-net fan-out)
   sys_aiskill.buildingSearching = 0.5 (was 0.7; reduce CQB pathfinding)
 KEEP-LIST (do not change for FPS): serverdvd=1, join_loners=1, setskills=1, debug flags=0, sets/factions.
 Effect is server-side: deploy to the dedicated server + headless client (AI is local there), not players.
 Revert: asr_ai_settings.hpp.bak beside the deployed copy.
 Canonical source: a2waspwarfare/server-config/userconfig/ASR_AI/asr_ai_settings.hpp
*/
class asr_ai {
```

- [ ] **Step 7: Verify the edits landed and nothing else changed**

```powershell
$dst = "<a2waspwarfare>\server-config\userconfig\ASR_AI\asr_ai_settings.hpp"
Select-String -Path $dst -Pattern 'radiorange = 300;','buildingSearching = 0.5;','WASP Warfare perf tuning' | Select-Object Line
# Confirm the keep-list is intact:
Select-String -Path $dst -Pattern 'serverdvd = 1;','join_loners = 1;','setskills = 1;','feature = 0;','version = 6;' | Select-Object Line
# Confirm no stray reversion of the old values:
if (Select-String -Path $dst -Pattern 'radiorange = 500;','buildingSearching = 0.7;' -Quiet) { "ERROR: old values still present" } else { "OK: old values replaced" }
```
Expected: new values + provenance present; keep-list all present; `OK: old values replaced`.

---

### Task 2: Deploy the tuned config to the local Steam install

**Files:**
- Overwrite: `C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\userconfig\ASR_AI\asr_ai_settings.hpp`
- Must NOT touch: the `asr_ai_settings.hpp.bak` beside it (stock revert point).

- [ ] **Step 1: Confirm the stock `.bak` exists (revert safety) before overwriting**

```powershell
Test-Path "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\userconfig\ASR_AI\asr_ai_settings.hpp.bak"
```
Expected: `True`. If `False`, first make one: `Copy-Item $src "$src.bak"` (where `$src` is the live `.hpp`) so a revert path exists.

- [ ] **Step 2: Deploy the canonical repo copy over the live file**

```powershell
$repo = "<a2waspwarfare>\server-config\userconfig\ASR_AI\asr_ai_settings.hpp"
$live = "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\userconfig\ASR_AI\asr_ai_settings.hpp"
Copy-Item -Path $repo -Destination $live -Force
```
Note: if this errors with access-denied, re-run the copy in an elevated PowerShell (Steam common dir occasionally needs admin).

- [ ] **Step 3: Verify the live file now matches the repo canonical and the `.bak` is unchanged**

```powershell
$repo = "<a2waspwarfare>\server-config\userconfig\ASR_AI\asr_ai_settings.hpp"
$live = "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\userconfig\ASR_AI\asr_ai_settings.hpp"
if ((Get-FileHash $repo).Hash -eq (Get-FileHash $live).Hash) { "LIVE MATCHES REPO" } else { "MISMATCH" }
Select-String -Path "$live.bak" -Pattern 'radiorange = 500;' -Quiet  # bak should still hold stock value
```
Expected: `LIVE MATCHES REPO`, and the `.bak` check returns `True` (stock 500 preserved).

---

### Task 3: Write the server-config deploy README

**Files:**
- Create: `<a2waspwarfare>\server-config\userconfig\README.md`

- [ ] **Step 1: Create the README with deploy + revert instructions**

Write this exact content to the file:

```markdown
# Server userconfig — ASR AI tuning

This folder holds the version-controlled ASR AI settings used by the WASP Warfare modpack
(`@adwasp` bundles ASR AI 1.16.0.40). ASR AI reads everything from
`ASR_AI/asr_ai_settings.hpp`; the shipped `asr_ai_settings.pbo` only `#include`s it, so this
is a plain-text tune — no PBO repack, no signature change.

## Why this is server-side

ASR AI's behaviour scripts run wherever the AI units are *local*. In this CTI/Warfare mission
that is the **dedicated server and the headless client(s)** — not individual players. Tuning
therefore takes effect from the **server's** copy of this file. Shipping it in the player
modpack zip does almost nothing for server FPS (a player's copy only affects AI in their own
group).

## Current tune — Profile A (Conservative, 2026-06-09)

- `sys_airearming.feature = 0` — rearming scan loop off (pre-existing).
- `sys_aiskill.radiorange = 300` (was 500) — smaller radio-net that shares enemy positions
  between AI groups (the cost that scales worst with group count).
- `sys_aiskill.buildingSearching = 0.5` (was 0.7) — AI clears buildings less often
  (expensive pathfinding).

Untouched on purpose (these help FPS or are init-only): `serverdvd`, `join_loners`,
`setskills`, the skill `sets`/`factions` blocks.

## Deploy

1. Copy `ASR_AI\asr_ai_settings.hpp` to the Arma 2 OA install on the **dedicated server** and
   each **headless client**, at: `<Arma 2 OA>\userconfig\ASR_AI\asr_ai_settings.hpp`.
2. Restart the server / HC.

> Production server host: _TODO — fill in once confirmed._

## Revert

Each install keeps a stock `asr_ai_settings.hpp.bak` beside the live file. To revert, copy the
`.bak` back over `asr_ai_settings.hpp` and restart.
```

- [ ] **Step 2: Verify the file exists and is non-empty**

```powershell
Get-Item "<a2waspwarfare>\server-config\userconfig\README.md" | Select-Object Length
```
Expected: a non-zero `Length`.

---

### Task 4: Update the miksuus-warfare guides

**Files:**
- Modify: `<miksuus-warfare>\web\content\guides\performance.mdx`
- Modify: `<miksuus-warfare>\web\content\guides\mods-and-modpack.mdx`

- [ ] **Step 1: Read both files** to confirm the anchor lines are still present (they were captured 2026-06-09 — if the surrounding text shifted, re-anchor on the same quoted sentence).

- [ ] **Step 2: Add the ASR AI section to `performance.mdx`** (Edit tool)

old_string:
```
If the game is *crashing* or *freezing* rather than just running slow, use [Troubleshooting](/guides/troubleshooting).
```
new_string:
```
## ASR AI tuning (server-side)

ASR AI (bundled in `@adwasp`) is the one mod that costs **server** frames. Its AI scripts run where the AI is *local* — in this CTI mission that's the **dedicated server + headless client**, not your PC. So this tuning reduces server desync for everyone, but it only takes effect on the **server install**, not the player modpack.

All settings live in a plain-text file — `…\Arma 2 Operation Arrowhead\userconfig\ASR_AI\asr_ai_settings.hpp` (no PBO repack). The server ships a conservative tune:

- `sys_airearming.feature = 0` — AI rearming scan loop off.
- `radiorange = 300` (was 500) — shrinks the radio-net that shares enemy positions between AI groups (the cost that scales worst with group count).
- `buildingSearching = 0.5` (was 0.7) — AI clears buildings a little less often (expensive pathfinding).

Server admins: deploy the tuned `userconfig\ASR_AI\asr_ai_settings.hpp` to the server and headless-client installs and restart. Revert via the `.bak` beside it.

If the game is *crashing* or *freezing* rather than just running slow, use [Troubleshooting](/guides/troubleshooting).
```

- [ ] **Step 3: Add the pointer in `mods-and-modpack.mdx`** (Edit tool)

old_string:
```
- **ASR AI** (inside `@adwasp`) can also lower FPS, especially on lower-end systems.
```
new_string:
```
- **ASR AI** (inside `@adwasp`) can also lower FPS, especially on lower-end systems. Most of its cost is **server-side** — server admins can tune it in `userconfig\ASR_AI\asr_ai_settings.hpp` (see [Performance](/guides/performance)).
```

- [ ] **Step 4: Verify both edits**

```powershell
Select-String -Path "<miksuus-warfare>\web\content\guides\performance.mdx" -Pattern 'ASR AI tuning \(server-side\)','radiorange = 300' | Select-Object Line
Select-String -Path "<miksuus-warfare>\web\content\guides\mods-and-modpack.mdx" -Pattern 'Most of its cost is' | Select-Object Line
```
Expected: both patterns found.

---

### Task 5: Add the modpack-integration backlog item to waspwarfare-next

**Files:**
- Modify: `<a2waspwarfare-next>\docs\codex-work-order.md`

> The rebuild repo has a binding protocol (`a2waspwarfare-next/CLAUDE.md`): claim-before-build, explicit-path commits with a `claude:` prefix, run both validators, never edit the legacy repo from here. A docs-only backlog addition is low-risk, but the commit must still follow that protocol (handled in Task 6). This task only writes the text.

- [ ] **Step 1: Add `Theme G` immediately before section 4** (Edit tool)

old_string:
```
# 4. Coordination & sequencing
```
new_string:
```
## Theme G — Modpack compatibility & integration (forward-looking; not part of baseline parity)

### G1. Officially support + integrate the current player modpack (MEDIUM)
**What:** Make the rebuild a first-class citizen of the live player modpack (`@CBA_CO;@JSRS1.5;@adwasp;@admkswf;@Blastcore_Visuals_R1.2`) without taking a hard mod dependency. Three sub-parts: (a) a compatibility matrix stating which mods are drop-in (CBA/JSRS/Blastcore/admkswf) vs. content the legacy experience relied on (the `@adwasp` WASP weapon/vehicle configs); (b) decide whether to absorb the zero-cost WASP content vanilla-side (script/config) or keep it as an optional companion addon, so a vanilla server still runs but a modded server gets the full experience; (c) ship sane ASR AI performance defaults from the mission itself via a `description.ext` `class asr_ai` (or `init.sqf` globals), so any server running ASR AI inherits the tuned values without relying on each operator's userconfig.
**Why:** The rebuild must still run vanilla (charter), but the community actually plays with the modpack. ASR AI is the only mod with real server-FPS cost, and the ASR AI userconfig header documents that its `asr_ai_*` globals can be set from `init.sqf` / `description.ext` — so perf defaults can be driven mission-side and survive any operator's userconfig. The WASP weapon content is config-only (zero runtime cost), so supporting it is low-risk. Reference: the June 2026 legacy ASR AI server-FPS tuning (Profile A: `radiorange 500→300`, `buildingSearching 0.7→0.5`).
**Approach:** Keep the mission vanilla-runnable (no mod entries in `mission.sqm` `addOns[]`). Add an optional `class asr_ai` block to `description.ext`, guarded so it is a harmless no-op when ASR AI is not loaded. Document the modpack compatibility matrix in `docs/`. Defer actual content-absorption (WASP weapons) to a follow-up — this item only establishes support + perf defaults + the matrix.
**Acceptance + validation:** Mission still loads and plays on vanilla Arma 2 OA 1.64 (no new hard deps); `mission.sqm` `addOns[]` gains no mod entries (validator-checkable). With the modpack loaded, ASR AI reads the mission-provided perf defaults (verify a tuned value resolves from the mission). Compatibility matrix doc committed. Both validators pass.
**Status (2026-06-09):** PROPOSED — backlog only; not started. Forward-looking item; sequence after Theme A baseline parity.

# 4. Coordination & sequencing
```

- [ ] **Step 2: Verify the entry landed in place**

```powershell
Select-String -Path "<a2waspwarfare-next>\docs\codex-work-order.md" -Pattern '## Theme G','### G1\.','# 4\. Coordination' | Select-Object LineNumber, Line
```
Expected: `Theme G` and `G1.` appear immediately before `# 4. Coordination & sequencing` (ascending line numbers, G1 just above section 4).

---

### Task 6: Final verification, then commit ONLY on Steff's go-ahead

**Files:** all of the above, across three repos. No `git add -A` anywhere — explicit paths only.

- [ ] **Step 1: Cross-repo final review** — re-read each changed file once more; confirm the spec's keep-list is intact in the `.hpp`, the guides render (no broken MDX — balanced backticks/brackets), and the backlog entry sits inside section 3's theme list.

- [ ] **Step 2: Show pending changes per repo (review before any commit)**

```powershell
git -C "<a2waspwarfare>" status --short
git -C "<miksuus-warfare>" status --short
git -C "<a2waspwarfare-next>" status --short
```
Expected: legacy repo shows the new `server-config/...` files + `docs/superpowers/...`; miksuus-warfare shows the two guide edits; rebuild shows only `docs/codex-work-order.md`.

- [ ] **Step 3: PAUSE — ask Steff for commit approval.** Do not proceed without an explicit "yes, commit". Commits are deferred per the global rule.

- [ ] **Step 4 (on approval): Run the rebuild validators before its commit** (required by `a2waspwarfare-next/CLAUDE.md`)

```powershell
cd "<a2waspwarfare-next>"
.\tools\validate-private-repo.ps1
.\tools\validate-mission-source.ps1
git diff --check
```
Expected: both validators pass; `git diff --check` clean. A docs-only edit should not affect either — if a validator fails, investigate before committing.

- [ ] **Step 5 (on approval): Commit each repo with explicit paths**

```powershell
# Legacy repo (branch master) — config + spec + plan + README
git -C "<a2waspwarfare>" add `
  "server-config/userconfig/ASR_AI/asr_ai_settings.hpp" `
  "server-config/userconfig/README.md" `
  "docs/superpowers/specs/2026-06-09-asr-ai-server-fps-tuning-design.md" `
  "docs/superpowers/plans/2026-06-09-asr-ai-server-fps-tuning.md"
git -C "<a2waspwarfare>" commit -m "perf(asr-ai): conservative server-FPS tune (radiorange 500->300, buildingSearching 0.7->0.5) + version-control userconfig"

# miksuus-warfare — guide docs
git -C "<miksuus-warfare>" add `
  "web/content/guides/performance.mdx" `
  "web/content/guides/mods-and-modpack.mdx"
git -C "<miksuus-warfare>" commit -m "docs(guides): document server-side ASR AI tuning"

# Rebuild repo (branch main) — explicit path, claude: prefix (per its protocol)
git -C "<a2waspwarfare-next>" add "docs/codex-work-order.md"
git -C "<a2waspwarfare-next>" commit -m "claude: backlog G1 - official modpack compatibility + integration (forward-looking)"
```
Note: do NOT push. Pushing is a separate explicit request.

- [ ] **Step 6: Report** — summarize what changed, the deferred deploy-to-production-server step (host still TODO), and that nothing was pushed.

---

## Self-Review

**1. Spec coverage:**
- Component 1 (Profile A two-value change) → Task 1 (Steps 4–5) ✓
- Component 1 keep-list integrity → Task 1 Step 7 (asserts keep-list present) ✓
- Component 2 (version-control the file) → Task 1 (create in repo) + Task 6 commit ✓
- Component 2 (apply to local install) → Task 2 ✓
- Component 3 (deployment note, server-not-client, host TODO) → Task 3 README + Task 6 Step 6 ✓
- Component 4 (miksuus-warfare guides) → Task 4 ✓
- Component 5 (waspwarfare-next roadmap entry, vanilla-policy framing) → Task 5 ✓
- Validation = syntax/value asserts, no in-engine benchmark → verification steps throughout; no engine run ✓

**2. Placeholder scan:** The only "TODO" is the production server host — that is an explicit, owner-supplied open item from the spec (not a plan gap), surfaced in Task 3 and Task 6 Step 6. No "implement later"/"add error handling"/vague steps. All edit content is literal old/new strings.

**3. Type/string consistency:** New values `radiorange = 300` / `buildingSearching = 0.5` and the provenance tag `[WASP perf 2026-06-09]` are identical across Task 1, Task 3 README, Task 4 docs, and Task 5 reference. Anchor strings match the files as read on 2026-06-09. Canonical path `server-config/userconfig/ASR_AI/asr_ai_settings.hpp` is identical in every reference.

**Note on dependencies:** Task 2 depends on Task 1 (repo copy is the deploy source). Task 6 depends on all. Tasks 3, 4, 5 are independent of each other and of Task 2 — they may run in any order after Task 1.
