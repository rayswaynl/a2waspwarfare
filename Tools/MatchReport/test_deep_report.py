"""
Behaviour tests for the in-depth match report (matchfacts / deepmatch / deep_report).

Deliberately stdlib-only, matching the modules under test: these run on a box that has
neither numpy nor Pillow, which is the whole point of the in-depth path existing
alongside the video renderer.
"""
import re
import unittest

import deep_report
from deepmatch import FACTION_ORDER, fmt_clock, parse_deep
from matchfacts import parse_match_family


def _w(seq, payload):
    """A WASPSTAT line as diag_log writes it — wrapped in double quotes."""
    return '"WASPSTAT|v1|%d|%s"' % (seq, payload)


class MatchFamilyTests(unittest.TestCase):
    def test_start_end_and_milestones_parse_from_wrapped_lines(self):
        f = parse_match_family([
            '"MATCH|v1|START|world=takistan|build=build89-cmdcon44|towns=18|missionSlots=61'
            '|aiEnabled=1|delegation=2|statlog=1|guer=0|naval=0|oilfield=1"',
            '"MATCH|v1|MILESTONE|FIRST_TOWN|side=WEST|town=Rasman|tMin=4"',
            '"MATCH|v1|MILESTONE|OILFIELD_CAP|owner=EAST|tMin=44"',
            '"MATCH|v1|END|winner=EAST|durationSec=3600|world=takistan|townsW=2|townsE=15'
            '|townsG=1|casW=88|casE=61|vehLostW=14|vehLostE=9|players=20|totalTowns=18"',
        ])
        self.assertEqual(f.world, "takistan")
        self.assertEqual(f.build, "build89-cmdcon44")
        self.assertEqual(f.winner, "east")
        self.assertEqual(f.duration, 3600)
        #--- numeric keys coerce; the build token stays a string
        self.assertEqual(f.start["towns"], 18)
        self.assertEqual(f.start["oilfield"], 1)
        self.assertEqual(f.final_towns(), {"west": 2, "east": 15, "guer": 1})
        self.assertEqual(f.casualties(), {"west": 88, "east": 61})
        self.assertEqual(f.vehicles_lost(), {"west": 14, "east": 9})
        self.assertEqual(len(f.milestones), 2)
        self.assertEqual(f.milestones[0]["t"], 240)

    def test_boolean_flags_survive_sqf_str_rendering(self):
        f = parse_match_family([
            '"MATCH|v1|START|world=chernarus|build=b|towns=20|missionSlots=55|aiEnabled=true'
            '|delegation=2|statlog=1|guer=false|naval=0|oilfield=0"'])
        self.assertEqual(f.start["aiEnabled"], 1)
        self.assertEqual(f.start["guer"], 0)

    def test_absent_family_never_raises(self):
        f = parse_match_family(["nothing to see here"])
        self.assertIsNone(f.start)
        self.assertIsNone(f.end)
        self.assertEqual(f.final_towns(), {})
        self.assertIsNone(f.winner)

    def test_unknown_milestone_subtype_is_surfaced_not_dropped(self):
        f = parse_match_family(['"MATCH|v1|MILESTONE|BRIDGE_BLOWN|span=North|tMin=12"'])
        self.assertEqual(len(f.milestones), 1)
        self.assertIn("span=North", f.describe(f.milestones[0]))

    def test_hq_destroyed_is_not_painted_as_the_victim_sides_win(self):
        f = parse_match_family(['"MATCH|v1|MILESTONE|HQ_DESTROYED|side=EAST|tMin=80"'])
        self.assertEqual(f.milestone_side(f.milestones[0]), "neu")


class DeepMatchTests(unittest.TestCase):
    def _lines(self):
        return [
            '"MATCH|v1|START|world=chernarus|build=build89|towns=20|missionSlots=55'
            '|aiEnabled=1|delegation=2|statlog=1|guer=1|naval=0|oilfield=0"',
            _w(1, "CAPTURE|Pustoshka|4|0|t=100"),
            _w(2, "CAPTURE|Msta|4|1|t=200"),
            _w(3, "CAPTURE|Msta|1|0|t=600"),
            _w(4, "KILL|76561190000000011|76561190000000022|WEST|EAST|M16A2|250|INF|hw=M16A2|t=150"),
            _w(5, "KILL|||EAST|WEST|T72|-1|VEH|t=300"),
            _w(6, "KILL|76561190000000022|76561190000000011|EAST|WEST|SVD|900|INF|hw=SVD|t=450"),
            _w(7, "76561190000000011:5,1,0,0,0,0,2,1,0,0,1,0,0,0,600,1~Ghost"
                  "|76561190000000022:3,0,0,0,0,0,1,1,0,0,0,0,0,0,600,2~Krait"
                  "|76561190000000099:0,0,0,0,0,0,0,0,0,0,0,0,0,0,600,0~HC-AI-Control-1"),
            _w(8, "ROUNDEND|WEST|1000|chernarus"),
            '"MATCH|v1|END|winner=WEST|durationSec=1000|world=chernarus|townsW=12|townsE=0'
            '|townsG=0|casW=10|casE=20|vehLostW=1|vehLostE=3|players=2|totalTowns=20"',
        ]

    def setUp(self):
        self.dm = parse_deep(self._lines())

    def test_identity_comes_from_the_match_end_record(self):
        self.assertEqual(self.dm.winner, "west")
        self.assertEqual(self.dm.duration, 1000)
        self.assertEqual(self.dm.map_name, "CHERNARUS")

    def test_headless_and_ai_controllers_never_reach_a_stat_surface(self):
        names = [p["name"] for p in self.dm.players]
        self.assertEqual(sorted(names), ["Ghost", "Krait"])
        self.assertEqual(len(self.dm.excluded_players), 1)
        self.assertEqual(self.dm.coverage["excluded_rows"], 1)
        self.assertNotIn("HC-AI-Control-1", [d["a"] for d in self.dm.duels])

    def test_town_flip_history_and_territory_seconds(self):
        msta = [r for r in self.dm.town_rows if r["town"] == "Msta"][0]
        self.assertEqual(msta["flips"], 2)
        self.assertEqual(msta["first"], 200)
        self.assertEqual(msta["last"], 600)
        self.assertEqual(msta["final"], "west")
        #--- Msta: neutral 0-200, east 200-600, west 600-1000
        self.assertEqual(msta["held"]["east"], 400)
        self.assertEqual(msta["held"]["west"], 400)
        self.assertEqual(msta["held"]["neu"], 200)
        #--- only the two towns that actually flipped count toward the contested share
        self.assertEqual(self.dm.active_towns, 2)
        self.assertEqual(self.dm.active_seconds["west"], 900 + 400)

    def test_final_town_count_prefers_the_authoritative_end_record(self):
        #--- CAPTURE records only know about 2 towns; GetTownsHeld saw 12.
        self.assertEqual(self.dm.final_town_counts()["west"], 12)

    def test_unmeasured_distance_is_excluded_not_binned_as_zero(self):
        self.assertEqual(self.dm.total_kills, 3)
        self.assertEqual(self.dm.dist_measured, 2)
        self.assertEqual(sum(r["n"] for r in self.dm.dist_rows), 2)
        self.assertEqual(self.dm.longest["dist"], 900)

    def test_pvp_pairs_only_count_kills_with_both_uids(self):
        self.assertEqual(self.dm.pvp_kills, 2)
        self.assertEqual(len(self.dm.duels), 1)
        self.assertEqual(self.dm.duels[0]["tot"], 2)

    def test_every_faction_keeps_a_row_even_at_zero(self):
        for side in FACTION_ORDER:
            self.assertIn(side, self.dm.side_totals)
            self.assertIn(side, self.dm.series)

    def test_timeline_merges_all_three_families_in_order(self):
        kinds = [e["kind"] for e in self.dm.timeline]
        self.assertEqual(kinds[0], "START")
        self.assertEqual(kinds[-1], "END")
        self.assertIn("CAPTURE", kinds)
        ts = [e["t"] for e in self.dm.timeline]
        self.assertEqual(ts, sorted(ts))

    def test_measured_timestamps_are_not_reported_as_interpolated(self):
        self.assertTrue(all(c["exact"] for c in self.dm.caps))
        self.assertEqual(self.dm.coverage["cap_exact"], self.dm.coverage["cap_total"])
        self.assertEqual(self.dm.warnings, [])


class CoverageHonestyTests(unittest.TestCase):
    def test_extended_waspstat_records_are_not_counted_as_playerstats(self):
        dm = parse_deep([
            _w(1, "CAMP|Berezino|0|1|t=120|by=player|pN=1|aiN=0|who=Ghost"),
            _w(2, "BUILDINGKILL|76561190000000011|WEST|EAST|Base_WarfareBHeavyFactory|FACTORY"),
            _w(3, "ROUNDEND|WEST|600|chernarus"),
        ])

        self.assertEqual(dm.coverage["records"].get("CAMP"), 1)
        self.assertEqual(dm.coverage["records"].get("BUILDINGKILL"), 1)
        self.assertEqual(dm.coverage["records"].get("PLAYERSTATS", 0), 0)
        self.assertIn("not included in event tables", " ".join(dm.warnings))
        self.assertIn("CAMP / BUILDINGKILL", deep_report.render_html(dm))

    def test_live_camp_timestamp_keeps_report_clock_at_latest_observed_event(self):
        dm = parse_deep([
            _w(1, "CAMP|Berezino|0|1|t=120|by=player|pN=1|aiN=0|who=Ghost"),
        ])

        self.assertTrue(dm.in_progress)
        self.assertEqual(dm.duration, 120)

    def test_unrecognized_waspstat_record_is_reported_as_unknown(self):
        dm = parse_deep([
            _w(1, "FUTURE_EVENT:field=value"),
            _w(2, "ROUNDEND|WEST|600|chernarus"),
        ])

        self.assertEqual(dm.coverage["records"].get("UNKNOWN"), 1)
        self.assertEqual(dm.coverage["records"].get("PLAYERSTATS", 0), 0)
        self.assertIn("unrecognized", " ".join(dm.warnings))

    def test_missing_match_family_and_timestamps_raise_warnings(self):
        dm = parse_deep([
            _w(1, "CAPTURE|Msta|4|0"),
            _w(2, "KILL|||WEST|EAST|M16A2|100|INF"),
            _w(9, "ROUNDEND|WEST|600|chernarus"),
        ])
        joined = " ".join(dm.warnings)
        self.assertIn("MATCH|v1|START", joined)
        self.assertIn("MATCH|v1|END", joined)
        self.assertIn("interpolated", joined)
        #--- seq 3..8 never appeared
        self.assertEqual(dm.coverage["seq_gaps"], 6)
        self.assertIn("gap(s) in the WASPSTAT sequence", joined)
        #--- an interpolated event must not claim a measured time
        self.assertFalse(dm.caps[0]["exact"])

    def test_ai_only_round_is_reported_rather_than_rendered_empty(self):
        dm = parse_deep([_w(1, "KILL|||WEST|EAST|T72|50|VEH|t=10"),
                         _w(2, "ROUNDEND|WEST|100|chernarus")])
        self.assertTrue(dm.ai_only)
        self.assertIn("No human operators", " ".join(dm.warnings))
        self.assertIn("AI-only", deep_report.render_html(dm))

    def test_live_match_clock_falls_back_to_the_latest_observed_event(self):
        #--- a running match has neither ROUNDEND nor MATCH|v1|END, so the clock has to come
        #--- from the log itself; without this the duration collapses to 1 s and every
        #--- time-based surface (momentum, tempo, territory-seconds) degenerates.
        dm = parse_deep([
            '"MATCH|v1|START|world=chernarus|build=b|towns=20|missionSlots=55|aiEnabled=1'
            '|delegation=2|statlog=1|guer=1|naval=0|oilfield=0"',
            _w(1, "CAPTURE|Msta|4|0|t=600"),
            _w(2, "KILL|||WEST|EAST|M16A2|100|INF|t=1800"),
        ])
        self.assertTrue(dm.in_progress)
        self.assertEqual(dm.duration, 1800)
        self.assertGreater(dm.town_seconds["west"], 0)
        self.assertEqual(len(dm.ser_x), len(dm.series["west"]))
        self.assertIn("still in progress", " ".join(dm.warnings))

    def test_live_match_never_announces_a_winner(self):
        dm = parse_deep([_w(1, "CAPTURE|Msta|4|0|t=600")])
        self.assertTrue(dm.in_progress)
        self.assertEqual(dm.winner, "neu")
        self.assertEqual(dm.win_how[0], "IN PROGRESS")
        self.assertNotIn("END", [e["kind"] for e in dm.timeline])
        for out in (deep_report.render_html(dm), deep_report.render_md(dm)):
            self.assertIn("IN PROGRESS", out)
            self.assertNotIn("wins", out)
            self.assertNotIn("victory", out)

    def test_finished_match_is_not_flagged_in_progress(self):
        dm = parse_deep([_w(1, "ROUNDEND|WEST|600|chernarus")])
        self.assertFalse(dm.in_progress)

    def test_empty_log_still_produces_a_report(self):
        dm = parse_deep([])
        html = deep_report.render_html(dm)
        self.assertIn("<html", html)
        self.assertTrue(dm.warnings)


class RenderTests(unittest.TestCase):
    def setUp(self):
        self.dm = parse_deep(deep_report.sample_lines())
        self.html = deep_report.render_html(self.dm)

    def test_sample_exercises_the_real_parse_path(self):
        #--- the sample is a wire-format log, not a hand-built object, so parsing it proves
        #--- the parser rather than a stub
        self.assertGreater(self.dm.total_kills, 500)
        self.assertEqual(self.dm.winner, "west")
        self.assertTrue(self.dm.coverage["has_start"])
        self.assertTrue(self.dm.coverage["has_end"])
        self.assertEqual(len(self.dm.excluded_players), 1)

    def test_every_dom_id_is_unique(self):
        ids = re.findall(r'\sid="([^"]+)"', self.html)
        self.assertEqual(len(ids), len(set(ids)), "duplicate DOM ids: %s"
                         % [i for i in ids if ids.count(i) > 1])

    def test_every_colour_var_used_is_defined(self):
        used = set(re.findall(r"var\((--[a-z0-9-]+)\)", self.html))
        defined = set(re.findall(r"(--[a-z0-9-]+):", self.html))
        self.assertEqual(used - defined, set())

    def test_charts_ship_a_table_view_twin(self):
        charts = self.html.count('class="chart"')
        twins = self.html.count("Table view")
        self.assertGreaterEqual(twins, charts)

    def test_operator_names_are_html_escaped(self):
        dm = parse_deep([
            _w(1, '76561190000000011:1,0,0,0,0,0,0,0,0,0,0,0,0,0,60,1~<script>x</script>'),
            _w(2, "ROUNDEND|WEST|60|chernarus")])
        out = deep_report.render_html(dm)
        self.assertNotIn("<script>x</script>", out)
        self.assertIn("&lt;script&gt;", out)

    def test_self_contained_no_external_requests(self):
        for needle in ("http://", "https://", "<link", "src="):
            self.assertNotIn(needle, self.html)

    def test_markdown_mode_renders_without_html(self):
        md = deep_report.render_md(self.dm)
        self.assertIn("# WASP in-depth match report", md)
        self.assertIn("## Telemetry coverage", md)
        self.assertNotIn("<div", md)


class ClockTests(unittest.TestCase):
    def test_clock_formatting(self):
        self.assertEqual(fmt_clock(0), "00:00")
        self.assertEqual(fmt_clock(65), "01:05")
        self.assertEqual(fmt_clock(3725), "1:02:05")
        self.assertEqual(fmt_clock(-5), "00:00")


if __name__ == "__main__":
    unittest.main()
