from pathlib import Path


SOURCE = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Functions" / "Common_AICOMAirLeg.sqf"


def test_arrival_rechecks_hot_lz_before_landing():
    text = SOURCE.read_text(encoding="utf-8-sig")
    approach_wait = text.index("time > _t0 || isNull _h")
    landing_gate = text.index("if (count _fl > 0) then", approach_wait)
    abort = text.index("AIRMOBILE_HOT_LZ_ABORT")

    assert approach_wait < abort < landing_gate
    assert "(_hotTown getVariable [\"sideID\", -1]) != _sID" in text[approach_wait:landing_gate]
    assert "_fl = []" in text[approach_wait:landing_gate]
