from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PLAYERSTAT = Path("Server") / "FSM" / "server_playerstat_loop.sqf"
MIRRORS = (
    ROOT / r"Missions\[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / r"Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan",
    ROOT / r"Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad",
)


def test_playerstat_emission_stops_at_round_end_in_every_mirror() -> None:
    sources = [(mission / PLAYERSTAT).read_text(encoding="utf-8-sig") for mission in MIRRORS]

    assert sources[0] == sources[1] == sources[2]
    source = sources[0]
    loop = source.index("while {!gameOver} do {")
    sleep = source.index("sleep _interval;", loop)
    guard = source.index("if (gameOver || {WFBE_GameOver}) exitWith {};", sleep)
    first_work = source.index('private ["_hcs"', sleep)
    emission = source.index('"PLAYERSTAT|v1|', first_work)

    assert loop < sleep < guard < first_work < emission
