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
  -ExpectedGit e3b6e37903 `
  -ExpectedArchiveSha256 3DB01AC1656329ECCAE9896CE9442680D5D904C563DD44590FFBD20954CF7B87 `
  -RequireReleaseMarkers `
  -Json `
  -OutFile "C:\WASP\rpt-archive\marker-sweep-e3b6e37903.json"
```

Only add PR #126 HC-audit markers to `-RequirePattern` when the package being tested actually includes that instrumentation:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WaspRptMarkerSweep.ps1 `
  -RptDirectory "C:\WASP\rpt-archive" `
  -Latest 8 `
  -ExpectedCandidate release-command-center-20260630 `
  -ExpectedGit e3b6e37903 `
  -ExpectedArchiveSha256 3DB01AC1656329ECCAE9896CE9442680D5D904C563DD44590FFBD20954CF7B87 `
  -RequireReleaseMarkers `
  -RequirePattern HCDROP_AICOM_AUDIT,HCRECON_AICOM_AUDIT `
  -Json `
  -OutFile "C:\WASP\rpt-archive\marker-sweep-e3b6e37903-hc-audit.json"
```

By default, samples include the marker name, public file label, line number, and a short line hash. `-OutFile` writes the same redaction-safe JSON that `-Json` prints, and the output records the expected candidate, git marker, archive SHA and generated terrain markers. Use `-IncludeLineText` only when the log owner accepts that marker lines may contain names, UIDs, owner IDs, positions, or other operational details.

Useful PR #126 proof markers:

- `WASPRELEASE`
- `WASPRELEASE|v1|candidate=release-command-center-20260630|git=e3b6e37903`
- `HCDROP_AICOM_AUDIT`
- `HCRECON_AICOM_AUDIT`
- `HCSIDE|v1|disconnect`
- `HCSIDE|v1|reconnect`
- `HCDISPATCH`
- `HCSTAT`
- `AICOMSTAT`

Current PR #125 package checkpoint is `codex/release-command-center-20260630@e3b6e37903`, `_MISSIONS.7z` SHA256 `3DB01AC1656329ECCAE9896CE9442680D5D904C563DD44590FFBD20954CF7B87`, `1,885` entries, `7,162,113` bytes, handoff `ready_for_runtime_collection`. Treat marker sweeps as health/provenance triage only until the exact Chernarus and Takistan RPT packet is collected and scored against that package tuple.

## Runtime Evidence Manifest

`Test-WaspRuntimeEvidenceManifest.ps1` validates the redaction-safe handoff manifest after marker-sweep JSON files have been produced. The manifest proves the release gate has one matching sweep for every required terrain/role slot without copying private RPT contents into git:

```json
{
  "schema": "a2waspwarfare-runtime-evidence-manifest-v1",
  "evidence": [
    {
      "terrain": "chernarus",
      "role": "server",
      "markerSweepPath": "marker-sweep-chernarus-server.json"
    }
  ]
}
```

Run it against the current package tuple before treating runtime evidence as complete:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Test-WaspRuntimeEvidenceManifest.ps1 `
  -ManifestPath "C:\WASP\rpt-archive\runtime-evidence-e3b6e37903.json" `
  -ExpectedCandidate release-command-center-20260630 `
  -ExpectedGit e3b6e37903 `
  -ExpectedArchiveSha256 3DB01AC1656329ECCAE9896CE9442680D5D904C563DD44590FFBD20954CF7B87
```

Default required slots are `chernarus,takistan` x `server,hc1,hc2,start-client,late-jip`. Use `-RequiredTerrain` or `-RequiredRole` only when the release owner explicitly narrows the evidence matrix.

Run the helper contract self-test after editing it:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Test-WaspRptMarkerSweep.SelfTest.ps1
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Test-WaspRuntimeEvidenceManifest.SelfTest.ps1
```
