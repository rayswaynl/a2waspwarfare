# WASP Monitor Helpers

Small operator-side helpers for reading live or archived Arma 2 OA RPT files.

## Windowed RPT Reads

`Get-WindowedRpt.ps1` reads an RPT with read/write sharing and returns only the latest mission window by default.

```powershell
. .\Tools\Monitor\Get-WindowedRpt.ps1
$lines = Get-WindowedRpt -RptPath "C:\WASP\rpt-archive\arma2oaserver-latest.RPT"
```

## Redaction-Safe Marker Sweep

`Get-WaspRptMarkerSweep.ps1` counts release, AI Commander and HC proof markers without copying logs, printing absolute paths, or dumping RPT lines.

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WaspRptMarkerSweep.ps1 `
  -RptDirectory "C:\WASP\rpt-archive" `
  -Latest 8 `
  -RequirePattern HCDROP_AICOM_AUDIT,HCRECON_AICOM_AUDIT `
  -Json
```

By default, samples include the marker name, public file label, line number, and a short line hash. Use `-IncludeLineText` only when the log owner accepts that marker lines may contain names, UIDs, owner IDs, positions, or other operational details.

Useful PR #126 proof markers:

- `WASPRELEASE`
- `WASPRELEASE|v1|candidate=release-command-center-20260630|git=c0d2b42ef5`
- `HCDROP_AICOM_AUDIT`
- `HCRECON_AICOM_AUDIT`
- `HCSIDE|v1|disconnect`
- `HCSIDE|v1|reconnect`
- `HCDISPATCH`
- `HCSTAT`
- `AICOMSTAT`

Current PR #125 source head observed after the package refresh is `153a513fb`, but the last recorded package/handoff tuple remains `codex/release-command-center-20260630@c0d2b42ef5`, `_MISSIONS.7z` SHA256 `A99EC513243EC161319B6AE16BB5A9A5308541FF03B6148D60FBE208D4E04AAC`, `1,879` entries, `7,139,450` bytes, handoff `ready_for_runtime_collection`. Treat marker sweeps as health/provenance triage only until the exact Chernarus and Takistan RPT packet is collected and scored against the chosen package tuple. If `153a513fb` is the runtime target, wait for a fresh package/handoff identity first.

Run the helper contract self-test after editing it:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Test-WaspRptMarkerSweep.SelfTest.ps1
```
