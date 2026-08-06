"""Regression contract for duplicate player defense requests.

RequestDefense receives optimistic client charges, so a server-side duplicate
reject must use the existing DefenseRequestRejected refund contract.  The
repeat ledger must be claimed before any construction dispatch and remain
byte-identical across the maintained terrain copies.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REQUEST_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestDefense.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/RequestDefense.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/PVFunctions/RequestDefense.sqf"),
)


def test_requestdefense_claims_duplicate_key_before_any_build_dispatch():
    source_bytes = []
    for relative in REQUEST_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding="utf-8-sig")
        source_bytes.append(path.read_bytes())

        guard_start = text.index('//--- isNil\'s code scope')
        claim = text.index('wfbe_defense_request_ledger', guard_start)
        reject = text.index('DefenseRequestRejected', claim)
        first_dispatch = min(
            text.index('Spawn Server_ConstructPosition'),
            text.index('Call ConstructDefense'),
        )

        assert 'WFBE_C_DEFENSE_REQUEST_REPEAT_WINDOW' in text
        assert 'isNil {' in text[guard_start:first_dispatch]
        assert guard_start < claim < reject < first_dispatch
        assert 'setVariable ["wfbe_defense_request_ledger"' in text

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == "__main__":
    test_requestdefense_claims_duplicate_key_before_any_build_dispatch()
    print("RequestDefense duplicate-request contract: PASS")
