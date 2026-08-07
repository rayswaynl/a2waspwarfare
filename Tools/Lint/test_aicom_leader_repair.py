"""Static contract for r204 AICOM leader repair on the owning machine."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def _read(relative: str) -> str:
    return (CH / relative).read_text(encoding="utf-8")


def _assert_safe_repair(source: str, marker: str) -> None:
    assert marker in source
    repair = source[source.index(marker) :]
    assert "leader _team" in repair
    assert "alive _x" in repair
    assert "!isPlayer _x" in repair
    assert "local _x" in repair
    assert "_team selectLeader" in repair


def test_hc_driver_repairs_a_dead_or_missing_leader_before_main_loop() -> None:
    source = _read("Common/Functions/Common_RunCommanderTeam.sqf")
    _assert_safe_repair(source, "r204 LEADER REPAIR")
    assert source.index("r204 LEADER REPAIR") < source.index(
        "behaviour (leader _team)"
    )


def test_server_producer_repairs_a_dead_or_missing_server_local_leader() -> None:
    source = _read("Server/AI/Commander/AI_Commander_Produce.sqf")
    _assert_safe_repair(source, "r204 SERVER-LOCAL LEADER REPAIR")
    assert source.index("r204 SERVER-LOCAL LEADER REPAIR") < source.index(
        "_wm_ldr = leader _team"
    )
