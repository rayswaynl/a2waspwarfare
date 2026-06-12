Private ["_ammo","_easaDefault","_easaLoadout","_easaVehi","_is_AAMissile","_loadout","_loadout_line","_vehicle"];
EASA_Equip = Compile preprocessFileLineNumbers 'Client\Module\EASA\EASA_Equip.sqf';EASA_RemoveLoadout = Compile preprocessFileLineNumbers 'Client\Module\EASA\EASA_RemoveLoadout.sqf';

_easaDefault = [];
_easaLoadout = [];
_easaVehi = [];

/* [[Price], [Description], [Weapon, Ammos], [Weapon, Ammos]...] */

// Su-34 [AF5] - 10 pylons
_easaVehi = _easaVehi + ['Su34'];
_easaDefault = _easaDefault + [[['Ch29Launcher_Su34','R73Launcher_2'],['6Rnd_Ch29','2Rnd_R73','2Rnd_R73']]];
_easaLoadout = _easaLoadout + [
[
[16400,'FAB-250 (6) | GBU-12 (2) | Kh-29 (4) | R-73 (2)',[['AirBombLauncher','BombLauncherF35','Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','4Rnd_Ch29','2Rnd_R73']]],
[21000,'FAB-250 (6) | GBU-12 (2) | Kh-29 (4) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','Ch29Launcher_Su34','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','4Rnd_Ch29','40Rnd_S8T']]],
[15200,'FAB-250 (6) | GBU-12 (2) | Kh-29 (6)',[['AirBombLauncher','BombLauncherF35','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','6Rnd_Ch29']]],
[26000,'FAB-250 (6) | GBU-12 (2) | R-73 (2) | S-8 (80)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[21400,'FAB-250 (6) | GBU-12 (2) | R-73 (4) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[15800,'FAB-250 (6) | GBU-12 (2) | R-73 (6)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','2Rnd_R73','2Rnd_R73']]],
[29600,'FAB-250 (6) | GBU-12 (2) | S-8 (120)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[22000,'FAB-250 (6) | GBU-12 (4) | Kh-29 (4)',[['AirBombLauncher','BombLauncherF35','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','4Rnd_Ch29']]],
[28000,'FAB-250 (6) | GBU-12 (4) | R-73 (2) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T']]],
[22400,'FAB-250 (6) | GBU-12 (4) | R-73 (4)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','2Rnd_R73']]],
[31600,'FAB-250 (6) | GBU-12 (4) | S-8 (80)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T']]],
[29000,'FAB-250 (6) | GBU-12 (6) | R-73 (2)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73']]],
[33600,'FAB-250 (6) | GBU-12 (6) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T']]],
[34600,'FAB-250 (6) | GBU-12 (8)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[14400,'FAB-250 (6) | Kh-29 (4) | R-73 (2) | S-8 (40)',[['AirBombLauncher','Ch29Launcher_Su34','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','2Rnd_R73','40Rnd_S8T']]],
[8800,'FAB-250 (6) | Kh-29 (4) | R-73 (4)',[['AirBombLauncher','Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','2Rnd_R73','2Rnd_R73']]],
[18000,'FAB-250 (6) | Kh-29 (4) | S-8 (80)',[['AirBombLauncher','Ch29Launcher_Su34','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','40Rnd_S8T','40Rnd_S8T']]],
[8600,'FAB-250 (6) | Kh-29 (6) | R-73 (2)',[['AirBombLauncher','Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','6Rnd_Ch29','2Rnd_R73']]],
[13200,'FAB-250 (6) | Kh-29 (6) | S-8 (40)',[['AirBombLauncher','Ch29Launcher_Su34','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','6Rnd_Ch29','40Rnd_S8T']]],
[7400,'FAB-250 (6) | Kh-29 (8)',[['AirBombLauncher','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','4Rnd_Ch29']]],
[23000,'FAB-250 (6) | R-73 (2) | S-8 (120)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[18400,'FAB-250 (6) | R-73 (4) | S-8 (80)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[13800,'FAB-250 (6) | R-73 (6) | S-8 (40)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[8200,'FAB-250 (6) | R-73 (8)',[['AirBombLauncher','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','2Rnd_R73','2Rnd_R73','2Rnd_R73']]],
[14600,'FAB-250 (12) | GBU-12 (2) | Kh-29 (4)',[['AirBombLauncher','BombLauncherF35','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','4Rnd_Ch29']]],
[20600,'FAB-250 (12) | GBU-12 (2) | R-73 (2) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T']]],
[15000,'FAB-250 (12) | GBU-12 (2) | R-73 (4)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','2Rnd_R73']]],
[24200,'FAB-250 (12) | GBU-12 (2) | S-8 (80)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T']]],
[21600,'FAB-250 (12) | GBU-12 (4) | R-73 (2)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73']]],
[26200,'FAB-250 (12) | GBU-12 (4) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T']]],
[27200,'FAB-250 (12) | GBU-12 (6)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[8000,'FAB-250 (12) | Kh-29 (4) | R-73 (2)',[['AirBombLauncher','Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','2Rnd_R73']]],
[12600,'FAB-250 (12) | Kh-29 (4) | S-8 (40)',[['AirBombLauncher','Ch29Launcher_Su34','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','40Rnd_S8T']]],
[6800,'FAB-250 (12) | Kh-29 (6)',[['AirBombLauncher','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','6Rnd_Ch29']]],
[17600,'FAB-250 (12) | R-73 (2) | S-8 (80)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[13000,'FAB-250 (12) | R-73 (4) | S-8 (40)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[7400,'FAB-250 (12) | R-73 (6)',[['AirBombLauncher','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','2Rnd_R73','2Rnd_R73']]],
[21200,'FAB-250 (12) | S-8 (120)',[['AirBombLauncher','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[14200,'FAB-250 (18) | GBU-12 (2) | R-73 (2)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73']]],
[18800,'FAB-250 (18) | GBU-12 (2) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','40Rnd_S8T']]],
[19800,'FAB-250 (18) | GBU-12 (4)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12']]],
[6200,'FAB-250 (18) | Kh-29 (4)',[['AirBombLauncher','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29']]],
[12200,'FAB-250 (18) | R-73 (2) | S-8 (40)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','40Rnd_S8T']]],
[6600,'FAB-250 (18) | R-73 (4)',[['AirBombLauncher','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','2Rnd_R73']]],
[15800,'FAB-250 (18) | S-8 (80)',[['AirBombLauncher','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','40Rnd_S8T']]],
[12400,'FAB-250 (24) | GBU-12 (2)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12']]],
[5800,'FAB-250 (24) | R-73 (2)',[['AirBombLauncher','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73']]],
[10400,'FAB-250 (24) | S-8 (40)',[['AirBombLauncher','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T']]],
[4000,'FAB-250 (30)',[['AirBombLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250']]],
[21800,'GBU-12 (2) | Kh-29 (4) | R-73 (2) | S-8 (40)',[['BombLauncherF35','Ch29Launcher_Su34','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','4Rnd_Ch29','2Rnd_R73','40Rnd_S8T']]],
[16200,'GBU-12 (2) | Kh-29 (4) | R-73 (4)',[['BombLauncherF35','Ch29Launcher_Su34','R73Launcher_2'],['2Rnd_GBU12','4Rnd_Ch29','2Rnd_R73','2Rnd_R73']]],
[25400,'GBU-12 (2) | Kh-29 (4) | S-8 (80)',[['BombLauncherF35','Ch29Launcher_Su34','S8Launcher'],['2Rnd_GBU12','4Rnd_Ch29','40Rnd_S8T','40Rnd_S8T']]],
[16000,'GBU-12 (2) | Kh-29 (6) | R-73 (2)',[['BombLauncherF35','Ch29Launcher_Su34','R73Launcher_2'],['2Rnd_GBU12','6Rnd_Ch29','2Rnd_R73']]],
[20600,'GBU-12 (2) | Kh-29 (6) | S-8 (40)',[['BombLauncherF35','Ch29Launcher_Su34','S8Launcher'],['2Rnd_GBU12','6Rnd_Ch29','40Rnd_S8T']]],
[14800,'GBU-12 (2) | Kh-29 (8)',[['BombLauncherF35','Ch29Launcher_Su34'],['2Rnd_GBU12','4Rnd_Ch29','4Rnd_Ch29']]],
[30400,'GBU-12 (2) | R-73 (2) | S-8 (120)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_R73','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[25800,'GBU-12 (2) | R-73 (4) | S-8 (80)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_R73','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[21200,'GBU-12 (2) | R-73 (6) | S-8 (40)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_R73','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[15600,'GBU-12 (2) | R-73 (8)',[['BombLauncherF35','R73Launcher_2'],['2Rnd_GBU12','2Rnd_R73','2Rnd_R73','2Rnd_R73','2Rnd_R73']]],
[22800,'GBU-12 (4) | Kh-29 (4) | R-73 (2)',[['BombLauncherF35','Ch29Launcher_Su34','R73Launcher_2'],['2Rnd_GBU12','2Rnd_GBU12','4Rnd_Ch29','2Rnd_R73']]],
[27400,'GBU-12 (4) | Kh-29 (4) | S-8 (40)',[['BombLauncherF35','Ch29Launcher_Su34','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','4Rnd_Ch29','40Rnd_S8T']]],
[21600,'GBU-12 (4) | Kh-29 (6)',[['BombLauncherF35','Ch29Launcher_Su34'],['2Rnd_GBU12','2Rnd_GBU12','6Rnd_Ch29']]],
[32400,'GBU-12 (4) | R-73 (2) | S-8 (80)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[27800,'GBU-12 (4) | R-73 (4) | S-8 (40)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[22200,'GBU-12 (4) | R-73 (6)',[['BombLauncherF35','R73Launcher_2'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','2Rnd_R73','2Rnd_R73']]],
[36000,'GBU-12 (4) | S-8 (120)',[['BombLauncherF35','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[28400,'GBU-12 (6) | Kh-29 (4)',[['BombLauncherF35','Ch29Launcher_Su34'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','4Rnd_Ch29']]],
[34400,'GBU-12 (6) | R-73 (2) | S-8 (40)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T']]],
[28800,'GBU-12 (6) | R-73 (4)',[['BombLauncherF35','R73Launcher_2'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','2Rnd_R73']]],
[38000,'GBU-12 (6) | S-8 (80)',[['BombLauncherF35','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T']]],
[35400,'GBU-12 (8) | R-73 (2)',[['BombLauncherF35','R73Launcher_2'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73']]],
[40000,'GBU-12 (8) | S-8 (40)',[['BombLauncherF35','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T']]],
[18800,'Kh-29 (4) | R-73 (2) | S-8 (80)',[['Ch29Launcher_Su34','R73Launcher_2','S8Launcher'],['4Rnd_Ch29','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[14200,'Kh-29 (4) | R-73 (4) | S-8 (40)',[['Ch29Launcher_Su34','R73Launcher_2','S8Launcher'],['4Rnd_Ch29','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[8600,'Kh-29 (4) | R-73 (6)',[['Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_Ch29','2Rnd_R73','2Rnd_R73','2Rnd_R73']]],
[22400,'Kh-29 (4) | S-8 (120)',[['Ch29Launcher_Su34','S8Launcher'],['4Rnd_Ch29','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[14000,'Kh-29 (6) | R-73 (2) | S-8 (40)',[['Ch29Launcher_Su34','R73Launcher_2','S8Launcher'],['6Rnd_Ch29','2Rnd_R73','40Rnd_S8T']]],
[8400,'Kh-29 (6) | R-73 (4)',[['Ch29Launcher_Su34','R73Launcher_2'],['6Rnd_Ch29','2Rnd_R73','2Rnd_R73']]],
[17600,'Kh-29 (6) | S-8 (80)',[['Ch29Launcher_Su34','S8Launcher'],['6Rnd_Ch29','40Rnd_S8T','40Rnd_S8T']]],
[8200,'Kh-29 (8) | R-73 (2)',[['Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_Ch29','4Rnd_Ch29','2Rnd_R73']]],
[12800,'Kh-29 (8) | S-8 (40)',[['Ch29Launcher_Su34','S8Launcher'],['4Rnd_Ch29','4Rnd_Ch29','40Rnd_S8T']]],
[7000,'Kh-29 (10)',[['Ch29Launcher_Su34'],['6Rnd_Ch29','4Rnd_Ch29']]],
[22800,'R-73 (4) | S-8 (120)',[['R73Launcher_2','S8Launcher'],['2Rnd_R73','2Rnd_R73','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[18200,'R-73 (6) | S-8 (80)',[['R73Launcher_2','S8Launcher'],['2Rnd_R73','2Rnd_R73','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[13600,'R-73 (8) | S-8 (40)',[['R73Launcher_2','S8Launcher'],['2Rnd_R73','2Rnd_R73','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[8000,'R-73 (10)',[['R73Launcher_2'],['2Rnd_R73','2Rnd_R73','2Rnd_R73','2Rnd_R73','2Rnd_R73']]]
]
];

// Su-25A [AF3] - 6 pylons
_easaVehi = _easaVehi + ['Su25_Ins'];
_easaDefault = _easaDefault + [[['AirBombLauncher','57mmLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','64Rnd_57mm']]];
_easaLoadout = _easaLoadout + [
[
[6000,'Ataka-V (4) | FAB-250 (6) | Gun rounds (360rnd) (2)',[['AT9Launcher','AirBombLauncher'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','180Rnd_30mm_GSh301','180Rnd_30mm_GSh301']]],
[5200,'Ataka-V (4) | FAB-250 (6) | Igla-V (2)',[['AT9Launcher','AirBombLauncher','Igla_twice'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_Igla']]],
[5800,'Ataka-V (4) | FAB-250 (6) | S-5 (64)',[['AT9Launcher','AirBombLauncher','57mmLauncher'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','64Rnd_57mm']]],
[4400,'Ataka-V (4) | FAB-250 (12)',[['AT9Launcher','AirBombLauncher'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250']]],
[5800,'Ataka-V (4) | Gun rounds (360rnd) (2) | Igla-V (2)',[['AT9Launcher','Igla_twice'],['4Rnd_AT9_Mi24P','180Rnd_30mm_GSh301','180Rnd_30mm_GSh301','2Rnd_Igla']]],
[6400,'Ataka-V (4) | Gun rounds (360rnd) (2) | S-5 (64)',[['AT9Launcher','57mmLauncher'],['4Rnd_AT9_Mi24P','180Rnd_30mm_GSh301','180Rnd_30mm_GSh301','64Rnd_57mm']]],
[5600,'Ataka-V (4) | Igla-V (2) | S-5 (64)',[['AT9Launcher','Igla_twice','57mmLauncher'],['4Rnd_AT9_Mi24P','2Rnd_Igla','64Rnd_57mm']]],
[5200,'Ataka-V (4) | S-5 (128)',[['AT9Launcher','57mmLauncher'],['4Rnd_AT9_Mi24P','64Rnd_57mm','64Rnd_57mm']]],
[5200,'FAB-250 (6) | Gun rounds (360rnd) (2) | Igla-V (2)',[['AirBombLauncher','Igla_twice'],['4Rnd_FAB_250','2Rnd_FAB_250','180Rnd_30mm_GSh301','180Rnd_30mm_GSh301','2Rnd_Igla']]],
[5800,'FAB-250 (6) | Gun rounds (360rnd) (2) | S-5 (64)',[['AirBombLauncher','57mmLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','180Rnd_30mm_GSh301','180Rnd_30mm_GSh301','64Rnd_57mm']]],
[5000,'FAB-250 (6) | Igla-V (2) | S-5 (64)',[['AirBombLauncher','Igla_twice','57mmLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_Igla','64Rnd_57mm']]],
[4600,'FAB-250 (6) | S-5 (128)',[['AirBombLauncher','57mmLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','64Rnd_57mm','64Rnd_57mm']]],
[4400,'FAB-250 (12) | Gun rounds (360rnd) (2)',[['AirBombLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','180Rnd_30mm_GSh301','180Rnd_30mm_GSh301']]],
[3600,'FAB-250 (12) | Igla-V (2)',[['AirBombLauncher','Igla_twice'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_Igla']]],
[4200,'FAB-250 (12) | S-5 (64)',[['AirBombLauncher','57mmLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','64Rnd_57mm']]],
[2800,'FAB-250 (18)',[['AirBombLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250']]],
[5600,'Gun rounds (360rnd) (2) | Igla-V (2) | S-5 (64)',[['Igla_twice','57mmLauncher'],['180Rnd_30mm_GSh301','180Rnd_30mm_GSh301','2Rnd_Igla','64Rnd_57mm']]],
[5200,'Gun rounds (360rnd) (2) | S-5 (128)',[['57mmLauncher'],['180Rnd_30mm_GSh301','180Rnd_30mm_GSh301','64Rnd_57mm','64Rnd_57mm']]],
[4400,'Igla-V (2) | S-5 (128)',[['Igla_twice','57mmLauncher'],['2Rnd_Igla','64Rnd_57mm','64Rnd_57mm']]],
[4000,'S-5 (192)',[['57mmLauncher'],['64Rnd_57mm','64Rnd_57mm','64Rnd_57mm']]]
]
];

// Su-25T [AF4] - 8 pylons
_easaVehi = _easaVehi + ['Su25_TK_EP1'];
_easaDefault = _easaDefault + [[['AT9Launcher','R73Launcher_2','S8Launcher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','2Rnd_R73','40Rnd_S8T']]];
_easaLoadout = _easaLoadout + [
[
[15200,'Ataka-V (4) | FAB-250 (6) | GBU-12 (2) | R-73 (2)',[['AT9Launcher','AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73']]],
[19800,'Ataka-V (4) | FAB-250 (6) | GBU-12 (2) | S-8 (40)',[['AT9Launcher','AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','40Rnd_S8T']]],
[20800,'Ataka-V (4) | FAB-250 (6) | GBU-12 (4)',[['AT9Launcher','AirBombLauncher','BombLauncherF35'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12']]],
[13200,'Ataka-V (4) | FAB-250 (6) | R-73 (2) | S-8 (40)',[['AT9Launcher','AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','40Rnd_S8T']]],
[16800,'Ataka-V (4) | FAB-250 (6) | S-8 (80)',[['AT9Launcher','AirBombLauncher','S8Launcher'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','40Rnd_S8T']]],
[13400,'Ataka-V (4) | FAB-250 (12) | GBU-12 (2)',[['AT9Launcher','AirBombLauncher','BombLauncherF35'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12']]],
[6800,'Ataka-V (4) | FAB-250 (12) | R-73 (2)',[['AT9Launcher','AirBombLauncher','R73Launcher_2'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73']]],
[11400,'Ataka-V (4) | FAB-250 (12) | S-8 (40)',[['AT9Launcher','AirBombLauncher','S8Launcher'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T']]],
[5000,'Ataka-V (4) | FAB-250 (18)',[['AT9Launcher','AirBombLauncher'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250']]],
[20600,'Ataka-V (4) | GBU-12 (2) | R-73 (2) | S-8 (40)',[['AT9Launcher','BombLauncherF35','R73Launcher_2','S8Launcher'],['4Rnd_AT9_Mi24P','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T']]],
[24200,'Ataka-V (4) | GBU-12 (2) | S-8 (80)',[['AT9Launcher','BombLauncherF35','S8Launcher'],['4Rnd_AT9_Mi24P','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T']]],
[21600,'Ataka-V (4) | GBU-12 (4) | R-73 (2)',[['AT9Launcher','BombLauncherF35','R73Launcher_2'],['4Rnd_AT9_Mi24P','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73']]],
[26200,'Ataka-V (4) | GBU-12 (4) | S-8 (40)',[['AT9Launcher','BombLauncherF35','S8Launcher'],['4Rnd_AT9_Mi24P','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T']]],
[27200,'Ataka-V (4) | GBU-12 (6)',[['AT9Launcher','BombLauncherF35'],['4Rnd_AT9_Mi24P','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[17600,'Ataka-V (4) | R-73 (2) | S-8 (80)',[['AT9Launcher','R73Launcher_2','S8Launcher'],['4Rnd_AT9_Mi24P','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[21200,'Ataka-V (4) | S-8 (120)',[['AT9Launcher','S8Launcher'],['4Rnd_AT9_Mi24P','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[14000,'Ataka-V (8) | FAB-250 (6) | GBU-12 (2)',[['AT9Launcher','AirBombLauncher','BombLauncherF35'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12']]],
[7400,'Ataka-V (8) | FAB-250 (6) | R-73 (2)',[['AT9Launcher','AirBombLauncher','R73Launcher_2'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73']]],
[12000,'Ataka-V (8) | FAB-250 (6) | S-8 (40)',[['AT9Launcher','AirBombLauncher','S8Launcher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T']]],
[5600,'Ataka-V (8) | FAB-250 (12)',[['AT9Launcher','AirBombLauncher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250']]],
[14800,'Ataka-V (8) | GBU-12 (2) | R-73 (2)',[['AT9Launcher','BombLauncherF35','R73Launcher_2'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','2Rnd_GBU12','2Rnd_R73']]],
[19400,'Ataka-V (8) | GBU-12 (2) | S-8 (40)',[['AT9Launcher','BombLauncherF35','S8Launcher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','2Rnd_GBU12','40Rnd_S8T']]],
[20400,'Ataka-V (8) | GBU-12 (4)',[['AT9Launcher','BombLauncherF35'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','2Rnd_GBU12','2Rnd_GBU12']]],
[12800,'Ataka-V (8) | R-73 (2) | S-8 (40)',[['AT9Launcher','R73Launcher_2','S8Launcher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','2Rnd_R73','40Rnd_S8T']]],
[16400,'Ataka-V (8) | S-8 (80)',[['AT9Launcher','S8Launcher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','40Rnd_S8T','40Rnd_S8T']]],
[6200,'Ataka-V (12) | FAB-250 (6)',[['AT9Launcher','AirBombLauncher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250']]],
[13600,'Ataka-V (12) | GBU-12 (2)',[['AT9Launcher','BombLauncherF35'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','2Rnd_GBU12']]],
[7000,'Ataka-V (12) | R-73 (2)',[['AT9Launcher','R73Launcher_2'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','2Rnd_R73']]],
[11600,'Ataka-V (12) | S-8 (40)',[['AT9Launcher','S8Launcher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','40Rnd_S8T']]],
[5800,'Ataka-V (16)',[['AT9Launcher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P']]],
[20000,'FAB-250 (6) | GBU-12 (2) | R-73 (2) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T']]],
[23600,'FAB-250 (6) | GBU-12 (2) | S-8 (80)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T']]],
[21000,'FAB-250 (6) | GBU-12 (4) | R-73 (2)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73']]],
[25600,'FAB-250 (6) | GBU-12 (4) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T']]],
[26600,'FAB-250 (6) | GBU-12 (6)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[17000,'FAB-250 (6) | R-73 (2) | S-8 (80)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[20600,'FAB-250 (6) | S-8 (120)',[['AirBombLauncher','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[13600,'FAB-250 (12) | GBU-12 (2) | R-73 (2)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73']]],
[18200,'FAB-250 (12) | GBU-12 (2) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','40Rnd_S8T']]],
[19200,'FAB-250 (12) | GBU-12 (4)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12']]],
[11600,'FAB-250 (12) | R-73 (2) | S-8 (40)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','40Rnd_S8T']]],
[15200,'FAB-250 (12) | S-8 (80)',[['AirBombLauncher','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','40Rnd_S8T']]],
[11800,'FAB-250 (18) | GBU-12 (2)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12']]],
[5200,'FAB-250 (18) | R-73 (2)',[['AirBombLauncher','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73']]],
[9800,'FAB-250 (18) | S-8 (40)',[['AirBombLauncher','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T']]],
[3400,'FAB-250 (24)',[['AirBombLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250']]],
[24400,'GBU-12 (2) | R-73 (2) | S-8 (80)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[28000,'GBU-12 (2) | S-8 (120)',[['BombLauncherF35','S8Launcher'],['2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[26400,'GBU-12 (4) | R-73 (2) | S-8 (40)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T']]],
[30000,'GBU-12 (4) | S-8 (80)',[['BombLauncherF35','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T']]],
[27400,'GBU-12 (6) | R-73 (2)',[['BombLauncherF35','R73Launcher_2'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73']]],
[32000,'GBU-12 (6) | S-8 (40)',[['BombLauncherF35','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T']]],
[21400,'R-73 (2) | S-8 (120)',[['R73Launcher_2','S8Launcher'],['2Rnd_R73','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[25000,'S-8 (160)',[['S8Launcher'],['40Rnd_S8T','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]]
]
];

// Su-39 [AF5] - 10 pylons
_easaVehi = _easaVehi + ['Su39'];
_easaDefault = _easaDefault + [[['R73Launcher_2','S8Launcher','VikhrLauncher'],['2Rnd_R73','40Rnd_S8T','40Rnd_S8T','12Rnd_Vikhr_KA50']]];
_easaLoadout = _easaLoadout + [
[
[16400,'FAB-250 (6) | GBU-12 (2) | Kh-29 (4) | R-73 (2)',[['AirBombLauncher','BombLauncherF35','Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','4Rnd_Ch29','2Rnd_R73']]],
[21000,'FAB-250 (6) | GBU-12 (2) | Kh-29 (4) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','Ch29Launcher_Su34','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','4Rnd_Ch29','40Rnd_S8T']]],
[15200,'FAB-250 (6) | GBU-12 (2) | Kh-29 (6)',[['AirBombLauncher','BombLauncherF35','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','6Rnd_Ch29']]],
[26000,'FAB-250 (6) | GBU-12 (2) | R-73 (2) | S-8 (80)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[14400,'FAB-250 (6) | GBU-12 (2) | R-73 (2) | Vikhr (12)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','12Rnd_Vikhr_KA50']]],
[21400,'FAB-250 (6) | GBU-12 (2) | R-73 (4) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[19000,'FAB-250 (6) | GBU-12 (2) | S-8 (40) | Vikhr (12)',[['AirBombLauncher','BombLauncherF35','S8Launcher','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[29600,'FAB-250 (6) | GBU-12 (2) | S-8 (120)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[22000,'FAB-250 (6) | GBU-12 (4) | Kh-29 (4)',[['AirBombLauncher','BombLauncherF35','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','4Rnd_Ch29']]],
[28000,'FAB-250 (6) | GBU-12 (4) | R-73 (2) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T']]],
[22400,'FAB-250 (6) | GBU-12 (4) | R-73 (4)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','2Rnd_R73']]],
[31600,'FAB-250 (6) | GBU-12 (4) | S-8 (80)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T']]],
[20000,'FAB-250 (6) | GBU-12 (4) | Vikhr (12)',[['AirBombLauncher','BombLauncherF35','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','12Rnd_Vikhr_KA50']]],
[29000,'FAB-250 (6) | GBU-12 (6) | R-73 (2)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73']]],
[33600,'FAB-250 (6) | GBU-12 (6) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T']]],
[34600,'FAB-250 (6) | GBU-12 (8)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[14400,'FAB-250 (6) | Kh-29 (4) | R-73 (2) | S-8 (40)',[['AirBombLauncher','Ch29Launcher_Su34','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','2Rnd_R73','40Rnd_S8T']]],
[8800,'FAB-250 (6) | Kh-29 (4) | R-73 (4)',[['AirBombLauncher','Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','2Rnd_R73','2Rnd_R73']]],
[18000,'FAB-250 (6) | Kh-29 (4) | S-8 (80)',[['AirBombLauncher','Ch29Launcher_Su34','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','40Rnd_S8T','40Rnd_S8T']]],
[6400,'FAB-250 (6) | Kh-29 (4) | Vikhr (12)',[['AirBombLauncher','Ch29Launcher_Su34','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','12Rnd_Vikhr_KA50']]],
[8600,'FAB-250 (6) | Kh-29 (6) | R-73 (2)',[['AirBombLauncher','Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','6Rnd_Ch29','2Rnd_R73']]],
[13200,'FAB-250 (6) | Kh-29 (6) | S-8 (40)',[['AirBombLauncher','Ch29Launcher_Su34','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','6Rnd_Ch29','40Rnd_S8T']]],
[7400,'FAB-250 (6) | Kh-29 (8)',[['AirBombLauncher','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','4Rnd_Ch29']]],
[12400,'FAB-250 (6) | R-73 (2) | S-8 (40) | Vikhr (12)',[['AirBombLauncher','R73Launcher_2','S8Launcher','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[23000,'FAB-250 (6) | R-73 (2) | S-8 (120)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[18400,'FAB-250 (6) | R-73 (4) | S-8 (80)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[6800,'FAB-250 (6) | R-73 (4) | Vikhr (12)',[['AirBombLauncher','R73Launcher_2','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','2Rnd_R73','12Rnd_Vikhr_KA50']]],
[16000,'FAB-250 (6) | S-8 (80) | Vikhr (12)',[['AirBombLauncher','S8Launcher','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[26600,'FAB-250 (6) | S-8 (160)',[['AirBombLauncher','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[3400,'FAB-250 (6) | Vikhr (24)',[['AirBombLauncher','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','12Rnd_Vikhr_KA50','12Rnd_Vikhr_KA50']]],
[14600,'FAB-250 (12) | GBU-12 (2) | Kh-29 (4)',[['AirBombLauncher','BombLauncherF35','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','4Rnd_Ch29']]],
[20600,'FAB-250 (12) | GBU-12 (2) | R-73 (2) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T']]],
[15000,'FAB-250 (12) | GBU-12 (2) | R-73 (4)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73','2Rnd_R73']]],
[24200,'FAB-250 (12) | GBU-12 (2) | S-8 (80)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T']]],
[12600,'FAB-250 (12) | GBU-12 (2) | Vikhr (12)',[['AirBombLauncher','BombLauncherF35','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','12Rnd_Vikhr_KA50']]],
[21600,'FAB-250 (12) | GBU-12 (4) | R-73 (2)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73']]],
[26200,'FAB-250 (12) | GBU-12 (4) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T']]],
[27200,'FAB-250 (12) | GBU-12 (6)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[8000,'FAB-250 (12) | Kh-29 (4) | R-73 (2)',[['AirBombLauncher','Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','2Rnd_R73']]],
[12600,'FAB-250 (12) | Kh-29 (4) | S-8 (40)',[['AirBombLauncher','Ch29Launcher_Su34','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29','40Rnd_S8T']]],
[6800,'FAB-250 (12) | Kh-29 (6)',[['AirBombLauncher','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','6Rnd_Ch29']]],
[17600,'FAB-250 (12) | R-73 (2) | S-8 (80)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[6000,'FAB-250 (12) | R-73 (2) | Vikhr (12)',[['AirBombLauncher','R73Launcher_2','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','12Rnd_Vikhr_KA50']]],
[13000,'FAB-250 (12) | R-73 (4) | S-8 (40)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[10600,'FAB-250 (12) | S-8 (40) | Vikhr (12)',[['AirBombLauncher','S8Launcher','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[21200,'FAB-250 (12) | S-8 (120)',[['AirBombLauncher','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[14200,'FAB-250 (18) | GBU-12 (2) | R-73 (2)',[['AirBombLauncher','BombLauncherF35','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_R73']]],
[18800,'FAB-250 (18) | GBU-12 (2) | S-8 (40)',[['AirBombLauncher','BombLauncherF35','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','40Rnd_S8T']]],
[19800,'FAB-250 (18) | GBU-12 (4)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12','2Rnd_GBU12']]],
[6200,'FAB-250 (18) | Kh-29 (4)',[['AirBombLauncher','Ch29Launcher_Su34'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_Ch29']]],
[12200,'FAB-250 (18) | R-73 (2) | S-8 (40)',[['AirBombLauncher','R73Launcher_2','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','40Rnd_S8T']]],
[6600,'FAB-250 (18) | R-73 (4)',[['AirBombLauncher','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73','2Rnd_R73']]],
[15800,'FAB-250 (18) | S-8 (80)',[['AirBombLauncher','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','40Rnd_S8T']]],
[4200,'FAB-250 (18) | Vikhr (12)',[['AirBombLauncher','VikhrLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','12Rnd_Vikhr_KA50']]],
[12400,'FAB-250 (24) | GBU-12 (2)',[['AirBombLauncher','BombLauncherF35'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_GBU12']]],
[5800,'FAB-250 (24) | R-73 (2)',[['AirBombLauncher','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73']]],
[10400,'FAB-250 (24) | S-8 (40)',[['AirBombLauncher','S8Launcher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T']]],
[4000,'FAB-250 (30)',[['AirBombLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250']]],
[21800,'GBU-12 (2) | Kh-29 (4) | R-73 (2) | S-8 (40)',[['BombLauncherF35','Ch29Launcher_Su34','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','4Rnd_Ch29','2Rnd_R73','40Rnd_S8T']]],
[16200,'GBU-12 (2) | Kh-29 (4) | R-73 (4)',[['BombLauncherF35','Ch29Launcher_Su34','R73Launcher_2'],['2Rnd_GBU12','4Rnd_Ch29','2Rnd_R73','2Rnd_R73']]],
[25400,'GBU-12 (2) | Kh-29 (4) | S-8 (80)',[['BombLauncherF35','Ch29Launcher_Su34','S8Launcher'],['2Rnd_GBU12','4Rnd_Ch29','40Rnd_S8T','40Rnd_S8T']]],
[13800,'GBU-12 (2) | Kh-29 (4) | Vikhr (12)',[['BombLauncherF35','Ch29Launcher_Su34','VikhrLauncher'],['2Rnd_GBU12','4Rnd_Ch29','12Rnd_Vikhr_KA50']]],
[16000,'GBU-12 (2) | Kh-29 (6) | R-73 (2)',[['BombLauncherF35','Ch29Launcher_Su34','R73Launcher_2'],['2Rnd_GBU12','6Rnd_Ch29','2Rnd_R73']]],
[20600,'GBU-12 (2) | Kh-29 (6) | S-8 (40)',[['BombLauncherF35','Ch29Launcher_Su34','S8Launcher'],['2Rnd_GBU12','6Rnd_Ch29','40Rnd_S8T']]],
[14800,'GBU-12 (2) | Kh-29 (8)',[['BombLauncherF35','Ch29Launcher_Su34'],['2Rnd_GBU12','4Rnd_Ch29','4Rnd_Ch29']]],
[19800,'GBU-12 (2) | R-73 (2) | S-8 (40) | Vikhr (12)',[['BombLauncherF35','R73Launcher_2','S8Launcher','VikhrLauncher'],['2Rnd_GBU12','2Rnd_R73','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[30400,'GBU-12 (2) | R-73 (2) | S-8 (120)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_R73','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[25800,'GBU-12 (2) | R-73 (4) | S-8 (80)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_R73','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[14200,'GBU-12 (2) | R-73 (4) | Vikhr (12)',[['BombLauncherF35','R73Launcher_2','VikhrLauncher'],['2Rnd_GBU12','2Rnd_R73','2Rnd_R73','12Rnd_Vikhr_KA50']]],
[23400,'GBU-12 (2) | S-8 (80) | Vikhr (12)',[['BombLauncherF35','S8Launcher','VikhrLauncher'],['2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[34000,'GBU-12 (2) | S-8 (160)',[['BombLauncherF35','S8Launcher'],['2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[10800,'GBU-12 (2) | Vikhr (24)',[['BombLauncherF35','VikhrLauncher'],['2Rnd_GBU12','12Rnd_Vikhr_KA50','12Rnd_Vikhr_KA50']]],
[22800,'GBU-12 (4) | Kh-29 (4) | R-73 (2)',[['BombLauncherF35','Ch29Launcher_Su34','R73Launcher_2'],['2Rnd_GBU12','2Rnd_GBU12','4Rnd_Ch29','2Rnd_R73']]],
[27400,'GBU-12 (4) | Kh-29 (4) | S-8 (40)',[['BombLauncherF35','Ch29Launcher_Su34','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','4Rnd_Ch29','40Rnd_S8T']]],
[21600,'GBU-12 (4) | Kh-29 (6)',[['BombLauncherF35','Ch29Launcher_Su34'],['2Rnd_GBU12','2Rnd_GBU12','6Rnd_Ch29']]],
[32400,'GBU-12 (4) | R-73 (2) | S-8 (80)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[20800,'GBU-12 (4) | R-73 (2) | Vikhr (12)',[['BombLauncherF35','R73Launcher_2','VikhrLauncher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','12Rnd_Vikhr_KA50']]],
[27800,'GBU-12 (4) | R-73 (4) | S-8 (40)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[25400,'GBU-12 (4) | S-8 (40) | Vikhr (12)',[['BombLauncherF35','S8Launcher','VikhrLauncher'],['2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[36000,'GBU-12 (4) | S-8 (120)',[['BombLauncherF35','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[28400,'GBU-12 (6) | Kh-29 (4)',[['BombLauncherF35','Ch29Launcher_Su34'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','4Rnd_Ch29']]],
[34400,'GBU-12 (6) | R-73 (2) | S-8 (40)',[['BombLauncherF35','R73Launcher_2','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','40Rnd_S8T']]],
[28800,'GBU-12 (6) | R-73 (4)',[['BombLauncherF35','R73Launcher_2'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73','2Rnd_R73']]],
[38000,'GBU-12 (6) | S-8 (80)',[['BombLauncherF35','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T','40Rnd_S8T']]],
[26400,'GBU-12 (6) | Vikhr (12)',[['BombLauncherF35','VikhrLauncher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','12Rnd_Vikhr_KA50']]],
[35400,'GBU-12 (8) | R-73 (2)',[['BombLauncherF35','R73Launcher_2'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_R73']]],
[40000,'GBU-12 (8) | S-8 (40)',[['BombLauncherF35','S8Launcher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','40Rnd_S8T']]],
[18800,'Kh-29 (4) | R-73 (2) | S-8 (80)',[['Ch29Launcher_Su34','R73Launcher_2','S8Launcher'],['4Rnd_Ch29','2Rnd_R73','40Rnd_S8T','40Rnd_S8T']]],
[7200,'Kh-29 (4) | R-73 (2) | Vikhr (12)',[['Ch29Launcher_Su34','R73Launcher_2','VikhrLauncher'],['4Rnd_Ch29','2Rnd_R73','12Rnd_Vikhr_KA50']]],
[14200,'Kh-29 (4) | R-73 (4) | S-8 (40)',[['Ch29Launcher_Su34','R73Launcher_2','S8Launcher'],['4Rnd_Ch29','2Rnd_R73','2Rnd_R73','40Rnd_S8T']]],
[11800,'Kh-29 (4) | S-8 (40) | Vikhr (12)',[['Ch29Launcher_Su34','S8Launcher','VikhrLauncher'],['4Rnd_Ch29','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[22400,'Kh-29 (4) | S-8 (120)',[['Ch29Launcher_Su34','S8Launcher'],['4Rnd_Ch29','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[14000,'Kh-29 (6) | R-73 (2) | S-8 (40)',[['Ch29Launcher_Su34','R73Launcher_2','S8Launcher'],['6Rnd_Ch29','2Rnd_R73','40Rnd_S8T']]],
[8400,'Kh-29 (6) | R-73 (4)',[['Ch29Launcher_Su34','R73Launcher_2'],['6Rnd_Ch29','2Rnd_R73','2Rnd_R73']]],
[17600,'Kh-29 (6) | S-8 (80)',[['Ch29Launcher_Su34','S8Launcher'],['6Rnd_Ch29','40Rnd_S8T','40Rnd_S8T']]],
[6000,'Kh-29 (6) | Vikhr (12)',[['Ch29Launcher_Su34','VikhrLauncher'],['6Rnd_Ch29','12Rnd_Vikhr_KA50']]],
[8200,'Kh-29 (8) | R-73 (2)',[['Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_Ch29','4Rnd_Ch29','2Rnd_R73']]],
[12800,'Kh-29 (8) | S-8 (40)',[['Ch29Launcher_Su34','S8Launcher'],['4Rnd_Ch29','4Rnd_Ch29','40Rnd_S8T']]],
[7000,'Kh-29 (10)',[['Ch29Launcher_Su34'],['6Rnd_Ch29','4Rnd_Ch29']]],
[16800,'R-73 (2) | S-8 (80) | Vikhr (12)',[['R73Launcher_2','S8Launcher','VikhrLauncher'],['2Rnd_R73','40Rnd_S8T','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[27400,'R-73 (2) | S-8 (160)',[['R73Launcher_2','S8Launcher'],['2Rnd_R73','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[4200,'R-73 (2) | Vikhr (24)',[['R73Launcher_2','VikhrLauncher'],['2Rnd_R73','12Rnd_Vikhr_KA50','12Rnd_Vikhr_KA50']]],
[12200,'R-73 (4) | S-8 (40) | Vikhr (12)',[['R73Launcher_2','S8Launcher','VikhrLauncher'],['2Rnd_R73','2Rnd_R73','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[22800,'R-73 (4) | S-8 (120)',[['R73Launcher_2','S8Launcher'],['2Rnd_R73','2Rnd_R73','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]],
[8800,'S-8 (40) | Vikhr (24)',[['S8Launcher','VikhrLauncher'],['40Rnd_S8T','12Rnd_Vikhr_KA50','12Rnd_Vikhr_KA50']]],
[20400,'S-8 (120) | Vikhr (12)',[['S8Launcher','VikhrLauncher'],['40Rnd_S8T','40Rnd_S8T','40Rnd_S8T','12Rnd_Vikhr_KA50']]],
[31000,'S-8 (200)',[['S8Launcher'],['40Rnd_S8T','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T','40Rnd_S8T']]]
]
];

// L-39 [AF3] - 4 pylons
_easaVehi = _easaVehi + ['L39_TK_EP1'];
_easaDefault = _easaDefault + [[['R73Launcher_2','57mmLauncher'],['2Rnd_R73','64Rnd_57mm']]];
_easaLoadout = _easaLoadout + [
[
[3800,'Ataka-V (4) | FAB-250 (6)',[['AT9Launcher','AirBombLauncher'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250']]],
[4600,'Ataka-V (4) | R-73 (2)',[['AT9Launcher','R73Launcher_2'],['4Rnd_AT9_Mi24P','2Rnd_R73']]],
[4200,'Ataka-V (4) | S-5 (64)',[['AT9Launcher','57mmLauncher'],['4Rnd_AT9_Mi24P','64Rnd_57mm']]],
[3400,'Ataka-V (8)',[['AT9Launcher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P']]],
[4000,'FAB-250 (6) | R-73 (2)',[['AirBombLauncher','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_R73']]],
[3600,'FAB-250 (6) | S-5 (64)',[['AirBombLauncher','57mmLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','64Rnd_57mm']]],
[2200,'FAB-250 (12)',[['AirBombLauncher'],['4Rnd_FAB_250','2Rnd_FAB_250','4Rnd_FAB_250','2Rnd_FAB_250']]],
[4400,'R-73 (2) | S-5 (64)',[['R73Launcher_2','57mmLauncher'],['2Rnd_R73','64Rnd_57mm']]],
[3800,'R-73 (4)',[['R73Launcher_2'],['2Rnd_R73','2Rnd_R73']]],
[3000,'S-5 (128)',[['57mmLauncher'],['64Rnd_57mm','64Rnd_57mm']]]
]
];

// F-35B [AF5] - 6 pylons
_easaVehi = _easaVehi + ['F35B'];
_easaDefault = _easaDefault + [[['MaverickLauncher','SidewinderLaucher_F35','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_F35','2Rnd_GBU12']]];
_easaLoadout = _easaLoadout + [
[
[13600,'AGM-65 (2) | AIM-9L (2) | GBU-12 (2)',[['MaverickLauncher','SidewinderLaucher_F35','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_F35','2Rnd_GBU12']]],
[6000,'AGM-65 (2) | AIM-9L (4)',[['MaverickLauncher','SidewinderLaucher_F35'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_F35','2Rnd_Sidewinder_F35']]],
[19200,'AGM-65 (2) | GBU-12 (4)',[['MaverickLauncher','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_GBU12','2Rnd_GBU12']]],
[5800,'AGM-65 (4) | AIM-9L (2)',[['MaverickLauncher','SidewinderLaucher_F35'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_F35']]],
[12400,'AGM-65 (4) | GBU-12 (2)',[['MaverickLauncher','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_GBU12']]],
[4600,'AGM-65 (6)',[['MaverickLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10']]],
[19400,'AIM-9L (2) | GBU-12 (4)',[['SidewinderLaucher_F35','BombLauncherF35'],['2Rnd_Sidewinder_F35','2Rnd_GBU12','2Rnd_GBU12']]],
[12800,'AIM-9L (4) | GBU-12 (2)',[['SidewinderLaucher_F35','BombLauncherF35'],['2Rnd_Sidewinder_F35','2Rnd_Sidewinder_F35','2Rnd_GBU12']]],
[5200,'AIM-9L (6)',[['SidewinderLaucher_F35'],['2Rnd_Sidewinder_F35','2Rnd_Sidewinder_F35','2Rnd_Sidewinder_F35']]],
[25000,'GBU-12 (6)',[['BombLauncherF35'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]]
]
];

// L-159 [AF3] - 6 pylons
_easaVehi = _easaVehi + ['L159_ACR'];
_easaDefault = _easaDefault + [[['MaverickLauncher','SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR']]];
_easaLoadout = _easaLoadout + [
[
[4400,'AGM-114 (8) | AGM-65 (2)',[['HellfireLauncher','MaverickLauncher'],['8Rnd_Hellfire','2Rnd_Maverick_A10']]],
[4600,'AGM-114 (8) | AIM-9L (2)',[['HellfireLauncher','SidewinderLaucher_AH1Z'],['8Rnd_Hellfire','2Rnd_Sidewinder_AH1Z']]],
[4200,'AGM-114 (8) | Hydra (38)',[['HellfireLauncher','FFARLauncher'],['8Rnd_Hellfire','38Rnd_FFAR']]],
[3800,'AGM-114 (8) | MK-82 (6)',[['HellfireLauncher','Mk82BombLauncher_6'],['8Rnd_Hellfire','6Rnd_Mk82']]],
[6600,'AGM-65 (2) | AIM-9L (2) | Hydra (38)',[['MaverickLauncher','SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR']]],
[6200,'AGM-65 (2) | AIM-9L (2) | MK-82 (6)',[['MaverickLauncher','SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82']]],
[6000,'AGM-65 (2) | AIM-9L (4)',[['MaverickLauncher','SidewinderLaucher_AH1Z'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z']]],
[5800,'AGM-65 (2) | Hydra (38) | MK-82 (6)',[['MaverickLauncher','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','38Rnd_FFAR','6Rnd_Mk82']]],
[5200,'AGM-65 (2) | Hydra (76)',[['MaverickLauncher','FFARLauncher'],['2Rnd_Maverick_A10','38Rnd_FFAR','38Rnd_FFAR']]],
[4400,'AGM-65 (2) | MK-82 (12)',[['MaverickLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','6Rnd_Mk82','6Rnd_Mk82']]],
[5800,'AGM-65 (4) | AIM-9L (2)',[['MaverickLauncher','SidewinderLaucher_AH1Z'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z']]],
[5400,'AGM-65 (4) | Hydra (38)',[['MaverickLauncher','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','38Rnd_FFAR']]],
[5000,'AGM-65 (4) | MK-82 (6)',[['MaverickLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','6Rnd_Mk82']]],
[4600,'AGM-65 (6)',[['MaverickLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10']]],
[6000,'AIM-9L (2) | Hydra (38) | MK-82 (6)',[['SidewinderLaucher_AH1Z','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','6Rnd_Mk82']]],
[5400,'AIM-9L (2) | Hydra (76)',[['SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','38Rnd_FFAR']]],
[4600,'AIM-9L (2) | MK-82 (12)',[['SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','6Rnd_Mk82','6Rnd_Mk82']]],
[5800,'AIM-9L (4) | Hydra (38)',[['SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR']]],
[5400,'AIM-9L (4) | MK-82 (6)',[['SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82']]],
[4200,'Hydra (38) | MK-82 (12)',[['FFARLauncher','Mk82BombLauncher_6'],['38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82']]],
[4600,'Hydra (76) | MK-82 (6)',[['FFARLauncher','Mk82BombLauncher_6'],['38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82']]],
[4000,'Hydra (114)',[['FFARLauncher'],['38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR']]],
[2800,'MK-82 (18)',[['Mk82BombLauncher_6'],['6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]]
]
];

// A-10A [AF3] - 4 pylons
_easaVehi = _easaVehi + ['A10'];
_easaDefault = _easaDefault + [[['FFARLauncher','Mk82BombLauncher_6'],['38Rnd_FFAR','6Rnd_Mk82']]];
_easaLoadout = _easaLoadout + [
[
[4200,'AGM-65 (2) | Hydra (38)',[['MaverickLauncher','FFARLauncher'],['2Rnd_Maverick_A10','38Rnd_FFAR']]],
[3800,'AGM-65 (2) | MK-82 (6)',[['MaverickLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','6Rnd_Mk82']]],
[3600,'AGM-65 (2) | Stinger (2)',[['MaverickLauncher','StingerLauncher_twice'],['2Rnd_Maverick_A10','2Rnd_Stinger']]],
[3600,'Hydra (38) | MK-82 (6)',[['FFARLauncher','Mk82BombLauncher_6'],['38Rnd_FFAR','6Rnd_Mk82']]],
[3400,'Hydra (38) | Stinger (2)',[['FFARLauncher','StingerLauncher_twice'],['38Rnd_FFAR','2Rnd_Stinger']]],
[3000,'Hydra (76)',[['FFARLauncher'],['38Rnd_FFAR','38Rnd_FFAR']]],
[3000,'MK-82 (6) | Stinger (2)',[['Mk82BombLauncher_6','StingerLauncher_twice'],['6Rnd_Mk82','2Rnd_Stinger']]],
[2200,'MK-82 (12)',[['Mk82BombLauncher_6'],['6Rnd_Mk82','6Rnd_Mk82']]]
]
];

// A-10C [AF4] - 8 pylons
_easaVehi = _easaVehi + ['A10_US_EP1'];
_easaDefault = _easaDefault + [[['MaverickLauncher','SidewinderLaucher_AH1Z','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','6Rnd_Mk82']]];
_easaLoadout = _easaLoadout + [
[
[6800,'AGM-114 (8) | AGM-65 (2) | AIM-9L (2)',[['HellfireLauncher','MaverickLauncher','SidewinderLaucher_AH1Z'],['8Rnd_Hellfire','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z']]],
[13400,'AGM-114 (8) | AGM-65 (2) | GBU-12 (2)',[['HellfireLauncher','MaverickLauncher','BombLauncherF35'],['8Rnd_Hellfire','2Rnd_Maverick_A10','2Rnd_GBU12']]],
[6400,'AGM-114 (8) | AGM-65 (2) | Hydra (38)',[['HellfireLauncher','MaverickLauncher','FFARLauncher'],['8Rnd_Hellfire','2Rnd_Maverick_A10','38Rnd_FFAR']]],
[6000,'AGM-114 (8) | AGM-65 (2) | MK-82 (6)',[['HellfireLauncher','MaverickLauncher','Mk82BombLauncher_6'],['8Rnd_Hellfire','2Rnd_Maverick_A10','6Rnd_Mk82']]],
[5600,'AGM-114 (8) | AGM-65 (4)',[['HellfireLauncher','MaverickLauncher'],['8Rnd_Hellfire','2Rnd_Maverick_A10','2Rnd_Maverick_A10']]],
[13600,'AGM-114 (8) | AIM-9L (2) | GBU-12 (2)',[['HellfireLauncher','SidewinderLaucher_AH1Z','BombLauncherF35'],['8Rnd_Hellfire','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12']]],
[6600,'AGM-114 (8) | AIM-9L (2) | Hydra (38)',[['HellfireLauncher','SidewinderLaucher_AH1Z','FFARLauncher'],['8Rnd_Hellfire','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR']]],
[6200,'AGM-114 (8) | AIM-9L (2) | MK-82 (6)',[['HellfireLauncher','SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['8Rnd_Hellfire','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82']]],
[13200,'AGM-114 (8) | GBU-12 (2) | Hydra (38)',[['HellfireLauncher','BombLauncherF35','FFARLauncher'],['8Rnd_Hellfire','2Rnd_GBU12','38Rnd_FFAR']]],
[12800,'AGM-114 (8) | GBU-12 (2) | MK-82 (6)',[['HellfireLauncher','BombLauncherF35','Mk82BombLauncher_6'],['8Rnd_Hellfire','2Rnd_GBU12','6Rnd_Mk82']]],
[19200,'AGM-114 (8) | GBU-12 (4)',[['HellfireLauncher','BombLauncherF35'],['8Rnd_Hellfire','2Rnd_GBU12','2Rnd_GBU12']]],
[5800,'AGM-114 (8) | Hydra (38) | MK-82 (6)',[['HellfireLauncher','FFARLauncher','Mk82BombLauncher_6'],['8Rnd_Hellfire','38Rnd_FFAR','6Rnd_Mk82']]],
[5200,'AGM-114 (8) | Hydra (76)',[['HellfireLauncher','FFARLauncher'],['8Rnd_Hellfire','38Rnd_FFAR','38Rnd_FFAR']]],
[4400,'AGM-114 (8) | MK-82 (12)',[['HellfireLauncher','Mk82BombLauncher_6'],['8Rnd_Hellfire','6Rnd_Mk82','6Rnd_Mk82']]],
[3400,'AGM-114 (16)',[['HellfireLauncher'],['8Rnd_Hellfire','8Rnd_Hellfire']]],
[15600,'AGM-65 (2) | AIM-9L (2) | GBU-12 (2) | Hydra (38)',[['MaverickLauncher','SidewinderLaucher_AH1Z','BombLauncherF35','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','38Rnd_FFAR']]],
[15200,'AGM-65 (2) | AIM-9L (2) | GBU-12 (2) | MK-82 (6)',[['MaverickLauncher','SidewinderLaucher_AH1Z','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','6Rnd_Mk82']]],
[21600,'AGM-65 (2) | AIM-9L (2) | GBU-12 (4)',[['MaverickLauncher','SidewinderLaucher_AH1Z','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','2Rnd_GBU12']]],
[8200,'AGM-65 (2) | AIM-9L (2) | Hydra (38) | MK-82 (6)',[['MaverickLauncher','SidewinderLaucher_AH1Z','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','6Rnd_Mk82']]],
[7600,'AGM-65 (2) | AIM-9L (2) | Hydra (76)',[['MaverickLauncher','SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','38Rnd_FFAR']]],
[6800,'AGM-65 (2) | AIM-9L (2) | MK-82 (12)',[['MaverickLauncher','SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82','6Rnd_Mk82']]],
[14800,'AGM-65 (2) | GBU-12 (2) | Hydra (38) | MK-82 (6)',[['MaverickLauncher','BombLauncherF35','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_GBU12','38Rnd_FFAR','6Rnd_Mk82']]],
[14200,'AGM-65 (2) | GBU-12 (2) | Hydra (76)',[['MaverickLauncher','BombLauncherF35','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_GBU12','38Rnd_FFAR','38Rnd_FFAR']]],
[13400,'AGM-65 (2) | GBU-12 (2) | MK-82 (12)',[['MaverickLauncher','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_GBU12','6Rnd_Mk82','6Rnd_Mk82']]],
[21200,'AGM-65 (2) | GBU-12 (4) | Hydra (38)',[['MaverickLauncher','BombLauncherF35','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR']]],
[20800,'AGM-65 (2) | GBU-12 (4) | MK-82 (6)',[['MaverickLauncher','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_GBU12','2Rnd_GBU12','6Rnd_Mk82']]],
[27200,'AGM-65 (2) | GBU-12 (6)',[['MaverickLauncher','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[6400,'AGM-65 (2) | Hydra (38) | MK-82 (12)',[['MaverickLauncher','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82']]],
[6800,'AGM-65 (2) | Hydra (76) | MK-82 (6)',[['MaverickLauncher','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82']]],
[6200,'AGM-65 (2) | Hydra (114)',[['MaverickLauncher','FFARLauncher'],['2Rnd_Maverick_A10','38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR']]],
[5000,'AGM-65 (2) | MK-82 (18)',[['MaverickLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]],
[14800,'AGM-65 (4) | AIM-9L (2) | GBU-12 (2)',[['MaverickLauncher','SidewinderLaucher_AH1Z','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12']]],
[7800,'AGM-65 (4) | AIM-9L (2) | Hydra (38)',[['MaverickLauncher','SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR']]],
[7400,'AGM-65 (4) | AIM-9L (2) | MK-82 (6)',[['MaverickLauncher','SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82']]],
[14400,'AGM-65 (4) | GBU-12 (2) | Hydra (38)',[['MaverickLauncher','BombLauncherF35','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_GBU12','38Rnd_FFAR']]],
[14000,'AGM-65 (4) | GBU-12 (2) | MK-82 (6)',[['MaverickLauncher','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_GBU12','6Rnd_Mk82']]],
[20400,'AGM-65 (4) | GBU-12 (4)',[['MaverickLauncher','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_GBU12','2Rnd_GBU12']]],
[7000,'AGM-65 (4) | Hydra (38) | MK-82 (6)',[['MaverickLauncher','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','38Rnd_FFAR','6Rnd_Mk82']]],
[6400,'AGM-65 (4) | Hydra (76)',[['MaverickLauncher','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','38Rnd_FFAR','38Rnd_FFAR']]],
[5600,'AGM-65 (4) | MK-82 (12)',[['MaverickLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','6Rnd_Mk82','6Rnd_Mk82']]],
[7000,'AGM-65 (6) | AIM-9L (2)',[['MaverickLauncher','SidewinderLaucher_AH1Z'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z']]],
[13600,'AGM-65 (6) | GBU-12 (2)',[['MaverickLauncher','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_GBU12']]],
[6600,'AGM-65 (6) | Hydra (38)',[['MaverickLauncher','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','38Rnd_FFAR']]],
[6200,'AGM-65 (6) | MK-82 (6)',[['MaverickLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','6Rnd_Mk82']]],
[5800,'AGM-65 (8)',[['MaverickLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10']]],
[15000,'AIM-9L (2) | GBU-12 (2) | Hydra (38) | MK-82 (6)',[['SidewinderLaucher_AH1Z','BombLauncherF35','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','38Rnd_FFAR','6Rnd_Mk82']]],
[14400,'AIM-9L (2) | GBU-12 (2) | Hydra (76)',[['SidewinderLaucher_AH1Z','BombLauncherF35','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','38Rnd_FFAR','38Rnd_FFAR']]],
[13600,'AIM-9L (2) | GBU-12 (2) | MK-82 (12)',[['SidewinderLaucher_AH1Z','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','6Rnd_Mk82','6Rnd_Mk82']]],
[21400,'AIM-9L (2) | GBU-12 (4) | Hydra (38)',[['SidewinderLaucher_AH1Z','BombLauncherF35','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR']]],
[21000,'AIM-9L (2) | GBU-12 (4) | MK-82 (6)',[['SidewinderLaucher_AH1Z','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','2Rnd_GBU12','6Rnd_Mk82']]],
[27400,'AIM-9L (2) | GBU-12 (6)',[['SidewinderLaucher_AH1Z','BombLauncherF35'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[6600,'AIM-9L (2) | Hydra (38) | MK-82 (12)',[['SidewinderLaucher_AH1Z','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82']]],
[7000,'AIM-9L (2) | Hydra (76) | MK-82 (6)',[['SidewinderLaucher_AH1Z','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82']]],
[6400,'AIM-9L (2) | Hydra (114)',[['SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR']]],
[5200,'AIM-9L (2) | MK-82 (18)',[['SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]],
[13200,'GBU-12 (2) | Hydra (38) | MK-82 (12)',[['BombLauncherF35','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_GBU12','38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82']]],
[13600,'GBU-12 (2) | Hydra (76) | MK-82 (6)',[['BombLauncherF35','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_GBU12','38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82']]],
[13000,'GBU-12 (2) | Hydra (114)',[['BombLauncherF35','FFARLauncher'],['2Rnd_GBU12','38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR']]],
[11800,'GBU-12 (2) | MK-82 (18)',[['BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_GBU12','6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]],
[20600,'GBU-12 (4) | Hydra (38) | MK-82 (6)',[['BombLauncherF35','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR','6Rnd_Mk82']]],
[20000,'GBU-12 (4) | Hydra (76)',[['BombLauncherF35','FFARLauncher'],['2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR','38Rnd_FFAR']]],
[19200,'GBU-12 (4) | MK-82 (12)',[['BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_GBU12','2Rnd_GBU12','6Rnd_Mk82','6Rnd_Mk82']]],
[27000,'GBU-12 (6) | Hydra (38)',[['BombLauncherF35','FFARLauncher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR']]],
[26600,'GBU-12 (6) | MK-82 (6)',[['BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','6Rnd_Mk82']]],
[33000,'GBU-12 (8)',[['BombLauncherF35'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[4800,'Hydra (38) | MK-82 (18)',[['FFARLauncher','Mk82BombLauncher_6'],['38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]],
[5200,'Hydra (76) | MK-82 (12)',[['FFARLauncher','Mk82BombLauncher_6'],['38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82']]],
[5600,'Hydra (114) | MK-82 (6)',[['FFARLauncher','Mk82BombLauncher_6'],['38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82']]],
[5000,'Hydra (152)',[['FFARLauncher'],['38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR']]],
[3400,'MK-82 (24)',[['Mk82BombLauncher_6'],['6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]]
]
];

// AV8B (LGB) [AF4] - 8 pylons
_easaVehi = _easaVehi + ['AV8B'];
_easaDefault = _easaDefault + [[['BombLauncherF35'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]];
_easaLoadout = _easaLoadout + [
[
[3000,'GBU-12 (6) | Hydra (38)',[['BombLauncherF35','FFARLauncher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR']]],
[9000,'GBU-12 (8)',[['BombLauncherF35'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]]
]
];

// AV8B [AF5] - 8 pylons
_easaVehi = _easaVehi + ['AV8B2'];
_easaDefault = _easaDefault + [[['MaverickLauncher','SidewinderLaucher_AH1Z'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z']]];
_easaLoadout = _easaLoadout + [
[
[6800,'AGM-114 (8) | AGM-65 (2) | AIM-9L (2)',[['HellfireLauncher','MaverickLauncher','SidewinderLaucher_AH1Z'],['8Rnd_Hellfire','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z']]],
[13400,'AGM-114 (8) | AGM-65 (2) | GBU-12 (2)',[['HellfireLauncher','MaverickLauncher','BombLauncherF35'],['8Rnd_Hellfire','2Rnd_Maverick_A10','2Rnd_GBU12']]],
[6400,'AGM-114 (8) | AGM-65 (2) | Hydra (38)',[['HellfireLauncher','MaverickLauncher','FFARLauncher'],['8Rnd_Hellfire','2Rnd_Maverick_A10','38Rnd_FFAR']]],
[6000,'AGM-114 (8) | AGM-65 (2) | MK-82 (6)',[['HellfireLauncher','MaverickLauncher','Mk82BombLauncher_6'],['8Rnd_Hellfire','2Rnd_Maverick_A10','6Rnd_Mk82']]],
[5600,'AGM-114 (8) | AGM-65 (4)',[['HellfireLauncher','MaverickLauncher'],['8Rnd_Hellfire','2Rnd_Maverick_A10','2Rnd_Maverick_A10']]],
[13600,'AGM-114 (8) | AIM-9L (2) | GBU-12 (2)',[['HellfireLauncher','SidewinderLaucher_AH1Z','BombLauncherF35'],['8Rnd_Hellfire','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12']]],
[6600,'AGM-114 (8) | AIM-9L (2) | Hydra (38)',[['HellfireLauncher','SidewinderLaucher_AH1Z','FFARLauncher'],['8Rnd_Hellfire','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR']]],
[6200,'AGM-114 (8) | AIM-9L (2) | MK-82 (6)',[['HellfireLauncher','SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['8Rnd_Hellfire','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82']]],
[6000,'AGM-114 (8) | AIM-9L (4)',[['HellfireLauncher','SidewinderLaucher_AH1Z'],['8Rnd_Hellfire','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z']]],
[13200,'AGM-114 (8) | GBU-12 (2) | Hydra (38)',[['HellfireLauncher','BombLauncherF35','FFARLauncher'],['8Rnd_Hellfire','2Rnd_GBU12','38Rnd_FFAR']]],
[12800,'AGM-114 (8) | GBU-12 (2) | MK-82 (6)',[['HellfireLauncher','BombLauncherF35','Mk82BombLauncher_6'],['8Rnd_Hellfire','2Rnd_GBU12','6Rnd_Mk82']]],
[19200,'AGM-114 (8) | GBU-12 (4)',[['HellfireLauncher','BombLauncherF35'],['8Rnd_Hellfire','2Rnd_GBU12','2Rnd_GBU12']]],
[5800,'AGM-114 (8) | Hydra (38) | MK-82 (6)',[['HellfireLauncher','FFARLauncher','Mk82BombLauncher_6'],['8Rnd_Hellfire','38Rnd_FFAR','6Rnd_Mk82']]],
[5200,'AGM-114 (8) | Hydra (76)',[['HellfireLauncher','FFARLauncher'],['8Rnd_Hellfire','38Rnd_FFAR','38Rnd_FFAR']]],
[4400,'AGM-114 (8) | MK-82 (12)',[['HellfireLauncher','Mk82BombLauncher_6'],['8Rnd_Hellfire','6Rnd_Mk82','6Rnd_Mk82']]],
[15600,'AGM-65 (2) | AIM-9L (2) | GBU-12 (2) | Hydra (38)',[['MaverickLauncher','SidewinderLaucher_AH1Z','BombLauncherF35','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','38Rnd_FFAR']]],
[15200,'AGM-65 (2) | AIM-9L (2) | GBU-12 (2) | MK-82 (6)',[['MaverickLauncher','SidewinderLaucher_AH1Z','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','6Rnd_Mk82']]],
[21600,'AGM-65 (2) | AIM-9L (2) | GBU-12 (4)',[['MaverickLauncher','SidewinderLaucher_AH1Z','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','2Rnd_GBU12']]],
[8200,'AGM-65 (2) | AIM-9L (2) | Hydra (38) | MK-82 (6)',[['MaverickLauncher','SidewinderLaucher_AH1Z','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','6Rnd_Mk82']]],
[7600,'AGM-65 (2) | AIM-9L (2) | Hydra (76)',[['MaverickLauncher','SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','38Rnd_FFAR']]],
[6800,'AGM-65 (2) | AIM-9L (2) | MK-82 (12)',[['MaverickLauncher','SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82','6Rnd_Mk82']]],
[15000,'AGM-65 (2) | AIM-9L (4) | GBU-12 (2)',[['MaverickLauncher','SidewinderLaucher_AH1Z','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12']]],
[8000,'AGM-65 (2) | AIM-9L (4) | Hydra (38)',[['MaverickLauncher','SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR']]],
[7600,'AGM-65 (2) | AIM-9L (4) | MK-82 (6)',[['MaverickLauncher','SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82']]],
[7400,'AGM-65 (2) | AIM-9L (6)',[['MaverickLauncher','SidewinderLaucher_AH1Z'],['2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z']]],
[14800,'AGM-65 (2) | GBU-12 (2) | Hydra (38) | MK-82 (6)',[['MaverickLauncher','BombLauncherF35','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_GBU12','38Rnd_FFAR','6Rnd_Mk82']]],
[14200,'AGM-65 (2) | GBU-12 (2) | Hydra (76)',[['MaverickLauncher','BombLauncherF35','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_GBU12','38Rnd_FFAR','38Rnd_FFAR']]],
[13400,'AGM-65 (2) | GBU-12 (2) | MK-82 (12)',[['MaverickLauncher','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_GBU12','6Rnd_Mk82','6Rnd_Mk82']]],
[21200,'AGM-65 (2) | GBU-12 (4) | Hydra (38)',[['MaverickLauncher','BombLauncherF35','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR']]],
[20800,'AGM-65 (2) | GBU-12 (4) | MK-82 (6)',[['MaverickLauncher','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_GBU12','2Rnd_GBU12','6Rnd_Mk82']]],
[27200,'AGM-65 (2) | GBU-12 (6)',[['MaverickLauncher','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[6400,'AGM-65 (2) | Hydra (38) | MK-82 (12)',[['MaverickLauncher','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82']]],
[6800,'AGM-65 (2) | Hydra (76) | MK-82 (6)',[['MaverickLauncher','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82']]],
[6200,'AGM-65 (2) | Hydra (114)',[['MaverickLauncher','FFARLauncher'],['2Rnd_Maverick_A10','38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR']]],
[5000,'AGM-65 (2) | MK-82 (18)',[['MaverickLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]],
[14800,'AGM-65 (4) | AIM-9L (2) | GBU-12 (2)',[['MaverickLauncher','SidewinderLaucher_AH1Z','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12']]],
[7800,'AGM-65 (4) | AIM-9L (2) | Hydra (38)',[['MaverickLauncher','SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR']]],
[7400,'AGM-65 (4) | AIM-9L (2) | MK-82 (6)',[['MaverickLauncher','SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82']]],
[7200,'AGM-65 (4) | AIM-9L (4)',[['MaverickLauncher','SidewinderLaucher_AH1Z'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z']]],
[14400,'AGM-65 (4) | GBU-12 (2) | Hydra (38)',[['MaverickLauncher','BombLauncherF35','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_GBU12','38Rnd_FFAR']]],
[14000,'AGM-65 (4) | GBU-12 (2) | MK-82 (6)',[['MaverickLauncher','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_GBU12','6Rnd_Mk82']]],
[20400,'AGM-65 (4) | GBU-12 (4)',[['MaverickLauncher','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_GBU12','2Rnd_GBU12']]],
[7000,'AGM-65 (4) | Hydra (38) | MK-82 (6)',[['MaverickLauncher','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','38Rnd_FFAR','6Rnd_Mk82']]],
[6400,'AGM-65 (4) | Hydra (76)',[['MaverickLauncher','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','38Rnd_FFAR','38Rnd_FFAR']]],
[5600,'AGM-65 (4) | MK-82 (12)',[['MaverickLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','6Rnd_Mk82','6Rnd_Mk82']]],
[7000,'AGM-65 (6) | AIM-9L (2)',[['MaverickLauncher','SidewinderLaucher_AH1Z'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Sidewinder_AH1Z']]],
[13600,'AGM-65 (6) | GBU-12 (2)',[['MaverickLauncher','BombLauncherF35'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_GBU12']]],
[6600,'AGM-65 (6) | Hydra (38)',[['MaverickLauncher','FFARLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','38Rnd_FFAR']]],
[6200,'AGM-65 (6) | MK-82 (6)',[['MaverickLauncher','Mk82BombLauncher_6'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','6Rnd_Mk82']]],
[5800,'AGM-65 (8)',[['MaverickLauncher'],['2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10','2Rnd_Maverick_A10']]],
[15000,'AIM-9L (2) | GBU-12 (2) | Hydra (38) | MK-82 (6)',[['SidewinderLaucher_AH1Z','BombLauncherF35','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','38Rnd_FFAR','6Rnd_Mk82']]],
[14400,'AIM-9L (2) | GBU-12 (2) | Hydra (76)',[['SidewinderLaucher_AH1Z','BombLauncherF35','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','38Rnd_FFAR','38Rnd_FFAR']]],
[13600,'AIM-9L (2) | GBU-12 (2) | MK-82 (12)',[['SidewinderLaucher_AH1Z','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','6Rnd_Mk82','6Rnd_Mk82']]],
[21400,'AIM-9L (2) | GBU-12 (4) | Hydra (38)',[['SidewinderLaucher_AH1Z','BombLauncherF35','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR']]],
[21000,'AIM-9L (2) | GBU-12 (4) | MK-82 (6)',[['SidewinderLaucher_AH1Z','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','2Rnd_GBU12','6Rnd_Mk82']]],
[27400,'AIM-9L (2) | GBU-12 (6)',[['SidewinderLaucher_AH1Z','BombLauncherF35'],['2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[6600,'AIM-9L (2) | Hydra (38) | MK-82 (12)',[['SidewinderLaucher_AH1Z','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82']]],
[7000,'AIM-9L (2) | Hydra (76) | MK-82 (6)',[['SidewinderLaucher_AH1Z','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82']]],
[6400,'AIM-9L (2) | Hydra (114)',[['SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR']]],
[5200,'AIM-9L (2) | MK-82 (18)',[['SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]],
[14800,'AIM-9L (4) | GBU-12 (2) | Hydra (38)',[['SidewinderLaucher_AH1Z','BombLauncherF35','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','38Rnd_FFAR']]],
[14400,'AIM-9L (4) | GBU-12 (2) | MK-82 (6)',[['SidewinderLaucher_AH1Z','BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','6Rnd_Mk82']]],
[20800,'AIM-9L (4) | GBU-12 (4)',[['SidewinderLaucher_AH1Z','BombLauncherF35'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12','2Rnd_GBU12']]],
[7400,'AIM-9L (4) | Hydra (38) | MK-82 (6)',[['SidewinderLaucher_AH1Z','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','6Rnd_Mk82']]],
[6800,'AIM-9L (4) | Hydra (76)',[['SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR','38Rnd_FFAR']]],
[6000,'AIM-9L (4) | MK-82 (12)',[['SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82','6Rnd_Mk82']]],
[14200,'AIM-9L (6) | GBU-12 (2)',[['SidewinderLaucher_AH1Z','BombLauncherF35'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_GBU12']]],
[7200,'AIM-9L (6) | Hydra (38)',[['SidewinderLaucher_AH1Z','FFARLauncher'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','38Rnd_FFAR']]],
[6800,'AIM-9L (6) | MK-82 (6)',[['SidewinderLaucher_AH1Z','Mk82BombLauncher_6'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','6Rnd_Mk82']]],
[6600,'AIM-9L (8)',[['SidewinderLaucher_AH1Z'],['2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z','2Rnd_Sidewinder_AH1Z']]],
[13200,'GBU-12 (2) | Hydra (38) | MK-82 (12)',[['BombLauncherF35','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_GBU12','38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82']]],
[13600,'GBU-12 (2) | Hydra (76) | MK-82 (6)',[['BombLauncherF35','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_GBU12','38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82']]],
[13000,'GBU-12 (2) | Hydra (114)',[['BombLauncherF35','FFARLauncher'],['2Rnd_GBU12','38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR']]],
[11800,'GBU-12 (2) | MK-82 (18)',[['BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_GBU12','6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]],
[20600,'GBU-12 (4) | Hydra (38) | MK-82 (6)',[['BombLauncherF35','FFARLauncher','Mk82BombLauncher_6'],['2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR','6Rnd_Mk82']]],
[20000,'GBU-12 (4) | Hydra (76)',[['BombLauncherF35','FFARLauncher'],['2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR','38Rnd_FFAR']]],
[19200,'GBU-12 (4) | MK-82 (12)',[['BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_GBU12','2Rnd_GBU12','6Rnd_Mk82','6Rnd_Mk82']]],
[27000,'GBU-12 (6) | Hydra (38)',[['BombLauncherF35','FFARLauncher'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','38Rnd_FFAR']]],
[26600,'GBU-12 (6) | MK-82 (6)',[['BombLauncherF35','Mk82BombLauncher_6'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','6Rnd_Mk82']]],
[33000,'GBU-12 (8)',[['BombLauncherF35'],['2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12','2Rnd_GBU12']]],
[4800,'Hydra (38) | MK-82 (18)',[['FFARLauncher','Mk82BombLauncher_6'],['38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]],
[5200,'Hydra (76) | MK-82 (12)',[['FFARLauncher','Mk82BombLauncher_6'],['38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82','6Rnd_Mk82']]],
[5600,'Hydra (114) | MK-82 (6)',[['FFARLauncher','Mk82BombLauncher_6'],['38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR','6Rnd_Mk82']]],
[5000,'Hydra (152)',[['FFARLauncher'],['38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR','38Rnd_FFAR']]],
[3400,'MK-82 (24)',[['Mk82BombLauncher_6'],['6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82','6Rnd_Mk82']]]
]
];

// Mi-24V (CZ) [AF3] - 4 pylons
_easaVehi = _easaVehi + ['Mi24_D_CZ_ACR'];
_easaDefault = _easaDefault + [[['AT9Launcher'],['8Rnd_AT9_Mi24V']]];
_easaLoadout = _easaLoadout + [
[
[6800,'Ataka-V (8) | Stinger (2)',[['AT9Launcher','StingerLauncher_twice'],['8Rnd_AT9_Mi24V','2Rnd_Stinger']]]
]
];

// AH-64D (TOW) [AF3] - 4 pylons
_easaVehi = _easaVehi + ['AH64D'];
_easaDefault = _easaDefault + [[['TOWLauncherSingle'],['6Rnd_TOW2']]];
_easaLoadout = _easaLoadout + [
[
[6800,'Stinger (2) | TOW-2 (6)',[['StingerLauncher_twice','TOWLauncherSingle'],['2Rnd_Stinger','6Rnd_TOW2']]]
]
];

// AH-64D (Hellfire) [AF4] - 4 pylons
_easaVehi = _easaVehi + ['AH64D_EP1'];
_easaDefault = _easaDefault + [[['HellfireLauncher'],['8Rnd_Hellfire']]];
_easaLoadout = _easaLoadout + [
[
[6800,'AGM-114 (8) | Stinger (2)',[['HellfireLauncher','StingerLauncher_twice'],['8Rnd_Hellfire','2Rnd_Stinger']]]
]
];

// Apache AH1 [AF4] - 4 pylons
_easaVehi = _easaVehi + ['BAF_Apache_AH1_D'];
_easaDefault = _easaDefault + [[['HellfireLauncher'],['8Rnd_Hellfire']]];
_easaLoadout = _easaLoadout + [
[
[6800,'AGM-114 (8) | Stinger (2)',[['HellfireLauncher','StingerLauncher_twice'],['8Rnd_Hellfire','2Rnd_Stinger']]]
]
];

// AH-1Z [AF5] - 4 pylons
_easaVehi = _easaVehi + ['AH1Z'];
_easaDefault = _easaDefault + [[['HellfireLauncher'],['8Rnd_Hellfire','8Rnd_Hellfire']]];
_easaLoadout = _easaLoadout + [
[
[3400,'AGM-114 (8) | AIM-9L (2)',[['HellfireLauncher','SidewinderLaucher_AH1Z'],['8Rnd_Hellfire','2Rnd_Sidewinder_AH1Z']]],
[1000,'AGM-114 (16)',[['HellfireLauncher'],['8Rnd_Hellfire','8Rnd_Hellfire']]]
]
];

// Wildcat AH11 [AF3] - 4 pylons
_easaVehi = _easaVehi + ['AW159_Lynx_BAF'];
_easaDefault = _easaDefault + [[['CRV7_HEPD','CTWS','SpikeLauncher_ACR'],['6Rnd_CRV7_HEPD','200Rnd_40mmHE_FV510','200Rnd_40mmSABOT_FV510','2Rnd_Spike_ACR','2Rnd_Spike_ACR']]];
_easaLoadout = _easaLoadout + [
[
[8800,'Spike (2) | Stinger (2)',[['CRV7_HEPD','CTWS','SpikeLauncher_ACR','StingerLauncher_twice'],['6Rnd_CRV7_HEPD','200Rnd_40mmHE_FV510','200Rnd_40mmSABOT_FV510','2Rnd_Spike_ACR','2Rnd_Stinger']]],
[5000,'Spike (4)',[['CRV7_HEPD','CTWS','SpikeLauncher_ACR'],['6Rnd_CRV7_HEPD','200Rnd_40mmHE_FV510','200Rnd_40mmSABOT_FV510','2Rnd_Spike_ACR','2Rnd_Spike_ACR']]],
[10600,'Stinger (4)',[['CRV7_HEPD','CTWS','StingerLauncher_twice'],['6Rnd_CRV7_HEPD','200Rnd_40mmHE_FV510','200Rnd_40mmSABOT_FV510','2Rnd_Stinger','2Rnd_Stinger']]]
]
];

// Mi-24V [AF3] - 4 pylons
_easaVehi = _easaVehi + ['Mi24_V'];
_easaDefault = _easaDefault + [[['AT9Launcher'],['4Rnd_AT9_Mi24P']]];
_easaLoadout = _easaLoadout + [
[
[6800,'Ataka-V (4) | Igla-V (2)',[['AT9Launcher','Igla_twice'],['4Rnd_AT9_Mi24P','2Rnd_Igla']]]
]
];

// Mi-24P [AF3] - 4 pylons
_easaVehi = _easaVehi + ['Mi24_P'];
_easaDefault = _easaDefault + [[['AT9Launcher','HeliBombLauncher'],['4Rnd_AT9_Mi24P','2Rnd_FAB_250']]];
_easaLoadout = _easaLoadout + [
[
[2600,'Ataka-V (4) | FAB-250 (6)',[['AT9Launcher','AirBombLauncher'],['4Rnd_AT9_Mi24P','4Rnd_FAB_250','2Rnd_FAB_250']]],
[6800,'Ataka-V (4) | Igla-V (2)',[['AT9Launcher','Igla_twice'],['4Rnd_AT9_Mi24P','2Rnd_Igla']]],
[7400,'FAB-250 (6) | Igla-V (2)',[['AirBombLauncher','Igla_twice'],['4Rnd_FAB_250','2Rnd_FAB_250','2Rnd_Igla']]]
]
];

// Ka-52 [AF4] - 8 pylons
_easaVehi = _easaVehi + ['Ka52'];
_easaDefault = _easaDefault + [[['AT9Launcher'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P']]];
_easaLoadout = _easaLoadout + [
[
[6800,'Ataka-V (12) | Igla-V (2)',[['AT9Launcher','Igla_twice'],['4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','4Rnd_AT9_Mi24P','2Rnd_Igla']]]
]
];

// Ka-52 (Black) [AF5] - 4 pylons
_easaVehi = _easaVehi + ['Ka52Black'];
_easaDefault = _easaDefault + [[['VikhrLauncher'],['12Rnd_Vikhr_KA50']]];
_easaLoadout = _easaLoadout + [
[
[9000,'R-73 (2) | Vikhr (12)',[['R73Launcher_2','VikhrLauncher'],['2Rnd_R73','12Rnd_Vikhr_KA50']]]
]
];
for '_i' from 0 to count(_easaVehi)-1 do {	_loadout = _easaLoadout select _i;		for '_j' from 0 to count(_loadout)-1 do {		_loadout_line = _loadout select _j;		_is_AAMissile = false;				{			_ammo = getText(configFile >> "CfgMagazines" >> _x >> "ammo");						if (_ammo != "") then {				if (getNumber(configFile >> "CfgAmmo" >> _ammo >> "airLock") == 1 && configName(inheritsFrom(configFile >> "CfgAmmo" >> _ammo)) == "MissileBase") exitWith {_is_AAMissile = true};			};		} forEach ((_loadout_line select 2) select 1);				_loadout_line set [3, if (_is_AAMissile) then {true} else {false}];	};};
missionNamespace setVariable ['WFBE_EASA_Vehicles',_easaVehi];missionNamespace setVariable ['WFBE_EASA_Loadouts',_easaLoadout];missionNamespace setVariable ['WFBE_EASA_Default',_easaDefault];