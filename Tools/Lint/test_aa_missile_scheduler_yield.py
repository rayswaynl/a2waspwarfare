from pathlib import Path


MISSILE_GUIDANCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Common"
    / "Functions"
    / "Common_HandleAAMissiles.sqf"
)
SEAD_GUIDANCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Common"
    / "Functions"
    / "Common_HandleSEADMissile.sqf"
)


def test_aa_missile_guidance_loop_yields_between_steering_ticks():
    """Each Fired EH worker must yield while its missile remains alive."""
    source = MISSILE_GUIDANCE.read_text(encoding="utf-8-sig")
    loop = source.split("While {!isNull _rkt} do {", 1)[1].split("scopeName \"OUT\"", 1)[0]
    assert "sleep 0.01;" in loop


def test_sead_missile_guidance_loop_yields_between_steering_ticks():
    """The optional SEAD Fired EH worker must obey the same scheduler rule."""
    source = SEAD_GUIDANCE.read_text(encoding="utf-8-sig")
    loop = source.split("While {!isNull _rkt && {!isNull _nearest} && {alive _nearest}} do {", 1)[1]
    assert "sleep 0.01;" in loop
