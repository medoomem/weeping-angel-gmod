# Weeping Angel for Garry's Mod

An edit of the Weeping Angel (Multiplayer Support!) workshop addon. The angel only moves when nobody is looking at it. I reworked how it sees, hunts and targets players, and added TARDIS mod support.

I made this to hand back to the original authors. If you made the original and want these changes, take them. Everyone else: if you post this on the Workshop, credit the people below and link their page.

## What changed

- Multiplayer targeting by distance, who looked away most recently, and who it hasn't scared lately
- Lag compensation, so fast camera turns and high ping never show it moving
- It moves the moment nobody is looking, with no cooldowns
- Teleport distances fit the room, and it keeps off walls
- Flashlight blink (optional blackout), dormant statues, feeding, double touch
- Settings panel in the Q menu: Utilities > Weeping Angel > Settings
- TARDIS mod support: shelter inside, angels wait and knock at the door, open door and follow rules

Every option has its own console variable (`weepingangel_...`) and can be switched off.

## Install

Put the `weepingangel` folder contents into `garrysmod/addons/<any name>/`, so the paths look like:

```
addons/weeping angels/lua/entities/weepingangel/init.lua
addons/weeping angels/lua/autorun/client/weepingangel_client.lua
```

Or download the `.gma` from Releases and put it in `garrysmod/addons/`. The angel models and materials are not in this repository.

Spawn it from the Entities tab.

## Credits

- Original Weeping Angel addon: Doctor, holy holy goldy (GoldyTX), CyberNovaDW
- Earlier addons it builds on: Mr.blue, TSEG, Doctor amigos
- Angel model and textures: The Sniper 9
- TARDIS mod: AmyJeanes and contributors
- Weeping Angels created by Steven Moffat for Doctor Who. Fan made, not affiliated with the BBC.

Original Workshop page: https://steamcommunity.com/sharedfiles/filedetails/?id=3618646793
