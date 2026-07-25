"""Regression checks for the ATTACK_WAVE_INIT forged-supply fix.

Server_AttackWave.sqf's "ATTACK_WAVE_INIT" PVEH used to feed the client-
supplied _supply figure (carried in the ATTACK_WAVE_INIT payload from
Common_AttackWaveActivate.sqf) straight into the heavy-attack discount/
duration formula - docs/design/ATTACK-WAVE-PRICE-MODIFIER-AUDIT-2026-07-03.md
flagged this "forged supply input" as an open gap. The fix overwrites the
client-sent _supply with a server-derived value (`_side call GetSideSupply`,
the same source AttackWave.sqf's own full-supply debit already trusts)
before the discount formula reads it. This test locks that contract so a
future edit cannot reintroduce the client-trusted figure into the formula.

Note: this test only covers the supply-forgery half of the ATTACK_WAVE_INIT
finding. The requester/side-membership half (binding the activation to the
clicking player's own side) is covered separately by the sibling hardening
branch for the ATTACK_WAVE_DETAILS handler - see this PR's body for the
composition note.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ATTACKWAVE_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AttackWave.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_AttackWave.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/Server_AttackWave.sqf'),
)


def test_supply_is_server_derived_before_discount_formula():
    source_bytes = []
    for relative in ATTACKWAVE_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding='utf-8-sig')
        source_bytes.append(path.read_bytes())

        # The spawn body still binds the client-sent payload slot into _supply
        # first (it has to - it is _this select 0)...
        client_bind = text.index('_supply = _this select 0;')

        # ...but that value is immediately overwritten with a server-derived
        # read before the discount formula ever consults it.
        server_derive = text.index('_supply = _side call GetSideSupply;')
        assert client_bind < server_derive

        discount_formula = text.index(
            '_discountPercentage = 0.4 + ((WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT - _supply) * (1/50000));'
        )
        assert server_derive < discount_formula

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == '__main__':
    test_supply_is_server_derived_before_discount_formula()
    print('ATTACK_WAVE_INIT server-derived supply contract: PASS')
