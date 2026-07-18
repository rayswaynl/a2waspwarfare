#!/usr/bin/env python3
"""Regression coverage for the elongated Khe Sanh carrier seam geometry."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)

ARMED_SEAM = (
    'if (isNil "WFBE_C_NAVAL_SEAM_BRIDGE")  then '
    '{WFBE_C_NAVAL_SEAM_BRIDGE   = 1};'
)
UNCHANGED_INLINE_GAP = (
    'if (isNil "WFBE_C_NAVAL_INLINE_GAP")   then '
    '{WFBE_C_NAVAL_INLINE_GAP    = -265};'
)
SEAM_BLOCK_START = "//--- Seam-bridge piers"
SEAM_BLOCK_END = '["INITIALIZATION", Format ["Init_NavalHVT.sqf : fable/naval-inline-hulls'
EXPECTED_OFFSETS = "_seam_Y_offsets = [-131, -134, -137, -140];"
DIRECT_DECK_PLACEMENT = "_bridgeZ = _ocDeckZ;"


def test_naval_seam_is_armed_and_seated_on_the_proven_deck_height() -> None:
    for mission_root in MISSION_ROOTS:
        constants_path = mission_root / "Common/Init/Init_CommonConstants.sqf"
        naval_path = mission_root / "Server/Init/Init_NavalHVT.sqf"

        constants = (ROOT / constants_path).read_text(encoding="utf-8")
        naval = (ROOT / naval_path).read_text(encoding="utf-8")
        seam_start = naval.index(SEAM_BLOCK_START)
        seam_end = naval.index(SEAM_BLOCK_END, seam_start)
        seam_block = naval[seam_start:seam_end]

        assert ARMED_SEAM in constants, f"seam bridge is not armed in {constants_path}"
        assert UNCHANGED_INLINE_GAP in constants, f"inline gap drifted in {constants_path}"
        assert EXPECTED_OFFSETS in seam_block, f"four-pier seam layout drifted in {naval_path}"
        assert DIRECT_DECK_PLACEMENT in seam_block, f"seam is not seated at _ocDeckZ in {naval_path}"
        assert "boundingBox" not in seam_block, f"invalid model bounds still drive seam height in {naval_path}"
        assert "_deckZB" not in seam_block, f"stale Hull B height estimate remains in {naval_path}"


if __name__ == "__main__":
    test_naval_seam_is_armed_and_seated_on_the_proven_deck_height()
