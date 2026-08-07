"""Regression contract for Forward FOB worker termination at round end."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def test_forward_fob_worker_stops_before_post_match_polling() -> None:
    for mission in MISSIONS:
        source = (
            mission / "Server/Functions/Server_ForwardFOBWorker.sqf"
        ).read_text(encoding="utf-8-sig")
        loop = source[source.index("while {") :]

        assert "!WFBE_GameOver" in loop, mission.name
        assert loop.index("!WFBE_GameOver") < loop.index("do {"), mission.name


if __name__ == "__main__":
    test_forward_fob_worker_stops_before_post_match_polling()
    print("forward FOB worker lifecycle contract passed")
