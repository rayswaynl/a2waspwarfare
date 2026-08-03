"""Regression coverage for GUER QRF group-creation failure cleanup."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
DIRECTOR_PATHS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
        "Server/AI/Server_GuerDirector.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
        "Server/AI/Server_GuerDirector.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
        "Server/AI/Server_GuerDirector.sqf"
    ),
)


def test_qrf_reaps_its_hull_when_group_creation_fails() -> None:
    """A QRF group-cap failure must not leave a helicopter or use grpNull."""
    failure_guard = re.compile(
        r"if \(isNull _hGrp\) then \{\s+deleteVehicle _h;\s+\} else \{"
    )
    for relative_path in DIRECTOR_PATHS:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        assert source.count('[resistance, "qrf-air"] Call WFBE_CO_FNC_CreateGroup;') == 2
        assert len(failure_guard.findall(source)) == 2


if __name__ == "__main__":
    test_qrf_reaps_its_hull_when_group_creation_fails()
