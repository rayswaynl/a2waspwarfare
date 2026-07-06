# Lane 326 - AICOM Arty Request Cooldown No-Change Audit

<!-- GUIDE-REV: GR-2026-07-03a -->

## Verdict

No mission source change is warranted on current `claude/build84-cmdcon36`.

The lane 326 prompt describes a stale path where a fresh player artillery request is cleared even when no artillery piece fires, but `wfbe_aicom_arty_last` is not updated. Current Build84 already stamps `wfbe_aicom_arty_last` at the fresh-request clear point, so the next normal cadence tick cannot treat the unstamped default as an expired cooldown and fire a free salvo.

This PR is intentionally docs-only because `AI_Commander_Strategy.sqf` is hot under multiple open Build84 PRs, and the current base already contains the guard this lane asks for.

## Source Evidence

Checked base: `origin/claude/build84-cmdcon36@4910fc3f5fb5657feee6b554d700155f3a827092`.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf`:

- Lines 1052-1063 read `wfbe_aicom_arty_request`, validate `[pos, time]`, and set `_riArtyFresh = true` only while the request is fresh.
- Line 1066 lets a fresh player request bypass the ordinary artillery cooldown gate.
- Line 1072 overrides the automatic target with `_riArtyPos` when `_riArtyFresh` is true.
- Line 1095 stamps `wfbe_aicom_arty_last` on the normal fired path.
- Lines 1106-1111 clear every fresh player request and, crucially, stamp `wfbe_aicom_arty_last` at the request-clear point even if `_fired` never became true.

The maintained mirrors are byte-identical for this file:

```text
CH AI_Commander_Strategy.sqf sha256 7CB2531D0943FEE3E4F4962CAFAC3033790349E518B1BB996A1978E148C12F62
TK AI_Commander_Strategy.sqf sha256 7CB2531D0943FEE3E4F4962CAFAC3033790349E518B1BB996A1978E148C12F62
ZG AI_Commander_Strategy.sqf sha256 7CB2531D0943FEE3E4F4962CAFAC3033790349E518B1BB996A1978E148C12F62
```

## Why This Closes The Prompted Bug

The risky sequence would be:

1. A player submits a fresh AICOM artillery request.
2. `_riArtyFresh` bypasses the normal cooldown gate.
3. No piece is in range, no gunner is alive, or no friendly-town support condition passes.
4. The request is consumed.
5. The next cadence tick sees `wfbe_aicom_arty_last` still at the old/default value and fires without a fresh player request.

Current Build84 breaks that sequence at step 4:

```sqf
if (_riArtyFresh) then {
    _logik setVariable ["wfbe_aicom_arty_request", []];
    _logik setVariable ["wfbe_aicom_arty_last", time];
};
```

That stamp is independent of whether an artillery piece actually fired. The no-gun path still consumes the request and advances the cooldown timer.

## Collision Check

The exact lane was free before claim:

- No open PR title or branch matched lane326 / artillery request cooldown.
- No remote branch matched `lane326`, `arty-request`, or this request-clear cooldown path.
- Wiki and Game PC brain scans found no exact `fleet-lane-326-*` owner.

The target Strategy file is not safe for a source edit right now. Current open Build84 PRs touching `AI_Commander_Strategy.sqf` include #607, #605, #604, #594, #592, #581, and #328. This audit therefore avoids SQF churn and leaves those source owners undisturbed.

## Validation

- Re-read the current Build84 `AI_Commander_Strategy.sqf` player artillery request block.
- Confirmed the request-clear path includes both `wfbe_aicom_arty_request` clearing and `wfbe_aicom_arty_last` stamping.
- Confirmed Chernarus, Takistan, and Zargabad Strategy mirrors have matching SHA256 values.
- Confirmed this PR changes only this documentation file.

No LoadoutManager run is needed because no mission source or generated mirror file changed.
