"""Regression contract for identity-bound structure-cap reservations.

RequestStructure reserves multi-instance structure slots before launching a
construction worker.  The worker must release the reservation it received,
not whichever reservation happens to be oldest when it finishes.
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
WORKERS = ("Construction_SmallSite.sqf", "Construction_MediumSite.sqf")


def _read(terrain, relative):
    return (ROOT / terrain / relative).read_text(encoding="utf-8-sig")


def _release_matching(entries, token):
    return [entry for entry in entries if entry[0] != token]


def test_out_of_order_completion_keeps_the_other_reservation():
    reservations = [[101, 10.0], [102, 11.0]]

    assert _release_matching(reservations, 102) == [[101, 10.0]]


def test_request_and_workers_thread_the_reservation_identity():
    request = _read(
        TERRAINS[0],
        Path("Server/PVFunctions/RequestStructure.sqf"),
    )
    request_call = re.compile(
        r'\[_structureType,_side,_pos,_dir,_index,"","",_reqPlayer,_capToken\]'
        r'\s+ExecVM'
    )
    assert "WFBE_%1_%2_PENDING_SEQ" in request
    assert "_capFreshArr + [[_capToken, time]]" in request
    assert request_call.search(request)

    for worker in WORKERS:
        source = _read(
            TERRAINS[0],
            Path("Server/Construction") / worker,
        )
        assert (
            "_capToken = if ((count _this) > 8) then {_this select 8} else {-1};"
            in source
        )
        assert "(_capEntry select 0) != _capToken" in source
        assert 'for "_capI" from 1 to (count _capArr - 1)' not in source


def test_all_terrain_mirrors_preserve_the_identity_contract():
    request_copies = []
    worker_copies = {worker: [] for worker in WORKERS}

    for terrain in TERRAINS:
        request = _read(terrain, Path("Server/PVFunctions/RequestStructure.sqf"))
        request_copies.append((ROOT / terrain / "Server/PVFunctions/RequestStructure.sqf").read_bytes())
        assert "WFBE_%1_%2_PENDING_SEQ" in request
        assert "_capFreshArr + [[_capToken, time]]" in request

        for worker in WORKERS:
            path = ROOT / terrain / "Server/Construction" / worker
            source = path.read_text(encoding="utf-8-sig")
            worker_copies[worker].append(path.read_bytes())
            assert "(_capEntry select 0) != _capToken" in source

    assert request_copies[0] == request_copies[1] == request_copies[2]
    for copies in worker_copies.values():
        assert copies[0] == copies[1] == copies[2]


if __name__ == "__main__":
    test_out_of_order_completion_keeps_the_other_reservation()
    test_request_and_workers_thread_the_reservation_identity()
    test_all_terrain_mirrors_preserve_the_identity_contract()
    print("Structure cap reservation identity contract: PASS")
