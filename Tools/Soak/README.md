# WASP Soak Analyzer

`analyze_soak.py` summarizes Arma 2 OA RPT soak logs by build. It accepts raw `.rpt`, `.log` or `.txt` files and emits a per-build KPI table for Build 86 telemetry families:

- `AICOMSTAT` events, including `MHQRELOC` states and road/build placement markers.
- `FPSREPORT`, `WASPSTAT`, `PLAYERSTAT` and `HCSIDE` pipe telemetry.
- Plain RPT strings for SCUD/TEL, EASA/gear and the `[WFBE (SKIN)]` apply chain.
- Patrol unstuck and naval-skip markers when present.

## Usage

```powershell
python .\Tools\Soak\analyze_soak.py Build85=.\rpts\build85.rpt Build86=.\rpts\build86.rpt --csv .\soak.csv --json .\soak.json --md .\soak.md
```

For a folder:

```powershell
python .\Tools\Soak\analyze_soak.py Build86=.\rpts --recurse --md .\soak.md
```

Inputs without `BUILD=` use the filename stem as the build label.
