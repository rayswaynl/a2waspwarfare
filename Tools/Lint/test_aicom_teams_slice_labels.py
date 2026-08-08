#!/usr/bin/env python3
"""Regression contract for phase labels in chunked AICOM team scans."""

from pathlib import Path
import re


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander_Teams.sqf"
)


PHASES = (
    "teams-census",
    "teams-fieldsplit",
    "teams-eligibility",
    "teams-vehicle-caps",
    "teams-buckets",
    "teams-compose",
)


def test_slice_yield_decodes_array_labels_used_by_call_sites():
    source = SOURCE.read_text(encoding="utf-8")
    helper = re.search(r"_sliceYield = \{(?P<body>.*?)\n\};", source, re.S)
    assert helper, "chunked team scan must define _sliceYield"
    body = helper.group("body")
    assert 'typeName _this == "ARRAY"' in body
    assert "_sliceLabel = _this select 0" in body
    for phase in PHASES:
        assert f'["{phase}"] Call _sliceYield;' in source
