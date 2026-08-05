from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = [
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander.sqf",
]


def main():
    sources = [path.read_text(encoding="utf-8-sig") for path in SOURCES]
    for source in sources:
        assert "WASPSCALE|v2|" in source, "WASPSCALE v2 telemetry emitter is missing"
        assert "_humN = count ([] Call WFBE_CO_FNC_RealPlayers);" in source, (
            "WASPSCALE players must use the canonical HC-filtered real-player helper"
        )
        assert (
            "{ if (isPlayer _x) then {_humN=_humN+1} else { switch (side _x)"
            not in source
        ), "WASPSCALE must not count every isPlayer body in allUnits as a human"

    assert sources[1:] == sources[:1] * 2, "CH/TK/ZG AICOM mirrors have drifted"


if __name__ == "__main__":
    main()
