"""Regression contracts for AICOM air watchdog mission-time deadlines."""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = tuple(
    ROOT / mission_root
    for mission_root in (
        "Missions/[55-2hc]warfarev2_073v48co.chernarus",
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
    )
)


def _source(root: Path, filename: str) -> str:
    path = root / "Server/AI/Commander" / filename
    return mask_comments(path.read_text(encoding="utf-8-sig"))


def test_aicom_air_watchdogs_anchor_hold_windows_to_mission_time() -> None:
    """Poll duration must follow mission time, not a fixed number of wakeups."""
    for filename, duration_local in (
        ("AI_Commander_AirResp.sqf", "_loiter"),
        ("AI_Commander_AirStrike.sqf", "_hold"),
    ):
        sources = [_source(root, filename) for root in MISSION_ROOTS]
        for source in sources:
            assert f"_deadline = _t0 + {duration_local};" in source
            assert "_t0 = _this select 4;" in source
            assert "while {_hot && {time < _deadline}" in source
            assert "_elapsed = _elapsed + _poll" not in source
        assert sources[0].encode("utf-8") == sources[1].encode("utf-8") == sources[2].encode("utf-8")


if __name__ == "__main__":
    test_aicom_air_watchdogs_anchor_hold_windows_to_mission_time()
    print("AICOM air watchdog mission-time deadline contract: PASS")
