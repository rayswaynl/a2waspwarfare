"""Regression contract for the AICOM service-latch recovery watchdog.

The HC-owned service worker publishes ``wfbe_aicom_svcstate`` to reserve a
group.  The server-side recovery watchdog can only reclaim an orphaned
reservation when it sees the associated deadline, so both values must cross
the HC-to-server boundary.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVICE_PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMServiceTick.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_AICOMServiceTick.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_AICOMServiceTick.sqf",
)

DEADLINE_PUBLISH = (
    '_team setVariable ["wfbe_aicom_svcdeadline", time + '
    '(missionNamespace getVariable ["WFBE_C_AICOM_SVC_TIMEOUT", 300]), true];'
)


def test_service_deadline_is_published_with_the_enroute_latch() -> None:
    payloads = []
    for path in SERVICE_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        payloads.append(path.read_bytes())

        assert DEADLINE_PUBLISH in source, (
            "server latch-reclaim cannot observe the HC-owned service deadline: %s" % path
        )
        assert source.index(DEADLINE_PUBLISH) > source.index(
            '_team setVariable ["wfbe_aicom_svcstate", "enroute", true];'
        ), "deadline must be published when the service latch is acquired: %s" % path

    assert payloads[0] == payloads[1] == payloads[2], "service helper mirrors differ"
