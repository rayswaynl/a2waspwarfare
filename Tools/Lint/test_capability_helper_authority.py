"""Regression checks for the shared capability-token helper (WFBE_SE_FNC_MintCapability /
WFBE_SE_FNC_ConsumeCapability).

Generalises the mint/consume idiom already hand-rolled in Init_IcbmTel.sqf and Support_FPV.sqf:
a server-minted, purpose-bound, one-shot token privately delivered to the requesting player's
owning client, later atomically compared-and-consumed before any side effect. This test locks
the invariants a future edit must not silently break:
  - the capability is cleared INSIDE the atomic (isNil {}) block, strictly before the function
    returns "ok" -- so no caller side effect can ever run before the clear;
  - the mint reply is sent via the private single-target helper (WFBE_CO_FNC_SendToClient), never
    a broadcast to the shared bus;
  - the UID used for both storage and reply is always derived server-side via getPlayerUID on the
    player object, never accepted as a client-supplied string;
  - Consume distinguishes and reports all four failure modes (missing / malformed / mismatched /
    expired) the precedents established.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MINT_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_MintCapability.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_MintCapability.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/Server_MintCapability.sqf'),
)
CONSUME_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_ConsumeCapability.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_ConsumeCapability.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/Server_ConsumeCapability.sqf'),
)
INIT_SERVER_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Init/Init_Server.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Init/Init_Server.sqf'),
)


def test_mint_derives_uid_server_side_and_replies_privately_only():
    source_bytes = []
    for relative in MINT_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding='utf-8-sig')
        source_bytes.append(path.read_bytes())

        # The UID is derived from the player object, never taken from the call arguments.
        derive = text.index('_uid = getPlayerUID _player;')
        assert '_uid = _this select' not in text

        # The reply goes out via the private single-target helper -- never publicVariable /
        # SendToClients (the shared, all-client bus) and never a raw publicVariableClient here
        # (that plumbing lives inside WFBE_CO_FNC_SendToClient itself).
        reply = text.index('Call WFBE_CO_FNC_SendToClient;')
        assert derive < reply
        assert 'WFBE_CO_FNC_SendToClients' not in text
        assert 'publicVariableClient' not in text
        assert 'publicVariable ' not in text

        # Rate limiting only gates the FRESH-mint path; reuse of an already-valid capability must
        # stay ungated (a throttle on reuse would let a flooder deny the legitimate owner's own
        # retries -- see the doc comment).
        reuse_branch = text.index('if (_capValid) then {')
        fresh_branch = text.index('missionNamespace setVariable [_mintKey, _now];')
        assert reuse_branch < fresh_branch
        reuse_slice = text[reuse_branch:fresh_branch]
        assert 'mint_last' not in reuse_slice  # no rate stamp write on the reuse path

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


def test_consume_clears_before_returning_ok_and_reports_all_failure_modes():
    source_bytes = []
    for relative in CONSUME_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding='utf-8-sig')
        source_bytes.append(path.read_bytes())

        # The four failure modes the precedents established must all be reachable.
        for reason in ('"missing"', '"malformed"', '"mismatched"', '"expired"'):
            assert reason in text

        # The clear happens strictly BEFORE the "ok" state is set, and both happen inside the
        # same isNil {} atomic block as the token comparison.
        atomic_open = text.index('isNil {')
        compare = text.index('if (_token != (_cap select 0)) then {')
        clear = text.index('missionNamespace setVariable [_capKey, []];')
        ok_state = text.index('_state = "ok"')
        assert atomic_open < compare < clear < ok_state

        # A mismatched token must NOT clear the stored capability (it may belong to a legitimate
        # in-flight request racing this one) -- the clear line must not appear before the
        # mismatch branch resolves.
        mismatch_state = text.index('_state = "mismatched";')
        assert compare < mismatch_state < clear

        # The function returns false on every non-"ok" state and true only on a real consume.
        assert '[false, _state]' in text
        assert '[true, ""]' in text

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


def test_capability_helper_registered_identically_in_init_server():
    source_bytes = []
    for relative in INIT_SERVER_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding='utf-8-sig')
        source_bytes.append(path.read_bytes())

        assert 'WFBE_SE_FNC_MintCapability = Compile preprocessFileLineNumbers "Server\\Functions\\Server_MintCapability.sqf";' in text
        assert 'WFBE_SE_FNC_ConsumeCapability = Compile preprocessFileLineNumbers "Server\\Functions\\Server_ConsumeCapability.sqf";' in text

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == '__main__':
    test_mint_derives_uid_server_side_and_replies_privately_only()
    test_consume_clears_before_returning_ok_and_reports_all_failure_modes()
    test_capability_helper_registered_identically_in_init_server()
    print('Capability-helper mint/consume authority contract: PASS')
