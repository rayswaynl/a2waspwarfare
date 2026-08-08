#!/usr/bin/env python3
"""Regression contract for wave0804b FIX 1a (build-menu apostrophe/quote corruption).

BIS_fnc_createmenu (coin_interface.sqf ~line 1046) formats the WHOLE per-category
_arrayParams array into a SINGLE-quoted `call compile '%3'` click-handler
(coin_interface.sqf ~line 1046). Any apostrophe (ASCII 39) or double-quote (ASCII 34)
riding inside a resolved item label (_itemname, ~line 1008-1029) prematurely closes
that single-quoted string and corrupts every sibling item's click handler in the same
category (proven: BIS RPT "Error Missing '''" two-statement-later signature).

Arma 2 OA SQF cannot be executed by this repository's Python tooling, so this test
(a) pins the structural shape of the fix - the sanitize block runs AFTER _itemname is
resolved and BEFORE it is folded into _arrayParams - and (b) exercises the exact
character-filter algorithm transcribed from the SQF (toArray -> drop ASCII 39/34 ->
toString) against a small deterministic model to prove the *behavior*, not just that
some code exists.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
COIN_INTERFACE = CHERNARUS / "Client" / "Module" / "CoIn" / "coin_interface.sqf"


def sqf_sanitize_label(raw: str) -> str:
    """Python transcription of the coin_interface.sqf toArray/toString filter.

    Mirrors (character-for-character in intent, not literally executing SQF):
        _wc19Chars = toArray _itemname;
        _wc19Clean = [];
        for "_wc19i" from 0 to (count _wc19Chars - 1) do {
            _wc19c = _wc19Chars select _wc19i;
            if (_wc19c != 39 && {_wc19c != 34}) then {_wc19Clean set [count _wc19Clean, _wc19c]};
        };
        _itemname = toString _wc19Clean;
    """
    chars = [ord(c) for c in raw]
    clean = [c for c in chars if c != 39 and c != 34]
    return "".join(chr(c) for c in clean)


def test_sanitize_strips_apostrophes_and_double_quotes_only() -> None:
    assert sqf_sanitize_label("Farmer's Market") == "Farmers Market"
    assert sqf_sanitize_label('Say "Hi" Base') == "Say Hi Base"
    assert sqf_sanitize_label("O'Brien's \"Camp\"") == "OBriens Camp"
    # No apostrophe/quote anywhere in the output alphabet.
    assert "'" not in sqf_sanitize_label("It's a 'test' with \"quotes\"")
    assert '"' not in sqf_sanitize_label("It's a 'test' with \"quotes\"")


def test_sanitize_is_a_no_op_on_clean_labels() -> None:
    assert sqf_sanitize_label("LoS Screen (Tall)") == "LoS Screen (Tall)"
    assert sqf_sanitize_label("Barrier Wall (5x)") == "Barrier Wall (5x)"


def test_source_sanitizes_itemname_before_it_reaches_arrayparams() -> None:
    """The sanitize block must sit between the _itemname resolution and the
    _arrayParams append (~line 1028) - the ONLY place untrusted label text
    crosses into the single-quoted BIS_fnc_createmenu payload."""
    code = COIN_INTERFACE.read_text(encoding="utf-8-sig")

    itemname_idx = code.index(
        '_itemname = if (count _x > 3) then {_x select 3} else '
        '{getText (configFile >> "CfgVehicles" >> _itemclass >> "displayName")};'
    )
    sanitize_toarray_idx = code.index("_wc19Chars = toArray _itemname;", itemname_idx)
    sanitize_filter_idx = code.index("_wc19c != 39 && {_wc19c != 34}", sanitize_toarray_idx)
    sanitize_reassign_idx = code.index("_itemname = toString _wc19Clean;", sanitize_filter_idx)
    # fable/placement-preview-fix (owner 2026-08-08, live RPT: 318x "Invalid number in
    # expression"): the appended element was renamed _x -> _xSafe, a numeric-safe copy of
    # _x built between the sanitize block and this append (see
    # test_arrayparams_embeds_the_numeric_safe_copy below) - same ordering contract, new name.
    arrayparams_append_idx = code.index(
        '_arrayParams = _arrayParams + [[_logic getVariable "BIS_COIN_ID"] + [_xSafe,_i]];',
        sanitize_reassign_idx,
    )

    assert itemname_idx < sanitize_toarray_idx < sanitize_filter_idx < sanitize_reassign_idx < arrayparams_append_idx

    # regexReplace does not exist on Arma 2 OA 1.64 (A3 2.06+ only) - the implementation
    # itself (not commentary referencing why it's banned) must never call it.
    implementation = code[sanitize_toarray_idx:sanitize_reassign_idx]
    assert "regexReplace" not in implementation


def test_sanitize_filters_both_ascii_39_and_ascii_34() -> None:
    code = COIN_INTERFACE.read_text(encoding="utf-8-sig")
    filter_line_idx = code.index("_wc19c != 39 && {_wc19c != 34}")
    filter_line = code[filter_line_idx : filter_line_idx + 40]
    assert "39" in filter_line and "34" in filter_line


# ---------------------------------------------------------------------------
# fable/placement-preview-fix (owner 2026-08-08): live RPT showed 318x "Error
# Invalid number in expression" with an empty error position, ending at
# `_logic setVariable ['BIS_COIN_params',_params];` - the same single-quoted
# BIS_fnc_createmenu click-handler compile the apostrophe bug above corrupts, but
# via a malformed NUMERIC cost instead of a label. PR8 (2026-06-07, commit
# a840431c77) already proved the mechanism ("an invalid WDDM commander-anchor
# class makes Core_CIV emit a malformed item whose cost is [cash,<null>]") and
# sanitized the LOCAL _itemcost/_itemcash used for the canAfford display, but
# explicitly left the raw _x (embedded into _arrayParams) untouched - "restoring
# the build preview for the affected WDDM positions still needs valid anchor
# classes (separate, held fix)". This is that fix, made unconditional so no
# future malformed cost - from any item, in any category - can corrupt a
# sibling's click handler.
# ---------------------------------------------------------------------------

def test_xsafe_is_built_between_the_pr8_guard_and_the_arrayparams_append() -> None:
    code = COIN_INTERFACE.read_text(encoding="utf-8-sig")

    pr8_guard_idx = code.index(
        'if (isNil "_itemcost" || {typeName _itemcost != "SCALAR"}) then {_itemcost = 0};'
    )
    xsafe_build_idx = code.index("_xSafe = +_x;", pr8_guard_idx)
    xsafe_set_idx = code.index(
        "_xSafe set [2, if (_itemcostWasArray) then {[_itemcash,_itemcost]} else {_itemcost}];",
        xsafe_build_idx,
    )
    arrayparams_append_idx = code.index(
        '_arrayParams = _arrayParams + [[_logic getVariable "BIS_COIN_ID"] + [_xSafe,_i]];',
        xsafe_set_idx,
    )

    assert pr8_guard_idx < xsafe_build_idx < xsafe_set_idx < arrayparams_append_idx, (
        "_xSafe must be built from the already-sanitized _itemcost/_itemcash AFTER the "
        "existing PR8 guard, and _arrayParams must embed _xSafe, never the raw _x"
    )
    # The raw _x must never reach _arrayParams again (that was the actual bug: PR8 only
    # fixed the LOCAL display calc, not the payload every sibling's click handler shares).
    assert '[_x,_i]' not in code


def test_xsafe_preserves_the_original_cost_shape() -> None:
    """_xSafe's cost field (index 2) must stay array-shaped ([cash,cost]) when the
    original was array-shaped, and scalar when the original was scalar - coin_interface.sqf's
    own preview-loop reader (`_itemcost = _params select 2; if (typename _itemcost ==
    "ARRAY") then {...}`) depends on that shape being unchanged for well-formed items."""
    code = COIN_INTERFACE.read_text(encoding="utf-8-sig")
    set_line_idx = code.index(
        "_xSafe set [2, if (_itemcostWasArray) then {[_itemcash,_itemcost]} else {_itemcost}];"
    )
    set_line = code[set_line_idx : set_line_idx + 100]
    assert "_itemcostWasArray" in set_line
    assert "[_itemcash,_itemcost]" in set_line, "array-shaped costs must reconstruct as [cash,cost]"


if __name__ == "__main__":
    test_sanitize_strips_apostrophes_and_double_quotes_only()
    test_sanitize_is_a_no_op_on_clean_labels()
    test_source_sanitizes_itemname_before_it_reaches_arrayparams()
    test_sanitize_filters_both_ascii_39_and_ascii_34()
    test_xsafe_is_built_between_the_pr8_guard_and_the_arrayparams_append()
    test_xsafe_preserves_the_original_cost_shape()
    print("coin menu label apostrophe/quote sanitize regression check passed")
