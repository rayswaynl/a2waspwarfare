from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def read(relative):
    return (CH / relative).read_text(encoding="utf-8-sig")


def test_aicom_base_builder_marks_primary_and_forward_workers_for_commit_revalidation():
    source = read("Server/AI/Commander/AI_Commander_Base.sqf")

    assert "_aicomCommitCheck" in source
    assert source.count("_aicomCommitCheck") >= 2


def test_construction_workers_revalidate_aicom_position_after_the_build_delay():
    for worker in (
        "Server/Construction/Construction_SmallSite.sqf",
        "Server/Construction/Construction_MediumSite.sqf",
    ):
        source = read(worker)
        check_at = source.index("_aicomCommitCheck")
        create_at = source.index("_site = createVehicle")

        assert check_at < create_at
        assert "surfaceIsWater _position" in source[check_at:create_at]
        assert "WFBE_C_AICOM_BUILD_HQ_RANGE" in source[check_at:create_at]
        assert "WFBE_CO_FNC_GetSideStructures" in source[check_at:create_at]
        assert "reason=aicom-commit-position-invalid" in source
