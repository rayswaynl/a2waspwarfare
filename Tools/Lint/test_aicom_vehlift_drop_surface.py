"""Regression contract for AICOM vehicle-lift drop-point selection.

The deep-drop search must shorten toward the objective when a dry candidate is
not flat.  A raw candidate is allowed only at the depth-zero terminal fallback;
otherwise a sloped/occupied drop point can release the lifted vehicle into an
unusable position.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VEHLIFT_FILES = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirLeg.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_AICOMAirLeg.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_AICOMAirLeg.sqf"
    ),
)


def test_nonflat_dry_vehicle_drop_shortens_before_terminal_fallback() -> None:
    for relative_path in VEHLIFT_FILES:
        text = (ROOT / relative_path).read_text(encoding="utf-8-sig")
        region = text.split("_tryDepth = _depth;", 1)[1].split(
            "//--- SLING the vehicle below the transport.", 1
        )[0]

        assert "if (count _fe > 0) then {_vehDrop = _fe; _ok = true} else {" in region
        assert "if (_tryDepth <= 0) then {_vehDrop = _candPos; _ok = true};" in region
        assert (
            "if (count _fe > 0) then {_vehDrop = _fe} else {_vehDrop = _candPos}; _ok = true;"
            not in region
        ), f"positive-depth non-flat fallback still accepts a raw drop point in {relative_path}"
