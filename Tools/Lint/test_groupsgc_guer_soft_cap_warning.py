#!/usr/bin/env python3
"""Regression contract for the GUER soft-cap approach warning.

The server already computes the configured GUER soft threshold and emits the
GUERCAP gauge, but the threshold must also drive a debounced RPT warning.  The
warning is telemetry-only: it must not change group creation, garrison
admission, or the configured cap.  Keep the contract mirrored across the
maintained Chernarus, Takistan, and Zargabad missions.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
SOURCE = Path("Server/FSM/server_groupsGC.sqf")
GUERCAP_LINE = 'diag_log ("GUERCAP|v1|count="'
WEST_WARNING_MARKER = "// WEST - approach (130)"


def test_guer_soft_threshold_is_consumed_by_debounced_warning() -> None:
    for mission in MISSIONS:
        source = (mission / SOURCE).read_text(encoding="utf-8-sig")
        guercap_at = source.index(GUERCAP_LINE)
        west_warning_at = source.index(WEST_WARNING_MARKER, guercap_at)
        guercap_block = source[guercap_at:west_warning_at]

        assert "_guerSoftThreshold = round (_guerMax * 0.9);" in source
        assert "if (_cntGuer >= _guerSoftThreshold) then {" in guercap_block
        assert (
            'missionNamespace getVariable ["wfbe_groupcap_warn_guer90", -9999];'
            in guercap_block
        )
        assert "if ((_now - _lastGuerSoft) >= _warnInterval) then {" in guercap_block
        assert (
            'missionNamespace setVariable ["wfbe_groupcap_warn_guer90", _now];'
            in guercap_block
        )
        assert "Call WFBE_CO_FNC_AICOMLog;" in guercap_block


def test_guer_groupgc_warning_block_is_mirrored() -> None:
    sources = [(mission / SOURCE).read_text(encoding="utf-8-sig") for mission in MISSIONS]
    assert sources[1] == sources[0]
    assert sources[2] == sources[0]


if __name__ == "__main__":
    test_guer_soft_threshold_is_consumed_by_debounced_warning()
    test_guer_groupgc_warning_block_is_mirrored()
