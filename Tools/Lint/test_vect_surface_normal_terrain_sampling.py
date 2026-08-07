from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Functions" / "Common_VectSurfaceNormal.sqf"


def executable_sqf(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//.*", "", text)


def test_surface_normal_samples_terrain_with_an_a2_safe_probe():
    code = executable_sqf(SOURCE.read_text(encoding="utf-8"))

    assert "getTerrainHeightASL" not in code
    assert '"Sign_sphere10cm_EP1" createVehicleLocal [0, 0, 0]' in code
    assert "_probe setPos [_center select 0, _center select 1, 0]" in code
    assert "_h0 = (getPosASL _probe) select 2" in code
    assert "deleteVehicle _probe" in code
