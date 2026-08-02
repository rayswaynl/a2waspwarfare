"""Regression contract for AI supply squads with no owned town.

An outbound supply squad with no owned town must remain at base.  It must not
enter the loading state (and later credit supply) merely because its fallback
target is the base position.
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
SUPPLY_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_AicomSupplySquad.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Server_AicomSupplySquad.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Server_AicomSupplySquad.sqf"),
)

OUTBOUND_ARRIVAL_GUARD = re.compile(
    r'''if \(_eState == "outbound"\) then \{.*?'''
    r'''if \(!isNull _eTown && \{\(_eCur distance _eObj\) < _eArrive\}\) then \{\s*'''
    r'''_eState = "loading";''',
    re.MULTILINE | re.DOTALL,
)


def read(relative: Path) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def test_outbound_arrival_requires_an_owned_town() -> None:
    for relative in SUPPLY_PATHS:
        text = read(relative)
        assert OUTBOUND_ARRIVAL_GUARD.search(text), relative


def test_no_town_fallback_cannot_use_the_legacy_unconditional_arrival_branch() -> None:
    legacy_branch = (
        'if ((_eCur distance _eObj) < _eArrive) then {\n'
        '\t\t\t\t\tif (_eState == "outbound") then {'
    )
    for relative in SUPPLY_PATHS:
        assert legacy_branch not in read(relative), relative


def test_supply_squad_mirrors_are_byte_identical() -> None:
    blobs = [(ROOT / relative).read_bytes() for relative in SUPPLY_PATHS]
    assert blobs[0] == blobs[1] == blobs[2]


if __name__ == "__main__":
    test_outbound_arrival_requires_an_owned_town()
    test_no_town_fallback_cannot_use_the_legacy_unconditional_arrival_branch()
    test_supply_squad_mirrors_are_byte_identical()
    print("AICOM supply no-town credit contract: PASS")
