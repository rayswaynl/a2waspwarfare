# AICAP MID/HIGH scatter — 2026-07-22

## Dataset

- Source: retained full server RPT, `docs/Proposals/wasp-soak-rpt-harvest-20260716/raw/arma2oaserver.RPT` in the fleet scratch archive.
- Source SHA-256: `24383A7240DE1E8BAFB37A897D148E9B5B49222612880A67ED414CBC0A7F61F9`.
- Parser: every `WASPSCALE|v2|` line in the file; 282 samples, `AI_TOT` 33–696 and server `fps` 12–49. All samples are tier 0, so this is a load knee measurement, not a claim of per-tier live coverage.
- The locally retained active RPT at the time of analysis contained no WASPSCALE rows; its SHA is deliberately not substituted for this measured source.

## AI_TOT versus server-FPS scatter

Each character cell spans 25 AI_TOT by 2 FPS. A digit is the number of raw samples in that cell; `*` is ten or more. This is the entire 282-sample scatter, density-preserved rather than a hand-picked subset.

```text
50 |           1                |
48 |        54**9721    1       |
46 |    121  1125622332         |
44 | 1    2112641252441 1       |
42 | 1      1 12112 134         |
40 |          1  11215121       |
38 |             22 262211      |
36 |                122121 1    |
34 |            1   5311 3 1    |
32 |             2 11   11111   |
30 |             12 2243 1 11   |
28 |                 111 1 1    |
26 |           11  1 121   22   |
24 |                    12 1    |
22 |                 1    11111 |
20 |                    2    12 |
18 |                   1 112 121|
16 |                    11 1 1 1|
14 |                    21  1  1|
12 |                      1     |
10 |                            |
   +----------------------------+
     0    100  200  300  400  500  600  700 AI_TOT
```

| AI_TOT band | Samples | Median AI_TOT | Median FPS | Mean FPS | Minimum FPS |
| --- | ---: | ---: | ---: | ---: | ---: |
| 250–299 | 51 | 280 | 47.0 | 45.6 | 26 |
| 300–349 | 40 | 328 | 46.0 | 43.6 | 25 |
| 350–399 | 25 | 368 | 43.0 | 40.8 | 25 |
| 400–449 | 51 | 429 | 38.0 | 37.6 | 21 |
| 450–499 | 32 | 471 | 35.0 | 34.2 | 17 |
| 500–549 | 26 | 522 | 30.0 | 28.0 | 13 |
| 550–599 | 16 | 588 | 24.5 | 24.2 | 12 |
| 600–649 | 10 | 618 | 22.0 | 22.4 | 14 |
| 650–699 | 8 | 658 | 17.5 | 17.9 | 13 |

## Conservative first cut

The stable 300–349 band has a 46 FPS median. The first sustained decline is the 350–399 band (43 FPS), followed by 38 FPS at 400–449. The first cut therefore holds the MID ceiling 30 AI below the observed ~360 knee and takes a smaller 10-AI-per-side HIGH reduction:

| Tier | Legacy per-side cap | Armed per-side cap | Change |
| --- | ---: | ---: | ---: |
| LOW | 140 | 140 | 0 |
| MID | 130 | 115 | −15 |
| HIGH | 100 | 90 | −10 |
| FULL | 80 | 80 | 0 |

The feature is `WFBE_C_AICAP_MIDHIGH_TRIM`, default `0`. When armed, CH/TK use `[140,115,90,80]`; Zargabad retains its independent `[80,80,70,60]` governor. The match-start `AICAP|v1|tiers=...` stamp identifies armed soaks. Interpret its next soak together with the separately queued 20% garrison scale and merge-up cards: all three alter AI composition, so this evidence does not attribute their effects independently.
