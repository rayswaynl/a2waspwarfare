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


def _crew_vitality_decision_block(path: Path) -> str:
    """Return only the r187 invalid-slot decision, excluding earlier prune guards."""
    block = _crew_vitality_block(path)
    match = re.search(
        r"if \(!_drop && \{(?P<predicate>.*?)\}\) then \{(?P<body>.*?)\n\s*\};",
        block,
        re.DOTALL,
    )
    assert match, "r187 invalid-slot decision must remain an explicit source block"
    return match.group("body")


def _role_selection_block(path: Path) -> str:
    """Return the actual maintain-loop role-selection block from the SQF source."""
    maintain = _maintain_block(path)
    start = maintain.index("_nextRole = \"\";")
    end = maintain.index('_nextClass = "";', start)
    return maintain[start:end]


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

        # Bind the player-safe drop decision to the exact r187 crew-vitality block;
        # searching the whole prune phase can accidentally match the older driver-loss guard.
        invalid = _crew_vitality_decision_block(path)
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
    for path in USV_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        activation = source[:source.index("//=== (1) EVALUATE ACTIVATION GATE")]
        maintain = _maintain_block(path)
        selection = _role_selection_block(path)
        assert 'WFBE_C_USV_FLOTILLA_ENABLE' in activation
        assert re.search(
            r"if \(_gateActive && \{count _flotilla < _count\} && \{count _route > 0\}\) then",
            maintain,
        )
        assert selection.count("forEach _roles") == 1
        assert selection.count("forEach _flotilla") == 1
        assert selection.count("_nextRole = _candidateRole") == 1
        assert re.search(
            r"_rolePresent = false;.*?forEach _flotilla;.*?"
            r"if \(!_rolePresent && \{_nextRole == \"\"\}\) then \{_nextRole = _candidateRole\};",
            selection,
            re.DOTALL,
        )

        class_start = maintain.index('_nextClass = "";')
        spawn_start = maintain.index('if (_nextClass != "") then {', class_start)
        class_lookup = maintain[class_start:spawn_start]
        assert re.search(
            r"if \(\(_x select 0\) == _nextRole\) exitWith \{_nextClass = _x select 1\};"
            r"\s*\} forEach _loadouts;",
            class_lookup,
        )

        # The actual source branch selected above creates one static role per maintain
        # tick; no detached Python list model can pass if this call is removed or moved.
        spawn = maintain[spawn_start:]
        assert spawn.count("createVehicle [_nextClass") == 1
        assert spawn.count("WFBE_CO_FNC_CreateVehicle") == 1
