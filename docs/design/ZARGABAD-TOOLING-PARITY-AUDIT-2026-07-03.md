# Zargabad Tooling Parity Audit

Lane 301 source check against `claude/build84-cmdcon36` at `54f4a07b2ddcac5ee3981684054a8d259b7fc0ed`.

## Verdict

Zargabad is present in the maintained mission tree and has a campaign definition, but the reporting tools are not at parity:

- `Tools/MatchReport` is missing `WORLD_SIZE["zargabad"]` and `TOWN_COORDS["zargabad"]`, so a Zargabad report falls back to the default 15360 m world and auto-places only towns observed in capture lines.
- `Tools/Soak/analyze_soak.py` is mostly terrain-agnostic. It preserves `map=` from `WASPSCALE|v2` and the final `ROUNDEND` map field, but it has no Zargabad fixture proving that path.
- `Tools/MatchReport/README.md` is stale: it still says Takistan coordinates are empty, but `matchdata.py` now contains exact Takistan coordinates.

No mission source change is required for this audit. The small implementation lane should update MatchReport data/docs and add one Zargabad regression fixture.

## Evidence

`docs/zargabad-campaign.json` is the authoritative local campaign input:

- `map`: `zargabad`
- `size`: `8192`
- `towns`: 11 entries, each with `pos`
- Comment says the town positions are real CfgWorlds named locations and alignment-verified.

`Tools/MatchReport/matchdata.py` has terrain tables:

- `WORLD_SIZE = {"chernarus": 15360, "takistan": 12800, "default": 15360}`
- `TOWN_COORDS` contains `chernarus` and `takistan`, but no `zargabad`.
- `coords_for(map_name, town_names)` reads `TOWN_COORDS.get(map_name.lower(), {})` and falls back to `WORLD_SIZE["default"]` when the map is unknown.
- `parse_waspstat` builds the report map from the full static set only when `TOWN_COORDS` has the map key; otherwise it uses only captured town names.

`Tools/Soak/analyze_soak.py` handles map labels without a terrain table:

- The docstring covers `WASPSTAT|v1|...|ROUNDEND|...|<map>` and `WASPSCALE|v2|...|map=...`.
- The parser stores `roundend["map"]` from the final field and stores `scale[-1]["map"]` from `WASPSCALE`.
- JSON/compare output includes those map labels.
- There is no Zargabad sample or unit assertion in `Tools/Soak/test_analyze_soak.py`.

## Ready Coordinate Payload

Suggested MatchReport patch:

```python
WORLD_SIZE = {"chernarus": 15360, "takistan": 12800, "zargabad": 8192, "default": 15360}
```

```python
"zargabad": {
    "Zargabad": (4071.37, 4183.32),
    "Zargabad AF": (3386.26, 4082.67),
    "Yarum": (4154.24, 3592.65),
    "The Villa": (4813.26, 4645.28),
    "Nango": (2823.53, 5022.13),
    "Azizayt": (1929.89, 4652.94),
    "Hazar Bagh": (3943.51, 5957.63),
    "Military Base": (4982.72, 6207.94),
    "Shahbaz": (3528.11, 1932.74),
    "Firuz Baharv": (5059.49, 1878.24),
    "Shur Dam": (2889.65, 3143.63),
},
```

## Implementation Checklist

1. Add `zargabad` to `WORLD_SIZE` in `Tools/MatchReport/matchdata.py`.
2. Add `TOWN_COORDS["zargabad"]` from the coordinate payload above.
3. Add a MatchReport regression that calls `coords_for("zargabad", [...])` and asserts:
   - world size is `8192`
   - all 11 static towns are available when the parser builds the full map set
   - an unknown captured town still auto-places without losing the static Zargabad set
4. Update `Tools/MatchReport/README.md` caveat 2:
   - remove the stale "`takistan` is empty" wording
   - state that Chernarus, Takistan and Zargabad have static coordinates, with boot-harvest still preferred for future map additions
5. Update `Tools/MatchReport/PRODUCTION.md` caveat if desired:
   - current wording is still true at a high level, but it should distinguish "exact static coordinates present" from "future maps need boot-harvest"
6. Add a minimal Soak fixture with:
   - `WASPSCALE|v2|...|map=zargabad|...`
   - `WASPSTAT|v1|...|ROUNDEND|WEST|...|zargabad`
   - assertions that text, JSON and compare output preserve the `zargabad` map label

## Non-Goals

- Do not change mission runtime, emitters or lobby flags for this lane.
- Do not run `Tools/LoadoutManager`; this is report-only.
- Do not harvest live RPTs from the game PC for coordinates unless a future owner wants to replace campaign JSON positions with `TOWNPOS|v1` boot output.
- Do not add Zargabad control-map code without tests, because the current fallback silently produces plausible but wrong maps.
