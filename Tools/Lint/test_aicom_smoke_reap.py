"""Regression contract for spawned-team AICOM smoke-shell reaping."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMMANDER_TEAM_FILES = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_RunCommanderTeam.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_RunCommanderTeam.sqf"),
)


def test_spawned_team_smoke_volleys_schedule_reaping() -> None:
    for relative_path in COMMANDER_TEAM_FILES:
        source = (ROOT / relative_path).read_text(encoding="utf-8")

        assert "[_asS0, _asS1] spawn {" in source, (
            f"assault smoke has no scheduled reaper in {relative_path}"
        )
        assert "[_smkS0, _smkS1] spawn {" in source, (
            f"break-off smoke has no scheduled reaper in {relative_path}"
        )
        assert source.count("sleep 20;") >= 2, (
            f"both AICOM smoke volleys must retain their bounded TTL in {relative_path}"
        )
