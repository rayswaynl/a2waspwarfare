#requires -Version 5.1
<#
.SYNOPSIS
    Guards the SML camp-split cargo-ejection contract across maintained terrains.

.DESCRIPTION
    SML-1 must eject seated non-crew infantry before issuing its per-unit camp
    orders.  SML-1 and SML-2 are independent spawned workers, so SML-1 may only
    stamp and rejoin units for which it successfully claims the shared stamp;
    it must preserve a stamp already owned by another SML worker.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$script:Fails = 0
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Assert-True {
    param(
        [Parameter(Mandatory)] [bool]$Condition,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($Condition) {
        Write-Host ("  PASS  {0}" -f $Label)
    } else {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Fails++
    }
}

function Assert-Match {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    Assert-True -Condition ($Text -match $Pattern) -Label $Label
}

$terrains = @(
    @{ Name = "Chernarus"; Root = "Missions\[55-2hc]warfarev2_073v48co.chernarus" },
    @{ Name = "Takistan";  Root = "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan" },
    @{ Name = "Zargabad";  Root = "Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad" }
)

$campTexts = @{}
foreach ($terrain in $terrains) {
    $campPath = Join-Path $repoRoot (Join-Path $terrain.Root "Common\Functions\Common_SMLCampSplit.sqf")
    $dismountPath = Join-Path $repoRoot (Join-Path $terrain.Root "Common\Functions\Common_SMLDismounts.sqf")
    $constantsPath = Join-Path $repoRoot (Join-Path $terrain.Root "Common\Init\Init_CommonConstants.sqf")

    Assert-True -Condition (Test-Path -LiteralPath $campPath) -Label ("{0}: camp-split worker exists" -f $terrain.Name)
    Assert-True -Condition (Test-Path -LiteralPath $dismountPath) -Label ("{0}: dismount worker exists" -f $terrain.Name)
    Assert-True -Condition (Test-Path -LiteralPath $constantsPath) -Label ("{0}: constants exist" -f $terrain.Name)
    if (!(Test-Path -LiteralPath $campPath) -or !(Test-Path -LiteralPath $dismountPath) -or !(Test-Path -LiteralPath $constantsPath)) {
        continue
    }

    $campText = Get-Content -LiteralPath $campPath -Raw
    $dismountText = Get-Content -LiteralPath $dismountPath -Raw
    $constantsText = Get-Content -LiteralPath $constantsPath -Raw
    $campTexts[$terrain.Name] = $campText

    Assert-Match -Text $constantsText -Pattern 'WFBE_C_SML_CAMP_SPLIT\s*=\s*1' -Label ("{0}: SML-1 is default-on" -f $terrain.Name)
    Assert-Match -Text $constantsText -Pattern 'WFBE_C_SML_DISMOUNTS\s*=\s*1' -Label ("{0}: SML-2 is default-on" -f $terrain.Name)
    Assert-Match -Text $dismountText -Pattern 'if \(!\(isNil \{_uX getVariable "wfbe_sml_detach_at"\}\)\) then' -Label ("{0}: SML-2 preserves another worker's stamp ownership" -f $terrain.Name)

    $ownerClaimMatch = [regex]::Match($campText, 'if \(isNil \{_x getVariable "wfbe_sml_detach_at"\}\) then \{\s*_x setVariable \["wfbe_sml_detach_at", _stamp\];\s*_detachedBySML1 set \[count _detachedBySML1, _x\];\s*\};')
    Assert-True -Condition $ownerClaimMatch.Success -Label ("{0}: SML-1 preserves a foreign stamp and tracks only its own claim" -f $terrain.Name)
    Assert-Match -Text $campText -Pattern 'Private \[[^\]]*"_detachedBySML1"' -Label ("{0}: SML-1 has an explicit owned-unit receipt" -f $terrain.Name)
    Assert-Match -Text $campText -Pattern '_nFoot = count _detachedBySML1;\s*if \(_nFoot < 3\) exitWith' -Label ("{0}: SML-1 declines a split when its owned receipt is too small" -f $terrain.Name)

    $normalEjectStart = $campText.IndexOf('//--- Eject only SML-1-owned seated foot infantry.')
    $orderIndex = $campText.IndexOf('//--- Issue one-shot movement orders', $normalEjectStart)
    $normalEjectBlock = if ($normalEjectStart -ge 0 -and $orderIndex -gt $normalEjectStart) { $campText.Substring($normalEjectStart, $orderIndex - $normalEjectStart) } else { '' }
    $ownedEjectMatch = [regex]::Match($normalEjectBlock, 'if \(alive _x && \{vehicle _x != _x\}\) then \{\s*unassignVehicle _x;\s*moveOut _x;\s*\};\s*\} forEach _detachedBySML1;')
    Assert-True -Condition $ownedEjectMatch.Success -Label ("{0}: SML-1 normal split path ejects only its owned seated infantry" -f $terrain.Name)
    Assert-True -Condition ($ownerClaimMatch.Success -and $ownedEjectMatch.Success -and $ownerClaimMatch.Index -lt $normalEjectStart -and $normalEjectStart -lt $orderIndex) -Label ("{0}: SML-1 claims, ejects, then orders its owned set" -f $terrain.Name)

    $splitStart = $campText.IndexOf('_i = 0;')
    $splitEnd = $campText.IndexOf('//--- Hold position', $splitStart)
    $splitBlock = if ($splitStart -ge 0 -and $splitEnd -gt $splitStart) { $campText.Substring($splitStart, $splitEnd - $splitStart) } else { '' }
    Assert-Match -Text $splitBlock -Pattern '\} forEach _detachedBySML1;' -Label ("{0}: SML-1 builds camp split groups only from its owned receipt" -f $terrain.Name)
    Assert-True -Condition ($splitBlock -notmatch '\} forEach _footInf;') -Label ("{0}: SML-1 excludes foreign units from camp split groups" -f $terrain.Name)

    $groupChangeStart = $campText.IndexOf('_grpChg = false;')
    $groupChangeEnd = $campText.IndexOf('if (_grpChg) exitWith', $groupChangeStart)
    $groupChangeBlock = if ($groupChangeStart -ge 0 -and $groupChangeEnd -gt $groupChangeStart) { $campText.Substring($groupChangeStart, $groupChangeEnd - $groupChangeStart) } else { '' }
    Assert-Match -Text $groupChangeBlock -Pattern '\} forEach _detachedBySML1;' -Label ("{0}: SML-1 watchdog ignores foreign-unit group changes" -f $terrain.Name)
    Assert-True -Condition ($groupChangeBlock -notmatch '\} forEach _footInf;') -Label ("{0}: SML-1 watchdog excludes foreign-unit group changes" -f $terrain.Name)
    Assert-Match -Text $campText -Pattern '(?s)_x setVariable \["wfbe_sml_detach_at", nil\];.*?\} forEach _detachedBySML1;' -Label ("{0}: SML-1 rejoin is restricted to its owned-unit receipt" -f $terrain.Name)
}

if ($campTexts.Count -eq 3) {
    $chernarusHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($campTexts['Chernarus']))) -Algorithm SHA256).Hash
    foreach ($terrainName in @('Takistan', 'Zargabad')) {
        $terrainHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($campTexts[$terrainName]))) -Algorithm SHA256).Hash
        Assert-True -Condition ($terrainHash -eq $chernarusHash) -Label ("{0}: camp-split worker matches Chernarus" -f $terrainName)
    }
}

Write-Host ""
if ($script:Fails -eq 0) {
    Write-Host "Test-SMLCampSplitCargoEject: PASS" -ForegroundColor Green
    exit 0
}

Write-Host ("Test-SMLCampSplitCargoEject: {0} failure(s)" -f $script:Fails) -ForegroundColor Red
exit 1
