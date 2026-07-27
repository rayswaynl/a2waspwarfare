#!/usr/bin/env python3
"""Regression contract for cooperative AICOM team-founding scans."""

from pathlib import Path


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander_Teams.sqf"
)


def test_chunked_founding_labels_and_yields_each_expensive_scan_phase():
    """The flag-on path must not leave candidate and vehicle scans in one frame."""
    source = SOURCE.read_text(encoding="utf-8")

    for phase in (
        "teams-census",
        "teams-fieldsplit",
        "teams-eligibility",
        "teams-vehicle-caps",
        "teams-buckets",
        "teams-compose",
    ):
        assert f'["{phase}"] Call _sliceYield;' in source


def test_chunk_audit_rows_identify_the_completed_phase():
    source = SOURCE.read_text(encoding="utf-8")

    assert '_sliceLabel = "";' in source
    assert 'if (typeName _this == "STRING") then {_sliceLabel = _this};' in source
    assert 'Format["phase:%1", _sliceLabel]' in source


if __name__ == "__main__":
    test_chunked_founding_labels_and_yields_each_expensive_scan_phase()
    test_chunk_audit_rows_identify_the_completed_phase()
