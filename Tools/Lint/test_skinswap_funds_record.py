#!/usr/bin/env python3
"""Regression contract for skin-swap wallet reconciliation.

The skin-swap client can land in a fresh fallback group.  That group must be
reconciled by the server's JIP-wallet path; a client-side carried snapshot is
not allowed to become a second wallet truth without updating WFBE_JIP_USER.
"""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
SKIN_RELATIVE = Path("WASP/actions/SkinSelector/SkinSelector_Apply.sqf")


def test_skin_swap_defers_fallback_wallet_to_server_record_reconciliation() -> None:
    """A carried client snapshot must not overwrite the group-only wallet copy."""
    for terrain in TERRAINS:
        source = mask_comments(
            (ROOT / terrain / SKIN_RELATIVE).read_text(encoding="utf-8-sig")
        )
        start = source.index("_curGrp = group player;")
        end = source.index("if (!(isNull commanderTeam)) then {", start)
        wallet_block = source[start:end]

        assert 'RequestFundsResend", [player, WFBE_Client_SideJoined]' in wallet_block
        assert '_curGrp setVariable ["wfbe_funds", _carryFunds, true]' not in wallet_block


if __name__ == "__main__":
    test_skin_swap_defers_fallback_wallet_to_server_record_reconciliation()
    print("Skin-swap funds-record regression check passed")
