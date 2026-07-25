from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAPS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_attack_wave_reserves_the_side_before_spawning_its_timer():
    for mission_root in MAPS:
        source = (ROOT / mission_root / "Server/Functions/Server_AttackWave.sqf").read_text(encoding="utf-8")
        west_reservation = "if (_side == west) then {ATTACK_WAVE_ACTIVE_WEST = true}"
        east_reservation = "if (_side == east) then {ATTACK_WAVE_ACTIVE_EAST = true}"
        spawn = "[_supply, _side] spawn {"

        assert west_reservation in source, mission_root
        assert east_reservation in source, mission_root
        assert source.index(west_reservation) < source.index(spawn), mission_root
        assert source.index(east_reservation) < source.index(spawn), mission_root
