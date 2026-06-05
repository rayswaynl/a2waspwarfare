param(
    [string[]]$Roots = @("Missions", "Missions_Vanilla", "Modded_Missions"),
    [string]$OutputPath = "docs/analysis/dead-code-pv-channel-scan.json"
)

$ErrorActionPreference = "Stop"

function Get-RelativeLiteralPath {
    param([string]$Path)

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $base = (Get-Location).Path
    if ($resolved.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        return $resolved.Substring($base.Length + 1)
    }

    return $resolved
}

function Get-MissionRootLabel {
    param([string]$RelativePath)

    $parts = $RelativePath -split '[\\/]'
    for ($i = 0; $i -lt $parts.Length; $i++) {
        if ($parts[$i] -in @("Missions", "Missions_Vanilla", "Modded_Missions")) {
            if ($i + 1 -lt $parts.Length) {
                return "$($parts[$i])/$($parts[$i + 1])"
            }
        }
    }

    return "unknown"
}

function Test-CommentOnlyLine {
    param([string]$Line)

    $trimmed = $Line.TrimStart()
    return $trimmed.StartsWith("//") -or $trimmed.StartsWith("*") -or $trimmed.StartsWith("/*")
}

function Add-Record {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Kind,
        [string]$Channel,
        [string]$Function,
        [System.IO.FileInfo]$File,
        [int]$LineNumber,
        [string]$Line
    )

    $relative = Get-RelativeLiteralPath -Path $File.FullName
    $List.Add([PSCustomObject]@{
        kind = $Kind
        channel = $Channel
        function = $Function
        source = $relative
        missionRoot = Get-MissionRootLabel -RelativePath $relative
        line = $LineNumber
        commentOnly = Test-CommentOnlyLine -Line $Line
        text = $Line.Trim()
    })
}

$textExtensions = @(".sqf", ".fsm", ".hpp", ".ext")
$files = foreach ($root in $Roots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Recurse -File | Where-Object { $textExtensions -contains $_.Extension.ToLowerInvariant() }
    }
}

$records = [System.Collections.Generic.List[object]]::new()
$eventHandlerRegex = '"([^"]+)"\s+addPublicVariableEventHandler'
$publicVariableRegex = '\b(publicVariableServer|publicVariableClient|publicVariable)\s+"([^"]+)"'
$publicVariableSingleRegex = "\b(publicVariableServer|publicVariableClient|publicVariable)\s+'([^']+)'"

foreach ($file in $files) {
    $lines = Get-Content -LiteralPath $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        foreach ($match in [regex]::Matches($line, $eventHandlerRegex)) {
            Add-Record -List $records -Kind "receiver" -Channel $match.Groups[1].Value -Function "addPublicVariableEventHandler" -File $file -LineNumber ($i + 1) -Line $line
        }

        foreach ($match in [regex]::Matches($line, $publicVariableRegex)) {
            Add-Record -List $records -Kind "sender" -Channel $match.Groups[2].Value -Function $match.Groups[1].Value -File $file -LineNumber ($i + 1) -Line $line
        }

        foreach ($match in [regex]::Matches($line, $publicVariableSingleRegex)) {
            Add-Record -List $records -Kind "sender" -Channel $match.Groups[2].Value -Function $match.Groups[1].Value -File $file -LineNumber ($i + 1) -Line $line
        }
    }
}

$activeRecords = @($records | Where-Object { -not $_.commentOnly })
$commentRecords = @($records | Where-Object { $_.commentOnly })

$channels = foreach ($channel in ($records | Select-Object -ExpandProperty channel -Unique | Sort-Object)) {
    $channelRecords = @($records | Where-Object { $_.channel -eq $channel })
    $activeChannelRecords = @($channelRecords | Where-Object { -not $_.commentOnly })
    $senders = @($activeChannelRecords | Where-Object { $_.kind -eq "sender" })
    $receivers = @($activeChannelRecords | Where-Object { $_.kind -eq "receiver" })
    $commentSenders = @($channelRecords | Where-Object { $_.kind -eq "sender" -and $_.commentOnly })
    $commentReceivers = @($channelRecords | Where-Object { $_.kind -eq "receiver" -and $_.commentOnly })

    [PSCustomObject]@{
        channel = $channel
        activeSenderCount = $senders.Count
        activeReceiverCount = $receivers.Count
        commentSenderCount = $commentSenders.Count
        commentReceiverCount = $commentReceivers.Count
        activeMissionRoots = @($activeChannelRecords | Select-Object -ExpandProperty missionRoot -Unique | Sort-Object)
        activeSenders = $senders
        activeReceivers = $receivers
        commentOnlyReferences = @($channelRecords | Where-Object { $_.commentOnly })
    }
}

$result = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString("o")
    roots = $Roots
    scannedFiles = @($files).Count
    totalRecords = $records.Count
    activeRecords = $activeRecords.Count
    commentOnlyRecords = $commentRecords.Count
    activeChannelCount = @($channels | Where-Object { $_.activeSenderCount -gt 0 -or $_.activeReceiverCount -gt 0 }).Count
    activeSenderOnlyChannels = @($channels | Where-Object { $_.activeSenderCount -gt 0 -and $_.activeReceiverCount -eq 0 })
    activeReceiverOnlyChannels = @($channels | Where-Object { $_.activeReceiverCount -gt 0 -and $_.activeSenderCount -eq 0 })
    commentOnlyChannels = @($channels | Where-Object { $_.activeReceiverCount -eq 0 -and $_.activeSenderCount -eq 0 -and ($_.commentSenderCount + $_.commentReceiverCount) -gt 0 })
    channels = @($channels)
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
$result
