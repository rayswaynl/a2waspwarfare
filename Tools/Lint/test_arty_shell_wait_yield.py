"""Regression contract for artillery shell-fall scheduler waits."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
HANDLERS = tuple(
    mission / "Common" / "Module" / "Arty" / handler
    for mission in MISSIONS
    for handler in ("ARTY_HandleILLUM.sqf", "ARTY_HandleSADARM.sqf")
)


def _first_shell_wait_body(source: str) -> str:
    marker = "//--- Wait before deploying."
    marker_offset = source.index(marker)
    wait_offset = source.index("waitUntil", marker_offset)
    open_brace = source.index("{", wait_offset)
    depth = 0
    for index in range(open_brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[open_brace + 1 : index]
    raise AssertionError("shell-fall waitUntil has no closing brace")


def test_artillery_shell_fall_waits_yield_before_rechecking_height():
    for handler in HANDLERS:
        source = handler.read_text(encoding="utf-8-sig")
        body = _first_shell_wait_body(source)
        assert body.lstrip().startswith("sleep 0.05;"), handler
