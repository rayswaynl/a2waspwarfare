#!/usr/bin/env python3
"""Regression contract for the one-shot AICOM BOOT operator snapshot.

The line is an early deploy sanity check, so it must report the same population-tier
AI cap that the founding/production gates enforce and the configured HC slot count,
never the unrelated HC-owned group registry.
"""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
COMMANDER = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/AI/Commander/AI_Commander.sqf"
)


def boot_snapshot_code() -> str:
    text = mask_comments(COMMANDER.read_text(encoding="utf-8-sig"))
    start = text.index("[AICOM BOOT]")
    return text[start - 600 : start + 800]


def resolve_tier_cap(cap_tiers: list[int], pop_tier: int, fallback: int) -> int:
    """Mirror the cap resolution shared by founding, production, and BOOT telemetry."""
    if len(cap_tiers) < 1:
        cap_tiers = [fallback]
    cap_index = max(pop_tier, 0)
    cap_last = len(cap_tiers) - 1
    if cap_index > cap_last:
        cap_index = cap_last
    return cap_tiers[cap_index]


def test_boot_snapshot_reports_the_active_tier_cap() -> None:
    boot = boot_snapshot_code()

    assert 'missionNamespace getVariable ["WFBE_C_TOTAL_AI_MAX_BY_TIER", [140,130,100,80]]' in boot
    assert 'if ((count _aiCapTiers) < 1) then {_aiCapTiers = [missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TOTAL_AI_MAX", 140]]};' in boot
    assert '_aiCapTierIndex = (missionNamespace getVariable ["WFBE_PopTier", 0]) max 0;' in boot
    assert 'if (_aiCapTierIndex > _aiCapTierLast) then {_aiCapTierIndex = _aiCapTierLast};' in boot
    assert '_aiMax = _aiCapTiers select _aiCapTierIndex;' in boot
    assert 'aiMax=%4 startFunds=%5", str _side, _grpCount, _hcCount, _aiMax,' in boot


def test_tier_cap_resolution_matches_founding_and_production_edges() -> None:
    assert resolve_tier_cap([180, 170, 150, 120], 0, 140) == 180
    assert resolve_tier_cap([180, 170, 150, 120], 99, 140) == 120
    assert resolve_tier_cap([180, 170, 150, 120], -1, 140) == 180
    assert resolve_tier_cap([], 0, 140) == 140


def test_boot_snapshot_reports_configured_hc_slots_not_hc_groups() -> None:
    boot = boot_snapshot_code()

    assert 'missionNamespace getVariable ["WFBE_C_HC_SLOTS", 0]' in boot
    assert 'WFBE_HEADLESSCLIENTS_ID' not in boot


if __name__ == "__main__":
    test_boot_snapshot_reports_the_active_tier_cap()
    test_tier_cap_resolution_matches_founding_and_production_edges()
    test_boot_snapshot_reports_configured_hc_slots_not_hc_groups()
