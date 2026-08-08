"""Regression contracts for persistent-display input handlers on client re-entry."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INIT_CLIENT = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf"


def test_view_distance_handler_is_replaced_before_client_reentry_registration():
    """Repeated Init_Client execution must leave only one User18/User19/User20 handler."""
    source = INIT_CLIENT.read_text(encoding="utf-8")
    old_id = 'uiNamespace getVariable ["WFBE_CL_VAR_ViewDistanceKeyDownEH", -1]'
    remove = '_display displayRemoveEventHandler ["KeyDown", _viewDistanceEH];'
    add = '_viewDistanceEH = _display displayAddEventHandler ["KeyDown","_this call keyPressedForAdjustingViewDistance"];'
    store = 'uiNamespace setVariable ["WFBE_CL_VAR_ViewDistanceKeyDownEH", _viewDistanceEH];'

    assert old_id in source
    assert remove in source
    assert add in source
    assert store in source
    assert source.index(remove) < source.index(add) < source.index(store)


def test_tint_legend_handler_is_replaced_before_client_reentry_registration():
    """Repeated Init_Client execution must not toggle the tint legend twice per key press."""
    source = INIT_CLIENT.read_text(encoding="utf-8")
    old_id = 'uiNamespace getVariable ["WFBE_CL_VAR_TintLegendKeyDownEH", -1]'
    remove = '_display displayRemoveEventHandler ["KeyDown", _tintLegendEH];'
    add = '_tintLegendEH = _display displayAddEventHandler ["KeyDown", "_this call WFBE_CL_FNC_ToggleTintLegend"];'
    store = 'uiNamespace setVariable ["WFBE_CL_VAR_TintLegendKeyDownEH", _tintLegendEH];'

    assert old_id in source
    assert remove in source
    assert add in source
    assert store in source
    assert source.index(remove) < source.index(add) < source.index(store)
