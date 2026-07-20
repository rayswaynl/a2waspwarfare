import unittest

from PIL import Image, ImageDraw

from matchdata import TOWN_COORDS, WORLD_SIZE
import render


class ReportLayoutTests(unittest.TestCase):
    def test_committed_brand_vehicle_fallback_is_available(self):
        expected = {"veh-hind", "veh-t90", "veh-a10", "veh-bmp3", "veh-grad", "veh-technical"}

        self.assertEqual(expected, set(render.BRAND_VEHICLE_FALLBACKS))
        for vehicle_name in expected:
            vehicle = render.brand_vehicle(vehicle_name)
            self.assertIsNotNone(vehicle, vehicle_name)
            self.assertGreater(vehicle.width, 0, vehicle_name)
            self.assertGreater(vehicle.height, 0, vehicle_name)

    def test_faction_ledger_keeps_all_report_treatments_visible(self):
        rows = render.faction_ledger(
            {
                "West Town": "west",
                "East Town": "east",
                "Guer Town": "guer",
                "Neutral One": "neu",
                "Neutral Two": "neu",
            }
        )

        self.assertEqual(
            [
                ("west", "BLUFOR", 1),
                ("east", "OPFOR", 1),
                ("guer", "GUER", 1),
                ("neu", "CIV / CONTESTED", 2),
            ],
            rows,
        )

    def test_zargabad_label_layout_labels_every_static_town_without_overlap(self):
        image = Image.new("RGB", (1000, 1000))
        draw = ImageDraw.Draw(image)
        labels = render.layout_town_labels(
            draw,
            TOWN_COORDS["zargabad"],
            WORLD_SIZE["zargabad"],
            0,
            0,
            1000,
            render.f_xs,
        )

        self.assertEqual(set(TOWN_COORDS["zargabad"]), set(labels))
        boxes = []
        for town, (x, y) in labels.items():
            left, top, right, bottom = draw.textbbox((x, y), town, font=render.f_xs)
            self.assertGreaterEqual(left, 0, town)
            self.assertGreaterEqual(top, 0, town)
            self.assertLessEqual(right, 1000, town)
            self.assertLessEqual(bottom, 1000, town)
            for other_town, other_box in boxes:
                ox0, oy0, ox1, oy1 = other_box
                overlaps = max(left, ox0) < min(right, ox1) and max(top, oy0) < min(bottom, oy1)
                self.assertFalse(overlaps, f"{town} overlaps {other_town}")
            boxes.append((town, (left, top, right, bottom)))


if __name__ == "__main__":
    unittest.main()
