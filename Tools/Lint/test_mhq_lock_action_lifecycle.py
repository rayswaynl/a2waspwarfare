from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_mhq_lock_action_reattachers_replace_their_local_handles():
    """Repeated CoIn exits / SetMHQLock deliveries must not stack MHQ scroll actions."""
    for relative in (
        "Client/PVFunctions/SetMHQLock.sqf",
        "Client/Module/CoIn/coin_interface.sqf",
    ):
        text = (SOURCE / relative).read_text(encoding="utf-8")
        assert 'getVariable ["wfbe_mhq_lock_actions", []]' in text
        assert 'setVariable ["wfbe_mhq_lock_actions", [_unlockAction, _lockAction], false]' in text
        assert 'removeAction _x' in text
