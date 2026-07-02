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
  -ExpectedGit 4893faaa5d `
  -ExpectedArchiveSha256 22F5AEE4BAF78FCB417A5C7CB7C76B2E1C67B7968541F95EB47527E0AF2A085E `
  -ExpectedRole server `
  -ExpectedTerrain chernarus `
  -RequireReleaseMarkers `
  -Json `
  -OutFile "C:\WASP\rpt-archive\marker-sweep-4893faaa5d.json"
```

Only add PR #126 HC-audit markers to `-RequirePattern` when the package being tested actually includes that instrumentation:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WaspRptMarkerSweep.ps1 `
  -RptDirectory "C:\WASP\rpt-archive" `
  -Latest 8 `
  -ExpectedCandidate release-command-center-20260630 `
  -ExpectedGit 4893faaa5d `
  -ExpectedArchiveSha256 22F5AEE4BAF78FCB417A5C7CB7C76B2E1C67B7968541F95EB47527E0AF2A085E `
  -ExpectedRole hc1 `
  -ExpectedTerrain chernarus `
  -RequireReleaseMarkers `
  -RequirePattern HCDROP_AICOM_AUDIT,HCRECON_AICOM_AUDIT `
  -Json `
  -OutFile "C:\WASP\rpt-archive\marker-sweep-4893faaa5d-hc-audit.json"
```

By default, samples include the marker name, public file label, line number, and a short line hash. `-OutFile` writes the same redaction-safe JSON that `-Json` prints, and the output records the expected candidate, git marker, archive SHA, role stamp, terrain stamp and generated terrain markers. Use `-IncludeLineText` only when the log owner accepts that marker lines may contain names, UIDs, owner IDs, positions, or other operational details.

Useful PR #126 proof markers:

- `WASPRELEASE`
- `WASPRELEASE|v1|candidate=release-command-center-20260630|git=4893faaa5d`
- `HCDROP_AICOM_AUDIT`
- `HCRECON_AICOM_AUDIT`
- `HCSIDE|v1|disconnect`
- `HCSIDE|v1|reconnect`
- `HCDISPATCH`
- `HCSTAT`
- `AICOMSTAT`

Current PR #125 package checkpoint is `codex/release-command-center-20260630@4893faaa5d`, `_MISSIONS.7z` SHA256 `22F5AEE4BAF78FCB417A5C7CB7C76B2E1C67B7968541F95EB47527E0AF2A085E`, `1,885` entries, `7,166,685` bytes, handoff `ready_for_runtime_collection`. Treat marker sweeps as health/provenance triage only until the exact Chernarus and Takistan RPT packet is collected and scored against that package tuple.

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

Generate the full default manifest skeleton instead of hand-writing the ten rows:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\New-WaspRuntimeEvidenceManifestTemplate.ps1 `
  -OutFile "C:\WASP\rpt-archive\runtime-evidence-4893faaa5d.json" `
  -CommandOutFile "C:\WASP\rpt-archive\marker-sweep-commands-4893faaa5d.ps1" `
  -ExpectedCandidate release-command-center-20260630 `
  -ExpectedGit 4893faaa5d `
  -ExpectedArchiveSha256 22F5AEE4BAF78FCB417A5C7CB7C76B2E1C67B7968541F95EB47527E0AF2A085E
```

`-CommandOutFile` writes a local marker-sweep command template with one command per terrain/role slot. Fill in private RPT paths locally and do not commit populated private paths or raw RPT contents.

Run it against the current package tuple before treating runtime evidence as complete:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Test-WaspRuntimeEvidenceManifest.ps1 `
  -ManifestPath "C:\WASP\rpt-archive\runtime-evidence-4893faaa5d.json" `
  -ExpectedCandidate release-command-center-20260630 `
  -ExpectedGit 4893faaa5d `
  -ExpectedArchiveSha256 22F5AEE4BAF78FCB417A5C7CB7C76B2E1C67B7968541F95EB47527E0AF2A085E `
  -ArchivePath "C:\WASP\release\_MISSIONS.7z"
```

Default required slots are `chernarus,takistan` x `server,hc1,hc2,start-client,late-jip`. Use `-RequiredTerrain` or `-RequiredRole` only when the release owner explicitly narrows the evidence matrix.

Manifest validation also checks each marker-sweep artifact's `expectedRole` and `expectedTerrain` against its manifest row, so a server sweep cannot accidentally satisfy an HC/JIP slot and a broad or wrong-terrain sweep cannot satisfy the other terrain. `-ArchivePath` is optional but recommended whenever the package artifact is locally available; it hashes the package and verifies it against `-ExpectedArchiveSha256` without copying private RPT contents into git.

Run the helper contract self-test after editing it:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Test-WaspRptMarkerSweep.SelfTest.ps1
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Test-WaspRuntimeEvidenceManifest.SelfTest.ps1
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Test-WaspRuntimeEvidenceManifestTemplate.SelfTest.ps1
```
