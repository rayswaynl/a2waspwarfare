#requires -Version 5.1
<#!
.SYNOPSIS
    Guards against registering non-functional GUER defensive assets.

.DESCRIPTION
    The GUER air-defense loop and town-garrison dressing loop must only count
    their fresh assets after the intended crew occupy their required seats.
    A failed driver/gunner placement must clean up the fresh local asset rather
    than consuming the town/cap slot with a harmless hull or loose crewman.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'
$script:Failures = 0

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
}

function Read-RequiredText {
    param([Parameter(Mandatory)] [string]$RelativePath)

    $path = Join-Path $RepoRoot $RelativePath
    if (!(Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path"
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Match {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($Text -match $Pattern) {
        Write-Host ("  PASS  {0}" -f $Label)
    } else {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
    }
}

function Assert-EqualText {
    param(
        [Parameter(Mandatory)] [string]$Left,
        [Parameter(Mandatory)] [string]$Right,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($Left -ceq $Right) {
        Write-Host ("  PASS  {0}" -f $Label)
    } else {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
    }
}

function Remove-SqfLineComments {
    param([Parameter(Mandatory)] [string]$Text)

    return (($Text -split "\r?\n" | ForEach-Object { $_ -replace '//.*$', '' }) -join "`n")
}

function Get-SqfBlockFromOpenBrace {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [int]$OpenBraceIndex,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($OpenBraceIndex -lt 0 -or $OpenBraceIndex -ge $Text.Length -or $Text[$OpenBraceIndex] -ne '{') {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
        return $null
    }

    $depth = 0
    for ($index = $OpenBraceIndex; $index -lt $Text.Length; $index++) {
        if ($Text[$index] -eq '{') { $depth++ }
        if ($Text[$index] -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return [pscustomobject]@{
                    Start = $OpenBraceIndex
                    End = $index
                    Text = $Text.Substring($OpenBraceIndex, $index - $OpenBraceIndex + 1)
                }
            }
        }
    }

    Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
    $script:Failures++
    return $null
}

function Get-SqfBranchBlock {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label,
        [int]$Occurrence = 0
    )

    $matches = [regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($matches.Count -le $Occurrence) {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
        return $null
    }

    $match = $matches[$Occurrence]
    $openBrace = $match.Groups['open']
    if (!$openBrace.Success) {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
        return $null
    }

    return Get-SqfBlockFromOpenBrace -Text $Text -OpenBraceIndex $openBrace.Index -Label $Label
}

function Get-SqfElseBlock {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [AllowNull()] $IfBlock,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($null -eq $IfBlock) { return $null }
    $suffixStart = $IfBlock.End + 1
    $suffix = $Text.Substring($suffixStart)
    $match = [regex]::Match($suffix, '^\s*else\s*(?<open>\{)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (!$match.Success) {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
        return $null
    }

    return Get-SqfBlockFromOpenBrace -Text $Text -OpenBraceIndex ($suffixStart + $match.Index + $match.Length - 1) -Label $Label
}

function Assert-BlockMatch {
    param(
        $Block,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($null -ne $Block) { Assert-Match -Text $Block.Text -Pattern $Pattern -Label $Label }
}

function Assert-BlockNotMatch {
    param(
        $Block,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($null -eq $Block) { return }
    if ($Block.Text -match $Pattern) {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
    } else {
        Write-Host ("  PASS  {0}" -f $Label)
    }
}

$chernarusAirDef = 'Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Server_GuerAirDef.sqf'
$takistanAirDef = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan\Server\Server_GuerAirDef.sqf'
$zargabadAirDef = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad\Server\Server_GuerAirDef.sqf'
$chernarusGarrison = 'Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Server_TownGarrisonDressing.sqf'
$takistanGarrison = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan\Server\Server_TownGarrisonDressing.sqf'
$zargabadGarrison = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad\Server\Server_TownGarrisonDressing.sqf'

$airDef = Read-RequiredText $chernarusAirDef
$garrison = Read-RequiredText $chernarusGarrison
$airDefCode = Remove-SqfLineComments $airDef
$garrisonCode = Remove-SqfLineComments $garrison

Write-Host 'Checking air-defense crew admission'
Assert-Match $airDef '(?s)_airCrewReady\s*=.*?\(driver _veh\)\s*==\s*_pilot.*?\(gunner _veh\)\s*==\s*_gunner' 'Air-defense verifies pilot and gunner seat occupancy'
Assert-Match $airDef 'GUERAIRDEF\|SPAWNFAIL\|.*reason=crew_seat' 'Air-defense records seat-placement failure'
$airAdmission = Get-SqfBranchBlock -Text $airDefCode -Pattern 'if\s*\(\s*_airCrewReady\s*\)\s*then\s*(?<open>\{)' -Label 'Air-defense admission branch exists'
$airFailure = Get-SqfBranchBlock -Text $airDefCode -Pattern 'if\s*\(\s*!_airCrewReady\s*\)\s*then\s*(?<open>\{)' -Label 'Air-defense seat-failure branch exists' -Occurrence 1
Assert-BlockMatch $airAdmission '_defenders\s*=\s*_defenders' 'Air-defense registers inside the fully crewed branch'
Assert-BlockMatch $airFailure '(?s)deleteVehicle _pilot.*deleteVehicle _gunner.*deleteVehicle _veh.*deleteGroup _grp' 'Air-defense seat failure cleans fresh crew, hull, and group'
Assert-BlockNotMatch $airFailure 'GUERAIRDEF\|SPAWN\|' 'Air-defense seat failure cannot emit spawn success'
Assert-Match $airDef '(?s)_swarmCrewReady\s*=.*?\(driver _eVeh2\)\s*==\s*_ePilot.*?\(gunner _eVeh2\)\s*==\s*_eGunner' 'Swarm extras verify pilot and gunner seat occupancy'
Assert-Match $airDef 'GUERAIRDEF\|SWARMFAIL\|.*reason=crew_seat' 'Swarm extras record seat-placement failure'
$swarmAdmission = Get-SqfBranchBlock -Text $airDefCode -Pattern 'if\s*\(\s*_swarmCrewReady\s*\)\s*then\s*(?<open>\{)' -Label 'Swarm admission branch exists'
$swarmFailure = Get-SqfBranchBlock -Text $airDefCode -Pattern 'if\s*\(\s*!_swarmCrewReady\s*\)\s*then\s*(?<open>\{)' -Label 'Swarm seat-failure branch exists' -Occurrence 1
Assert-BlockMatch $swarmAdmission '_defenders\s*=\s*_defenders' 'Swarm registers inside the fully crewed branch'
Assert-BlockMatch $swarmFailure '(?s)deleteVehicle _ePilot.*deleteVehicle _eGunner.*deleteVehicle _eVeh2' 'Swarm seat failure cleans only fresh crew and hull'
Assert-BlockNotMatch $swarmFailure 'deleteGroup _grp' 'Swarm seat failure preserves the shared leader group'
Assert-Match $airDef '_defenders\s*=\s*_defenders\s*\+\s*\[\[_town, _veh, _grp, _pilot, _gunner, time, time\]\]' 'Air-defense records the admitted pilot and gunner for lifecycle checks'
Assert-Match $airDef '_defenders\s*=\s*_defenders\s*\+\s*\[\[_town, _eVeh2, _grp, _ePilot, _eGunner, time, time\]\]' 'Swarm records each admitted pilot and gunner for lifecycle checks'
Assert-Match $airDef '(?s)_ePilot\s*=\s*_entry select 3;.*?_eGunner\s*=\s*_entry select 4;' 'Air-defense prune reads recorded pilot and gunner'
$airCrewPrune = Get-SqfBranchBlock -Text $airDefCode -Pattern 'if\s*\(\s*!_drop\s*&&\s*\{\s*isNull _ePilot.*?isNull _eGunner.*?\}\s*\)\s*then\s*(?<open>\{)' -Label 'Air-defense dead-crew prune branch exists'
$airSeatPrune = Get-SqfBranchBlock -Text $airDefCode -Pattern 'if\s*\(\s*!_drop\s*&&\s*\{.*?\(driver _eVeh\)\s*!=\s*_ePilot.*?\(gunner _eVeh\)\s*!=\s*_eGunner.*?\}\s*\)\s*then\s*(?<open>\{)' -Label 'Air-defense seat-prune branch exists'
Assert-BlockMatch $airCrewPrune '_drop\s*=\s*true' 'Air-defense prune marks dead or missing crew for removal'
Assert-BlockMatch $airSeatPrune '_drop\s*=\s*true' 'Air-defense prune marks a lost or displaced crew for removal'

Write-Host 'Checking town-garrison gunner admission'
Assert-Match $garrison '_gunnerSeated\s*=\s*\(\(gunner _gun\)\s*==\s*_crew\)' 'Garrison verifies the gunner seat after retry'
Assert-Match $garrison 'GARNDRESS\|FAIL\|.*reason=gunner_unseated' 'Garrison records a failed gunner placement'
$garrisonAdmission = Get-SqfBranchBlock -Text $garrisonCode -Pattern 'if\s*\(\s*_gunnerSeated\s*\)\s*then\s*(?<open>\{)' -Label 'Garrison admission branch exists'
$garrisonFailure = Get-SqfElseBlock -Text $garrisonCode -IfBlock $garrisonAdmission -Label 'Garrison seat-failure branch exists'
Assert-BlockMatch $garrisonAdmission '_registry\s*=\s*_registry' 'Garrison registers inside the seated-gunner branch'
Assert-BlockMatch $garrisonFailure '(?s)deleteVehicle _crew.*deleteVehicle _gun.*deleteGroup _grp' 'Garrison seat failure cleans fresh crew, hull, and group'
Assert-BlockNotMatch $garrisonFailure 'GARNDRESS\|PLACE' 'Garrison seat failure cannot emit placement success'
$garrisonCrewPrune = Get-SqfBranchBlock -Text $garrisonCode -Pattern 'if\s*\(\s*!_drop\s*\)\s*then\s*\{\s*if\s*\(\s*isNull _eCrew\s*\|\|\s*\{\s*!\(alive _eCrew\)\s*\}\s*\)\s*then\s*(?<open>\{)' -Label 'Garrison dead-crew prune branch exists'
$garrisonSeatPrune = Get-SqfBranchBlock -Text $garrisonCode -Pattern 'if\s*\(\s*!_drop\s*&&\s*\{\s*\(\(gunner _eGun\)\s*!=\s*_eCrew\)\s*\}\s*\)\s*then\s*(?<open>\{)' -Label 'Garrison seat-prune branch exists'
Assert-BlockMatch $garrisonCrewPrune '_drop\s*=\s*true' 'Garrison prune marks dead or missing gunner for removal'
Assert-BlockMatch $garrisonSeatPrune '_drop\s*=\s*true' 'Garrison prune marks a displaced gunner for removal'

Write-Host 'Checking maintained-mirror parity'
Assert-EqualText $airDef (Read-RequiredText $takistanAirDef) 'Takistan air-defense mirror matches Chernarus'
Assert-EqualText $airDef (Read-RequiredText $zargabadAirDef) 'Zargabad air-defense mirror matches Chernarus'
Assert-EqualText $garrison (Read-RequiredText $takistanGarrison) 'Takistan garrison mirror matches Chernarus'
Assert-EqualText $garrison (Read-RequiredText $zargabadGarrison) 'Zargabad garrison mirror matches Chernarus'

Write-Host ''
if ($script:Failures -eq 0) {
    Write-Host 'Test-GuerDefensiveCrewAtomic: PASS' -ForegroundColor Green
    exit 0
}

Write-Host ("Test-GuerDefensiveCrewAtomic: {0} failure(s)" -f $script:Failures) -ForegroundColor Red
exit 1
