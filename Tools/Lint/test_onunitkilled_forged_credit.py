"""Regression checks for the RequestOnUnitKilled forged/replayed-kill-credit fix.

RequestOnUnitKilled.sqf is the server-authoritative on-kill pipeline (bounty, score,
streaks, stats, GUER tech unlocks, teamkill penalty, corpse GC). PR #209 validated the
payload SHAPE ([killed, killer, sideId] array/object/scalar checks) but never validated
that the reported kill actually happened. A well-formed but fabricated triple could still
mint full bounty/score/AI-commander funds, and a forger could REPLAY the same real corpse
to re-mint credit on every resend.

The fix (flag-gated behind WFBE_C_SEC_HARDENING, default 0 = byte-identical legacy
behavior) re-derives from server-authoritative state instead of trusting the claim:
  - the reported victim must actually be dead right now (rejects a still-ALIVE "killed"
    claim outright);
  - each corpse settles kill credit at most once (one-shot latch, same idiom as
    Server_OnHQKilled.sqf's wfbe_hq_killed_done), closing the repeat-mint/replay attack.

This test locks that contract so a future edit cannot silently drop the alive check or
the one-shot latch, and cannot reintroduce a payload-crediting path that runs BEFORE the
latch is set.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
KILL_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestOnUnitKilled.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/RequestOnUnitKilled.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/PVFunctions/RequestOnUnitKilled.sqf'),
)


def test_forged_and_replayed_kill_credit_is_rejected():
    source_bytes = []
    for relative in KILL_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding='utf-8-sig')
        source_bytes.append(path.read_bytes())

        # The hardening gate is a local flag var, read once from the shared kill-switch.
        gate = text.index(
            '_secHardening = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;'
        )
        assert '"_secHardening"' in text[:gate]  # declared Private

        # A claimed-dead unit that is still alive is rejected - this is the core
        # fabrication guard (audit finding: a well-formed but fabricated triple
        # otherwise mints full credit for a unit that was never killed).
        alive_guard = text.index('if (_secHardening && {alive _killed}) exitWith {')
        assert gate < alive_guard

        # One-shot per-corpse latch: reject if this exact corpse already settled
        # credit (closes the repeat-mint/replay attack even if a single fabrication
        # against a genuinely-dead unit remains possible - documented PR residual).
        latch_check = text.index(
            'if (_secHardening && {_killed getVariable ["wfbe_killcredit_settled", false]}) exitWith {'
        )
        assert alive_guard < latch_check

        latch_set = text.index(
            'if (_secHardening) then {_killed setVariable ["wfbe_killcredit_settled", true, true];};'
        )
        assert latch_check < latch_set

        # The latch must be armed BEFORE any funds/score/stats credit path runs -
        # spot-check against the first bounty award site and the GUER tech-unlock
        # counter, both of which must sit strictly after the latch write.
        guer_tech_credit = text.index('WFBE_GUER_PLAYER_KILLS = (missionNamespace getVariable')
        bounty_award = text.index('_srvBounty = [_killed_type, false] Call WFBE_CO_FNC_ComputeKillBounty;')
        assert latch_set < guer_tech_credit < bounty_award

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == '__main__':
    test_forged_and_replayed_kill_credit_is_rejected()
    print('RequestOnUnitKilled forged/replayed kill-credit contract: PASS')
