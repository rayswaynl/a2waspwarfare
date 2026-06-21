$ErrorActionPreference='Stop'
$f='C:\WASP\web\changelog.json'

# --- BACK UP (gotcha-mandated explicit pre-B57 backup, plus the timestamped one) ---
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item -LiteralPath $f -Destination "$f.bak-$stamp" -Force
$preBak="$f.bak-preB57"
Copy-Item -LiteralPath $f -Destination $preBak -Force

# --- READ existing entries via FLATTEN (NEVER @(Get-Content|ConvertFrom-Json): PS5.1 collapses single-element arrays) ---
$o = Get-Content -Raw $f | ConvertFrom-Json
$old=@(); foreach($e in @($o)){ if($e -is [array]){$old+=@($e)} else {$old+=$e} }
$oldCount=@($old).Count

# --- NEW B57 ENTRY ---
$e57=[ordered]@{ build='57'; date='2026-06-20'; title='Bigger AI armies that take ground - join fully fixed, slots by role, map-marker fix'; items=@(
  'Joins fully fixed - the black-screen-on-join is gone. The client startup was stalling before the screen-clear could run; now it always completes.',
  'Much bigger AI squads - infantry teams are brought to full strength (8-12) when they form. They used to be thin 3-6 and never reinforced, and the AI now runs up to 10 teams a side.',
  'AI takes towns and pushes the front - it concentrates force on one spearhead, pulls battered squads back to reform, makes a last stand when cornered, and won''t suicide-rush your HQ when it''s behind. Towns are still hard - the AI just plays better.',
  'Lobby slots grouped by role - medics, engineers, support, riflemen and snipers are grouped together per side, so you pick your slot faster.',
  'Your map marker now points the way you''re actually facing, on foot and in vehicles.',
  'Under the hood: AI economy paced so it earns its tech from towns and convoys instead of snowballing; a randomized HQ start each match; plus more stability and telemetry.'
) }

# --- PREPEND + DEDUPE by build (same shape as publish-b41) ---
$seen=@{}; $all=@()
foreach($e in (@($e57)+@($old))){ if($null -eq $e){continue}; $b=[string]$e.build; if($b -and -not $seen.ContainsKey($b)){$seen[$b]=$true; $all+=$e} }

# --- WRITE (UTF-8 no BOM) ---
$json = $all | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($f,$json,(New-Object Text.UTF8Encoding($false)))

# --- VERIFY via re-read + FLATTEN ---
$chk = Get-Content -Raw $f | ConvertFrom-Json
$cf=@(); foreach($e in @($chk)){ if($e -is [array]){$cf+=@($e)} else {$cf+=$e} }
$newCount=@($cf).Count
$builds=@($cf | ForEach-Object {[string]$_.build})
$have49 = $builds -contains '49'
$have48 = $builds -contains '48'
$have47 = $builds -contains '47'
$have46 = $builds -contains '46'
$have57 = $builds -contains '57'

$ok = ($newCount -eq ($oldCount + 1)) -and $have57 -and $have49 -and $have48 -and $have47 -and $have46

if(-not $ok){
  Copy-Item -LiteralPath $preBak -Destination $f -Force
  "FAILURE: restored backup. old=$oldCount new=$newCount have57=$have57 49=$have49 48=$have48 47=$have47 46=$have46"
  exit 1
}

"PUBLISHED B57 OK: old=$oldCount new=$newCount (expected $($oldCount+1)); 49/48/47/46 present = $have49/$have48/$have47/$have46"
"TOP10: " + ((@($cf) | Select-Object -First 10 | ForEach-Object {[string]$_.build}) -join ', ')
