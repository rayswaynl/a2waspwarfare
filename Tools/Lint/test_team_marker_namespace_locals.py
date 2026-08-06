"""Contract for private locals in the team-marker worker."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = [
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "FSM"
    / "updateteamsmarkers.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Client"
    / "FSM"
    / "updateteamsmarkers.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Client"
    / "FSM"
    / "updateteamsmarkers.sqf",
]
LEAK_PRONE_LOCALS = (
    "_ownLabel",
    "_ownLastLabel",
    "_ownTag",
    "_classReqDone",
    "_classReqTicks",
)


def test_team_marker_state_locals_are_private_in_each_mirror():
    for source_path in SOURCES:
        source = source_path.read_text(encoding="utf-8")
        private_declaration = source.splitlines()[1]

        for local in LEAK_PRONE_LOCALS:
            assert f'"{local}"' in private_declaration


if __name__ == "__main__":
    test_team_marker_state_locals_are_private_in_each_mirror()
