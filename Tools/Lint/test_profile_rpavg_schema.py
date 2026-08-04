from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_rpavg_readers_reject_truncated_or_wrong_type_records():
    for relative in ("Server/Init/Init_Server.sqf", "Server/Functions/Server_LogGameEnd.sqf"):
        text = (CH / relative).read_text(encoding="utf-8")
        assert 'typeName _rpavg185 != "ARRAY"' in text
        assert "count _rpavg185 != 2" in text
        assert 'profileNamespace setVariable ["WFBE_RPAVG", _rpavg185]' in text


if __name__ == "__main__":
    test_rpavg_readers_reject_truncated_or_wrong_type_records()
    print("PASS: persisted WFBE_RPAVG readers validate and normalize schema")
