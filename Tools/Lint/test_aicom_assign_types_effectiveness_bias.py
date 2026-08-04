from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_server_local_template_picker_uses_the_live_effectiveness_bias() -> None:
    """HC and server-local AICOM founders must consume the same active bias knob."""
    teams = (MISSION / "Server" / "AI" / "Commander" / "AI_Commander_Teams.sqf").read_text(encoding="utf-8")
    assign_types = (MISSION / "Server" / "AI" / "Commander" / "AI_Commander_AssignTypes.sqf").read_text(encoding="utf-8")

    expected = 'missionNamespace getVariable ["WFBE_C_AICOM_EFF_BIAS_EXP", 0.5]'
    assert expected in teams, "The HC founding path must establish the active effectiveness-bias contract."
    assert expected in assign_types, "The server-local fallback must use the same active effectiveness-bias contract."
    assert "WFBE_C_AICOM_TIER_BIAS_EXP" not in assign_types, (
        "The server-local fallback must not consume the superseded tier-price bias."
    )


if __name__ == "__main__":
    test_server_local_template_picker_uses_the_live_effectiveness_bias()
