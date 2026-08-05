from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAPS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def test_match_counter_read_normalizes_malformed_profile_values():
    for mission in MAPS:
        text = (mission / "Server/Init/Init_Server.sqf").read_text(encoding="utf-8")
        assert 'profileNamespace getVariable ["WFBE_MATCH_COUNTER", 0]' in text
        assert 'typeName _matchN != "SCALAR"' in text
        assert "_matchN < 0" in text
        assert 'profileNamespace setVariable ["WFBE_MATCH_COUNTER", _matchN]' in text


if __name__ == "__main__":
    test_match_counter_read_normalizes_malformed_profile_values()
    print("PASS: persisted WFBE_MATCH_COUNTER readers validate and normalize schema")
