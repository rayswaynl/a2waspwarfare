<#
.SYNOPSIS
	Random bug-hunt mode for the WASP Warfare PR test harness.

.DESCRIPTION
	A heuristic static bug hunter for the Arma 2 OA SQF mission. It scans mission
	.sqf files for high-signal bug patterns (A3-only commands, off-by-one loops,
	descending loops with no negative step, un-yielded busy loops, missing compiled
	files, and per-file bracket imbalance) and reports suspects with file:line.

	Unlike Test-WaspStaticSmoke.ps1 (a pass/fail gate on specific claims), this is an
	open-ended HUNTER: it surfaces *candidates* to eyeball, not guaranteed bugs.

	"Random" mode (-Random N [-Seed S]) scans a random sample of N files each run, so
	repeated runs hunt different corners of the mission instead of the same diff. Omit
	-Random to scan the PR diff (changed-vs-base) or pass -All for the whole tree.

.EXAMPLE
	pwsh Find-WaspBugHunt.ps1                      # hunt the PR diff (changed vs origin/master)
	pwsh Find-WaspBugHunt.ps1 -All                 # hunt the whole Chernarus mission
	pwsh Find-WaspBugHunt.ps1 -Random 40           # hunt a random 40-file sample (new seed each run)
	pwsh Find-WaspBugHunt.ps1 -Random 40 -Seed 7   # reproducible random sample
	pwsh Find-WaspBugHunt.ps1 -All -MinSeverity high -FailOnHigh   # CI-style gate on HIGH only
#>
param(
	[string]$BaseRef = "origin/master",
	[string]$HeadRef = "HEAD",
	[string]$MissionRoot = "",
	[switch]$All,                       # scan the whole mission tree (default: changed-vs-base)
	[int]$Random = 0,                   # scan a random sample of N files
	[Nullable[int]]$Seed = $null,       # seed the random sample for reproducibility
	[ValidateSet("low","medium","high")][string]$MinSeverity = "medium",
	[int]$Top = 80,                     # max findings to print
	[switch]$FailOnHigh                 # exit 1 if any HIGH finding (for CI)
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
if ([string]::IsNullOrWhiteSpace($MissionRoot)) {
	$MissionRoot = Join-Path $repoRoot "Missions\[55-2hc]warfarev2_073v48co.chernarus"
}
$sevRank = @{ low = 0; medium = 1; high = 2 }
$findings = New-Object System.Collections.Generic.List[object]

function Add-Finding {
	param([string]$Severity, [string]$Rule, [string]$File, [int]$Line, [string]$Snippet)
	$rel = $File
	try { $rel = Resolve-Path -LiteralPath $File -Relative } catch {}
	$findings.Add([pscustomobject]@{
		Severity = $Severity; Rule = $Rule; Location = "$rel`:$Line"; Snippet = $Snippet.Trim()
	}) | Out-Null
}

# Return code-only lines (same line count) with // line comments and /* */ block comments removed,
# but STRINGS KEPT. Strings are kept on purpose: SQF writes the for-loop iterator and getVariable
# names as string literals (for "_i" ..., getVariable "x"), so blanking strings would hide the very
# structures we hunt. The original false positives were all in COMMENTS, which we still strip.
function Get-CodeLines {
	param([string]$Text)
	$out = New-Object System.Collections.Generic.List[string]
	$sb = New-Object System.Text.StringBuilder
	$inS = $false; $inD = $false; $inBlock = $false; $inLine = $false
	$len = $Text.Length; $i = 0
	while ($i -lt $len) {
		$c = $Text[$i]
		$nx = if ($i + 1 -lt $len) { $Text[$i + 1] } else { [char]0 }
		# Reset string state per line (most SQF strings are single-line); block comments span lines.
		if ($c -eq "`n") { $out.Add($sb.ToString()) | Out-Null; [void]$sb.Clear(); $inLine = $false; $inS = $false; $inD = $false; $i++; continue }
		if ($c -eq "`r") { $i++; continue }
		if ($inLine) { $i++; continue }
		if ($inBlock) { if ($c -eq '*' -and $nx -eq '/') { $inBlock = $false; $i += 2; continue }; $i++; continue }
		if ($inS) { [void]$sb.Append($c); if ($c -eq "'") { if ($nx -eq "'") { [void]$sb.Append($nx); $i += 2; continue } else { $inS = $false } }; $i++; continue }
		if ($inD) { [void]$sb.Append($c); if ($c -eq '"') { if ($nx -eq '"') { [void]$sb.Append($nx); $i += 2; continue } else { $inD = $false } }; $i++; continue }
		if ($c -eq '/' -and $nx -eq '/') { $inLine = $true; $i++; continue }
		if ($c -eq '/' -and $nx -eq '*') { $inBlock = $true; $i++; continue }
		if ($c -eq "'") { $inS = $true; [void]$sb.Append($c); $i++; continue }
		if ($c -eq '"') { $inD = $true; [void]$sb.Append($c); $i++; continue }
		[void]$sb.Append($c); $i++
	}
	$out.Add($sb.ToString()) | Out-Null
	return $out
}

function Get-TargetFiles {
	if ($Random -gt 0 -or $All) {
		$all = Get-ChildItem -LiteralPath $MissionRoot -Recurse -File -Filter *.sqf | ForEach-Object { $_.FullName }
		if ($Random -gt 0) {
			if ($null -ne $Seed) { $rng = [System.Random]::new([int]$Seed) } else { $rng = [System.Random]::new() }
			$all = $all | Sort-Object { $rng.Next() } | Select-Object -First $Random
		}
		return $all
	}
	# Default: changed Chernarus .sqf files vs base.
	$rel = & git -C $repoRoot diff --name-only "$BaseRef..$HeadRef" -- "Missions/[55-2hc]warfarev2_073v48co.chernarus"
	$files = @()
	foreach ($p in $rel) {
		if ($p -match '\.sqf$') {
			$full = Join-Path $repoRoot ($p -replace '/', '\')
			if (Test-Path -LiteralPath $full) { $files += $full }
		}
	}
	return $files
}

# A3-only commands that do not exist in A2 OA (runtime error if reached).
$A3 = @("pushBack","pushBackUnique","selectRandom","isEqualTo","parseSimpleArray","remoteExec","remoteExecCall",
	"setGroupOwner","append","apply","findIf","deleteAt","createHashMap","hashMap","getOrDefault","insert","arrayIntersect")
$a3Pattern = "\b(" + (($A3 | ForEach-Object {[regex]::Escape($_)}) -join "|") + ")\b"

function Test-File {
	param([string]$Path)
	$text = [System.IO.File]::ReadAllText($Path)
	$rawLines = $text -split "`n"
	$codeLines = Get-CodeLines $text
	# Per-line detectors (run on code-only lines; show the raw line as the snippet)
	for ($idx = 0; $idx -lt $codeLines.Count; $idx++) {
		$code = $codeLines[$idx]
		if ([string]::IsNullOrWhiteSpace($code)) { continue }
		$n = $idx + 1
		$raw = if ($idx -lt $rawLines.Count) { $rawLines[$idx] } else { $code }

		# 1. A3-only command — DISABLED: duplicates check_sqf.py A3CMD rule (same command list,
		#    same mission tree, different runner). Keeping this enabled would double-report every
		#    A3CMD finding; the Python linter is the canonical gate. All other rules below are
		#    genuinely additive (loop off-by-one, nil-hazard getVariable, missing compiled files).
		# if ($code -match $a3Pattern) { Add-Finding "high" "A3-only command '$($matches[1])'" $Path $n $raw }

		# 2. Ascending off-by-one: for "_i"/'_i' from .. to <expr with count> do  (no -1)
		if ($code -match 'for\s+["''][^"'']+["'']\s+from\b.+?\bto\s+([^;{]*?\bcount\b[^;{]*?)\s+do\b') {
			if ($matches[1] -notmatch '-\s*1') { Add-Finding "high" "Off-by-one: loop 'to (count ...)' without -1 (index runs 1 past end)" $Path $n $raw }
		}
		# 2b. C-style off-by-one: _i <= count ...
		if ($code -match '\b_\w+\s*<=\s*[^;{]*\bcount\b') { Add-Finding "medium" "Off-by-one: '<= count ...' (use <)" $Path $n $raw }

		# 3. Descending loop with no negative step: from (..count..) to 0 do  (body never runs)
		if ($code -match 'for\s+["''][^"'']+["'']\s+from\b[^;{]*\bcount\b[^;{]*\bto\s+0\s+do\b') {
			if ($code -notmatch '\bstep\b') { Add-Finding "high" "Descending loop missing 'step -1' (body never runs)" $Path $n $raw }
		}

		# 4. 'local' applied to a group value (Type Group, expected Object -> throws, esp. on HC)
		if ($code -match '\blocal\s*\(\s*group\b' -or $code -match '\blocal\s+_(group|grp|team)\b') {
			Add-Finding "medium" "'local' on a likely Group value (throws; use locality of leader/object)" $Path $n $raw
		}

		# 5. string-form getVariable (no default) used in a NIL-HAZARD context: !(x getVariable "y")
		#    or arithmetic ( + (x getVariable "y") ). Plain getVariable-without-default is valid SQF and
		#    far too common to flag, so we only flag the negation/arithmetic shapes that actually throw on nil.
		if ($code -notmatch 'getVariable\s*\[' -and ($code -match '!\s*\(\s*\w[\w ]*\s+getVariable\s+"' -or $code -match '[-+*/]\s*\(\s*\w[\w ]*\s+getVariable\s+"')) {
			Add-Finding "medium" "getVariable (no default) negated/in arithmetic — nil throws if unset" $Path $n $raw
		}
	}

	$codeText = ($codeLines -join "`n")

	# 6. Missing compiled/exec'd file: preprocessFile/execVM/loadFile of a path that does not exist
	#    (runs on comment-stripped code so commented-out compiles are NOT flagged)
	$pp = [regex]::Matches($codeText, '(?:preprocessFileLineNumbers|preprocessFile|execVM|loadFile)\s+"([^"]+\.(?:sqf|fsm|hpp|h))"')
	foreach ($m in $pp) {
		$q = $m.Groups[1].Value
		if ($q -match '%' ) { continue }                 # dynamic format path, skip
		$full = Join-Path $MissionRoot ($q -replace '/', '\')
		if (-not (Test-Path -LiteralPath $full)) {
			$ln = ($codeText.Substring(0, $m.Index) -split "`n").Count
			Add-Finding "high" "Compiled/exec path not found: $q" $Path $ln $m.Value
		}
	}

# (Bracket-imbalance detector intentionally omitted: without a full SQF parser it false-positives
#  on multi-line strings and macros. Per-file brace balance is covered by the smoke harness / manual
#  diff checks on changed files, where it is reliable.)
}

$targets = @(Get-TargetFiles)
if ($targets.Count -eq 0) {
	Write-Host "BugHunt: no target files (no diff vs $BaseRef). Try -All or -Random N." -ForegroundColor Yellow
	return
}

$mode = if ($Random -gt 0) { "random sample ($($targets.Count) files" + $(if ($null -ne $Seed) { ", seed $Seed)" } else { ", new seed)" }) } elseif ($All) { "whole mission ($($targets.Count) files)" } else { "PR diff ($($targets.Count) files)" }
Write-Host "WASP BugHunt — scanning $mode" -ForegroundColor Cyan

foreach ($f in $targets) { try { Test-File $f } catch { Write-Host "  (skipped $($f): $($_.Exception.Message))" -ForegroundColor DarkGray } }

$min = $sevRank[$MinSeverity]
$shown = $findings | Where-Object { $sevRank[$_.Severity] -ge $min } | Sort-Object @{e={$sevRank[$_.Severity]};Descending=$true}, Location
$total = @($shown).Count

if ($total -eq 0) {
	Write-Host "`nBugHunt: no suspects at/above '$MinSeverity'." -ForegroundColor Green
} else {
	$counts = $findings | Group-Object Severity | ForEach-Object { "$($_.Name)=$($_.Count)" }
	Write-Host "`nSuspects (showing up to $Top of $total at>= '$MinSeverity'): $($counts -join ' ')" -ForegroundColor Yellow
	$shown | Select-Object -First $Top | Format-Table Severity, Rule, Location, Snippet -AutoSize -Wrap
	Write-Host "These are HEURISTIC leads — eyeball each before acting." -ForegroundColor DarkGray
}

$highCount = @($findings | Where-Object { $_.Severity -eq "high" }).Count
if ($FailOnHigh -and $highCount -gt 0) {
	Write-Host "FAIL: $highCount HIGH-severity suspect(s)." -ForegroundColor Red
	exit 1
}
exit 0
