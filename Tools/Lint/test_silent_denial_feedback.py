from pathlib import Path


MISSION = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_forward_fob_authoritative_rejections_name_the_failed_gate_for_requester():
    source = (MISSION / "Server" / "PVFunctions" / "RequestForwardFOB.sqf").read_text(encoding="utf-8")

    for message in (
        "Forward FOB rejected: your side already has",
        "Forward FOB rejected: too close to your base area",
        "Forward FOB rejected: not enough funds",
    ):
        assert message in source
    assert '[_player, "LocalizeMessage", ["Wildcard", _denyMsg]] Call WFBE_CO_FNC_SendToClient;' in source


def test_mhq_repair_authoritative_race_rejections_name_the_failed_gate_for_requester():
    source = (MISSION / "Server" / "Functions" / "Server_MHQRepair.sqf").read_text(encoding="utf-8")

    for message in (
        "MHQ repair rejected: another repair is already in progress.",
        "MHQ repair rejected: the HQ has already been rebuilt.",
    ):
        assert message in source
    assert '["Wildcard", _denyMsg]] Call WFBE_CO_FNC_SendToClient' in source
