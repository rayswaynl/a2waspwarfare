# AI Commander Donation Double-Debit Audit - 2026-07-03

Lane: fleet lane 76, G6
Base checked: `origin/claude/build84-cmdcon36@b1608b096`

## Scope

The fleet prompt flags the AI Commander donation path as a double-debit risk:
`GUI_TransferMenu.sqf` and `RequestAIComDonate.sqf` both used to debit the
donor when a player transferred money to the AI commander wallet.

This pass checks the current target across the three maintained roots:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad`

No mission source, generated mirror output, live runtime settings, package
artifacts, wallet values, or donation defaults are changed here.

## Verdict

Lane 76 is already fixed on the current target.

The AI Commander row in `GUI_TransferMenu.sqf` no longer performs an optimistic
client-side debit. It sends one `RequestAIComDonate` request to the server and
refreshes the local funds display. The normal player-to-player transfer branch
still debits and credits locally, but that is a separate branch from the AI
Commander donation row.

`RequestAIComDonate.sqf` is now the single authority for the AI Commander
donation transfer. On success it debits the donor team once with
`ChangeTeamFunds`, credits the AI commander wallet once with
`ChangeAICommanderFunds`, confirms to the donor, broadcasts the donation, and
logs the wallet-after value.

The historical double-debit was fixed by `1e401fb07`:

`fix(econ): AI-commander donate double-debited the donor team (E2)`

## Evidence Table

| Surface | Evidence | Result |
| --- | --- | --- |
| AI Commander UI branch | `Client/GUI/GUI_TransferMenu.sqf:85-92` documents that the server is authoritative and the client-side optimistic debit was removed. The branch sends `["RequestAIComDonate", [player, clientTeam, _funds_transfering]]` and refreshes `_funds`. | The AI Commander row does not debit locally. |
| Normal transfer branch | `Client/GUI/GUI_TransferMenu.sqf:99-103` still handles ordinary player-to-player transfers with `ChangeClientFunds`, `ChangeTeamFunds`, and a recipient message. | The remaining local debit belongs to a different branch, not the AI Commander donation path. |
| Server validation | `Server/PVFunctions/RequestAIComDonate.sqf:39-69` rejects non-positive amounts, missing side logic, human commanders, and insufficient donor-team funds. | The transfer is checked at execution time on the server. |
| Server transfer | `Server/PVFunctions/RequestAIComDonate.sqf:72-76` reads the current AI wallet, debits `[_donorTeam, -_amount] Call ChangeTeamFunds`, then credits `[_side, _amount] Call ChangeAICommanderFunds`. | Exactly one donor debit and one AI-wallet credit are performed for the AI Commander path. |
| Feedback and telemetry | `Server/PVFunctions/RequestAIComDonate.sqf:80-94` confirms to the donor, broadcasts `AIComDonation`, emits a greppable `[DONATION]` log, and writes an `AICOMSTAT|v2|EVENT|...|DONATION|...|wallet_after=` line. | The server-side transfer is visible to the donor, teammates, logs, and balance telemetry. |
| Fix lineage | `git log -S"client-side optimistic debit was REMOVED"` points to `1e401fb07`. | The current target includes the named E2 fix for the double-debit bug. |

## Out Of Scope

This audit is distinct from lane 140's live-player donor validation work. The
current target proves the double-debit bug is fixed, but this document does not
claim that every possible forged donor/requester shape is fully closed.

This audit also does not change AI commander wallet balance, donation limits,
team-funds semantics, or the normal player-to-player funds transfer branch.

## Verification

- `rg` confirmed the AI Commander UI branch in all three roots sends only
  `RequestAIComDonate` and documents the removed optimistic debit.
- `rg` confirmed the remaining `ChangeClientFunds` and `ChangeTeamFunds` calls
  in `GUI_TransferMenu.sqf` are in the normal player-to-player branch, not the
  AI Commander donation branch.
- `rg` confirmed `RequestAIComDonate.sqf` performs one donor-team debit and one
  AI commander wallet credit in Chernarus, Takistan, and Zargabad.
- `git log -S` confirmed the current target carries the `1e401fb07` E2 fix
  lineage for the removed optimistic debit.
- `git diff --no-index` confirmed Chernarus/Takistan parity for both checked
  donation files; Chernarus/Zargabad parity was checked the same way.
- This PR is docs-only. LoadoutManager was not run because no mission source or
  generated mirror source changed.
