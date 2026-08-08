"""Regression contract for deadspawn cleanup at terminal game-over."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def _read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def _block_after(text: str, marker: str, start: int = 0) -> tuple[int, int, str]:
    marker_start = text.index(marker, start)
    open_brace = text.index("{", marker_start)
    depth = 0
    for index in range(open_brace, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return marker_start, index, text[open_brace : index + 1]
    raise AssertionError(f"unclosed SQF block after {marker!r}")


def _assert_terminal_cleanup(
    source: str,
    *,
    wait_marker: str,
    handoff_marker: str,
    unit: str,
    wait_is_block: bool = True,
) -> None:
    if wait_is_block:
        wait_start, wait_end, _ = _block_after(source, wait_marker)
    else:
        wait_start = source.index(wait_marker)
        wait_end = wait_start + len(wait_marker)
    terminal_marker = "if (gameOver) exitWith {"
    assert terminal_marker in source[wait_end:], "terminal game-over cleanup exit is missing"
    terminal_start = source.index(terminal_marker, wait_end)
    terminal_end = _block_after(source, terminal_marker, terminal_start)[1]
    handoff_start = source.index(handoff_marker, terminal_end)
    body = source[terminal_start : terminal_end + 1]

    assert wait_start < terminal_start < terminal_end < handoff_start
    assert f"_deadspawnGuardApplied && {{alive {unit}}}" in body
    assert f"{unit} setCaptive false;" in body
    assert f"{unit} allowDamage true;" in body
    assert "addMagazine" not in body
    assert "addWeapon" not in body
    assert "setPos" not in body


def test_advanced_respawn_cleans_guard_before_terminal_exit() -> None:
    source = _read(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/AI_AdvancedRespawn.sqf"
    )
    _assert_terminal_cleanup(
        source,
        wait_marker="while {_i > 0} do {",
        handoff_marker="if (isPlayer(_respawnedUnit) || !(alive _respawnedUnit)) then {",
        unit="_respawnedUnit",
    )


def test_squad_respawn_cleans_guard_before_terminal_exit() -> None:
    source = _read(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/AI_SquadRespawn.sqf"
    )
    _assert_terminal_cleanup(
        source,
        wait_marker="sleep _rd;",
        handoff_marker="if (isPlayer _leader || !(alive _leader)) then {",
        unit="_leader",
        wait_is_block=False,
    )


def test_respawn_terminal_cleanup_is_mirrored() -> None:
    advanced = _read(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/AI_AdvancedRespawn.sqf"
    )
    squad = _read(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/AI_SquadRespawn.sqf"
    )
    for terrain in ("takistan", "zargabad"):
        assert _read(
            f"Missions_Vanilla/[61-2hc]warfarev2_073v48co.{terrain}/Server/AI/AI_AdvancedRespawn.sqf"
        ) == advanced
        assert _read(
            f"Missions_Vanilla/[61-2hc]warfarev2_073v48co.{terrain}/Server/AI/AI_SquadRespawn.sqf"
        ) == squad
