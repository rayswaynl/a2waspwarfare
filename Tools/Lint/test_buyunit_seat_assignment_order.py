"""Regression contract for AICOM refill seat-order pairing."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BUY_UNIT = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/Functions/Server_BuyUnit.sqf"
)


def test_vehicle_refill_assigns_seat_before_issuing_get_in_order() -> None:
    """A failed immediate moveIn must leave a live, role-specific boarding order."""
    text = BUY_UNIT.read_text(encoding="utf-8-sig")

    expected_sequences = (
        "_soldier assignAsDriver _vehicle;\n\t\t[_soldier] orderGetIn true;\n\t\t_soldier moveInDriver _vehicle;",
        "_soldier assignAsGunner _vehicle;\n\t\t\t[_soldier] orderGetIn true;\n\t\t\t_soldier moveInGunner _vehicle;",
        "(leader _team) assignAsCommander _vehicle;\n\t\t\t[leader _team] orderGetIn true;\n\t\t\t(leader _team) moveInCommander _vehicle;",
        "_soldier assignAsCommander _vehicle;\n\t\t\t\t[_soldier] orderGetIn true;\n\t\t\t\t_soldier moveInCommander _vehicle;",
    )

    for sequence in expected_sequences:
        assert sequence in text
