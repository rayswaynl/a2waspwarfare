from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _read(mission: str) -> str:
    path = ROOT / mission / "Server/Server_TownGarrisonDressing.sqf"
    return path.read_text(encoding="utf-8-sig")


def test_existing_garrisons_reconcile_searchlights_to_current_time():
    for mission in MISSIONS:
        source = _read(mission)
        prune = source.split("//=== (2) MAINTAIN", 1)[0]

        assert "((date select 3) < 6)" in prune
        assert "_lightClass createVehicle" in prune
        assert "GARNDRESS|LIGHT|" in prune
        assert "state=ON" in prune
        assert "state=OFF" in prune
        assert "sin (_gunDir - 90)" in prune
        assert "cos (_gunDir - 90)" in prune
        assert "_kept         = _kept + [[_eTown, _eGun, _eLight" in prune


def test_searchlight_reconciliation_stays_inside_existing_registry_prune():
    source = _read(MISSIONS[0])
    prune = source.split("//=== (2) MAINTAIN", 1)[0]
    compact = " ".join(prune.split())

    assert compact.index("_eLight = _entry select 2;") < compact.index("GARNDRESS|LIGHT|")
    assert compact.index("GARNDRESS|LIGHT|") < compact.index("_kept = _kept + [[_eTown, _eGun, _eLight")
