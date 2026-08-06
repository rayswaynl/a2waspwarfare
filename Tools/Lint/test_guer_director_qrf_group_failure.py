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


def _guard_bodies(source: str) -> list:
    """Return the brace-matched body of every `if (isNull _hGrp) then {...}` block."""
    head = "if (isNull _hGrp) then {"
    bodies = []
    cursor = 0
    while True:
        start = source.find(head, cursor)
        if start == -1:
            return bodies
        open_brace = start + len(head) - 1
        depth = 1
        i = open_brace + 1
        while depth > 0 and i < len(source):
            if source[i] == "{":
                depth += 1
            elif source[i] == "}":
                depth -= 1
            i += 1
        bodies.append(source[open_brace + 1:i - 1])
        cursor = i


def test_qrf_reaps_its_hull_when_group_creation_fails() -> None:
    """A QRF group-cap failure must not leave a helicopter or use grpNull.

    Asserted structurally, not as a literal character sequence: the original regex
    required `deleteVehicle _h;` to be immediately followed by `} else {`, so it broke
    as soon as a fold added QRF_SKIP telemetry inside the same guard - even though the
    hull reap it protects was untouched.
    """
    for relative_path in DIRECTOR_PATHS:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        assert source.count('[resistance, "qrf-air"] Call WFBE_CO_FNC_CreateGroup;') == 2
        bodies = _guard_bodies(source)
        assert len(bodies) == 2, (
            f"{relative_path}: expected 2 isNull-_hGrp failure guards, found {len(bodies)}"
        )
        for body in bodies:
            assert "deleteVehicle _h" in body, (
                f"{relative_path}: a QRF group-creation failure no longer reaps its hull - "
                f"the helicopter leaks when the group cap is hit"
            )


if __name__ == "__main__":
    test_qrf_reaps_its_hull_when_group_creation_fails()
