$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot 'Update-PublicStats.ps1'
$source = Get-Content -LiteralPath $sourcePath -Raw
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw "Update-PublicStats.ps1 has parse errors: $($parseErrors | Out-String)" }

$functionAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-PlayerRosterCounts'
}, $true)
if ($null -eq $functionAst) { throw 'Get-PlayerRosterCounts was not found in Update-PublicStats.ps1' }
. ([scriptblock]::Create($functionAst.Extent.Text))

function Assert-Equal([object]$expected, [object]$actual, [string]$label) {
    if ($expected -ne $actual) { throw "$label`: expected [$expected], got [$actual]" }
}

$rows = @(
    'diag WASPSTAT|v1|10|alpha:1,2,3,4,5,6,7,0,0,0,0,0,0,0,0,1~|bravo:0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2~',
    'diag WASPSTAT|v1|11|alpha:1,1,1,1,1,1,2,0,0,0,0,0,0,0,0,1~',
    'diag WASPSTAT|v1|12|KILL|alpha|bravo|WEST|EAST|rifle|10|INF',
    'diag WASPSTAT|v1|13|malformed:not,enough,fields~'
)

$counts = Get-PlayerRosterCounts $rows
if (-not $counts.ContainsKey('alpha')) { throw 'alpha roster row was dropped' }
if (-not $counts.ContainsKey('bravo')) { throw 'bravo roster row was dropped' }
Assert-Equal 27 $counts['alpha'].kills 'alpha kills summed across flush deltas'
Assert-Equal 9  $counts['alpha'].deaths 'alpha deaths summed across flush deltas'
Assert-Equal 0  $counts['bravo'].kills 'bravo zero-kill row preserved'
Assert-Equal 0  $counts['bravo'].deaths 'bravo zero-death row preserved'

Write-Output 'PASS: roster rows are parsed, KILL rows are ignored, and successive delta flushes are summed.'
