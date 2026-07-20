from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ATTACK_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AI_SetTownAttackPath.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_AI_SetTownAttackPath.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/Server_AI_SetTownAttackPath.sqf'),
)


def test_deleted_dispatch_inputs_exit_before_dereference():
    source_bytes = []
    for relative in ATTACK_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding='utf-8')
        source_bytes.append(path.read_bytes())
        team_assignment = text.index('_team = _this select 0;')
        town_assignment = text.index('_town_assigned = _this select 1;')
        null_guard = text.index('if (isNull _team || {isNull _town_assigned}) exitWith {')
        leader_read = text.index('_wp_origin = getPos (leader _team);')
        side_read = text.index('_side = (_team getVariable "wfbe_side") Call WFBE_CO_FNC_GetSideID;')
        side_guard = text.index('if (isNil "_side") exitWith {')
        assert team_assignment < null_guard
        assert town_assignment < null_guard < leader_read
        assert side_read < side_guard
        assert text.count('["WARNING", Format') >= 2
        assert text.count('Call WFBE_CO_FNC_LogContent') >= 2
    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == '__main__':
    test_deleted_dispatch_inputs_exit_before_dereference()
    print('set-town-attack-path nil guard contract: PASS')
