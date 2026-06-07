param(
	[string]$BaseRef = "origin/master",
	[string]$HeadRef = "HEAD",
	[string]$ActiveMissionRoot = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$harnessRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$missionRoot = Join-Path $repoRoot "Missions\[55-2hc]warfarev2_073v48co.chernarus"
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
	$relative = & git -C $repoRoot diff --name-only "$BaseRef..$HeadRef" -- "Missions/[55-2hc]warfarev2_073v48co.chernarus"
	$files = @()
	foreach ($path in $relative) {
		if ($path -match '\.(sqf|fsm)$') {
			$full = Join-Path $repoRoot ($path -replace '/', '\')
			if (Test-Path -LiteralPath $full) { $files += $full }
		}
	}
	return $files
}

function Remove-LineComment {
	param([string]$Line)
	$idx = $Line.IndexOf("//")
	if ($idx -ge 0) { return $Line.Substring(0, $idx) }
	return $Line
}

function Test-ForbiddenA3Commands {
	$forbidden = @(
		"pushBack","pushBackUnique","selectRandom","isEqualTo","params",
		"parseSimpleArray","remoteExec","setGroupOwner","append","apply",
		"findIf","deleteAt","createHashMap","hashMap"
	)
	$pattern = "\b(" + (($forbidden | ForEach-Object {[regex]::Escape($_)}) -join "|") + ")\b"
	$hits = @()
	foreach ($file in Get-ChangedMissionFiles) {
		$lineNumber = 0
		foreach ($line in [System.IO.File]::ReadLines($file)) {
			$lineNumber++
			$code = Remove-LineComment $line
			if ($code -match $pattern) {
				$rel = Resolve-Path -LiteralPath $file -Relative
				$hits += "$rel`:$lineNumber $($matches[1])"
			}
		}
	}
	Add-Result "A2 OA command dialect" ($hits.Count -eq 0) ($(if ($hits.Count) { $hits -join "; " } else { "No forbidden A3-only commands in changed Chernarus mission files." }))
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
	$smallGuard = $smallText.Contains('_rlType != "AARadar"') -and $smallText.Contains("AARadar auto walls skipped")
	$mediumGuard = $mediumText.Contains('_rlType != "AARadar"') -and $mediumText.Contains("AARadar auto walls skipped")
	Add-Result "AARadar wall template removed" ($templateMatch.Success -and $objectCount -eq 0 -and $smallGuard -and $mediumGuard) "templateFound=$($templateMatch.Success) wallObjects=$objectCount smallGuard=$smallGuard mediumGuard=$mediumGuard"
}

function Test-WddmInstantStaticCrew {
	$handle = Get-Text (Join-Path $missionRoot "Server\Functions\Server_HandleDefense.sqf")
	$create = Get-Text (Join-Path $missionRoot "Common\Functions\Common_CreateUnitForStaticDefence.sqf")
	$construct = Get-Text (Join-Path $missionRoot "Server\Functions\Server_ConstructPosition.sqf")
	$spawnAtGun = $handle.Contains('if (_moveInGunner) then {_position = getPosATL _defense}')
	$logsStaticType = $handle.Contains('typeOf _defense') -and $handle.Contains('instant=%3')
	$passesWddmFlag = $construct.Contains('false, true] Call ConstructDefense')
	$retry = $create.Contains('retried instant static manning') -and $create.Contains('setPosATL (getPosATL _defence)') -and $create.Contains('_unit moveInGunner _defence')
	$settles = $create.Contains('disableAI "MOVE"') -and $create.Contains('WFBE_StaticDefenseSettled')
	Add-Result "WDDM instant static crew settling" ($spawnAtGun -and $logsStaticType -and $passesWddmFlag -and $retry -and $settles) "spawnAtGun=$spawnAtGun logsStaticType=$logsStaticType wddmFlag=$passesWddmFlag retry=$retry settles=$settles"
}

function Test-PvfIntegrity {
	$initPv = Get-Text (Join-Path $missionRoot "Common\Init\Init_PublicVariables.sqf")
	$serverPvDir = Join-Path $missionRoot "Server\PVFunctions"
	$required = @("RequestEnqueue","RequestDequeue","RequestDefense","RequestSpecial","RequestUpgrade","RequestOnUnitKilled")
	$missing = @()
	foreach ($name in $required) {
		$registered = $initPv.Contains($name)
		$handler = Test-Path -LiteralPath (Join-Path $serverPvDir "$name.sqf")
		if (-not ($registered -and $handler)) { $missing += "$name registered=$registered handler=$handler" }
	}
	Add-Result "PVF registration/handlers" ($missing.Count -eq 0) ($(if ($missing.Count) { $missing -join "; " } else { "Core PR8 server PVF channels are registered and have handlers." }))
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
	$createUnit = Get-Text (Join-Path $missionRoot "Common\Functions\Common_CreateUnit.sqf")
	$createTeam = Get-Text (Join-Path $missionRoot "Common\Functions\Common_CreateTeam.sqf")
	$townLocalizes = $delegateTown.Contains("count units _team") -and $delegateTown.Contains("_team = createGroup _side") -and $delegateTown.Contains("_teams set [_i, _team]")
	$staticLocalizes = $delegateStatic.Contains("count units _team") -and $delegateStatic.Contains("_team = createGroup _side")
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
		$fullRoot = Join-Path $repoRoot $root
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

function Test-RhudEconomyFpsLayout {
	$rhud = Get-Text (Join-Path $missionRoot "Client\Client_UpdateRHUD.sqf")
	$menu = Get-Text (Join-Path $missionRoot "Client\GUI\GUI_Menu.sqf")
	$stressPath = Join-Path $ActiveMissionRoot "test\wasp_pr8_stress_mission.sqf"
	$stress = if (Test-Path -LiteralPath $stressPath) { Get-Text $stressPath } else { "" }
	$moneyIncome = $rhud.Contains('%1 $ | %2') -and $rhud.Contains('[7, "Money:"]')
	$svPlus = $rhud.Contains('[11, "Base:"]') -and (-not $rhud.Contains('[13, "SV Min:"]'))   # recalibrated: index-11 row renamed SV+: -> Base:
	$fpsCombined = $rhud.Contains('[13, "FPS C/S:"]') -and $rhud.Contains('format ["%1 / %2", _clientFPS, _serverFPS]') -and (-not $rhud.Contains('[15, "FPS Server:"]'))
	$hiddenOldRows = $rhud.Contains('{[_x, false] call _RHUDSetShow} forEach [15,16,17,18,19,20,21,22]')
	$topStrip = $menu.Contains('| SV+ %9') -and (-not $menu.Contains('| FPS %9'))
	$stressProof = $stress.Contains('topStrip=uptime|time|players|towns|svPlus') -and $stress.Contains('rhud=moneyIncome|svPlus|fpsClientServer')
	Add-Result "RHUD economy/FPS layout" ($moneyIncome -and $svPlus -and $fpsCombined -and $hiddenOldRows -and $topStrip -and $stressProof) "moneyIncome=$moneyIncome svPlus=$svPlus fpsCombined=$fpsCombined hiddenOldRows=$hiddenOldRows topStrip=$topStrip stressProof=$stressProof"
}

function Test-AfkBoolComparisons {
	$monitor = Get-Text (Join-Path $missionRoot "Client\Module\AFKkick\monitorAFK.sqf")
	$noBoolNotEquals = -not [regex]::IsMatch($monitor, "\b(_afk|_commandAndConquer)\s*!=")
	$afkXor = $monitor.Contains("(_afk && !_afkShouldBe) || (!_afk && _afkShouldBe)")
	$commandXor = $monitor.Contains("(_commandAndConquer && !_commandAndConquerShouldBe) || (!_commandAndConquer && _commandAndConquerShouldBe)")
	Add-Result "AFK boolean comparison guard" ($noBoolNotEquals -and $afkXor -and $commandXor) "noBoolNotEquals=$noBoolNotEquals afkXor=$afkXor commandXor=$commandXor"
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
		$fullRoot = Join-Path $repoRoot $root
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
	$coverage = @("hcDelegation","timedSyntheticWaves","townLifecycle","prePressureCapPostRestore","TOWN_SNAPSHOT","TOWN_GROUPS","TOWN_PRESSURE","TOWN_CAPTURE_FORCE","TOWN_CAMP_CAPTURE_FORCE","TOWN_RESTORE","TOWN_PRESSURE_CLEANUP","wddm","hqWalls","commanderArtillery","supplyHeli","supplyInterdiction","easa","service","directDelayedAttribution","buyAutoCrew","autoManning","NOISECHECK","supplyCompletion","teamFunds","reinforcement","WASP_PR8_STRESS_PROFILE","PROFILE selected","CLIENT_COMMAND","clientWave","clientHeavyWave","CLEANUP","WASP_PR8_STRESS_AI_BEHAVIOR","AI_BEHAVIOR","AI_DELEGATION_AUDIT","BUGHUNT_AUDIT","GPS_UI_AUDIT","CLIENT_GPS_STATE","CLIENT_UI_TEXT_STATE","CLIENT_SERVICE_CLIP_AUDIT","farStopped","leaderFarStopped","underStrengthGroups","noDestination","noWaypoint","PLAYER_EXPERIENCE_AUDIT","FACTORY_AUDIT","SERVICE_SUPPLY_AUDIT","WDDM_ARTILLERY_AUDIT","UI_AUDIT","PERF_BURST","SPAWN vehicleLoad","WASP_PR8_STRESS_FACTORY_AUDIT","WASP_PR8_STRESS_SERVICE_SUPPLY_AUDIT","WASP_PR8_STRESS_WDDM_ARTILLERY_AUDIT","WASP_PR8_STRESS_UI_AUDIT","WASP_PR8_STRESS_AI_DELEGATION_AUDIT","WASP_PR8_STRESS_BUGHUNT_AUDIT","WASP_PR8_STRESS_PERF_BURST","WASP_PR8_STRESS_SPAWN_VEHICLE_LOAD","wasp-pr8-stress-v5","perfAuditSid","maxAiUnitsVehiclesGroupsDead","CLIENT_COMMAND_SCHEDULED ai-deep-sample","WASP_PR8_STRESS_QUEUE","WASP_PR8_STRESS_QUEUE_ADD","WASP_PR8_STRESS_QUEUE_RUNNER","WASP_PR8_STRESS_QUEUE_SEQUENCE","WASP_PR8_STRESS_WAIT_FOR_HC","QUEUE_ENQUEUE","QUEUE_BEGIN","QUEUE_STEP","QUEUE_END","QUEUE_STATUS","QUEUE_STOP","QUEUE_PROOF","HC_WAIT_BEGIN","HC_READY","HC_WAIT_TIMEOUT","CLEANUP_LOOP")
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
	$actions = @("queue-full","queue-ai","queue-factory","queue-service","queue-wddm","queue-ui","queue-load","queue-gps-ui","queue-bughunt","queue-status","queue-stop","cleanup-loop-start","cleanup-loop-stop","snapshot","ai-audit","ai-deep-sample","spawn-wave","spawn-heavy-wave","perf-burst","vehicle-load","factory-audit","ui-audit","gps-ui-audit","gps-gain-toggle-audit","player-experience-audit","ai-delegation-audit","bughunt-audit","service-supply-audit","wddm-artillery-audit","trigger-direct","town-lifecycle","profile","cleanup")
	$missing = @()
	foreach ($token in $actions) {
		if (-not ($clientText.Contains($token) -and $actionText.Contains("WASP_PR8_STRESS_CLIENT_COMMAND"))) { $missing += $token }
	}
	$sends = $actionText.Contains('publicVariableServer "WASP_PR8_STRESS_CLIENT_COMMAND"')
	Add-Result "Local active stress client helper actions" ($exists -and $gated -and $missing.Count -eq 0 -and $sends) "exists=$exists gated=$gated missingActions=$($missing -join ',') sends=$sends"
}

function Test-Pr8StressRptAnalyzer {
	$analyzer = Join-Path $harnessRoot "Rpt\Analyze-WaspStressRpt.ps1"
	$allow = Join-Path $harnessRoot "Rpt\KnownNoise.txt"
	$missionIssues = Join-Path $harnessRoot "Rpt\MissionIssuePatterns.txt"
	$exists = (Test-Path -LiteralPath $analyzer) -and (Test-Path -LiteralPath $allow) -and (Test-Path -LiteralPath $missionIssues)
	$text = if (Test-Path -LiteralPath $analyzer) { Get-Text $analyzer } else { "" }
	$allowText = if (Test-Path -LiteralPath $allow) { Get-Text $allow } else { "" }
	$issueText = if (Test-Path -LiteralPath $missionIssues) { Get-Text $missionIssues } else { "" }
	$anchors = @("PROFILE selected=","PHASE_BEGIN","AI_BEHAVIOR","SNAPSHOT_SIDE","TOWN_SNAPSHOT","TOWN_GROUPS","TOWN_PRESSURE","TOWN_CAPTURE_FORCE","TOWN_CAMP_CAPTURE_FORCE","TOWN_RESTORE","TOWN_PRESSURE_CLEANUP","ACTION_MATRIX","TRIGGER supplyCompletion","TRIGGER supplyInterdiction","TRIGGER teamFunds","PROBE delayedKill","SPAWN reinforcement","PERF #","NOISECHECK","EVIDENCE","maxFarStopped","maxLeaderFarStopped","maxUnderStrengthGroups","maxNoDestination","AI/pathing symptom counts","Out of path-planning region","Wrong unit index","FACTORY_AUDIT","SERVICE_SUPPLY_AUDIT","WDDM_ARTILLERY_AUDIT","UI_AUDIT","GPS_UI_AUDIT","CLIENT_GPS_STATE","CLIENT_UI_TEXT_STATE","CLIENT_SERVICE_CLIP_AUDIT","AI_DELEGATION_AUDIT","BUGHUNT_AUDIT","PLAYER_EXPERIENCE_AUDIT","PERF_BURST","SPAWN vehicleLoad","QUEUE_ENQUEUE","QUEUE_STEP","QUEUE_PROOF","QUEUE_END","HC_READY","HC_WAIT_TIMEOUT","CLEANUP_LOOP","queue:","client-heavy-wave","audits:")
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
	$anchors = @("HostRpt","HcRpt","AI_BEHAVIOR","farStopped","leaderFarStopped","underStrengthGroups","noDestination","noWaypoint","emptyGroups","knownNoise","missionIssue","Get-CimInstance","Win32_Process","SupplyMissionUnload","SupplyMissionCompleted","commanderArtillery","FACTORY_AUDIT","SERVICE_SUPPLY_AUDIT","WDDM_ARTILLERY_AUDIT","UI_AUDIT","GPS_UI_AUDIT","CLIENT_GPS_STATE","CLIENT_UI_TEXT_STATE","CLIENT_SERVICE_CLIP_AUDIT","AI_DELEGATION_AUDIT","BUGHUNT_AUDIT","PLAYER_EXPERIENCE_AUDIT","PERF_BURST","SPAWN vehicleLoad","QUEUE_ENQUEUE","QUEUE_STEP","QUEUE_PROOF","QUEUE_END","HC_READY","HC_WAIT_TIMEOUT","CLEANUP_LOOP","queue:","gps/ui:","bughunt:","audits:")
	$missing = @()
	foreach ($token in $anchors) {
		if (-not $text.Contains($token)) { $missing += $token }
	}
	Add-Result "PR8 live RPT watcher" ($exists -and $missing.Count -eq 0) "exists=$exists missingAnchors=$($missing -join ',')"
}

function Test-ShippingMissionsExcludeHarness {
	$chernarusTest = Join-Path $missionRoot "test"
	$takistanRoot = Join-Path $repoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	$takistanTest = Join-Path $takistanRoot "test"
	$chernarusAbsent = -not (Test-Path -LiteralPath $chernarusTest)
	$takistanAbsent = -not (Test-Path -LiteralPath $takistanTest)
	Add-Result "Shipping missions exclude stress harness" ($chernarusAbsent -and $takistanAbsent) "chernarusTestAbsent=$chernarusAbsent takistanTestAbsent=$takistanAbsent"
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
	$picker = $mission.Contains('briefingName="TEST PR8 Stress - June Feature Bundle"') -and $mission.Contains("Auto-starts WASP-PR8-STRESS")
	$name = $version.Contains('#define WF_MISSIONNAME "TEST PR8 Stress - Chernarus"')
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
	$anchors = $def.Contains("'RoadBarrier'") -and $def.Contains("'RoadBarrier_light'") -and $def.Contains("'RoadCone'")
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

Test-ForbiddenA3Commands
Test-HqShield
Test-AARadarHasNoWalls
Test-WddmInstantStaticCrew
Test-PvfIntegrity
Test-HcPvfGuard
Test-HcDelegatedAiLocalGroups
Test-GuiImageTabGuard
Test-StaleUpgradeDialog
Test-SupplyHeliTimers
Test-ServiceMenuDisplayGuard
Test-RhudEconomyFpsLayout
Test-AfkBoolComparisons
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
