#!/usr/bin/env python3
"""Regression contract for wave0804b FIX 2 (tooltip _itemname/_preview undefined-variable
RPT spam, regression from commit 942bb614ef).

RPT proved "Undefined variable in expression: _itemname" at coin_interface.sqf:873 and
a matching "_preview" undefined at :890, firing on placement-preview ticks. Both reads
must be isNil-guarded so no undefined-variable error can fire, while still preferring
the WFBE buy-menu label / live rotation readout whenever the variable IS in scope.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
COIN_INTERFACE = CHERNARUS / "Client" / "Module" / "CoIn" / "coin_interface.sqf"


def test_itemname_header_read_is_isnil_guarded_with_displayname_fallback() -> None:
    code = COIN_INTERFACE.read_text(encoding="utf-8-sig")

    header_idx = code.index(
        '_textHeader = format ["<t color=\'#42b6ff\' shadow=\'1\' align=\'center\' size=\'1.8\'> %1 </t><br />",'
    )
    guard_idx = code.index('(if (isNil "_itemname") then {""}', header_idx)
    else_branch_idx = code.index("else {_itemname})", guard_idx)

    assert header_idx < guard_idx < else_branch_idx, (
        "tooltip header must read _itemname through an isNil guard with an empty-string fallback"
    )

    # test_fortif_placement_preview_facing.py pins that commit 942bb614ef's WFBE-label
    # switch is never reverted - the stock CfgVehicles displayName lookup must not
    # reappear anywhere in the header format[] args.
    header_block_for_stock_check = code[header_idx : code.index("];", header_idx)]
    assert 'getText (configFile >> "cfgvehicles" >> _type >> "displayname")' not in header_block_for_stock_check

    # A bare, unguarded `_itemname,` argument (the pre-fix / regressed shape) must not
    # exist anywhere else in the header format[] call.
    header_block = code[header_idx : code.index("];", header_idx)]
    assert "\t\t\t\t\t\t_itemname, //" not in header_block


def test_rotate_readout_preview_read_is_isnil_guarded() -> None:
    code = COIN_INTERFACE.read_text(encoding="utf-8-sig")

    text1_idx = code.index('_text1 = if (count _params > 0) then {')
    guard_idx = code.index('!(isNil "_preview")', text1_idx)
    getdir_idx = code.index("round (getDir _preview)", guard_idx)

    assert text1_idx < guard_idx < getdir_idx, (
        "the rotate-readout's `getDir _preview` call must be reachable only after an "
        "isNil \"_preview\" guard on the same line"
    )


def test_wfbe_buy_menu_label_still_preferred_when_in_scope() -> None:
    """FIX 2 must not silently regress commit 942bb614ef's intent: when _itemname IS
    bound, the tooltip header must still show it (not unconditionally fall back)."""
    code = COIN_INTERFACE.read_text(encoding="utf-8-sig")
    header_idx = code.index(
        '_textHeader = format ["<t color=\'#42b6ff\' shadow=\'1\' align=\'center\' size=\'1.8\'> %1 </t><br />",'
    )
    header_block = code[header_idx : code.index("];", header_idx)]
    assert "else {_itemname}" in header_block


if __name__ == "__main__":
    test_itemname_header_read_is_isnil_guarded_with_displayname_fallback()
    test_rotate_readout_preview_read_is_isnil_guarded()
    test_wfbe_buy_menu_label_still_preferred_when_in_scope()
    print("coin tooltip _itemname/_preview undefined-variable guard regression check passed")
