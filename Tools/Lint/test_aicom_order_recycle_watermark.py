"""Regression contract for recycled AICOM order-sequence watermarks.

Arma 2 can recycle a deleted group slot with its custom variables intact.  A
new ``Common_RunCommanderTeam`` driver must remember the inherited order
sequence before it registers the replacement team, then use that sequence as
its local consumed watermark.  Clearing the record would restart numbering at
zero; keeping the payload with a ``-1`` watermark executes the old plan once.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNNER_PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_RunCommanderTeam.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_RunCommanderTeam.sqf",
)

SNAPSHOT = '_foundOrder = _team getVariable "wfbe_aicom_order";'
WATERMARK = "_lastSeq = _foundOrderSeq;"
REGISTRATION = '["aicom-team-created", _sideID, _team] Call HandleSpecial;'


def test_recycled_order_sequence_is_consumed_before_team_registration() -> None:
    raw = []
    for path in RUNNER_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        raw.append(path.read_bytes())

        assert SNAPSHOT in source, f"missing inherited order snapshot: {path}"
        assert source.index(SNAPSHOT) < source.index(REGISTRATION), (
            f"order sequence must be captured before the server can publish a fresh order: {path}"
        )
        assert WATERMARK in source, f"driver still accepts a recycled plan payload: {path}"
        assert "_lastSeq = -1;" not in source, (
            f"constant watermark replays the previous group occupant's order: {path}"
        )

    assert raw[0] == raw[1] == raw[2], "commander-team mirrors differ"
