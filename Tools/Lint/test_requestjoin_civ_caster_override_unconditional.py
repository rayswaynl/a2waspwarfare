#!/usr/bin/env python3
"""Regression contract for wave0804b FIX 4 (whitelisted caster kicked after faction
stint) - HELD, not applied.

PROVEN dead code (triage lane 3, verdict CONFIRMED): RequestJoin.sqf's CIV-caster
always-allowed override `if (_side == civilian) then {_canJoin = true};` sits INSIDE
`if (WF_A2_Vanilla) then {...}` (~lines 85-95), and WF_A2_Vanilla is a compile-time
`#ifdef VANILLA` flag (initJIPCompatible.sqf) that is FALSE on the deployed OA/CombinedOps
build - so the override never runs on live, and a caster who played a real faction
earlier in the session gets bounced to the lobby when re-joining the CIV seat.

This fix is INTENTIONALLY NOT APPLIED in this change. Server/PVFunctions/RequestJoin.sqf
is explicitly listed under CLAUDE.md's "Owner constraints" as a file agents must never
touch ("Never touch: HC architecture, player enrollment/JIP flow, deploy/box scripts.")
with no carve-out for correctness fixes, and Tools/Lint/test_commander_lease.py already
encodes an independent, dated owner ruling to the same effect (2026-07-21: "RequestJoin.sqf
- a JIP-flow file agents must never modify" / "RequestJoin.sqf is now pinned byte-identical
to its pre-C1 base"). The adversarial verifier on this exact lane independently reached the
same conclusion (fixRisk: "escalate rather than proceed on 'correctness fix' reasoning
alone"). See JOURNAL.md wave0804b entry for the ready-to-apply patch text, held pending
explicit fresh owner sign-off to override the standing ban.

This test is skipped (not failing, not silently absent) so CI stays green while making
the held state and the exact behavioral contract FIX 4 must satisfy, once authorized,
explicit and re-runnable.
"""

from __future__ import annotations

import pytest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
REQUEST_JOIN = CHERNARUS / "Server" / "PVFunctions" / "RequestJoin.sqf"

SKIP_REASON = (
    "FIX 4 held pending owner sign-off: RequestJoin.sqf is player-enrollment/JIP-flow, "
    "explicitly banned from agent edits by CLAUDE.md Owner constraints and by the dated "
    "2026-07-21 owner ruling already encoded in test_commander_lease.py "
    "(test_07b_requestjoin_is_untouched_jip_flow_file). See JOURNAL.md wave0804b entry."
)


@pytest.mark.skip(reason=SKIP_REASON)
def test_civ_override_runs_unconditionally_before_both_send_branches() -> None:
    """Once authorized: the CIV-always-allowed override must execute BEFORE the
    join-answer is sent, on BOTH the WF_A2_Vanilla and the live (else) branch - i.e.
    it must be textually outside (before) the `if (WF_A2_Vanilla) then {` block, not
    nested inside only one arm of it."""
    code = REQUEST_JOIN.read_text(encoding="utf-8-sig")

    override_idx = code.index("if (_side == civilian) then {_canJoin = true};")
    vanilla_gate_idx = code.index("if (WF_A2_Vanilla) then {")
    send_to_clients_idx = code.index('"join-answer"', vanilla_gate_idx)
    else_branch_idx = code.index("} else {", vanilla_gate_idx)
    send_to_client_idx = code.index('"join-answer"', else_branch_idx)

    # The override must run before the gate opens at all (unconditional), and
    # therefore before both send call sites.
    assert override_idx < vanilla_gate_idx
    assert override_idx < send_to_clients_idx
    assert override_idx < send_to_client_idx


@pytest.mark.skip(reason=SKIP_REASON)
def test_civ_override_comment_explains_why_it_was_hoisted() -> None:
    """Once authorized: the hoisted override must carry a comment naming
    WF_A2_Vanilla as a compile-time #ifdef VANILLA flag that is false on OA/CO,
    so a future reader doesn't renest it "for tidiness"."""
    code = REQUEST_JOIN.read_text(encoding="utf-8-sig")
    override_idx = code.index("if (_side == civilian) then {_canJoin = true};")
    preceding_comment = code[max(0, override_idx - 800) : override_idx]
    assert "WF_A2_Vanilla" in preceding_comment
    assert "ifdef VANILLA" in preceding_comment or "initJIPCompatible" in preceding_comment


if __name__ == "__main__":
    print(
        "FIX 4 (RequestJoin.sqf CIV caster override) tests are HELD/skipped - "
        "see JOURNAL.md wave0804b entry for the pending owner-authorization gate."
    )
