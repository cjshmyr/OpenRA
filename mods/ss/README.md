Hello!

About this mod - This mod was based off of OpenRA's Tiberian Dawn mod with the intent of re-creating the original Sole Survivor (SS). The original SS heavily used assets from the original CNC, with a few extra assets of their own - mostly sounds, music, with just some art. However this comes with some difficulties, the current version of SS isn't playable online at all except for an offline practice mode, so research is purely from files at this point or reasonable conjecture from people.

All sole survivor information is being gathered on a patched (version 1.05) version of SS.

Map Format - Unlike CNC's 64x64 maps, the SS maps are 128x128. And unlike CNC which includes bytes for every tile in a map, SS will only include (in no particular order) bytes for tiles that are used. This means an additional two bytes are used to specify the x,y. This is likely an attempt to save file space in the past.

Maps on CD - They have odd hex names, but the INI & BIN files are in alphabetical order. This means that IE18E5F8 and 1E1DE0F1 are partners, and so on. Some of the maps don't seem to have names either. All maps have been extracted from the MIX and properly renamed, inside of a /dev/ folder already.