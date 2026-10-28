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

Q menu, Utilities tab, **Weeping Angel > Settings**. Everyone can see the values, only superadmins can change them. Changes apply instantly and are saved. Every option is also a console variable, listed in [COMMANDS.md](COMMANDS.md).

## Features

### The angel itself

- **Quantum lock.** The angel only moves while no player can see it. Visibility uses each player's real field of view (widescreen and zoom included), line of sight and walls. Set `weepingangel_aspect` for ultrawide players.
- **Angels lock each other.** Two angels that can see each other freeze, as in "Blink". You can use that to trap one. Turn it off with `weepingangel_angel_lock`.
- **Instant movement.** The moment nobody is looking, it moves. No cooldowns, so there is no safe window right after you look away.
- **Hunting.** It picks a player, follows their footsteps around corners, and gets closer every time you look away. Haunting builds tension. When its patience runs out (`weepingangel_patience`, 25 seconds by default, random per angel) it strikes.
- **Close-range scares.** Now and then it appears right behind you with its hands out the moment you turn.
- **Time travel touch.** A touch sends you to another spot on the map and gives you a sepia filter for a few seconds. `weepingangel_touch_mode 1` makes the touch kill instead.
- **Room fitting.** Teleport distances shrink to the room you are in, and it keeps a gap from walls and props instead of standing glued to them. It will not end up behind a wall.
- **Max range.** An angel only teleports to players within `weepingangel_max_range` units (4000 by default). The one exception is a player in a TARDIS the angels are allowed to follow into.
- **Protection.** Angels cannot be grabbed with the physgun or gravity gun, unfrozen, or hit with tools and properties.
- **Sonic Screwdriver.** With the Sonic Screwdriver SWEP, primary fire locks an angel in time and secondary fire releases it. It will not be pleased.

### Multiplayer

- **Smart targeting.** With several players the angel does not stick to the first one it chose. It scores each player by distance, who looked away from it most recently, and who it has not scared lately, and picks the best one. The player who looks away last gets its attention.
- **Spread out.** Angels avoid piling onto the same victim.
- **Lag compensation.** The "can see it" cone grows with how fast you are turning and with your ping, so a fast camera turn or a laggy connection never shows the angel mid-move.
- **Dedicated server ready.** A settings panel in the Q menu, with every option also a console variable. Only superadmins can change them, and changes apply instantly.

### Darkness and light

- **Flashlight blink.** A close angel makes your flashlight blink slowly a few times, then blows it out. It stays dead for 5 seconds. `weepingangel_flashlight_blackout 1` also blacks out the screen with each blink.
- **Light draining.** Nearby lights flicker and blow out.
- **Darkness (experimental).** An angel standing in the dark cannot be seen, so it moves freely there. Your own flashlight lights up what it points at. Tune `weepingangel_dark_level` per map with the debug overlay on.

### Extras you can switch on

- **Dormant statues.** New angels spawn as still statues with covered faces. They wake when a player comes within `weepingangel_dormant_wake_dist` units, or after a set time.
- **Feeding.** Each successful touch makes that angel hungrier. It builds tension faster and its light draining reaches further (15% per touch, up to 5 touches).
- **Double touch.** A second touch within 90 seconds of the first is lethal.

### Tools for server owners

- **Debug overlay.** Admins see each angel's mode, tension, distance, who it targets, why it is frozen, flashlight state and TARDIS status. Turn it on with `weepingangel_debug 1`.
- **`weepingangel_tardis_info`.** Run it inside a TARDIS to print what the addon can read from the TARDIS mod. Include the output in bug reports.

## TARDIS mod support

Optional. Works with the [TARDIS mod](https://steamcommunity.com/sharedfiles/filedetails/?id=307175678). Without it the angels behave as normal.

### Shelter

- Players inside a TARDIS are left alone. `weepingangel_tardis_shelter` sets how: **1** protects while the TARDIS shields are on, **2** protects inside any TARDIS, **0** turns it off.
- Angels stay outside instead of teleporting into the interior, and an angel already inside is cleared out so it never gets stuck in the walls or the void around the interior.
- Flashlight blinks and blackouts stop while you are sheltered.
- Players who are sheltered are not counted as targets, so angels turn to other players.

### Waiting at the door

- With nobody else to hunt, angels walk to the front of the TARDIS door and wait there, but only while nobody is looking at them. The range is `weepingangel_tardis_siege` (3000 units by default, 0 turns it off).
- The door side is worked out from the mod's doorway data and from where players walk in and out.
- With several angels, they line up in a curve around the doorway instead of crowding one spot.
- If the way is blocked, the angel appears in front of the door while unseen.

### Knocking

- One angel per TARDIS knocks, so there is never a chorus. It uses the mod's own knock sounds.
- If the TARDIS is locked it pounds on the door with the mod's banging sound, and the interior shakes.
- `weepingangel_tardis_knock` turns it off and `weepingangel_tardis_knock_volume` sets the loudness (0.7 by default).

### Doors

- **Open door rule.** With the door open, angels outside only freeze while someone inside is actually looking at the doorway. Someone standing inside with their back to the door does not count as watching. Turn this off with `weepingangel_tardis_door_look`.
- **Following in.** An angel can only follow you into a TARDIS through a closed door, and not in the first seconds after you step in. This stops it from disappearing when you walk in through an open door.
- **Grace after leaving.** For 8 seconds after you step out (`weepingangel_tardis_grace`), the angels can still move and scare you, but they cannot touch you.

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
