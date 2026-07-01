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
  -Json
```

For the current package lane, let the helper build and require both exact terrain release markers:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WaspRptMarkerSweep.ps1 `
  -RptDirectory "C:\WASP\rpt-archive" `
  -Latest 8 `
  -ExpectedCandidate release-command-center-20260630 `
  -ExpectedGit a94818f2eb `
  -ExpectedArchiveSha256 703F71E6C9F7E2FEB5323ADE32B5A4AFF7A2B277FC8B5BBE2687F5ED91601BED `
  -RequireReleaseMarkers `
  -Json `
  -OutFile "C:\WASP\rpt-archive\marker-sweep-a94818f2eb.json"
```

Only add PR #126 HC-audit markers to `-RequirePattern` when the package being tested actually includes that instrumentation:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WaspRptMarkerSweep.ps1 `
  -RptDirectory "C:\WASP\rpt-archive" `
  -Latest 8 `
  -ExpectedCandidate release-command-center-20260630 `
  -ExpectedGit a94818f2eb `
  -ExpectedArchiveSha256 703F71E6C9F7E2FEB5323ADE32B5A4AFF7A2B277FC8B5BBE2687F5ED91601BED `
  -RequireReleaseMarkers `
  -RequirePattern HCDROP_AICOM_AUDIT,HCRECON_AICOM_AUDIT `
  -Json `
  -OutFile "C:\WASP\rpt-archive\marker-sweep-a94818f2eb-hc-audit.json"
```

By default, samples include the marker name, public file label, line number, and a short line hash. `-OutFile` writes the same redaction-safe JSON that `-Json` prints, and the output records the expected candidate, git marker, archive SHA and generated terrain markers. Use `-IncludeLineText` only when the log owner accepts that marker lines may contain names, UIDs, owner IDs, positions, or other operational details.

Useful PR #126 proof markers:

- `WASPRELEASE`
- `WASPRELEASE|v1|candidate=release-command-center-20260630|git=a94818f2eb`
- `HCDROP_AICOM_AUDIT`
- `HCRECON_AICOM_AUDIT`
- `HCSIDE|v1|disconnect`
- `HCSIDE|v1|reconnect`
- `HCDISPATCH`
- `HCSTAT`
- `AICOMSTAT`

Current PR #125 package checkpoint is `codex/release-command-center-20260630@a94818f2eb`, `_MISSIONS.7z` SHA256 `703F71E6C9F7E2FEB5323ADE32B5A4AFF7A2B277FC8B5BBE2687F5ED91601BED`, `1,885` entries, `7,161,776` bytes, handoff `ready_for_runtime_collection`. Treat marker sweeps as health/provenance triage only until the exact Chernarus and Takistan RPT packet is collected and scored against that package tuple.

Run the helper contract self-test after editing it:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Test-WaspRptMarkerSweep.SelfTest.ps1
```
