from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
PILOT_REL = Path("Client/Module/AWACS/awacs_pilot_watch.sqf")
SPOTTER_REL = Path("Client/Module/AWACS/awacs_spotter.sqf")


def test_awacs_workers_stop_before_post_gameover_work() -> None:
    pilot_bytes = []
    spotter_bytes = []

    for mission_dir in MISSION_DIRS:
        pilot_path = mission_dir / PILOT_REL
        spotter_path = mission_dir / SPOTTER_REL
        pilot = pilot_path.read_text(encoding="utf-8-sig")
        spotter = spotter_path.read_text(encoding="utf-8-sig")
        pilot_bytes.append(pilot_path.read_bytes())
        spotter_bytes.append(spotter_path.read_bytes())

        assert "while {!gameOver} do {" in pilot, pilot_path
        assert "while {true} do {" not in pilot, pilot_path
        pilot_sleep = pilot.index("sleep 5;")
        pilot_guard = pilot.index("if (gameOver) exitWith {};", pilot_sleep)
        pilot_work = pilot.index("if (alive player) then {", pilot_guard)
        assert pilot_sleep < pilot_guard < pilot_work, pilot_path

        expected_spotter_loop = (
            "while {alive _awacs && {vehicle player == _awacs} && "
            "{driver _awacs == player} && {!gameOver}} do {"
        )
        assert expected_spotter_loop in spotter, spotter_path
        assert "while {alive _awacs && {vehicle player == _awacs} && {driver _awacs == player}} do {" not in spotter, spotter_path
        spotter_sleep = spotter.index("sleep (0.05 + random 0.05);")
        spotter_guard = spotter.index("if (!gameOver) then {", spotter_sleep)
        spotter_reveal = spotter.index(
            '[sideJoined, "HandleSpecial", ["uav-reveal", _awacs, _target]] Call WFBE_CO_FNC_SendToClients;',
            spotter_guard,
        )
        assert spotter_sleep < spotter_guard < spotter_reveal, spotter_path

    assert pilot_bytes[0] == pilot_bytes[1] == pilot_bytes[2]
    assert spotter_bytes[0] == spotter_bytes[1] == spotter_bytes[2]


if __name__ == "__main__":
    test_awacs_workers_stop_before_post_gameover_work()
