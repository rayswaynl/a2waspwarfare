from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ALLOCATE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "AI" / "Commander" / "AI_Commander_Allocate.sqf"


def main():
    source = ALLOCATE.read_text(encoding="utf-8")

    assert '_losingPress = _logik getVariable ["wfbe_aicom_losing_press", false];' in source, (
        "The V2 allocator must read Strategy's live losing-PRESS state."
    )
    assert "&& {!_losingPress}" in source, (
        "Losing-PRESS must bypass the neutral-only expansion gate."
    )


if __name__ == "__main__":
    main()
