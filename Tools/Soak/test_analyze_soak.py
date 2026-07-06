"""Regression tests for analyze_soak.py (canonical Soak API).

Salvaged from PR #139's intent (a synthetic-RPT KPI regression test) but
rewritten against the current canonical analyzer: the merged tool exposes a
`Soak` class fed by `ingest_server(lines)`, not the `analyze([...]).row()`
schema #139 targeted. These asserts pin the parse -> KPI path for the AICOM
dispatch/arrival counters, the dist-bucketed arrival table, the median
dispatch->arrival, kills, MHQ verbs, WASPSCALE perf + v2-EXT war-state, and the
Build 86 log families (SCUD/skin/road/EASA), so a future refactor that breaks
line parsing fails loudly.

stdlib only (unittest). Run: python -m unittest Tools/Soak/test_analyze_soak.py
or simply `python Tools/Soak/test_analyze_soak.py`.
"""

import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import analyze_soak


# Synthetic server RPT covering the parse paths the analyzer scores. Two teams
# so the dist buckets and median pairing are exercised. Ticks are minutes.
SAMPLE = """\
MISSINIT: missionName=warfare, worldName=Chernarus, isMultiplayer=true, isServer=true, isDedicated=true
AICOMSTAT|v2|EVENT|WEST|10|ASSAULT_DISPATCH|team=A 1-1|town=Elektro|dist=300|reissue=false
AICOMSTAT|v2|EVENT|WEST|13|ASSAULT_ARRIVED|team=A 1-1|town=Elektro|dist=20|elapsed=180
AICOMSTAT|v2|EVENT|EAST|11|ASSAULT_DISPATCH|team=B 2-1|town=Cherno|dist=2500|reissue=false
AICOMSTAT|v2|EVENT|EAST|20|ASSAULT_DISPATCH|team=B 2-1|town=Cherno|dist=2500|reissue=true
AICOMSTAT|v1|MHQRELOC|WEST|14|DEPLOYED|reason=front|pos=[100,200,0]
AICOMSTAT|v1|MHQRELOC|EAST|15|ABORT|reason=ringed
WASPSTAT|v1|1|KILL|||WEST|EAST|BMP2|120|shot|hw=|vc=|t=800
WASPSTAT|v1|2|KILL|||EAST|WEST|T72|90|shot|hw=|vc=|t=810
WASPSTAT|v1|3|KILL|||WEST|GUER|UAZ|40|shot|hw=|vc=|t=820
WASPSCALE|v2|12|tier=2|players=4|AI_W=120|AI_E=118|AI_GUER=30|AI_TOT=268|groups=90|fps=42|map=Chernarus|build=build86-cmdcon42|hc_fps=48|townsW=3|townsE=2|townsG=1|postW=spearhead|postE=laststand|disp=2|arrv=1|recov=5|mhqrel=1|patr=2|sort=1|telW=1|telE=2|terr=none|fpsmin=31|hc2fps=50|grpW=45|grpE=44
[WFBE (SKIN)] B6 COMPLETE: player='Ray' class='US_Soldier'
Support_ScudStrike.sqf : [WEST] denied -- cooldown (120s left).
GUI_Menu_EASA.sqf: Player requested EASA loadout.
BUILD_ROAD_CLEAR|type=Barracks
UPGRADE_SOUND|v1|mode=2|side=WEST|upgrade=Supply
TIP_SKIP|v1|id=12|flag=WFBE_C_GUER_PLAYERSIDE|value=0
TIP_SHOW|v1|id=50|text=class-tags
VEHLIFT_DROP|v1|vehicle=HMMWV|carrier=Mi17|reason=release
VEHLIFT_ABORT|v1|vehicle=BMP2|reason=too-fast
Error in expression <_free call BIS_fnc_selectRandom>: Undefined variable in expression: bis_fnc_selectrandom
WASPSTAT|v1|9|ROUNDEND|WEST|5432|Chernarus
"""


class AnalyzeSoakCanonicalTests(unittest.TestCase):
    def setUp(self):
        self.soak = analyze_soak.Soak()
        scoped, _ok = analyze_soak.scope_last_missinit(SAMPLE.splitlines(True))
        self.soak.ingest_server(scoped)

    def test_dispatch_arrival_counters(self):
        self.assertEqual(self.soak.dispatch_count, 3)   # 2 unique + 1 reissue
        self.assertEqual(self.soak.arrive_count, 1)
        self.assertEqual(self.soak.reissue_count, 1)

    def test_arrival_pct(self):
        # 1 arrival / 3 dispatches
        self.assertAlmostEqual(self.soak.arrival_pct(), 100.0 / 3.0, places=3)

    def test_arrival_by_bucket(self):
        buckets = self.soak.arrival_by_bucket()
        # WEST team A dispatched at dist=300 -> "<500", arrived.
        self.assertEqual(buckets["<500"]["d"], 1)
        self.assertEqual(buckets["<500"]["a"], 1)
        # EAST team B dispatched twice at dist=2500 -> "2000+", never arrived.
        self.assertEqual(buckets["2000+"]["d"], 2)
        self.assertEqual(buckets["2000+"]["a"], 0)

    def test_median_dispatch_to_arrival(self):
        # Only WEST A arrived: dispatch tick 10 -> arrival tick 13 = 3 min.
        self.assertEqual(self.soak.median_dispatch_to_arrival_min(), 3)

    def test_zombies(self):
        # EAST team B: 2 dispatches, 0 arrivals -> zombie at min_dispatch=2.
        z = self.soak.zombies(min_dispatch=2)
        self.assertEqual(len(z), 1)

    def test_kills(self):
        self.assertEqual(self.soak.kill_total, 3)
        # W<->E kills = WEST->EAST + EAST->WEST = 2 (the WEST->GUER kill excluded).
        self.assertEqual(self.soak.we_kills(), 2)

    def test_mhq_verbs(self):
        self.assertEqual(sum(c.get("DEPLOYED", 0) for c in self.soak.mhq.values()), 1)
        self.assertEqual(sum(c.get("ABORT", 0) for c in self.soak.mhq.values()), 1)

    def test_perf_summary(self):
        p = self.soak.perf_summary()
        self.assertEqual(p["samples"], 1)
        self.assertEqual(p["fps"][2], 42)       # max fps from the one sample
        self.assertEqual(p["fpsmin"][0], 31)    # v2-EXT per-window floor

    def test_scale_ext_summary(self):
        ext = self.soak.scale_ext_summary()
        self.assertTrue(ext.get("present"))
        self.assertEqual(ext["disp_run"], 0)    # single sample -> no run delta
        self.assertEqual(ext["postW_last"], "spearhead")
        self.assertEqual(ext["postE_last"], "laststand")

    def test_build86_families(self):
        self.assertGreaterEqual(sum(self.soak.skin_steps.values()), 1)
        self.assertEqual(len(self.soak.scud_lines), 1)
        self.assertGreaterEqual(self.soak.easa_count, 1)
        self.assertGreaterEqual(sum(self.soak.build_road.values()), 1)

    def test_cmdcon43_families(self):
        self.assertEqual(self.soak.cmd43["UPGRADE_SOUND"], 1)
        self.assertEqual(self.soak.upgrade_sound_modes["2"], 1)
        self.assertEqual(self.soak.cmd43["TIP_SKIP"], 1)
        self.assertEqual(self.soak.cmd43["TIP_SHOW"], 1)
        self.assertEqual(self.soak.cmd43["VEHLIFT_DROP"], 1)
        self.assertEqual(self.soak.cmd43["VEHLIFT_ABORT"], 1)
        self.assertEqual(self.soak.cmd43["BISRNG"], 1)

    def test_roundend(self):
        self.assertIsNotNone(self.soak.roundend)


class AnalyzeSoakAicom2Tests(unittest.TestCase):
    """Regression tests for the AICOM2 section (soak-gate tooling, cc44u fixture).

    Uses the sample_cc44u.rpt fixture file so the exact grammar from the live
    emitter is exercised rather than inline strings.  The fixture uses the REAL
    emitter grammar (AI_Commander_Decapitate.sqf + Common_RunCommanderTeam.sqf):
      - 7 SNAP lines per side (West/East); sides normalised WEST/EAST upper-case
      - 4 ALLOC lines per side
      - 6 DECAP closer lines for WEST (real state names: IDLE/ARMING/COMMITTED)
        + 1 driver PRESS line (AICOM2|v1|DECAP|West|8|PRESS|team=...|dist=...)
        * sensed is emitted as integer 1/0 (not "true"/"false")
        * COMMITTED is the state emitted when the closer is actively pressing
        * the driver PRESS line has no state= field (parsed with default IDLE)
      - 1 FISTPOOL line (West)
      - 1 ORDER line (war-room-task)
    """

    @classmethod
    def setUpClass(cls):
        fixture = Path(__file__).resolve().parent / "sample_cc44u.rpt"
        with open(str(fixture), "r", encoding="latin-1") as fh:
            lines = fh.readlines()
        scoped, _ok = analyze_soak.scope_last_missinit(lines)
        cls.soak = analyze_soak.Soak()
        cls.soak.ingest_server(scoped)
        cls.a2 = cls.soak.aicom2_summary()

    def test_present(self):
        self.assertTrue(self.a2.get("present"), "aicom2_summary must be present for cc44u fixture")

    def test_has_snap_alloc_decap(self):
        self.assertTrue(self.a2["has_snap"])
        self.assertTrue(self.a2["has_alloc"])
        self.assertTrue(self.a2["has_decap"])

    def test_snap_west_towns(self):
        sd = self.a2["per_side"].get("WEST") or self.a2["per_side"].get("west")
        self.assertIsNotNone(sd, "WEST side must be in per_side")
        sn = sd["snap"]
        self.assertIsNotNone(sn)
        # fixture: west myTowns goes 3->5->6 (max=6)
        self.assertGreaterEqual(sn["myTowns_max"], 5)
        self.assertGreater(sn["snap_count"], 0)

    def test_alloc_west_primary_changes(self):
        sd = self.a2["per_side"].get("WEST") or self.a2["per_side"].get("west")
        al = sd["alloc"]
        self.assertIsNotNone(al)
        # fixture: all 4 allocs go to 'Vybor', one EAST alloc changes primary -> WEST should be 0
        self.assertEqual(al["primary_changes"], 0)

    def test_decap_west_committed(self):
        """COMMITTED is the real active-press state (not PRESS, which is a separate driver line)."""
        sd = self.a2["per_side"].get("WEST") or self.a2["per_side"].get("west")
        dec = sd["decap"]
        self.assertIsNotNone(dec, "WEST must have DECAP records in cc44u fixture")
        # fixture: WEST DECAP closer states: IDLE/ARMING/ARMING/COMMITTED/COMMITTED
        # The separate driver PRESS line (AICOM2|v1|DECAP|West|8|PRESS|...) is also
        # captured but has no state= field so defaults to IDLE.
        # Verify COMMITTED state is present in the distribution.
        self.assertIn("COMMITTED", dec["state_dist"],
                      "COMMITTED state must appear in WEST DECAP state distribution")
        self.assertGreaterEqual(dec["state_dist"]["COMMITTED"], 1)

    def test_decap_sensed_latches(self):
        sd = self.a2["per_side"].get("WEST") or self.a2["per_side"].get("west")
        dec = sd["decap"]
        # fixture: west sensed=0 at tick=3, sensed=1 at tick=4 (integer grammar).
        # Parser must treat "1" as True -> one latch transition detected.
        self.assertGreaterEqual(dec["sensed_latches"], 1,
            "sensed latch must be detected; check that integer 1/0 is parsed (not true/false)")

    def test_decap_inrange_streak(self):
        sd = self.a2["per_side"].get("WEST") or self.a2["per_side"].get("west")
        dec = sd["decap"]
        # fixture: ticks 4-7 all have inRange>0 for WEST (2/3/4/5), streak=4
        self.assertGreaterEqual(dec["inRange_max"], 2)
        # roll cadence should be OK (not VIOLATED): only inRange>0 windows tested,
        # and tick 3 (inRange=0) must be excluded from cadence evaluation.
        self.assertNotEqual(dec["roll_cadence_ok"], False,
            "roll cadence must not be VIOLATED; check inRange>0 filtering is applied")

    def test_decap_verdict_no_fail(self):
        # cc44u has both SNAP and DECAP so verdict must not be FAIL
        self.assertNotEqual(self.a2["decap_verdict"], "FAIL",
                            "DECAP verdict must not be FAIL when DECAP lines are present")

    def test_order_lines(self):
        # fixture: 1 AICOM2|v1|ORDER line (war-room-task)
        self.assertIn("war-room-task", self.a2["order_summary"])
        self.assertGreaterEqual(self.a2["order_summary"]["war-room-task"], 1)

    def test_absent_on_v1_only(self):
        """A V1-only RPT (the build86 sample) must not report AICOM2 present."""
        fixture = Path(__file__).resolve().parent / "sample_build86.rpt"
        with open(str(fixture), "r", encoding="latin-1") as fh:
            lines = fh.readlines()
        scoped, _ok = analyze_soak.scope_last_missinit(lines)
        soak2 = analyze_soak.Soak()
        soak2.ingest_server(scoped)
        a2 = soak2.aicom2_summary()
        self.assertFalse(a2.get("present"),
                         "V1-only build86 fixture must have present=False in aicom2_summary")


if __name__ == "__main__":
    unittest.main(verbosity=2)
