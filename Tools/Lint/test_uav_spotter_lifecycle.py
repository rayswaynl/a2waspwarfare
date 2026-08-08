from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
SPOTTER_REL = Path("Client/Module/UAV/uav_spotter.sqf")


def test_uav_spotter_workers_stop_before_post_gameover_reveals() -> None:
    mirror_bytes = []

    for mission_dir in MISSION_DIRS:
        path = mission_dir / SPOTTER_REL
        source = path.read_text(encoding="utf-8-sig")
        mirror_bytes.append(path.read_bytes())

        assert "while {!gameOver} do {" in source, path
        assert "while {true} do {" not in source, path

        cycle_sleep = source.index("sleep _delay;")
        cycle_guard = source.index("if (gameOver) exitWith {};", cycle_sleep)
        alive_guard = source.index("if !(alive _uav) exitWith {};", cycle_guard)
        assert cycle_sleep < cycle_guard < alive_guard, path

        target_gate = source.index("if (!gameOver && {alive _x}")
        target_sleep = source.index("sleep (0.05 + random 0.05);")
        target_guard = source.index("if (!gameOver) then {", target_sleep)
        reveal = source.index(
            '[sideJoined, "HandleSpecial", ["uav-reveal", _uav, _x]] Call WFBE_CO_FNC_SendToClients;',
            target_guard,
        )
        assert target_gate < target_sleep < target_guard < reveal, path

    assert mirror_bytes[0] == mirror_bytes[1] == mirror_bytes[2]


if __name__ == "__main__":
    test_uav_spotter_workers_stop_before_post_gameover_reveals()
