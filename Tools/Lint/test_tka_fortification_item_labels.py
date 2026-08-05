#!/usr/bin/env python3
"""Regression contract for wave0804b FIX 1b (TKA empty-label Fortification items).

TK_WarfareBBarrier5x_EP1 / TK_WarfareBBarrier10x_EP1 / TK_WarfareBBarrier10xTall_EP1
and (WFBE_C_DEFMENU_V2-recategorised) Land_CamoNet_EAST_EP1 / Land_CamoNetVar_EAST_EP1 /
Land_CamoNetB_EAST_EP1 were registered in Core_TKA.sqf with an empty label (''), which
made coin_interface.sqf fall back to the raw stock CfgVehicles displayName for these
TKA/EAST-exclusive classnames (Core_TKA.sqf is their sole registration - confirmed no
'Duplicated Element' RPT entry shadows them from Core_CIV.sqf). Giving them real,
apostrophe-free labels removes the stock-fallback pathway for these six items entirely,
independent of FIX 1a's sanitize.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
CORE_TKA = CHERNARUS / "Common" / "Config" / "Core" / "Core_TKA.sqf"

TARGET_CLASSNAMES = [
    "TK_WarfareBBarrier5x_EP1",
    "TK_WarfareBBarrier10x_EP1",
    "TK_WarfareBBarrier10xTall_EP1",
    "Land_CamoNet_EAST_EP1",
    "Land_CamoNetVar_EAST_EP1",
    "Land_CamoNetB_EAST_EP1",
]


def _extract_label(code: str, classname: str) -> str:
    """Find `_c = _c + ['<classname>'];` then read the first string literal of the
    very next `_i = _i + [[...]];` item-array append - that first element is the
    QUERYUNITLABEL slot (confirmed via Init_Coin.sqf: `_d select QUERYUNITLABEL`
    reads index 0 of this same per-item array)."""
    class_idx = code.index(f"_c = _c + ['{classname}'];")
    item_idx = code.index("_i = _i + [[", class_idx)
    # The label is the first quoted (single-quote) token after the opening [[.
    match = re.match(r"_i = _i \+ \[\['([^']*)'", code[item_idx : item_idx + 200])
    assert match, f"could not parse item-array label for {classname}"
    return match.group(1)


def test_all_six_tka_fortification_items_have_nonempty_labels() -> None:
    code = CORE_TKA.read_text(encoding="utf-8-sig")
    for classname in TARGET_CLASSNAMES:
        label = _extract_label(code, classname)
        assert label != "", f"{classname} still has an empty label - stock displayName fallback is still live"


def test_all_six_tka_fortification_labels_are_apostrophe_and_quote_free() -> None:
    code = CORE_TKA.read_text(encoding="utf-8-sig")
    for classname in TARGET_CLASSNAMES:
        label = _extract_label(code, classname)
        assert "'" not in label, f"{classname} label {label!r} contains an apostrophe"
        assert '"' not in label, f"{classname} label {label!r} contains a double-quote"


def test_all_six_tka_fortification_items_still_registered_as_fortification_or_gated() -> None:
    """The relabel must not have touched the category field (index 6) - Fortification,
    or (for the camo nets) the WFBE_C_DEFMENU_V2 gated Fortification/Strategic switch."""
    code = CORE_TKA.read_text(encoding="utf-8-sig")
    for classname in ("TK_WarfareBBarrier5x_EP1", "TK_WarfareBBarrier10x_EP1", "TK_WarfareBBarrier10xTall_EP1"):
        class_idx = code.index(f"_c = _c + ['{classname}'];")
        item_idx = code.index("_i = _i + [[", class_idx)
        item_line_end = code.index("\n", item_idx)
        assert "'Fortification'" in code[item_idx:item_line_end]

    for classname in ("Land_CamoNet_EAST_EP1", "Land_CamoNetVar_EAST_EP1", "Land_CamoNetB_EAST_EP1"):
        class_idx = code.index(f"_c = _c + ['{classname}'];")
        item_idx = code.index("_i = _i + [[", class_idx)
        item_line_end = code.index("\n", item_idx)
        assert "WFBE_C_DEFMENU_V2" in code[item_idx:item_line_end]


if __name__ == "__main__":
    test_all_six_tka_fortification_items_have_nonempty_labels()
    test_all_six_tka_fortification_labels_are_apostrophe_and_quote_free()
    test_all_six_tka_fortification_items_still_registered_as_fortification_or_gated()
    print("TKA fortification item label regression check passed")
