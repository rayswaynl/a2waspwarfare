from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _groups_block(text: str) -> str:
    start = text.index("class Groups")
    marker = text.index("\n\tclass Markers", start)
    return text[start:marker]


def _group_items(block: str):
    declared = int(re.search(r"\bitems=(\d+);", block).group(1))
    groups = []
    depth = 0
    pending = None
    body = []
    for line in block.splitlines(keepends=True):
        if pending is not None:
            body.append(line)
        elif depth == 1:
            match = re.match(r"\s*class Item(\d+)\s*$", line.strip("\r\n"))
            if match:
                pending = int(match.group(1))
                body = [line]
        depth += line.count("{") - line.count("}")
        if pending is not None and depth == 1 and len(body) > 1:
            groups.append((pending, "".join(body)))
            pending = None
            body = []
    return declared, groups


def test_each_terrain_has_one_caster_group_after_two_hcs_and_closed_group_indices():
    for terrain in TERRAINS:
        block = _groups_block(_text(terrain / "mission.sqm"))
        declared, groups = _group_items(block)
        assert [index for index, _ in groups] == list(range(declared))
        caster_groups = []
        hc_groups = []
        for index, body in groups:
            if 'description="CASTER (allowlist only) -- spectator";' in body:
                caster_groups.append((index, body))
            if 'forceHeadlessClient=1;' in body:
                hc_groups.append((index, body))
        assert len(caster_groups) == 1
        assert len(hc_groups) == 2
        caster_index, caster = caster_groups[0]
        assert caster_index > max(index for index, _ in hc_groups)
        caster_ids = [int(value) for value in re.findall(r"\bid=(\d+);", caster)]
        hc_ids = [int(value) for _, body in hc_groups for value in re.findall(r"\bid=(\d+);", body)]
        assert len(caster_ids) == 1
        assert caster_ids[0] > max(hc_ids)
        assert 'side="CIV";' in caster
        assert 'vehicle="Functionary1";' in caster
        assert 'player="PLAY CDG";' in caster
        assert 'forceHeadlessClient=1;' not in caster
        assert 'this setVariable [""WFBE_C_SPECTATOR_CASTER_SLOT"", 1]' in caster


def test_caster_flag_branch_and_shared_predicate_are_present():
    source = TERRAINS[0]
    constants = _text(source / "Common/Init/Init_CommonConstants.sqf")
    client = _text(source / "Client/Init/Init_Client.sqf")
    common_init = _text(source / "Common/Init/Init_Common.sqf")
    predicate = _text(source / "Common/Functions/Common_IsRealPlayer.sqf")
    real_players = _text(source / "Common/Functions/Common_RealPlayers.sqf")
    real_players_near = _text(source / "Common/Functions/Common_RealPlayersNear.sqf")

    assert 'if (isNil "WFBE_C_SPECTATOR_CASTER_SLOT") then {WFBE_C_SPECTATOR_CASTER_SLOT = 0}' in constants
    assert "WFBE_CO_FNC_IsRealPlayer = Compile preprocessFileLineNumbers" in common_init
    assert 'player getVariable ["WFBE_C_SPECTATOR_CASTER_SLOT", 0]' in client
    assert 'player setPos (getMarkerPos "GuerTempRespawnMarker")' in client
    assert "WFBE_CL_FNC_SpectatorEnter" in client
    assert "sleep 60" in client
    assert "WFBE_CO_FNC_IsRealPlayer" in real_players
    assert "WFBE_CO_FNC_IsRealPlayer" in real_players_near
    assert 'getVariable ["WFBE_C_SPECTATOR_CASTER_SLOT", 0]' in predicate
    assert 'missionNamespace getVariable ["WFBE_C_SPECTATOR_CASTER_SLOT", 0]' in predicate
    caster_branch = client[client.index("WFBE_C_SPECTATOR_CASTER_SLOT") : client.index("sideJoined = side player;")]
    assert "disableSerialization" not in caster_branch
    assert "hintSilent" not in caster_branch
