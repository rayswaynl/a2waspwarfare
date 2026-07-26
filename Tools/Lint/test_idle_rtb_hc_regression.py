from pathlib import Path


SOURCE = Path(__file__).parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Functions" / "Common_RunCommanderTeam.sqf"


def assert_before(text, first, second):
    assert first in text, f"missing: {first}"
    assert second in text, f"missing: {second}"
    assert text.index(first) < text.index(second), f"expected {first!r} before {second!r}"


def main():
    text = SOURCE.read_text(encoding="utf-8")
    idle_start = text.index('private ["_idleRtbEnabled"')
    idle_end = text.index('if ((missionNamespace getVariable ["WFBE_C_AICOM_HELI_CANNON_NUDGE", 1])', idle_start)
    idle_gate = text[idle_start:idle_end]
    assert_before(idle_gate, "_idleRtbEnabled = false;", "_idleRtbEnabled = (missionNamespace")
    assert_before(idle_gate, "_idleSenseProbe = -1;", "_idleSenseProbe = missionNamespace getVariable")
    assert 'if ((typeName _idleSenseProbe) != "SCALAR") then {_idleSenseProbe = -1};' in idle_gate
    assert "{_idleSenseProbe > 0};" in idle_gate

    reap_start = text.index('private ["_rh","_rCrew","_rEnemy"')
    reap_end = text.index("} forEach _reapVehs;", reap_start)
    reap_block = text[reap_start:reap_end]
    assert '"_rCrew"' in reap_block
    assert_before(reap_block, "_rCrew = [];", "_rCrew = crew _rh;")
    assert 'if ((typeName _rCrew) != "ARRAY") then {_rCrew = []};' in reap_block
    assert "(crew _rh)" not in reap_block
    assert '"_recheckCrew"' in reap_block
    assert_before(reap_block, "_recheckCrew = [];", "_recheckCrew = crew _h;")
    assert 'if ((typeName _recheckCrew) != "ARRAY") then {_recheckCrew = []};' in reap_block
    assert "(crew _h)" not in reap_block
    print("idle RTB HC regression guard: PASS")


if __name__ == "__main__":
    main()
