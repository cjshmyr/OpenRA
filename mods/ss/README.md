# Sole Survivor

### About
This is an attempt to document the gameplay and technical details behind the C&C game known as Sole Survivor. Sole Survivor is unlike other C&Cs at the time -- rather than establishing a base and buiilding up forces, the played controlled a single unit of choice among dozens of other players in an online setting. The game modes varied, favoring more deathmatch-style or objective based gameplay. The player's unit will encounter crates along its path containing upgrades - or danger - as you wage war with allies and enemies. The SS universe is that of Tiberian Dawn's, as the game's assets are almost entirely composed of the original C&C's

The original SS at this point in time simply cannot be played online, even though there have been a attempts by others to create a dedicated server, it hasn't happened. The largest amount of resources we have right now for SS is purely from the files, the Offline Practice mode within SS, videos, pictures, and reasonable conjecture from people.

All sole survivor information is being gathered on a patched (version 1.05) version. A considerable amunt of information can also be found on cnc-comm in the Sole Survivor subforum.

#### Official Patches
There is a sole survivor patch that upgrades from version 1.00 to 1.05, which contains a myriad of changes detailed in a changelog added with the patch. There is plenty in those notes that are not docuemnted here and it definitely deserves a peek [here](https://github.com/cjshmyr/OpenRA/tree/ss-master/mods/ss/dev/ssnews.txt).

### Gameplay
##### Game modes
There are five game modes, more details can be found in the ssnews.txt file linked above.
- Capture The Flag (CTF)
- Football
- Human vs. Hunter (HvsH)
- Free-For-All (FFA)
- Team Fight

Interestingly none of the maps have any base defenses on them, the logic as to how flags spawn, where they sapwn, and where bases spawn on the maps is unknown to me at this time.

##### Basics
Ingame there is a help page covering the basics, seen [here](http://i.imgur.com/kubxMqX.png). It highlights the basics such as crates, base defenses, and game modes objectives.

##### Unit behavior
On spawn, the player's unit is invisible for ~30 seconds.
Five stats could be upgrade for a vehicle several times until maxed out: Move Speed, Attack Speed, Attack and Vision Range, Rate of Fire, and Armor.

##### Crates
There are five different types of crates. A list of crates you can encounter during the game can be found [here](http://www.cnc-source.com/?page=content/ss/ssmisc).

##### Units
The player is allowed to pick from any land unit (QUESTION: At the start of the game only, or during the game?). A list of playable units can be found [here](http://www.cnc-source.com/index.php?page=content/ss/ssunits).

##### Rules.ini
Rules this time live within the executable, so it's a bit trickier to find stuff out. This may be because the game isn't really extendable.

##### Offline practice
There's an offline practice mode available, where you can practice solo on a randomly chosen map against 0-10 AI players, who are all against you. They also will never lose sight of you no matter how far you run. Interestingly, even though it's a timed deathmatch, enemy base defenses can pop up. The base defense behavior is currently unknown to me at this time.

#### Online servers
There are a *lot* of varying server configurations, this isn't yet documented but the information about this is scattered. The settings could range from game mode, ion storm danger, time limit, kill limit, number of CTF structures, number of football flags, which types of crates could drop, so on.

By pressing F2 in Sole Survivor, the "game parameters" can be seen. In Offline Practice this is displayed:
```
You are playing in the Offline Practice channel.
Crates Ratio is 1000 Wooden : 0 Steel : 0 Green : 0 Orange
Armageddon is NOT possible
You do NOT lose invulnerability when you pick up an orange crate.
This is NOT a ladder game.
There is a Time limit of 15 minutes.
There is NO Score limit.
There is NO Life limit.
TeamCrates are OFF.
There is NO Ion Cannon.
Map reshroud is ENABLED.
Radar is NOT provided free to everybody.
Healthbars are shown only for YOU.
Hunters are NOT matched to the numbers of players.
Hunters are introduced according to these numbers: (u)120/10, (b)120/3
```
Notes:
- Armageddon is the fifth, red crate
- Ion Cannon is refers to Ion Storm, a factor where by the more crates you picked up, the higher chance you had of being zapped by an ion cannon.

And also online, players could join a game in progress!

### MIX Files
The MIX files used by Sole Survivor are a combination of files on the disk, and installed to the hard drive (extracted from the Setup.Z file). It's unknown to me at this time what version the C&C files are. 

**Re-used CNC mixes**:
aud.mix, conquer.mix, deseicnh.mix, desert.mix,  general.mix, local.mix,  sounds.mix, speech.mix, temperat.mix, tempicnh.mix, update.mix, updatec.mix, winter.mix, wintericnh.mix.

**New SS mixes**:
scores.mix, sole.mix, soledisk.mix

### SS Exclusive MIX Files

##### scores.mix
Contains 10 audio tracks exclusive to Sole Survivor. These audio tracks were also found on the N64 version of Red Alert.
```
mudremx: Mud (Remix)
drill: Drill
creeping: Creeping Upon
crshnvox: Crush (Remix)
workremx: Workmen (Remix)
depthchg: Depth Charge
hellnvox: Hell March (Remix)
ironfist: Iron Fist
mercy98: No Mercy '98
map1: Map Theme
```


##### sole.mix
Contains new UI art, crate pickup sound fx, crate effects art, crate art, as well as dinosaur sounds and art.

##### soledisk.mix
Contains maps, and audio for four different announcer sound packs. The announcer packs are a feature new to SS, they narrarated the game as it went on depending on events (crate pickups, death, etc). The names of the announcers are EVA, Commando, Let's Make a Kill, 1-900-KILL-YOU. There is a fifth unused announcer pack on the disk which appears to be Frank Klepacki guitar riffs.

### Reading the MIX files
When reading the MIX files through XCC mixer they all have an 8 character name, or the assets don't show up in OpenRA's engine. This is because both rely on a global mix database.dat which does not contain entries for the Sole Survivor assets. To properly reference/view them, a mapping can be found [here](https://github.com/cjshmyr/OpenRA/blob/ss-master/mods/ss/MIX%20FILE%20MAPPING.txt). Others have also attempted to add in Sole Survivor assets to the database themselves, but I have found those files incompleted compared to the mentioned mapping above.

Example
```
ID		    Filename        Description
A6064500	MUDREMX.AUD	    MUD Remix
```

### Maps
There are 29 maps included with Solve Survivor, which also get updated with the latest 1.05 patch. One of the maps imported into OpenRA can be seen [here](http://i.imgur.com/PhWHZth.png). All of the original maps, and a powershell script used to convert them to OpenRA's TD mod en masse, can be found [here](https://github.com/cjshmyr/OpenRA/tree/ss-master/mods/ss/dev).

### Map waypoints / spawnpoints
Of the 29 maps, only 10 of them had a name, while the remaining 19 remained unnamed. There is some subtle differences between the two.

- Maps with a name have anywhere from 4-8 spawn points defined. If the map is opened in the an editor it can be observed it has waypoints also defined. This implies  waypoints and spawns were dual purposed for spawns.

- Maps without a name had 8 player spawns properly set up, potentially with more waypoints.

SS supported up to 4 teams max (orange, blue, ???, grey), so the other spawns may have been utilized for gameplay purposes (such as CTF bases), but it's unknown at this time.

### Map binary file
The map format is slightly different from C&C's.

```
Mod             Map Size    File Size
C&C             64x64       8192 kb
Sole Survivor   128x128     {varies}
```

C&C bin files are a constant 8192 kb - the file defines tiles for every X,Y coordinate in the map. SS maps are a different case and they all vary in size. The presumption is because back then disk space was a bit more sacred, and rather than ship ~1.6MB sized maps, they changed the format up.

Example:

A C&C map binary beginning with bytes `` 9C OO | 8D OO | 9D OO | 8D O1 ``, means at ``0,0`` the *terrain type* and *tile index* map up to ``9C`` and ``00`` respectively, continuing until the 64x64 table is complete. There are plenty of resources on the format online.

A SS map binary beginning with bytes `` 9C OO 8D OO | 9D OO 8D O1 ``, means at coordinate ``9C,00``, the *terrain type* and *tile index* map to ``8D`` and ``00`` respectively. Any parts where an X,Y is not specified this means use the default terrain tile (grass, desert). When importing maps into OpenRA, we have to multiply the Y byte's integer value by 2 to have a proper map created.

### Map ini file
The INI format is mostly the same between C&C and SS -- differences noted so far:
- 99 player definitions exist.

### Is this everything?
No -- this document is missing a lot.