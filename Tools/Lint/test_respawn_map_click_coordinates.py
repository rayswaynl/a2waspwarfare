"""Regression contract for respawn-map click coordinate capture."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DIALOGS = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp"


def _respawn_map_definition() -> str:
    source = DIALOGS.read_text(encoding="utf-8")
    match = re.search(
        r"class WF_MiniMap\s*:\s*RscMapControl\s*\{(?P<body>.*?)\n\s*\};",
        source,
        flags=re.DOTALL,
    )
    assert match is not None, "WFBE_RespawnMenu must define WF_MiniMap"
    return match.group("body")


def test_respawn_map_button_down_captures_its_click_coordinates():
    """A click must not depend on a prior onMouseMoving event or stale cursor data."""
    definition = _respawn_map_definition()
    match = re.search(
        r'onMouseButtonDown\s*=\s*"(?P<handler>[^"]+)"',
        definition,
    )
    assert match is not None, "WF_MiniMap must define an onMouseButtonDown handler"
    handler = match.group("handler")

    x_capture = "mouseX = (_this select 2)"
    y_capture = "mouseY = (_this select 3)"
    button_capture = "mouseButtonDown = _this select 1"
    assert x_capture in handler
    assert y_capture in handler
    assert button_capture in handler
    assert handler.index(x_capture) < handler.index(button_capture)
    assert handler.index(y_capture) < handler.index(button_capture)
