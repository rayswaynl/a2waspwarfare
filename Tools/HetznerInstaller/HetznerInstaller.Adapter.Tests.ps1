$ErrorActionPreference='Stop'
$script:fails=0
function Assert([bool]$Condition,[string]$Name){if($Condition){Write-Host "  PASS  $Name"}else{Write-Host "  FAIL  $Name" -ForegroundColor Red;$script:fails++}}

$path=Join-Path $PSScriptRoot 'Adapters\WindowsServiceAdapter.ps1'
$source=[System.IO.File]::ReadAllText($path)
$tokens=$null;$errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)|Out-Null

Write-Host 'TEST A1: concrete adapter process selection is exact and fail-closed'
Assert(@($errors).Count-eq 0) 'A1 adapter parses under the current PowerShell AST'
Assert($source-match'function Get-ConfiguredProcessMatches') 'A1 one canonical process matcher owns enumeration'
Assert($source-notmatch'catch\s*\{\s*\}') 'A1 no empty catch converts query or duplicate failures into absence'
$matcher=[regex]::Match($source,'(?ms)^function Get-ConfiguredProcessMatches.*?^\}').Value
Assert($matcher-match'Expected\.Name'-and$matcher-match'Expected\.ProfileRoot'-and$matcher-match'Expected\.SandboxRoot') 'A1 matcher binds name, profile, and sandbox identities'
$stop=[regex]::Match($source,'(?ms)^function Stop-ConfiguredHeadlessClients.*?^\}').Value
Assert($stop-match'Get-ConfiguredProcessMatches'-and$stop-notmatch'Get-CimInstance') 'A1 stop uses only the canonical exact matcher'

Write-Host 'TEST A2: fatal evidence is measured from configured RPT files'
Assert($source-match'function Get-AdapterFatalLineCount') 'A2 adapter has a concrete RPT fatal counter'
$observeIsolation=[regex]::Match($source,"(?ms)'ObserveIsolation'\s*\{.*?^\s*\}").Value
Assert($observeIsolation-match'Get-AdapterFatalLineCount') 'A2 isolation observation reports measured HC RPT fatal lines'
$serviceEvidence=[regex]::Match($source,'(?ms)^function Get-ServiceEvidence.*?^\}').Value
Assert($serviceEvidence-match'Get-AdapterFatalLineCount') 'A2 service observation includes measured server and HC RPT fatal lines'

if($script:fails-eq 0){Write-Host 'ADAPTER TESTS PASSED' -ForegroundColor Green;exit 0}
Write-Host "$($script:fails) ADAPTER TEST(S) FAILED" -ForegroundColor Red
exit 1
