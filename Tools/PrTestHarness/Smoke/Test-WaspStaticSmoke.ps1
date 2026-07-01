param(
	[string]$BaseRef = "origin/master",
	[string]$HeadRef = "HEAD",
	[string]$SourceMissionRoot = "",
	[string]$ActiveMissionRoot = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$harnessRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$sourceRepoRoot = $repoRoot
$missionRoot = Join-Path $repoRoot "Missions\[55-2hc]warfarev2_073v48co.chernarus"
if (![string]::IsNullOrWhiteSpace($SourceMissionRoot)) {
	$missionRoot = (Resolve-Path -LiteralPath $SourceMissionRoot).Path
	$sourceRepoRoot = Split-Path -Parent (Split-Path -Parent $missionRoot)
}
if ([string]::IsNullOrWhiteSpace($ActiveMissionRoot)) {
	$ActiveMissionRoot = Join-Path $env:USERPROFILE "Documents\ArmA 2 Other Profiles\Zwanon\MPMissions\WASP_PR8_StressTest.Chernarus"
}
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
	param([string]$Name, [bool]$Passed, [string]$Detail)
	$results.Add([pscustomobject]@{ Name = $Name; Passed = $Passed; Detail = $Detail }) | Out-Null
}

function Get-Text {
	param([string]$Path)
	return [System.IO.File]::ReadAllText($Path)
}

function Get-ChangedMissionFiles {
	$sourceRepoRootPath = if ($sourceRepoRoot -is [System.Management.Automation.PathInfo]) { $sourceRepoRoot.Path } else { [string]$sourceRepoRoot }
	$files = @()
	$roots = @($missionRoot)
	if ([string]::IsNullOrWhiteSpace($SourceMissionRoot)) {
		$takistanRoot = Join-Path $sourceRepoRootPath "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
		if (Test-Path -LiteralPath $takistanRoot) { $roots += (Resolve-Path -LiteralPath $takistanRoot).Path }
	}
	foreach ($root in $roots) {
		$missionPath = $root.Substring($sourceRepoRootPath.Length).TrimStart('\') -replace '\\','/'
		$relative = & git -C $sourceRepoRootPath diff --name-only "$BaseRef..$HeadRef" -- $missionPath
		foreach ($path in $relative) {
			if ($path -match '\.(sqf|fsm)$') {
				$full = Join-Path $sourceRepoRootPath ($path -replace '/', '\')
				if (Test-Path -LiteralPath $full) { $files += $full }
			}
		}
	}
	return @($files | Select-Object -Unique)
}

function Remove-LineComment {
	param([string]$Line)
	$idx = $Line.IndexOf("//")
	if ($idx -ge 0) { return $Line.Substring(0, $idx) }
	return $Line
}

function Remove-CodeComments {
	param(
		[string]$Line,
		[ref]$InBlockComment
	)
	$remaining = $Line
	$out = ""
	while ($remaining.Length -gt 0) {
		if ($InBlockComment.Value) {
			$end = $remaining.IndexOf("*/")
			if ($end -lt 0) { return $out }
			$remaining = $remaining.Substring($end + 2)
			$InBlockComment.Value = $false
			continue
		}
		$lineComment = $remaining.IndexOf("//")
		$blockComment = $remaining.IndexOf("/*")
		if ($lineComment -ge 0 -and ($blockComment -lt 0 -or $lineComment -lt $blockComment)) {
			$out += $remaining.Substring(0, $lineComment)
			return $out
		}
		if ($blockComment -ge 0) {
			$out += $remaining.Substring(0, $blockComment)
			$remaining = $remaining.Substring($blockComment + 2)
			$InBlockComment.Value = $true
			continue
		}
		$out += $remaining
		return $out
	}
	return $out
}

function Remove-StringLiterals {
	param([string]$Line)
	$withoutDouble = [regex]::Replace($Line, '"[^"]*"', '""')
	return [regex]::Replace($withoutDouble, "'[^']*'", "''")
}

function Test-ForbiddenReleaseCommands {
	$forbidden = @(
		"allMapMarkers","allMissionObjects","pushBack","pushBackUnique","selectRandom","isEqualTo","params",
		"parseSimpleArray","remoteExec","setGroupOwner","append","apply",
		"findIf","deleteAt","createHashMap","hashMap"
	)
	$pattern = "\b(" + (($forbidden | ForEach-Object {[regex]::Escape($_)}) -join "|") + ")\b"
	$hits = @()
	foreach ($file in Get-ChangedMissionFiles) {
		$lineNumber = 0
		$inBlockComment = $false
		foreach ($line in [System.IO.File]::ReadLines($file)) {
			$lineNumber++
			$code = Remove-StringLiterals (Remove-CodeComments $line ([ref]$inBlockComment))
			if ($code -match $pattern) {
				$rel = Resolve-Path -LiteralPath $file -Relative
				$hits += "$rel`:$lineNumber $($matches[1])"
			}
		}
	}
	Add-Result "A2 OA command dialect" ($hits.Count -eq 0) ($(if ($hits.Count) { $hits -join "; " } else { "No forbidden/project-blocked commands in changed maintained mission files." }))
}

function Test-HarnessOverlayA3Dialect {
	# Dialect-scan the harness overlay's OWN sqf (init.sqf + test/*.sqf). The main
	# dialect check only covers changed mission files, so harness forbidden/project-blocked
	# command regressions previously slipped to runtime.
	$forbidden = @(
		"allMapMarkers","allMissionObjects","pushBack","pushBackUnique","selectRandom","isEqualTo","params",
		"parseSimpleArray","remoteExec","setGroupOwner","append","apply",
		"findIf","deleteAt","createHashMap","hashMap"
	)
	$pattern = "\b(" + (($forbidden | ForEach-Object {[regex]::Escape($_)}) -join "|") + ")\b"
	$overlayRoot = Join-Path $harnessRoot "Overlays\pr8-stress"
	$files = @()
	$initFile = Join-Path $overlayRoot "init.sqf"
	if (Test-Path -LiteralPath $initFile) { $files += $initFile }
	$testDir = Join-Path $overlayRoot "test"
	if (Test-Path -LiteralPath $testDir) { $files += (Get-ChildItem -LiteralPath $testDir -Filter "*.sqf" -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
	$hits = @()
	foreach ($file in $files) {
		$lineNumber = 0
		$inBlockComment = $false
		foreach ($line in [System.IO.File]::ReadLines($file)) {
			$lineNumber++
			$code = Remove-StringLiterals (Remove-CodeComments $line ([ref]$inBlockComment))
			if ($code -match $pattern) {
				$hits += "$(Split-Path -Leaf $file):$lineNumber $($matches[1])"
			}
		}
	}
	Add-Result "Harness overlay A2 dialect" ($hits.Count -eq 0) ($(if ($hits.Count) { $hits -join "; " } else { "No forbidden/project-blocked commands in the pr8-stress harness overlay scripts." }))
}

function Test-HqShield {
	$defenses = Join-Path $missionRoot "Server\Init\Init_Defenses.sqf"
	$hqSite = Join-Path $missionRoot "Server\Construction\Construction_HQSite.sqf"
	$defText = Get-Text $defenses
	$hqText = Get-Text $hqSite

	$templateMatch = [regex]::Match($defText, "WFBE_NEURODEF_HEADQUARTERS_WALLS'\s*,\s*\[(?<body>[\s\S]*?)\]\s*\];")
	$body = if ($templateMatch.Success) { $templateMatch.Groups["body"].Value } else { "" }
	$objectCount = ([regex]::Matches($body, "\['[^']+'\s*,\s*\[[^\]]+\]\s*,\s*-?[0-9.]+\]")).Count
	$hasConcrete = $body.Contains("Concrete_Wall_EP1")
	$hasBlocks = $body.Contains("Land_CncBlock")
	$hasFunnel = $body.Contains("335") -and $body.Contains("325") -and $body.Contains("25") -and $body.Contains("35")
	$tightTemplate = $body.Contains("6.1") -and (-not $body.Contains("10.5")) -and (-not $body.Contains("13,0")) -and (-not $body.Contains("10.8"))   # recalibrated: shipped HQ shield uses 6.1/4.4 concrete spacing (was 7.2)
	$spawns = $hqText.Contains('missionNamespace getVariable "WFBE_NEURODEF_HEADQUARTERS_WALLS"') -and $hqText.Contains("call CreateDefenseTemplate")
	$stores = $hqText.Contains('setVariable ["wfbe_hq_walls"') -and $hqText.Contains('setVariable ["WFBE_Walls"')
	$cleans = $hqText.Contains('getVariable ["wfbe_hq_walls", _HQ getVariable ["WFBE_Walls", []]]') -and $hqText.Contains("deleteVehicle _x")

	$ok = $templateMatch.Success -and ($objectCount -gt 0) -and $hasConcrete -and $hasBlocks -and $hasFunnel -and $tightTemplate -and $spawns -and $stores -and $cleans
	Add-Result "HQ shield deploy/cleanup" $ok "templateObjects=$objectCount concrete=$hasConcrete blocks=$hasBlocks funnel=$hasFunnel tight=$tightTemplate spawns=$spawns stores=$stores cleans=$cleans"
}

function Test-AARadarHasNoWalls {
	$defText = Get-Text (Join-Path $missionRoot "Server\Init\Init_Defenses.sqf")
	$smallText = Get-Text (Join-Path $missionRoot "Server\Construction\Construction_SmallSite.sqf")
	$mediumText = Get-Text (Join-Path $missionRoot "Server\Construction\Construction_MediumSite.sqf")
	$templateMatch = [regex]::Match($defText, "WFBE_NEURODEF_AARADAR_WALLS'\s*,\s*\[(?<body>[\s\S]*?)\]\s*\];")
	$body = if ($templateMatch.Success) { $templateMatch.Groups["body"].Value } else { "" }
	$objectCount = ([regex]::Matches($body, "\['[^']+'\s*,\s*\[[^\]]+\]\s*,\s*-?[0-9.]+\]")).Count
	$smallGuard = $smallText.Contains('!(_rlType in ["AARadar","CBRadar"])') -and $smallText.Contains("%2 auto walls skipped")
	$mediumGuard = $mediumText.Contains('!(_rlType in ["AARadar","Bank","Reserve","ArtilleryRadar"])') -and $mediumText.Contains("%2 auto walls skipped")
	Add-Result "AARadar wall template removed" ($templateMatch.Success -and $objectCount -eq 0 -and $smallGuard -and $mediumGuard) "templateFound=$($templateMatch.Success) wallObjects=$objectCount smallGuard=$smallGuard mediumGuard=$mediumGuard"
}

function Test-WddmInstantStaticCrew {
	$handle = Get-Text (Join-Path $missionRoot "Server\Functions\Server_HandleDefense.sqf")
	$create = Get-Text (Join-Path $missionRoot "Common\Functions\Common_CreateUnitForStaticDefence.sqf")
	$construct = Get-Text (Join-Path $missionRoot "Server\Functions\Server_ConstructPosition.sqf")
	$spawnAtGun = $handle.Contains('_moveInGunner = true') -and $handle.Contains('_position = getPosATL _defense')
	$logsStaticType = $handle.Contains('typeOf _defense') -and $handle.Contains('instant=%3')
	$passesWddmFlag = $construct.Contains('false, true] Call ConstructDefense')
	$retry = $create.Contains('retried instant static manning') -and $create.Contains('setPosATL (getPosATL _defence)') -and $create.Contains('_unit moveInGunner _defence')
	$settles = $create.Contains('disableAI "MOVE"') -and $create.Contains('WFBE_StaticDefenseSettled')
	Add-Result "WDDM instant static crew settling" ($spawnAtGun -and $logsStaticType -and $passesWddmFlag -and $retry -and $settles) "spawnAtGun=$spawnAtGun logsStaticType=$logsStaticType wddmFlag=$passesWddmFlag retry=$retry settles=$settles"
}

function Test-WddmAnchorClassValidity {
	# Guards the exact regression behind the "WDDM build preview missing" live finding:
	# an invalid CfgVehicles anchor class (RoadBarrier / RoadBarrier_light / RoadBarrier_long)
	# made Core_CIV log "Element '...' is not a valid class.", skip registration, and feed CoIn
	# a malformed [cash,<null>] cost -> _canAffordCount undefined cascade -> no placement ghost.
	#
	# isClass cannot run outside the engine, so validity is enforced two ways:
	#   1. denylist  - no known-invalid (Arma-3-only) anchor class may appear in any WDDM file, on any map.
	#   2. allowlist - every WFBE_POSITION_ANCHOR_NAMES entry must be a class already CONFIRMED valid
	#                  in Arma 2 OA. Adding a new anchor forces an in-engine isClass check + this list.

	# Curated set confirmed to resolve in Arma 2 OA CfgVehicles (the commander build anchors).
	$validAnchors = @(
		"Land_Ind_BoardsPack1","Land_CncBlock_Stripes","Land_Barrel_sand",
		"Land_Ind_BoardsPack2","Land_WoodenRamp","RoadCone",
		"Paleta1","Paleta2","Land_Ind_Timbers"
	)
	# Classes that previously broke the commander build menu (Arma-3-only / invalid in A2 OA).
	$invalidAnchors = @("RoadBarrier","RoadBarrier_light","RoadBarrier_long")

	$wddmFiles = @(
		"Common\Config\Core\Core_CIV.sqf",
		"Common\Config\Core_Structures\Structures_CO_RU.sqf",
		"Common\Config\Core_Structures\Structures_CO_US.sqf",
		"Server\Construction\Construction_MediumSite.sqf",
		"Server\Construction\Construction_SmallSite.sqf",
		"Server\Init\Init_Defenses.sqf"
	)

	# 1. Denylist scan across EVERY maintained mission (Chernarus/Takistan/Napf/eden/lingor/...).
	$invalidHits = @()
	foreach ($root in @("Missions", "Missions_Vanilla", "Modded_Missions")) {
		$fullRoot = Join-Path $sourceRepoRoot $root
		if (!(Test-Path -LiteralPath $fullRoot)) { continue }
		foreach ($missionDir in Get-ChildItem -LiteralPath $fullRoot -Directory) {
			foreach ($rel in $wddmFiles) {
				$f = Join-Path $missionDir.FullName $rel
				if (!(Test-Path -LiteralPath $f)) { continue }
				$t = Get-Text $f
				foreach ($bad in $invalidAnchors) {
					if ([regex]::IsMatch($t, "'$([regex]::Escape($bad))'")) {
						$invalidHits += "$($missionDir.Name)\$rel : $bad"
					}
				}
			}
		}
	}

	# 2/3. Parse the Chernarus source of truth for the anchor list + template-map keys.
	$defText = Get-Text (Join-Path $missionRoot "Server\Init\Init_Defenses.sqf")
	$anchorMatch = [regex]::Match($defText, "WFBE_POSITION_ANCHOR_NAMES\s*=\s*\[(?<body>[^\]]*)\]")
	$anchorBody = if ($anchorMatch.Success) { $anchorMatch.Groups["body"].Value } else { "" }
	$anchorNames = @([regex]::Matches($anchorBody, "'(?<c>[^']+)'") | ForEach-Object { $_.Groups["c"].Value })

	$mapMatch = [regex]::Match($defText, "WFBE_POSITION_TEMPLATE_MAP\s*=\s*\[(?<body>[\s\S]*?)\];")
	$mapBody = if ($mapMatch.Success) { $mapMatch.Groups["body"].Value } else { "" }
	$mapKeys = @([regex]::Matches($mapBody, "\[\s*'(?<c>[^']+)'") | ForEach-Object { $_.Groups["c"].Value })

	# 4. Every shipped anchor must be on the confirmed-valid allowlist.
	$unknown = @($anchorNames | Where-Object { $validAnchors -notcontains $_ })

	# 5. Anchor names and template-map keys must be the SAME set (no orphan anchor / template).
	$anchorsSorted = (($anchorNames | Sort-Object) -join ",")
	$keysSorted = (($mapKeys | Sort-Object) -join ",")
	$consistent = ($anchorMatch.Success -and $mapMatch.Success -and $anchorNames.Count -gt 0 -and $anchorsSorted -eq $keysSorted)

	# 6. Each anchor must be wired into the CoIn commander build menu (Core_CIV) so it can be placed.
	$coiv = Get-Text (Join-Path $missionRoot "Common\Config\Core\Core_CIV.sqf")
	$unwired = @($anchorNames | Where-Object { -not $coiv.Contains("'$_'") })

	$ok = ($invalidHits.Count -eq 0) -and ($unknown.Count -eq 0) -and $consistent -and ($unwired.Count -eq 0)
	Add-Result "WDDM anchor-class validity" $ok "anchors=$($anchorNames.Count) consistentMap=$consistent invalidHits=[$($invalidHits -join '; ')] unknown=[$($unknown -join ',')] unwired=[$($unwired -join ',')]"
}

function Test-PvfIntegrity {
	$initPv = Get-Text (Join-Path $missionRoot "Common\Init\Init_PublicVariables.sqf")
	$initCommon = Get-Text (Join-Path $missionRoot "Common\Init\Init_Common.sqf")
	$clientHandle = Get-Text (Join-Path $missionRoot "Client\Functions\Client_HandlePVF.sqf")
	$serverHandle = Get-Text (Join-Path $missionRoot "Server\Functions\Server_HandlePVF.sqf")
	$serverPvDir = Join-Path $missionRoot "Server\PVFunctions"
	$required = @("RequestEnqueue","RequestDequeue","RequestDefense","RequestSpecial","RequestUpgrade","RequestOnUnitKilled","RequestSiteClearance","CounterBatteryFired")
	$missing = @()
	foreach ($name in $required) {
		$registered = $initPv.Contains($name)
		$handler = Test-Path -LiteralPath (Join-Path $serverPvDir "$name.sqf")
		if (-not ($registered -and $handler)) { $missing += "$name registered=$registered handler=$handler" }
	}
	$allowlists = $initPv.Contains("WFBE_CL_PVF_ALLOWED") -and $initPv.Contains("WFBE_SE_PVF_ALLOWED") -and $initPv.Contains('Format["CLTFNC%1", _x]') -and $initPv.Contains('Format["SRVFNC%1", _x]')
	$dispatchChecks = $clientHandle.Contains("WFBE_CL_PVF_ALLOWED") -and $serverHandle.Contains("WFBE_SE_PVF_ALLOWED") -and $clientHandle.Contains("rejected unregistered PVF handler") -and $serverHandle.Contains("rejected unregistered PVF handler")
	$shapeChecks = $clientHandle.Contains('typeName _publicVar != "ARRAY"') -and $clientHandle.Contains("count _publicVar < 2") -and $clientHandle.Contains('typeName _script != "STRING"') -and $serverHandle.Contains('typeName _publicVar != "ARRAY"') -and $serverHandle.Contains("count _publicVar < 1") -and $serverHandle.Contains('typeName _script != "STRING"')
	$directClientAllowed = $initCommon.Contains('WFBE_CL_PVF_ALLOWED = WFBE_CL_PVF_ALLOWED + ["CLTFNCGuerVbiedBounty"]')
	Add-Result "PVF registration/handlers" ($missing.Count -eq 0 -and $allowlists -and $dispatchChecks -and $shapeChecks -and $directClientAllowed) ($(if ($missing.Count) { $missing -join "; " } else { "Core PR8 server PVF channels are registered and have handlers. allowlists=$allowlists dispatchChecks=$dispatchChecks shapeChecks=$shapeChecks directClientAllowed=$directClientAllowed" }))
}

function Test-SideSupplyAuthorityGuard {
	$takistanRoot = Join-Path $sourceRepoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$roots = @(
		[pscustomobject]@{ Terrain = "chernarus"; Root = $missionRoot },
		[pscustomobject]@{ Terrain = "takistan"; Root = $takistanRoot }
	)
	$missing = @()
	foreach ($entry in $roots) {
		$serverPath = Join-Path $entry.Root "Server\Functions\Server_ChangeSideSupply.sqf"
		$commonPath = Join-Path $entry.Root "Common\Functions\Common_ChangeSideSupply.sqf"
		$server = Get-Text $serverPath
		$common = Get-Text $commonPath
		$serverCode = [regex]::Replace($server, "//.*", "")
		$commonCode = [regex]::Replace($common, "//.*", "")
		if (-not $server.Contains("WFBE_SE_FNC_HandleSideSupplyChange")) { $missing += "$($entry.Terrain):helper" }
		if (-not ($server.Contains('typeName _payload != "ARRAY"') -and $server.Contains("count _payload < 3"))) { $missing += "$($entry.Terrain):payload-shape" }
		if (-not ($server.Contains('typeName _side != "SIDE"') -and $server.Contains("_side != _expectedSide"))) { $missing += "$($entry.Terrain):side-channel" }
		if (-not $server.Contains('typeName _amount != "SCALAR"')) { $missing += "$($entry.Terrain):amount-type" }
		if (-not ($server.Contains('[_this, west] Call WFBE_SE_FNC_HandleSideSupplyChange') -and $server.Contains('[_this, resistance] Call WFBE_SE_FNC_HandleSideSupplyChange') -and $server.Contains('[_this, east] Call WFBE_SE_FNC_HandleSideSupplyChange'))) { $missing += "$($entry.Terrain):handler-wiring" }
		if ($serverCode.Contains("_currentSupply - _amount") -or $commonCode.Contains("_currentSupply - _amount")) { $missing += "$($entry.Terrain):old-negative-floor" }
	}
	Add-Result "Side-supply channel authority guard" ($missing.Count -eq 0) "missing=$($missing -join ',')"
}

function Test-UpgradeRequestAuthorityGuard {
	$takistanRoot = Join-Path $sourceRepoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$roots = @(
		[pscustomobject]@{ Terrain = "chernarus"; Root = $missionRoot },
		[pscustomobject]@{ Terrain = "takistan"; Root = $takistanRoot }
	)
	$missing = @()
	foreach ($entry in $roots) {
		$requestPath = Join-Path $entry.Root "Server\PVFunctions\RequestUpgrade.sqf"
		$clientPath = Join-Path $entry.Root "Client\GUI\GUI_UpgradeMenu.sqf"
		$clientSpecialPath = Join-Path $entry.Root "Client\Functions\Client_FNC_Special.sqf"
		$request = Get-Text $requestPath
		$requestCode = [regex]::Replace($request, "//.*", "")
		$client = Get-Text $clientPath
		$clientCode = [regex]::Replace($client, "//.*", "")
		$clientSpecial = Get-Text $clientSpecialPath
		if (-not ($request.Contains('typeName _this != "ARRAY"') -and $request.Contains("count _args < 6"))) { $missing += "$($entry.Terrain):payload-shape" }
		if (-not ($request.Contains('typeName _side != "SIDE"') -and $request.Contains('typeName _upgrade_id != "SCALAR"') -and $request.Contains('typeName _upgrade_level != "SCALAR"') -and $request.Contains('typeName _upgrade_isplayer != "BOOL"') -and $request.Contains('typeName _requester != "OBJECT"') -and $request.Contains('typeName _requestTeam != "GROUP"'))) { $missing += "$($entry.Terrain):payload-types" }
		if (-not ($request.Contains('!_upgrade_isplayer') -and $request.Contains('RequestUpgrade is the player-commander path'))) { $missing += "$($entry.Terrain):player-request-only" }
		if (-not ($request.Contains('group _requester != _requestTeam') -and $request.Contains('side _requestTeam != _side') -and $request.Contains('_requestTeam != _cmdTeam') -and $request.Contains('leader _cmdTeam != _requester') -and $request.Contains('!isPlayer _requester') -and $request.Contains('!isPlayer (leader _cmdTeam)') -and $request.Contains('side (leader _cmdTeam) != _side'))) { $missing += "$($entry.Terrain):commander-team-hardening" }
		if (-not $request.Contains('_logic getVariable ["wfbe_upgrading", false]')) { $missing += "$($entry.Terrain):running-gate" }
		if (-not ($request.Contains('WFBE_C_UPGRADES_%1_ENABLED') -and $request.Contains('WFBE_C_UPGRADES_%1_LEVELS') -and $request.Contains('WFBE_C_UPGRADES_%1_TIMES') -and $request.Contains('WFBE_C_UPGRADES_%1_LINKS') -and $request.Contains('WFBE_C_UPGRADES_%1_COSTS'))) { $missing += "$($entry.Terrain):config-gates" }
		if (-not ($request.Contains('_upgrade_level != _current') -and $request.Contains('stale/skipped upgrade level'))) { $missing += "$($entry.Terrain):server-current-level" }
		if (-not $request.Contains('_linkNeeded')) { $missing += "$($entry.Terrain):dependency-gate" }
		if (-not ($request.Contains('WFBE_CO_FNC_GetTeamFunds') -and $request.Contains('WFBE_CO_FNC_GetSideSupply') -and $request.Contains('WFBE_CO_FNC_ChangeTeamFunds') -and $request.Contains('Player commander tech upgrade'))) { $missing += "$($entry.Terrain):server-payment" }
		if (-not ($request.Contains('setVariable ["wfbe_upgrading", true, true]') -and $request.Contains('accepted player commander upgrade'))) { $missing += "$($entry.Terrain):server-accept-state" }
		if (-not ($client.Contains('player, clientTeam') -and $client.Contains('Final acceptance and payment are server-owned'))) { $missing += "$($entry.Terrain):client-request-context" }
		if ($clientCode.Contains('WFBE_CL_FNC_ChangeClientFunds') -or $clientCode.Contains('Tech upgrade started.') -or $clientCode.Contains('WFBE_Client_Logic setVariable ["wfbe_upgrading", true, true]')) { $missing += "$($entry.Terrain):client-local-spend" }
		if (-not ($clientSpecial.Contains('upgrade-sync') -and $clientSpecial.Contains('commanderTeam == group player'))) { $missing += "$($entry.Terrain):accepted-start-sync" }
		if ($requestCode.Contains("_this Spawn WFBE_SE_FNC_ProcessUpgrade")) { $missing += "$($entry.Terrain):raw-spawn" }
		if (-not $requestCode.Contains("_args Spawn WFBE_SE_FNC_ProcessUpgrade")) { $missing += "$($entry.Terrain):validated-spawn" }
	}
	Add-Result "Upgrade request authority guard" ($missing.Count -eq 0) "missing=$($missing -join ',')"
}

function Test-AIComDonateAuthorityGuard {
	$takistanRoot = Join-Path $sourceRepoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$roots = @(
		[pscustomobject]@{ Terrain = "chernarus"; Root = $missionRoot },
		[pscustomobject]@{ Terrain = "takistan"; Root = $takistanRoot }
	)
	$missing = @()
	foreach ($entry in $roots) {
		$requestPath = Join-Path $entry.Root "Server\PVFunctions\RequestAIComDonate.sqf"
		$clientPath = Join-Path $entry.Root "Client\GUI\GUI_TransferMenu.sqf"
		$request = Get-Text $requestPath
		$requestCode = [regex]::Replace($request, "//.*", "")
		$requestCode = [regex]::Replace($requestCode, "/\*[\s\S]*?\*/", "")
		$client = Get-Text $clientPath
		if (-not ($requestCode.Contains('typeName _this != "ARRAY"') -and $requestCode.Contains("count _args < 3"))) { $missing += "$($entry.Terrain):payload-shape" }
		if (-not ($requestCode.Contains('typeName _donor != "OBJECT"') -and $requestCode.Contains('typeName _donorTeam != "GROUP"') -and $requestCode.Contains('typeName _amount != "SCALAR"') -and $requestCode.Contains('_amount != floor _amount'))) { $missing += "$($entry.Terrain):payload-types" }
		if (-not ($requestCode.Contains('!isPlayer _donor') -and $requestCode.Contains('alive _donor') -and $requestCode.Contains('group _donor != _donorTeam'))) { $missing += "$($entry.Terrain):donor-team-binding" }
		if (-not ($requestCode.Contains('_side in [west, east]') -and $requestCode.Contains('WFBE_C_AI_COMMANDER_ENABLED') -and $requestCode.Contains('_humanCmd') -and $requestCode.Contains('isPlayer (leader _cmdTeam)'))) { $missing += "$($entry.Terrain):aicom-side-enabled" }
		if (-not ($requestCode.Contains('WFBE_CO_FNC_GetTeamFunds') -and $requestCode.Contains('WFBE_CO_FNC_ChangeTeamFunds') -and $requestCode.Contains('ChangeAICommanderFunds'))) { $missing += "$($entry.Terrain):server-payment" }
		if ($requestCode.Contains('_donorTeam getVariable "wfbe_funds"')) { $missing += "$($entry.Terrain):raw-group-funds-read" }
		if (-not ($client.Contains('sideJoined in [west, east]') -and $client.Contains('WFBE_C_AI_COMMANDER_ENABLED') -and $client.Contains('player, clientTeam, _funds_transfering'))) { $missing += "$($entry.Terrain):client-request-gate" }
	}
	Add-Result "AI commander donation authority guard" ($missing.Count -eq 0) "missing=$($missing -join ',')"
}

function Test-AicomCommandConsoleAuthorityGuard {
	$takistanRoot = Join-Path $sourceRepoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$roots = @(
		[pscustomobject]@{ Terrain = "chernarus"; Root = $missionRoot },
		[pscustomobject]@{ Terrain = "takistan"; Root = $takistanRoot }
	)
	$missing = @()
	foreach ($entry in $roots) {
		$serverPath = Join-Path $entry.Root "Server\Functions\Server_HandleSpecial.sqf"
		$clientPath = Join-Path $entry.Root "Client\GUI\GUI_Menu_Command.sqf"
		$server = Get-Text $serverPath
		$client = Get-Text $clientPath
		if (-not ($client.Contains('["aicom-posture", sideJoined, _pv, player, group player]') -and $client.Contains('["aicom-fieldorder", sideJoined, _pv, player, group player]') -and $client.Contains('["aicom-ai-command", sideJoined, _send, player, group player]') -and $client.Contains('["aicom-arty-here", sideJoined, [_position select 0, _position select 1, 0], player, group player]') -and $client.Contains('["aicom-request-unit", sideJoined, _reqTypes select _rs, player, group player]') -and $client.Contains('["aicom-team-disband", sideJoined, "ALL", player, group player]'))) { $missing += "$($entry.Terrain):client-requester-context" }
		if (-not ($server.Contains('_validateAicomConsoleRequester') -and $server.Contains('count _vArgs < 5'))) { $missing += "$($entry.Terrain):validator-shape" }
		if (-not ($server.Contains('typeName _requester != "OBJECT"') -and $server.Contains('typeName _requestTeam != "GROUP"') -and $server.Contains('!isPlayer _requester') -and $server.Contains('group _requester != _requestTeam') -and $server.Contains('side _requestTeam != _vSide'))) { $missing += "$($entry.Terrain):requester-team-binding" }
		if (-not ($server.Contains('leader _cmdTeam != _requester') -and $server.Contains('!isPlayer (leader _cmdTeam)'))) { $missing += "$($entry.Terrain):human-commander-binding" }
		if (-not ($server.Contains('[_args, _aSide, true] Call _validateAicomConsoleRequester') -and $server.Contains('[_args, _pSide, false] Call _validateAicomConsoleRequester') -and $server.Contains('[_args, _dSide, true] Call _validateAicomConsoleRequester') -and $server.Contains('[_args, _uSide, true] Call _validateAicomConsoleRequester') -and $server.Contains('[_args, _fSide, true] Call _validateAicomConsoleRequester') -and $server.Contains('[_args, _rSide, true] Call _validateAicomConsoleRequester'))) { $missing += "$($entry.Terrain):case-gates" }
	}
	Add-Result "AICOM command-console authority guard" ($missing.Count -eq 0) "missing=$($missing -join ',')"
}

function Test-AicomTeamLifecycleAuthorityGuard {
	$takistanRoot = Join-Path $sourceRepoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$roots = @(
		[pscustomobject]@{ Terrain = "chernarus"; Root = $missionRoot },
		[pscustomobject]@{ Terrain = "takistan"; Root = $takistanRoot }
	)
	$missing = @()
	foreach ($entry in $roots) {
		$serverPath = Join-Path $entry.Root "Server\Functions\Server_HandleSpecial.sqf"
		$runnerPath = Join-Path $entry.Root "Common\Functions\Common_RunCommanderTeam.sqf"
		$server = Get-Text $serverPath
		$runner = Get-Text $runnerPath
		$serverCode = [regex]::Replace($server, "//.*", "")
		$serverCode = [regex]::Replace($serverCode, "/\*[\s\S]*?\*/", "")
		$runnerCode = [regex]::Replace($runner, "//.*", "")
		$runnerCode = [regex]::Replace($runnerCode, "/\*[\s\S]*?\*/", "")
		$headingBlock = ""
		$headingStart = $serverCode.IndexOf('case "aicom-team-heading"')
		if ($headingStart -ge 0) {
			$headingEnd = $serverCode.IndexOf('case "aicom-vehicle-abandoned"', $headingStart)
			if ($headingEnd -gt $headingStart) {
				$headingBlock = $serverCode.Substring($headingStart, $headingEnd - $headingStart)
			}
		}
		if (-not ($runnerCode.Contains('setVariable ["wfbe_aicom_sideid", _sideID, true]') -and $runnerCode.Contains('setVariable ["wfbe_aicom_transport_team", _team, true]') -and $runnerCode.Contains('setVariable ["wfbe_aicom_transport_type", typeOf _airVeh, true]') -and $runnerCode.Contains('count _this > 9') -and $runnerCode.Contains('["aicom-team-ended", _sideID, grpNull, _pendingToken]') -and $runnerCode.Contains('["aicom-team-created", _sideID, _team, _pendingToken]') -and $runnerCode.Contains('["aicom-heli-refunded", _sID, _h, _tm, _htype]'))) { $missing += "$($entry.Terrain):sender-team-binding" }
		if (-not ($serverCode.Contains('_validateAicomManagedTeamForSide') -and $serverCode.Contains('WFBE_CO_FNC_GroupGetBool') -and $serverCode.Contains('wfbe_aicom_sideid') -and $serverCode.Contains('_consumeAicomPendingToken') -and $serverCode.Contains('wfbe_aicom_pending_tokens'))) { $missing += "$($entry.Terrain):managed-team-validator" }
		if (-not ($serverCode.Contains('count _args < 3') -and $serverCode.Contains('rejected malformed aicom-team-created') -and $serverCode.Contains('rejected untrusted aicom-team-created') -and $serverCode.Contains('rejected duplicate aicom-team-created') -and $serverCode.Contains('rejected stale aicom-team-created pending token'))) { $missing += "$($entry.Terrain):created-guard" }
		if (-not ($serverCode.Contains('rejected malformed aicom-team-ended') -and $serverCode.Contains('rejected untrusted aicom-team-ended') -and $serverCode.Contains('rejected unregistered aicom-team-ended') -and $serverCode.Contains('rejected live aicom-team-ended') -and $serverCode.Contains('rejected unauthenticated aicom-team-ended pending release') -and $serverCode.Contains('rejected stale aicom-team-ended pending release token') -and $serverCode.Contains('typeName _x == "ARRAY"') -and $serverCode.Contains('count _x >= 4'))) { $missing += "$($entry.Terrain):ended-guard" }
		if (-not ($serverCode.Contains('rejected malformed aicom-team-heading') -and $serverCode.Contains('typeName _hdir != "SCALAR"') -and $serverCode.Contains('rejected untrusted aicom-team-heading') -and $serverCode.Contains('rejected unregistered aicom-team-heading'))) { $missing += "$($entry.Terrain):heading-guard" }
		if ($headingBlock.Contains('(_args select 1) select 0')) { $missing += "$($entry.Terrain):raw-heading-select" }
		if (-not ($serverCode.Contains('count _args < 5') -and $serverCode.Contains('typeName _rVeh != "OBJECT"') -and $serverCode.Contains('typeName _rTeam != "GROUP"') -and $serverCode.Contains('typeName _rType != "STRING"') -and $serverCode.Contains('typeOf _rVeh != _rType') -and $serverCode.Contains('group (driver _rVeh) != _rTeam') -and $serverCode.Contains('wfbe_aicom_transport_refunded') -and $serverCode.Contains('_rCost = _rMaxCost') -and $serverCode.Contains('rejected untrusted aicom-heli-refunded') -and $serverCode.Contains('rejected unregistered aicom-heli-refunded') -and $serverCode.Contains('rejected aicom-heli-refunded transport not off-map'))) { $missing += "$($entry.Terrain):refund-guard" }
	}
	Add-Result "AICOM lifecycle/refund authority guard" ($missing.Count -eq 0) "missing=$($missing -join ',')"
}

function Test-AicomHcTopUpDraftExcluded {
	$takistanRoot = Join-Path $sourceRepoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$roots = @(
		[pscustomobject]@{ Terrain = "chernarus"; Root = $missionRoot },
		[pscustomobject]@{ Terrain = "takistan"; Root = $takistanRoot }
	)
	$hits = @()
	$forbiddenTokens = @(
		"WFBE_SE_FNC_AI_Com_HCTopUp",
		"aicom-team-topup",
		"aicom-team-merge",
		"WFBE_C_AICOM_HC_TOPUP",
		"WFBE_C_AICOM_HC_MERGE_ENABLE",
		"WFBE_C_AICOM_HC_MERGE_FRAC",
		"WFBE_C_AICOM_HC_MERGE_RANGE",
		"WFBE_C_AICOM_HC_MERGE_INTERVAL",
		"AICOMHCMERGE",
		"HC_TOPUP",
		"HC_MERGE",
		"AI_Commander_HCTopUp.DRAFT"
	)
	foreach ($entry in $roots) {
		$draft = Join-Path $entry.Root "Server\AI\Commander\AI_Commander_HCTopUp.DRAFT.sqf"
		if (Test-Path -LiteralPath $draft) { $hits += "$($entry.Terrain):draft-file" }
		$files = Get-ChildItem -LiteralPath $entry.Root -Recurse -File -ErrorAction SilentlyContinue |
			Where-Object { $_.Extension -in @(".sqf",".fsm",".ext",".hpp") }
		foreach ($file in $files) {
			$text = [System.IO.File]::ReadAllText($file.FullName)
			foreach ($token in $forbiddenTokens) {
				if ($text.Contains($token)) {
					$relative = $file.FullName.Substring($entry.Root.Length).TrimStart('\')
					$hits += "$($entry.Terrain):$($relative):$token"
				}
			}
		}
	}
	Add-Result "AICOM HC top-up draft excluded" ($hits.Count -eq 0) "hits=$($hits -join ',')"
}

function Test-AicomGroupVariableDefaults {
	$takistanRoot = Join-Path $sourceRepoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$roots = @(
		[pscustomobject]@{ Terrain = "chernarus"; Root = $missionRoot },
		[pscustomobject]@{ Terrain = "takistan"; Root = $takistanRoot }
	)
	$missing = @()
	foreach ($entry in $roots) {
		$executePath = Join-Path $entry.Root "Server\AI\Commander\AI_Commander_Execute.sqf"
		$commanderPath = Join-Path $entry.Root "Server\AI\Commander\AI_Commander.sqf"
		$runTeamPath = Join-Path $entry.Root "Common\Functions\Common_RunCommanderTeam.sqf"
		$commandGuiPath = Join-Path $entry.Root "Client\GUI\GUI_Menu_Command.sqf"
		$initCommonPath = Join-Path $entry.Root "Common\Init\Init_Common.sqf"
		$commanderDir = Join-Path $entry.Root "Server\AI\Commander"
		$groupDefaultScanPaths = @(
			$commandGuiPath,
			$runTeamPath,
			(Join-Path $entry.Root "Server\FSM\server_groupsGC.sqf"),
			(Join-Path $entry.Root "Server\Functions\Server_HandleSpecial.sqf"),
			(Join-Path $entry.Root "Server\Functions\Server_OnPlayerConnected.sqf"),
			(Join-Path $entry.Root "Server\Support\Support_ScudStrike.sqf"),
			(Join-Path $entry.Root "Client\PVFunctions\HandleSpecial.sqf")
		)
		$execute = Get-Text $executePath
		$commander = Get-Text $commanderPath
		$runTeam = Get-Text $runTeamPath
		$commandGui = Get-Text $commandGuiPath
		$initCommon = Get-Text $initCommonPath
		if (-not $initCommon.Contains("WFBE_CO_FNC_GroupGetValue = Compile preprocessFileLineNumbers")) { $missing += "$($entry.Terrain):group-get-value-helper" }
		if (-not $execute.Contains('[_team, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetValue')) { $missing += "$($entry.Terrain):execute-mode" }
		if (-not $execute.Contains('[_team, "wfbe_teamgoto", [0,0,0]] Call WFBE_CO_FNC_GroupGetValue')) { $missing += "$($entry.Terrain):execute-goto" }
		if (-not $execute.Contains('[_team, "wfbe_exec_lastmode", ""] Call WFBE_CO_FNC_GroupGetValue')) { $missing += "$($entry.Terrain):execute-lastmode" }
		if (-not $execute.Contains('[_team, "wfbe_exec_lastgoto", [0,0,0]] Call WFBE_CO_FNC_GroupGetValue')) { $missing += "$($entry.Terrain):execute-lastgoto" }
		if (-not $execute.Contains('[_team, "wfbe_exec_at", -1e9] Call WFBE_CO_FNC_GroupGetValue')) { $missing += "$($entry.Terrain):execute-at" }
		if ($execute.Contains('_team getVariable ["wfbe_teammode", "towns"]') -or $execute.Contains('_team getVariable ["wfbe_teamgoto", [0,0,0]]') -or $execute.Contains('_team getVariable ["wfbe_exec_sig", []') -or $execute.Contains('_team getVariable ["wfbe_exec_lastmode", "') -or $execute.Contains('_team getVariable ["wfbe_exec_lastgoto", [0,0,0]]') -or $execute.Contains('_team getVariable ["wfbe_exec_at", -1e9]')) { $missing += "$($entry.Terrain):execute-raw-group-default" }
		if ($commander.Contains('wfbe_exec_sig')) { $missing += "$($entry.Terrain):commander-old-exec-sig" }
		if (-not $commander.Contains('_x setVariable ["wfbe_exec_lastmode", ""]') -or -not $commander.Contains('_x setVariable ["wfbe_exec_lastgoto", [0,0,0]]') -or -not $commander.Contains('_x setVariable ["wfbe_exec_at", -1e9]')) { $missing += "$($entry.Terrain):commander-latch-reset" }
		if (-not $runTeam.Contains('[_team, "wfbe_aicom_cappasses", 0] Call WFBE_CO_FNC_GroupGetValue')) { $missing += "$($entry.Terrain):capture-pass-helper" }
		if ($runTeam.Contains('_team getVariable ["wfbe_aicom_cappasses", 0]')) { $missing += "$($entry.Terrain):capture-pass-raw-group-default" }
		if (-not $commandGui.Contains('[_grp, "wfbe_teamgoto", objNull] Call WFBE_CO_FNC_GroupGetValue')) { $missing += "$($entry.Terrain):command-gui-goto-helper" }
		if ($commandGui.Contains('_grp getVariable ["wfbe_teamgoto", objNull]')) { $missing += "$($entry.Terrain):command-gui-raw-group-default" }
		$groupDefaultScanPaths += (Get-ChildItem -LiteralPath $commanderDir -Filter "*.sqf" -File | ForEach-Object { $_.FullName })
		foreach ($filePath in $groupDefaultScanPaths) {
			$lineNumber = 0
			$inBlockComment = $false
			foreach ($line in [System.IO.File]::ReadLines($filePath)) {
				$lineNumber++
				$code = Remove-StringLiterals (Remove-CodeComments $line ([ref]$inBlockComment))
				if ($code -match '\b(_team|_grp|_riGrp|_wTeam|_free|_best|_cand|_candidate|_cteam|_hteam|_rTeam|_tm)\s+getVariable\s+\[') {
					$missing += "$($entry.Terrain):raw-group-default:$([System.IO.Path]::GetFileName($filePath)):$lineNumber"
				}
				if ($code -match '(\(group\s+[_a-zA-Z0-9]+\)|\b(_playerTeam|_playerGroup|_requestTeam|_donorTeam|_cmdTeam|_comTeam|_team|_grp|_riGrp|_wTeam|_free|_best|_cand|_candidate|_cteam|_hteam|_rTeam|_tm))\s+getVariable\s+\["wfbe_funds"') {
					$missing += "$($entry.Terrain):raw-group-funds-default:$([System.IO.Path]::GetFileName($filePath)):$lineNumber"
				}
				if (([System.IO.Path]::GetFileName($filePath) -eq "Server_OnPlayerConnected.sqf") -and ($code -match '\b_x\s+getVariable\s+\["wfbe_funds"')) {
					$missing += "$($entry.Terrain):raw-roster-funds-default:$([System.IO.Path]::GetFileName($filePath)):$lineNumber"
				}
			}
		}
	}
	Add-Result "AICOM group variable default guards" ($missing.Count -eq 0) "missing=$($missing -join ',')"
}

function Test-HcPvfGuard {
	$handle = Get-Text (Join-Path $missionRoot "Client\Functions\Client_HandlePVF.sqf")
	$town = Get-Text (Join-Path $missionRoot "Client\PVFunctions\TownCaptured.sqf")
	$camp = Get-Text (Join-Path $missionRoot "Client\PVFunctions\CampCaptured.sqf")
	$allCamps = Get-Text (Join-Path $missionRoot "Client\PVFunctions\AllCampsCaptured.sqf")
	$bounty = Get-Text (Join-Path $missionRoot "Client\PVFunctions\AwardBounty.sqf")
	$bountyPlayer = Get-Text (Join-Path $missionRoot "Client\PVFunctions\AwardBountyPlayer.sqf")
	$detectsHc = $handle.Contains("isHeadLessClient") -and $handle.Contains("hasInterface")
	$allowsDelegates = $handle.Contains("delegate-townai") -and $handle.Contains("delegate-ai-static-defence")
	$blocksPlayerPvfs = $handle.Contains("if !(_hcAllowed) exitWith {}")
	$guardsSide = $handle.Contains('if !(isNil "sideJoined")')
	$guardsTown = $town.Contains('if (isNil "WFBE_Client_SideID") exitWith {}')
	$guardsCamp = $camp.Contains('if (isNil "WFBE_Client_SideID") exitWith {}')
	$guardsAll = $allCamps.Contains('if (isNil "WFBE_Client_SideID") exitWith {}')
	$guardsBounty = $bounty.Contains('if (!isNil "isHeadLessClient") then {if (isHeadLessClient) exitWith {}}') -and $bounty.Contains('if (isNull player) exitWith {}') -and $bountyPlayer.Contains('if (!isNil "isHeadLessClient") then {if (isHeadLessClient) exitWith {}}') -and $bountyPlayer.Contains('if (isNull player) exitWith {}')
	Add-Result "HC client PVF guard" ($detectsHc -and $allowsDelegates -and $blocksPlayerPvfs -and $guardsSide -and $guardsTown -and $guardsCamp -and $guardsAll -and $guardsBounty) "detectsHc=$detectsHc delegates=$allowsDelegates blocks=$blocksPlayerPvfs sideGuard=$guardsSide town=$guardsTown camp=$guardsCamp all=$guardsAll bounty=$guardsBounty"
}

function Test-HcDelegatedAiLocalGroups {
	$delegateTown = Get-Text (Join-Path $missionRoot "Client\Functions\Client_DelegateTownAI.sqf")
	$delegateStatic = Get-Text (Join-Path $missionRoot "Client\Functions\Client_DelegateAIStaticDefence.sqf")
	$createStatic = Get-Text (Join-Path $missionRoot "Common\Functions\Common_CreateUnitForStaticDefence.sqf")
	$createUnit = Get-Text (Join-Path $missionRoot "Common\Functions\Common_CreateUnit.sqf")
	$createTeam = Get-Text (Join-Path $missionRoot "Common\Functions\Common_CreateTeam.sqf")
	$townLocalizes = $delegateTown.Contains("count units _team") -and $delegateTown.Contains('[_side, "town-ai"] Call WFBE_CO_FNC_CreateGroup') -and $delegateTown.Contains("_teams set [_i, _team]")
	$staticLocalizes = $delegateStatic.Contains("GROUP BLOAT REDUCTION") -and $delegateStatic.Contains("WFBE_CO_FNC_CreateUnitForStaticDefence") -and $createStatic.Contains('[_side, "defense-gunners"] Call WFBE_CO_FNC_CreateGroup') -and $createStatic.Contains("wfbe_hc_local_grp")
	$unitFallback = $createUnit.Contains("_teamLeader = leader _team") -and $createUnit.Contains("!local _teamLeader") -and $createUnit.Contains("is not local here; creating local fallback group") -and $createUnit.Contains("if (isNull _unit) exitWith") -and (-not $createUnit.Contains("local _team)"))
	$teamFiltersNull = $createTeam.Contains("if (isNull _unit) then") -and $createTeam.Contains("if (isNull _crewUnit) exitWith {}")   # recalibrated: baseline guards the null-unit case with isNull (not !isNull)
	Add-Result "HC delegated AI local groups" ($townLocalizes -and $staticLocalizes -and $unitFallback -and $teamFiltersNull) "town=$townLocalizes static=$staticLocalizes unitFallback=$unitFallback nullFilter=$teamFiltersNull"
}

function Test-GuiImageTabGuard {
	$buyUnits = Join-Path $missionRoot "Client\GUI\GUI_Menu_BuyUnits.sqf"
	$text = Get-Text $buyUnits
	$danger = ($text -match "ctrlSet(Text|StructuredText)[\s\S]{0,120}(12001|12002|12003|12004)")
	Add-Result "Buy Units image-tab guard" (-not $danger) ($(if ($danger) { "Queue/text write appears close to an image-tab IDC." } else { "No ctrlSetText/ctrlSetStructuredText writes near factory image-tab IDCs." }))
}

function Test-StaleUpgradeDialog {
	$roots = @("Missions", "Missions_Vanilla", "Modded_Missions")
	$hits = @()
	foreach ($root in $roots) {
		$fullRoot = Join-Path $sourceRepoRoot $root
		if (!(Test-Path -LiteralPath $fullRoot)) { continue }
		foreach ($dialog in Get-ChildItem -LiteralPath $fullRoot -Recurse -Filter "Dialogs.hpp") {
			$text = Get-Text $dialog.FullName
			if ($text.Contains("class RscMenu_Upgrade") -or $text.Contains("GUI_Menu_Upgrade.sqf")) {
				$hits += (Resolve-Path -LiteralPath $dialog.FullName -Relative)
			}
		}
	}
	Add-Result "Stale upgrade dialog removed" ($hits.Count -eq 0) ($(if ($hits.Count) { $hits -join "; " } else { "No stale RscMenu_Upgrade blocks or missing GUI_Menu_Upgrade.sqf onLoad references remain." }))
}

function Test-SupplyHeliTimers {
	$constants = Get-Text (Join-Path $missionRoot "Common\Init\Init_CommonConstants.sqf")
	$initClient = Get-Text (Join-Path $missionRoot "Client\Init\Init_Client.sqf")
	$startScript = Get-Text (Join-Path $missionRoot "Client\Module\supplyMission\supplyMissionStart.sqf")
	$loadMatch = [regex]::Match($constants, "WFBE_C_SUPPLY_HELI_LOAD_TIME\s*=\s*(?<value>\d+)")
	$unloadMatch = [regex]::Match($constants, "WFBE_C_SUPPLY_HELI_UNLOAD_TIME\s*=\s*(?<value>\d+)")
	$load = if ($loadMatch.Success) { [int]$loadMatch.Groups["value"].Value } else { -1 }
	$unload = if ($unloadMatch.Success) { [int]$unloadMatch.Groups["value"].Value } else { -1 }
	$compileOnly = $initClient.Contains('WFBE_CL_FNC_SupplyMissionStart = Compile preprocessFileLineNumbers "Client\Module\supplyMission\supplyMissionStart.sqf"') -and $initClient.Contains('WFBE_CL_FNC_SupplyMissionUnload = Compile preprocessFileLineNumbers "Client\Module\supplyMission\supplyMissionUnload.sqf"')
	$noCallCompile = -not $initClient.Contains('WFBE_CL_FNC_SupplyMissionStart = Call Compile') -and -not $initClient.Contains('WFBE_CL_FNC_SupplyMissionUnload = Call Compile')
	$guardedCursor = $startScript.Contains('if (isNull _cursorTarget) exitWith') -and $startScript.Contains('is not a supply vehicle') -and $startScript.Contains('_loadedAmount = _cursorTarget getVariable ["SupplyAmount", 0]')
	Add-Result "Supply heli load/unload timers" ($load -eq 15 -and $unload -eq 15 -and $compileOnly -and $noCallCompile -and $guardedCursor) "load=$load unload=$unload compileOnly=$compileOnly noCallCompile=$noCallCompile guardedCursor=$guardedCursor"
}

function Test-ServiceMenuDisplayGuard {
	$service = Get-Text (Join-Path $missionRoot "Client\GUI\GUI_Menu_Service.sqf")
	$activeService = if (Test-Path -LiteralPath $ActiveMissionRoot) { Get-Text (Join-Path $ActiveMissionRoot "Client\GUI\GUI_Menu_Service.sqf") } else { "" }
	$sourceOk = $service.Contains("disableSerialization;") -and $service.Contains("_dialog = findDisplay 20000") -and (-not $service.Contains("currentBEDialog displayCtrl 20021")) -and (-not $service.Contains('&& {!isNull currentBEDialog}'))
	$activeOk = ($activeService -eq "") -or ($activeService.Contains("_dialog = findDisplay 20000") -and (-not $activeService.Contains("currentBEDialog displayCtrl 20021")))
	Add-Result "Service menu display guard" ($sourceOk -and $activeOk) "sourceOk=$sourceOk activeOk=$activeOk"
}

function Test-WfMenuGpsButton {
	$dialogs = Get-Text (Join-Path $missionRoot "Rsc\Dialogs.hpp")
	$menu = Get-Text (Join-Path $missionRoot "Client\GUI\GUI_Menu.sqf")
	$description = Get-Text (Join-Path $missionRoot "description.ext")
	$activeDialogsPath = Join-Path $ActiveMissionRoot "Rsc\Dialogs.hpp"
	$activeMenuPath = Join-Path $ActiveMissionRoot "Client\GUI\GUI_Menu.sqf"
	$activeDescriptionPath = Join-Path $ActiveMissionRoot "description.ext"
	$activeDialogs = if (Test-Path -LiteralPath $activeDialogsPath) { Get-Text $activeDialogsPath } else { "" }
	$activeMenu = if (Test-Path -LiteralPath $activeMenuPath) { Get-Text $activeMenuPath } else { "" }
	$activeDescription = if (Test-Path -LiteralPath $activeDescriptionPath) { Get-Text $activeDescriptionPath } else { "" }
	$sourceHudButton = $dialogs.Contains("class CA_HUD_Button : RscButton_Main") -and $dialogs.Contains('text = "HUD";') -and $dialogs.Contains("tooltip = ""HUD On/Off""")
	$sourceButton = $dialogs.Contains("class CA_GPS_Button : RscButton_Main") -and $dialogs.Contains('text = "GPS";') -and $dialogs.Contains("tooltip = ""Enable GPS / Mini Map""")
	$sourceGpsAllowed = $description.Contains("showGPS = 1;")
	$sourceToggle = $menu.Contains('WFBE_Client_MenuGPSState') -and $menu.Contains('!("ItemGPS" in weapons player)') -and $menu.Contains('player addWeapon "ItemGPS"') -and $menu.Contains("showGPS true") -and $menu.Contains("shownGPS") -and $menu.Contains("GPS enabled.") -and $menu.Contains("closeDialog 0")
	$activeHudButton = ($activeDialogs -eq "") -or ($activeDialogs.Contains("class CA_HUD_Button : RscButton_Main") -and $activeDialogs.Contains('text = "HUD";'))
	$activeButton = ($activeDialogs -eq "") -or ($activeDialogs.Contains("class CA_GPS_Button : RscButton_Main") -and $activeDialogs.Contains('text = "GPS";') -and $activeDialogs.Contains("tooltip = ""Enable GPS / Mini Map"""))
	$activeGpsAllowed = ($activeDescription -eq "") -or $activeDescription.Contains("showGPS = 1;")
	$activeToggle = ($activeMenu -eq "") -or ($activeMenu.Contains('WFBE_Client_MenuGPSState') -and $activeMenu.Contains('!("ItemGPS" in weapons player)') -and $activeMenu.Contains('player addWeapon "ItemGPS"') -and $activeMenu.Contains("showGPS true") -and $activeMenu.Contains("shownGPS") -and $activeMenu.Contains("GPS enabled.") -and $activeMenu.Contains("closeDialog 0"))
	Add-Result "WF menu GPS/HUD buttons" ($sourceHudButton -and $sourceButton -and $sourceGpsAllowed -and $sourceToggle -and $activeHudButton -and $activeButton -and $activeGpsAllowed -and $activeToggle) "sourceHud=$sourceHudButton sourceGps=$sourceButton sourceGpsAllowed=$sourceGpsAllowed sourceEnable=$sourceToggle activeHud=$activeHudButton activeGps=$activeButton activeGpsAllowed=$activeGpsAllowed activeEnable=$activeToggle"
}

function Test-RhudEconomyFpsLayout {
	$rhud = Get-Text (Join-Path $missionRoot "Client\Client_UpdateRHUD.sqf")
	$initClient = Get-Text (Join-Path $missionRoot "Client\Init\Init_Client.sqf")
	$menu = Get-Text (Join-Path $missionRoot "Client\GUI\GUI_Menu.sqf")
	$stressPath = Join-Path $ActiveMissionRoot "test\wasp_pr8_stress_mission.sqf"
	$activeInitPath = Join-Path $ActiveMissionRoot "Client\Init\Init_Client.sqf"
	$activeRhudPath = Join-Path $ActiveMissionRoot "Client\Client_UpdateRHUD.sqf"
	$stress = if (Test-Path -LiteralPath $stressPath) { Get-Text $stressPath } else { "" }
	$activeInit = if (Test-Path -LiteralPath $activeInitPath) { Get-Text $activeInitPath } else { "" }
	$activeRhud = if (Test-Path -LiteralPath $activeRhudPath) { Get-Text $activeRhudPath } else { "" }
	$moneyIncome = $rhud.Contains('%1 $ | %2') -and $rhud.Contains('[7, "Money:"]')
	$baseStatus = $rhud.Contains('[11, "Base:"]') -and (-not $rhud.Contains('[13, "SV Min:"]'))   # recalibrated: index-11 row renamed SV+: -> Base: (kept $baseStatus name — consumed by Add-Result below)
	$fpsCombined = $rhud.Contains('[13, "FPS C/S:"]') -and $rhud.Contains('format ["%1 / %2  VD %3", _clientFPS, _serverFPS, round viewDistance]') -and (-not $rhud.Contains('[15, "FPS Server:"]'))
	$hiddenOldRows = $rhud.Contains('{[_x, false] call _RHUDSetShow} forEach [15,16,17,18]') -and $rhud.Contains('{[_x, false] call _RHUDSetShow} forEach [27,28]')
	$topStrip = $menu.Contains('| SV %9') -and (-not $menu.Contains('| SV+ %9')) -and (-not $menu.Contains('| FPS %9'))
	$stressProof = $stress.Contains('topStrip=uptime|time|players|towns|svSigned') -and $stress.Contains('rhud=moneyIncome|baseStatus|fpsClientServer')
	$hudDefaultOn = $initClient.Contains('if (isNil "RUBHUD") then {RUBHUD = true}') -and $rhud.Contains('if (isNil "RUBHUD") then {RUBHUD = true}') -and (-not $initClient.Contains("Start RHUD hidden"))
	$activeHudDefaultOn = ($activeInit -eq "") -or ($activeInit.Contains('if (isNil "RUBHUD") then {RUBHUD = true}') -and $activeRhud.Contains('if (isNil "RUBHUD") then {RUBHUD = true}'))
	Add-Result "RHUD economy/FPS layout" ($moneyIncome -and $baseStatus -and $fpsCombined -and $hiddenOldRows -and $topStrip -and $stressProof -and $hudDefaultOn -and $activeHudDefaultOn) "moneyIncome=$moneyIncome baseStatus=$baseStatus fpsCombined=$fpsCombined hiddenOldRows=$hiddenOldRows topStrip=$topStrip stressProof=$stressProof hudDefaultOn=$hudDefaultOn activeHudDefaultOn=$activeHudDefaultOn"
}

function Test-AfkBoolComparisons {
	$updateClient = Get-Text (Join-Path $missionRoot "Client\FSM\updateclient.sqf")
	$noBoolNotEquals = -not [regex]::IsMatch($updateClient, "\b(_afk|_commandAndConquer)\s*!=")
	$afkXor = $updateClient.Contains("(_afk && !_afkShouldBe) || (!_afk && _afkShouldBe)")
	$publishes = $updateClient.Contains('player setVariable ["WASP_AFK", _afkShouldBe, true]')
	$commandXor = (-not $updateClient.Contains("_commandAndConquer")) -or $updateClient.Contains("(_commandAndConquer && !_commandAndConquerShouldBe) || (!_commandAndConquer && _commandAndConquerShouldBe)")
	Add-Result "AFK boolean comparison guard" ($noBoolNotEquals -and $afkXor -and $publishes -and $commandXor) "noBoolNotEquals=$noBoolNotEquals afkXor=$afkXor publishes=$publishes commandXor=$commandXor"
}

function Test-HarnessBoolComparisons {
	$roots = @()
	$overlayTest = Join-Path $harnessRoot "Overlays\pr8-stress\test"
	$activeTest = Join-Path $ActiveMissionRoot "test"
	if (Test-Path -LiteralPath $overlayTest) { $roots += $overlayTest }
	if (Test-Path -LiteralPath $activeTest) { $roots += $activeTest }
	$hits = @()
	foreach ($root in $roots) {
		foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -Filter "*.sqf") {
			$lineNumber = 0
			foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
				$lineNumber++
				$code = Remove-LineComment $line
				if ($code -match "(?i)(!=\s*(true|false)|(true|false)\s*!=)") {
					$hits += "$($file.Name):$lineNumber"
				}
			}
		}
	}
	Add-Result "Harness boolean comparison guard" ($hits.Count -eq 0) ($(if ($hits.Count) { $hits -join "; " } else { "No true/false != comparisons in stress harness SQF." }))
}

function Test-DefenseAutoManningDefault {
	$initClient = Get-Text (Join-Path $missionRoot "Client\Init\Init_Client.sqf")
	$coin = Get-Text (Join-Path $missionRoot "Client\Module\CoIn\coin_interface.sqf")
	$request = Get-Text (Join-Path $missionRoot "Server\PVFunctions\RequestDefense.sqf")
	$defaultsOn = [regex]::IsMatch($initClient, "(?m)^\s*manningDefense\s*=\s*true\s*;")
	$sent = $coin.Contains('"RequestDefense", [sideJoined,_class,_pos,_dir,manningDefense')
	$toggle = $coin.Contains('Auto-manning defense: %1')
	$comment = $request.Contains('defaults on')
	Add-Result "Defense auto-manning default" ($defaultsOn -and $sent -and $toggle -and $comment) "defaultOn=$defaultsOn sent=$sent toggleText=$toggle comment=$comment"
}

function Test-BuyMenuAutoCrewDefault {
	$buyUnits = Get-Text (Join-Path $missionRoot "Client\GUI\GUI_Menu_BuyUnits.sqf")
	$driverInit = [regex]::IsMatch($buyUnits, "(?m)^\s*_driverEnabledByDefault\s*=\s*true\s*;")
	$profileInit = $buyUnits.Contains('profileNamespace setVariable ["wfbe_c_driver_enabled_by_default", true]')
	$gunnerInit = [regex]::IsMatch($buyUnits, "(?m)^\s*_gunner\s*=\s*true\s*;")
	$commanderInit = [regex]::IsMatch($buyUnits, "(?m)^\s*_commander\s*=\s*true\s*;")
	$extraInit = [regex]::IsMatch($buyUnits, "(?m)^\s*_extracrew\s*=\s*true\s*;")
	$selectionReset = $buyUnits.Contains('_gunner = true;') -and $buyUnits.Contains('_commander = true;') -and $buyUnits.Contains('_extracrew = true;')
	Add-Result "Buy-menu auto-crew default" ($driverInit -and $profileInit -and $gunnerInit -and $commanderInit -and $extraInit -and $selectionReset) "driver=$driverInit profile=$profileInit gunner=$gunnerInit commander=$commanderInit extra=$extraInit reset=$selectionReset"
}

function Test-VehicleBountyAssistType {
	$killed = Get-Text (Join-Path $missionRoot "Server\PVFunctions\RequestOnUnitKilled.sqf")
	$noStaleObjectType = -not [regex]::IsMatch($killed, "\b_objectType\b")
	$assistUsesKilledType = $killed.Contains('"AwardBounty", [_killed_type, true]')
	Add-Result "Vehicle bounty assist type" ($noStaleObjectType -and $assistUsesKilledType) "noObjectType=$noStaleObjectType assistUsesKilledType=$assistUsesKilledType"
}

function Test-SkillInitSingleCompile {
	$initClient = Get-Text (Join-Path $missionRoot "Client\Init\Init_Client.sqf")
	$count = ([regex]::Matches($initClient, [regex]::Escape('Client\Module\Skill\Skill_Init.sqf'))).Count
	$applies = $initClient.Contains('(player) Call WFBE_SK_FNC_Apply;')
	Add-Result "Skill init single compile" ($count -eq 1 -and $applies) "skillInitCalls=$count applyCall=$applies"
}

function Test-ParatrooperMarkerRegistration {
	$initPv = Get-Text (Join-Path $missionRoot "Common\Init\Init_PublicVariables.sqf")
	$handler = Test-Path -LiteralPath (Join-Path $missionRoot "Client\PVFunctions\HandleParatrooperMarkerCreation.sqf")
	$support = Get-Text (Join-Path $missionRoot "Server\Support\Support_Paratroopers.sqf")
	$registered = $initPv.Contains('HandleParatrooperMarkerCreation')
	$sent = $support.Contains('"HandleParatrooperMarkerCreation"')
	Add-Result "Paratrooper marker PVF" ($registered -and $handler -and $sent) "registered=$registered handler=$handler serverSend=$sent"
}

function Test-AiSupplyTruckDisabled {
	$initServer = Get-Text (Join-Path $missionRoot "Server\Init\Init_Server.sqf")
	$fsm = Test-Path -LiteralPath (Join-Path $missionRoot "Server\FSM\supplytruck.fsm")
	$spawnsLegacy = [regex]::IsMatch($initServer, "(?m)^\s*\[_side\]\s+Spawn\s+UpdateSupplyTruck\s*;")
	$warns = $initServer.Contains("AI supply-truck logistics are disabled")
	Add-Result "Legacy AI supply truck guarded" ((-not $fsm) -and (-not $spawnsLegacy) -and $warns) "supplytruckFsmExists=$fsm spawnsLegacy=$spawnsLegacy warning=$warns"
}

function Test-StaleLogGameEndRemoved {
	$hits = @()
	foreach ($root in @("Missions", "Missions_Vanilla")) {
		$fullRoot = Join-Path $sourceRepoRoot $root
		if (!(Test-Path -LiteralPath $fullRoot)) { continue }
		foreach ($file in Get-ChildItem -LiteralPath $fullRoot -Recurse -Filter "LogGameEnd.sqf") {
			if ($file.FullName -match [regex]::Escape("Server\PVFunctions\LogGameEnd.sqf")) {
				$hits += (Resolve-Path -LiteralPath $file.FullName -Relative)
			}
		}
	}
	Add-Result "Stale LogGameEnd PVF removed" ($hits.Count -eq 0) ($(if ($hits.Count) { $hits -join "; " } else { "No stale Server/PVFunctions/LogGameEnd.sqf copies remain in maintained missions." }))
}

function Test-ConfirmActionSurfaces {
	$confirm = Get-Text (Join-Path $missionRoot "Client\Functions\Client_ConfirmAction.sqf")
	$economy = Get-Text (Join-Path $missionRoot "Client\GUI\GUI_Menu_Economy.sqf")
	$tactical = Get-Text (Join-Path $missionRoot "Client\GUI\GUI_Menu_Tactical.sqf")
	$clientInit = Get-Text (Join-Path $missionRoot "Client\Init\Init_Client.sqf")
	$confirmCompiled = $clientInit.Contains('WFBE_CL_FNC_ConfirmAction = Compile preprocessFileLineNumbers "Client\Functions\Client_ConfirmAction.sqf"')
	$sellConfirm = $economy.Contains('wf_sell_') -and $economy.Contains('WFBE_CL_FNC_ConfirmAction')
	$icbmConfirm = $tactical.Contains('wf_icbm') -and $tactical.Contains('Confirm ICBM strike?') -and $tactical.Contains('WFBE_CL_FNC_ConfirmAction')
	$twoClickWindow = $confirm.Contains('uiNamespace getVariable ["wfbe_confirm_key"') -and $confirm.Contains('uiNamespace setVariable ["wfbe_confirm_time", time]') -and $confirm.Contains('(time - _pendTime) < 6') -and $confirm.Contains('returns true ONLY')
	Add-Result "Sell/ICBM confirmation surfaces" ($confirmCompiled -and $sellConfirm -and $icbmConfirm -and $twoClickWindow) "compiled=$confirmCompiled sell=$sellConfirm icbm=$icbmConfirm window=$twoClickWindow"
}

function Test-CleanerStartupThrottle {
	$crater = Get-Text (Join-Path $missionRoot "Server\FSM\cleaners\crater_cleaner.sqf")
	$dropped = Get-Text (Join-Path $missionRoot "Server\FSM\cleaners\droppeditems_cleaner.sqf")
	$ruins = Get-Text (Join-Path $missionRoot "Server\FSM\cleaners\ruins_cleaner.sqf")
	$restorer = Get-Text (Join-Path $missionRoot "Server\FSM\restorers\buildings_restorer.sqf")
	$craterOk = $crater.Contains('if (_timer < 1800) then {_timer = 1800}') -and $crater.Contains('sleep _timer;')
	$droppedOk = $dropped.Contains('if (_timer < 300) then {_timer = 300}') -and $dropped.Contains('sleep _timer;')
	$ruinsOk = $ruins.Contains('if (_timer < 1800) then {_timer = 1800}') -and $ruins.Contains('sleep _timer;')
	$restorerOk = $restorer.Contains('if (_timer < 1800) then {_timer = 1800}') -and $restorer.Contains('uisleep _timer;') -and $restorer.Contains('if ((damage _x) > 0) then')
	Add-Result "Cleaner startup throttles" ($craterOk -and $droppedOk -and $ruinsOk -and $restorerOk) "crater=$craterOk dropped=$droppedOk ruins=$ruinsOk restorer=$restorerOk"
}

function Test-Pr8StressHarness {
	$harness = Join-Path $ActiveMissionRoot "test\wasp_pr8_stress_mission.sqf"
	$readme = Join-Path $ActiveMissionRoot "test\README.md"
	$selftest = Join-Path $ActiveMissionRoot "test\wasp_selftest.sqf"
	$exists = (Test-Path -LiteralPath $harness) -and (Test-Path -LiteralPath $readme) -and (Test-Path -LiteralPath $selftest)
	$text = if (Test-Path -LiteralPath $harness) { Get-Text $harness } else { "" }
	$gated = $text.Contains("WASP_PR8_STRESS_ENABLED") -and $text.Contains("disabled - flag is false")
	$anchors = $text.Contains("[WASP-PR8-STRESS]") -and $text.Contains("PHASE_BEGIN") -and $text.Contains("SNAPSHOT") -and $text.Contains("AI_BEHAVIOR") -and $text.Contains("ACTION_MATRIX") -and $text.Contains("TRIGGER") -and $text.Contains("EVIDENCE")
	$coverage = @("hcDelegation","timedSyntheticWaves","townLifecycle","prePressureCapPostRestore","TOWN_SNAPSHOT","TOWN_GROUPS","TOWN_PRESSURE","TOWN_CAPTURE_FORCE","TOWN_CAMP_CAPTURE_FORCE","TOWN_RESTORE","TOWN_PRESSURE_CLEANUP","wddm","hqWalls","commanderArtillery","supplyHeli","supplyInterdiction","easa","service","directDelayedAttribution","buyAutoCrew","autoManning","NOISECHECK","supplyCompletion","teamFunds","reinforcement","WASP_PR8_STRESS_PROFILE","PROFILE selected","CLIENT_COMMAND","clientWave","clientHeavyWave","CLEANUP","WASP_PR8_STRESS_AI_BEHAVIOR","AI_BEHAVIOR","AI_DELEGATION_AUDIT","BUGHUNT_AUDIT","RANDOM_BUGHUNT_AUDIT","GPS_UI_AUDIT","CLIENT_GPS_STATE","CLIENT_UI_TEXT_STATE","CLIENT_SERVICE_CLIP_AUDIT","farStopped","leaderFarStopped","underStrengthGroups","noDestination","noWaypoint","PLAYER_EXPERIENCE_AUDIT","FACTORY_AUDIT","SERVICE_SUPPLY_AUDIT","WDDM_ARTILLERY_AUDIT","UI_AUDIT","PERF_BURST","SPAWN vehicleLoad","WASP_PR8_STRESS_FACTORY_AUDIT","WASP_PR8_STRESS_SERVICE_SUPPLY_AUDIT","WASP_PR8_STRESS_WDDM_ARTILLERY_AUDIT","WASP_PR8_STRESS_UI_AUDIT","WASP_PR8_STRESS_AI_DELEGATION_AUDIT","WASP_PR8_STRESS_BUGHUNT_AUDIT","WASP_PR8_STRESS_RANDOM_BUGHUNT_AUDIT","WASP_PR8_STRESS_PERF_BURST","WASP_PR8_STRESS_SPAWN_VEHICLE_LOAD","wasp-pr8-stress-v5","perfAuditSid","maxAiUnitsVehiclesGroupsDead","CLIENT_COMMAND_SCHEDULED ai-deep-sample","WASP_PR8_STRESS_QUEUE","WASP_PR8_STRESS_QUEUE_ADD","WASP_PR8_STRESS_QUEUE_ENQUEUES","WASP_PR8_STRESS_QUEUE_RUNNER","WASP_PR8_STRESS_QUEUE_SEQUENCE","WASP_PR8_STRESS_WAIT_FOR_HC","WASP_PR8_STRESS_AUTORUN_START","AUTORUN_WAIT","AUTORUN_TRIGGER","operator","ai-long","systems","ui-long","QUEUE_ENQUEUE","QUEUE_BEGIN","QUEUE_STEP","QUEUE_END","QUEUE_STATUS","QUEUE_STOP","QUEUE_PROOF","QUEUE_NOT_TRIGGERED","HC_WAIT_BEGIN","HC_READY","HC_WAIT_TIMEOUT","CLEANUP_LOOP","final_ai_delegation","final_bughunt","final_random_bughunt","final_perf_burst","reason=noDisplay")
	$missing = @()
	foreach ($token in $coverage) {
		if (-not $text.Contains($token)) { $missing += $token }
	}
	$forbidden = @("pushBack","pushBackUnique","selectRandom","isEqualTo","params","parseSimpleArray","remoteExec","setGroupOwner","append","apply","findIf","deleteAt","createHashMap","hashMap")
	$code = [regex]::Replace($text, "//.*", "")
	$forbiddenHits = @()
	foreach ($token in $forbidden) {
		if ($code -match "\b$([regex]::Escape($token))\b") { $forbiddenHits += $token }
	}
	$noUpperError = -not $text.Contains("ERROR")
	Add-Result "Local active stress harness present/gated" ($exists -and $gated -and $anchors -and $missing.Count -eq 0 -and $forbiddenHits.Count -eq 0 -and $noUpperError) "exists=$exists selftest=$(Test-Path -LiteralPath $selftest) gated=$gated anchors=$anchors missingTokens=$($missing -join ',') forbidden=$($forbiddenHits -join ',') noUpperError=$noUpperError"
}

function Test-Pr8StressClientHelper {
	$client = Join-Path $ActiveMissionRoot "test\wasp_pr8_stress_client.sqf"
	$action = Join-Path $ActiveMissionRoot "test\wasp_pr8_stress_client_action.sqf"
	$exists = (Test-Path -LiteralPath $client) -and (Test-Path -LiteralPath $action)
	$clientText = if (Test-Path -LiteralPath $client) { Get-Text $client } else { "" }
	$actionText = if (Test-Path -LiteralPath $action) { Get-Text $action } else { "" }
	$gated = $clientText.Contains("WASP_PR8_STRESS_ENABLED") -and $actionText.Contains("WASP_PR8_STRESS_ENABLED") -and $clientText.Contains("isDedicated")
	$actions = @("queue-operator","queue-ai-long","queue-systems","queue-ui-long","queue-status","queue-stop","cleanup-loop-start","cleanup-loop-stop")
	$missing = @()
	foreach ($token in $actions) {
		if (-not ($clientText.Contains($token) -and $actionText.Contains("WASP_PR8_STRESS_CLIENT_COMMAND"))) { $missing += $token }
	}
	$sends = $actionText.Contains('publicVariableServer "WASP_PR8_STRESS_CLIENT_COMMAND"')
	$hcSkip = $clientText.Contains("helper skipped headless/non-interface") -and $actionText.Contains("skipped headless/non-interface") -and $clientText.Contains("hasInterface") -and $clientText.Contains("isHeadLessClient")
	$autoProbes = $clientText.Contains("WASP_PR8_STRESS_CLIENT_AUTOFIRED") -and $clientText.Contains("auto probe command") -and $clientText.Contains("auto probes complete") -and $clientText.Contains("gps-gain-toggle-audit") -and $clientText.Contains("bughunt-audit") -and $clientText.Contains("random-bughunt-audit") -and $clientText.Contains("DIALOG_AUTO_PROBE")
	$closedUiEvidence = $actionText.Contains("reason=noDisplay")
	$uiSerializationGuard = $actionText.Contains("disableSerialization;") -and $actionText.Contains("findDisplay 11000") -and $actionText.Contains("findDisplay 20000")
	$gpsProbeRestores = $actionText.Contains("_restoreGpsAfterAudit") -and $actionText.Contains("showGPS _gpsBefore") -and $actionText.Contains("CLIENT_GPS_RESTORE")
	Add-Result "Local active stress client helper actions" ($exists -and $gated -and $missing.Count -eq 0 -and $sends -and $hcSkip -and $autoProbes -and $closedUiEvidence -and $uiSerializationGuard -and $gpsProbeRestores) "exists=$exists gated=$gated missingActions=$($missing -join ',') sends=$sends hcSkip=$hcSkip autoProbes=$autoProbes closedUi=$closedUiEvidence uiSerializationGuard=$uiSerializationGuard gpsProbeRestores=$gpsProbeRestores"
}

function Test-Pr8StressRptAnalyzer {
	$analyzer = Join-Path $harnessRoot "Rpt\Analyze-WaspStressRpt.ps1"
	$allow = Join-Path $harnessRoot "Rpt\KnownNoise.txt"
	$missionIssues = Join-Path $harnessRoot "Rpt\MissionIssuePatterns.txt"
	$exists = (Test-Path -LiteralPath $analyzer) -and (Test-Path -LiteralPath $allow) -and (Test-Path -LiteralPath $missionIssues)
	$text = if (Test-Path -LiteralPath $analyzer) { Get-Text $analyzer } else { "" }
	$allowText = if (Test-Path -LiteralPath $allow) { Get-Text $allow } else { "" }
	$issueText = if (Test-Path -LiteralPath $missionIssues) { Get-Text $missionIssues } else { "" }
	$anchors = @("PROFILE selected=","PHASE_BEGIN","AI_BEHAVIOR","SNAPSHOT_SIDE","TOWN_SNAPSHOT","TOWN_GROUPS","TOWN_PRESSURE","TOWN_CAPTURE_FORCE","TOWN_CAMP_CAPTURE_FORCE","TOWN_RESTORE","TOWN_PRESSURE_CLEANUP","ACTION_MATRIX","TRIGGER supplyCompletion","TRIGGER supplyInterdiction","TRIGGER teamFunds","PROBE delayedKill","SPAWN reinforcement","PERF #","NOISECHECK","EVIDENCE","maxFarStopped","maxLeaderFarStopped","maxUnderStrengthGroups","maxNoDestination","AI/pathing symptom counts","Out of path-planning region","Wrong unit index","FACTORY_AUDIT","SERVICE_SUPPLY_AUDIT","WDDM_ARTILLERY_AUDIT","UI_AUDIT","GPS_UI_AUDIT","CLIENT_GPS_STATE","CLIENT_UI_TEXT_STATE","CLIENT_SERVICE_CLIP_AUDIT","AI_DELEGATION_AUDIT","BUGHUNT_AUDIT","RANDOM_BUGHUNT_AUDIT","PLAYER_EXPERIENCE_AUDIT","PERF_BURST","SPAWN vehicleLoad","QUEUE_ENQUEUE","QUEUE_STEP","QUEUE_PROOF","QUEUE_END","QUEUE_NOT_TRIGGERED","HC_READY","HC_WAIT_TIMEOUT","CLEANUP_LOOP","DIALOG_AUTO_PROBE","dialogAutoProbe","queue:","client-heavy-wave","audits:","randomBughunt")
	$missing = @()
	foreach ($token in $anchors) {
		if (-not $text.Contains($token)) { $missing += $token }
	}
	$live = $text.Contains('$Json') -and $text.Contains('$LiveSummary') -and $text.Contains('$Tail') -and $text.Contains('$CurrentRun') -and $text.Contains('$MissionIssuePatternPath') -and $text.Contains("featureTriggers") -and $text.Contains("missionIssueCount")
	$noise = $text.Contains("undefined variable") -and $text.Contains("script .* not found") -and $text.Contains("AllowPattern") -and $allowText.Contains("expectedErrorLines=0") -and $allowText.Contains("MissionIssuePatterns.txt") -and $issueText.Contains("AwardBounty") -and $issueText.Contains("WFBE_Client_SideID")
	Add-Result "PR8 stress RPT analyzer" ($exists -and $missing.Count -eq 0 -and $noise -and $live) "exists=$exists missingAnchors=$($missing -join ',') noiseAllowlist=$noise liveModes=$live"
}

function Test-Pr8LiveWatcher {
	$watcher = Join-Path $harnessRoot "Rpt\Watch-WaspLiveRpt.ps1"
	$exists = Test-Path -LiteralPath $watcher
	$text = if ($exists) { Get-Text $watcher } else { "" }
	$anchors = @("HostRpt","HcRpt","AI_BEHAVIOR","farStopped","leaderFarStopped","underStrengthGroups","noDestination","noWaypoint","emptyGroups","knownNoise","missionIssue","Get-CimInstance","Win32_Process","SupplyMissionUnload","SupplyMissionCompleted","commanderArtillery","FACTORY_AUDIT","SERVICE_SUPPLY_AUDIT","WDDM_ARTILLERY_AUDIT","UI_AUDIT","GPS_UI_AUDIT","CLIENT_GPS_STATE","CLIENT_UI_TEXT_STATE","CLIENT_SERVICE_CLIP_AUDIT","AI_DELEGATION_AUDIT","BUGHUNT_AUDIT","RANDOM_BUGHUNT_AUDIT","PLAYER_EXPERIENCE_AUDIT","PERF_BURST","SPAWN vehicleLoad","QUEUE_ENQUEUE","QUEUE_STEP","QUEUE_PROOF","QUEUE_END","QUEUE_NOT_TRIGGERED","HC_READY","HC_WAIT_TIMEOUT","CLEANUP_LOOP","queue:","gps/ui:","bughunt:","audits:","randomBughunt")
	$missing = @()
	foreach ($token in $anchors) {
		if (-not $text.Contains($token)) { $missing += $token }
	}
	Add-Result "PR8 live RPT watcher" ($exists -and $missing.Count -eq 0) "exists=$exists missingAnchors=$($missing -join ',')"
}

function Test-ShippingMissionsExcludeHarness {
	$chernarusTest = Join-Path $missionRoot "test"
	$takistanRoot = Join-Path $sourceRepoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$takistanTest = Join-Path $takistanRoot "test"
	$chernarusAbsent = -not (Test-Path -LiteralPath $chernarusTest)
	$takistanAbsent = -not (Test-Path -LiteralPath $takistanTest)
	Add-Result "Shipping missions exclude stress harness" ($chernarusAbsent -and $takistanAbsent) "chernarusTestAbsent=$chernarusAbsent takistanTestAbsent=$takistanAbsent"
}

function Test-ReleaseRoleProofDiagLogEmitters {
	$takistanRoot = Join-Path $sourceRepoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$roots = @(
		[pscustomobject]@{ Terrain = "chernarus"; Root = $missionRoot },
		[pscustomobject]@{ Terrain = "takistan"; Root = $takistanRoot }
	)
	$missing = @()
	foreach ($entry in $roots) {
		$init = Get-Text (Join-Path $entry.Root "initJIPCompatible.sqf")
		$client = Get-Text (Join-Path $entry.Root "Client\Init\Init_Client.sqf")
		$hc = Get-Text (Join-Path $entry.Root "Headless\Init\Init_HC.sqf")
		if (-not $init.Contains('diag_log "initJIPCompatible.sqf: Detected an headless client."')) { $missing += "$($entry.Terrain):hc-detected" }
		if (-not $init.Contains('diag_log "initJIPCompatible.sqf: Executing the Client Initialization."')) { $missing += "$($entry.Terrain):client-init-bridge" }
		if (-not $client.Contains('diag_log format ["Init_Client.sqf: Client initialization begins')) { $missing += "$($entry.Terrain):client-init-start" }
		if (-not $hc.Contains('diag_log "Init_HC.sqf: Running the headless client initialization."')) { $missing += "$($entry.Terrain):hc-init-start" }
	}
	Add-Result "Release role-proof diag_log emitters" ($missing.Count -eq 0) "missing=$($missing -join ',')"
}

function Test-ReleaseRuntimeProofTokenEmitters {
	$takistanRoot = Join-Path $sourceRepoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$roots = @(
		[pscustomobject]@{ Terrain = "chernarus"; Root = $missionRoot },
		[pscustomobject]@{ Terrain = "takistan"; Root = $takistanRoot }
	)
	$tokens = @(
		[pscustomobject]@{ Name = "aicom-heartbeat"; Needle = "AICOMHB|v2|" },
		[pscustomobject]@{ Name = "aicom-tick"; Needle = "AICOMSTAT|v1|TICK|" },
		[pscustomobject]@{ Name = "aicom-event"; Needle = "AICOMSTAT|v2|EVENT|" },
		[pscustomobject]@{ Name = "aicom-team-founded-hc"; Needle = "TEAM_FOUNDED|via=HC" },
		[pscustomobject]@{ Name = "aicom-front"; Needle = "AICOMSTAT|v1|FRONT|" },
		[pscustomobject]@{ Name = "aicom-posture"; Needle = "AICOMSTAT|v1|POSTURE|" },
		[pscustomobject]@{ Name = "aicom-snapshot"; Needle = "AICOM2|v1|SNAP|" },
		[pscustomobject]@{ Name = "aicom-ai-command-order"; Needle = "AICOM2|v1|ORDER|aicom-ai-command" },
		[pscustomobject]@{ Name = "aicom-arty-request"; Needle = "AICOM2|v1|ARTYREQ" },
		[pscustomobject]@{ Name = "aicom-fallback-source"; Needle = "AICOMGATE|%1|infFallback" },
		[pscustomobject]@{ Name = "aicom-jip-request-status"; Needle = "aiStatus=%4" },
		[pscustomobject]@{ Name = "aicom-hc-reconnect-audit"; Needle = "HCRECON_AICOM_AUDIT" },
		[pscustomobject]@{ Name = "aicom-hc-drop-audit"; Needle = "HCDROP_AICOM_AUDIT" },
		[pscustomobject]@{ Name = "aicom-active"; Needle = "AI commander ACTIVE" },
		[pscustomobject]@{ Name = "aicom-assist"; Needle = "AI commander ASSIST" },
		[pscustomobject]@{ Name = "cmdrstat"; Needle = "CMDRSTAT|v1" },
		[pscustomobject]@{ Name = "srvperf"; Needle = "SRVPERF|v1" },
		[pscustomobject]@{ Name = "grpbudget"; Needle = "GRPBUDGET|v1" },
		[pscustomobject]@{ Name = "hc-connect"; Needle = "HCSIDE|v1|connect|" },
		[pscustomobject]@{ Name = "hc-stat"; Needle = "HCSTAT|v1" },
		[pscustomobject]@{ Name = "hc-deleg"; Needle = "HCDELEG|v1" },
		[pscustomobject]@{ Name = "deleg-stat"; Needle = "DELEGSTAT|v1" },
		[pscustomobject]@{ Name = "town-ai-hc-cleanup"; Needle = "TOWN_AI_HC_CLEANUP" },
		[pscustomobject]@{ Name = "gcstat"; Needle = "GCSTAT|v1" },
		[pscustomobject]@{ Name = "emptygrp"; Needle = "EMPTYGRP|v1" },
		[pscustomobject]@{ Name = "client-empty-group-cleanup"; Needle = "CLIENT_EMPTY_GROUP_CLEANUP|v1" },
		[pscustomobject]@{ Name = "arty-threat"; Needle = "ARTY_THREAT_ARMED" },
		[pscustomobject]@{ Name = "fire-mission"; Needle = "FIRE_MISSION" },
		[pscustomobject]@{ Name = "supply-loaded"; Needle = "SupplyMissionStart.sqf: Player" },
		[pscustomobject]@{ Name = "supply-unload"; Needle = "SupplyMissionUnload.sqf: Player" },
		[pscustomobject]@{ Name = "supply-completed"; Needle = "SupplyMissionCompleted.sqf: Completion accepted" },
		[pscustomobject]@{ Name = "supply-interdiction"; Needle = "Logistics interdiction" }
	)
	$missing = @()
	foreach ($entry in $roots) {
		$builder = New-Object System.Text.StringBuilder
		$files = Get-ChildItem -LiteralPath $entry.Root -Recurse -File -ErrorAction SilentlyContinue |
			Where-Object { $_.Extension -in @(".sqf",".fsm",".ext",".hpp") }
		foreach ($file in $files) {
			[void]$builder.AppendLine([System.IO.File]::ReadAllText($file.FullName))
		}
		$text = $builder.ToString()
		foreach ($token in $tokens) {
			if (-not $text.Contains($token.Needle)) { $missing += "$($entry.Terrain):$($token.Name)" }
		}
	}
	Add-Result "Release runtime-proof token emitters" ($missing.Count -eq 0) "missing=$($missing -join ',')"
}

function Test-ActiveStressMissionCopy {
	if (!(Test-Path -LiteralPath $ActiveMissionRoot)) {
		Add-Result "Active stress mission copy" $true "Skipped: active mission root not present at $ActiveMissionRoot"
		return
	}

	$init = Get-Text (Join-Path $ActiveMissionRoot "init.sqf")
	$mission = Get-Text (Join-Path $ActiveMissionRoot "mission.sqm")
	$version = Get-Text (Join-Path $ActiveMissionRoot "version.sqf")
	$harness = Join-Path $ActiveMissionRoot "test\wasp_pr8_stress_mission.sqf"
	$client = Join-Path $ActiveMissionRoot "test\wasp_pr8_stress_client.sqf"
	$action = Join-Path $ActiveMissionRoot "test\wasp_pr8_stress_client_action.sqf"
	$selftest = Join-Path $ActiveMissionRoot "test\wasp_selftest.sqf"
	$hasHarness = Test-Path -LiteralPath $harness
	$hasClient = (Test-Path -LiteralPath $client) -and (Test-Path -LiteralPath $action)
	$hasSelftest = (-not $init.Contains('[] execVM "test\wasp_selftest.sqf"')) -or (Test-Path -LiteralPath $selftest)
	$launches = $init.Contains("WASP_PR8_STRESS_ENABLED = true") -and $init.Contains('[] execVM "test\wasp_pr8_stress_mission.sqf"') -and $init.Contains('[] execVM "test\wasp_pr8_stress_client.sqf"') -and $hasSelftest
	$timed = $init.Contains("WASP_PR8_STRESS_PROFILE") -and $init.Contains("WASP_PR8_STRESS_PHASE_DELAY") -and $init.Contains("WASP_PR8_STRESS_REINFORCEMENT_INTERVAL") -and $init.Contains("WASP_PR8_STRESS_TRIGGER_DIRECT_ACTIONS = true") -and $init.Contains("WASP_PR8_STRESS_TOWN_LIFECYCLE_ENABLED = true") -and $init.Contains("WASP_PR8_STRESS_TOWN_RESTORE = true") -and $init.Contains("WASP_PR8_STRESS_REQUIRE_HC = true")
	$picker = $mission.Contains('briefingName="TEST PR8 Stress') -and $mission.Contains("Auto-starts WASP-PR8-STRESS")
	$name = $version.Contains('#define WF_MISSIONNAME "TEST PR8 Stress')
	Add-Result "Active stress mission copy" ($hasHarness -and $hasClient -and $launches -and $timed -and $picker -and $name) "harness=$hasHarness client=$hasClient selftest=$hasSelftest launches=$launches timed=$timed picker=$picker name=$name root=$ActiveMissionRoot"
}

#=== June 2026 finalize checks (added for the post-bundle final run) ===
function Test-MashRemoved {
	$params = Get-Text (Join-Path $missionRoot "Rsc\Parameters.hpp")
	$consts = Get-Text (Join-Path $missionRoot "Common\Init\Init_CommonConstants.sqf")
	$respawn = Get-Text (Join-Path $missionRoot "Client\Functions\Client_GetRespawnAvailable.sqf")
	$officerGone = -not (Test-Path -LiteralPath (Join-Path $missionRoot "Client\Module\Skill\Skill_Officer.sqf"))
	$markerGone = -not (Test-Path -LiteralPath (Join-Path $missionRoot "Server\Module\MASH\MASHMarker.sqf"))
	$paramGone = -not $params.Contains("WFBE_C_RESPAWN_MASH")
	$defaultGone = -not $consts.Contains("WFBE_C_RESPAWN_MASH")
	$respawnGone = -not $respawn.Contains("wfbe_mash")
	Add-Result "MASH system removed" ($officerGone -and $markerGone -and $paramGone -and $defaultGone -and $respawnGone) "officerGone=$officerGone markerGone=$markerGone paramGone=$paramGone defaultGone=$defaultGone respawnGone=$respawnGone"
}

function Test-GpsSlotFreed {
	$titles = Get-Text (Join-Path $missionRoot "Rsc\Titles.hpp")
	# Match the actual binding line `name="gps";` (semicolon) so an explanatory comment that mentions
	# name="gps", (comma) does not trip a false negative; also confirm the rename positively.
	$freed = (-not $titles.Contains('name="gps";')) -and $titles.Contains('name="wf_hud_overlay"')
	Add-Result "GPS slot freed (RscOverlay no longer name=gps)" $freed "noGpsBinding=$(-not $titles.Contains('name=""gps"";')) renamed=$($titles.Contains('name=""wf_hud_overlay""'))"
}

function Test-EmptyVehicleRefundFix {
	$build = Get-Text (Join-Path $missionRoot "Client\Functions\Client_BuildUnit.sqf")
	$factoryRefund = $build.Contains("real destroyed-factory path")
	$noEmptyRefund = $build.Contains("NO refund here")
	Add-Result "Empty-vehicle free-buy exploit fixed" ($factoryRefund -and $noEmptyRefund) "factoryDeadRefund=$factoryRefund emptyBranchNoRefund=$noEmptyRefund"
}

function Test-WddmTiers {
	$def = Get-Text (Join-Path $missionRoot "Server\Init\Init_Defenses.sqf")
	$tpls = @("WFBE_NEURODEF_AAPOS_WEST","WFBE_NEURODEF_AAPOS_HEAVY_WEST","WFBE_NEURODEF_ARTYPOS_LIGHT_WEST","WFBE_NEURODEF_ARTYPOS_WEST","WFBE_NEURODEF_MIXEDPOS_WEST","WFBE_NEURODEF_MIXEDPOS_HEAVY_WEST","WFBE_NEURODEF_AAPOS_HEAVY_EAST","WFBE_NEURODEF_ARTYPOS_LIGHT_EAST","WFBE_NEURODEF_MIXEDPOS_HEAVY_EAST")
	$missing = @()
	foreach ($t in $tpls) { if (-not $def.Contains("'$t'")) { $missing += $t } }
	$anchors = $def.Contains("'Land_Ind_BoardsPack1'") -and $def.Contains("'Land_CncBlock_Stripes'") -and $def.Contains("'Land_Barrel_sand'") -and $def.Contains("'Land_Ind_BoardsPack2'") -and $def.Contains("'Land_WoodenRamp'") -and $def.Contains("'RoadCone'") -and $def.Contains("WFBE_POSITION_ANCHOR_NAMES")
	Add-Result "WDDM light/heavy tiers present" (($missing.Count -eq 0) -and $anchors) "missingTemplates=$($missing -join ',') newAnchors=$anchors"
}

function Test-HqWallLeakFix {
	$hqKill = Get-Text (Join-Path $missionRoot "Server\Functions\Server_OnHQKilled.sqf")
	$ok = $hqKill.Contains('getVariable ["wfbe_hq_walls"') -and $hqKill.Contains("deleteVehicle")
	Add-Result "HQ wall leak fixed on destruction" $ok "deletesWalls=$ok"
}

function Test-InterdictionEnemyGuard {
	$supply = Get-Text (Join-Path $missionRoot "Server\Module\supplyMission\supplyMissionStarted.sqf")
	$ok = $supply.Contains("(side _veh)") -and $supply.Contains("_killerSide != ")
	Add-Result "Supply interdiction enemy-side guard" $ok "enemyGuard=$ok"
}

function Test-MissionConflictMarkers {
	$sourceRepoRootPath = if ($sourceRepoRoot -is [System.Management.Automation.PathInfo]) { $sourceRepoRoot.Path } else { [string]$sourceRepoRoot }
	$roots = @("Missions", "Missions_Vanilla", "Modded_Missions")
	$existingRoots = @()
	foreach ($root in $roots) {
		if (Test-Path -LiteralPath (Join-Path $sourceRepoRootPath $root)) { $existingRoots += $root }
	}
	$hits = @()
	if ($existingRoots.Count -gt 0) {
		$hits = @(& git -C $sourceRepoRootPath grep -I -n -E '^(<{7}|={7}|>{7})|<{7}|>{7}' -- $existingRoots 2>$null)
		if ($LASTEXITCODE -gt 1) { $hits += "git grep failed with exit $LASTEXITCODE" }
	}
	Add-Result "Mission conflict markers absent" ($hits.Count -eq 0) ($(if ($hits.Count) { $hits -join "; " } else { "No conflict markers in tracked mission roots." }))
}

Test-MissionConflictMarkers
Test-ForbiddenReleaseCommands
Test-HarnessOverlayA3Dialect
Test-HqShield
Test-AARadarHasNoWalls
Test-WddmInstantStaticCrew
Test-WddmAnchorClassValidity
Test-PvfIntegrity
Test-SideSupplyAuthorityGuard
Test-UpgradeRequestAuthorityGuard
Test-AIComDonateAuthorityGuard
Test-AicomCommandConsoleAuthorityGuard
Test-AicomTeamLifecycleAuthorityGuard
Test-AicomHcTopUpDraftExcluded
Test-AicomGroupVariableDefaults
Test-HcPvfGuard
Test-HcDelegatedAiLocalGroups
Test-GuiImageTabGuard
Test-StaleUpgradeDialog
Test-SupplyHeliTimers
Test-ServiceMenuDisplayGuard
Test-WfMenuGpsButton
Test-RhudEconomyFpsLayout
Test-AfkBoolComparisons
Test-HarnessBoolComparisons
Test-DefenseAutoManningDefault
Test-BuyMenuAutoCrewDefault
Test-VehicleBountyAssistType
Test-SkillInitSingleCompile
Test-ParatrooperMarkerRegistration
Test-AiSupplyTruckDisabled
Test-StaleLogGameEndRemoved
Test-ConfirmActionSurfaces
Test-CleanerStartupThrottle
Test-Pr8StressHarness
Test-Pr8StressClientHelper
Test-Pr8StressRptAnalyzer
Test-Pr8LiveWatcher
Test-ShippingMissionsExcludeHarness
Test-ReleaseRoleProofDiagLogEmitters
Test-ReleaseRuntimeProofTokenEmitters
Test-ActiveStressMissionCopy

#--- June 2026 finalize checks
Test-MashRemoved
Test-GpsSlotFreed
Test-EmptyVehicleRefundFix
Test-WddmTiers
Test-HqWallLeakFix
Test-InterdictionEnemyGuard

$failed = @($results | Where-Object { -not $_.Passed })
$results | Format-Table -AutoSize

if ($failed.Count -gt 0) {
	Write-Host ""
	Write-Host "FAILED: $($failed.Count) PR8 static smoke check(s)." -ForegroundColor Red
	exit 1
}

Write-Host ""
Write-Host "PASS: PR8 static smoke checks clean." -ForegroundColor Green
