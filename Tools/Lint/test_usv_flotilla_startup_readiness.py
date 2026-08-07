from pathlib import Path


SOURCE = (
    Path(__file__).parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "Server_USVFlotilla.sqf"
)


def _startup_gate(text: str) -> str:
    start = text.index("Server_USVFlotilla.sqf : USV flotilla feature ENABLED")
    end = text.index("//------------------------------------------------------------------------------------\n//--- ONE-TIME", start)
    return text[start:end]


def test_usv_startup_gate_is_bounded_and_yields() -> None:
    gate = _startup_gate(SOURCE.read_text(encoding="utf-8"))

    assert "_usvTownDeadline = diag_tickTime + 90;" in gate
    assert "sleep 0.25;" in gate
    assert "diag_tickTime >= _usvTownDeadline" in gate
    assert "waitUntil { !isNil \"townInit\" && townInit };" not in gate
    assert "waitUntil { !isNil \"towns\" && {count towns > 0} };" not in gate


def test_usv_startup_failure_is_terminal_and_receipted() -> None:
    gate = _startup_gate(SOURCE.read_text(encoding="utf-8"))

    assert "_usvTownInitReady = !isNil \"townInit\" && {townInit};" in gate
    assert "_usvTownsReady = !isNil \"towns\" && {count towns > 0};" in gate
    assert "USVFLOTILLA|STARTUP_TIMEOUT" in gate
    assert "USVFLOTILLA|STARTUP_ABORT" in gate
    assert "if (!_usvTownInitReady || {!_usvTownsReady}) exitWith" in gate
    assert "WFBE_GameOver" in gate


if __name__ == "__main__":
    test_usv_startup_gate_is_bounded_and_yields()
    test_usv_startup_failure_is_terminal_and_receipted()
