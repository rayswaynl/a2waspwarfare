import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
USV_PATHS = (
    REPO_ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_USVFlotilla.sqf",
    REPO_ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Server_USVFlotilla.sqf",
    REPO_ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Server_USVFlotilla.sqf",
)


def _crew_vitality_block(path: Path) -> str:
    source = path.read_text(encoding="utf-8-sig")
    prune_start = source.index("//=== (2) PRUNE")
    maintain_start = source.index("//=== (3) MAINTAIN")
    prune = source[prune_start:maintain_start]
    marker = "//--- r187 crew-vitality:"
    block_start = prune.index(marker)
    block_end = prune.index("//--- Gate closed", block_start)
    return prune[block_start:block_end]


def _prune_block(path: Path) -> str:
    source = path.read_text(encoding="utf-8-sig")
    prune_start = source.index("//=== (2) PRUNE")
    maintain_start = source.index("//=== (3) MAINTAIN")
    return source[prune_start:maintain_start]


def _maintain_block(path: Path) -> str:
    source = path.read_text(encoding="utf-8-sig")
    return source[source.index("//=== (3) MAINTAIN"):]


def _prune_decision(*, static_alive, gunner_alive, gunner_seated, boat_player, static_player):
    """Small executable contract for the source-level invalid-slot decision."""
    invalid = not static_alive or not gunner_alive or not gunner_seated
    return invalid and not boat_player and not static_player


def _first_missing_role(roles, entries):
    """Model the bounded one-role refill selection in the SQF maintain block."""
    present = {entry[0] for entry in entries}
    for role in roles:
        if role not in present:
            return role
    return roles[len(entries) % len(roles)]


def test_usv_prune_recycles_bare_or_unseated_weapon_crew_slots():
    for path in USV_PATHS:
        block = _crew_vitality_block(path)

        assert re.search(r"isNull\s+_eStatic", block)
        assert re.search(r"alive\s+_eStatic", block)
        assert re.search(r"isNull\s+_eGunner", block)
        assert re.search(r"alive\s+_eGunner", block)
        assert "gunner _eStatic" in block
        assert "crew _eBoat" in block
        assert "crew _eStatic" in block
        assert "isPlayer _x" in block
        assert 'weapon_crew_lost' in block

        # The invalid-slot predicate must cause a real state transition, not merely
        # mention the fields in a diagnostic/comment.  This is the executable branch
        # that makes the existing maintain loop eligible to refill the role.
        assert re.search(
            r"if \(!_drop && \{.*?\}\) then \{(?P<body>.*?)\n\s*\};",
            block,
            re.DOTALL,
        ).group("body").count('_drop = true; _reason = "weapon_crew_lost";') == 1


def test_usv_prune_decision_is_player_safe_and_reaches_refillable_drop():
    for path in USV_PATHS:
        prune = _prune_block(path)
        assert 'if ((missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_ENABLE", 0]) != 1)' not in prune

        # A broken, unoccupied slot is dropped for the next maintain pass; the same
        # broken slot remains registered while either hull is player-occupied.
        assert _prune_decision(
            static_alive=True,
            gunner_alive=False,
            gunner_seated=False,
            boat_player=False,
            static_player=False,
        )
        assert not _prune_decision(
            static_alive=True,
            gunner_alive=False,
            gunner_seated=False,
            boat_player=True,
            static_player=False,
        )
        assert not _prune_decision(
            static_alive=True,
            gunner_alive=False,
            gunner_seated=False,
            boat_player=False,
            static_player=True,
        )
        assert not _prune_decision(
            static_alive=True,
            gunner_alive=True,
            gunner_seated=True,
            boat_player=False,
            static_player=False,
        )

        invalid = re.search(
            r"if \(!_drop && \{.*?\}\) then \{(?P<body>.*?)\n\s*\};",
            prune,
            re.DOTALL,
        ).group("body")
        assert re.search(
            r"if \(!_boatHasPlayer && !_staticHasPlayer\) then \{\s*_drop = true;",
            invalid,
            re.DOTALL,
        )


def test_usv_prune_retains_player_occupied_drop_for_later_cleanup():
    for path in USV_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        prune_start = source.index("//=== (2) PRUNE")
        maintain_start = source.index("//=== (3) MAINTAIN")
        prune = source[prune_start:maintain_start]
        drop_start = prune.index("if (_drop) then {")
        movement_marker = "//--- Movement only while the gate is active"
        drop = prune[drop_start:prune.index(movement_marker, drop_start)]

        player_safe = re.search(
            r"if \(!_boatHasPlayer && !_staticHasPlayer\) then \{(?P<delete>.*?)\}"
            r"\s*else\s*\{(?P<occupied>.*?)\}",
            drop,
            re.DOTALL,
        )
        assert player_safe, "drop teardown must branch on player occupancy"
        assert re.search(r"_kept\s*=\s*_kept\s*\+\s*\[_entry\];", player_safe.group("occupied")), (
            "player-occupied drop must stay registered until a later prune can clean it up"
        )
        assert "deleteVehicle" not in player_safe.group("occupied")
        assert "deleteGroup" not in player_safe.group("occupied")


def test_usv_maintain_refills_one_missing_role_per_tick():
    roles = ["AA", "ROCKET", "HMG"]
    entries = [("AA", "boat-a"), ("HMG", "boat-h")]
    selected = _first_missing_role(roles, entries)
    assert selected == "ROCKET"
    entries.append((selected, "replacement"))
    assert len(entries) == 3
    assert _first_missing_role(roles, entries) in roles

    for path in USV_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        activation = source[:source.index("//=== (1) EVALUATE ACTIVATION GATE")]
        maintain = _maintain_block(path)
        assert 'WFBE_C_USV_FLOTILLA_ENABLE' in activation
        assert re.search(
            r"if \(_gateActive && \{count _flotilla < _count\} && \{count _route > 0\}\) then",
            maintain,
        )
        assert "_nextRole = \"\";" in maintain
        assert "if (!_rolePresent && {_nextRole == \"\"}) then" in maintain
        assert "if (_nextRole == \"\") then" in maintain
        assert maintain.count("WFBE_CO_FNC_CreateVehicle") == 1
