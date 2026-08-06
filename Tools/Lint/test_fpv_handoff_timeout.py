#!/usr/bin/env python3
"""Regression contract for the FPV pilot-seat handoff window.

The client preflight must not abandon a launch before the server-side
replication wait has expired.  Both sides are bounded and uncharged until the
server accepts the purchase, so the client window must cover the server
window rather than being a shorter competing timeout.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

CLIENT = Path("Client/Module/FPV/fpv.sqf")
SERVER = Path("Server/Support/Support_FPV.sqf")


def read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


def read_bytes(root: Path, relative: Path) -> bytes:
    return (root / relative).read_bytes()


def deadline_seconds(code: str, clock: str) -> int:
    match = re.search(
        rf"_seatDeadline\s*=\s*{clock}\s*\+\s*(\d+)\s*;",
        code,
    )
    if match is None:
        raise AssertionError("missing %s-side FPV seat deadline" % clock)
    return int(match.group(1))


class FpvHandoffTimeoutTests(unittest.TestCase):
    def test_client_preflight_covers_server_replication_window(self) -> None:
        client = read(MAINTAINED_ROOTS[0], CLIENT)
        server = read(MAINTAINED_ROOTS[0], SERVER)
        client_window = deadline_seconds(client, "time")
        server_window = deadline_seconds(server, "diag_tickTime")
        self.assertGreaterEqual(
            client_window,
            server_window,
            "client must not delete the drone before the server can observe pilot seating",
        )

    def test_client_handoff_file_is_mirrored(self) -> None:
        source = read_bytes(MAINTAINED_ROOTS[0], CLIENT)
        self.assertEqual(
            source.count(b"\n"),
            source.count(b"\r\n"),
            "Chernarus FPV client source must remain CRLF-only",
        )
        for mirror in MAINTAINED_ROOTS[1:]:
            self.assertEqual(
                source,
                read_bytes(mirror, CLIENT),
                "%s drifted from the Chernarus source in %s" % (CLIENT, mirror.name),
            )


if __name__ == "__main__":
    unittest.main()
