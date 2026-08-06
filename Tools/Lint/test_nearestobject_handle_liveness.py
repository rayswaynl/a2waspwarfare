from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RELATIVE_PATHS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_at_velocity_only_runs_for_a_resolved_nearest_rocket():
    for mission in RELATIVE_PATHS:
        source = (ROOT / mission / "Common/Functions/Common_HandleAT.sqf").read_text(encoding="utf-8-sig")
        assert "if (isNull _rocket) exitWith {};" in source
        assert source.index("if (isNull _rocket) exitWith {};") < source.index("_vec = velocity _rocket;")


def test_alarm_loop_stops_when_its_nearest_missile_is_deleted():
    for mission in RELATIVE_PATHS:
        source = (ROOT / mission / "Common/Functions/Common_HandleAlarm.sqf").read_text(encoding="utf-8-sig")
        assert "while {!isNull _missile && {_source distance _missile < _limit}} do {" in source


def test_tracer_rechecks_its_nearest_rocket_after_the_effect_delay():
    for mission in RELATIVE_PATHS:
        source = (ROOT / mission / "Common/Functions/Common_HandleRocketTracer.sqf").read_text(encoding="utf-8-sig")
        delay = source.index("sleep 0.7;")
        post_delay_guard = source.index("if (isNull _rocket) exitWith {};", delay)
        final_effect = source.index('_fp1 = "#particlesource" createVehicleLocal getPos _rocket;')
        assert delay < post_delay_guard < final_effect
