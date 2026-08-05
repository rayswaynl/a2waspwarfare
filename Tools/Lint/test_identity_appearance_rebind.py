#!/usr/bin/env python3
"""Regression contract for group callsign replay after JIP team rebinds."""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_group_callsigns_replay_after_each_client_teams_rebind() -> None:
    """Late JIP team sync must not leave the rebound groups with default IDs."""
    for terrain in TERRAINS:
        source = mask_comments(
            (ROOT / terrain / "Client/Init/Init_Client.sqf").read_text(
                encoding="utf-8-sig"
            )
        )

        compile_line = (
            'WFBE_CL_FNC_SetGroupsID = Compile preprocessFile '
            '"Client\\Functions\\Client_SetGroupsID.sqf";'
        )
        call_line = "[] Call WFBE_CL_FNC_SetGroupsID;"
        assert compile_line in source, f"{terrain}: callsign helper must be compiled once"
        assert source.count(call_line) == 3, (
            f"{terrain}: initial plus both JIP rebind paths must replay callsigns"
        )
        assert "[] Call Compile preprocessFile \"Client\\Functions\\Client_SetGroupsID.sqf\";" not in source

        rebinds = [idx for idx in range(len(source)) if source.startswith("clientTeams = _teams;", idx)]
        assert len(rebinds) == 2, f"{terrain}: expected both JIP rebind assignments"
        for idx in rebinds:
            window = source[idx : idx + 160]
            assert call_line in window, f"{terrain}: callsigns must replay after clientTeams rebind"


if __name__ == "__main__":
    test_group_callsigns_replay_after_each_client_teams_rebind()
    print("identity/appearance rebind regression check passed")
