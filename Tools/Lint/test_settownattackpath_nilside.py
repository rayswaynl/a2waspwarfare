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
        # RECONCILED: this test pinned #1203's original simple guard (isNil "_side" exitWith).
        # #1209 layered fallback-leader recovery on top - a nil/negative side no longer exits
        # immediately, it first tries to recover the side from the team's live leader before
        # giving up. Pin the CURRENT merged shape instead: the recovery block (isNil OR
        # negative-side -> try leader) must run between the side read and the final guard, and
        # the final guard itself now also checks the negative-side case, not just isNil.
        recovery_guard = text.index('if (isNil "_side" || {_side < 0}) then {')
        fallback_leader_read = text.index('_fallbackLeader = leader _team')
        side_guard = text.index('if (isNil "_side" || {_side < 0}) exitWith {')
        assert team_assignment < null_guard
        assert town_assignment < null_guard < leader_read
        assert side_read < recovery_guard < fallback_leader_read < side_guard
        assert text.count('["WARNING", Format') >= 2
        assert text.count('Call WFBE_CO_FNC_LogContent') >= 2
    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == '__main__':
    test_deleted_dispatch_inputs_exit_before_dereference()
    print('set-town-attack-path nil guard contract: PASS')
