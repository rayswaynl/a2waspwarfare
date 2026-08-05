from pathlib import Path


MISSION = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def _release_pending_model(pending_ids, pending_id, legacy_pending):
    """Specify the identity-ledger transition used by the server terminal path."""
    if pending_id >= 0:
        keep = [entry for entry in pending_ids if entry[0] != pending_id]
        if len(keep) != len(pending_ids):
            return keep, len(keep)
        return list(pending_ids), legacy_pending
    return list(pending_ids), max(legacy_pending - 1, 0)


def test_chunked_founding_rechecks_gameover_before_commit():
    source = (MISSION / "Server" / "AI" / "Commander" / "AI_Commander_Teams.sqf").read_text(encoding="utf-8")
    final_yield = source.rfind("Call _sliceYield;")
    assert final_yield >= 0
    commit = source.index("[_side, -_price] Call ChangeAICommanderFunds", final_yield)
    assert "if (gameOver) exitWith {};" in source[final_yield:commit]


def test_delegated_team_creation_rejects_completed_round():
    source = (MISSION / "Common" / "Functions" / "Common_RunCommanderTeam.sqf").read_text(encoding="utf-8")
    create_group = source.index('[_side, "aicom"] Call WFBE_CO_FNC_CreateGroup')
    assert "if (gameOver || {WFBE_GameOver}) exitWith" in source[:create_group]


def test_pending_id_is_available_to_every_pre_creation_exit():
    source = (MISSION / "Common" / "Functions" / "Common_RunCommanderTeam.sqf").read_text(encoding="utf-8")
    pending_decl = source.index("_pendingId = -1;")
    endgame_guard = source.index("if (gameOver || {WFBE_GameOver}) exitWith")
    test_cap_guard = source.index("WFBE_C_TEST_TEAM_CAP=0")
    assert pending_decl < endgame_guard
    assert pending_decl < test_cap_guard


def test_pre_creation_exits_forward_pending_id_to_server_release():
    source = (MISSION / "Common" / "Functions" / "Common_RunCommanderTeam.sqf").read_text(encoding="utf-8")
    endgame_guard = source.index("if (gameOver || {WFBE_GameOver}) exitWith")
    lab_guard = source.index("WFBE_C_TEST_TEAM_CAP=0")
    lab_end = source.index("//--- PLANE AIRFIELD-SPAWN", lab_guard)
    assert "[\"aicom-team-ended\", _sideID, grpNull, _pendingId]" in source[endgame_guard:lab_guard]
    assert "[\"aicom-team-ended\", _sideID, grpNull, _pendingId]" in source[lab_guard:lab_end]


def test_creation_failure_forwards_pending_id_to_server_release():
    source = (MISSION / "Common" / "Functions" / "Common_RunCommanderTeam.sqf").read_text(encoding="utf-8")
    failure = source.index("team creation failed")
    tail = source[failure:source.index("_team allowFleeing", failure)]
    assert "[\"aicom-team-ended\", _sideID, grpNull, _pendingId]" in tail


def test_disband_and_driver_tail_forward_group_pending_id():
    disband = (MISSION / "Common" / "Functions" / "Common_AICOMDisbandTeam.sqf").read_text(encoding="utf-8")
    run_team = (MISSION / "Common" / "Functions" / "Common_RunCommanderTeam.sqf").read_text(encoding="utf-8")
    assert "wfbe_aicom_pending_id" in disband
    assert "[\"aicom-team-ended\", _sideID, _team, _pendingId]" in disband
    assert "[\"aicom-team-ended\", _sideID, _team, _pendingId]" in run_team


def test_server_team_end_retires_identity_and_keeps_legacy_fallback():
    source = (MISSION / "Server" / "Functions" / "Server_HandleSpecial.sqf").read_text(encoding="utf-8")
    start = source.index('case "aicom-team-ended":')
    next_case = source.find("\n\tcase ", start + 1)
    ended = source[start:next_case if next_case >= 0 else len(source)]
    assert "_ependingId" in ended
    assert "wfbe_aicom_pending_ids" in ended
    assert "if (count _args > 3)" in ended
    assert "if (_ependingId < 0) then" in ended


def test_pending_terminal_state_model_covers_identity_and_legacy_paths():
    cases = [
        ("success-head", [[10, 100], [11, 101]], 10, 2, [[11, 101]], 1),
        ("success-out-of-order", [[10, 100], [11, 101]], 11, 2, [[10, 100]], 1),
        ("timeout-style-oldest-release", [[20, 200], [21, 201]], 20, 2, [[21, 201]], 1),
        ("late-or-duplicate-unknown", [[30, 300]], 99, 1, [[30, 300]], 1),
        ("endgame-null-with-id", [[40, 400], [41, 401]], 41, 2, [[40, 400]], 1),
        ("legacy-null-fallback", [], -1, 2, [], 1),
        ("legacy-null-floor", [], -1, 0, [], 0),
    ]
    for name, pending_ids, pending_id, legacy_pending, expected_ids, expected_pending in cases:
        actual_ids, actual_pending = _release_pending_model(pending_ids, pending_id, legacy_pending)
        assert (actual_ids, actual_pending) == (expected_ids, expected_pending), name
