"""Regression contract for player-facing Zeta cargo release authority."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
UNHOOK = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Client/Module/ZetaCargo/Zeta_Unhook.sqf"
)


def test_zeta_unhook_requires_the_active_lifter_driver() -> None:
    source = UNHOOK.read_text(encoding="utf-8-sig")
    guard = "if (_caller != driver _lifter) exitWith {};"
    payload_read = '_vehicle = if ((typeName _param) == "ARRAY"'

    assert guard in source, "Zeta release action does not re-check driver authority"
    assert source.index(guard) < source.index(payload_read), (
        "Zeta release must reject a non-driver before touching the cargo payload"
    )
