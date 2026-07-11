# Wildcard Deck QA - 2026-07-02

Lane: `fleet-lane-63-wildcard-deck-qa-2026-07-02`
Branch: `codex/63-wildcard-deck-qa`
Base checked: `origin/claude/build84-cmdcon36@24604e9f7`
Scope: docs-first QA of the conventional AI commander wildcard deck, GUER wildcard deck, marker/announcement paths, and `UNUSED-ASSETS.md` alignment. No mission source was changed in this lane.

## Summary

The live conventional deck is mostly coherent at runtime. The removed cards are weight-zeroed, W8 is not reused, the newer visible combat cards W22/W23/W24 are active, and positional markers are side-local with cleanup watchers. The GUER wildcard worker is separate from the conventional deck and has its own eligibility gates, tax/toll resolution, FOB-token reward path, and cleanup.

The main issue found is W2 Supply Drop: it stays in the common draw pool even when side supply is already capped, then reports an ineligible/no-op result while the standard player announcement still says supply was delivered. The other issues are stale player-facing/help text and stale source/design inventory text around removed cards and deck totals.

## Findings

| ID | Severity | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| WC-QA-01 | P3 | W2 Supply Drop can consume a common draw at the side-supply cap and still announce a successful supply delivery. | W2 has weight 17 in the base table (`AI_Commander_Wildcard.sqf:507`) and there is no W2 eligibility zeroing in the ineligible-card block (`:530-551`). The apply block clamps the grant to `1500 min (_maxSupply - _supply)` and sets `_result = "ineligible"` when capped (`:623-635`). The later announcement is unconditional and maps W2 to `+1500 supply delivered to the front` (`:1514-1527`, `:1615-1627`). | Add a pre-draw W2 eligibility check such as side supply `< WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT` and zero `_wW2` when capped, or redraw/fallback when W2 becomes ineligible. If no redraw is desired, suppress the success wording when `_result != "applied"`. |
| WC-QA-02 | P3 | In-game wildcard help still advertises removed cards. | Briefing text says "veteran reinforcement companies" and "local uprisings" are random events (`briefing.sqf:172-174`). The redesigned help menu says "veteran companies, town uprisings, heliborne QRF and more" (`GUI_Menu_Help.sqf:165-166`). W7 Veteran Company and W9 Uprising are both weight 0 in the live table (`AI_Commander_Wildcard.sqf:508-509`). | Refresh player-facing wildcard copy after the in-flight wildcard source PRs settle. Current accurate examples would include heliborne QRF, Top Gun, Armor Column, Technical Swarm, and GUER car-bomb/checkpoint events. |
| WC-QA-03 | P3 | Source/design inventory text is stale against the live deck. | The source header still says deck total 123 and lists removed cards with nonzero weights (`AI_Commander_Wildcard.sqf:12-33`), then later says those same cards are removed (`:41-51`). It also says losing-side escalation doubles W4/W7/W9 (`:65`), but the runtime escalation adjusts W4/W6/W13/W19/W22/W23/W24 (`:517-527`). The header says the interval default is 1800 (`:74-75`), while constants set 900 seconds (`Init_CommonConstants.sqf:507-508`). `UNUSED-ASSETS.md` says the deck has 9 inert cards but lists 8 and omits retired W8 from that count (`UNUSED-ASSETS.md:20-23`, `:78-86`). | Treat the live weight table as source of truth and refresh the manifest/comment block plus `UNUSED-ASSETS.md`. Clarify whether "inert" means weight-zero apply blocks only, or also retired/absent slots like W8. |

## Verified Non-Findings

- Removed conventional cards are not draw-eligible on the checked base: W3, W7, W9, W10, W14, W17, W18, and W21 are forced to weight 0 (`AI_Commander_Wildcard.sqf:507-514`).
- W8 Motor Pool Delivery is retired and absent from the runtime weight table; W20 is appended as its own ID and does not reuse slot 8 (`AI_Commander_Wildcard.sqf:553-560`).
- Losing-side escalation applies only to currently live combat/helpful cards, including W22/W23/W24 (`AI_Commander_Wildcard.sqf:517-527`).
- Marker creation for conventional positional cards is gated on `_result == "applied"`, sent to the owning side object, and self-deletes after the event lifetime (`AI_Commander_Wildcard.sqf:1559-1611`). Pure economy/flag cards intentionally have no map marker (`:1552-1554`).
- The local marker PVF guards headless/dedicated/null player cases, validates array/string shape, recreates idempotently, and deletes only existing local markers (`WildcardMarker.sqf:20-54`).
- W17's old global supply-convoy marker is already removed in the inert apply block, avoiding an enemy-visible convoy leak if the card is ever revived (`AI_Commander_Wildcard.sqf:1081-1085`).
- Human-side wildcard announcements now route to the side object, not a side string, so clients can receive them through `Client_HandlePVF` (`AI_Commander_Wildcard.sqf:1620-1624`).
- `LocalizeMessage` has an explicit `Wildcard` passthrough case with command chat enabled (`LocalizeMessage.sqf:193-194`), and the PVF is registered with `WildcardMarker` (`Init_PublicVariables.sqf:44-45`).
- W11 Field Hospital's one-shot free-refound flag is consumed by the team-founding path before the price gate and skips the matching deduction once (`AI_Commander_Teams.sqf:928-935`, `:1039-1042`).
- W12 Spoils of War is consumed by the kill-bounty path while its missionNamespace expiry is active (`RequestOnUnitKilled.sqf:303-310`).
- W15 Black Market is consumed by the AI production path as a live 50 percent discount flag (`AI_Commander_Produce.sqf:452-457`).
- GUER wildcards zero their G1/G2 weights when no occupied towns or required classes exist, and exit cleanly when nothing is eligible (`AI_Commander_Wildcard_GUER.sqf:80-92`).
- GUER G1 car-bomb markers are side-restricted to resistance clients and cleaned by a watcher (`AI_Commander_Wildcard_GUER.sqf:151-166`).
- GUER G2 checkpoint resolution taxes the occupier while held, pays GUER tolls, rewards the occupier on clear, grants one tier-scaled FOB token on timeout, and cleans vehicle, crew, units, group, and marker (`AI_Commander_Wildcard_GUER.sqf:240-285`).
- Startup is split as expected: conventional wildcard workers start when AI commander wildcards and AI commander are enabled, while the GUER worker starts independently when GUER is present and enabled (`Init_Server.sqf:1205-1215`).

## Map/Tree Parity

Compared Chernarus mission files against `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` for wildcard-related paths.

- SHA-256 matched: `AI_Commander_Wildcard.sqf`, `AI_Commander_Wildcard_GUER.sqf`, `WildcardMarker.sqf`, `briefing.sqf`, `Init_CommonConstants.sqf`, `LocalizeMessage.sqf`, `AI_Commander_Teams.sqf`, `AI_Commander_Produce.sqf`, and `RequestOnUnitKilled.sqf`.
- Expected/non-wildcard delta: `Init_Server.sqf` differs only in the antistack map id (`SET_MAP` 1 vs 2).
- Help menu is intentionally not parity-matched: Chernarus carries the redesigned help controller, while `Missions_Vanilla` Takistan still has the legacy help content.

## Adjacent Open Work

- PR #287 (`fable/aicom-recon-drone-wildcard`) adds in-flight W25/W26 recon drone wildcard source work in `AI_Commander_Wildcard.sqf`; this lane avoided source edits there.
- PR #220 (`codex/lane149-wildcard-marker-popup`) is adjacent UI/explanation work for wildcard map markers.
- PR #212 (`codex/153-w20-cache-tier-text`) is adjacent text work for W20 support-tier naming.

## Verification

- Read project instructions (`CLAUDE.md`) and recent `JOURNAL.md` notes before work.
- Audited source against `origin/claude/build84-cmdcon36@24604e9f7`.
- Used `rg` line anchors plus targeted source excerpts for the evidence above.
- Compared Chernarus/Takistan vanilla wildcard-related file hashes as listed above.
- No mission source was edited, so `Tools/LoadoutManager/dotnet run` was not run.
- `git diff --check` passed before commit.

## Reconciliation 2026-07-11 (fleet-task wasp-wildcard-deck-doc-contract-reconcile)

Docs-only pass verifying WC-QA-03 against current `origin/master`. `AI_Commander_Wildcard.sqf` is now 1341 lines; anchors below refreshed from the 2026-07-02 snapshot. No mission source was edited in this lane.

- **WC-QA-03 still stands.** The `.sqf` source header comment block remains stale vs the live deck:
  - Live active deck (14 slots, base total 110): W1(17) W2(17) W4(6) W6(8) W11(8) W12(6) W13(6) W15(6) W16(6) W19(5) W20(6) W22(6) W23(7) W24(6) — `_weights` at `:622`, base weights `:567-575`.
  - Header top DECK table still reads `total=123` and lists removed W7/W14/W17/W18/W21 as active while omitting W22-24 (`:12-33`); only the REMOVED/ADDED sections below it (`:35-51`) reflect reality.
  - Header ESCALATION line still says "doubles W4/W7/W9" (`:65`); runtime escalation adjusts W4/W6/W13/W19/W22/W23/W24 (`:577-587`).
  - Header lists interval `default 1800` (`:75`, `:92`), but the live constant sets **900s** (`Init_CommonConstants.sqf:614`, "15 min faster testing cadence, 2026-06-14"). Purchased-draw cooldown is 1800s, active only when COST>0 (`:616`).
  - **Recommendation:** refresh the `.sqf` header comment block in a separate mission-edit lane (Python edit CH + LoadoutManager mirror + lint gate); out of scope for this docs-only task.
- **UNUSED-ASSETS.md corrected in this lane:** "9 inert cards" -> "8 weight-zeroed" + clarified W8 retired/absent (9 dead slots incl. the retirement) + noted W22-24 active. Resolves the WC-QA-03 count discrepancy.
- WC-QA-01 (W2 supply-cap announcement) and WC-QA-02 (stale player-facing help text) are unchanged and out of scope for this docs pass.
