#requires -Version 5.1
<#
.SYNOPSIS
    Dependency-free tests for Set-MissionTemplate.ps1 (no Pester required).
.EXAMPLE
    .\Set-MissionTemplate.Tests.ps1     # exits 0 if all pass, 1 otherwise
#>
$ErrorActionPreference = 'Stop'
$helper = Join-Path $PSScriptRoot 'Set-MissionTemplate.ps1'
$enc = [System.Text.Encoding]::GetEncoding(28591)   # Latin-1 (byte-preserving)
$script:fails = 0

function Assert($cond, $name) {
    if ($cond) { Write-Host "  PASS  $name" }
    else { Write-Host "  FAIL  $name" -ForegroundColor Red; $script:fails++ }
}

function New-Cfg([string]$templateLine) {
    $p = [System.IO.Path]::GetTempFileName()
    $content = @"
hostName = "Test Server";
class Missions
{
    class PR8_Chernarus
    {
        $templateLine
        difficulty = "Veteran";
    };
    class PR8_Takistan
    {
        template = "[61-2hc]warfarev2_073v48co.takistan";
        difficulty = "Veteran";
    };
};
"@
    [System.IO.File]::WriteAllText($p, $content)
    return $p
}

$target = '[55-2hc]warfarev2_073v48co_b742aicom.chernarus'

Write-Host "TEST 1: already-correct (same-build redeploy) -> success, no throw, cfg unchanged"
$c = New-Cfg 'template = "[55-2hc]warfarev2_073v48co_b742aicom.chernarus";'
$before = [System.IO.File]::ReadAllText($c)
$r = & $helper -CfgPath $c -MissionName $target -Apply
Assert ($r.AlreadyCorrect -eq $true)  "T1 AlreadyCorrect"
Assert ($r.Changed -eq $false)        "T1 not Changed"
Assert ([System.IO.File]::ReadAllText($c) -eq $before) "T1 cfg unchanged"
Remove-Item $c -Force

Write-Host "TEST 2: needs update (new build) -> rewrites only the chernarus line"
$c = New-Cfg 'template = "[55-2hc]warfarev2_073v48co_b741aicom.chernarus";'
$r = & $helper -CfgPath $c -MissionName $target -Apply
$after = [System.IO.File]::ReadAllText($c)
Assert ($r.Changed -eq $true)  "T2 Changed"
Assert ($r.Applied -eq $true)  "T2 Applied"
Assert ($after -match [regex]::Escape('template = "' + $target + '";')) "T2 new template present"
Assert ($after -notmatch 'b741aicom') "T2 old template gone"
Assert ($after -match '\[61-2hc\][^"]*takistan') "T2 takistan line untouched"
Remove-Item $c -Force

Write-Host "TEST 3: genuine no-match (no [55-2hc] chernarus template) -> throws"
$c = New-Cfg 'template = "SomeOther.chernarus";'   # present, but not [55-2hc]
$threw = $false
try { & $helper -CfgPath $c -MissionName $target -Apply } catch { $threw = $true }
Assert ($threw -eq $true) "T3 throws on genuine no-match"
Remove-Item $c -Force

Write-Host "TEST 4: dry-run safety -> reports change but writes nothing"
$c = New-Cfg 'template = "[55-2hc]warfarev2_073v48co_b741aicom.chernarus";'
$before = [System.IO.File]::ReadAllText($c)
$r = & $helper -CfgPath $c -MissionName $target        # no -Apply
Assert ($r.Changed -eq $true)   "T4 Changed reported"
Assert ($r.Applied -eq $false)  "T4 not Applied"
Assert ([System.IO.File]::ReadAllText($c) -eq $before) "T4 cfg NOT written in dry run"
Remove-Item $c -Force

Write-Host "TEST 5: idempotency -> second -Apply is a clean no-op"
$c = New-Cfg 'template = "[55-2hc]warfarev2_073v48co_b741aicom.chernarus";'
$null = & $helper -CfgPath $c -MissionName $target -Apply
$r2 = & $helper -CfgPath $c -MissionName $target -Apply
Assert ($r2.AlreadyCorrect -eq $true) "T5 second run already-correct"
Assert ($r2.Changed -eq $false)       "T5 second run no change"
Remove-Item $c -Force

Write-Host "TEST 6: mission name containing a literal '`$' is written verbatim (no backreference)"
$weird = '[55-2hc]warfarev2_x$1y.chernarus'
$c = New-Cfg 'template = "[55-2hc]warfarev2_073v48co_b741aicom.chernarus";'
$null = & $helper -CfgPath $c -MissionName $weird -Apply
$after = [System.IO.File]::ReadAllText($c)
Assert ($after -match [regex]::Escape('template = "' + $weird + '";')) "T6 literal dollar-sign preserved"
Remove-Item $c -Force

Write-Host "TEST 7: empty mission name is rejected"
$c = New-Cfg 'template = "[55-2hc]warfarev2_073v48co_b741aicom.chernarus";'
$threw = $false
try { & $helper -CfgPath $c -MissionName '' -Apply } catch { $threw = $true }
Assert ($threw -eq $true) "T7 throws on empty MissionName"
Remove-Item $c -Force

Write-Host "TEST 8: a commented-out template line is NOT matched (only the live, line-start line is repointed)"
$p = [System.IO.Path]::GetTempFileName()
$cfg8 = @"
class Missions
{
    // template = "[55-2hc]warfarev2_073v48co_b740aicom.chernarus";
    class PR8_Chernarus
    {
        template = "[55-2hc]warfarev2_073v48co_b741aicom.chernarus";
    };
};
"@
[System.IO.File]::WriteAllText($p, $cfg8, $enc)
$r = & $helper -CfgPath $p -MissionName $target -Apply
$after = [System.IO.File]::ReadAllText($p, $enc)
Assert ($r.Matches -eq 1) "T8 only the live (line-start) line matched"
Assert ($after -match [regex]::Escape('template = "' + $target + '";')) "T8 live line repointed"
Assert ($after -match 'b740aicom') "T8 commented line left untouched"
Assert ($after -notmatch 'b741aicom') "T8 old live value gone"
Remove-Item $p -Force

Write-Host "TEST 9: multiple live chernarus template lines -> all repointed, Matches=2"
$p = [System.IO.Path]::GetTempFileName()
$cfg9 = @"
class Missions
{
    class A
    {
        template = "[55-2hc]warfarev2_073v48co_b741aicom.chernarus";
    };
    class B
    {
        template = "[55-2hc]warfarev2_073v48co_b740aicom.chernarus";
    };
};
"@
[System.IO.File]::WriteAllText($p, $cfg9, $enc)
$r = & $helper -CfgPath $p -MissionName $target -Apply -WarningAction SilentlyContinue
$after = [System.IO.File]::ReadAllText($p, $enc)
Assert ($r.Matches -eq 2) "T9 two matches reported"
Assert ((([regex]::Matches($after, [regex]::Escape('template = "' + $target + '";'))).Count) -eq 2) "T9 both lines repointed"
Remove-Item $p -Force

Write-Host "TEST 10: extended (non-ASCII) bytes elsewhere survive (Latin-1 round-trip, no UTF-8 mangling)"
$p = [System.IO.Path]::GetTempFileName()
$cfg10 = @"
hostName = "Caf$([char]0xE9) Server";
class Missions
{
    class PR8_Chernarus
    {
        template = "[55-2hc]warfarev2_073v48co_b741aicom.chernarus";
    };
};
"@
[System.IO.File]::WriteAllText($p, $cfg10, $enc)   # 0xE9 ('e') as a single Latin-1 byte
$null = & $helper -CfgPath $p -MissionName $target -Apply
$bytes = [System.IO.File]::ReadAllBytes($p)
Assert ($bytes -contains 0xE9) "T10 0xE9 byte preserved (not UTF-8 replacement-charred)"
Assert (-not ($bytes -contains 0xEF)) "T10 no UTF-8 BOM/replacement bytes introduced"
$after = [System.IO.File]::ReadAllText($p, $enc)
Assert ($after -match [regex]::Escape('template = "' + $target + '";')) "T10 template still repointed"
Remove-Item $p -Force

Write-Host "TEST 11: empty pattern is rejected before regex replacement"
$c = New-Cfg 'template = "[55-2hc]warfarev2_073v48co_b741aicom.chernarus";'
$threw = $false
try { & $helper -CfgPath $c -MissionName $target -Pattern '' -Apply } catch { $threw = $true }
Assert ($threw -eq $true) "T11 throws on empty Pattern"
Remove-Item $c -Force

Write-Host ""
if ($script:fails -eq 0) { Write-Host "ALL TESTS PASSED" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:fails) TEST(S) FAILED" -ForegroundColor Red; exit 1 }
