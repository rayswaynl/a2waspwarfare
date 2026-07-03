# Town Defense RPT Analyzer

Author: Marty

Analyzes Arma 2 Warfare RPT logs for town defense spawning problems, especially Headless Client group saturation.

The tool is external to the mission and has no gameplay or FPS impact.

Shared RPT input, delimiter, CSV export and HTML-escape helpers live in `Tools/RptParsing`.

## Usage

Double-click:

```text
Start-TownDefenseRptAnalyzer.cmd
```

The launcher opens a Windows form with `Browse...` buttons for the server RPT, the HC RPT, and the output folder. When analysis finishes, the HTML report opens automatically.

Analyze server and HC logs together:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\RptTownDefenseAnalyzer\Analyze-TownDefenseRpt.ps1 -ServerRpt ".\server.rpt" -HcRpt ".\headless.rpt"
```

Analyze a folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\RptTownDefenseAnalyzer\Analyze-TownDefenseRpt.ps1 -InputPath ".\logs" -Recurse
```

Choose an output folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\RptTownDefenseAnalyzer\Analyze-TownDefenseRpt.ps1 -ServerRpt ".\server.rpt" -HcRpt ".\headless.rpt" -OutputPath ".\TownDefenseRptResults"
```

## Main Verdicts

- `OK`: no empty town activation and no `createGroup` failure were found.
- `INCOMPLETE`: the log does not contain enough EAST/WEST town activations to validate the reported bug.
- `FAILURE`: empty town activations, `createGroup` failures, or cleanup anomalies were found.

## Important Keywords

The analyzer looks for:

```text
TD Debug build
activated witha total of
no valid group could be created
TOWN_GROUP_COUNT
TOWN_AI_HC_CLEANUP
Client_DelegateTownAI.sqf
```

## Outputs

```text
town_defense_report.md
town_defense_report.html
town_defense_report.txt
town_defense_summary.json
town_defense_activations.csv
town_defense_create_failures.csv
town_defense_group_counts.csv
town_defense_cleanup.csv
town_defense_delegation.csv
town_defense_builds.csv
```

The CSV separator defaults to `;`, which is convenient for French Excel.
