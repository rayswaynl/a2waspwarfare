from pathlib import Path


MISSION = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_hc_init_stops_after_the_bounded_player_wait_times_out():
    text = (MISSION / "Headless" / "Init" / "Init_HC.sqf").read_text(encoding="utf-8")

    bounded_wait = 'waitUntil { uiSleep 0.5; (!isNull player) || (diag_tickTime > _hcInitDeadline) };'
    timeout_exit = 'if (isNull player) exitWith {'
    reseat_wait = 'waitUntil {uiSleep 0.25; !isNull player};'

    assert bounded_wait in text
    assert timeout_exit in text
    assert text.index(bounded_wait) < text.index(timeout_exit)
    assert reseat_wait not in text
