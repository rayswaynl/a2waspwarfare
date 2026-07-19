#requires -Version 5.1
<#
.SYNOPSIS
    Guards paid camp-repair cancellation refunds across all mission variants.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$script:fails = 0

function Assert-Match {
	param([string]$Text, [string]$Pattern, [string]$Label)
	if ($Text -match $Pattern) { Write-Host ("  PASS  {0}" -f $Label) }
	else { Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red; $script:fails++ }
}

function Assert-Count {
	param([string]$Text, [string]$Pattern, [int]$Expected, [string]$Label)
	$actual = ([regex]::Matches($Text, $Pattern)).Count
	if ($actual -eq $Expected) { Write-Host ("  PASS  {0}" -f $Label) }
	else { Write-Host ("  FAIL  {0} (expected {1}, got {2})" -f $Label, $Expected, $actual) -ForegroundColor Red; $script:fails++ }
}

function Assert-EqualNormalized {
	param([string]$Left, [string]$Right, [string]$Label)
	$leftNormalized = $Left -replace "`r`n", "`n"
	$rightNormalized = $Right -replace "`r`n", "`n"
	if ($leftNormalized -ceq $rightNormalized) { Write-Host ("  PASS  {0}" -f $Label) }
	else { Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red; $script:fails++ }
}

function Read-Source {
	param([string]$RelativePath)
	$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
	$path = Join-Path $repoRoot $RelativePath
	if (!(Test-Path -LiteralPath $path)) { throw "Source not found: $path" }
	Get-Content -LiteralPath $path -Raw
}

$roots = @(
	"Missions\[55-2hc]warfarev2_073v48co.chernarus",
	"Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan",
	"Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad"
)

$sources = @()
foreach ($root in $roots) {
	$sources += [PSCustomObject]@{
		Root = $root
		Standard = Read-Source (Join-Path $root "Client\Action\Action_RepairCamp.sqf")
		Engineer = Read-Source (Join-Path $root "Client\Action\Action_RepairCampEngineer.sqf")
	}
}

foreach ($source in $sources) {
	$label = if ($source.Root -like '*takistan*') { 'Takistan' } elseif ($source.Root -like '*zargabad*') { 'Zargabad' } else { 'Chernarus' }
	foreach ($variant in @(
		[PSCustomObject]@{ Name = 'standard'; Text = $source.Standard },
		[PSCustomObject]@{ Name = 'engineer'; Text = $source.Engineer }
	)) {
		$prefix = "$label $($variant.Name) camp repair"
		Assert-Match $variant.Text 'Private \[.*"_price".*\];' "$prefix snapshots the charged price"
		Assert-Match $variant.Text '_price = missionNamespace getVariable "WFBE_C_CAMPS_REPAIR_PRICE";' "$prefix reads the price once"
		Assert-Match $variant.Text 'if \(\(_price > 0\) && \{\(Call WFBE_CL_FNC_GetClientFunds\) < _price\}\) exitWith' "$prefix uses the same snapshot for the funds gate"
		Assert-Match $variant.Text '\(-_price\) Call WFBE_CL_FNC_ChangeClientFunds;' "$prefix debits the snapshot"
		Assert-Match $variant.Text 'if \(!\(alive _vehicle\) \|\| \(_vehicle distance _camp > _range\)\) exitWith \{\s*hint \(localize "STR_WF_Repair_[^"]+"\);\s*if \(_price > 0\) then \{_price Call WFBE_CL_FNC_ChangeClientFunds;\};\s*\};' "$prefix refunds inside the cancellation exit"
		Assert-Match $variant.Text '(?s)if \(alive \(_camp getVariable ''wfbe_camp_bunker''\)\) exitWith \{\s*hint \(localize "STR_WF_Repair_Camp_IsAlive"\);.*?if \(_price > 0\) then \{_price Call WFBE_CL_FNC_ChangeClientFunds;\};\s*\};' "$prefix preserves the competing-repair refund"
		Assert-Count $variant.Text 'if \(_price > 0\) then \{_price Call WFBE_CL_FNC_ChangeClientFunds;\};' 2 "$prefix has exactly two terminal refund sites"
	}
}

$ch = $sources[0]
foreach ($source in $sources | Select-Object -Skip 1) {
	$label = if ($source.Root -like '*takistan*') { 'Takistan' } else { 'Zargabad' }
	Assert-EqualNormalized $ch.Standard $source.Standard "$label standard repair mirrors Chernarus"
	Assert-EqualNormalized $ch.Engineer $source.Engineer "$label engineer repair mirrors Chernarus"
}

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-CampRepairCancellationRefund: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-CampRepairCancellationRefund: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
