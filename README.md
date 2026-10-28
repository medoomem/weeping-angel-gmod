# All console variables

Set them in the server console or rcon, for example `weepingangel_speed 300`. They are saved automatically. The same options are in the Q menu under Utilities > Weeping Angel > Settings (superadmins can change them).

## Hunting

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_speed` | 400 | Full speed of the angel in units per second while unobserved (player run speed is about 400). |
| `weepingangel_patience` | 25 | Seconds of unobserved haunting before the angel is ready to strike. Randomised by about 30% per angel. |
| `weepingangel_allow_touch` | 1 | 0 = angels only scare and never touch you. 1 = they eventually strike. |
| `weepingangel_touch_mode` | 0 | 0 = a touch sends you back in time (teleport). 1 = a touch kills. |
| `weepingangel_instant_move` | 1 | 1 = the angel moves the moment nobody is looking, with no cooldowns. |
| `weepingangel_smart_target` | 1 | 1 = with several players, the target is picked by distance, who looked away most recently and who was scared least recently. |
| `weepingangel_lag_comp` | 1 | 1 = the visibility cone grows with camera turn speed and ping, so you do not see it move during fast turns or lag. |
| `weepingangel_fit_space` | 1 | 1 = teleport distances shrink to the size of the room, and the angel keeps off walls and props. |
| `weepingangel_max_range` | 4000 | An angel can only teleport to a player within this many units (0 = no limit). |

## Scares

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_scares` | 1 | 1 = angels sometimes appear very close behind you with their hands out. |
| `weepingangel_scare_scale` | 1 | Multiplier for the delay between scares (0.1 = very frequent, handy for testing). |

## World

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_angel_lock` | 1 | 1 = angels freeze each other when they can see each other. |
| `weepingangel_bots_see` | 0 | 1 = bots count as observers and targets. Off by default because bots stare at nothing and would freeze the angels. |
| `weepingangel_lights` | 1 | 1 = angels flicker and blow out nearby lights. |
| `weepingangel_breadcrumbs` | 1 | 1 = angels follow footsteps around corners. |
| `weepingangel_move_sounds` | 0 | 1 = faint stone grinding sound when the angel moves. |
| `weepingangel_aspect` | 1.7778 | Widest screen aspect ratio among your players (16:9 = 1.7778, 21:9 = 2.3333, 32:9 = 3.5556). Widens the "can see" cone. |

## Dormant statues (applies to angels spawned after the change)

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_dormant` | 0 | 1 = new angels spawn as still statues until they wake. |
| `weepingangel_dormant_wake_dist` | 500 | A dormant angel wakes when a player comes within this many units. |
| `weepingangel_dormant_wake_time` | 0 | A dormant angel also wakes by itself after this many seconds (0 = never). |

## Feeding

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_feeding` | 0 | 1 = every successful touch makes that angel hungrier (faster tension, longer light draining reach). |
| `weepingangel_feeding_step` | 0.15 | How much shorter its patience gets per touch (0.15 = 15%, stacking). |
| `weepingangel_feeding_max` | 5 | Maximum number of touches an angel remembers. |

## Double touch

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_double_touch` | 0 | 1 = a second touch soon after the first kills the victim. |
| `weepingangel_double_touch_window` | 90 | Seconds after a touch during which the next touch is lethal. |

## Past-era filter

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_past_filter` | 1 | 1 = sepia filter after being cast back in time. |
| `weepingangel_past_filter_time` | 8 | How many seconds the filter lasts. |

## Flashlight blink

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_flashlight_drain` | 1 | 1 = a close angel can make your flashlight blink slowly and then blow it out. |
| `weepingangel_flashlight_dist` | 450 | How close the angel has to be to start (units). |
| `weepingangel_flashlight_block` | 5 | Seconds the flashlight stays dead after it is blown out. |
| `weepingangel_flashlight_blackout` | 0 | 1 = the whole screen goes black with every blink. |

## TARDIS mod

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_tardis_shelter` | 1 | 0 = ignore the TARDIS mod. 1 = safe inside a TARDIS whose shields are on. 2 = safe inside any TARDIS. |
| `weepingangel_tardis_siege` | 3000 | Angels with nobody else to hunt wait at the door of a TARDIS within this many units (0 = off). |
| `weepingangel_tardis_knock` | 1 | 1 = one angel per TARDIS knocks on the door. Pounds on it if it is locked. |
| `weepingangel_tardis_knock_volume` | 0.7 | How loud the knocking and pounding is (1 = full). Also scales the screen shake inside. |
| `weepingangel_tardis_door_look` | 1 | 1 = an open door only freezes angels outside while someone inside is looking through it. 0 = anyone inside with the door open counts as watching. |
| `weepingangel_tardis_grace` | 8 | Seconds after leaving a TARDIS during which angels cannot touch you (they can still move and scare you). |

## Darkness (experimental)

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_darkness` | 0 | 1 = a player cannot see an angel standing in the dark, so it moves freely there. |
| `weepingangel_dark_level` | 0.009 | Light level (0 to 1) below which an angel counts as standing in the dark. The debug overlay shows the measured value, so tune it per map. |
| `weepingangel_dark_flashlight` | 1 | 1 = your flashlight lights up an angel it points at, so you can still see it in the dark. |

## Debug

| Variable | Default | What it does |
| --- | --- | --- |
| `weepingangel_debug` | 0 | 1 = shows the debug overlay to admins and prints each angel's state to the server console once per second. |

## Commands

| Command | What it does |
| --- | --- |
| `weepingangel_tardis_info` | Admin only. Stand inside a TARDIS and run it. Prints what the addon can read from the TARDIS mod (door, doorway, shields, sheltered or not) and the state of every nearby angel. Include the output in bug reports. |
