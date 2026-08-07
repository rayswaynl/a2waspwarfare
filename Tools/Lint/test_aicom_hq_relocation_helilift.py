from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_helilift_uses_current_deployed_hq_not_start_snapshot():
    worker = (CH / "Server" / "AI" / "Commander" / "AI_Commander_HeliLift.sqf").read_text(encoding="utf-8")
    executor = (CH / "Server" / "Support" / "Support_HeliLift.sqf").read_text(encoding="utf-8")

    assert "GetSideHQDeployStatus" in worker
    assert "GetSideHQ" in worker
    assert 'getVariable "wfbe_startpos"' not in worker
    assert "GetSideHQ" in executor
    assert 'getVariable "wfbe_startpos"' not in executor
