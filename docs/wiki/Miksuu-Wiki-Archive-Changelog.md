# Miksuu Wiki Archive: Changelog

> Imported from [`Miksuu/a2waspwarfare.wiki`](https://github.com/Miksuu/a2waspwarfare/wiki) at commit `45ef3da` (`45ef3da367d65e6487de488bbe3b16a8a8b21ba3`) on `2026-06-03`. Original file: `Changelog.md`.
> This page preserves upstream community/developer documentation as historical provenance. It is not the current canonical source of truth for implementation details.

Current routing: [Community & Dev](Community-And-Dev) | [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import)

Archive category: `community-release-history`

---

Here you can find the changelogs for the released patches (from our [Discord](https://discord.gg/7QcCKVmrcV))

Todo:
Check the formatting some of the sentences. Especially when mentioning the player who reported the bug/suggested a feature.

# v31072024 (Marty, Miksuu)
||@everyone :stalin_ping:||

- New feature to tune view distance automatically based on a set target FPS that is configurable with hotkeys has been added!
- You need to set the following hotkeys to make the feature work (from the Custom controls menu):

## Use Action 18: Turn the feature on/off

This will adjust your view distance to keep your FPS within +/- 2 of the set target FPS.
Right now the target FPS is being saved to your profile, but you need to turn on the feature every time you join the game. We might change this later.

### While turned on
Use Action 19 = Decrease target FPS
Use Action 20 = Increase target FPS

With parameters of:
Target FPS decrease/increase per press: 1 (you can hold the key down)
FPS range: 5
Default target FPS: 60 (when you change it, it will be saved to your profile namespace!)
Min target FPS: 30
Max target FPS: 240
(As of mission version v31072024)

### While turned off
Use Action 19 = Decrease view distance
Use Action 20 = Increase view distance
(like before, and according to #use-action-shortcuts )

The parameters of the features can be adjusted easily. 
Regarding the FPS range setting of the automatic view distance optimizer, be sure to leave feedback regarding how it works on your PC so we can change it or implement feature to adjust it in game.

Thanks a lot to @marty0007 for programming this feature. Additionally, I contributed to it by making the feature more configurable for the user.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ATTENTION !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
:trophy:  We are currently finishing our plans to host 2-3 tournaments with a shared price pool of **~1800$**. Be sure to be tuned to our Discord channels for more information in the coming days!

# v23072024 (Marty, Miksuu)

- **FAB-250 and MK-82 Bombs:**
  - FAB-250 and MK-82 bombs will now be destroyed if a player locks a target and the distance to the target is above 2000m. Players will receive a hint message notification.

- **Defences Distance:**
  - Increased the defences distance from 300m to 350m. This adjustment should resolve any remaining but rare issues of defences not manning properly.

- **AFK Timer Adjustment:**
  - Lowered the AFK timer from 15 to 10 minutes. Future offenders who frequently trigger the AFK timer may receive a short ban. Please remember that bypassing the script is not allowed. Join only when you have the time to commit to playing. Thank you.

- **Server Logging Disabled:**
  - Disabled logging on the server to improve performance. We have not been able to catch the bug related to ghost base areas and haven't received any reports about it for months. It may have been resolved with recent performance enhancements on the new server.

# v16072024 (Marty, Miksuu)

- **Unit Camera Enhancements**
  - Added AI numbers to the unit camera list. In the camera unit, numbers have been added near each unit's name reflecting their number in the Function key management.

- **Climbing Gear**
  - Added climbing gear for MHQ.
  - Added climbing gear for Light Factory vehicles.
  This greatly improves the mobility of these vehicles.

- **Artillery Enhancements**
  - Artillery circle range is now drawn on the map when a player calls it and is visible for their team.
  - For developers: Optional parameters have been added to the marker_creation function to be used for different situations (simple marker or marker with ellipse as an option).

- **Nuke Enhancements**
  - Enhanced the destruction caused by the nuke impact by damaging all objects within an 800m radius around the target, including trees, buildings, factories, and animals. Logical objects, camps, depots, and flags have been preserved to avoid disrupting game mechanics. Spam bombs in the impact area have been removed to prevent performance issues. Unnecessary spawns have also been removed for the same reason.
  - Added a radiation sound effect when players enter a radiation nuke zone.
  - To test these changes on a live server, we're offering nukes for a discounted price of $75,000 each (instead of $150,000) for a limited time of ~1 week.
  - Since we now have the optional parameters in the marker creation script, @marty0007 is already planning to add a radius of destruction to the incoming nuclear strike marker on the map. 

- **Sound Adjustments**
  - Corrected sound levels for certain sounds such as artillery call. If you have feedback regarding these changes, let us know how we could optimise the sound mix of the mission even further!

Big thanks to @marty0007 for programming these huge QoL changes that have been laying around in the backlog for a while now.

Also we've updated the #rules of the server, removing the rule of dropping guided bombs from the high altitude since that's scripted now and quite balanced with the current limit. Minefield deployment from the repair trucks is now restricted in any situation when the vehicle is airborne.

— Arma2Warfare GPT & @marty0007 & @miksuu 
||@everyone :stalin_ping:||

# v03072024 (Marty, Miksuu)

- Implemented a restriction on dropping all types of bombs known to date on the server, with a maximum altitude set by default to 2500 meters. This measure aims to prevent players from exploiting the 3000-meter limit of surface-to-air missile fire. If a player drops a bomb beyond the regulated altitude, the bomb will automatically disintegrate and the occupants of the aircraft will receive a notification via the vehicle channel. The notification message supports multiple languages and is available in 6 different languages. Additionally, administrators can adjust the altitude restriction parameter in the launch settings. Finally, the code has been optimized using an event handler only for flying vehicles.
[GBU-12 is unaffected!]

- Updated the camera list to display only players by filtering out all leader bots. This change helps to avoid useless lines corresponding to empty slots in the camera list, ensuring that only players with their corresponding units are shown.

- Increased Warrior price from $5 000 to $6 500

# v10052024 (Miksuu)

||@everyone @Veteran :stalin_ping:  ||

## Changed the functionality of the code regarding building the construction sites and it broadcasting the message to all of the sides players. 
- This should resolve the performance issues that some of the players were having on long sessions when looking towards a base or being in one. When you'll play on server, let us know if the mission has better performance in regards this (compared to the v22032024 patch). I'll be testing this today too.
- In a week or so, we will enable @marty0007 's command center unit number feature on the cam, and monitor client sided performance. 
- Report all of the observations in #performance-discussion , thanks!

## Changed server view distance from 3000 to 3500 meters
- Might affect server performance a little bit, but makes the server sided bots engage you better on the edge of the missile range limit.
- We might tweak this later, so post your feedback! https://discord.com/channels/440257265941872660/1232934505178992641/1232934505178992641

I have added a @Veteran role. You can request this role in #role-request channel. Post your in game nick at the same time, and if not done yet, I can change your discord name to it at the same time when assigning the role. In the future only players who have this role, might be able to vote on the #vote-suggestions channel.

# v22032024_1 (Miksuu)

Hello ||@everyone :KKomrade: ||

**The server has been updated to: v22032024_1** (not visible on ingame info window)

The following feature has been reverted for testing:
``Modifying the script that list the remote camera in order to display only human players and not bots (= empty slots) in the unit camera``

If you still experience huge FPS issues, like 2-3x lower performance with +15 players or so (especially if you played yesterday and had these issues), let us know ASAP and if we confirm this, we will revert the next feature that was implemented on the previous patch. Eventually we will find the root cause of the issue, thanks!

Please note that this should not affect server FPS in any way, and you can still have bad client FPS even though server runs with +40 FPS. With this bug, you will see **very** low client fps if the server starts lagging too.

-- Set the default & server view distance to 3000 meters. This doesn't affect the view distance of the client, and should give huge performance gains. However, I read that AI can't calculate beyond that point now but 3k should be fine for that either way.

# v22032024 (Miksuu, Marty, An-2 is a good plane)

Hello ||@everyone :stalin_ping:||, we have a new patch up on the server.

## Each factory now features a unique build sound and message, enhancing the immersive experience within the game.
- This feature is displayed in the Command Chat for better visibility. 
- Check the video below for the demonstration. Also I have posted the sounds below too (excluding service point which is a drill, basically)!

## Implemented additional levels of IR smoke, providing four more charges and a consistent warning for Level 2. Our appreciation goes to @rainbowbier for the extensive testing and valuable feedback on the features mentioned above
- Video below for demo
- Looking ahead, we are considering the addition of a toggle feature for the IR smoke effects to switch them on and off while preserving the warning sounds.

## Modifying the script that list the remote camera in order to display only human players and not bots (= empty slots) in the unit camera list (by @marty0007)

## We've introduced the BVP-1 to Opfor HF1 with a price tag of $2,200. Please note that the Bradley vehicle remains as it was in the previous version (by @nonotgulag)

## Significant updates have been rolled out for the Chernarus map, along with minor adjustments to the Takistan map.

- **Deadspawn Overhaul**: Locations of deadspawn points have been reorganized, and a new deadspawn marker introduced for enhanced gameplay clarity.
- **Starting Positions**: 
  - Dense forest starting points like **Bor** have been removed to facilitate faster gameplay.
  - New strategic starting points added in **Kozlovka**, **Pass Sosnovy**, **NW part of the North West Airfield**, **Veresnik hill**, among others.
  - Superfluous starting points, such as **Devils Castle** and **Krasnostav Airfield**, have been removed.
- **Town Adjustments**:
  - **Kozlovka** removed to improve player mobility.
  - **Bor** has added as replacement for **Kozlovka**
  - **Pogorevka** replaced with **Rogovo** and **Pulkovo** * inserted to focus action in the Center.
  - Removed **Orlovets**.
  - Added **Nizhnoye** to replace it.
  
- **Supply Value Changes**: 
  - Supply values have been calibrated for towns across the map to encourage strategic decision-making and resource management, putting bigger emphasis on the Center control.
  - Notable supply value increases for towns such as **Kabanino**, **Stary Sobor**, and **Novy Sobor** to highlight their strategic importance.
  - Some towns like **Kamenka**, **Tulga**, **Petrovka**, and **Olsha** have seen a reduction in supply values.
- The **Balota hangar** has been repositioned and rotated to avoid direct aircraft spawns on the runway.

- **Takistan Adjustments**:
  - Deadspawn locations updated with new warning markers.
  - Hangar placements optimized to prevent unintended aircraft spawns on runways.
  - Introduction of new starting positions in **Sagarm** and **north of Lalezar** to expand gameplay variety.

- Full list of the documented changes can be found on the images below.

- Please share your feedback on these changes, especially if you encounter any repetitive or unfavorable spawns.

## The guerrilla barracks have been removed entirely for extra performance and to avoid other the issues that they cause.

## The task system has been decisively eliminated from the mission in this update.

## Corrections have been made to the Russian translations within the engineer salvage feature.

Please provide feedback on the current audio mix of the mission, since it is so easy to adjust now. Also I have noticed that if you have effects turned up really high in the game, somehow the sounds get amplified, so try lowering that inside the sound settings if you have issues with that. In the future we will optimise the sound mix to run on ~50% of the ingame volume, but your overall feedback is very crucial! 

— Arma2Warfare GPT & @miksuu

![image](https://github.com/Miksuu/a2waspwarfare/assets/39275678/19389f24-09ea-4a84-9af3-b5c6006d0ebf)
![image](https://github.com/Miksuu/a2waspwarfare/assets/39275678/25710891-c2ab-43b6-b5b1-104c0441146b)
https://cdn.discordapp.com/attachments/1116268624458547261/1220557510822330428/irSmokeLevel2Sound.mp4?ex=660f5fc3&is=65fceac3&hm=fde41a61e49c899af4f9cb63fc669e0a30aeccf7534bf07ab0f1e0a6f7bdadef&
https://cdn.discordapp.com/attachments/1116268624458547261/1220557523837255761/newRenderBuildSounds.mp4?ex=660f5fc6&is=65fceac6&hm=c84eec575b576fca6cb11b2dd8ffe7b5da4bbcfa282ed3ff567fdce462d76ea0&

# v06032024 (Miksuu)

- Fixed _availweapons error when placing defences outside of the base area. This should fix them permanently now, let me know if there are any issues still.

# v04032024 (Marty, Miksuu)

- The HQ wreck marker is put back as it was in September 24th 2023. The update marker when HQ is moved by a player is not yet implemented in order to keep it simple for test purpose (by @marty0007 )
- Removed the task system from the mission to remove clutter from the UI.
- Added debug lines to investigate the occasional base area limit bug. If you encounter this issue, please report it on Discord with a timestamp and, if possible, screenshots or video of the base setup.
- Implemented debug lines to monitor the total number of groups and AI units in the game. This change aims to identify and eliminate possible "ghost" groups that may cause lag, especially after increasing the server's processing power with the latest configuration change. If you notice consistent low server FPS that does not recover to approximately 45-48, please report it for further investigation.
- Corrected the last syntax error in the base defences and resolved the last major error on the server RPT side (except for the algorithm managing guerrilla AI groups from the resistance barracks, which only generates errors at the game's start). 

This is very experimental patch since we can't test these things on the testing server, so please report any issues with the wreck marker or unusual server lag! It will help us optimize performance for a smooth experience with up to 30 players with the power of the new server that we have, especially when it's configured correctly now!

— Arma2Warfare GPT & @miksuu

# v17022024 (Miksuu)

- Added one rocket back to the British NLAW soldier. This should fix the issue of them not firing at all. I didn't test this change (will when I merge it to the current dev version), but let me know if it still doesn't work.
- At the same time, the price of the NLAW soldier was raised by 100$, making it's price 650$.

# v09022024 (Miksuu)

- Introduced a new **Barracks Spawn Marker** to improve AI orientation on the battlefield. This feature is visually represented by a yellow rectangle marker on the ground:

![image](https://github.com/Miksuu/a2waspwarfare/assets/39275678/741742f8-502e-4e2a-a9bb-5b7d9fdc74cf)


- Added a **Salvage Feature** for the Engineer class. Engineers can now salvage vehicles as a unit with a cooldown of 10 seconds. This feature is subject to future adjustments based on gameplay balance and player feedback. Access to the salvage option is available through the scroll wheel, alongside other skills:

![image](https://github.com/Miksuu/a2waspwarfare/assets/39275678/b00e773f-c53d-41eb-93cd-31d1d3845d19)

- **Balancing Adjustments:**
  - The build time for RPG-7VR soldiers has been reduced from 7 seconds to 5 seconds. This change aligns the RPG-7VR soldier build time with that of other RPG-equipped soldiers, ensuring consistency in unit production times.

— Arma2Warfare GPT & @miksuu

# v28122023 (Miksuu)
||@everyone :stalin_ping:||

- Added AT Specialist (Dragon) with 2 rockets to OPFOR priced at $600 (at Barracks Level 2).
- Added RPG-7 VR Soldier with 2 rockets to OPFOR priced at $350 (at Barracks Level 2).
- **Important Notice:** Please be aware that the unit descriptions in-game regarding the loadout for the AT Specialist (Dragon) and RPG-7 VR Soldier may be incorrect for now.
- Removed one rocket from the NLAW soldier, now equipped with 2 rockets.
- Implemented a 0.5 seconds delay between spawning the town AI groups to mitigate the sudden lag spike experienced by all clients when the town is activated.
- Decreased AI limit from 16 to 15.
- Enabled wall construction by default (can still be toggled by action hotkey).
- Increased the AV8B (AF5) Sidewinder carrying capacity from 6 to 8.
- Added +50 seconds to each artillery reload level. Now ranging from 550 to 250 seconds.
- Removed rules from the MOTD to reduce unnecessary chat spam because they are now always visible with upon join with a Pastebin link for those who are not on the discord. They were just recently updated to #rules too!

— Arma2Warfare GPT & @miksuu

# v26122023 (Miksuu)
- The 7950X3D server has been disabled. It seems that it wasn't worth it at all. Thanks for trying it out though! We might upgrade to 14th gen Intel when it becomes available to the host we use. If you connect by IP, use 88.198.47.228 now again, as updated to #server-info 
- Experimental: Headless client custom memory allocator enabled. Please report your performance findings in #performance-discussion (Mr.James is still active, no multithreading yet). Server has been running this memory allocator before too.
- Quick fix: Attempt removing "Dumb Bomb Rocket Simulation", that might have forced infrared lock on the bombs, possibly fixing the guidance of the bombs. Report your findings and if they still guide, we'll implement a range limit for the bombs.

# v16122023 (Miksuu)
- **Vehicle Adjustments**
  - Wildcat weapons have been moved from the gunner to the pilot seat. To balance this change, Wildcat loadout prices have slightly increased, while the overall vehicle cost has been reduced by $2,000.

- **Base Management**
  - Possibly addressed an issue with undeploying HQ not removing the base area as intended. This bug fix is aimed at improving the stability of base operations. Let us know how it works on longer rounds.

- **Event Configuration**
  - Introduced a new parameter for server admins to enable the Air War Event, enhancing the customizability of server events.

- **Unit Menu Organization**
  - Reorganized the placement of NLAW soldier in the units menu for better coherence. It is now positioned above SMAW soldiers for easier access.

- **Loadout Interface**
  - Loadouts are now sorted alphabetically by weapon type instead of by price, allowing for a more intuitive and accessible loadout selection process.

- **Aircraft Feature Enhancement**
  - Added UH-1Y hydras to the pilot seat enabling manual fire without the need for a separate feature. Also fixed a bug where flares were incorrectly assigned to the wrong seat. The flare count remains at 120.

- **Weaponry**
  - Removed the HandleBombs script for Mk82 and FAB-250 dumb bombs to prevent unintended target guidance. A server-wide vote will be proposed to consider granting dumb bombs a 3km range.

- **Missile Loadout Expansion**
  - Increased the AV8B (AF5) Sidewinder missile capacity from 4 to 6, adding 4 new loadouts. A vote will determine if the capacity should be further increased to 8.

- **Headquarter Maintenance**
  - Temporarily set HQ repair costs to 25k supply per incident until a new script for counting HQ repairs is implemented server-side.

- **Factory Upgrades**
  - Revised upgrade times for factories post-level 3. For instance, upgrade times for Aircraft Factories (AF) have changed from [60,80,100,100,100] to [60,80,100,120,140].

- **Server Stability**
  - Fixed several script warnings related to missing files in the server's Kick and LogGame Modules to ensure smoother server performance.

- **Visual Experience**
  - Modified the debounce script for setting the view distance timer from 1.5 to 0.75 seconds for a more responsive visual setting experience.
  - Info about the feature: https://discord.com/channels/440257265941872660/1135891800373071894/1135897984945631272

- **Sniper Gameplay**
  - Implemented a lockpick feature for the Sniper class (previously exclusive to SpecOps aka Support class).

- **Visual Customization**
  - Temporarily restored the original color schemes for salvage trucks and factories on the map for further evaluation: salvage trucks to khaki and factories to black.

- **Supply Truck Mechanics**
  - Altered supply truck mechanics to prevent them from disappearing up to 24 hours, allowing for lifting without AI needing to be inside them.

- **Vehicle Classification**
  - Classified all supply trucks in the game as Light Factory 0 (LF0) for consistency in vehicle categorization.

~~This patch will be available on the Next Restart on the server.~~ deployed

— Arma2Warfare GPT & @miksuu

# v24112023 (Miksuu)

Hello, Arma 2 gamers! We're excited to bring you the latest updates with patch v24112023. Check out the detailed improvements and optimizations below:

### Map and Gameplay Adjustments
- **Fixed Modded Maps Boundaries**: Corrected map boundary parameters to ensure proper gameplay space and prevent out-of-bounds issues. The new boundaries for maps are:
  - Lingor: 10300 meters
  - Sahrani: 20480 meters
  - Taviana: 25600 meters
  - Dingor: 10300 meters

- **Economy and Balance Changes**:
  - **Everon Town Supply Value**: Increased by approximately 20% to support better resource flow and gameplay dynamics.
  - **MiG-21 Cost Adjustment**: The price of the MiG-21 has been lowered from 49999 to 45712 dollars, making it more accessible.

- **Spawn Locations**:
  - **Remove Napf South East Spawns**: We've removed problematic spawn points in the South East of the Napf map to improve the starting conditions and fairness.

- **Technical Fixes and Tweaks**:
  - **Start Vehicle & Texture Files**: Fixed an issue where `Start_Veh.sqf` & `texHeaders.bin` files were missing from the Napf map, affecting vehicle and texture loading.

### Community Feedback and Voting Outcomes
- **Modded Maps Rotation**:
  - Following a community vote, Lingor has been moved to the last position in the modded maps rotation due to a 5-6 vote decision. The vote is still up, and in the future the map might be removed from the rotation completely.

### Project and Development Workflow Enhancements For Developers
- **Mission File Management**:
  - A new system has been introduced for writing mission files to 7z archive. This feature enhances the mission deployment process making it more seamless and efficient.

### Additional Notes
- Please remember that these changes are made with the community's feedback in mind. We encourage you to continue providing your input and suggestions as they are vital for the ongoing enhancement of your gaming experience.

Thank you for your dedication and support. Let's dive into the improved world of Arma 2 together!

— Arma2Warfare GPT & @miksuu

# v17112023 (Miksuu)

We are excited to announce the latest updates to Arma 2 with patch v17112023! Here's what's new and what's been improved:

### Air War Event Enhancements
- **Improved Balance**:
  - Nuke and vehicles with Tunguska missiles have been disabled for events using the `IS_AIR_WAR_EVENT` parameter.
  - Each player now starts with +1.337M in cash, and each team receives +50k supply, ensuring a level playing field.
  - Each team receives maximum upgrades on the start.
- **Map Adjustments**:
  - Towns have been divided appropriately to enhance gameplay strategy.

### Loading and Performance Optimizations
- **Faster Loading**: Compressed `loadscreen.jpg` images for both maps to speed up loading times.

### Gameplay Tweaks
- **Spawn Logic Update**: Adjusted the definition of TinyTown to SmallTown on desert maps to ensure RPG soldiers always spawn correctly.
- **Visual Improvements**: Changed the color of the salvage truck on the map from Khaki to Blue for better visibility.
- **Ambient Sound Update**: Removed the starting music to prevent potential audio clutter and improve overall sound clarity during gameplay.
- **Map Marker Clarity**: The black factory marker color has been adjusted to be Khaki coloured to prevent blending with player markers.

### Quality of Life Adjustments
- **Endgame Music**: Reinstated the classic "Iron Mountain" from Arma 2: Operation Arrowhead soundtrack, removing the custom endgame music to facilitate faster mission downloads and preserve the nostalgic Arma experience.

Thank you for your continued support and feedback. Your input is invaluable and helps us make Arma 2 the best experience possible. Please continue to report bugs and share your suggestions on our Discord channels. #old_report-a-bug #old_suggestions 

Keep the feedback coming, and let's enjoy the enhanced gameplay together!

-Arma2Warfare GPT & @miksuu

# v10112023 (Miksuu)
-- Added money receiving sound
-- Added boats to the town center at LF0 (CRRC and PBX). Takistan is excluded
-- Changed spawn distances in Isla Duala to 5.5k, Sahrani to 10.5k, Napf 12.5k.
-- Some under the hood changes that at the same time moved end game music to sounds. Will be fixed later but as of now, we have a system that allows adding of the sounds very easily with our tools.

# v05112023 (Miksuu)

-- Added Light Repair option for the Support class.
-- Added translations to the Light Repair option.
the mechanic itself is unchanged.

# v26102023 (Net_2, Miksuu)
-- Changed player and units markers and their colors (see welcome message when you join)

-- Updated player kills and bounty calculations

-- Decreased server desync with under-the-hood changes - let us know if desync improves from now on!

-- Changed end game music to @ezcoo's old ones like "America, Fuck Yeah"

-- Updated welcome message on the server

-- Added helpful hint for newly assigned commander

-- Added increasing repair costs for HQ (**S 25000**, **S 40000**, **S 49500**) - it can be repaired 3 times now (in addition to buying it once)

-- Added helpful hints for (most) special vehicles when you select them in Buy Units menu

-- Driver slot in AI vehicles is disabled by default now

-- Added supply missions/runs for the support class (old Spec Ops)
Note that at#rules rule 14 has been added:
``14. Duping supply run missions is not allowed. (This will be monitored regularly and if someone exploits the feature, they'll receive a ban.)``

-- Players spawn on latest built **production factory** when joining the game (CC, AAR, SP is excluded now)

-- Disabled the currently bugged HQ wreck marker
This will be fixed at later date and the marker will be reintroduced

-- Decreased sound levels of the artillery call

-- Increased volume of the artillery ready sound which comes when the cooldown is over

-- Increased the afk warning timer from **30 seconds** to **120 seconds**

-- Decreased Ural Zu23 price from **$1750** to **$1100** (and make construction time 20 seconds)

-- Added snipers to the town center depots at barracks level 2

-- Fixed MiG-21 display name on the radar and now new vehicles will automatically have this feature on them, which helps to speed up the development when adding new vehicles in to the game.

Please note that Rule 1 has been modified to:
Missile usage is restricted to situations where the player has a direct line of sight to the target. Exploiting game mechanics to glitch missiles is strictly prohibited. Lofting missiles is permitted under specific conditions: when behind a hill but still having a direct line of sight to the target; when having a height advantage that allows seeing the target behind an obstacle; or when both the player and the target are near obstructions like a treeline.

If you have any issues with the patch let me know, since it's a big codebase merge with the @ezcoo's old code.


# v25092023 (Marty, Miksuu)

||@everyone Hello again KKomrades :stalin_ping: ||
Server will update when the round ends or at tomorrow morning.

**Marty's changes: **
- **The money transfer** list and the advanced transfer displayed only players and not bots now [Images 1 & 2]
- **Added a better notice to the center of the screen and a new sound when your artillery is off the cooldown**
- **Fixed errors regarding BIS_CONTROL_CAM**
- **For the developers:** complete refactoring of the magic function "createMarker" that can handle now object or coordinate positions as string. When the function get an object, the marker position will be automatically updated. Easy to use.
 
**Miksuu's changes: **
**- [Bug Fix] Reverted changes of Common_SortByDistance.sqf script that most likely caused the crash on the server yesterday. It will be fixed at a later date so resistance can roam the map again.**

**- [Bug Fix] Fixed upgrade notice grammar error, added more proper translations at the same time**

**- [Balancing/Voted] Added new artillery upgrade levels and reworked the costs, and cooldown times for each of the upgrade levels** https://discord.com/channels/440257265941872660/1116365031228063755/1131988965419921428
(although the last level with 200sec was added, but it can be very easily removed if it gets negative feedback)
> New levels:
> Level = cooldown - cost in supplies - upgrade time. 
> - Level 0 = 500 seconds - 0 - 0
> - Level 1 = 450 seconds - 800 - 40
> - Level 2 = 400 seconds - 1400 - 70
> - Level 3 = 350 seconds - 2200 - 100
> - Level 4 = 300 seconds - 3700- 130
> - Level 5 = 250 seconds - 6100 - 160
> - Level 6 = 200 seconds - 10000 - 190
> 
> These levels might require further tuning based on your feedback after you have tried it on the server, so please provide it in #balancing_discussion !

**- [Balancing/Voted] Raised the price of Stryker MC from $4200 to $4800**  https://discord.com/channels/440257265941872660/1116365031228063755/1131988857823428658

**- [Balancing/QoL] ICBM supply cost reduced to 49500 from 50000 to allow players still deploy/undeploy HQ when they run the upgrade before the next supply tick**

**- [Balancing/QoL] Lowered Airlift upgrade time from 45 to 30 to allow players buy lift-capable AF1/AF2 helicopter while the upgrade is running and still get the airlift feature to that helicopter when it's ready at 100% certainty **

**- [QoL] Changed artillery notice marker text format to: ARTY [PlayerName], reducing unnecessary clutter on the map**

**- [QoL] Used different sign on the artillery notice marker to differentiate it from the ICBM warning marker (the color will stay red)**

**- [QoL] Increased sound levels of all the new warning sound effects (ICBM/Arty), making them more hearable when there are loud effects around the player (e.g. when operating a tank, flying a plane or getting hit by artillery)**
> We will be continiously improving the sound mix, since there is a lot of them in the game now. Appropriate feedback is appreciated!

**- [QoL] Raised reptruck time to disappear by twice as much (just like Ambulances)**
> Sometimes on the repair truck paradrop, depending where you call it and on the RNG where the lift vehicle will spawn, you couldn't receive it in time so we added this.

**- [Voted] Added airlift capability to AN-2. Enjoy the meming with it such as a anti-aircraft platform [Image 3]** https://discord.com/channels/440257265941872660/1116365031228063755/1131988813363806238

![image](https://github.com/Miksuu/a2waspwarfare/assets/39275678/cd087647-b056-41c7-8ec6-02e084eb4a93)
![image](https://github.com/Miksuu/a2waspwarfare/assets/39275678/9886f141-06d1-4230-8f7c-bff94f05a8e5)
![image](https://github.com/Miksuu/a2waspwarfare/assets/39275678/252f8c9b-b82b-4a9c-ae11-274bf8ae6a7c)

# v22092023 (Marty, Miksuu)
@marty0007:
1. Fixed gear menu template selection error (see Trello card 'Bug When Buying Gear').

2. Set ICBM audio volume to normal (1.0) as per wiki.

3. Corrected 'Common_SortByDistance' enhancing object distance measurement.

4. Fixed camera interface errors, defaulting to player selection.

5. Resolved errors in commander's construction view using 'isNil' instead of 'isnull'.

@miksuu:
- Fixed US tanks having forest camo in Takistan
- [Debug mode only] Disabled teamswapping for easier testing and not having to navigate to the parameter menu every time

Big props to @marty0007 for the fixes! These QoL changes are just way too awesome!
Since the aircraft I intended to add tomorrows event (modded V10 air event on Taviana with new air vehicles) were bugged, not balanced at all (sidewinders didn't kill them with one shot), I postponed the event possibly to next week (will be decided later). 
On the other hand, today I went back to developing the main mission itself, so a lot of updates are coming to the mission (already in testing, below on the image) in the next few days! However, I need your feedback on this: https://discord.com/channels/440257265941872660/445631540513210379/1155144257947041943 (upcoming arty reload changes).
As a reminder, features that have the most effect on the gameplay while having a fast implementation time will be prioritised. Thanks!

# v19092023 (Marty, Miksuu)
@marty0007:
1. **Headquarters Wreck Marker Update:**
   The symbol showing a wreck HQ is now updated when the team moves it using a helicopter transport.

2. **ICBM Language Fix:**
   If an intercontinental ballistic missile is launched, each player will now receive messages in their preferred language set in Arma 2: Operation Arrowhead.

3. **Artillery Language Fix:**
   When a player calls for artillery support, all players will now receive messages in their chosen language set in Arma 2: Operation Arrowhead.

4. **Technical aspects:**
   The magic function WF_sendMessage can take a 4th parameter in case of compile string to generate multi-language message.

@miksuu:
- Added regular Mi-8 available to buy from the hangars for the OPFOR (just like BLUFOR has MV-22 available as airlifter from there)
- Reduced wildcat price from $29692 to $24692

# V9 MODPACK Changelog (Miksuu)
(merged to v16092023: https://discord.com/channels/440257265941872660/1116268624458547261/1152932725230149713)
Available to download at #event-mods ! (For this Sundays and and next weeks Mondays mod event)

## Extending the LoadoutManager tool to support adding modded vehicles in to the game more easily
We now have ability to add any mod vehicle (that is not in a broken state) to the game in less than 15-30min, configuring its loadouts and testing, including automatic copy to all the modded terrains. First vehicle added is MiG-21MF, that is currently available to play on event that is going on the server right now. (more info below!)

Since the adding of the new vehicles is so easy now, next weekend I plan to host V10 modpack event (possibly with the huge 50x50km PMC desert terrain) with Air War Event parameters, for a day. This way we can add several new vehicles to the modded terrains with little effort. If you want to see some specific vehicle added in to the game, let me know. The mod preferably shouldn't produce any errors on the error log, so it can be added easily. List of available mods can be found here: http://www.armedassault.info/index.php?s=31e7b3bb56f768ddd4d608e5166718f7&game=1&cat=addons&era=0&type=0&sort=download&order=desc&page=1 (if the site goes down, I have them all backed up ;) ) If you have any loadout ideas for that vehicle, let me know so we can make each of the vehicles unique!

## Added Taviana map to the modpack
Due to a bug in the mod itself (or a configuration error by me), the map can not be run simultaneously with other maps on the server without causing a crash. I will attempt to fix this later so it can be put in to normal rotation with other maps. Because of this, we will only run the map on the Sunday, while on Monday the other mod maps will be run in a rotation.

We are aware that there are some issues with pathfinding with AI on this map, and I plan to fix them later. The map could be made more suitable for CTI by adding land bridge between the islands, so AI can cross the island even though the bridge is destroyed.

Vote will be added later, if the crashing issue with other maps isn't fixed, that if we want to run this map every 4-8 weeks or so, for one day during the event.

Screenshot of the map (deadspawns are at Otok island, do not enter there! marker will be added for next time),
with a gameplay video from 2020 can be found below:
![image](https://github.com/Miksuu/a2waspwarfare/assets/39275678/ae031ff4-f990-467f-a984-daa1baa3426c)
https://www.youtube.com/watch?v=nXQWt6MJjpQ

## Added MiG-21MF to all of the modded maps
Faction: **:opfor_icon: OPFOR**
Upgrade level: **AF5**
Cost: **49999$** (subject to change with feedback)
### Loadouts:
Pylon amount: **4**

R-73 (missile script included)

GBU-12 (limited to 2)

Ataka-V (limited to 4)


**Remember, you can use the afterburner option in the scroll menu, making this the fastest and the highest accelerating jet in the game right now. This consumes a lot fuel though!**

![image](https://github.com/Miksuu/a2waspwarfare/assets/39275678/096d637a-9921-4e1f-98a6-902479b0aff2)
![image](https://github.com/Miksuu/a2waspwarfare/assets/39275678/c9c714ea-aa5e-4353-823f-c207f5c56156)

# v16092023 (Miksuu)

-- Some more refactoring of the mission, removed Core_Units directory from the blacklist (those files are now identical between Chernarus and Takistan, only seperated by @marty0007 's variable that he added earlier). These files control what units each of the factions get.
-- Added IS_mod_map_dependant variable for every single map (it's off on Chernarus and on Takistan). This way we can add mod vehicle definitions to Chernarus and they will get copied to every single map (but still are effective only on the modded maps). Vehicles affected as of V9 modpack: MiG-21 (more to come!).
-- Mod pack version is now visible on the welcome message that appears on the right hand side.** If you see that it is updated and you haven't downloaded the new modpack, it means that it is available on our Discord, and will be required for our next event.
**

# v15092023 (Marty, Miksuu)

Another update again! As you all wanted, we're excited to introduce others greats update to enhance the server's gameplay experience! These improvements are aimed at the following aspects:

1. **ARTY Mark on the Map:**
   - When a player calls in artillery support, a distinctive marker with the player's name is now visible on the map.
   - An audio message, supporting multiple languages, is broadcast to all players on the same team when artillery support is requested. 
   - After the cooldown period for artillery, the player who made the call will receive a notification in the form of a multilingual hint message.
   - Audio messages are available in three different languages based on the faction you are playing with: American, Russian, and Arabic for the Takistanish faction.
   - The marker is automatically removed once the artillery support mission is completed. To enhance reliability, it will be removed automatically after 80 seconds.

2. **Multiple ICBM Markers:**
   - Multiple ICBM markers are now possible and will only be visible to the side that launches them. As with the previous patch, both teams will receive specific audio and text messages.

3. **Bug Fixes and Technical Improvements:**
   - The HQ wreck marker now spawns correctly on the server.
   - The ICBM message code has been refactored, introducing a magic function to easily send audio and text messages to one side.
   - The log content can now be activated or deactivated using comments for the `WF_LOG_CONTENT` constant in `version.sqf`. This setting is also mentioned in the log file at the beginning of the script mission, indicating whether it is activated or not.

We hope these updates enhance your gaming experience. Enjoy the improved gameplay in this latest version! Another update announcement for this patch about @miksuu's part is coming very soon!

![](https://cdn.discordapp.com/attachments/1116268624458547261/1151868740657487932/image.png)
https://cdn.discordapp.com/attachments/1116268624458547261/1151868741060153415/ARTY_warning_Friendly_message_russian_v1.ogg
https://cdn.discordapp.com/attachments/1116268624458547261/1151868741458595890/ARTY_warning_Friendly_message_v3.ogg
https://cdn.discordapp.com/attachments/1116268624458547261/1151868741903196332/ARTY_warning_Friendly_message_arabic_v1.ogg

**continuation to the v15092023 patch notes:** (Miksuu)
-- Huge refactoring of the missions Cherno and Takistan files are now very similar
-- Added a feature to the LoadoutManager for it to copy almost all files (some blacklisted, we'll reduce this list later) from Chernarus to Takistan (and these are cloned to the event maps automatically, just like before)

These changes will make development for our contributors very easy since most of the time, they need to edit Chernarus. However, it is a huge refactoring change for the whole mission (since there was many differences between Takistan and Chernarus). 

Although it's tested quite well, **let us know if you notice any small bugs in the mission, or something's just off.** I will keep you posted when I do refactoring the missions until the point they are identical (excluding the factions and mission.sqm file), but yet still the same way they are right now for the player.

# v10092023 (Marty)
**MHQ/HQ WRECK marking is here ! @everyone**

Now, when the HQ or MHQ gets destroyed, their wrecks will show up on the map for your teammates, but not to the other team.
This makes it easier to find the wreckage for potential repairs. The marking will be easy to spot on the map and won't go away until the MHQ is repaired or a new one is purchased at a town depot.

Thanks also to @Miksuu to get the mission project up to date on git and for fixing some bugs in this new patch !

ENJOY

![](https://cdn.discordapp.com/attachments/1116268624458547261/1151597893304721558/image.png)


# v09092023 (Marty)

We have made some improvements to the nuclear strike (ICBM) system, incorporating essential features for an even more immersive and strategic gaming experience. Here is an overview of the key enhancements:

1. **Audio and text Messages for Both Teams**: Now, when using a nuclear strike, each team receives its own audio and textual messages, enhancing coordination and strategic communication.

2. **Multilingual Support for Text Messages**: Our enhancements include support for multilingual environments. Text messages generated by the ICBM are now tailored to the user's language, improving user-friendliness for players worldwide. Language supported : english, french german, russian, italian.

3. **Restricted Marker Visibility**: Markers created by the ICBM are visible only to the friendly team, thereby enhancing the confidentiality of crucial information and avoiding unfair advantages.

4. **Admin Parameter for Time Before Impact**: For @Game Admin , we have added the ability to set the delay before the nuclear strike impact as a customizable parameter. This allows for better control of game dynamics.

5. **Developer Utility Functions**: To support future development @Contributor , we have introduced specific utility functions that can be reused for subsequent projects. These functions include the ability to delete markers, obtain lists of enemy or friendly players, and collect lists of players on the West or East teams. This greatly simplifies the process of creating new features for content creators.

These enhancements aim to provide a more immersive, balanced, and user-friendly gaming experience while providing powerful tools for mod developers and server administrators. We look forward to seeing how these changes enrich your experience in the world of ICBM. Enjoy the strategic action!

https://cdn.discordapp.com/attachments/1116268624458547261/1149985991885606942/warning_Friendly_ICBM_v2.ogg
https://cdn.discordapp.com/attachments/1116268624458547261/1149985992233730170/warning_Enemy_ICBM_v2.ogg

# v05092023 (Marty)

**A real automatic kick system for inactive players (AFK)** has been implemented. Players who remain AFK for a specified duration will be automatically removed from the server.
This action will free up slots in the lobby, addressing the issue of unbalance caused by AFK players.
The default AFK timeout is set to **10 minutes**, as per the community vote, but @Game Admin  have the ability to adjust this value in the mission parameters.
A countdown will appear on the screen of AFK players 30 seconds prior to the automatic kick. Admins cannot modify this timeframe, although it can be developped if necessary.

![](https://cdn.discordapp.com/attachments/1116268624458547261/1148717952913383554/image.png)

# v28082023 (Miksuu, DMR, Marty)

-- Pandur/BTR-90: Available now at LF3 without their rocket launchers, which become available at LF4.

-- Pandur Cannon: Changed to M242BC with 210 rounds (AP and HE included), from ATKMK44 with 60 rounds.

-- A-10A/Su-25a Loadouts: Added 2 AGM-65 Maverick / 4 Ataka as EASA loadouts.

-- Tank Crew: Replaced crewmen inside tanks with engineers for repair capabilities. 

-- MI-24CZ: Lowered price from **$42620** to **$39620**.

-- Pandur: Lowered price from **$3500** to **$2650**.

-- NLAW Soldier: Raised price from **$360** to **$550** and moved to B1 from B3.

-- BTR-90: Lowered price from **$3450** to **$2550**.

-- GRAD (Chernarus): Lowered price from **$7800** to **$6800**.

-- Stryker MGS: Lowered price from **$3250** to **$2800**.

-- Smaw Soldier (Chernarus): Lowered from B3 to B2. (In Takistan, Maaws soldier will stay at B2, priced at **$350**.)

-- LAV-25: Lowered price from **$1800** to **$1650**.

-- Su-25a: Fixed missing HandleBombs script.

Thanks a lot to @DMR#1208 @marty0007 for some of these changes!

# v21082023 (Miksuu)
||@everyone :stalin_ping: ||
Since the latest patch air patch, especially now that the Blufor has the V hind, the metagame has been just to rush AF3 to get access to that vehicle. This patch should bring some variety to that metagame, encouraging players to buy the new vehicles such as: A-10A, Su-25a, AH-64D (TOW), and the Wildcat. I think that as the result of this patch, Blufor AF3 on helicopters might be a bit weaker (since they are missing the hind now completely), but let us know how we can make especially the AH-64D (TOW) more viable (if it's needed).

The problem with the hind is that the vehicle itself is very tanky, and is very difficult to take out of the game. Also, I think that no vehicle should have **80** S8 rockets on AF3, or since there is no really counterpart to that rocket, S8 at AF3 at all (Hydra does the same damage than S5 rocket though).

So for the update **v21082023**:

**-- Both of the Mi-24V variants moved to AF4** 

**-- Mi-24V (CZ) price raised to $42620 from $35620**

**-- Mi-24V (OPFOR) Ataka count has been reduced from 8 to 4**

**-- Mi-24P 40 S8 rockets changed to 64 S5 rockets, the vehicle's price is unaffected and its AF level stays at 3**


Note that changes like this are *extremely easy* to implement now (this is why I created the framework), so I gave it a go. If a lot of negative feedback is received as an result, I can just revert that merge and the mission is back to the old one in the next restart, simple as that.

However, as what I have observed, before the air patch and after it (and playing a lot with @DMR#1208 and talking with him about it), it seems that this vehicle shouldn't belong in AF3, and neither S8's should be present on that AF level. Before the patch the same happened on the OPFOR hind, but after the patch, it was the same on BLUFOR. Would you really want to play a game where one vehicle (on both sides) runs the game? Instead of having more variety and when both teams try to rush AF:
- The team with better pilots of that *one vehicle* will outright just win the game with that vehicle
- Very small advantage in supply will result in victory (since you reach AF3 faster)

However, if the other team goes full on HF:
- There's a chance that the team rushing AF3 will reach is faster than the other team going for HF4, completely dominating the game
- Other possibility is that the other team reaches HF4 first, making the game a very stale one with Linebacker/Tunguska/Hind camping and artillery fest (especially with passive commanders)

Or the last option:
- We try make the game to have many options for you to win the game to (as the whole air patch was supposed to do).
- Sudden power spikes at AF3 (for both teams) are removed completely (could even buff AF2 tbh, adjust upgrade costs, what do you think?)
- LF is made more viable, offering teams to go for fast LF4, then AF. If both teams opt in for this, the game is decided by who controls the air with ***jets***, and not helicopters. Base building at airfields (and open fields) becomes more important, and HQ for both teams will be more mobile, as it should be in my opinion.
- Nearly every single vehicle has their own role for contributing winning the game, and the players should choose one, that fits the current situation the best (alongside with its loadouts)
- There might be further tuning of the power curve that the Aircraft Factory provides right now
- More upgrade levels are added to provide more variety for the commanders. This would also end games faster for the team that has the advantage in upgrades such as Artillery reload with multiple levels.

Let us know in #balancing_discussion how we can improve the balance of the mission. Without your proper feedback, we can't make this better.
There's a chance that minor changes will be made without voting still, to finetune the balance, but perhaps I'll do some new ones this week, depending on the feedback we receive.
Thanks, and see you on the server!

# v19082023 (0=1, Miksuu)
**-- Introducing Spawn Markers (by 0=1)**
- You can place them from 4-menu of the HQ / Repair Truck build menu.
- There are markers for: LF, HF, AF
- Multiple marker placements are possible
- Vehicles will spawn randomly on one of the markers randomly (per factory type)
Thanks a lot to 0=1 for this incredible feature!

**-- Fixed HandleATMissile.sqf script not working at all (some AT missile behaviour might have been altered now)**

**-- Updated all mod maps to v19082023 (excluding slots, report any bugs with these ones). The event will start as soon as possible!**

**-- Fixed slot bugs on Tasmania like OPFOR Engineer not having gear at all**
This is something we can't utilise the new system for managing the files (since mission.sqm is different on all maps due to placement of the towns, camps, airfields, starting positions, and deadspawns). I tested them all now on Tasmania and Everon (same for rest of the forest maps) should be fixed now, let me know if you still spawn without gear and take a screenshot from that slot from the lobby. Thanks.

# v18082023 (Miksuu)
**-- Reworked Takistani Guerilla defence groups by:**
- Removing AT soldiers (Dragon, RPG7 soldiers) from every group other than the Anti-tank squad
- Increased AT soldier count in the AT squad, removed other type of troops from it
- Other changes such as making machinegunner groups to only have machinegunners, sniper group has now two soldiers instead of one

**-- Increased TOW damage against T-90 slightly (damage modifier up from 23 to 33)**

**-- Replaced all instances of ``side player`` with ``side group player`` syntax, fixing a rare bug when BMP-2 would spawn on top of you and killing the player, and the script would not remove the Konkurs launcher from that HF1 BMP-2 because ``side player`` returned civilian faction when the player was dead**

**-- Fixed one extra repair cycle animation on the camp that the player would do for no reason, however for some reason the message is still delayed (fixing this in the future) **

**-- Lowered Stryker (TOW) from LF4 to LF3**

**-- Buffed Tunguska missile manoeuvrability, let me know if you still are able to dodge those ones!**

**-- Fixed zero divisor errors in the missile script that boosts AA missile's speed, manoeuvrability etc.**

**-- Added keys for the modified JSRS1.5 mod to fix the error with the mod (beta test of the mod, will not be in the official modpack yet, if you try it, let me know how it works for you!)**
https://drive.google.com/file/d/1iHZEIuNJMkt7X16TOFEj2OocPikeZg5B/view?usp=sharing

# v15082023 (Miksuu)

**-- Lowered the ammo truck price to $1850 from $2850**
Thanks for the suggestion @opftafel007 !

**-- Fixed ICBM warning sound file missing from Takistan**

**-- Added a modfolder which lowers the cooldown between the magazine reload of the Sidewinder missile in F-35, Av8b, and the L-159 alca. Download it here to upgrade your modpack for the server: https://drive.google.com/file/d/1fqAD04sNLp0TQgAAMQk_AfQX4c7xLF5h/view?usp=sharing**

# v13082023 (Miksuu)
**-- An experimental change of removing the AIM-9 and R-73 missile script from AH-1Z and Ka-52 (black) has been implemented. Jets will maintain their old missile launch parameters.**

**-- Gave Maverick missile significantly more speed and manoeuvrability.**
>  According to my testing, every missile hit, and they might be a bit too fast now (basically same parameters than R73 missiles). Since these values are easily tweakable, let me know in #balancing_discussion  what is your experience using them, thanks!

**-- Fixed BRDM (Igla) missing from Takistan**

**-- Raised Uh-60 and Mi-8 ambu heli prices to be $1000 above their non ambu variants, and both variants raised to AF2**

**-- Fixed some minor misplacements of the order in the AF buy menu for vehicles such as AH6, UH1, AH64, MI8**
> Let me know if somethings still off that I didn't notice for some reason (other than Air menu is not organised, yet!)

# v12082023 (Miksuu, Cleinstein, DMR)

||@everyone :stalin_ping: ||
Important update before we get in to the changelog:
The #rules were updated to add rule 13:
``Do not shut down your engine to avoid getting locked by the enemy while flying.``
Please report any players who seem unlockable frequently, preferably with multiple video clips, thanks.

**v12082023 [The Air Balance Patch] changelog:**

**-- Many vehicle additions and such as:**
- AH-64D (TOW) at AF3 (new vehicle)
- Mi-24V (CZ) at AF3 (new :blufor_icon: BLUFOR vehicle!)
- Reintroduced Wildcat with loadouts that don't crash your game :KEKW: 
- A-10A at AF3 (new vehicle)
- A-10C at AF4 (loadouts changed from the original A-10)
- Su-25A at AF3 (new vehicle)
- Su-25T at AF4 (loadout changed from the original Su-25)
- Su-39 at AF5 (loadout changes, and raised from AF4)
- Helicopters are limited to Stingers and Iglas now, up until AF5 where they get maximum of two Sidewinders or R-73's (AH-1Z, Ka-52 Black)
(refer to the spreadsheet for full list of changes)

**-- Removed GBU-12's from L-159 Alca**

**-- Added GBU-12s to Su-25T, Su-39, and Su-34 in OPFOR loadouts**

**-- Reorganised the Aircraft factory unit order to: helicopters, then jets (both categories ordered from AF0 to AF5)**

**-- Build times of aircraft have been changed to: [from AF0: 25, 30, 35, 40, 45, 50 to AF5]**
> We will probably apply these changes to other factories too later.

**-- Added BRDM (Igla) to OPFOR LF4**

**-- Changed BRDM (ATGM) to LF3, as it should be**
Thanks for these @cleinstein !

**-- Created a system that calculates all the possible weapon combinations (selected weapons with their possible set limits) for every defined aircraft. Here's how the system works:**
- Every aircraft has set amount of pylons, for example the Su-39 at AF5 has 10 pylons.
- Its default game config from the game files looks like:
weapons[] = {"GSh301","AirBombLauncher", "R73Launcher_2", "S8Launcher", "CMFlareLauncher" };
magazines[] = {"180Rnd_30mm_GSh301", "4Rnd_FAB_250", "2Rnd_R73", "80Rnd_S8T", "120Rnd_CMFlare_Chaff_Magazine"};
- This data is fed to C# application, while configuring its default loadout in that application per magazines (this defines the default loadout the vehicle spawns in).
- For EASA loadouts configuration, data is structured like:
[the magazine type, max occupied pylons by that magazine type] for example:
```cs
allowedAmmunitionTypesWithTheirLimitationAmount = new Dictionary<AmmunitionType, int>
  {
    { AmmunitionType.SIXROUNDFAB250, 0 },
    { AmmunitionType.FOURTYROUNDS8, 0 },
    { AmmunitionType.TWELVEROUNDSVIKHR, 4 }, (Vikhrs and Hellfires are automatically multiplied by two)
    { AmmunitionType.BASECH29, 0 },
    { AmmunitionType.TWOROUNDGBU12, 8 },
    { AmmunitionType.TWOROUNDR73, 4 },
  };
```
- Based on this data, the program will automatically calculate all available combinations for the given aircraft. Note that 12 Vikhrs and 8 Hellfires will always take four pylons, and some weapons can fit many in to one pylon (for example 3 FAB250/MK82 bombs, and 20 S8 rockets per pylon!)
- The price of the loadout is calculated cost per pylon basis, and each of the magazines have their own price. Each new weapon currently adds +1000$ to the cost (this may be changed later per weapon). Almost complete list of these costs can be found at: https://docs.google.com/spreadsheets/d/1OQLpb3D2rDABWtIFxcPb_FplgNpYA53-/edit#gid=342224945 (this won't be updated), or the current one in the source code of the application (will be updated): https://github.com/Miksuu/a2waspwarfare/blob/master/Tools/LoadoutManager/Data/Ammunition/Implementations/AirToGroundWeapons/Bombs/LaserGuidedBombs/GBU12/TWOROUNDGBU12.cs

- Here's an example how one of the loadouts,
``[14400,'FAB-250 (6) | S-8 (40) | Kh-29 (4) | R-73 (2)',[['AirBombLauncher','S8Launcher','Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','4Rnd_Ch29','2Rnd_R73']]],``
is calculated:
6 FAB250s, 40 S8s, 2 R73's take two pylons each, and four Kh-29's take one each per missile. Prices of them per pylon: [300, 3000, 600, 700], so total cost is 10400. However, as mentioned before each of the new weapon types, such as AirBombLauncher for the FAB250s, adds 1000$ to the price, thus with four weapon types giving us the final price of 14400$.
- Helicopters have modifiers of prices for missiles like the AIM-9/R-73, which makes them more expensive for that type of aircraft. Perhaps if we need to make helicopters with such missiles less accessible, we will up this modifier.
- The complete list of all the loadouts can be found here: https://github.com/Miksuu/a2waspwarfare/blob/master/Missions/%5B55-2hc%5Dwarfarev2_073v48co.chernarus/Client/Module/EASA/EASA_Init.sqf (updated always when a new version of the mission is deployed to the server)
**- This means that in the future, we will only change these values in the program and generate new loadouts with those, and inform you what values were changed. With this system, editing these values and exporting them to the game is very easy, so feel free to suggest any changes to the prices if you think that something's not priced correctly!**

**Identified issues (high priority fix in the near term): **
- For some aircraft with many pylons and available weapon combinations, the EASA list is quite huge. We'll implement a favourite loadout window to the EASA interface soon. For the meantime, since the loadouts are sorted by prices, you can memorise/write down the prices of your favourite loadouts.
~~- Sidewinders have very high reloading time per two shots now (they use the two round mags for the two pylons now)~~
~~- Mavericks still miss quite easily, we might just replace them quickly with Spike missiles utilising this system that I built.~~ (maverick parameters changed, spike change disregarded)
~~- BRDM (Igla) is missing in Takistan (I will fix this tomorrow)~~
- Camos are not the most optimal for every aircraft (for example, the takistani Su-25T has desert camo on both maps)
~~- Now that An-2 is on AF1 on both maps, to my knowledge, OPFOR does not have any AF2 aircraft. Perhaps we'll move ambu helicopters to that level for both factions, or such.~~

I'd like to thank you for community contributor for this brilliant idea and your spreadsheet to rework the whole air balance. 
Many thanks for @cleinstein helping to put it together.
And @DMR#1208 for helping me to implement all of this stuff in to the mission.

Remember to post your feedback in appropriate channels: #suggestions #balancing_discussion #bugs_and_issues. As I mentioned before, loadouts and the weapon prices are very easy to change now, so please don't hesitate!

We might host Tasmania by @quadxd next weekend just to test it out, so remember to download:
https://drive.google.com/file/d/1RuJAPTLG8L-DOeeYbThVnbuNsFKfZrp3/view?usp=sharing

Thanks, and have fun on the server enjoying the largest update so far (with its framework to make it happen)!

# v04082023 (Miksuu)

**-- Fixed bunch of inconsistencies on town depot soldiers like Machinegunner, Engineer and AT soldiers (Opfor ones). Soldiers and their Barracks level requirements from the depots:**
- Level 0: Rifleman, Medic, M136/RPG18 soldiers
- Level 1: Machinegunner, Engineer, RPG7 soldiers
- Level 2: [nothing for now, should we add something, any ideas? snipers?]
- Level 3: AA soldiers

**-- Fixed a bug where ground vehicle AI's with IR Smoke made a warning sound when player was not inside the vehicle**

@everyone 
We've been working on a huge Air Balancing patch with @DMR#1208, a community contributor and @cleinstein. Loadout generator is pretty much done, with the correct prices on the weapons. They can be found here: https://pastebin.com/DTEperMn . What do you think? To ensure we will get everything right, I think that we'll release this patch next week and have an air event on Saturday and perhaps briefly testing @quadxd 's new Tasmania map on Sunday. Repacked @a2waspterrainsv7 modpack can be found here: https://drive.google.com/file/d/1RuJAPTLG8L-DOeeYbThVnbuNsFKfZrp3/view?usp=sharing. Keys have been added to the server now, although the server might require a restart so don't enable these mods yet, and I think during non-events you should keep them off anyways, since they are not needed.

# v31072023 (Miksuu)

**-- Added a feature to tune the view distance with hotkeys. See: https://discord.com/channels/440257265941872660/1135891800373071894/1135897984945631272 **

Thanks for the idea to add a debounce feature for this @quadxd! 

**-- Fixed OPFOR not having any AT soldiers on the depots at B0, added RPG18 soldier for that level (RPG-7 soldiers are available from B1 level)**
Thanks for the reminder to fix this @rainbowbier !

# v25072023 (Miksuu)
**-- Add aircraft label (AAR2 feature) to its display name (e.g. Apache AH1) instead of its type name (e.g. BAF_Apache_AH1_D)**

**-- Lowered AAR Upgrade costs from 15000,35000 to 5000,12500**

**-- Lowered AAR Upgrade research times from 150,250 to 50,125**

**-- Increased AAR Upgrade refresh rates from 3,2,1 to 5,3,1 seconds.**
Thanks for the suggestion @DMR#1208!

**-- Lowered Artillery ammo upgrade cost from 2500,5250,9000 to 2500,3500,6000**

**-- Change the color of the airlifters in AF unit buy menu to make it so that it's not unreadable when clicked**

**-- Fixed the HF4 town defence groups having Tunguskas and Linebackers in them**
Thanks for the bug report @opftafel007 !

**-- Fixed light repair doing one useless cycle that didn't affect vehicle's health at all**

**-- Gave engineers ability to repair camps**
> Now every single class excluding SpecOps can repair camps, however I think I'll remove this feature from Snipers once they receive ability to mark factories with the spotting ability.

Thanks for the suggestion @malialek !

**-- Removed Satchel Charge and added grenades to the engineers starting loadouts**
Thanks for the suggestion @Blu#0925 !

**-- Replace binoculars with rangefinders on the snipers starting loadouts**

**-- Further paratrooper changes, merged my and 0=1's scripts so now the paratroopers will be visible in your group once the vehicle carrying them spawns in. This should fix the issue of them appearing as green dots in the map sometimes, if not, let me know!**

# v24072023 (Panovich, Miksuu)
**-- Added an optimization fix by Panovich from 2021 that should greatly increase Server and Client FPS**

**-- Takistan defences manning range increased from 250m to 300m (just like in Cherno)**

**-- Fixed Takistan slot that was labeled as Soldier, was a Spec Ops one. Takistan has now 5 blufor soldier slots (same as Opfor)**


Let me know how the server runs after this optimisation change, if it makes any difference.
Also we're planning to rework air balance completely, and will release the plan hopefully within a week or so. I have been working on a tool that generates loadouts for each of the planes (all combinations with the available weapons on the aircraft, price will be defined by the weapon launchers and ammunition cost that is defined in the files and total price will be calculated automatically) and it's almost ready. This will make creating the loadouts very easy and balancing EASA will become multiple times faster to work on.


# v20072023 (0=1, Miksuu, Quad)

**-- You can now buy gear from Ammunition Truck (LF2), additionally it's price was raised from $750 to $2750**

**-- Changes to the map markers:**
- Changed Ammunition Truck's icon on the map to be "Attack"-type red symbol.
- Repair Truck to brown color
- Artillery vehicles to pink
- Airlifters to white
- Salvage trucks to khaki

**-- Changes to the buy menu labels: **
- Airlifter labels are now marked as light blue color in the buy menu [Image 1]
- Ambulances as yellow
- Repair trucks as brown
- Ammunition Trucks as red
- Salvage trucks as green
- Artillery vehicles as purple
[Image 2]

**-- Fix town defences armoured vehicles not appearing in defender's towns when their Heavy Factory was on level 4**

**-- Change logic when ClientInitComplete is done to the end of Init_Client.sqf script**
> This shouldn't have any effect joining games, but if it does cause any issues let me now. Best case scenario, it fixes the bug that ruins a round every few months or so :D

Thank you for 0=1 for these contributions above! Much appreciated! :beers: 

**-- Changed SADARM artillery (Artillery Ammunition Upgrade level 3, from the Ammunition Truck) to target helicopters more efficiently. Additionally, Artillery Ammunition Upgrade Level 2's supply price was raised from 3500 to 5250, and Level 3 was raised from 4500 to 9000**
> This should help to deal with helicopter camping in bases where the supply points are. They are incentivised for more active gameplay, alongside with teamwork to build new supply points with your teams repair truck drivers + and commander to relocate bases to deal with the threat. Interested to see where this will go. Since this is such an experimental feature, please provide feedback on it, thanks! I have also added a vote about the artillery ammunition upgrade costs, check it out if you like to get that changed. https://discord.com/channels/440257265941872660/1116365031228063755/1131988888928407622

Thank you @quadxd for your brilliant idea, and for writing this script! :beers: 

**-- Added Anti Air Radar-upgrade [Image 3] with three different levels that's cost 15000 and 35000 supplies, with upgrade time of 150 and 250 seconds**
- Level 0 provides you with position, direction, and speed data of the enemy aircrafts, with 3 seconds refresh rate
- Level 1 adds altitude, lowering the refresh rate to 2 seconds.
- Level 2 adds the aircraft type and lowers the refresh rate to 1 second. See [Image 4]
> I have some further ideas to expand this feature, and add more end game upgrades to the game. See this post https://discord.com/channels/440257265941872660/1116365031228063755/1131989367007739996 for further information, and if you would like that the current price/refresh rate of the upgrades to be changed.

**-- Attempt fixing the runtime error of defence manning since it's last update**

> This is kinda still work in progress and further errors might appear in longer games, just let me know if it causes problems (should have 40 defences per base that won't be manned again once the AI operator is killed)

**-- Fix paratroopers not showing in the map as orange AI markers**

Thanks @cleinstein and 0=1 for the bug report.

**-- Raise AI limit from 14 to 16**
> https://discord.com/channels/440257265941872660/1116365031228063755/1131988526263713803 :AhShitHereWeGoAgain: 

**-- Added sound warning for incoming missiles on tanks with IR smoke upgrade researched**

**-- Fix Cherno OPFOR, Taki BLUFOR&OPFOR supply points wouldn't disappear in the script I introduced in v18072023**

**-- Fix that US Vehicle Paradrop is now a Repair Truck**

**-- Change label of Paradrop - Vehicle to Paradrop - Repair Truck in the WF menu**

**-- Raise Engineer repair script cooldown from 5 to 25 seconds**

**-- Fix all Engineer types having a fast repair option**

**-- Fix that 0 score players wouldn't grant any bounty**

**-- Fix OPFOR Engineer having error with it's GP_HE25 loadout (syntax error)**

**-- Add Pandur to the list of random vehicles that team can receive on the start**

![](https://cdn.discordapp.com/attachments/1116268624458547261/1131992221743317173/image.png)
![](https://cdn.discordapp.com/attachments/1116268624458547261/1131992222062100480/image.png)
![](https://cdn.discordapp.com/attachments/1116268624458547261/1131992222372483072/image.png)
![](https://cdn.discordapp.com/attachments/1116268624458547261/1131992222624120994/image.png)

# v18072023 (Miksuu)

**-- Possibly fixed a rare runtime error of base defences not manning**
> I imported a script from v50 version (Arma 3 mission by Spayker) that from my understanding of the code should fix this error. When headless client is working properly, the defences should be manned just like before (by units to running to them from the barracks). Otherwise without the HC, defences will be instantly manned. Since the bug was almost impossible to reproduce, let me know if it doesn't suddenly work and I'll check the log. Thanks. 

**-- Bought supply points with money will now be deleted once a base is down**
> I added this feature, because once you sold a base that had one of these supply points it caused a bug that the base area didn't stop counting. Since you can't sell that structure, this caused these base areas to exist that you couldn't get rid off. Do you want a feature for these bought service points to be marked on the map automatically when built, and being able to sell them. https://discord.com/channels/440257265941872660/1116365031228063755/1130681186977595502

**-- Added a sound warning for launched ICBM**
> We might add separate sounds for friendly and enemy launched ICBM's like: https://discord.com/channels/440257265941872660/445631540513210379/1118918119956684860 (created by @marty0007 ). Vote about it here: https://discord.com/channels/440257265941872660/1116365031228063755/1130679047425372190

**-- Added more advanced score counting system for killing factories**
> The formula for the reward is same than in the old mission: [bounty price] / 100 * 3. So for example HQ kill you will receive 900 points *(30000 / 100 \* 3),* and for barracks kill you will receive 90 points *(3000 / 100 \* 3)*. The difference being to the old mission version that you won't gain score for teamkilling a friendly MHQ.

> Neither more expensive units don't grant higher score (yet, want this feature? https://discord.com/channels/440257265941872660/1116365031228063755/1130679339504119898 )

**-- Since factory kills give score now, bounty modifier has been lowered from 7 to 4**
> Formula for total amount of received $ for each player kill: *100 + 4 \* [score of the killed player]*.

> Is this bounty amount too low in your opinion? Post about it in #suggestions .

**-- Replaced LAV-25 with Pandur as a starting vehicle of BLUFOR**
> This is a better counterpart for BTR-90 that OPFOR has on the start. It seems that reloading of the Spike launcher takes a while when not produced out from a factory, so when you get in to the vehicle, start the reload instantly so it will be most likely ready when you reach a town.

**-- Max Base AI limit has been raised from 12 to 14**
> Want this to be raised still from 14 to 16? Check https://discord.com/channels/440257265941872660/1116365031228063755/1130679025770180618

**-- Fix a bug that allowed commander to repair structures with 0 supply**
Thanks for the bug report @quadxd !

**-- Added two mags of 250 round to GSh-23 cannon of the MI-24P, just like in the old mission**

**-- Replaced RPG-18 soldiers with RPG-7 soldiers in the town depots, just like in the old mission**
Thanks for the suggestion @opftafel007 !

**-- Restrict using heal/repair function from a supply point or a town depot if the price is not more than 0 for that given unit**

**-- Enabled tablock for Shilka (just like any other AA vehicle)**

**-- Increased Stryker MC price from $2400 to $4200 in Chernarus, just like it is in Takistan**

*[Multiple commits by @miksuu between 13/07/2023 - 18/07/2023]*

Check the new #vote-suggestions and please discuss the newly added suggestions in their threads (create one if it doesn't exist). Thanks, and have fun on the server :KKalinka:

# v13072023 (Miksuu)

**-- Updated the Discord bot to have new features:**
- The current player count, max player count and current map are now visible on the <#1128390247965802599> message, and also on the bot's "playing"-status message which is visible on the members list of the discord server.
- Added uptime counter to the status message
- The game status message has it's embed color changing now depending on the current map
- The bot's status will now change also (Green/online = Chernarus, Yellow/away = Takistan)
*[Multiple commits by @miksuu on 12/07/2023]*

# v11072023 (Miksuu)

First of all I'd like to inform @everyone that, the rule 4 was changed to:
> 4. Stacking (pro players joining already better team) is not allowed. Veterans are expected to watch the <#1128390247965802599> channel before joining the game to help them determine which team to join based on the current score (and current veteran counts per teams, make your own judgement with this available data). Abusers of the system will be visible on the logs and will be banned.
*(More info after the patch notes)*

And rule 13 was removed:
> 13. Duping supply run missions is not allowed. (This will be monitored regularly and if someone exploits the feature, they'll receive a ban.)

Update **v11072023** has been applied to the server:

**-- Removed old, obsolete PersistanceDB causing syntax errors with its callExtension procedures**

**-- Created a callExtension framework for exporting data out of the game for usage such as Discord Bot see [Image 1] **

*[Multiple commits by @miksuu between 07/07/2023 - 12/07/2023]*

The current callExtension and Discord Bot features are very minimal right now, but they will be expanded over time.
Planned features are such as adding current map, uptime, player count (and a list later) and server fps to the status message.

Less priority (over SQF game mechanics programming and balancing the mission itself, depends on the feedback too):
- The current score system could be improved for giving players score for killing factories (just like it was before).
- Add #game-log channel to log when round starts and ends etc.
- Add a button to press to get a game recap via DM after the current round has ended (or having it as an option after discord ID's and GUIDs can be linked to each other).
- Add ELO system to measure individual player skill, add average ELO of the team to be visible on the status message.
- Create a self learning algorithm to give best estimate for the player on which team to join based on variables such as:
Team scores
Team average ELO points
Team upgrade levels (won't be visible, only affects the suggestion)
Only if necessary, and after weeks of monitoring the data the algorithm is producing, less strict Anti-stack might be implemented. By less strict I mean as if the team balance values are close to each other, it won't care which team you can join.

I hope that the current system will improve the balance of the games and let me know if you have any #suggestions where I should take it next. Your continuous feedback is very important for me to make most of the limited time for developing the mission.

Thank you @Rayswaycx#3767 for the **HUGE 250€** donation yesterday. This is the largest single donation that we have ever got (not taking in to account @rainbowbier 's and @eirik4461 's Patreon donations over time). Right now, with the current patreon support the server will be on for an indefinite amount of time.

![](https://cdn.discordapp.com/attachments/1116268624458547261/1128653118649938100/image.png)

# v06072023 (DMR, Quad, Miksuu)

**-- Added Pandur back to the mission**
**-- Added Dingo GL and MG variants back to the mission**
**-- Stryker MGS given an extra 6 APDS rounds **
*[Multiple commits by @DMR#1208 between 05/09/2020 - 06/10/2020]*

**-- Replaced the starting truck of BLUFOR with LAV-25 and on OPFOR with BTR-90**
> Perhaps LAV-25 could be replaced with Pandur to make a better counterpart for the BTR-90? -> https://discord.com/channels/440257265941872660/1116365031228063755/1126569690072887486
*[Commit by @quadxd on 23/10/2020]*

**-- Max Base AI limit has been raised from 10 to 12**
> We might make this limit higher in the future, based on the feedback. I've created a new vote https://discord.com/channels/440257265941872660/1116365031228063755/1126570971986395196 to raise it from 12 to 14 already, since with the current player numbers and the powerful server we have it should be a good change.

**-- Added current/maximum AI amount to the UI. See [Image 1]**
> The current implementation of it only shows the current AI's (not the ones being produced in factories). In the future I might add additional data to the UI of the units that have been queued, or create a different solution for this, we'll see.

**-- Added commander selection sound**

**-- Replaced all references of "AI Commander" with "No Commander" (since the AI commander has been deactivated)**

**-- Fixed OPFOR SpecOps class not having the correct ammunition on it's RPK weapon**

**-- Fixed MG Bipod issues related conflict with the Tablock script (Press TAB to deploy it while proning down with a machine gun!)**
> I think that there should be a feature when the player prones down with MG, that the bipod will be deployed automatically. -> https://discord.com/channels/440257265941872660/1116365031228063755/1126567798005575750

**-- Removed Wildcat from the mission due to it's rocket launcher causing game to crash**
> The vehicle will be reintroduced after it's loadouts have been reworked. I'll create a vote on https://discord.com/channels/440257265941872660/1116365031228063755/1126569670233829439 with a thread where you can suggest them. I was thinking something that with Ka-60 in the mission, we could maybe make AF2 a bit more relevant and perhaps adjust AF upgrade prices with it.

*[Multiple commits by @miksuu between 03/07/2023 - 06/07/2023]*

*other minor syntax fixes*

The merger comparison: https://github.com/Miksuu/a2waspwarfare/compare/48bccc0e44dd...e498d7adbfc9

Don't forget to vote + discuss the newly added suggestions in #vote-suggestions 
||And enjoy the incoming double @everyone  ping :stalin_ping:||

![](https://cdn.discordapp.com/attachments/1116268624458547261/1126573390422089828/image.png)

# v16062023 (Miksuu, Marty)

**-- Air balancing changes (re-introducing the Alca too!):**

-- Add a new BLUFOR jet, the L-159 Alca with cost of $28 900

-- Balance L-39's EASA loadouts accordingly to make it more balanced against the Alca, it's price is also now: $23 904 (FAB-250 guidance bug fix included)

-- Move AV-8B (LGB) from AF3 to AF4. It's new price is: $37 140, and adjust it's loadouts.

-- Move AN-2 from AF2 to AF1 in Takistan
*[Multiple commits by @miksuu on 13/04/2020 & on 20/08/2020 & on 06/11/2020]*

**-- Remove Humvee (TOW) from OPFOR town defences in Takistan and replace is with a SPG9 car instead**
*[Commit by @miksuu on 23/09/2020]*

**-- Added black arrow to show the direction of where the friendly players marked on the map are heading [Image 1]**

**-- AAR enemy aircraft marker is now a red arrow to show where the enemy aircraft is heading on the map [Image 2]**

*[Multiple commits by @marty0007 & @miksuu on 14/06/2023 & on 15/06/2023]*

**-- Change part of the message on the top right when the player joins the game (and the version)**

*[Commit by @miksuu on 15/06/2023]*

**-- Disabled script that enforces balance by number of players in the team (please balance the games by veteran number counts per team, thanks!)**

*[Multiple commits by @miksuu on 15/06/2023 & on 16/06/2023]*

*other minor syntax fixes*

The merger commit: https://github.com/Miksuu/a2waspwarfare/commit/ef38664475794f3c4cdaa75bec464387d35620d0

Thanks for your contributions towards the development of the mission @marty0007! Much appreciated! :beers:

![](https://cdn.discordapp.com/attachments/1116268624458547261/1119115880584990860/image.png)
![](https://cdn.discordapp.com/attachments/1116268624458547261/1119115880828239952/image.png)

# v13062023 (Miksuu)

**-- Add a Server FPS counter, located below the Client FPS one**

**-- Change "FPS Client" to "FPS:" now that Server FPS is added, reducing clutter, see [Image 1]**

**-- Add version to the message that is shown after loading in to the game is complete, see [Image 2]**

**-- Add Tablock for Humvee Avenger**
> Stinger and Igla manpads (including statics) up next!

*and other minor syntax fixes that won't be visible in game, hopefully :KEKW: *

*[Multiple commits by @miksuu on 13/06/2023]*

The merger commit: https://github.com/Miksuu/a2waspwarfare/commit/81bb68d76c2d440f882c0b3dda838979eecb9897

Feedback is always appreciated!

![](https://cdn.discordapp.com/attachments/1116268624458547261/1118167547951464589/image.png)
![](https://cdn.discordapp.com/attachments/1116268624458547261/1118167548161171507/image.png)

# v12062023 (Miksuu)

**-- Modify "Changelog" message on the top right when the player joins a slot, to be more appropriate and to inform the players about the current state of the mission**
*[Commit by @miksuu on 11/06/2023]*

**-- Remove default service point walls when built with supply from HQ**
*[Commit by @miksuu on 11/06/2023]*
Thanks for the suggestion @quadxd !

**-- Make HQ buy price to be consistently $200 000**
*[Multiple Commits by @miksuu on 13/02/2021 & on 11/06/2023]*

**-- Add speed and altitude marker to the Anti-Air Radar [Image 1]**
*[Multiple Commits by @miksuu on 11/06/2023]*

**-- TabLock now works for Air vehicles, and Anti-air ground vehicles (only Linebacker and Tunguska for now). On every other ground vehicle it is now disabled.**
> I will add vehicles such as Humvee Avenger to have ability to tablock later too, and perhaps manpads too
*[Commit by @miksuu on 11/06/2023]*

Here's the merge to the master branch (the code differences relative to the v08062023):
https://github.com/Miksuu/a2waspwarfare/commit/ffab7876ebc7b16e734a18b0c9fd27e77bcb529e

I've organised the task list a bit better now ([Image 2] & link on #trello-tasklist). The current task order is highly dependant on how fast the task can be completed and how much benefit it has for the mission. I've pushed the re-addition of the Alca and modifications to the loadouts of the aircrafts since this takes always a lot of time to test. But feel free to give feedback what is important to you. Have fun on the server, and thanks for the continued support!
*I swear this is the last @everyone ping before some major update.*

![](https://cdn.discordapp.com/attachments/1116268624458547261/1117777350852087839/image.png)
![](https://cdn.discordapp.com/attachments/1116268624458547261/1117777351124729917/image.png)

# v09062023 (Miksuu)

**-- AF building signs (where the aircraft will spawn) are now fixed for every faction**

**-- Default and maximum view distance is now 6 000 meters**

*[Multiple commits by @miksuu on 08/06/2023]*

Bipod still seems to have some issues, I'll look in to it.

Thanks for the suggestions so far. Keep them coming! Next up for the changes (current priority first from right to left and then up to down):

![](https://cdn.discordapp.com/attachments/1116268624458547261/1116696492862869595/image.png)

# v08062023 (Miksuu)

Hello @everyone! Since the recent attempt to take down my server by @ezcoo yesterday (more info in #general channel), today we'll start recovering the mission from its 2018 state and perhaps make it even better in a few months! I also realized that we've made several mistakes regarding the development in the past few years. Additionally, nowadays we have tools like GPT-4 available, so the development should be a lot easier, provided that these tools are utilized correctly. On the other hand, it's also a good way to start fresh. Although re-implementing some of the essential quality of life and balancing changes might take a few weeks, I'm willing to dedicate at least 10 hours per week to this project. Other contributions are welcome too. Just contact me, and I'll help you get set up for that (programming skills are not necessary, but certainly helpful).

**-- ICBM Enabled on Chernarus and Takistan**

**-- Increase the Max Supply Limit default value to 50 000**

**-- Change LF upgrade cost to: LF1 = 250, LF2 = 950, LF3 = 1 900, LF4 = 3 500**

**-- Move LAV-25 to LF3**

*[Multiple commits by @miksuu on 02/10/2018]*

**-- Add one more HF4 upgrade level with an upgrade time of 30:**

-- Move M2A2 Bradley from HF0 to HF1

-- Move M2A3 Bradley from HF1 to HF2

-- Move Fv510 Warrior from HF2 to HF3

-- Move M1A1 Abrams from HF2 to HF3

-- Move M270 MLRS from HF2 to HF3

-- Move M1A1 Abrams (TUSK) from HF3 to HF4

-- Move M6 Linebacker from HF3 to HF4

-- Move T-34 from HF0 to HF1

-- Move BMP-2 from HF0 to HF1 (its rocket launcher will now be available on HF2 as well, instead of HF1)

-- Move T-55 from HF1 to HF2

-- Move ZSU-23 Shilka from HF2 to HF3

-- Move T-72 from HF2 to HF3

-- Move BMP-3 from HF2 to HF3

-- Move T-90 from HF3 to HF4

-- Move 2S6M Tunguska from HF3 to HF4 

*[Multiple commits by @miksuu on 03/10/2018]*

**-- Move AW159 Wildcat from AF4 to AF3 and reduce its price from 38 692 to 29 692**

**-- Change default starting range distance from 6 500 to 7 500 meters**

*[Multiple commits by @miksuu on 04/10/2018]*

**-- Change ICBM Dependency from AF3 to AF5**

*[Commit by @miksuu on 07/10/2018]*

**-- Change default view distance from 4 000m to 5 000m**
> Should we try increasing this to 6 000m so objects render to 3 000m to match the distance the radar sees and the missiles fly, since the hardware available nowadays is so much more powerful than back then? (added to the backlog)

**-- Fix Missile Glitch on Chernarus by taking the script file from Takistan files**

*[Multiple commits by @miksuu on 23/10/2018]*

**-- Fixes to artillery prices in Takistan:**

-- Grad price changed from $7 800 to $6 800

-- M1129 Stryker Mortar Carrier price changed from $2 400 to $4 200
> I will confirm later that these prices are matches in Chernarus too (added to the backlog)

*[Commit by @miksuu on 14/10/2019]*

**-- Add a Remote Unflip feature**

*[Commit by @miksuu on 15/10/2019]*

**-- Fix AF building sign in Takistan (for only the US side??)**
> Will need to check that these later (high priority on the task list)

**-- Add "Five minutes to impact"-warning to the ICBM message**
> Semi high priority to recover the sound on the backlog, any audio file suggestions?

**-- Change bounty modifier from 11 to 7 **
> Might need some tuning, especially now that we are missing the advanced score system with building kill score rewards (provide feedback please)

** Changed FR_R soldier slot to FR_Miles in Chernarus, fixing the fast repair bug **
> There might be some slots left that have this feature still, if you see it, be sure to post about it on the #suggestions / #bugs_and_issues channel

*[Multiple commits by @miksuu on 27/10/2019]*

**-- Fix Takistan bipod issues**
> Will investigate Chernarus later too

*[Commit by @miksuu on 06/03/2020]*

**-- Remove Humvee Avenger from the start vehicle list**

*[Multiple commits by @miksuu on 10/03/2020 and on 21/03/2020]*

**-- Fix Takistani Blufor having only four Soldier slots**

*[Commit by @miksuu on 22/03/2020]*

**-- Fix Soldier slot description on Takistan **

**-- Change a spec ops slot to a soldier one **
> Let me know if there's any further issues with the slots

*[Multiple commits by @miksuu on 26/03/2020]*

**-- Fix artillery reload timings on the stringtable (that shows in the game)**

*[Commit by @miksuu on 31/03/2020]*

Next up on the task list (available in #trello-tasklist ):

![](https://cdn.discordapp.com/attachments/1116268624458547261/1116307944485691392/image.png)