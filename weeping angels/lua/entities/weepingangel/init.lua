-- ========================================================
-- Weeping Angel (server side)
--
-- Hard rules (quantum lock):
--   * While ANY player (or another angel) can see it, the angel does
--     absolutely nothing: no movement, no rotation, no model change,
--     and its hunting clock is paused too.
--   * It only moves to a spot that is also not observed.
--   * Pose / rotation only ever change on ticks where it is unobserved.
-- ========================================================

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

-- --------------------------------------------------------
-- ConVars (change live from the console / server.cfg)
-- --------------------------------------------------------
local cvSpeed       = CreateConVar( "weepingangel_speed", "400", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Full angel speed in units/second while unobserved (player run speed is ~400).", 50, 5000 )
local cvPatience    = CreateConVar( "weepingangel_patience", "25", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Seconds of unobserved haunting before an angel is ready to strike (randomised +-30% per angel).", 10, 3600 )
local cvAllowTouch  = CreateConVar( "weepingangel_allow_touch", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "0 = angels only scare and never touch you, 1 = they eventually strike.", 0, 1 )
local cvScares      = CreateConVar( "weepingangel_scares", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = angels sometimes appear very close behind you with their hands out.", 0, 1 )
local cvScareScale  = CreateConVar( "weepingangel_scare_scale", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Multiplier for the delays between close-range scares (0.1 = very frequent, handy for testing).", 0.05, 10 )
local cvTouchMode   = CreateConVar( "weepingangel_touch_mode", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "0 = touch sends the victim back in time (teleport), 1 = touch kills.", 0, 1 )
local cvAngelLock   = CreateConVar( "weepingangel_angel_lock", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = angels freeze each other when they can see each other.", 0, 1 )
local cvBotsSee     = CreateConVar( "weepingangel_bots_see", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = bots count as observers (and targets). Off by default: bots stare at nothing and would freeze angels.", 0, 1 )
local cvMoveSnd     = CreateConVar( "weepingangel_move_sounds", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = play a faint stone-grinding sound when the angel moves.", 0, 1 )
local cvAspect      = CreateConVar( "weepingangel_aspect", "1.7778", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Widest screen aspect ratio among your players (16:9 = 1.7778, 21:9 = 2.3333, 32:9 = 3.5556). Widens the 'can see' cone.", 1, 4 )
local cvLights      = CreateConVar( "weepingangel_lights", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = angels flicker and blow out nearby light sources.", 0, 1 )
local cvBreadcrumbs = CreateConVar( "weepingangel_breadcrumbs", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = follow player footsteps around corners.", 0, 1 )
local cvDebug       = CreateConVar( "weepingangel_debug", "0", FCVAR_NONE,
    "1 = print each angel's mode / tension / distance to the server console once per second.", 0, 1 )

-- New features (all OFF by default)
local cvDormant      = CreateConVar( "weepingangel_dormant", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = newly spawned angels start as dormant statues (covered face, completely still) until they wake.", 0, 1 )
local cvDormantDist  = CreateConVar( "weepingangel_dormant_wake_dist", "500", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "A dormant angel wakes when a player comes within this many units.", 50, 5000 )
local cvDormantTime  = CreateConVar( "weepingangel_dormant_wake_time", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "A dormant angel also wakes on its own after this many seconds (0 = never, only distance wakes it).", 0, 3600 )
local cvFeeding      = CreateConVar( "weepingangel_feeding", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = every successful touch makes that angel hungrier: it builds tension faster and its light-draining reaches further.", 0, 1 )
local cvFeedStep     = CreateConVar( "weepingangel_feeding_step", "0.15", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "How much shorter its patience gets per touch (0.15 = 15% each time, stacking).", 0.01, 0.5 )
local cvFeedMax      = CreateConVar( "weepingangel_feeding_max", "5", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Maximum number of touches an angel remembers.", 1, 20 )
local cvDoubleTouch  = CreateConVar( "weepingangel_double_touch", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = a second touch soon after the first kills the victim (neck snap) instead of casting them back again.", 0, 1 )
local cvDoubleWindow = CreateConVar( "weepingangel_double_touch_window", "90", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Seconds after a touch during which the next touch is lethal.", 5, 3600 )

local cvPastFilter   = CreateConVar( "weepingangel_past_filter", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = a sepia filter is shown for a few seconds after you are cast back in time (needs weepingangel_client.lua on clients).", 0, 1 )
local cvPastTime     = CreateConVar( "weepingangel_past_filter_time", "8", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "How many seconds the past-era filter lasts.", 1, 60 )

util.AddNetworkString( "WeepingAngel_PastFilter" )

-- Darkness (EXPERIMENTAL, off by default). Replicated so clients know when to measure light.
local cvDarkness   = CreateConVar( "weepingangel_darkness", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
    "EXPERIMENTAL. 1 = a player cannot observe an angel that is standing in the dark, so it moves freely there (needs weepingangel_client.lua on clients).", 0, 1 )
local cvDarkLevel  = CreateConVar( "weepingangel_dark_level", "0.009", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
    "Light level (0-1) below which an angel counts as standing in the dark. The debug overlay shows the measured value.", 0, 1 )
local cvDarkFlash  = CreateConVar( "weepingangel_dark_flashlight", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
    "1 = your flashlight lights an angel it points at, so you still see it in the dark.", 0, 1 )

util.AddNetworkString( "WeepingAngel_Light" )

-- Flashlight drain: a nearby angel makes your flashlight flicker, then blows it out for a while
local cvFlashDrain = CreateConVar( "weepingangel_flashlight_drain", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = an angel near you can make your flashlight blink slowly a few times, then blow it out (like it is trying to free itself).", 0, 1 )
local cvFlashDist  = CreateConVar( "weepingangel_flashlight_dist", "450", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "How close an angel must be to start draining your flashlight (units).", 100, 2000 )
local cvFlashBlock = CreateConVar( "weepingangel_flashlight_block", "5", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Seconds your flashlight stays dead after it is blown out.", 1, 300 )
local cvFlashBlackout = CreateConVar( "weepingangel_flashlight_blackout", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = the whole screen goes black with every flashlight blink (hides the angel's moves on maps where the darkness threshold is hard to tune).", 0, 1 )

util.AddNetworkString( "WeepingAngel_Blackout" )

-- TARDIS mod support (workshop 307175678)
local cvTardis      = CreateConVar( "weepingangel_tardis_shelter", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "0 = ignore the TARDIS mod. 1 = angels leave you alone while you are inside a TARDIS whose SHIELDS are on (they stay outside). 2 = while inside any TARDIS.", 0, 2 )
local cvMaxRange    = CreateConVar( "weepingangel_max_range", "4000", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "An angel can only teleport to a player within this many units of it (0 = no limit). Exception: a player inside a TARDIS that angels are allowed to follow into.", 0, 50000 )
local cvTardisSiege = CreateConVar( "weepingangel_tardis_siege", "3000", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "An angel with nobody else to hunt walks to the front of a TARDIS door while its player is sheltered inside, if the TARDIS is within this many units (0 = off).", 0, 20000 )
local cvInstant     = CreateConVar( "weepingangel_instant_move", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = the moment nobody is looking at an angel any more, it moves at once (all move/teleport cooldowns are skipped).", 0, 1 )
local cvFit         = CreateConVar( "weepingangel_fit_space", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = teleport distances shrink to the room you are in, and the angel keeps a gap from walls and props instead of standing pressed against them.", 0, 1 )
local cvSmart       = CreateConVar( "weepingangel_smart_target", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = with several players, an angel picks its target by a mix of distance, who looked away from it most recently, and who it has not scared lately (instead of sticking to the first player it chose).", 0, 1 )
local cvLag         = CreateConVar( "weepingangel_lag_comp", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = the 'can see it' cone also grows with how fast a player is turning and with their ping, so a fast camera turn or a laggy connection doesn't show the angel moving.", 0, 1 )
local cvKnock       = CreateConVar( "weepingangel_tardis_knock", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "1 = an angel waiting at the door of a TARDIS knocks (only one angel per TARDIS). If the TARDIS is locked it pounds on the door, trying to break in.", 0, 1 )
local cvKnockVol    = CreateConVar( "weepingangel_tardis_knock_volume", "0.7", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "How loud the knocking / pounding at a TARDIS door is (1 = full, 0.3 = quiet). Also scales the screen shake inside.", 0.05, 2 )
local cvDoorLook = CreateConVar( "weepingangel_tardis_door_look", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "An open TARDIS door only freezes angels outside while someone inside is actually looking at the doorway (0 = anyone inside with the door open counts as watching).", 0, 1 )
local cvTardisGrace = CreateConVar( "weepingangel_tardis_grace", "8", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Seconds after you leave a TARDIS during which angels can still move and scare you, but cannot touch you.", 0, 120 )

-- flashlight blink timings (seconds unless noted)
local FLASH =
{
    MIN_AGE       = 5,     -- seconds after the angel spawned/woke before it may blink lights (tension is NOT needed: it only builds while unseen)
    COOLDOWN_MIN  = 10,     -- pause before the same player can be blinked again (after the light came back)
    COOLDOWN_MAX  = 20,
    FIRST_DARK_MIN = 1.5,     -- timer before the first blink when the angel stands in real darkness
    FIRST_DARK_MAX = 4,
    FIRST_LIT_MIN = 1.5,    -- ... and when only the blackout option hides it
    FIRST_LIT_MAX = 3,
    BLINKS_MIN    = 2,      -- how many times the light goes out before it is blown
    BLINKS_MAX    = 4,
    DARK_MIN      = 0.9,    -- how long each blink stays dark
    DARK_MAX      = 1.4,
    LIGHT_MIN     = 1.1,    -- how long the light stays on between blinks
    LIGHT_MAX     = 2.0,
    ACTION_DELAY  = 0.3,    -- the angel acts this long after the light went out (client has gone dark)
    ON_MARGIN     = 0.5,    -- the light returns at least this long after the angel finished moving
    OFF_WAIT      = 2,      -- flashlight off this long in the dark -> it comes to the front
    HOLD          = 8,      -- how long the final reveal holds after the flashlight can be used again
    REVEAL_MIN    = 30,     -- final reveal distance
    REVEAL_MAX    = 80,
    VANISH_MIN    = 400,    -- blink 1: how far away it vanishes to, behind you (units)
    VANISH_MAX    = 800,
    STEP_FAR      = 600,   -- later blinks, it reappears in front of you: the first step is about this far...
    STEP_NEAR     = 50,    -- ...and the last step before the final reveal is about this far
    STEP_JITTER   = 0.2,    -- random +-20% on every step so the jumps aren't evenly spaced
}

local DARK_STEP_RADIUS = 140   -- a "dark" report also covers positions this close to where the angel was measured

-- Clients tell us, a few times a second, which angels are standing in the dark for them
net.Receive( "WeepingAngel_Light", function( _, ply )
    if not IsValid( ply ) or not cvDarkness:GetBool() then return end

    local now = CurTime()
    if ( ply.WALightNext or 0 ) > now then return end
    ply.WALightNext = now + 0.1

    for _ = 1, net.ReadUInt( 5 ) do
        local ent  = Entity( net.ReadUInt( 16 ) )
        local dark = net.ReadBool()   -- unseen right now (flashlight included)
        local amb  = net.ReadBool()   -- dark by itself, ignoring the player's flashlight

        if IsValid( ent ) and ent:GetClass() == "weepingangel" then
            ent.DarkRep = ent.DarkRep or {}
            ent.DarkRep[ ply ] = { dark = dark, amb = amb, pos = ent:GetPos(), t = now }
        end
    end
end )

local FEED_LIGHT_STEP = 0.2   -- light-draining reach grows by this fraction per remembered touch
local sndSnap = Sound( "physics/body/body_medium_break3.wav" )  -- if this is silent, swap for any sound you like

-- --------------------------------------------------------
-- Tuning constants (RESTORED TO YOUR EXACT VALUES)
-- --------------------------------------------------------
local THINK_DELAY        = 0.05   -- how often we check for observers (20 Hz)
local SEEN_GRACE         = 0.15   -- stay frozen this long after last being seen (hides latency)
local MAX_STEP_DT        = 0.2    -- clamp for movement delta time

local VIEW_MARGIN_DEG    = 3     -- extra degrees added to the player's FOV cone
local ANGEL_SIGHT_DIST   = 3000
local ANGEL_COS          = math.cos( math.rad( 60 ) )

-- Director
local HOLD_FAR           = 800    -- distance it keeps at zero tension
local HOLD_NEAR          = 110    -- distance it keeps at full tension (stays outside touch range)
local HAUNT_SPEED_MUL    = 1.25   -- creeping speed while haunting (x weepingangel_speed)
local STRIKE_SPEED_MUL   = 1.25
local RELOCATE_MIN       = 2      -- seconds between "appear somewhere new" moves
local RELOCATE_MAX       = 4
local STRIKE_BLIND_TIME  = 0.5    -- the zap waits until no PLAYER has had it in view for this long; every glance restarts it (movement is not affected)
local STRIKE_TIMEOUT     = 15     -- give up a strike that takes this long

-- Strike choreography
local POINT_DIST         = 45    -- inside this: points its finger and creeps slowly
local FANG_DIST          = 80    -- between POINT_DIST and this: hands open, fangs
local POINT_WAIT         = 0.8    -- seconds (unobserved time) it points at you in touch range before touching
local POINT_CREEP_MUL    = 1.10   -- slow creep while pointing

-- Close-range scare
local SCARE_MIN_TENSION  = 0.35   -- no scares before the hunt has built up a bit
local SCARE_DIST_MIN     = 45     -- must stay outside the player's hull + angel hull
local SCARE_DIST_MAX     = 75
local SCARE_WAIT         = 14     -- how long it waits for you to turn around
local SCARE_SIDE_DEG     = 20     -- it leans up to this many degrees off dead-centre behind you
local SCARE_MOVE_SPEED   = 60     -- above this speed "behind you" means behind your direction of travel
local SCARE_COOLDOWN_MIN = 18     -- seconds between scares (shorter when tension is high)
local SCARE_COOLDOWN_MAX = 48     -- (all scare delays are multiplied by weepingangel_scare_scale)
local SCARE_FIRST_MIN    = 28     -- delay before the very first scare after spawning
local SCARE_FIRST_MAX    = 48

-- Touch / movement
local PLAYER_RADIUS      = 16     -- player hull half-width
local TOUCH_GAP          = 4      -- tiny air gap left between the two hulls
local TOUCH_REACH        = 6      -- within this of "touching" it stops sprinting, points, and closes the last gap
local TOUCH_COOLDOWN     = 3
local STEP_HEIGHT        = 18
local MAX_DROP           = 96
local FAR_TELEPORT_DIST  = 2500
local STUCK_TIME         = 1.0
local AMBUSH_MIN_DIST    = 400
local AMBUSH_MAX_DIST    = 900
local TELEPORT_COOLDOWN  = 3

local MODEL_YAW_OFFSET   = 0

local MODEL_IDLE   = "models/the_sniper_9/doctorwho/extras/angels/angelidle.mdl"
local MODEL_POINT  = "models/the_sniper_9/doctorwho/extras/angels/angelpoint.mdl"
local MODEL_ATTACK = "models/the_sniper_9/doctorwho/extras/angels/angelattack.mdl"
local POSES        = { MODEL_IDLE, MODEL_POINT, MODEL_ATTACK }
local SCARE_POSE   = MODEL_ATTACK

local sndZap    = Sound( "ambient/energy/zap1.wav" )
local sndWhoosh = Sound( "ambient/machines/teleport1.wav" )
local STONE_SOUNDS =
{
    Sound( "physics/concrete/rock_impact_hard1.wav" ),
    Sound( "physics/concrete/rock_impact_hard2.wav" ),
    Sound( "physics/concrete/rock_impact_hard3.wav" ),
}

local SPAWN_CLASSES =
{
    "info_player_start", "info_player_deathmatch", "info_player_combine",
    "info_player_rebel", "info_player_teamspawn",
}

WEEPINGANGEL_LIST = WEEPINGANGEL_LIST or {}

-- --------------------------------------------------------
-- Helpers
-- --------------------------------------------------------

local function GetViewInfo( ply )
    local view = ply:GetViewEntity()
    if IsValid( view ) and view ~= ply then
        return view:GetPos(), view:GetAngles(), view
    end
    return ply:EyePos(), ply:EyeAngles(), ply
end

local function ViewCosLimit( ply )
    local fov = ply:GetFOV()
    if not fov or fov <= 0 then fov = 90 end
    fov = math.Clamp( fov, 20, 140 )

    local widen = cvAspect:GetFloat() / ( 4 / 3 )
    local half  = math.deg( math.atan( math.tan( math.rad( fov * 0.5 ) ) * widen ) ) + VIEW_MARGIN_DEG

    -- lag compensation: how far the view could already have turned that the server does not know yet
    local extra = cvLag:GetBool() and ( ply.WAViewExtra or 0 ) or 0

    return math.cos( math.rad( math.min( half + extra, extra > 0 and 125 or 95 ) ) )
end

local function ScareDelay( a, b )
    local patience = math.Clamp( cvPatience:GetFloat() / 120, 0.1, 5 )
    return math.Rand( a, b ) * cvScareScale:GetFloat() * patience
end

-- The TARDIS (exterior entity) this player is inside, or nil. Uses the mod's own per-player data.
local function TardisOf( ply )
    if not IsValid( ply ) or not isfunction( ply.GetTardisData ) then return nil end

    local ok, ext = pcall( ply.GetTardisData, ply, "exterior" )
    if ok and IsValid( ext ) then return ext end

    return nil
end

-- Are this TARDIS's shields on? true / false, or nil when the state can't be read.
-- (the mod's exact accessor name isn't known here, so a few likely ones are tried)
local SHIELD_FUNCS = { "GetShields", "ShieldsOn", "GetShieldsOn", "ShieldsUp", "GetShieldsUp", "IsShielded", "GetShield", "ShieldsActive" }
local SHIELD_KEYS  = { "shields", "shield", "shields-on", "shieldson" }

local function TardisShieldsOn( ext )
    if not IsValid( ext ) then return nil end

    for _, name in ipairs( SHIELD_FUNCS ) do
        if isfunction( ext[ name ] ) then
            local ok, r = pcall( ext[ name ], ext )
            if ok and isbool( r ) then return r, name end
        end
    end

    if isfunction( ext.GetData ) then
        for _, key in ipairs( SHIELD_KEYS ) do
            local ok, r = pcall( ext.GetData, ext, key )
            if ok and isbool( r ) then return r, "GetData(" .. key .. ")" end
        end
    end

    return nil
end

-- Is this player sheltered from angels by the TARDIS they are in?
local function TardisShelter( ply )
    local mode = cvTardis:GetInt()
    if mode <= 0 then return false end

    local ext = TardisOf( ply )
    if not ext then return false end
    if mode >= 2 then return true end

    return TardisShieldsOn( ext ) == true
end

-- The interior entity of the TARDIS this player is in, or nil
local function InteriorOf( ply )
    if not TardisOf( ply ) then return nil end

    local ok, int = pcall( ply.GetTardisData, ply, "interior" )
    if ok and IsValid( int ) then return int end

    return nil
end

-- Is this world position inside the interior room itself (not in the void around it)?
-- If the interior's bounds can't be judged (tiny / missing), everything counts as inside.
local function InsideInterior( int, pos )
    if not IsValid( int ) then return true end

    local mins, maxs = int:OBBMins(), int:OBBMaxs()
    if ( maxs - mins ):Length() < 500 then return true end

    local l = int:WorldToLocal( pos )
    return l.x > mins.x - 16 and l.x < maxs.x + 16
       and l.y > mins.y - 16 and l.y < maxs.y + 16
       and l.z > mins.z - 64 and l.z < maxs.z + 64
end

local function InteriorRadius( int )
    return math.Clamp( int:BoundingRadius(), 1200, 4000 )
end

-- trace mask for sight checks: interior walls can be windows/grates that MASK_OPAQUE lets through
local function SightMask( ply )
    return TardisOf( ply ) and MASK_SOLID or MASK_OPAQUE
end

-- Is the exterior door of this TARDIS open? (unknown counts as closed)
local function TardisDoorOpen( ext )
    if not IsValid( ext ) then return false end

    if isfunction( ext.ExtDoorOpen ) then
        local ok, r = pcall( ext.ExtDoorOpen, ext )
        if ok and r then return true end
    end

    if isfunction( ext.DoorOpen ) then
        local ok, r = pcall( ext.DoorOpen, ext )
        if ok and r then return true end
    end

    return false
end

-- Is this TARDIS locked? true / false, or nil when the state can't be read (a few likely accessors are tried)
local LOCK_FUNCS = { "Locked", "GetLocked", "IsLocked", "GetLock" }
local LOCK_KEYS  = { "locked", "lock" }

local function TardisLocked( ext )
    if not IsValid( ext ) then return nil end

    for _, name in ipairs( LOCK_FUNCS ) do
        if isfunction( ext[ name ] ) then
            local ok, r = pcall( ext[ name ], ext )
            if ok and isbool( r ) then return r, name end
        end
    end

    if isfunction( ext.GetData ) then
        for _, key in ipairs( LOCK_KEYS ) do
            local ok, r = pcall( ext.GetData, ext, key )
            if ok and isbool( r ) then return r, "GetData(" .. key .. ")" end
        end
    end

    return nil
end

-- Where the doorway is on the exterior (world position)
local function TardisDoorPos( ext )
    if isfunction( ext.GetDoorway ) then
        local ok, dw = pcall( ext.GetDoorway, ext )
        if ok and istable( dw ) and isvector( dw.pos ) then return ext:LocalToWorld( dw.pos ) end
    end

    return ext:LocalToWorld( ext:OBBCenter() )
end

-- Where the door is on the INSIDE of the TARDIS (world position in the interior room).
-- Asked from the mod first, otherwise where players were seen stepping in / out. nil = unknown.
local function InteriorDoorPos( int )
    if not IsValid( int ) then return nil end

    if isfunction( int.GetPart ) then
        local ok, part = pcall( int.GetPart, int, "door" )
        if ok and IsValid( part ) then return part:LocalToWorld( part:OBBCenter() ), "part" end
    end

    if int.WAInDoorLocal then return int:LocalToWorld( int.WAInDoorLocal ) + Vector( 0, 0, 45 ), "learned" end

    return nil
end

-- Is this player (inside a TARDIS with an open door) looking at the doorway, so that they can see out?
-- Cached for a few frames, it is asked many times per think.
local function LooksAtDoor( ply, ext )
    local now = CurTime()
    local c = ply.WADoorLook
    if c and c.ext == ext and now - c.t < 0.05 then return c.v end

    local v = true   -- unknown door position: assume they can see out (old behaviour)
    local int = InteriorOf( ply )
    local door = InteriorDoorPos( int )

    if door then
        local eye, ang = GetViewInfo( ply )
        local to = door - eye
        local d = to:Length()

        if d > 1 then
            to:Mul( 1 / d )

            -- the door is a big target: widen the cone by how large it looks from here
            local half = math.acos( math.Clamp( ViewCosLimit( ply ), -1, 1 ) ) + math.atan( 55 / d )
            local cosA = ang:Forward():Dot( to )

            v = cosA >= math.cos( math.min( half, 2.3 ) )

            if v then
                -- something solid in the way (a console, a pillar, a wall)? check the middle and the upper part of the door
                local clear = false
                for _, off in ipairs( { Vector( 0, 0, 0 ), Vector( 0, 0, 30 ), Vector( 0, 0, -25 ) } ) do
                    local tr = util.TraceLine( { start = eye, endpos = door + off, filter = ply, mask = MASK_SOLID } )
                    if not tr.Hit or tr.Fraction > 0.9 then clear = true break end
                end
                v = clear
            end
        end
    end

    ply.WADoorLook = { t = now, v = v, ext = ext }
    return v
end

-- Four times a second: remember who is sheltered, start the grace period when they leave,
-- and cut short any flashlight blink that was running when they stepped in.
timer.Create( "WeepingAngel_TardisShelter", 0.25, 0, function()
    local now = CurTime()

    for _, ply in ipairs( player.GetAll() ) do
        local sheltered = TardisShelter( ply )

        -- remember which TARDIS they were last in (used to clear angels out of its interior)
        local ext = TardisOf( ply )
        if ext then
            local ok, int = pcall( ply.GetTardisData, ply, "interior" )
            if not ok then int = nil end
            if ok and IsValid( int ) then ply.WATardisRec = { ext = ext, int = int } end
            ply.WATardisEnter = ply.WATardisEnter or now

            if not ply.WAInsideTardis then
                -- just stepped in: where they stood a moment ago is right in front of the door
                ply.WAInsideTardis = ext

                local pp = ply.WAPrevPos
                if pp and pp:DistToSqr( ext:GetPos() ) < 500 * 500 then ext.WADoorLocal = ext:WorldToLocal( pp ) end

                -- and where they first stand in the interior is just inside the door
                if IsValid( int ) then int.WAInDoorLocal = int:WorldToLocal( ply:GetPos() ) end
            end

            ply.WAInPos = ply:GetPos()
        else
            ply.WATardisEnter = nil

            local was = ply.WAInsideTardis
            if was then
                -- just stepped out: they appear right in front of the door
                ply.WAInsideTardis = nil

                -- the last place they stood inside is the inside of the door
                local rec = ply.WATardisRec
                if rec and IsValid( rec.int ) and ply.WAInPos then rec.int.WAInDoorLocal = rec.int:WorldToLocal( ply.WAInPos ) end

                if IsValid( was ) and ply:GetPos():DistToSqr( was:GetPos() ) < 500 * 500 then
                    was.WADoorLocal = was:WorldToLocal( ply:GetPos() )
                end
            end

            ply.WAPrevPos = ply:GetPos()
        end

        if sheltered and not ply.WAShelter then
            local st = ply.WAFlash
            if st then
                if IsValid( st.owner ) and st.owner.FlashSeq == st then
                    st.owner:EndFlashSeq( ply, st, now, false )
                else
                    ply.WAFlash = nil
                end
            end
            ply.WABlindUntil = 0
        elseif not sheltered and ply.WAShelter then
            ply.WAShelterUntil = now + cvTardisGrace:GetFloat()
        end

        ply.WAShelter = sheltered
    end
end )

local function IsValidTarget( ply )
    if not IsValid( ply ) or not ply:Alive() then return false end
    if ply.WAShelter or TardisShelter( ply ) then return false end   -- inside a sheltering TARDIS
    if ply:IsFlagSet( FL_NOTARGET ) then return false end
    if ply:GetMoveType() == MOVETYPE_NOCLIP and not ply:InVehicle() then return false end
    if ply:IsBot() and not cvBotsSee:GetBool() then return false end
    return true
end

local function FindTimeDestination( ply, angelPos )
    local mins, maxs = ply:GetHull()
    local origin = ply:GetPos()

    local spawns = {}
    for _, class in ipairs( SPAWN_CLASSES ) do
        table.Add( spawns, ents.FindByClass( class ) )
    end

    local function IsGood( pos, avoidAngels, minDistSqr )
        if pos:DistToSqr( origin ) < minDistSqr then return false end
        if pos:DistToSqr( angelPos ) < minDistSqr then return false end

        if avoidAngels then
            for ang in pairs( WEEPINGANGEL_LIST ) do
                if IsValid( ang ) and pos:DistToSqr( ang:GetPos() ) < 700 * 700 then return false end
            end
        end

        local tr = util.TraceHull( {
            start = pos, endpos = pos,
            mins = mins, maxs = maxs,
            mask = MASK_PLAYERSOLID, filter = ply
        } )
        return not tr.StartSolid and not tr.Hit
    end

    for _, minDist in ipairs( { 1000, 500, 200 } ) do
        local minDistSqr = minDist * minDist
        for pass = 1, 2 do
            local avoid = ( pass == 1 )
            if #spawns > 0 then
                for _ = 1, 16 do
                    local pick = spawns[ math.random( #spawns ) ]
                    if IsValid( pick ) then
                        local pos = pick:GetPos() + Vector( 0, 0, 4 )
                        if IsGood( pos, avoid, minDistSqr ) then return pos end
                    end
                end
            end

            for _ = 1, 32 do
                local offset = Vector( math.Rand( -2500, 2500 ), math.Rand( -2500, 2500 ), 0 )
                local tr = util.TraceLine( {
                    start = origin + offset + Vector( 0, 0, 400 ),
                    endpos = origin + offset - Vector( 0, 0, 1500 ),
                    mask = MASK_SOLID_BRUSHONLY
                } )
                if tr.Hit and not tr.StartSolid and not tr.HitSky and tr.HitNormal.z > 0.7 then
                    local pos = tr.HitPos + Vector( 0, 0, 2 )
                    if IsGood( pos, avoid, minDistSqr ) then return pos end
                end
            end
        end
    end

    return nil
end

-- --------------------------------------------------------
-- Spawning / setup
-- --------------------------------------------------------

function ENT:SpawnFunction( ply, tr, ClassName )
    if not tr.Hit then return end
    local ent = ents.Create( ClassName or "weepingangel" )
    ent:SetPos( tr.HitPos + tr.HitNormal * 8 )
    ent:SetAngles( Angle( 0, ply:EyeAngles().yaw + 180, 0 ) )
    ent:Spawn()
    ent:Activate()
    ent:SetVictim( ply )
    ent:SnapToGround()
    return ent
end

function ENT:MeasurePoses()
    local mins, maxs = Vector( 0, 0, 0 ), Vector( 0, 0, 0 )
    for _, mdl in ipairs( POSES ) do
        util.PrecacheModel( mdl )
        self:SetModel( mdl )
        local a, b = self:OBBMins(), self:OBBMaxs()
        mins.x = math.min( mins.x, a.x ); mins.y = math.min( mins.y, a.y ); mins.z = math.min( mins.z, a.z )
        maxs.x = math.max( maxs.x, b.x ); maxs.y = math.max( maxs.y, b.y ); maxs.z = math.max( maxs.z, b.z )
    end

    if maxs.z - mins.z < 8 then
        mins = Vector( -16, -16, 0 )
        maxs = Vector( 16, 16, 72 )
    end

    local radius  = math.max( -mins.x, maxs.x, -mins.y, maxs.y )
    local hullR   = math.Clamp( radius, 12, 22 )
    local sightR  = math.Clamp( radius, 12, 30 )
    local midZ    = ( mins.z + maxs.z ) * 0.5

    self.HullMins  = Vector( -hullR, -hullR, mins.z )
    self.HullMaxs  = Vector(  hullR,  hullR, maxs.z )
    self.EyeHeight = maxs.z * 0.9

    self.SeenPoints =
    {
        Vector( 0, 0, mins.z + 6 ),
        Vector( 0, 0, midZ ),
        Vector( 0, 0, maxs.z - 6 ),
        Vector(  sightR, 0, midZ ),
        Vector( -sightR, 0, midZ ),
        Vector( 0,  sightR, midZ ),
        Vector( 0, -sightR, midZ ),
    }
end

function ENT:InitStaticPhysics()
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_VPHYSICS )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:EnableMotion( false )
    end
end

function ENT:SetPose( mdl )
    if self.CurPose == mdl then return end
    self.CurPose = mdl
    self:SetModel( mdl )
    self:InitStaticPhysics()
end

function ENT:Initialize()
    self:MeasurePoses()

    -- Trace filter for movement: only ourselves. Other angels are solid, so two angels
    -- can never walk through each other or pick the same spot (e.g. both appearing in
    -- the same place behind you during a scare).
    self.MoveFilter = self

    self.CurPose = MODEL_IDLE
    self:SetModel( MODEL_IDLE )
    self:InitStaticPhysics()
    self:SetHealth( 1 )

    local now = CurTime()
    self.LastThink        = now
    self.FrozenUntil      = 0
    self.NextTouch        = 0
    self.NextTeleport     = 0
    self.NextTeleportTry  = 0
    self.LastTeleport     = 0
    self.NextRetarget     = 0
    self.NextPoseChange   = 0
    self.NextMoveSound    = 0
    self.NextDebug        = 0
    self.NextOpenness     = 0
    self.Openness         = 1500
    self.StuckTime        = 0
    self.PointTime        = 0
    self.ScareFails       = 0
    self.NextSnap         = 0
    self.ScareDist        = SCARE_DIST_MIN
    self.ScareSide        = 0
    self.ScareYaw         = 0
    self.SteerSign        = ( math.random( 0, 1 ) == 1 ) and 1 or -1

    -- Director state
    self.Mode             = "haunt"
    self.Tension          = 0.05
    self.PatienceMul      = math.Rand( 0.7, 1.3 )
    self.StrikeUntil      = 0
    self.WasObserved      = false
    self.LastObserved     = now
    self.LastSeenByPlayer = now
    self.NextRelocate     = now + math.Rand( RELOCATE_MIN, RELOCATE_MAX )

    -- Close-range scare state
    self.ScareState       = nil
    self.ScareExpire      = 0
    self.RetreatAt        = 0
    self.NextScare        = now + ScareDelay( SCARE_FIRST_MIN, SCARE_FIRST_MAX )

    -- Merged smart features
    self.BlinkingLights   = {}
    self.NextLightScan    = 0
    self.PlayerPath       = {}
    self.NextPathRecord   = 0
    self.IsSonicFrozen    = false

    -- New features
    self.Hunger           = 0
    self.SpawnTime        = now
    self.Dormant          = cvDormant:GetBool()

    WEEPINGANGEL_LIST[ self ] = true
end

function ENT:SetVictim( ply )
    self.Victim = ply
end

function ENT:OnRemove()
    WEEPINGANGEL_LIST[ self ] = nil
end

function ENT:OnTakeDamage( dmg )
    return 0
end

-- ========================================================
-- Light Flickering Settings (Distance-Based Proximity)
-- ========================================================
local LIGHT_SCAN_DIST      = 500   -- Max distance the Angel can affect lights (Source units)
local LIGHT_SCAN_RATE      = 0.4   -- How often it scans for nearby lights in seconds
local LIGHT_FLICKER_MIN    = 10.0   -- Minimum seconds a light flickers before popping
local LIGHT_FLICKER_MAX    = 20.0  -- Maximum seconds a light flickers before popping

-- Distance Thresholds:
local LIGHT_DIST_NEAR      = 70    -- Point-blank distance (Flickers at MAXIMUM speed)
local LIGHT_DIST_FAR       = 450   -- Far edge distance (Flickers at SLOWEST speed)

-- Speed Multipliers based on distance:
local LIGHT_SPEED_NEAR_MUL = 0.25  -- Multiplier when close (0.12 = ~8x faster / violent spasm)
local LIGHT_SPEED_FAR_MUL  = 1.5  -- Multiplier when far (1.25 = slow, lazy warning twitches)

-- Base Timings (Before distance multipliers are applied):
local LIGHT_FAST_MIN       = 0.15  -- Quick blink base duration
local LIGHT_FAST_MAX       = 0.30
local LIGHT_MED_MIN        = 0.35  -- Medium pause base duration
local LIGHT_MED_MAX        = 0.65
local LIGHT_LONG_MIN       = 0.75  -- Long tension pause base duration
local LIGHT_LONG_MAX       = 1.20

-- --------------------------------------------------------
-- Interactive Lights (Distance-Based Dynamic Speed)
-- --------------------------------------------------------
function ENT:CheckNearbyLights( now )
    if not cvLights:GetBool() then return end

    -- 1. Scan for all lamps within radius
    if now >= ( self.NextLightScan or 0 ) then
        self.NextLightScan = now + LIGHT_SCAN_RATE

        local myPos = self:GetPos()
        local nearbyEnts = ents.FindInSphere( myPos, LIGHT_SCAN_DIST * self:HungerLightMul() )
        local foundMap = {}

        for _, ent in ipairs( nearbyEnts ) do
            if IsValid( ent ) and not ent.IsAngelBroken then
                local cls = ent:GetClass()
                if cls == "gmod_light" or cls == "gmod_lamp" then
                    foundMap[ ent ] = true
                    if not self.BlinkingLights[ ent ] then
                        self.BlinkingLights[ ent ] = {
                            StartTime  = now,
                            Duration   = math.Rand( LIGHT_FLICKER_MIN, LIGHT_FLICKER_MAX ),
                            NextToggle = now
                        }
                    end
                end
            end
        end

        -- Clean up lights that moved out of range
        for ent in pairs( self.BlinkingLights ) do
            if not foundMap[ ent ] then
                self.BlinkingLights[ ent ] = nil
            end
        end
    end

    -- 2. Process all active lights dynamically based on distance
    local myPos = self:GetPos()

    for ent, data in pairs( self.BlinkingLights ) do
        if IsValid( ent ) and not ent.IsAngelBroken then
            local elapsed = now - data.StartTime

            if elapsed >= data.Duration then
                -- Pop: Permanently blow out with sparks & sound
                if ent.SetBrightness then ent:SetBrightness( 0 ) end
                if ent.SetOn then ent:SetOn( false ) end
                if ent.Switch then ent:Switch( false ) end

                ent:EmitSound( "ambient/energy/spark1.wav", 80, 100 )
                ent:EmitSound( "items/flashlight1.wav", 75, 80 )

                local edata = EffectData()
                edata:SetOrigin( ent:GetPos() )
                edata:SetNormal( Vector( 0, 0, 1 ) )
                edata:SetMagnitude( 2 )
                edata:SetScale( 1 )
                edata:SetRadius( 5 )
                util.Effect( "Sparks", edata )

                ent.IsAngelBroken = true
                self.BlinkingLights[ ent ] = nil
            elseif now >= data.NextToggle then
                -- Toggle light state
                if ent.GetOn and ent.SetOn then
                    ent:SetOn( not ent:GetOn() )
                elseif ent.Toggle then
                    ent:Toggle()
                elseif ent.Switch and ent.On ~= nil then
                    ent:Switch( not ent.On )
                end

                -- DISTANCE CALCULATION:
                -- Measures exact distance between this specific light and the Angel
                local dist = myPos:Distance( ent:GetPos() )
                local distRange = math.max( 1, LIGHT_DIST_FAR - LIGHT_DIST_NEAR )
                local distFraction = math.Clamp( ( dist - LIGHT_DIST_NEAR ) / distRange, 0, 1 )

                -- Switch click sound (pitch gets higher the closer the Angel is)
                local pitch = math.random( 85, 110 ) + math.floor( ( 1 - distFraction ) * 30 )
                ent:EmitSound( "buttons/lightswitch2.wav", 60, pitch )

                -- Base randomized timing
                local roll = math.random()
                local baseDelay

                if roll < 0.45 then
                    baseDelay = math.Rand( LIGHT_FAST_MIN, LIGHT_FAST_MAX )
                elseif roll < 0.80 then
                    baseDelay = math.Rand( LIGHT_MED_MIN, LIGHT_MED_MAX )
                else
                    baseDelay = math.Rand( LIGHT_LONG_MIN, LIGHT_LONG_MAX )
                end

                -- DYNAMIC SPEED: Close = tiny delay (fast), Far = large delay (slow)
                local speedMul = Lerp( distFraction, LIGHT_SPEED_NEAR_MUL, LIGHT_SPEED_FAR_MUL )
                data.NextToggle = now + math.max( 0.03, baseDelay * speedMul )
            end
        else
            self.BlinkingLights[ ent ] = nil
        end
    end
end

function ENT:RecordPlayerPath( now )
    if not cvBreadcrumbs:GetBool() or not IsValid( self.Victim ) then return end
    if now < self.NextPathRecord then return end
    self.NextPathRecord = now + 0.25

    local pos = self.Victim:GetPos()
    local count = #self.PlayerPath
    if count == 0 or self.PlayerPath[ count ]:DistToSqr( pos ) > 36 * 36 then
        table.insert( self.PlayerPath, pos )
        if #self.PlayerPath > 80 then
            table.remove( self.PlayerPath, 1 )
        end
    end
end

function ENT:GetMoveDirection( to, flat )
    if not cvBreadcrumbs:GetBool() or #self.PlayerPath == 0 or flat <= POINT_DIST then
        return to, flat
    end

    local tr = util.TraceLine( {
        start  = self:GetPos() + Vector( 0, 0, 36 ),
        endpos = self.Victim:GetPos() + Vector( 0, 0, 36 ),
        filter = { self, self.Victim },
        mask   = MASK_SOLID_BRUSHONLY
    } )

    if not tr.Hit then return to, flat end

    local myPos = self:GetPos()
    local closestIdx, closestDist = nil, math.huge

    for i, pt in ipairs( self.PlayerPath ) do
        local d = myPos:DistToSqr( pt )
        if d < closestDist then
            closestDist = d
            closestIdx = i
        end
    end

    local targetIdx = math.min( #self.PlayerPath, ( closestIdx or 1 ) + 2 )
    local targetPt  = self.PlayerPath[ targetIdx ]

    if targetPt then
        local pathDir = targetPt - myPos
        pathDir.z = 0
        local pathFlat = pathDir:Length()
        if pathFlat > 8 then
            return pathDir, pathFlat
        end
    end

    return to, flat
end

-- --------------------------------------------------------
-- Vision / quantum lock
-- --------------------------------------------------------

function ENT:PlayerCanSee( ply, pos )
    if not IsValid( ply ) or not ply:Alive() then return false end
    if ply:IsBot() and not cvBotsSee:GetBool() then return false end
    if cvDarkness:GetBool() and self:IsDarkFor( ply, pos ) then return false end
    if ( ply.WABlindUntil or 0 ) > CurTime() then return false end   -- flashlight blink / blackout: they see nothing

    -- inside a TARDIS: the void around the interior room is never visible
    local int = InteriorOf( ply )
    if int and pos:Distance( int:GetPos() ) < InteriorRadius( int ) and not InsideInterior( int, pos ) then return false end

    local mask = SightMask( ply )

    local eyePos, eyeAng, viewEnt = GetViewInfo( ply )
    local fwd      = eyeAng:Forward()
    local cosLimit = ViewCosLimit( ply )
    local pts      = self.SeenPoints

    for i = 1, #pts do
        local p   = pos + pts[ i ]
        local dir = p - eyePos
        local len = dir:Length()

        if len < 1 then return true end

        dir = dir * ( 1 / len )

        if dir:Dot( fwd ) > cosLimit then
            local tr = util.TraceLine( {
                start  = eyePos,
                endpos = p,
                filter = { ply, viewEnt, self },
                mask   = mask
            } )
            if not tr.Hit then return true end
        end
    end

    return false
end

function ENT:AngelCanSee( other, pos )
    if other == self or not IsValid( other ) then return false end

    if other.CurPose == MODEL_IDLE or other:GetModel() == MODEL_IDLE then
        return false
    end

    local eye = other:GetPos() + Vector( 0, 0, other.EyeHeight or 60 )
    local mid = pos + self.SeenPoints[ 2 ]
    local dir = mid - eye
    local len = dir:Length()

    if len > ANGEL_SIGHT_DIST then return false end
    if len < 1 then return true end

    dir = dir * ( 1 / len )
    local fwd = Angle( 0, other:GetAngles().yaw - MODEL_YAW_OFFSET, 0 ):Forward()
    if dir:Dot( fwd ) < ANGEL_COS then return false end

    local tr = util.TraceLine( {
        start  = eye,
        endpos = mid,
        filter = { other, self },
        mask   = MASK_OPAQUE
    } )
    return not tr.Hit
end

-- A player standing inside a TARDIS with its door open can see the outside through the doorway,
-- but the server only knows where their body is (in the far-away interior). So an angel standing in
-- front of an open TARDIS door counts as seen while someone inside is looking at the doorway (they have to be
-- facing it to see out; with weepingangel_tardis_door_look 0 anyone inside counts), and it never moves in view.
function ENT:SeenThroughTardisDoor( pos )
    for _, ply in ipairs( player.GetAll() ) do
        local ext = TardisOf( ply )

        if ext and ply:Alive() and not ( ply:IsBot() and not cvBotsSee:GetBool() ) then
            if TardisDoorOpen( ext ) and ( not cvDoorLook:GetBool() or LooksAtDoor( ply, ext ) ) then
                local door = TardisDoorPos( ext )

                local mid = pos + self.SeenPoints[ 2 ]

                if door:DistToSqr( mid ) < 1500 * 1500 then
                    local dir = mid - door
                    dir:Normalize()

                    -- the exterior itself is not filtered: an angel behind the box is blocked by it
                    local tr = util.TraceLine( {
                        start  = door + dir * 8,
                        endpos = mid,
                        filter = self,
                        mask   = MASK_OPAQUE
                    } )

                    if not tr.Hit then return true end
                end
            end
        end
    end

    return false
end

function ENT:IsObservedAt( pos )
    for _, ply in ipairs( player.GetAll() ) do
        if self:PlayerCanSee( ply, pos ) then return true, true end
    end

    if self:SeenThroughTardisDoor( pos ) then return true, true end

    if cvAngelLock:GetBool() then
        for other in pairs( WEEPINGANGEL_LIST ) do
            if IsValid( other ) then
                if self:AngelCanSee( other, pos ) then return true, false end
            else
                WEEPINGANGEL_LIST[ other ] = nil
            end
        end
    end

    return false, false
end

function ENT:IsObserved()
    return self:IsObservedAt( self:GetPos() )
end

-- --------------------------------------------------------
-- Movement
-- --------------------------------------------------------

function ENT:FindGround( pos, up, down )
    local starts = ( up > 24 ) and { up, 24 } or { up }

    for _, u in ipairs( starts ) do
        local tr = util.TraceHull( {
            start  = pos + Vector( 0, 0, u ),
            endpos = pos - Vector( 0, 0, down ),
            mins   = self.HullMins,
            maxs   = self.HullMaxs,
            filter = self.MoveFilter,
            mask   = MASK_NPCSOLID
        } )

        if not tr.StartSolid then
            if tr.Hit and tr.HitNormal.z >= 0.6 then return tr.HitPos end
            return nil
        end
    end

    return nil
end

function ENT:SnapToGround()
    local ground = self:FindGround( self:GetPos(), 64, 512 )
    if ground then self:SetPos( ground ) end
end

function ENT:TryStep( dir, dist )
    local from = self:GetPos()
    local lift = Vector( 0, 0, STEP_HEIGHT )

    local tr = util.TraceHull( {
        start  = from + lift,
        endpos = from + lift + dir * dist,
        mins   = self.HullMins,
        maxs   = self.HullMaxs,
        filter = self.MoveFilter,
        mask   = MASK_NPCSOLID
    } )

    if tr.StartSolid or tr.Fraction < 0.5 then return nil end
    return self:FindGround( tr.HitPos - lift, STEP_HEIGHT, MAX_DROP )
end

function ENT:ContactDist()
    return self.HullMaxs.x + PLAYER_RADIUS + TOUCH_GAP
end

function ENT:FaceVictim()
    if not IsValid( self.Victim ) then return end
    local d = self.Victim:GetPos() - self:GetPos()
    d.z = 0
    if d:LengthSqr() < 1 then return end
    self:SetAngles( Angle( 0, d:Angle().yaw + MODEL_YAW_OFFSET, 0 ) )
end

function ENT:StalkStep( dt, to, flat, speedMul, stopDist )
    if flat < 8 then return false end

    local speed = cvSpeed:GetFloat() * speedMul
    local step  = math.min( speed * dt, flat - stopDist )
    if step < 1 then return false end

    local base = to * ( 1 / flat )
    local s    = self.SteerSign
    local offsets = { 0, 35 * s, -35 * s, 70 * s, -70 * s, 105 * s, -105 * s }

    for _, off in ipairs( offsets ) do
        local dir = Vector( base.x, base.y, 0 )
        dir:Rotate( Angle( 0, off, 0 ) )

        local newPos = self:TryStep( dir, step )
        if newPos and not self:IsObservedAt( newPos ) then
            self:SetPos( newPos )
            return true
        end
    end

    return false
end

function ENT:UpdateOpenness( now )
    if now < self.NextOpenness then return end
    self.NextOpenness = now + 1

    local victim = self.Victim
    local eye    = victim:EyePos()
    local total  = 0

    for k = 0, 7 do
        local tr = util.TraceLine( {
            start  = eye,
            endpos = eye + Angle( 0, k * 45, 0 ):Forward() * 1500,
            filter = { victim, self },
            mask   = MASK_OPAQUE
        } )
        total = total + tr.Fraction * 1500
    end

    self.Openness = total / 8
end

-- May this angel teleport to its victim? Not if the victim is beyond weepingangel_max_range,
-- except inside a TARDIS the angel is allowed into (the interior sits far away on the map).
function ENT:InTeleportRange()
    local victim = self.Victim
    if not IsValid( victim ) then return false end

    -- Following a player into a TARDIS: only through a closed door (with the door open the angel
    -- could be seen through it), and not in the first moments after they stepped in.
    local text = TardisOf( victim )
    if text then
        local now = CurTime()
        if not victim.WATardisEnter then victim.WATardisEnter = now end

        local int = InteriorOf( victim )
        local outside = int and self:GetPos():Distance( int:GetPos() ) > InteriorRadius( int )

        if outside and ( TardisDoorOpen( text ) or now - victim.WATardisEnter < 3 ) then return false end
    end

    local range = cvMaxRange:GetFloat()
    if range <= 0 then return true end

    if self:GetPos():DistToSqr( victim:GetPos() ) <= range * range then return true end

    return TardisOf( victim ) ~= nil
end

-- The spot in front of a TARDIS door. Uses the doorway the mod describes (both sides of its facing
-- are tried, the open one wins). If that can't be read, any open ground around the box is used.
function ENT:SiegeSpot( ext )
    local now = CurTime()
    if self.SiegeExt == ext and self.SiegePoint and now < ( self.SiegeUntil or 0 ) then return self.SiegePoint, self.SiegeHow end

    local best, bestFree, how

    -- 1. where players were seen walking in / stepping out (learned, works without reading the mod)
    local learned = ext.WADoorLocal
    if learned then
        local flat = Vector( learned.x, learned.y, 0 )
        local len  = flat:Length()

        if len > 20 then
            flat:Normalize()
            local ground = self:FindGround( ext:LocalToWorld( flat * math.max( len, 110 ) ), 48, 200 )
            if ground then best, how = ground, "learned door" end
        end
    end

    local door, fwd
    if not best and isfunction( ext.GetDoorway ) then
        local ok, dw = pcall( ext.GetDoorway, ext )
        if ok and istable( dw ) and isvector( dw.pos ) then
            door = ext:LocalToWorld( dw.pos )
            if isangle( dw.ang ) then fwd = ext:LocalToWorldAngles( dw.ang ):Forward() end
        end
    end

    if door and not best then
        local dirs = {}
        if fwd then
            dirs = { fwd, -fwd }
        else
            for k = 0, 7 do dirs[ #dirs + 1 ] = Angle( 0, k * 45, 0 ):Forward() end
        end

        for _, dir in ipairs( dirs ) do
            dir = Vector( dir.x, dir.y, 0 )
            dir:Normalize()

            -- clear line out of the doorway this way? (the box blocks the side it stands on)
            local out = util.TraceLine( { start = door + dir * 8, endpos = door + dir * 300, filter = self, mask = MASK_OPAQUE } )

            if not out.StartSolid and out.Fraction > 0.3 then
                local ground = self:FindGround( door + dir * 110, 48, 200 )

                if ground and ( not bestFree or out.Fraction > bestFree ) then
                    best, bestFree, how = ground, out.Fraction, "door"
                end
            end
        end
    end

    if not best then
        -- fallback: open ground around the box, nearest to the angel
        local centre = ext:GetPos()
        local radius = ext:BoundingRadius() + 110
        local bestD

        for k = 0, 11 do
            local ground = self:FindGround( centre + Angle( 0, k * 30, 0 ):Forward() * radius, 48, 200 )

            if ground then
                local d = ground:DistToSqr( self:GetPos() )
                if not bestD or d < bestD then best, bestD, how = ground, d, "ring" end
            end
        end
    end

    self.SiegeExt   = ext
    self.SiegePoint = best
    self.SiegeHow   = how
    self.SiegeUntil = now + 2

    return best, how
end

-- Several angels at the same door line up in a curve (an arc around the doorway, in front of it).
-- Each takes the slot that matches where it already is, so they don't cross each other's paths.
function ENT:SiegeSlot( ext, spot )
    local now = CurTime()
    self.SiegeActiveUntil = now + 1.5

    local c = ext:GetPos()
    local dir0 = Vector( spot.x - c.x, spot.y - c.y, 0 )
    if dir0:LengthSqr() < 1 then return spot end
    dir0:Normalize()

    local door = c + dir0 * 30
    local yaw0 = dir0:Angle().yaw

    -- every angel besieging this TARDIS right now
    local mates = {}
    for a in pairs( WEEPINGANGEL_LIST ) do
        if IsValid( a ) and ( a == self or ( a.SiegeExt == ext and ( a.SiegeActiveUntil or 0 ) > now ) ) then
            mates[ #mates + 1 ] = a
        end
    end

    if #mates <= 1 then return spot end

    local function Side( a )
        return math.NormalizeAngle( ( a:GetPos() - door ):Angle().yaw - yaw0 )
    end

    table.sort( mates, function( x, y )
        local sx, sy = Side( x ), Side( y )
        if sx == sy then return x:EntIndex() < y:EntIndex() end
        return sx < sy
    end )

    local idx = 1
    for i, a in ipairs( mates ) do
        if a == self then idx = i end
    end

    local R    = 130                                   -- distance from the door
    local step = math.Clamp( math.deg( 85 / R ), 20, 45 )   -- ~85 units between neighbours
    local off  = math.Clamp( ( idx - ( #mates + 1 ) / 2 ) * step, -110, 110 )

    local ground = self:FindGround( door + Angle( 0, yaw0 + off, 0 ):Forward() * R, 48, 200 )
    return ground or spot
end

local KNOCK_SOUNDS = { "physics/wood/wood_solid_impact_soft1.wav", "physics/wood/wood_solid_impact_soft2.wav", "physics/wood/wood_solid_impact_soft3.wav" }   -- soft knuckle raps
local POUND_SOUNDS = { "npc/zombie/zombie_pound_door.wav", "ambient/materials/door_hit1.wav", "physics/wood/wood_crate_impact_hard4.wav", "physics/wood/wood_crate_impact_hard5.wav" }
local BREAK_SOUNDS = { "physics/wood/wood_plank_break1.wav", "physics/wood/wood_crate_break1.wav" }

-- The TARDIS mod's own knock / bang sounds: found by searching the installed sound files inside a
-- tardis / drwho / doctor folder. Searched once, the first time it is needed.
local ModSounds   -- nil = not searched yet, otherwise { knock = {...}, bang = {...} } (sound paths)

local BANG_WORDS = { "bang", "pound", "slam", "thump", "smash" }

local function ScanSounds( dir, depth, out, budget )
    local files, dirs = file.Find( dir .. "/*", "GAME" )

    for _, f in ipairs( files or {} ) do
        local lf = string.lower( f )

        if string.EndsWith( lf, ".wav" ) or string.EndsWith( lf, ".mp3" ) or string.EndsWith( lf, ".ogg" ) then
            local path = dir .. "/" .. f
            local lp   = string.lower( path )

            if string.find( lp, "tardis", 1, true ) or string.find( lp, "drwho", 1, true ) or string.find( lp, "doctor", 1, true ) then
                local short = string.sub( path, 7 )   -- without the leading "sound/"

                if string.find( lf, "knock6", 1, true ) then
                    out.bang[ #out.bang + 1 ] = short
                elseif string.find( lf, "knock", 1, true ) then
                    out.knock[ #out.knock + 1 ] = short
                else
                    for _, w in ipairs( BANG_WORDS ) do
                        if string.find( lf, w, 1, true ) then out.bang[ #out.bang + 1 ] = short break end
                    end
                end
            end
        end
    end

    if depth > 0 then
        for _, d in ipairs( dirs or {} ) do
            budget.n = budget.n + 1
            if budget.n < 4000 then ScanSounds( dir .. "/" .. d, depth - 1, out, budget ) end
        end
    end
end

-- The TARDIS mod's known files: knock1-5 are normal knocking, knock6 is the banging
local MOD_KNOCKS = {}
for i = 1, 5 do MOD_KNOCKS[ i ] = "drmatt/tardis/events/knock" .. i .. ".wav" end
local MOD_BANG = "drmatt/tardis/events/knock6.wav"

local function GetModSounds()
    if ModSounds == nil then
        ModSounds = { knock = {}, bang = {} }

        for _, snd in ipairs( MOD_KNOCKS ) do
            if file.Exists( "sound/" .. snd, "GAME" ) then ModSounds.knock[ #ModSounds.knock + 1 ] = snd end
        end
        if file.Exists( "sound/" .. MOD_BANG, "GAME" ) then ModSounds.bang[ 1 ] = MOD_BANG end

        -- if the known files are not there (another version of the mod), search for similar ones
        if #ModSounds.knock == 0 or #ModSounds.bang == 0 then
            local found = { knock = {}, bang = {} }
            ScanSounds( "sound", 6, found, { n = 0 } )

            if #ModSounds.knock == 0 then ModSounds.knock = found.knock end
            if #ModSounds.bang  == 0 then ModSounds.bang  = found.bang  end
        end
    end

    return ModSounds
end

local function GetModKnock() return GetModSounds().knock end
local function GetModBang()  return GetModSounds().bang end

-- One angel at the door knocks; if the TARDIS is locked it pounds, trying to break in.
-- Only one angel per TARDIS makes the sound at a time (the others stand quietly).
function ENT:SiegeKnock( ext, now )
    if not cvKnock:GetBool() or TardisDoorOpen( ext ) then return end

    local k = ext.WAKnocker
    if IsValid( k ) and k ~= self and now - ( ext.WAKnockerT or 0 ) < 2 then return end
    ext.WAKnocker, ext.WAKnockerT = self, now

    if now < ( ext.WAKnockNext or 0 ) then return end

    local door   = TardisDoorPos( ext )
    local locked = TardisLocked( ext ) == true

    local inside = {}   -- sheltered players in this TARDIS hear it too (they are far away in the interior)
    for _, ply in ipairs( player.GetAll() ) do
        if ply.WAShelter and TardisOf( ply ) == ext then inside[ #inside + 1 ] = ply end
    end

    local intensity = cvKnockVol:GetFloat()

    local function Play( list, level, pitch, vol, shake )
        local snd = list[ math.random( #list ) ]
        vol = math.min( 1, vol * intensity )
        sound.Play( snd, door, level, pitch, vol )

        for _, ply in ipairs( inside ) do
            if IsValid( ply ) then
                ply:EmitSound( snd, 60, pitch, vol * 0.8 )
                if shake then util.ScreenShake( ply:GetPos(), shake * intensity, 6, 0.35, 300 ) end
            end
        end
    end

    local t, hits = 0, 0

    if locked and #GetModBang() > 0 then
        -- the TARDIS mod's own banging clip, once per round, with a few shake pulses while it plays
        Play( GetModBang(), 80, 100, 1, 4 )

        for i = 1, 3 do
            timer.Simple( i * 0.5, function()
                if not IsValid( ext ) then return end

                for _, ply in ipairs( inside ) do
                    if IsValid( ply ) then util.ScreenShake( ply:GetPos(), ( 3 + i ) * intensity, 6, 0.35, 300 ) end
                end
            end )
        end

        ext.WAKnockNext = now + 3 + math.Rand( 5, 9 )
    elseif locked then
        -- frantic pounding that speeds up and gets louder, ending in a splintering crack
        hits = math.random( 7, 11 )

        for i = 1, hits do
            local f = i / hits
            t = t + Lerp( f, 0.45, 0.16 ) * math.Rand( 0.85, 1.15 )

            timer.Simple( t, function()
                if IsValid( ext ) then Play( POUND_SOUNDS, 85, math.random( 70, 90 ), Lerp( f, 0.6, 1 ), 1 + 5 * f ) end
            end )
        end

        timer.Simple( t + 0.25, function()
            if IsValid( ext ) then Play( BREAK_SOUNDS, 90, math.random( 75, 90 ), 1, 8 ) end
        end )

        ext.WAKnockNext = now + t + 0.5 + math.Rand( 4, 8 )
    elseif #GetModKnock() > 0 then
        -- the TARDIS mod's own knock sound (one clip per round; it is usually a whole knocking sequence)
        Play( GetModKnock(), 75, 100, 1 )
        ext.WAKnockNext = now + math.Rand( 9, 16 )
    else
        -- knock, knock, knock
        hits = math.random( 2, 3 )

        for i = 1, hits do
            t = t + ( i == 1 and 0 or math.Rand( 0.9, 1.3 ) )

            timer.Simple( t, function()
                if IsValid( ext ) then Play( KNOCK_SOUNDS, 65, math.random( 96, 110 ), 0.8 ) end
            end )
        end

        ext.WAKnockNext = now + t + math.Rand( 7, 14 )
    end
end

-- No victim, but a player is sheltered in a TARDIS nearby: go and stand in front of its door.
-- Moves only while unobserved, like everything else. Returns true if this angel is busy with that.
function ENT:TardisSiege( now, dt )
    local range = cvTardisSiege:GetFloat()
    if range <= 0 then self.SiegeStatus = "off (range 0)" return false end
    if self.Dormant then self.SiegeStatus = "dormant" return false end

    local myPos = self:GetPos()
    local target, bestD
    local sheltered = 0

    for _, ply in ipairs( player.GetAll() ) do
        if ply.WAShelter then
            sheltered = sheltered + 1
            local ext = TardisOf( ply )

            if ext then
                local d = myPos:Distance( ext:GetPos() )

                if d <= range and ( not bestD or d < bestD ) then target, bestD = ext, d end
            end
        end
    end

    if not target then
        self.SiegeStatus = sheltered > 0 and "sheltered player, TARDIS out of range" or "nobody sheltered"
        return false
    end

    local spot, how = self:SiegeSpot( target )
    if not spot then self.SiegeStatus = "no open ground at the door" return false end

    -- with company: take a place in the curve around the door (recalculated once a second)
    self.SiegeExt = target
    if self.SlotExt ~= target or now >= ( self.SlotUntil or 0 ) then
        self.SlotSpot  = self:SiegeSlot( target, spot )
        self.SlotExt   = target
        self.SlotUntil = now + 1
    end
    spot = self.SlotSpot or spot

    -- never moves in view
    if self:IsObserved() then
        self.FrozenUntil = now + SEEN_GRACE
        self.WasObserved = true
        self.SiegeStatus = "seen - frozen"
        return true
    end

    self.WasObserved = false
    if now < self.FrozenUntil then return true end

    local to = spot - myPos
    to.z = 0
    local flat = to:Length()

    if flat > 30 then
        self.SiegeStatus = string.format( "walking to the %s (%d units)", how or "?", flat )

        -- progress watch: if it is not getting closer (obstacles, detours) it jumps there instead
        if self.SiegeSpotKey ~= spot then
            self.SiegeSpotKey  = spot
            self.SiegeBest     = flat
            self.SiegeProgress = now
        end

        local jump = false

        if self:StalkStep( dt, to, flat, HAUNT_SPEED_MUL, 0 ) then
            self.StuckTime = 0
            self:SetAngles( Angle( 0, to:Angle().yaw + MODEL_YAW_OFFSET, 0 ) )
            self:ChoosePose( flat )
            self:PlayMoveSound()

            if flat < self.SiegeBest - 25 then
                self.SiegeBest     = flat
                self.SiegeProgress = now
            elseif now - self.SiegeProgress > 2.5 then
                jump = true
            end
        else
            self.StuckTime = ( self.StuckTime or 0 ) + dt
            if self.StuckTime > 0.6 then jump = true end
        end

        if jump then
            -- cannot get there on foot: appear in front of the door, but only where nobody can see it
            if not self:IsObservedAt( spot ) then
                self:SetPos( spot )

                local face = TardisDoorPos( target ) - spot
                face.z = 0
                if face:LengthSqr() > 1 then self:SetAngles( Angle( 0, face:Angle().yaw + MODEL_YAW_OFFSET, 0 ) ) end

                self:SetPose( MODEL_IDLE )
                self.StuckTime     = 0
                self.SiegeBest     = 0
                self.SiegeProgress = now
            end
        end
    else
        -- arrived: stands at the door facing it, face covered
        self.SiegeStatus = "waiting at the " .. ( how or "?" )
        self:SiegeKnock( target, now )

        local face = TardisDoorPos( target ) - myPos
        face.z = 0
        if face:LengthSqr() > 1 then self:SetAngles( Angle( 0, face:Angle().yaw + MODEL_YAW_OFFSET, 0 ) ) end
        self:SetPose( MODEL_IDLE )
    end

    return true
end

-- Is this position inside the TARDIS interior described by `rec` ({ ext, int })?
-- (the interior is a separate room far away on the map; closer to it than to the exterior)
local function InTardisZone( pos, rec )
    if not rec or not IsValid( rec.ext ) or not IsValid( rec.int ) then return false end

    local radius = InteriorRadius( rec.int )
    local dInt   = pos:Distance( rec.int:GetPos() )

    return dInt < radius and dInt < pos:Distance( rec.ext:GetPos() )
end

-- Put the angel on the ground near a TARDIS exterior, facing it. Only when nobody can see the move.
function ENT:MoveNearExterior( ext )
    if self:IsObserved() then return false end

    local epos = ext:GetPos()

    for _ = 1, 16 do
        local dir    = Angle( 0, math.Rand( 0, 360 ), 0 ):Forward()
        local ground = self:FindGround( epos + dir * math.Rand( 140, 320 ), 48, 200 )

        if ground and not self:IsObservedAt( ground ) then
            self:SetPos( ground )

            local face = epos - ground
            face.z = 0
            if face:LengthSqr() > 1 then
                self:SetAngles( Angle( 0, face:Angle().yaw + MODEL_YAW_OFFSET, 0 ) )
            end

            return true
        end
    end

    return false
end

-- Keeps angels out of trouble around TARDIS interiors (once a second):
--  * an angel inside an interior whose player is gone, sheltered, or somewhere else is put next
--    to that TARDIS's exterior (so it can't sit stuck in a far-away room, or in the void behind it)
--  * an angel in the interior with its victim, but without a line of sight to them for a while
--    (it is stuck on odd ground or outside the walls) is teleported to a spot the victim can see
function ENT:TardisRescue( now )
    if now < ( self.NextRescue or 0 ) then return end
    self.NextRescue = now + 1

    if cvTardis:GetInt() < 0 then return end

    local myPos  = self:GetPos()
    local victim = self.Victim

    local vint
    if IsValid( victim ) and TardisOf( victim ) then
        local ok, i = pcall( victim.GetTardisData, victim, "interior" )
        if ok and IsValid( i ) then vint = i end
    end

    for _, ply in ipairs( player.GetAll() ) do
        local rec = ply.WATardisRec

        if rec and InTardisZone( myPos, rec ) then
            if vint ~= rec.int then
                -- its victim is not in here
                self.NoLosSince = nil
                self:MoveNearExterior( rec.ext )
            elseif IsValid( victim ) then
                -- its victim is in here: it must be able to reach them
                local inRoom = InsideInterior( rec.int, myPos )

                local tr = util.TraceLine( {
                    start  = victim:EyePos(),
                    endpos = myPos + self.SeenPoints[ 2 ],
                    filter = { victim, self },
                    mask   = MASK_SOLID
                } )

                if inRoom and not tr.Hit then
                    self.NoLosSince = nil
                elseif not self.NoLosSince then
                    self.NoLosSince = now
                elseif now - self.NoLosSince > ( inRoom and 8 or 2 ) then   -- outside the walls: act quickly
                    self.NoLosSince = now - 1   -- try again soon if this fails
                    self.NextTeleport = 0

                    if not self:AmbushTeleport( { min = 250, max = 700, los = true, ignoreThrottle = true } ) and not inRoom then
                        self:MoveNearExterior( rec.ext )   -- could not place it in the room: get it out of the void
                    end
                end
            end

            return
        end
    end

    self.NoLosSince = nil
end

-- Distance from this spot to the nearest wall / prop around it (up to 100 units)
function ENT:WallGap( pos )
    local origin = pos + Vector( 0, 0, self.SeenPoints[ 2 ].z )
    local gap    = 100

    for k = 0, 7 do
        local tr = util.TraceLine( {
            start  = origin,
            endpos = origin + Angle( 0, k * 45, 0 ):Forward() * 100,
            filter = { self, self.Victim },
            mask   = MASK_NPCSOLID
        } )
        gap = math.min( gap, 100 * tr.Fraction )
    end

    return gap
end

function ENT:AmbushTeleport( opts )
    opts = opts or {}

    if not self:InTeleportRange() then return false end

    local now = CurTime()
    if now < self.NextTeleport then return false end
    if not opts.ignoreThrottle and now < self.NextTeleportTry then return false end

    local victim = self.Victim
    if not IsValid( victim ) then return false end

    local minD      = opts.min or AMBUSH_MIN_DIST
    local maxD      = opts.max or AMBUSH_MAX_DIST
    local fit       = cvFit:GetBool()

    -- proportional to the room: never farther than the free space around the victim (open ground
    -- is ~1500+ so nothing changes outside; a small interior shrinks the distances to fit)
    if fit then
        maxD = math.min( maxD, math.max( HOLD_NEAR, self.Openness * 1.2 ) )
        minD = math.min( minD, maxD * 0.7 )
    end

    local spread    = opts.spread or 80
    local flexMin   = opts.flexMin or 0.5
    local needLOS   = opts.los or TardisOf( victim ) ~= nil   -- inside a TARDIS: only spots the victim can see (no void / behind walls)
    local vint      = InteriorOf( victim )
    local sightMask = SightMask( victim )

    local vpos      = victim:GetPos()
    local eye       = victim:EyePos()
    local behindYaw = victim:EyeAngles().yaw + 180
    local centre    = self.SeenPoints[ 2 ]

    for i = 1, 32 do
        local behind = ( i <= 22 ) or opts.behindOnly
        local yaw    = behind and ( behindYaw + math.Rand( -spread, spread ) ) or math.Rand( 0, 360 )
        local dir    = Angle( 0, yaw, 0 ):Forward()
        local dist   = math.Rand( minD, maxD )

        if needLOS or ( fit and i <= 28 ) then
            -- look a bit past the chosen distance so a wall just beyond it still counts
            local reach = fit and dist * 1.6 or dist
            local ray = util.TraceLine( {
                start  = eye,
                endpos = eye + dir * reach,
                filter = { victim, self },
                mask   = sightMask
            } )

            if ray.Hit then
                local free = reach * ray.Fraction

                if fit then
                    dist = math.min( dist, free * 0.6, free - 60 )   -- proportional: never near the wall
                else
                    dist = free - 48
                end
            end
        end

        if dist >= minD * flexMin then
            local ground = self:FindGround( vpos + dir * dist, 48, 160 )

            if ground
                and math.abs( ground.z - vpos.z ) < 100
                and bit.band( util.PointContents( ground + Vector( 0, 0, 8 ) ), MASK_WATER ) == 0
                and ( not vint or InsideInterior( vint, ground ) )
                and not self:IsObservedAt( ground ) then

                local ok = true
                if needLOS then
                    local tr = util.TraceLine( {
                        start  = eye,
                        endpos = ground + centre,
                        filter = { victim, self },
                        mask   = sightMask
                    } )
                    ok = not tr.Hit
                end

                -- keep a gap from walls and props (relaxed on the last tries so it can still be placed)
                if ok and fit and self:WallGap( ground ) < ( i <= 22 and 75 or 35 ) then ok = false end

                if ok then
                    self:SetPos( ground )
                    self:FaceVictim()

                    if opts.pose then
                        self:SetPose( opts.pose )
                    else
                        self.NextPoseChange = 0
                        self:ChoosePose( dist )
                    end

                    self.NextTeleport = now + TELEPORT_COOLDOWN
                    self.LastTeleport = now
                    return true
                end
            end
        end
    end

    self.NextTeleportTry = now + 0.4
    return false
end

function ENT:ChoosePose( dist )
    local now = CurTime()
    if now < self.NextPoseChange then return end
    self.NextPoseChange = now + math.Rand( 0.4, 1.2 )

    local r = math.random()
    local mdl

    if dist < 350 then
        mdl = ( r < 0.7 ) and MODEL_ATTACK or ( ( r < 0.9 ) and MODEL_POINT or MODEL_IDLE )
    else
        mdl = ( r < 0.4 ) and MODEL_IDLE or ( ( r < 0.7 ) and MODEL_POINT or MODEL_ATTACK )
    end

    self:SetPose( mdl )
end

function ENT:PlayMoveSound()
    if not cvMoveSnd:GetBool() then return end

    local now = CurTime()
    if now < self.NextMoveSound then return end
    self.NextMoveSound = now + math.Rand( 0.5, 0.9 )

    self:EmitSound( STONE_SOUNDS[ math.random( #STONE_SOUNDS ) ], 65, math.random( 80, 95 ), 0.6 )
end

-- --------------------------------------------------------
-- Touch
-- --------------------------------------------------------

function ENT:TouchVictim( ply )
    local now = CurTime()
    if now < self.NextTouch then return false end
    if ( ply.WAShelterUntil or 0 ) > now then return false end   -- just left a TARDIS

    self.Served = self.Served or {}
    self.Served[ ply ] = now

    if cvTouchMode:GetInt() == 1 then
        local dmg = DamageInfo()
        dmg:SetAttacker( self )
        dmg:SetInflictor( self )
        dmg:SetDamage( ply:Health() + ply:Armor() + 100 )
        dmg:SetDamageType( DMG_SLASH )
        dmg:SetDamageForce( Vector( 0, 0, 1 ) )
        ply:TakeDamageInfo( dmg )

        self.NextTouch = now + TOUCH_COOLDOWN
        return true
    end

    -- Double touch: a second touch soon after the first is lethal
    if cvDoubleTouch:GetBool() and ply.WALastTouch and now - ply.WALastTouch <= cvDoubleWindow:GetFloat() then
        ply.WALastTouch = nil

        if ply:InVehicle() then ply:ExitVehicle() end
        ply:EmitSound( sndSnap, 75, 100 )

        local dmg = DamageInfo()
        dmg:SetAttacker( self )
        dmg:SetInflictor( self )
        dmg:SetDamage( ply:Health() + ply:Armor() + 100 )
        dmg:SetDamageType( DMG_SLASH )
        dmg:SetDamageForce( Vector( 0, 0, 1 ) )
        ply:TakeDamageInfo( dmg )

        self.NextTouch = now + TOUCH_COOLDOWN
        return true
    end

    local dest = FindTimeDestination( ply, self:GetPos() )
    if not dest then
        self.NextTouch = now + 1
        return false
    end

    if ply:InVehicle() then ply:ExitVehicle() end

    ply:ScreenFade( SCREENFADE.IN, Color( 255, 255, 255, 255 ), 0.8, 0.3 )
    ply:EmitSound( sndZap, 75, 100 )
    ply:EmitSound( sndWhoosh, 75, 95 )

    ply:SetPos( dest )
    ply:SetLocalVelocity( vector_origin )
    ply:ChatPrint( "[Weeping Angel] The Angel touched you and cast you back in time!" )
    ply.WALastTouch = now

    if cvPastFilter:GetBool() then
        net.Start( "WeepingAngel_PastFilter" )
        net.WriteFloat( cvPastTime:GetFloat() )
        net.Send( ply )
    end

    self.NextTouch = now + TOUCH_COOLDOWN
    return true
end

-- --------------------------------------------------------
-- Target selection
-- --------------------------------------------------------

function ENT:ScoreVictim( ply, players )
    local ppos  = ply:GetPos()
    local score = self:GetPos():Distance( ppos )

    if cvSmart:GetBool() then
        local now = CurTime()

        -- The player who had it in view most recently is the one that "let it go": it follows them.
        -- (The preference fades over 12 s after they last looked at it.)
        if ply == self.LatestWatcher then
            score = score - 700 * math.Clamp( 1 - ( now - self.LatestWatchT ) / 12, 0, 1 )
        end

        -- scared / touched by this angel lately: share the attention
        local served = self.Served and self.Served[ ply ]
        if served and now - served < 20 then
            score = score + 400 * ( 1 - ( now - served ) / 20 )
        end
    end

    for _, other in ipairs( players ) do
        if other ~= ply and other:Alive() and other:GetPos():DistToSqr( ppos ) < 600 * 600 then
            score = score + 350
        end
    end

    for ang in pairs( WEEPINGANGEL_LIST ) do
        if IsValid( ang ) and ang ~= self and ang.Victim == ply then
            score = score + 500
        end
    end

    return score
end

-- Remember when each player last had this angel in view (about 10 times a second), and who
-- that was most recently. `force` skips the throttle (used at the moment it is freed).
function ENT:UpdateWatchers( now, force )
    if not force and now < ( self.NextWatch or 0 ) then return end
    self.NextWatch = now + 0.1

    self.WatchedAt = self.WatchedAt or {}
    local pos = self:GetPos()

    local latest, latestT
    for _, ply in ipairs( player.GetAll() ) do
        if IsValid( ply ) then
            if self:PlayerCanSee( ply, pos ) then self.WatchedAt[ ply ] = now end

            local t = self.WatchedAt[ ply ]
            if t and ( not latestT or t > latestT ) then latest, latestT = ply, t end
        end
    end

    self.LatestWatcher, self.LatestWatchT = latest, latestT or 0
end

-- More players = it is unobserved less often, so its patience runs out a bit faster (smart targeting)
function ENT:CrowdMul()
    if not cvSmart:GetBool() then return 1 end

    local n = 0
    for _, ply in ipairs( player.GetAll() ) do
        if IsValidTarget( ply ) then n = n + 1 end
    end

    return math.Clamp( 1 + 0.5 * ( n - 1 ), 1, 2 )
end

-- Choose who to hunt. `force` = it was just freed (nobody has it in view any more): decide right now,
-- ignoring the timers, so the player who looked away last becomes the target.
function ENT:UpdateVictim( force )
    local now = CurTime()
    local cur = self.Victim
    local smart = cvSmart:GetBool()

    local curValid = IsValidTarget( cur )
    if curValid and not force and now < self.NextRetarget then return end
    self.NextRetarget = now + 1

    if curValid and smart then
        -- never switch in the middle of a strike or a scare
        if self.Mode == "strike" or self.ScareState ~= nil then return end

        if force then
            if now - ( self.LastRelease or 0 ) < 2.5 then return end      -- no ping-pong
        elseif now - ( self.VictimSince or 0 ) < 6 then
            return                                                         -- just chose: give it time
        end
    end

    local players = player.GetAll()
    local best, bestScore

    for _, ply in ipairs( players ) do
        if IsValidTarget( ply ) then
            local s = self:ScoreVictim( ply, players )
            if not bestScore or s < bestScore then
                best, bestScore = ply, s
            end
        end
    end

    if curValid and best ~= cur then
        local curScore = self:ScoreVictim( cur, players )

        if smart then
            -- scores can be negative (bonus), so the margin is a plain amount, not a percentage
            if bestScore > curScore - ( force and 0 or 150 ) then best = cur end
        elseif bestScore > curScore * 0.6 then
            best = cur
        end
    end

    if best ~= cur then
        self.VictimSince = now

        if force and curValid then
            self.LastRelease = now               -- a hand-over between two valid targets keeps its tension
        else
            self.Tension = math.min( self.Tension, 0.4 )
        end

        self.Mode       = "haunt"
        self.ScareState = nil
        self.StuckTime  = 0
        self.PointTime  = 0
        self.PlayerPath = {}
    end

    self.Victim = best
end

-- --------------------------------------------------------
-- Director
-- --------------------------------------------------------

function ENT:GetHoldDistance()
    local hold = Lerp( self.Tension, HOLD_FAR, HOLD_NEAR )

    -- fit_space: it stays within about 60% of the average free distance around you (small and
    -- medium rooms pull it in, wide open ground does not change anything)
    local roomMul = cvFit:GetBool() and 0.6 or 1.2
    return math.min( hold, math.max( HOLD_NEAR, self.Openness * roomMul ) )
end

function ENT:IsBehindVictim()
    local victim = self.Victim

    local fwd = victim:EyeAngles():Forward()
    fwd.z = 0
    fwd:Normalize()

    local d = self:GetPos() - victim:GetPos()
    d.z = 0
    if d:LengthSqr() < 1 then return true end
    d:Normalize()

    return fwd:Dot( d ) < 0.1
end

function ENT:ReadyToStrike( now )
    if not cvAllowTouch:GetBool() then return false end

    -- just stepped out of a TARDIS: it can move and scare, but not strike yet
    if IsValid( self.Victim ) and ( self.Victim.WAShelterUntil or 0 ) > now then return false end

    if self.Tension < 1 then return false end
    if now < self.NextTouch then return false end

    return self:IsBehindVictim()
end

function ENT:BeginStrike( now )
    self.Mode        = "strike"
    self.StrikeUntil = now + STRIKE_TIMEOUT
    self.StuckTime   = 0
    self.PointTime   = 0
    self.ScareState  = nil
end

function ENT:EndStrike( now, tension )
    self.Mode         = "haunt"
    self.Tension      = tension
    self.StuckTime    = 0
    self.PointTime    = 0
    self.NextRelocate = now + math.Rand( RELOCATE_MIN, RELOCATE_MAX )
    self.NextScare    = now + ScareDelay( SCARE_COOLDOWN_MIN, SCARE_COOLDOWN_MAX )
end

function ENT:OnRevealed( now )
    self.NextRelocate = math.max( self.NextRelocate, now + math.Rand( RELOCATE_MIN, RELOCATE_MAX ) * 0.6 )

    if self.ScareState == "armed" then
        self.ScareState = "seen"
        self.RetreatAt  = 0

        if IsValid( self.Victim ) then
            self.Served = self.Served or {}
            self.Served[ self.Victim ] = now
        end
    end
end

function ENT:SnapBehind( now )
    local victim = self.Victim
    if not IsValid( victim ) or now < self.NextSnap then return false end
    if not self:InTeleportRange() then return false end

    local vel = victim:GetVelocity()
    vel.z = 0
    if vel:LengthSqr() > SCARE_MOVE_SPEED * SCARE_MOVE_SPEED then
        self.ScareYaw = vel:Angle().yaw + 180 + self.ScareSide
    end

    local vpos    = victim:GetPos()
    local eye     = victim:EyePos()
    local centre  = self.SeenPoints[ 2 ]
    local contact = self:ContactDist()
    local vint      = InteriorOf( victim )
    local sightMask = SightMask( victim )

    for _, off in ipairs( { 0, 25, -25, 50, -50 } ) do
        local dir = Angle( 0, self.ScareYaw + off, 0 ):Forward()

        for _, mul in ipairs( { 1, 0.8, 0.65 } ) do
            local d = self.ScareDist * mul

            local ray = util.TraceLine( {
                start  = eye,
                endpos = eye + dir * d,
                filter = { victim, self },
                mask   = sightMask
            } )
            if ray.Hit then d = d * ray.Fraction - ( self.HullMaxs.x + 8 ) end

            if d >= contact then
                local ground = self:FindGround( vpos + dir * d, 48, 160 )

                if ground
                    and math.abs( ground.z - vpos.z ) < 100
                    and bit.band( util.PointContents( ground + Vector( 0, 0, 8 ) ), MASK_WATER ) == 0
                    and ( not vint or InsideInterior( vint, ground ) )
                    and not self:IsObservedAt( ground ) then

                    local tr = util.TraceLine( {
                        start  = eye,
                        endpos = ground + centre,
                        filter = { victim, self },
                        mask   = sightMask
                    } )

                    if not tr.Hit then
                        if ground:DistToSqr( self:GetPos() ) > 16 then
                            self:SetPos( ground )
                            self:FaceVictim()
                            self:SetPose( SCARE_POSE )
                        end
                        return true
                    end
                end
            end
        end
    end

    self.NextSnap = now + 0.2
    return false
end

function ENT:BeginScare( now )
    local victim = self.Victim
    if now < self.NextTeleport then return false end
    if not self:InTeleportRange() then return false end

    self.ScareDist = math.Rand( SCARE_DIST_MIN, SCARE_DIST_MAX )
    self.ScareSide = math.Rand( -SCARE_SIDE_DEG, SCARE_SIDE_DEG )
    self.ScareYaw  = victim:EyeAngles().yaw + 180 + self.ScareSide
    self.NextSnap  = 0

    if not self:SnapBehind( now ) then return false end

    self.ScareState   = "armed"
    self.ScareExpire  = now + SCARE_WAIT
    self.RetreatAt    = 0
    self.NextTeleport = now + TELEPORT_COOLDOWN
    self.LastTeleport = now

    self:PlayMoveSound()
    return true
end

function ENT:EndScare( now, hold )
    local ok = self:AmbushTeleport( { min = hold * 0.9, max = hold * 1.2, los = true, flexMin = 0.4 } )
            or self:AmbushTeleport( { min = hold * 0.9, max = hold * 1.3, ignoreThrottle = true } )

    if ok then
        self.ScareState   = nil
        self.RetreatAt    = 0
        self.NextRelocate = now + math.Rand( RELOCATE_MIN, RELOCATE_MAX )
        self.NextScare    = now + ScareDelay( SCARE_COOLDOWN_MIN, SCARE_COOLDOWN_MAX ) * ( 1.3 - 0.8 * self.Tension )
    end

    return ok
end

function ENT:MoveToward( dt, to, flat, speedMul, stopDist )
    local moveDir, moveFlat = self:GetMoveDirection( to, flat )

    -- stopDist is measured to the victim, not to a breadcrumb. When following the
    -- trail, walk the full step and just refuse to move if we are already close enough.
    local stop = stopDist
    if moveDir ~= to then
        if flat <= stopDist then return false end
        stop = 0
    end

    if self:StalkStep( dt, moveDir, moveFlat, speedMul, stop ) then
        self.StuckTime = 0
        self:FaceVictim()
        self:ChoosePose( flat )
        self:PlayMoveSound()
        return true
    end

    return false
end

function ENT:StalkHaunt( dt, now, to, flat )
    if self:ReadyToStrike( now ) then
        self:BeginStrike( now )
        return
    end

    local hold = self:GetHoldDistance()

    -- Close-range scare in progress
    if self.ScareState == "armed" then
        if now > self.ScareExpire then
            if not self:EndScare( now, hold ) and now > self.ScareExpire + 8 then
                self.ScareState = nil
            end
        else
            self:SnapBehind( now )
        end
        return

    elseif self.ScareState == "seen" then
        if self.RetreatAt == 0 then self.RetreatAt = now + math.Rand( 1.5, 3 ) end

        if now >= self.RetreatAt then
            if not self:EndScare( now, hold ) and now > self.RetreatAt + 8 then
                self.ScareState = nil
            end
        end
        return
    end

    -- Close-range scare trigger
    if cvScares:GetBool() and now >= self.NextScare and self.Tension >= SCARE_MIN_TENSION and flat < 1800 then
        if self:BeginScare( now ) then return end
        self.ScareFails = self.ScareFails + 1
        self.NextScare  = now + 3
    end

    -- You looked away and back: it has already moved
    if self.InstantMove then
        self.InstantMove = false

        local ok = self:AmbushTeleport( { min = hold * 0.9, max = hold * 1.2, los = true, flexMin = 0.4, ignoreThrottle = true } )
        if not ok then
            ok = self:AmbushTeleport( { min = hold * 0.7, max = hold * 1.3, flexMin = 0.3, ignoreThrottle = true } )
        end

        if ok then
            self.NextRelocate = now + math.Rand( RELOCATE_MIN, RELOCATE_MAX ) * ( 1.2 - 0.6 * self.Tension )
            self.StuckTime    = 0
            return
        end
    end

    -- Catch up if far away
    if flat > FAR_TELEPORT_DIST and self:AmbushTeleport( { min = hold, max = hold * 1.4 } ) then
        return
    end

    if flat > hold + 60 then
        local mul = Lerp( math.Clamp( ( flat - 900 ) / 900, 0, 1 ), HAUNT_SPEED_MUL, 1.2 )

        if not self:MoveToward( dt, to, flat, mul, hold ) then
            self.StuckTime = self.StuckTime + dt

            if self.StuckTime > STUCK_TIME then
                self.SteerSign = -self.SteerSign
                if self:AmbushTeleport( { min = hold, max = hold * 1.3, ignoreThrottle = true } ) then
                    self.StuckTime = 0
                end
            end
        end

    elseif now >= self.NextRelocate or ( flat < hold * 0.5 and now - self.LastTeleport > 6 ) then
        -- 1. Try to teleport somewhere with line-of-sight
        local ok = self:AmbushTeleport( { min = hold * 0.9, max = hold * 1.2, los = true, flexMin = 0.4 } )

        -- 2. WALL FALLBACK: If behind a wall/prop, teleport to ANY valid unobserved spot!
        if not ok then
            ok = self:AmbushTeleport( { min = hold * 0.7, max = hold * 1.3, flexMin = 0.3, ignoreThrottle = true } )
        end

        if ok then
            self.NextRelocate = now + math.Rand( RELOCATE_MIN, RELOCATE_MAX ) * ( 1.2 - 0.6 * self.Tension )
        else
            self.NextRelocate = now + 1.5
        end

        self.StuckTime = 0
    else
        self.StuckTime = 0
    end
end

function ENT:StrikePose( flat )
    if flat <= POINT_DIST then
        self:SetPose( MODEL_POINT )
    elseif flat <= FANG_DIST then
        self:SetPose( MODEL_ATTACK )
    else
        self:ChoosePose( flat )
    end
end

function ENT:StalkStrike( dt, now, to, flat, dz )
    if now > self.StrikeUntil then
        self:EndStrike( now, 0.5 )
        return
    end

    local contact = self:ContactDist()
    local close   = flat <= POINT_DIST and dz <= 90

    if close then
        self:FaceVictim()

        if flat <= contact + TOUCH_REACH then
            self.PointTime = self.PointTime + dt
            self.StuckTime = 0

            if flat > contact + 1 then
                if self:StalkStep( dt, to, flat, POINT_CREEP_MUL, contact ) then
                    self:FaceVictim()
                    self:PlayMoveSound()
                end
            end

            local pressed   = flat <= contact + 6 or self.PointTime >= POINT_WAIT + 2
            local blindOver = now - self.LastSeenByPlayer >= STRIKE_BLIND_TIME
            local ready     = pressed and blindOver and self.PointTime >= POINT_WAIT
            self:SetPose( ready and MODEL_ATTACK or MODEL_POINT )

            if ready and self:TouchVictim( self.Victim ) then
                self:Feed()
                self:EndStrike( now, 0 )
            end

            return
        end

        self:SetPose( MODEL_POINT )
    else
        self.PointTime = 0
    end

    local mul = close and POINT_CREEP_MUL or STRIKE_SPEED_MUL

    -- MoveToward follows the player's footsteps around corners (breadcrumbs)
    if self:MoveToward( dt, to, flat, mul, contact ) then
        self:StrikePose( flat )
    else
        self.StuckTime = self.StuckTime + dt

        if self.StuckTime > STUCK_TIME then
            self.SteerSign = -self.SteerSign
            if self:AmbushTeleport( { min = 150, max = 300, los = true, flexMin = 0.4, ignoreThrottle = true } ) then
                self.StuckTime = 0
            end
        end
    end
end

function ENT:Stalk( dt )
    local now    = CurTime()
    local victim = self.Victim

    local to = victim:GetPos() - self:GetPos()
    local dz = math.abs( to.z )
    to.z = 0
    local flat = to:Length()

    if self.Mode == "strike" then
        if not cvAllowTouch:GetBool() then
            self:EndStrike( now, 0.5 )
            return
        end

        self:StalkStrike( dt, now, to, flat, dz )
    else
        self:StalkHaunt( dt, now, to, flat )
    end
end

-- --------------------------------------------------------
-- Feeding: each touch makes this angel hungrier (needs weepingangel_feeding 1)
-- --------------------------------------------------------
-- ========================================================
-- Flashlight blinks
--
-- An angel near a player who has their flashlight ON can, under certain conditions,
-- make it BLINK slowly a few times and then blow it out.
--
--   Conditions: the hunt has built up (tension), the angel is calm (haunting, no scare
--   running), the player cannot see it move (it stands in the dark, or the blackout
--   option is on), and a cooldown has passed. A timer runs first, longer in real darkness,
--   so the player has time to focus on the light.
--
--   Each blink: the light goes OFF, and only while it is off the angel changes pose and
--   moves (1st blink it vanishes, the next ones it reappears closer, in front of the
--   player). The light only comes back a safe moment after the angel finished, so you
--   never see it move.
--
--   Last: the light is blown out for weepingangel_flashlight_block seconds and the angel
--   stands right in front of you (sometimes behind you) when you turn it back on.
--
--   Also: if you switch your own flashlight OFF in the dark near an angel, it comes to the
--   front of you, so the next time you turn the light on, it is there.
-- ========================================================
local function SetFlashlight( ply, on )
    ply.WAFlashInternal = true      -- so our own switching is not blocked by the hook below
    ply:Flashlight( on )
    ply.WAFlashInternal = nil
end

-- full-screen black for `dur` seconds (only if weepingangel_flashlight_blackout is on)
local function Blackout( ply, dur )
    if not cvFlashBlackout:GetBool() then return end

    net.Start( "WeepingAngel_Blackout" )
    net.WriteFloat( dur )
    net.Send( ply )
end

-- Can this player not see the angel move? (it is in the dark for them, or the blackout hides it)
function ENT:FlashCanHide( ply )
    if cvFlashBlackout:GetBool() then return true end
    return cvDarkness:GetBool() and self:IsAmbientDark( ply, self:GetPos() )
end

function ENT:FlashEligible()
    return not self.Dormant and not self.FlashSeq and self.Mode == "haunt"
        and self.ScareState == nil and CurTime() - self.SpawnTime >= FLASH.MIN_AGE
end

-- a different statue pose than the current one
-- Debug text: why is (or isn't) this angel blinking its victim's flashlight?
function ENT:FlashStatus( now )
    local ply = self.Victim
    if not cvFlashDrain:GetBool() then return "disabled" end
    if not IsValid( ply ) then return "no victim" end

    local st = ply.WAFlash
    if st then
        if st.owner ~= self then return "another angel is busy with you" end
        if st.ev == "wait" then
            return string.format( "timer %.1fs%s", math.max( 0, st.at - now ), self:FlashCanHide( ply ) and "" or " (paused: not hidden)" )
        end
        return string.format( "blinking %d/%d  [%s]", st.step or 0, st.nBlinks or 0, st.ev )
    end

    if now < ( ply.WAFlashNext or 0 ) then return string.format( "cooldown %.0fs", ply.WAFlashNext - now ) end
    if self.Mode ~= "haunt" then return "no: strike mode" end
    if self.ScareState ~= nil then return "no: scare running (" .. tostring( self.ScareState ) .. ")" end
    if now - self.SpawnTime < FLASH.MIN_AGE then return string.format( "no: just spawned (%.0fs)", FLASH.MIN_AGE - ( now - self.SpawnTime ) ) end
    if self:GetPos():Distance( ply:GetPos() ) > cvFlashDist:GetFloat() then return "no: too far" end

    if ply:FlashlightIsOn() then
        if self:FlashCanHide( ply ) then return "ready (starts timer)" end
        return cvDarkness:GetBool() and "no: not in the dark (see light line)" or "no: darkness feature is off"
    end

    return "no: flashlight is off"
end

function ENT:ChangePoseNow()
    local pick = POSES[ math.random( #POSES ) ]

    if pick == self.CurPose then
        for i, m in ipairs( POSES ) do
            if m == pick then
                pick = POSES[ i % #POSES + 1 ]
                break
            end
        end
    end

    self:SetPose( pick )
end

-- Put the angel `dist` units from the player, `yawOff` degrees away from where they look
-- (0 = straight ahead, 180 = directly behind). needLOS = they must be able to see the spot.
-- Spots are checked like every other move: valid ground, not water, not seen by anyone else.
function ENT:PlaceNear( ply, yawOff, dist, needLOS )
    local vpos   = ply:GetPos()
    local eye    = ply:EyePos()
    local centre = self.SeenPoints[ 2 ]
    local base   = ply:EyeAngles().yaw + yawOff

    for i = 1, 14 do
        local yaw = base + ( i == 1 and 0 or math.Rand( -35, 35 ) )
        local dir = Angle( 0, yaw, 0 ):Forward()
        local d   = dist * ( i <= 7 and 1 or math.Rand( 0.6, 0.9 ) )

        -- interiors: fit the spot into the free space
        local ray = util.TraceLine( { start = eye, endpos = eye + dir * d, filter = { ply, self }, mask = MASK_OPAQUE } )
        if ray.Hit then d = d * ray.Fraction - ( self.HullMaxs.x + 8 ) end

        if d >= self:ContactDist() + 8 then
            local ground = self:FindGround( vpos + dir * d, 48, 160 )

            if ground
                and math.abs( ground.z - vpos.z ) < 100
                and bit.band( util.PointContents( ground + Vector( 0, 0, 8 ) ), MASK_WATER ) == 0
                and not self:IsObservedAt( ground ) then

                local ok = true
                if needLOS then
                    local tr = util.TraceLine( { start = eye, endpos = ground + centre, filter = { ply, self }, mask = MASK_OPAQUE } )
                    ok = not tr.Hit
                end

                if ok then
                    self:SetPos( ground )

                    local face = vpos - ground
                    face.z = 0
                    if face:LengthSqr() > 1 then
                        self:SetAngles( Angle( 0, face:Angle().yaw + MODEL_YAW_OFFSET, 0 ) )
                    end

                    return true
                end
            end
        end
    end

    return false
end

-- What the angel does during one blink's dark phase
function ENT:FlashStep( ply, st )
    if st.step == 1 then
        -- it vanishes: out of the player's view, usually behind them
        if not self:PlaceNear( ply, 180, math.Rand( FLASH.VANISH_MIN, FLASH.VANISH_MAX ), false ) then
            self.NextTeleport = 0
            self:AmbushTeleport( { min = FLASH.VANISH_MIN * 0.5, max = FLASH.VANISH_MAX, behindOnly = true, ignoreThrottle = true } )
        end
    else
        -- it reappears closer, in front of the player
        local dist = Lerp( ( st.step - 1 ) / ( st.nBlinks + 1 ), FLASH.STEP_FAR, FLASH.STEP_NEAR )
                   * math.Rand( 1 - FLASH.STEP_JITTER, 1 + FLASH.STEP_JITTER )
        self:PlaceNear( ply, 0, dist, true )
    end

    self:ChangePoseNow()
end

-- The final reveal: very close, in front of the player (or sometimes behind), hands out.
-- It then holds there like a close-range scare until the player has seen it.
function ENT:FlashReveal( ply, now, holdUntil )
    local front = math.random() < 0.65
    local dist  = math.Rand( FLASH.REVEAL_MIN, FLASH.REVEAL_MAX )

    local ok = self:PlaceNear( ply, front and 0 or 180, dist, true )
            or self:PlaceNear( ply, front and 180 or 0, dist, true )

    if not ok then return false end

    self:SetPose( SCARE_POSE )

    self.ScareState   = "seen"      -- handled by the existing scare code: holds, then slinks away
    self.RetreatAt    = holdUntil
    self.NextRelocate = now + math.Rand( RELOCATE_MIN, RELOCATE_MAX )
    self.NextScare    = now + ScareDelay( SCARE_COOLDOWN_MIN, SCARE_COOLDOWN_MAX )

    return true
end

function ENT:EndFlashSeq( ply, st, now, completed )
    if IsValid( ply ) then
        -- aborted before the final blow-out: give the light back
        if not completed and st.wasOn and not string.StartWith( st.ev or "", "final" )
            and now >= ( ply.WAFlashBlockedUntil or 0 ) then
            SetFlashlight( ply, true )
        end

        ply.WABlindUntil = 0
        if ply.WAFlash == st then ply.WAFlash = nil end

        if completed then
            ply.WAFlashNext = ( ply.WAFlashBlockedUntil or now ) + math.Rand( FLASH.COOLDOWN_MIN, FLASH.COOLDOWN_MAX )
        else
            ply.WAFlashNext = now + 8
        end
    end

    if self.FlashSeq == st then self.FlashSeq = nil end
end

-- One step of the blink sequence (events fire in order: off, act, on, off, act, on, ..., final)
function ENT:RunFlashSeq( ply, st, now )
    if now < st.at then return end

    local pingS = math.min( ply:Ping(), 400 ) / 1000   -- network delay, so the client has caught up

    if st.ev == "off" then
        -- light goes out. The angel acts a moment later; the light returns well after that.
        local dark = math.Rand( FLASH.DARK_MIN, FLASH.DARK_MAX )
        st.step  = st.step + 1
        st.actAt = now + FLASH.ACTION_DELAY + pingS
        st.onAt  = now + math.max( dark, ( st.actAt - now ) + FLASH.ON_MARGIN + pingS )

        SetFlashlight( ply, false )
        ply.WABlindUntil = st.onAt
        Blackout( ply, st.onAt - now )

        st.ev, st.at = "act", st.actAt

    elseif st.ev == "act" then
        if not self:IsObserved() then self:FlashStep( ply, st ) end   -- never moves if someone can see it
        st.ev, st.at = "on", st.onAt

    elseif st.ev == "on" then
        SetFlashlight( ply, true )
        ply.WABlindUntil = 0

        if st.step >= st.nBlinks then
            st.ev, st.at = "final_off", now + math.Rand( FLASH.LIGHT_MIN, FLASH.LIGHT_MAX )
        else
            st.ev, st.at = "off", now + math.Rand( FLASH.LIGHT_MIN, FLASH.LIGHT_MAX )
        end

    elseif st.ev == "final_off" then
        -- it breaks free: the flashlight is blown out and stays dead for a while
        SetFlashlight( ply, false )
        ply.WAFlashBlockedUntil = now + cvFlashBlock:GetFloat()

        ply:EmitSound( "ambient/energy/spark1.wav", 75, 100 )
        local edata = EffectData()
        edata:SetOrigin( ply:GetShootPos() )
        edata:SetNormal( Vector( 0, 0, 1 ) )
        edata:SetMagnitude( 1 )
        edata:SetScale( 1 )
        edata:SetRadius( 3 )
        util.Effect( "Sparks", edata )

        st.actAt = now + FLASH.ACTION_DELAY + pingS
        st.endAt = st.actAt + FLASH.ON_MARGIN + pingS

        ply.WABlindUntil = st.endAt
        Blackout( ply, st.endAt - now )

        st.ev, st.at = "final_act", st.actAt

    elseif st.ev == "final_act" then
        if not self:IsObserved() then
            self:FlashReveal( ply, now, ply.WAFlashBlockedUntil + FLASH.HOLD )
        end
        st.ev, st.at = "final_end", st.endAt

    elseif st.ev == "final_end" then
        self:EndFlashSeq( ply, st, now, true )
    end
end

function ENT:DrainFlashlights( now )
    -- a running sequence stops if its player is gone or the feature was switched off
    local seq = self.FlashSeq
    if seq and ( not IsValid( seq.ply ) or not seq.ply:Alive() or not cvFlashDrain:GetBool() or TardisOf( seq.ply ) ) then
        self:EndFlashSeq( seq.ply, seq, now, false )
    end

    if not cvFlashDrain:GetBool() then return end

    local range = cvFlashDist:GetFloat()
    local myPos = self:GetPos()

    for _, ply in ipairs( player.GetAll() ) do
        if IsValid( ply ) and ply:Alive() and not TardisOf( ply ) then   -- no blinks inside a TARDIS
            local st = ply.WAFlash
            local d  = myPos:Distance( ply:GetPos() )
            local on = ply:FlashlightIsOn()

            -- how long the flashlight has been off (for the dark ambush)
            if on then ply.WAOffSince = nil elseif not ply.WAOffSince then ply.WAOffSince = now end

            -- the angel that owned this has been removed: let go
            if st and not IsValid( st.owner ) then
                ply.WAFlash      = nil
                ply.WABlindUntil = 0
                st = nil
            end

            if not st then
                if now >= ( ply.WAFlashNext or 0 ) and d <= range and self:FlashEligible() then
                    local inDark = cvDarkness:GetBool() and self:IsAmbientDark( ply, myPos )

                    if on and self:FlashCanHide( ply ) then
                        -- timer before the first blink: longer in real darkness (the build-up)
                        local delay = inDark and math.Rand( FLASH.FIRST_DARK_MIN, FLASH.FIRST_DARK_MAX )
                                              or math.Rand( FLASH.FIRST_LIT_MIN, FLASH.FIRST_LIT_MAX )

                        ply.WAFlash = { owner = self, ply = ply, ev = "wait", at = now + delay, step = 0 }

                    elseif not on and inDark and ply.WAOffSince and now - ply.WAOffSince >= FLASH.OFF_WAIT
                        and now >= ( ply.WAFlashBlockedUntil or 0 ) and not self:IsObserved() then
                        -- light off in the dark: it comes to the front, so the next click shows it
                        ply.WABlindUntil = now + 1.2

                        if self:FlashReveal( ply, now, now + FLASH.HOLD ) then
                            ply.WAFlashNext = now + math.Rand( FLASH.COOLDOWN_MIN, FLASH.COOLDOWN_MAX )
                        else
                            ply.WABlindUntil = 0
                            ply.WAFlashNext  = now + 5
                        end
                    end
                end

            elseif st.owner == self then
                if st.ev == "wait" then
                    if not ( on and d <= range * 1.2 and self:FlashEligible() ) then
                        -- conditions broke while it was waiting: forget it for now
                        ply.WAFlash     = nil
                        ply.WAFlashNext = now + 5
                    elseif not self:FlashCanHide( ply ) then
                        -- the player's light is on it (or it is lit): hold the timer until it is hidden again
                        st.at = math.max( st.at, now + 0.5 )
                    elseif now >= st.at then
                        -- the timer ran out: the blinking starts
                        st.ev, st.at = "off", now
                        st.locked    = true      -- the player can't switch the light while it blinks
                        st.wasOn     = true
                        st.nBlinks   = math.random( FLASH.BLINKS_MIN, FLASH.BLINKS_MAX )
                        self.FlashSeq = st
                    end

                elseif not string.StartWith( st.ev, "final" ) and d > math.max( range * 1.8, FLASH.VANISH_MAX + 400 ) then
                    self:EndFlashSeq( ply, st, now, false )   -- the player got away

                else
                    self:RunFlashSeq( ply, st, now )
                end
            end
        end
    end
end

-- Darkness: is this angel standing in the dark, as far as this player can tell?
-- Based on the player's own latest report (fresh within 0.8 s), and only for positions
-- close to where it was measured. Anything else is judged by the normal view rules.
function ENT:IsDarkFor( ply, pos )
    local reps = self.DarkRep
    local r    = reps and reps[ ply ]

    if not r or not r.dark then return false end
    if CurTime() - r.t > 0.8 then return false end

    return pos:DistToSqr( r.pos ) <= DARK_STEP_RADIUS * DARK_STEP_RADIUS
end

-- Is the spot dark by itself (the player's own flashlight not counted)? Used by the flashlight blinks,
-- so an angel standing in a dark area can still be blinked while the player shines the light on it.
function ENT:IsAmbientDark( ply, pos )
    local r = self.DarkRep and self.DarkRep[ ply ]

    if not r or not r.amb then return false end
    if CurTime() - r.t > 0.8 then return false end

    return pos:DistToSqr( r.pos ) <= DARK_STEP_RADIUS * DARK_STEP_RADIUS
end

function ENT:Feed()
    if not cvFeeding:GetBool() then return end
    self.Hunger = math.min( self.Hunger + 1, cvFeedMax:GetInt() )
end

-- multiplier on its patience (below 1 = builds tension faster)
function ENT:HungerPatienceMul()
    if not cvFeeding:GetBool() or self.Hunger <= 0 then return 1 end
    return math.max( 0.25, ( 1 - cvFeedStep:GetFloat() ) ^ self.Hunger )
end

-- multiplier on how far its light-draining reaches
function ENT:HungerLightMul()
    if not cvFeeding:GetBool() or self.Hunger <= 0 then return 1 end
    return 1 + FEED_LIGHT_STEP * self.Hunger
end

-- --------------------------------------------------------
-- Dormant statues (needs weepingangel_dormant 1 when the angel is spawned)
-- --------------------------------------------------------
function ENT:ShouldWake( now )
    local wakeTime = cvDormantTime:GetFloat()
    if wakeTime > 0 and now - self.SpawnTime >= wakeTime then return true end

    local pos      = self:GetPos()
    local wakeDist = cvDormantDist:GetFloat()

    for _, ply in ipairs( player.GetAll() ) do
        if IsValidTarget( ply ) and ply:GetPos():DistToSqr( pos ) <= wakeDist * wakeDist then
            return true
        end
    end

    return false
end

function ENT:Wake( now )
    self.Dormant          = false
    self.Tension          = 0.05
    self.LastSeenByPlayer = now
    self.NextRelocate     = now + math.Rand( RELOCATE_MIN, RELOCATE_MAX )
    self.NextScare        = now + ScareDelay( SCARE_FIRST_MIN, SCARE_FIRST_MAX )
end

-- Sends the numbers the client debug overlay draws (see cl_init.lua).
-- Does nothing while weepingangel_debug is 0, and switches the overlay off again.
function ENT:UpdateDebugNW( now, observed, byPlayer )
    local on = cvDebug:GetBool()

    if self.DebugNWOn ~= on then
        self.DebugNWOn = on
        self:SetNW2Bool( "WADebug", on )
    end

    if not on then return end

    self:SetNW2String( "WAMode", self.Dormant and "dormant" or self.Mode )
    self:SetNW2Int( "WAHunger", self.Hunger )
    self:SetNW2String( "WAScare", tostring( self.ScareState ) )
    self:SetNW2Float( "WATension", self.Tension )
    self:SetNW2Float( "WABlind", math.max( 0, STRIKE_BLIND_TIME - ( now - self.LastSeenByPlayer ) ) )
    self:SetNW2Float( "WANextScare", math.max( 0, self.NextScare - now ) )
    self:SetNW2Float( "WAPoint", self.PointTime )
    self:SetNW2Int( "WAFails", self.ScareFails )
    self:SetNW2Bool( "WAObserved", observed )
    self:SetNW2Bool( "WAByAngel", observed and not byPlayer )
    self:SetNW2Entity( "WAVictim", IsValid( self.Victim ) and self.Victim or NULL )
    self:SetNW2String( "WAFlash", self:FlashStatus( now ) )
    self:SetNW2String( "WASiege", self.SiegeStatus or "-" )

    local parts, players = {}, player.GetAll()
    for _, ply in ipairs( players ) do
        if IsValidTarget( ply ) then
            parts[ #parts + 1 ] = string.format( "%s%s %d", ply == self.Victim and "> " or "", string.sub( ply:Nick(), 1, 12 ), self:ScoreVictim( ply, players ) )
        end
    end
    if IsValid( self.LatestWatcher ) then
        parts[ #parts + 1 ] = string.format( "[looked last: %s %.1fs ago]", string.sub( self.LatestWatcher:Nick(), 1, 12 ), now - self.LatestWatchT )
    end
    self:SetNW2String( "WAScores", table.concat( parts, "  |  " ) )
end

function ENT:Think()
    local now = CurTime()
    local dt  = math.Clamp( now - self.LastThink, 0, MAX_STEP_DT )
    self.LastThink = now

    if self.IsSonicFrozen then
        self:NextThink( now + 0.2 )
        return true
    end

    self:TardisRescue( now )
    if not self.Dormant then self:UpdateWatchers( now ) end
    self:UpdateVictim()

    if not IsValid( self.Victim ) then
        -- nobody to hunt (e.g. the player went into a TARDIS): drop a running flashlight blink
        local seq = self.FlashSeq
        if seq then self:EndFlashSeq( seq.ply, seq, now, false ) end

        local busy = self:TardisSiege( now, dt )
        self:UpdateDebugNW( now, self.WasObserved or false )

        if busy then
            self:NextThink( now + THINK_DELAY )
            return true
        end

        self:NextThink( now + 0.5 )
        return true
    end

    -- Dormant statue: stays completely still in the covered-face pose until it wakes
    if self.Dormant then
        if self:ShouldWake( now ) then
            self:Wake( now )
        else
            self:UpdateDebugNW( now, false )
            self:NextThink( now + 0.2 )
            return true
        end
    end

    self:RecordPlayerPath( now )
    self:CheckNearbyLights( now )
    self:DrainFlashlights( now )
    self:UpdateOpenness( now )

    local observed, byPlayer = self:IsObserved()

    if observed then
        if not self.WasObserved then self:OnRevealed( now ) end
        self.LastObserved = now
        if byPlayer then self.LastSeenByPlayer = now end
        self.FrozenUntil  = now + SEEN_GRACE + self:LagGrace()
        self.LostSight    = true
    else
        self.Tension = math.min( 1, self.Tension + dt * self:CrowdMul() / ( cvPatience:GetFloat() * self.PatienceMul * self:HungerPatienceMul() ) )

        if now >= self.FrozenUntil and not self.FlashSeq then
            -- first moment since it was seen: skip every move / teleport cooldown
            if self.LostSight then
                self.LostSight = false

                -- freed: the player who looked away last becomes its target
                if cvSmart:GetBool() then
                    self:UpdateWatchers( now, true )
                    self:UpdateVictim( true )
                end

                if cvInstant:GetBool() then
                    self.NextRelocate    = 0
                    self.NextTeleport    = 0
                    self.NextTeleportTry = 0
                    self.InstantMove     = true
                end
            end

            self:Stalk( dt )
            self.InstantMove = false   -- one-shot: only the first tick after losing sight
        end
    end

    self.WasObserved = observed

    self:UpdateDebugNW( now, observed, byPlayer )

    if cvDebug:GetBool() and now >= self.NextDebug then
        self.NextDebug = now + 1
        print( string.format( "[WeepingAngel %d] mode=%s scare=%s tension=%.2f dist=%d hold=%d openness=%d observed=%s",
            self:EntIndex(), self.Mode, tostring( self.ScareState ), self.Tension,
            self:GetPos():Distance( self.Victim:GetPos() ), self:GetHoldDistance(), self.Openness,
            tostring( observed ) ) )
    end

    self:NextThink( now + THINK_DELAY )
    return true
end

-- --------------------------------------------------------
-- Cross-Mod Interactions & Protection Hooks
-- --------------------------------------------------------

local function IsAngel( ent )
    return IsValid( ent ) and ent:GetClass() == "weepingangel"
end

hook.Add( "KeyPress", "WeepingAngel_SonicInteract", function( ply, key )
    if not IsValid( ply ) or not ply:Alive() then return end
    local weapon = ply:GetActiveWeapon()
    if not IsValid( weapon ) or weapon:GetClass() ~= "swep_sonicsd" then return end

    if key == IN_ATTACK or key == IN_ATTACK2 then
        local tr = util.TraceLine( {
            start  = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * 125,
            filter = ply,
            mask   = MASK_SHOT_HULL
        } )

        local ent = tr.Entity
        if IsAngel( ent ) then
            if SERVER then
                if key == IN_ATTACK then
                    ent.IsSonicFrozen = true
                    ent:EmitSound( "buttons/button11.wav", 75, 90 )
                    ply:ChatPrint( "[Sonic Screwdriver] The Weeping Angel is temporarily locked in time!" )
                elseif key == IN_ATTACK2 then
                    ent.IsSonicFrozen = false
                    ent.Victim = ply
                    ent.Tension = 1.0
                    ent:EmitSound( "ambient/energy/zap2.wav", 80, 110 )
                    ply:ChatPrint( "[Sonic Screwdriver] You unlocked the Angel... and enraged it!" )
                end
            end
        end
    end
end )

-- a blown-out flashlight cannot be turned back on until the block runs out
hook.Add( "PlayerSwitchFlashlight", "WeepingAngel_FlashBlock", function( ply, enabled )
    if ply.WAFlashInternal then return end   -- our own blinking

    -- while an angel is blinking the light, the player cannot switch it themselves
    local st = ply.WAFlash
    if st and st.locked and IsValid( st.owner ) then return false end

    if enabled and ( ply.WAFlashBlockedUntil or 0 ) > CurTime() then return false end
end )

-- a death clears the "recently touched" mark used by the double-touch kill
hook.Add( "PlayerDeath", "WeepingAngel_ClearTouch", function( ply )
    if not IsValid( ply ) then return end

    ply.WALastTouch = nil
    ply.WABlindUntil = 0

    local st = ply.WAFlash
    if st and IsValid( st.owner ) and st.owner.FlashSeq == st then st.owner.FlashSeq = nil end
    ply.WAFlash = nil
end )

hook.Add( "PlayerDisconnected", "WeepingAngel_ClearFlash", function( ply )
    local st = ply.WAFlash
    if st and IsValid( st.owner ) and st.owner.FlashSeq == st then st.owner.FlashSeq = nil end
    ply.WAFlash = nil
end )

hook.Add( "PhysgunPickup", "WeepingAngel_Protect", function( ply, ent )
    if IsAngel( ent ) then return false end
end )

hook.Add( "CanPlayerUnfreeze", "WeepingAngel_Protect", function( ply, ent, phys )
    if IsAngel( ent ) then return false end
end )

hook.Add( "GravGunPunt", "WeepingAngel_Protect", function( ply, ent )
    if IsAngel( ent ) then return false end
end )

hook.Add( "GravGunPickupAllowed", "WeepingAngel_Protect", function( ply, ent )
    if IsAngel( ent ) then return false end
end )

hook.Add( "CanTool", "WeepingAngel_Protect", function( ply, tr, tool )
    if IsAngel( tr.Entity ) and tool ~= "remover" then return false end
end )

hook.Add( "CanProperty", "WeepingAngel_Protect", function( ply, property, ent )
    if IsAngel( ent ) and property ~= "remove" then return false end
end )

-- Lag compensation: every tick, measure how fast each player is turning their view. Together with their
-- ping (plus the client's own interpolation delay) that says how many degrees the real view may already be
-- ahead of what the server knows, and the "can see it" cone is widened by that much.
hook.Add( "Think", "WeepingAngel_ViewSpeed", function()
    local now = CurTime()

    for _, ply in ipairs( player.GetAll() ) do
        local ang  = ply:EyeAngles()
        local prev = ply.WAPrevAng
        local pt   = ply.WAPrevAngT or now

        ply.WAPrevAng  = ang
        ply.WAPrevAngT = now

        local dt = now - pt
        if prev and dt > 0.001 then
            local dy = math.abs( math.NormalizeAngle( ang.yaw - prev.yaw ) )
            local dp = math.abs( math.NormalizeAngle( ang.pitch - prev.pitch ) )
            local speed = math.sqrt( dy * dy + dp * dp ) / dt                 -- degrees per second

            -- peak hold: keep a fast turn "remembered" for about a quarter second
            local held = ( ply.WAAngSpeed or 0 ) - 400 * dt
            ply.WAAngSpeed = math.max( speed, held, 0 )
        end

        local window = math.min( ply:Ping(), 400 ) / 1000 + 0.15              -- ping + interpolation + think delay
        ply.WAViewExtra = math.Clamp( ( ply.WAAngSpeed or 0 ) * window, 0, 45 )
    end
end )

-- extra freeze time after being seen, from the worst ping among players
function ENT:LagGrace()
    if not cvLag:GetBool() then return 0 end

    local worst = 0
    for _, ply in ipairs( player.GetAll() ) do
        worst = math.max( worst, ply:Ping() )
    end

    return math.min( worst, 400 ) / 1000 * 0.5
end

-- Diagnostics for the TARDIS mod support: stand inside a TARDIS and run  weepingangel_tardis_info
-- (server console, or as an admin in your own console). Prints what this addon can read from the mod.
concommand.Add( "weepingangel_tardis_info", function( ply )
    if IsValid( ply ) and not ply:IsAdmin() then return end

    local function out( msg )
        if IsValid( ply ) then ply:PrintMessage( HUD_PRINTCONSOLE, msg .. "\n" ) else print( msg ) end
    end

    if not IsValid( ply ) then out( "run this as a player (stand inside the TARDIS)" ) return end

    out( "---- Weeping Angel / TARDIS info ----" )
    out( "shelter mode: " .. cvTardis:GetInt() .. "   siege range: " .. cvTardisSiege:GetFloat() .. "   grace: " .. cvTardisGrace:GetFloat() )
    out( "GetTardisData available: " .. tostring( isfunction( ply.GetTardisData ) ) )

    local ext = TardisOf( ply )
    if not ext then out( "you are NOT inside a TARDIS (as far as the mod says)" ) return end

    out( "exterior: " .. tostring( ext ) .. " at " .. tostring( ext:GetPos() ) )
    out( "interior: " .. tostring( InteriorOf( ply ) ) )
    out( "door open: " .. tostring( TardisDoorOpen( ext ) ) )

    local dwOk, dw = false, nil
    if isfunction( ext.GetDoorway ) then dwOk, dw = pcall( ext.GetDoorway, ext ) end
    out( "doorway: " .. ( ( dwOk and istable( dw ) ) and ( "pos " .. tostring( dw.pos ) .. "  ang " .. tostring( dw.ang ) ) or "not readable" ) )

    local mk = GetModKnock()
    out( "TARDIS mod knock sounds found: " .. #mk .. ( #mk > 0 and ( "  e.g. " .. table.concat( mk, ", ", 1, math.min( #mk, 4 ) ) ) or "  (using the built-in soft knock)" ) )

    local mb = GetModBang()
    out( "TARDIS mod bang/pound sounds found: " .. #mb .. ( #mb > 0 and ( "  e.g. " .. table.concat( mb, ", ", 1, math.min( #mb, 4 ) ) ) or "  (using the built-in pounding)" ) )

    local locked, lvia = TardisLocked( ext )
    out( "locked: " .. tostring( locked ) .. ( lvia and ( "  (read via " .. lvia .. ")" ) or "  (no accessor worked, treated as unlocked)" ) )

    local shields, via = TardisShieldsOn( ext )
    out( "shields: " .. tostring( shields ) .. ( via and ( "  (read via " .. via .. ")" ) or "  (no accessor worked)" ) )
    out( "sheltered by this addon: " .. tostring( TardisShelter( ply ) ) )

    -- any shield / knock related functions the exterior has, in case the guesses above are wrong
    local names = {}
    local stored = scripted_ents.Get( "gmod_tardis" )
    if istable( stored ) then
        for k, v in pairs( stored ) do
            if isfunction( v ) and type( k ) == "string" then
                local l = string.lower( k )
                if string.find( l, "shield", 1, true ) or string.find( l, "knock", 1, true ) or string.find( l, "lock", 1, true ) then names[ #names + 1 ] = k end
            end
        end
    end
    table.sort( names )
    out( "shield/knock functions on gmod_tardis: " .. ( #names > 0 and table.concat( names, ", " ) or "(none found)" ) )

    for _, a in ipairs( ents.FindByClass( "weepingangel" ) ) do
        out( string.format( "angel #%d: dist %d, siege: %s", a:EntIndex(), a:GetPos():Distance( ext:GetPos() ), tostring( a.SiegeStatus ) ) )
    end
end )