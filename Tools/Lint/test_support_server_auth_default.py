from pathlib import Path


CONSTANTS = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf"
)


def test_tactical_support_server_authorization_is_armed_by_default():
    constants = CONSTANTS.read_text(encoding="utf-8-sig")

    assert (
        'if (isNil "WFBE_C_SUPPORT_SERVER_AUTH") then {WFBE_C_SUPPORT_SERVER_AUTH = 1};'
        in constants
    )


if __name__ == "__main__":
    test_tactical_support_server_authorization_is_armed_by_default()
