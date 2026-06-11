<#
.SYNOPSIS
    List, extract, or replace entries in an uncompressed Arma 2 PBO file.

.DESCRIPTION
    Understands the A2 PBO on-disk format:
      - Optional leading extension/property header entry (empty filename, packing method
        magic 0x56657273 "sreV"), followed by null-terminated key=value property pairs
        ending with an empty key string.
      - File entry table: each entry is a null-terminated path + 5x uint32-LE
        (PackingMethod, OriginalSize, Reserved, Timestamp, DataSize); terminated by an
        all-zero entry (empty filename + all five fields = 0).
      - Raw file data in entry order (uncompressed; PM=0x43707273 compressed entries
        are refused).
      - Trailing: one 0x00 byte, then a 20-byte SHA1 over ALL bytes before that zero.

    Modes:
      -List         Print entry table (path, packing method, sizes, timestamp).
      -Extract      Write the named inner file to -OutFile.
      -ReplaceWith  Rebuild the PBO with the named entry replaced by -ReplaceWith
                    content; write to -OutPbo (never in-place); recompute SHA1.

    After -ReplaceWith the output is re-parsed to validate structure and byte counts.
    Compatible with PowerShell 5.1 (Windows PowerShell, runs on the Hetzner box).

.PARAMETER PboPath
    Path to the source PBO file.

.PARAMETER InnerFile
    Exact entry path inside the PBO (case-sensitive, e.g. "fnc_AINet.sqf").

.PARAMETER List
    Switch: dump the entry table and exit.

.PARAMETER Extract
    Switch: extract -InnerFile to -OutFile.

.PARAMETER OutFile
    Destination path for -Extract output.

.PARAMETER ReplaceWith
    Path to the file whose content replaces -InnerFile in the rebuilt PBO.

.PARAMETER OutPbo
    Destination path for the rebuilt PBO (required with -ReplaceWith).

.EXAMPLE
    .\Patch-PboFile.ps1 -PboPath asr_ai_settings.pbo -List

.EXAMPLE
    .\Patch-PboFile.ps1 -PboPath asr_ai_sys_aiskill.pbo -InnerFile fnc_AINet.sqf `
        -Extract -OutFile fnc_AINet.sqf

.EXAMPLE
    .\Patch-PboFile.ps1 -PboPath asr_ai_sys_aiskill.pbo -InnerFile fnc_AINet.sqf `
        -ReplaceWith fnc_AINet_patched.sqf -OutPbo asr_ai_sys_aiskill.PATCHED.pbo
#>
[CmdletBinding(DefaultParameterSetName = 'List')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$PboPath,

    [Parameter(ParameterSetName = 'Extract', Mandatory = $true)]
    [Parameter(ParameterSetName = 'Replace', Mandatory = $true)]
    [string]$InnerFile,

    [Parameter(ParameterSetName = 'List', Mandatory = $true)]
    [switch]$List,

    [Parameter(ParameterSetName = 'Extract', Mandatory = $true)]
    [switch]$Extract,

    [Parameter(ParameterSetName = 'Extract', Mandatory = $true)]
    [string]$OutFile,

    [Parameter(ParameterSetName = 'Replace', Mandatory = $true)]
    [string]$ReplaceWith,

    [Parameter(ParameterSetName = 'Replace', Mandatory = $true)]
    [string]$OutPbo
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Binary helpers
# ---------------------------------------------------------------------------
function Script:Read-NullString {
    param([byte[]]$Buf, [ref]$Pos)
    $start = $Pos.Value
    while ($Pos.Value -lt $Buf.Length -and $Buf[$Pos.Value] -ne 0) { $Pos.Value++ }
    $s = [System.Text.Encoding]::UTF8.GetString($Buf, $start, $Pos.Value - $start)
    $Pos.Value++   # consume null terminator
    return $s
}

function Script:Read-UInt32LE {
    param([byte[]]$Buf, [ref]$Pos)
    $v = [System.BitConverter]::ToUInt32($Buf, $Pos.Value)
    $Pos.Value += 4
    return $v
}

function Script:Write-NullString {
    param([System.IO.Stream]$Stream, [string]$s)
    if ($s.Length -gt 0) {
        $encoded = [System.Text.Encoding]::UTF8.GetBytes($s)
        $Stream.Write($encoded, 0, $encoded.Length)
    }
    $Stream.WriteByte(0)
}

function Script:Write-UInt32LE {
    param([System.IO.Stream]$Stream, [uint32]$v)
    $b = [System.BitConverter]::GetBytes($v)
    $Stream.Write($b, 0, 4)
}

# ---------------------------------------------------------------------------
# Parse a PBO into a structured object
# Returns: @{ HeaderProps=[hashtable]; Entries=[array of entry hashtables];
#             DataStart=[int]; RawBytes=[byte[]] }
# Each entry: Name, PackingMethod, OriginalSize, Reserved, Timestamp, DataSize,
#             DataOffset, Data=[byte[]]
# ---------------------------------------------------------------------------
function Script:Parse-Pbo {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "PBO not found: $Path"
    }
    $raw = [System.IO.File]::ReadAllBytes($Path)
    $pos = [ref]0

    # --- Header entry ---
    $headerName = Read-NullString $raw $pos
    $headerPM   = Read-UInt32LE  $raw $pos
    $null       = Read-UInt32LE  $raw $pos   # OriginalSize (always 0 in header)
    $null       = Read-UInt32LE  $raw $pos   # Reserved
    $null       = Read-UInt32LE  $raw $pos   # Timestamp
    $null       = Read-UInt32LE  $raw $pos   # DataSize (always 0 in header)

    # Tolerate PBOs with no sreV header (headerName is a real filename or headerPM != sreV magic)
    $hasSreV = ($headerName -eq '' -and $headerPM -eq 0x56657273)
    $props = @{}

    if ($hasSreV) {
        # Read key=value property pairs until empty key
        while ($true) {
            $key = Read-NullString $raw $pos
            if ($key -eq '') { break }
            $val = Read-NullString $raw $pos
            $props[$key] = $val
        }
    } else {
        # No sreV header - rewind and treat everything as file entries
        $pos.Value = 0
    }

    # --- File entries ---
    $entries = @()
    while ($true) {
        $entryStart = $pos.Value
        $name = Read-NullString $raw $pos
        $pm   = Read-UInt32LE  $raw $pos
        $os   = Read-UInt32LE  $raw $pos
        $rs   = Read-UInt32LE  $raw $pos
        $ts   = Read-UInt32LE  $raw $pos
        $ds   = Read-UInt32LE  $raw $pos

        # Terminator: all-zero entry
        if ($name -eq '' -and $pm -eq 0 -and $os -eq 0 -and $ds -eq 0) {
            break
        }

        $entries += @{
            Name          = $name
            PackingMethod = $pm
            OriginalSize  = $os
            Reserved      = $rs
            Timestamp     = $ts
            DataSize      = $ds
            DataOffset    = 0     # filled in below
            Data          = $null # filled in below
        }
    }

    $dataStart = $pos.Value

    # Assign data offsets and read data blobs
    $offset = $dataStart
    foreach ($e in $entries) {
        $e.DataOffset = $offset
        if ($e.DataSize -gt 0) {
            $blob = New-Object byte[] $e.DataSize
            [System.Array]::Copy($raw, $offset, $blob, 0, $e.DataSize)
            $e.Data = $blob
        } else {
            $e.Data = [byte[]]@()
        }
        $offset += $e.DataSize
    }

    # Verify trailer
    $expectedEnd = $offset
    if ($expectedEnd -ge $raw.Length -or $raw[$expectedEnd] -ne 0) {
        throw "PBO parse error: expected trailing 0x00 at offset $expectedEnd (file size=$($raw.Length))"
    }
    $storedSha1 = $raw[($expectedEnd + 1)..($expectedEnd + 20)]
    $sha1Engine = [System.Security.Cryptography.SHA1]::Create()
    $computedSha1 = $sha1Engine.ComputeHash($raw, 0, $expectedEnd)
    $storedHex   = [System.BitConverter]::ToString($storedSha1).Replace('-', '')
    $computedHex = [System.BitConverter]::ToString($computedSha1).Replace('-', '')
    if ($storedHex -ne $computedHex) {
        Write-Warning "SHA1 MISMATCH in $Path`n  stored:   $storedHex`n  computed: $computedHex"
    }

    return @{
        HasSreV    = $hasSreV
        HeaderProps = $props
        Entries    = $entries
        DataStart  = $dataStart
        RawBytes   = $raw
        StoredSha1 = $storedHex
    }
}

# ---------------------------------------------------------------------------
# Serialize a parsed PBO structure to a new byte array (no SHA1 yet)
# Returns the stream bytes BEFORE the trailing 0x00+SHA1
# ---------------------------------------------------------------------------
function Script:Serialize-PboBody {
    param($Pbo)

    $ms = New-Object System.IO.MemoryStream

    if ($Pbo.HasSreV) {
        # --- Header entry ---
        Write-NullString $ms ''       # empty filename
        Write-UInt32LE   $ms 0x56657273  # sreV magic
        Write-UInt32LE   $ms 0           # OriginalSize
        Write-UInt32LE   $ms 0           # Reserved
        Write-UInt32LE   $ms 0           # Timestamp
        Write-UInt32LE   $ms 0           # DataSize

        # Properties
        foreach ($kv in $Pbo.HeaderProps.GetEnumerator()) {
            Write-NullString $ms $kv.Key
            Write-NullString $ms $kv.Value
        }
        Write-NullString $ms ''  # end-of-properties empty key
    }

    # --- File entry table ---
    foreach ($e in $Pbo.Entries) {
        Write-NullString $ms $e.Name
        Write-UInt32LE   $ms $e.PackingMethod
        Write-UInt32LE   $ms $e.OriginalSize
        Write-UInt32LE   $ms $e.Reserved
        Write-UInt32LE   $ms $e.Timestamp
        Write-UInt32LE   $ms $e.DataSize
    }

    # Terminator entry
    Write-NullString $ms ''
    Write-UInt32LE   $ms 0
    Write-UInt32LE   $ms 0
    Write-UInt32LE   $ms 0
    Write-UInt32LE   $ms 0
    Write-UInt32LE   $ms 0

    # --- File data ---
    foreach ($e in $Pbo.Entries) {
        if ($e.DataSize -gt 0) {
            $ms.Write($e.Data, 0, $e.Data.Length)
        }
    }

    return $ms.ToArray()
}

# ---------------------------------------------------------------------------
# Write body + trailing 0x00 + SHA1 to a file
# ---------------------------------------------------------------------------
function Script:Write-PboFile {
    param([byte[]]$Body, [string]$OutPath)

    $sha1Engine = [System.Security.Cryptography.SHA1]::Create()
    $digest     = $sha1Engine.ComputeHash($Body)

    $ms = New-Object System.IO.MemoryStream ($Body.Length + 21)
    $ms.Write($Body, 0, $Body.Length)
    $ms.WriteByte(0)
    $ms.Write($digest, 0, 20)

    [System.IO.File]::WriteAllBytes($OutPath, $ms.ToArray())
    return [System.BitConverter]::ToString($digest).Replace('-', '')
}

# ===========================================================================
# MAIN
# ===========================================================================
$pbo = Parse-Pbo $PboPath

# ---------------------------------------------------------------------------
# -List
# ---------------------------------------------------------------------------
if ($PSCmdlet.ParameterSetName -eq 'List') {
    Write-Host ""
    Write-Host ("PBO: {0}  ({1} bytes)" -f (Split-Path $PboPath -Leaf), (Get-Item $PboPath).Length)
    if ($pbo.HasSreV) {
        Write-Host "Type: sreV header present"
        foreach ($kv in $pbo.HeaderProps.GetEnumerator()) {
            Write-Host ("  {0} = {1}" -f $kv.Key, $kv.Value)
        }
    } else {
        Write-Host "Type: no sreV header"
    }
    Write-Host ""
    Write-Host ("{0,-50} {1,-12} {2,12} {3,12} {4,12}" -f "Entry path", "PM", "OriginalSize", "DataSize", "Timestamp")
    Write-Host ("-" * 102)
    foreach ($e in $pbo.Entries) {
        $pmStr = if ($e.PackingMethod -eq 0) { "uncompressed" }
                 elseif ($e.PackingMethod -eq 0x43707273) { "COMPRESSED" }
                 else { "0x{0:X8}" -f $e.PackingMethod }
        Write-Host ("{0,-50} {1,-12} {2,12} {3,12} {4,12}" -f $e.Name, $pmStr, $e.OriginalSize, $e.DataSize, $e.Timestamp)
    }
    Write-Host ""
    Write-Host ("SHA1 trailer: {0}" -f $pbo.StoredSha1)
    return
}

# Shared: find the requested entry
$target = $pbo.Entries | Where-Object { $_.Name -eq $InnerFile }
if (-not $target) {
    $avail = ($pbo.Entries | ForEach-Object { $_.Name }) -join ', '
    throw "Entry '$InnerFile' not found in $PboPath.`nAvailable: $avail"
}

# Refuse compressed entries
if ($target.PackingMethod -eq 0x43707273) {
    throw "Entry '$InnerFile' uses lzss compression (PM=0x43707273). Decompression not implemented - BLOCKED."
}
if ($target.PackingMethod -ne 0) {
    throw ("Entry '$InnerFile' has unexpected PackingMethod 0x{0:X8} - cannot patch safely." -f $target.PackingMethod)
}

# ---------------------------------------------------------------------------
# -Extract
# ---------------------------------------------------------------------------
if ($PSCmdlet.ParameterSetName -eq 'Extract') {
    $outDir = Split-Path $OutFile -Parent
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Force $outDir | Out-Null
    }
    [System.IO.File]::WriteAllBytes($OutFile, $target.Data)
    Write-Host ("Extracted '{0}' ({1} bytes) -> {2}" -f $InnerFile, $target.DataSize, $OutFile)
    return
}

# ---------------------------------------------------------------------------
# -ReplaceWith
# ---------------------------------------------------------------------------
if (-not (Test-Path $ReplaceWith)) {
    throw "Replacement file not found: $ReplaceWith"
}

$newData = [System.IO.File]::ReadAllBytes($ReplaceWith)
$newSize = [uint32]$newData.Length

Write-Host ("Replacing '{0}': {1} bytes -> {2} bytes" -f $InnerFile, $target.DataSize, $newSize)

# Mutate the entry in-place
$target.DataSize     = $newSize
$target.OriginalSize = $newSize   # uncompressed: OrigSize = DataSize
$target.Data         = $newData

# Serialize
$body    = Serialize-PboBody $pbo
$sha1hex = Write-PboFile $body $OutPbo

Write-Host ("Written: {0}  ({1} bytes)  SHA1={2}" -f $OutPbo, (Get-Item $OutPbo).Length, $sha1hex)

# ---------------------------------------------------------------------------
# Validation: re-parse the output and verify
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Validating output..."
$reparsed = Parse-Pbo $OutPbo
$reparsedTarget = $reparsed.Entries | Where-Object { $_.Name -eq $InnerFile }
if (-not $reparsedTarget) {
    throw "VALIDATION FAILED: entry '$InnerFile' not found in reparsed output!"
}
if ($reparsedTarget.DataSize -ne $newSize) {
    throw ("VALIDATION FAILED: DataSize mismatch: expected $newSize got $($reparsedTarget.DataSize)")
}
# Byte-compare the data blob
$match = $true
if ($reparsedTarget.Data.Length -ne $newData.Length) {
    $match = $false
} else {
    for ($i = 0; $i -lt $newData.Length; $i++) {
        if ($reparsedTarget.Data[$i] -ne $newData[$i]) { $match = $false; break }
    }
}
if (-not $match) {
    throw "VALIDATION FAILED: reparsed data for '$InnerFile' does not match replacement content!"
}
# Entry count preserved
if ($reparsed.Entries.Count -ne $pbo.Entries.Count) {
    throw ("VALIDATION FAILED: entry count changed ({0} -> {1})" -f $pbo.Entries.Count, $reparsed.Entries.Count)
}
# SHA1 round-trip
if ($reparsed.StoredSha1 -ne $sha1hex) {
    throw "VALIDATION FAILED: SHA1 in reparsed file does not match written SHA1!"
}
Write-Host ("  Entry count : {0} (unchanged)" -f $reparsed.Entries.Count)
Write-Host ("  DataSize    : {0} bytes (correct)" -f $reparsedTarget.DataSize)
Write-Host ("  Data bytes  : byte-identical to replacement file")
Write-Host ("  SHA1        : {0} (verified)" -f $sha1hex)
Write-Host "Validation PASSED."
