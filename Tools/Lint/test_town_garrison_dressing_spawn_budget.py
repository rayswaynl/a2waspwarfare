from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _read(mission: str) -> str:
    return (ROOT / mission / "Server/Server_TownGarrisonDressing.sqf").read_text(
        encoding="utf-8-sig"
    )


def test_dressing_materialization_has_one_attempt_budget_per_cycle():
    for mission in MISSIONS:
        source = _read(mission)
        maintain_start = source.index("//=== (2) MAINTAIN:")
        maintain_end = source.index("//--- Re-read quiet window", maintain_start)
        maintain = source[maintain_start:maintain_end]

        reset = maintain.index("_spawnAttemptsThisCycle = 0;")
        gate = maintain.index("_spawnAttemptsThisCycle < 1")
        charge = maintain.index(
            "_spawnAttemptsThisCycle = _spawnAttemptsThisCycle + 1;"
        )
        materialize = maintain.index("_gun = _gunClass createVehicle _gunPos;")

        assert reset < gate < charge < materialize
        assert 'for "_scanOffset" from 0 to ((count towns) - 1) do {' in maintain
        assert "floor (random (count towns))" in maintain
