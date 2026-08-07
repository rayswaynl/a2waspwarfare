#!/usr/bin/env python3
"""Regression check for replacement-safe local commander-order task timers."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_replaced_task_timer_is_invalidated_by_generation() -> None:
    for terrain in TERRAINS:
        init_source = (ROOT / terrain / "Client/Init/Init_Client.sqf").read_text(encoding="utf-8")
        task_source = (ROOT / terrain / "Client/PVFunctions/SetTask.sqf").read_text(encoding="utf-8")

        assert "comTaskGeneration = 0;" in init_source, (
            f"{terrain}: local task generation must start at zero"
        )
        assert "comTaskGeneration = comTaskGeneration + 1;" in task_source, (
            f"{terrain}: each replacement must invalidate the prior timer"
        )
        assert "[comTask,comTaskGeneration,_taskTime,_taskPos,_task] Spawn {" in task_source, (
            f"{terrain}: each timer must retain the generation it owns"
        )
        assert "while {_generation == comTaskGeneration && {((taskDestination _task) select 0) == (_pos select 0)} && {!_succeed}} do {" in task_source, (
            f"{terrain}: stale task timers must stop before UI/radio completion"
        )
        assert "if (_generation == comTaskGeneration) then {" in task_source, (
            f"{terrain}: a task replacement during sleep must block completion"
        )


if __name__ == "__main__":
    test_replaced_task_timer_is_invalidated_by_generation()
    print("SetTask replacement lifecycle regression check passed")
