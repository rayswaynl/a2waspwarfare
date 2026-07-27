from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEAMS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "AI" / "Commander" / "AI_Commander_Teams.sqf"


def main():
    source = TEAMS.read_text(encoding="utf-8")

    assert "_pcN = count ([] Call WFBE_CO_FNC_RealPlayers);" in source, (
        "AICOM team scaling must use the canonical HC-filtered human-player helper."
    )
    assert "wfbe_aicom_teamstgt_pc" in source, (
        "TEAMS_TARGET must retain the last logged human count separately from its tier base."
    )
    assert "_pcN != _tgtPcPrev" in source, (
        "TEAMS_TARGET must emit when human count changes inside the same population tier."
    )
    assert "TEAMS_TARGET" in source and "|pc=" in source, (
        "TEAMS_TARGET must continue to expose the canonical human count for RPT comparison."
    )


if __name__ == "__main__":
    main()
