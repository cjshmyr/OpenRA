Hello!

About - This mod was based off of OpenRA's Tiberian Dawn mod with the intent of re-creating the original Sole Survivor (SS). The original SS heavily used assets from the original CNC, with a few extra assets of its own - mostly sounds, music, with just some art. However this comes with some difficulties, the current version of SS isn't playable online at all except for an offline practice mode, so research is purely from files at this point or reasonable conjecture from people.

FYI - All sole survivor information is being gathered on a patched (version 1.05) version of SS.

Assets (MIX files) - All assets used originate from the Sole Survivor disk (several MIX files), as well as the install folder from the unpatched version. This is in attempt to supply any patched content in the /bits/ directory and allow CD installs.

Inside MIXes - Note that through XCC mixer, there are some garbage names for the assets shown. See the MIX FILE MAPPING txt file for more information.

Map Format - Unlike CNC's 64x64 maps, the SS maps are 128x128. And unlike CNC which includes bytes for every tile in a map, SS will only include (in no particular order) bytes for tiles that are used. This means an additional two bytes are used to specify the x,y. This is likely an attempt to save file space in the past.

Maps on CD - All maps have been extracted from the MIX and properly renamed, inside of a /dev/ folder already.

Game Balance - It seems that patch 1.05 introduced some balance changes, so it should be expected not to mirror the original perfectly. Still researching original balance values. The actual balance lives inside of the EXE, so the best we can do at this time is mimic how the game feels in Offline mode.