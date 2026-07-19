#requires -Version 5.1
<#!
.SYNOPSIS
    Guards the dead-spawn captive-state handoff in AI_AdvancedRespawn.

.DESCRIPTION
    A leader parked at a temporary dead-spawn marker is made captive and
    invulnerable while it waits.  If a human replaces that leader during the
    wait, the regular AI-respawn branch is skipped, so the state must still be
    restored before that skip branch is evaluated.
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

function Assert-NotMatch {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($Text -match $Pattern) {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
    } else {
        Write-Host ("  PASS  {0}" -f $Label)
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
        [Parameter(Mandatory)] [string]$Label
    )

    $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (!$match.Success -or !$match.Groups['open'].Success) {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
        return $null
    }

    return Get-SqfBlockFromOpenBrace -Text $Text -OpenBraceIndex $match.Groups['open'].Index -Label $Label
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

    return Get-SqfBlockFromOpenBrace -Text $Text -OpenBraceIndex ($suffixStart + $match.Groups['open'].Index) -Label $Label
}

function Assert-BlockMatch {
    param(
        $Block,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($null -ne $Block) {
        Assert-Match -Text $Block.Text -Pattern $Pattern -Label $Label
    }
}

function Assert-BlockNotMatch {
    param(
        $Block,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($null -ne $Block) {
        Assert-NotMatch -Text $Block.Text -Pattern $Pattern -Label $Label
    }
}

function Assert-BlockBetween {
    param(
        $Block,
        $After,
        $Before,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($null -eq $Block -or $null -eq $After -or $null -eq $Before) {
        return
    }

    if ($Block.Start -gt $After.End -and $Block.End -lt $Before.Start) {
        Write-Host ("  PASS  {0}" -f $Label)
    } else {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
    }
}

$chernarus = 'Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\AI\AI_AdvancedRespawn.sqf'
$takistan = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan\Server\AI\AI_AdvancedRespawn.sqf'
$zargabad = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad\Server\AI\AI_AdvancedRespawn.sqf'
$squadChernarus = 'Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\AI\AI_SquadRespawn.sqf'
$squadTakistan = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan\Server\AI\AI_SquadRespawn.sqf'
$squadZargabad = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad\Server\AI\AI_SquadRespawn.sqf'

$source = Read-RequiredText $chernarus
$code = Remove-SqfLineComments $source
$squadSource = Read-RequiredText $squadChernarus
$squadCode = Remove-SqfLineComments $squadSource

Write-Host 'Checking dead-spawn guard handoff'
Assert-Match $code "'_deadspawnGuardApplied'" 'Guard receipt is private to this respawn invocation'
Assert-Match $code '_deadspawnGuardApplied\s*=\s*false\s*;' 'Guard receipt starts as not applied'

$park = Get-SqfBranchBlock -Text $code -Pattern 'if\s*\(\s*\(missionNamespace\s+getVariable\s*\[\s*"WFBE_C_DEADSPAWN_GUARD"\s*,\s*1\s*\]\)\s*>\s*0\s*&&\s*\{\s*alive\s+_respawnedUnit\s*\}\s*\)\s*then\s*(?<open>\{)' -Label 'Dead-spawn guard admission branch exists'
Assert-BlockMatch $park 'setCaptive\s+true\s*;' 'Parked leader becomes captive'
Assert-BlockMatch $park 'allowDamage\s+false\s*;' 'Parked leader becomes invulnerable'
Assert-BlockMatch $park '_deadspawnGuardApplied\s*=\s*true\s*;' 'Park records that it changed the leader state'

$wait = Get-SqfBranchBlock -Text $code -Pattern 'while\s*\{\s*_i\s*>\s*0\s*\}\s*do\s*(?<open>\{)' -Label 'Respawn wait branch exists'
$handoffCheck = Get-SqfBranchBlock -Text $code -Pattern 'if\s*\(\s*isPlayer\s*\(\s*_respawnedUnit\s*\)\s*\|\|\s*!\s*\(\s*alive\s+_respawnedUnit\s*\)\s*\)\s*then\s*(?<open>\{)' -Label 'Post-wait player/death recheck exists'
$skipRelease = Get-SqfBranchBlock -Text $code -Pattern 'if\s*\(\s*_skip\s*&&\s*_deadspawnGuardApplied\s*&&\s*\{\s*alive\s+_respawnedUnit\s*\}\s*\)\s*then\s*(?<open>\{)' -Label 'Skipped handoff guard-release branch exists'
$continue = Get-SqfBranchBlock -Text $code -Pattern 'if\s*!\s*\(\s*_skip\s*\)\s*then\s*(?<open>\{)' -Label 'AI-only continuation branch exists'

Assert-BlockMatch $handoffCheck '_skip\s*=\s*true' 'Post-wait recheck marks a human/dead leader as skipped'
Assert-BlockBetween -Block $handoffCheck -After $wait -Before $skipRelease -Label 'Post-wait recheck closes the final-sleep handoff race'
Assert-BlockBetween -Block $skipRelease -After $handoffCheck -Before $continue -Label 'Skipped handoff releases the guard before AI-only work is bypassed'
Assert-BlockMatch $skipRelease 'setCaptive\s+false\s*;' 'Skipped leader is no longer captive'
Assert-BlockMatch $skipRelease 'allowDamage\s+true\s*;' 'Skipped leader can take damage again'
Assert-BlockMatch $skipRelease 'DEADSPAWN_GUARD\|release\|' 'Skipped handoff release is observable in the server log'
Assert-BlockNotMatch $skipRelease 'WFBE_C_DEADSPAWN_GUARD' 'Skipped handoff follows the actual guard receipt, not a mutable config reread'
Assert-BlockMatch $continue '(?s)if\s*\(\s*_deadspawnGuardApplied\s*&&\s*\{\s*alive\s+_respawnedUnit\s*\}\s*\)\s*then\s*\{.*?setCaptive\s+false\s*;.*?allowDamage\s+true\s*;.*?\}\s*;\s*_pos\s*=' 'Normal AI release stays adjacent to leaving the temp marker'
Assert-BlockNotMatch $continue 'WFBE_C_DEADSPAWN_GUARD' 'Normal AI release follows the actual guard receipt, not a mutable config reread'

Write-Host 'Checking Vanilla squad-respawn guard handoff'
Assert-Match $squadCode '\b_deadspawnGuardApplied\b' 'Vanilla guard receipt is private to this respawn worker'
Assert-Match $squadCode '(?s)_leader\s*=\s*leader\s+_team\s*;\s*_deadspawnGuardApplied\s*=\s*false\s*;' 'Vanilla guard receipt resets for every new leader'
$squadPark = Get-SqfBranchBlock -Text $squadCode -Pattern 'if\s*\(\s*\(missionNamespace\s+getVariable\s*\[\s*"WFBE_C_DEADSPAWN_GUARD"\s*,\s*1\s*\]\)\s*>\s*0\s*&&\s*\{\s*alive\s+_leader\s*\}\s*\)\s*then\s*(?<open>\{)' -Label 'Vanilla dead-spawn guard admission branch exists'
Assert-BlockMatch $squadPark 'setCaptive\s+true\s*;' 'Vanilla parked leader becomes captive'
Assert-BlockMatch $squadPark 'allowDamage\s+false\s*;' 'Vanilla parked leader becomes invulnerable'
Assert-BlockMatch $squadPark '_deadspawnGuardApplied\s*=\s*true\s*;' 'Vanilla park records that it changed the leader state'
$squadHandoff = Get-SqfBranchBlock -Text $squadCode -Pattern 'if\s*\(\s*isPlayer\s*\(?\s*_leader\s*\)?\s*\|\|\s*!\s*\(\s*alive\s+_leader\s*\)\s*\)\s*then\s*(?<open>\{)' -Label 'Vanilla post-wait player/death recheck exists'
$squadContinue = Get-SqfElseBlock -Text $squadCode -IfBlock $squadHandoff -Label 'Vanilla AI-only continuation branch exists'
Assert-Match $squadCode '(?s)sleep\s+_rd\s*;\s*if\s*\(\s*isPlayer\s*\(?\s*_leader\s*\)?\s*\|\|\s*!\s*\(\s*alive\s+_leader\s*\)\s*\)\s*then' 'Vanilla rechecks immediately after its respawn sleep'
Assert-BlockMatch $squadHandoff '_deadspawnGuardApplied\s*&&\s*\{\s*alive\s+_leader\s*\}' 'Vanilla skipped handoff releases only an applied live guard'
Assert-BlockMatch $squadHandoff 'setCaptive\s+false\s*;' 'Vanilla skipped leader is no longer captive'
Assert-BlockMatch $squadHandoff 'allowDamage\s+true\s*;' 'Vanilla skipped leader can take damage again'
Assert-BlockMatch $squadHandoff 'DEADSPAWN_GUARD\|release\|' 'Vanilla skipped handoff release is observable in the server log'
Assert-BlockNotMatch $squadHandoff 'WFBE_C_DEADSPAWN_GUARD' 'Vanilla skipped handoff follows the actual guard receipt'
Assert-BlockMatch $squadContinue '(?s)if\s*\(\s*_deadspawnGuardApplied\s*&&\s*\{\s*alive\s+_leader\s*\}\s*\)\s*then\s*\{.*?setCaptive\s+false\s*;.*?allowDamage\s+true\s*;.*?\}\s*;\s*_pos\s*=' 'Vanilla normal AI release stays adjacent to leaving the temp marker'
Assert-BlockNotMatch $squadContinue 'WFBE_C_DEADSPAWN_GUARD' 'Vanilla normal release follows the actual guard receipt'

Write-Host 'Checking maintained-mirror parity'
Assert-EqualText $source (Read-RequiredText $takistan) 'Takistan advanced-respawn mirror matches Chernarus'
Assert-EqualText $source (Read-RequiredText $zargabad) 'Zargabad advanced-respawn mirror matches Chernarus'
Assert-EqualText $squadSource (Read-RequiredText $squadTakistan) 'Takistan squad-respawn mirror matches Chernarus'
Assert-EqualText $squadSource (Read-RequiredText $squadZargabad) 'Zargabad squad-respawn mirror matches Chernarus'

Write-Host ''
if ($script:Failures -eq 0) {
    Write-Host 'Test-DeadspawnGuardRelease: PASS' -ForegroundColor Green
    exit 0
}

Write-Host ("Test-DeadspawnGuardRelease: {0} failure(s)" -f $script:Failures) -ForegroundColor Red
exit 1
