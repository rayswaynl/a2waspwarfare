"""Regression contract for per-unit GUER ground-QRF spawn offsets."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AIRDEF_PATHS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
        "Server/Server_GuerAirDef.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
        "Server/Server_GuerAirDef.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
        "Server/Server_GuerAirDef.sqf"
    ),
)


def test_ground_qrf_draws_a_distinct_offset_for_each_roster_unit() -> None:
    """QRF roster units must not all be created at the shared ring position."""
    for relative_path in AIRDEF_PATHS:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        start = source.index("_qrfTemplate = _qrfPool select")
        end = source.index("_groundQrfs = _groundQrfs +", start)
        qrf = source[start:end]
        assert "_qrfUnitPos =" in qrf
        assert "[_x, _qrfGroup, _qrfUnitPos, WFBE_C_GUER_ID]" in qrf


if __name__ == "__main__":
    test_ground_qrf_draws_a_distinct_offset_for_each_roster_unit()
