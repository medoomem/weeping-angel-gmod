# Weeping Angel for Garry's Mod

> **This is not on the Steam Workshop.** I can't publish there because my Steam account is limited. Download it here instead:
> **[Download the latest release](https://github.com/medoomem/weeping-angel-gmod/releases/latest)** (a `.gma` file you drop into your `addons` folder), or use **Code > Download ZIP** at the top of this page.

An edit of the [Weeping Angel (Multiplayer Support!)](https://steamcommunity.com/sharedfiles/filedetails/?id=3618646793) workshop addon. The angel only moves when nobody is looking at it, it freezes when it is seen, and it freezes other angels that see it. If it gets hold of you, it sends you back in time.

I reworked how it sees, hunts and targets players, and added TARDIS mod support. I made this to hand back to the original authors. If you made the original and want these changes, take them. Everyone else: if you post this on the Workshop, credit the people listed under Credits and link their page.

## Install

**From the release:** put `weepingangels.gma` in `garrysmod/addons/` and restart the game.

**From the ZIP:** put the `weeping angels` folder in `garrysmod/addons/`. The paths should end up like this:

```
garrysmod/addons/weeping angels/lua/entities/weepingangel/init.lua
garrysmod/addons/weeping angels/lua/autorun/client/weepingangel_client.lua
```

Spawn it from the Entities tab. For a dedicated server, put the same folder (or the `.gma`) in the server's `addons` folder. Clients download the models and materials automatically.

## Settings

Q menu, Utilities tab, **Weeping Angel > Settings**. Everyone can see the values, only superadmins can change them. Changes apply instantly and are saved. Every option is also a console variable, listed in [CONVARS.md](CONVARS.md).

## Features

- **Quantum lock.** The angel only moves while no player can see it. Visibility uses each player's real field of view (widescreen and zoom included), line of sight and walls.
- **Angels lock each other.** Angels that can see each other freeze, as in "Blink".
- **Hunting.** It picks a player, follows their footsteps around corners and gets closer every time you look away. When its patience runs out it strikes.
- **Instant movement.** The moment you stop looking, it moves. No cooldowns, no safe window after a blink.
- **Scares.** Now and then it appears right behind you with its hands out.
- **Time travel touch.** A touch sends you to another spot on the map with a sepia filter. Optionally the touch kills.
- **Multiplayer targeting.** Picks a target by distance, who looked away from it most recently, and who it has not scared lately. Angels avoid piling onto the same victim.
- **Lag compensation.** The visibility cone grows with camera turn speed and ping, so fast turns and lag never show it moving.
- **Room fitting.** Teleport distances shrink to the room you are in and it keeps a gap from walls and props.
- **Flashlight blink.** A close angel makes your flashlight blink slowly and then blows it out. Optional screen blackout on each blink.
- **Light draining.** Nearby lights flicker and blow out.
- **Darkness (experimental).** An angel standing in the dark cannot be seen, so it moves freely there. Your flashlight lights up what it points at.
- **Dormant statues.** Angels can spawn as still statues that wake when a player gets close or after a set time.
- **Feeding and double touch.** Each touch makes an angel hungrier. A second touch soon after the first can be lethal.
- **Sonic Screwdriver.** With the Sonic Screwdriver SWEP, primary fire locks an angel in time and secondary fire releases it.
- **Protection.** Angels cannot be grabbed with the physgun or gravity gun, unfrozen, or hit with tools.

## TARDIS mod support

Optional. Works with the [TARDIS mod](https://steamcommunity.com/sharedfiles/filedetails/?id=307175678). Without it the angels behave as normal.

- **Shelter.** Players inside a TARDIS are left alone. Mode 1 protects while the shields are on, mode 2 protects inside any TARDIS, mode 0 turns it off.
- **Waiting at the door.** With nobody else to hunt, angels walk to the TARDIS door and wait. Several angels line up in a curve around it.
- **Knocking.** One angel per TARDIS knocks using the mod's own sounds. If the TARDIS is locked it pounds on the door and the interior shakes.
- **Open door rule.** With the door open, angels outside only freeze while someone inside is looking at the doorway.
- **Following in.** An angel can only follow you in through a closed door, and not right after you step in. You get a few seconds of grace after leaving where it cannot touch you.

## Main console variables

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_speed` | 400 | Angel speed in units per second while unobserved. |
| `weepingangel_patience` | 25 | Seconds of haunting before it strikes. |
| `weepingangel_allow_touch` | 1 | 0 = scares only, never touches. |
| `weepingangel_touch_mode` | 0 | 0 = touch sends you back in time. 1 = touch kills. |
| `weepingangel_max_range` | 4000 | Max distance it can teleport to a player (0 = unlimited). |
| `weepingangel_angel_lock` | 1 | Angels freeze each other. |
| `weepingangel_aspect` | 1.7778 | Widest player screen ratio (21:9 = 2.3333, 32:9 = 3.5556). |
| `weepingangel_dormant` | 0 | New angels spawn as dormant statues. |
| `weepingangel_flashlight_drain` | 1 | Angels blink and blow out your flashlight. |
| `weepingangel_darkness` | 0 | Angels in the dark cannot be seen (experimental). |
| `weepingangel_tardis_shelter` | 1 | 0 = off, 1 = safe with shields on, 2 = safe in any TARDIS. |
| `weepingangel_tardis_knock` | 1 | An angel at the TARDIS door knocks. |
| `weepingangel_debug` | 0 | Admin debug overlay above each angel. |

The full list is in [COMMANDS.md](COMMANDS.md).

## Tips

- `weepingangel_scare_scale 0.1` makes scares frequent for testing.
- On an ultrawide? Set `weepingangel_aspect` to the widest ratio among your players.
- The darkness option depends on map lighting. Tune `weepingangel_dark_level` with the debug overlay on.

## Credits

- Original Weeping Angel addon: Doctor, holy holy goldy (GoldyTX), CyberNovaDW
- Earlier addons it builds on: Mr.blue, TSEG, Doctor amigos
- Angel model and textures: The Sniper 9
- TARDIS mod: AmyJeanes and contributors
- Weeping Angels created by Steven Moffat for Doctor Who. Fan made, not affiliated with the BBC.

Original Workshop page: https://steamcommunity.com/sharedfiles/filedetails/?id=3618646793

Bugs and suggestions: open an issue on this repository.
