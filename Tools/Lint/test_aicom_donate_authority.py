"""Regression checks for the AIComDonate C4-drain fix.

RequestAIComDonate.sqf used to trust the client-supplied _donorTeam param
(_this select 1) as the wallet to debit - any client could name a different
team as donor and drain that team's funds into the AI commander wallet. The
fix derives the donor team server-side as `group _donor` (mirrors the
RequestFundsTransfer N1 pattern) and only uses the client-claimed team to
detect + log a forged-team mismatch. This test locks that contract so a
future edit cannot reintroduce a client-trusted team into the debit/funds
-check path.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DONATE_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestAIComDonate.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/RequestAIComDonate.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/PVFunctions/RequestAIComDonate.sqf'),
)


def test_donor_team_is_server_derived_not_client_claimed():
    source_bytes = []
    for relative in DONATE_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding='utf-8-sig')
        source_bytes.append(path.read_bytes())

        # The client payload's team slot is captured into an advisory-only
        # variable, never into the variable that actually gates the debit.
        claimed_assignment = text.index('_claimedTeam = _this select 1;')
        assert '_donorTeam = _this select 1;' not in text

        # The authoritative team is derived from the donor object itself.
        derive = text.index('_donorTeam = group _donor;')
        assert claimed_assignment < derive

        null_guard = text.index('if (isNull _donorTeam) exitWith {')
        assert derive < null_guard

        # A forged-team payload is detected and logged, never trusted.
        mismatch_check = text.index('if (_claimedTeam != _donorTeam) then {')
        assert null_guard < mismatch_check
        mismatch_block = text[mismatch_check: mismatch_check + 400]
        assert 'forged-team violation' in mismatch_block
        assert 'Call WFBE_CO_FNC_AICOMLog' in mismatch_block

        # The funds check and the actual debit/credit both key off the
        # server-derived team - never the client-claimed one.
        funds_check = text.index('_teamFunds = _donorTeam getVariable "wfbe_funds";')
        debit = text.index('[_donorTeam, -_amount] Call ChangeTeamFunds;')
        credit = text.index('[_side, _amount] Call ChangeAICommanderFunds;')
        assert mismatch_check < funds_check < debit < credit
        assert '_claimedTeam' not in text[mismatch_check + 400:]

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == '__main__':
    test_donor_team_is_server_derived_not_client_claimed()
    print('AIComDonate server-derived donor team contract: PASS')
