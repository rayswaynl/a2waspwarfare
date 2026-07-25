#!/usr/bin/env python3
"""Regression check for the FPV first-flight acknowledgement."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
FPV_INTERFACE = Path("Client/Module/FPV/fpv_interface.sqf")


def test_first_flight_acknowledgement_is_flushed_to_profile() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / FPV_INTERFACE).read_text(encoding="utf-8-sig")
        acknowledgement = source.index(
            '["WFBE_FPV_FIRSTFLIGHT_SHOWN", true] Call WFBE_CO_FNC_SetProfileVariable'
        )
        flush = source.index("Call WFBE_CO_FNC_SaveProfile", acknowledgement)
        hint = source.index("FPV STRIKE DRONE - FIRST FLIGHT", acknowledgement)
        assert flush < hint, f"{terrain}: first-flight acknowledgement is not flushed before its hint"


if __name__ == "__main__":
    test_first_flight_acknowledgement_is_flushed_to_profile()
    print("FPV first-flight profile-persistence regression check passed")
