-- Put this file at: lua/autorun/client/weepingangel_client.lua
-- Client side extras for the Weeping Angel addon:
--   * the past-era filter shown after an angel casts you back in time
--   * the Q-menu settings panel (Utilities > Weeping Angel > Settings)

-- --------------------------------------------------------
-- PAST-ERA FILTER
-- Sepia colour grade that fades in quickly and fades out over the last 2 seconds.
-- Triggered by the server (weepingangel_past_filter 1) when you are cast back in time.
-- --------------------------------------------------------
local pastEnd, pastDur = 0, 0

net.Receive( "WeepingAngel_PastFilter", function()
    pastDur = math.max( 0.5, net.ReadFloat() )
    pastEnd = CurTime() + pastDur
end )

hook.Add( "RenderScreenspaceEffects", "WeepingAngel_PastFilter", function()
    local left = pastEnd - CurTime()
    if left <= 0 then return end

    local s = math.min( math.Clamp( ( pastDur - left ) / 0.4, 0, 1 ), math.Clamp( left / 2, 0, 1 ) )

    DrawColorModify( {
        [ "$pp_colour_addr" ]       = 0.09 * s,
        [ "$pp_colour_addg" ]       = 0.04 * s,
        [ "$pp_colour_addb" ]       = 0,
        [ "$pp_colour_brightness" ] = -0.03 * s,
        [ "$pp_colour_contrast" ]   = 1 + 0.10 * s,
        [ "$pp_colour_colour" ]     = 1 - 0.80 * s,
        [ "$pp_colour_mulr" ]       = 0,
        [ "$pp_colour_mulg" ]       = 0,
        [ "$pp_colour_mulb" ]       = 0,
    } )
end )

-- --------------------------------------------------------
-- DARKNESS (EXPERIMENTAL, weepingangel_darkness 1 on the server)
-- Five times a second we measure how well lit each nearby angel is and tell the server.
-- An angel below weepingangel_dark_level counts as "in the dark": you can't observe it,
-- so it can move even while you face it. Your flashlight lights it if you point it there.
-- Use weepingangel_debug 1 to see the measured light value above each angel.
-- --------------------------------------------------------
timer.Create( "WeepingAngel_LightReport", 0.2, 0, function()
    local lp = LocalPlayer()
    if not IsValid( lp ) or not lp:Alive() then return end

    local cvOn = GetConVar( "weepingangel_darkness" )
    if not cvOn or not cvOn:GetBool() then return end

    local cvLevel = GetConVar( "weepingangel_dark_level" )
    local cvFlash = GetConVar( "weepingangel_dark_flashlight" )
    local level   = cvLevel and cvLevel:GetFloat() or 0.06
    local flashOn = cvFlash and cvFlash:GetBool() and lp:FlashlightIsOn()

    local eye    = lp:EyePos()
    local fwd    = lp:EyeAngles():Forward()
    local report = {}

    for _, ent in ipairs( ents.FindByClass( "weepingangel" ) ) do
        local mid = ent:LocalToWorld( ent:OBBCenter() )
        local d   = eye:Distance( mid )

        if d < 3000 then
            local c      = render.GetLightColor( mid )
            local bright = ( c.x + c.y + c.z ) / 3
            local lit    = bright >= level
            local amb    = not lit      -- dark by itself, before the flashlight is considered

            -- flashlight: it must point at the angel with nothing in between.
            -- Up close the angel's centre is far below your crosshair, so the cone is much wider there.
            local cone = ( d < 250 ) and 0.45 or 0.85
            if not lit and flashOn and d < 900 and d > 1 and ( ( mid - eye ) / d ):Dot( fwd ) > cone then
                local tr = util.TraceLine( { start = eye, endpos = mid, filter = lp, mask = MASK_OPAQUE } )
                if not tr.Hit or tr.Entity == ent then lit = true end
            end

            ent.WALight = bright   -- shown by the debug overlay
            ent.WADark  = not lit

            report[ #report + 1 ] = { d, ent:EntIndex(), not lit, amb }
        end
    end

    if #report == 0 then return end

    table.sort( report, function( a, b ) return a[ 1 ] < b[ 1 ] end )

    net.Start( "WeepingAngel_Light" )
    net.WriteUInt( math.min( #report, 16 ), 5 )
    for i = 1, math.min( #report, 16 ) do
        net.WriteUInt( report[ i ][ 2 ], 16 )
        net.WriteBool( report[ i ][ 3 ] )
        net.WriteBool( report[ i ][ 4 ] )
    end
    net.SendToServer()
end )

-- --------------------------------------------------------
-- SETTINGS PANEL
-- Everyone can open it, but only superadmins can change anything.
-- Entries: { convar, label, kind, min, max, decimals, default }
-- --------------------------------------------------------
local SECTIONS =
{
    { "Hunting", {
        { "weepingangel_speed",       "Angel speed",                          "num",  50, 5000, 0, 400 },
        { "weepingangel_patience",    "Patience (seconds until it strikes)",  "num",  10, 3600, 0, 25 },
        { "weepingangel_allow_touch", "Allow touching (strikes)",             "bool" },
        { "weepingangel_touch_mode",  "Touch kills (instead of time travel)", "bool" },
        { "weepingangel_instant_move", "Instant move when you look away (no cooldowns)", "bool" },
        { "weepingangel_smart_target", "Multiplayer: smart target switching", "bool" },
        { "weepingangel_lag_comp",     "Lag compensation (fast turns / ping)", "bool" },
        { "weepingangel_fit_space",    "Fit distances to the room, keep off walls", "bool" },
        { "weepingangel_max_range",   "Max teleport range (0 = unlimited)",   "num",  0, 50000, 0, 4000 },
    } },
    { "Scares", {
        { "weepingangel_scares",      "Close-range scares",                   "bool" },
        { "weepingangel_scare_scale", "Scare delay multiplier",               "num",  0.05, 10, 2, 1 },
    } },
    { "World", {
        { "weepingangel_angel_lock",  "Angels freeze each other",             "bool" },
        { "weepingangel_bots_see",    "Bots count as observers and targets",  "bool" },
        { "weepingangel_lights",      "Blow out nearby lights",               "bool" },
        { "weepingangel_breadcrumbs", "Follow footsteps around corners",      "bool" },
        { "weepingangel_move_sounds", "Stone grinding sound when moving",     "bool" },
        { "weepingangel_aspect",      "Widest player screen aspect ratio",    "num",  1, 4, 4, 1.7778 },
    } },
    { "Dormant statues (applies to newly spawned angels)", {
        { "weepingangel_dormant",           "Spawn as dormant statues",       "bool" },
        { "weepingangel_dormant_wake_dist", "Wake distance",                  "num",  50, 5000, 0, 500 },
        { "weepingangel_dormant_wake_time", "Wake after N seconds (0 = never)", "num", 0, 3600, 0, 0 },
    } },
    { "Feeding", {
        { "weepingangel_feeding",      "Touches make it hungrier",            "bool" },
        { "weepingangel_feeding_step", "Patience lost per touch",             "num",  0.01, 0.5, 2, 0.15 },
        { "weepingangel_feeding_max",  "Max remembered touches",              "num",  1, 20, 0, 5 },
    } },
    { "Double touch", {
        { "weepingangel_double_touch",        "Second touch kills",           "bool" },
        { "weepingangel_double_touch_window", "Window (seconds)",             "num",  5, 3600, 0, 90 },
    } },
    { "Past-era filter", {
        { "weepingangel_past_filter",      "Sepia filter after being cast back", "bool" },
        { "weepingangel_past_filter_time", "Duration (seconds)",              "num",  1, 60, 0, 8 },
    } },
    { "Flashlight blink", {
        { "weepingangel_flashlight_drain",    "Angels blink and blow out your flashlight", "bool" },
        { "weepingangel_flashlight_dist",     "Blink distance",                  "num",  100, 2000, 0, 450 },
        { "weepingangel_flashlight_block",    "Flashlight stays dead (seconds)", "num",  1, 300, 0, 5 },
        { "weepingangel_flashlight_blackout", "Black out the screen with each blink", "bool" },
    } },
    { "TARDIS mod (0 off, 1 safe while shields are on, 2 always safe inside)", {
        { "weepingangel_tardis_shelter", "Shelter mode",                       "num",  0, 2, 0, 1 },
        { "weepingangel_tardis_grace",   "No touching after leaving (seconds)", "num",  0, 120, 0, 8 },
        { "weepingangel_tardis_knock",   "Knock at the door (pound if locked)", "bool" },
        { "weepingangel_tardis_door_look", "Open door only watches while looked through", "bool" },
        { "weepingangel_tardis_knock_volume", "Knock / pound loudness",           "num",  0.05, 2, 2, 0.7 },
        { "weepingangel_tardis_siege",   "Wait at the TARDIS door within (units, 0 = off)", "num", 0, 20000, 0, 3000 },
    } },
    { "Darkness (experimental, needs testing per map)", {
        { "weepingangel_darkness",       "Can't see angels standing in the dark", "bool" },
        { "weepingangel_dark_level",     "Darkness threshold (see debug overlay)", "num", 0, 1, 3, 0.06 },
        { "weepingangel_dark_flashlight", "Flashlight lights angels",              "bool" },
    } },
    { "Debug", {
        { "weepingangel_debug", "Debug overlay and console output",           "bool" },
    } },
}

local values   = {}  -- last values the server sent (strings)
local controls = {}  -- convar name -> control
local defs     = {}  -- convar name -> definition
local syncing  = false

for _, section in ipairs( SECTIONS ) do
    for _, d in ipairs( section[ 2 ] ) do defs[ d[ 1 ] ] = d end
end

local function ServerNumber( name )
    local v = tonumber( values[ name ] )
    if v ~= nil then return v end

    local d = defs[ name ]
    return d and d[ 7 ] or 0
end

local function SendValue( name, val )
    net.Start( "WeepingAngel_SetConVar" )
    net.WriteString( name )
    net.WriteString( tostring( val ) )
    net.SendToServer()
end

-- Apply a value from the server to the control without sending it back
local function ApplyToControl( name )
    local c = controls[ name ]
    if not IsValid( c ) then return end

    syncing = true
    if c.WAKind == "bool" then
        c:SetChecked( ServerNumber( name ) ~= 0 )
    else
        c:SetValue( ServerNumber( name ) )
    end
    syncing = false
end

net.Receive( "WeepingAngel_ConVarSync", function()
    local n = net.ReadUInt( 8 )

    for _ = 1, n do
        local name = net.ReadString()
        values[ name ] = net.ReadString()
        ApplyToControl( name )
    end
end )

local function BuildPanel( panel )
    panel:ClearControls()
    controls = {}

    local isAdmin = IsValid( LocalPlayer() ) and LocalPlayer():IsSuperAdmin()

    panel:Help( "Changes apply to the server immediately." )
    if not isAdmin then
        panel:Help( "Only superadmins can change these settings. You are seeing the current values." )
    end

    for _, section in ipairs( SECTIONS ) do
        local header = panel:Help( section[ 1 ] )
        header:SetFont( "DermaDefaultBold" )

        for _, d in ipairs( section[ 2 ] ) do
            local name, label, kind = d[ 1 ], d[ 2 ], d[ 3 ]
            local c

            if kind == "bool" then
                c = vgui.Create( "DCheckBoxLabel" )
                c:SetText( label )
                c:SetDark( true )
                c.WAKind = "bool"
                c:SetChecked( ServerNumber( name ) ~= 0 )

                c.OnChange = function( _, val )
                    if syncing then return end
                    SendValue( name, val and 1 or 0 )
                end
            else
                local dec = d[ 6 ]

                c = vgui.Create( "DNumSlider" )
                c:SetText( label )
                c:SetDark( true )
                c:SetMinMax( d[ 4 ], d[ 5 ] )
                c:SetDecimals( dec )
                c.WAKind = "num"
                c:SetValue( ServerNumber( name ) )

                c.OnValueChanged = function( _, val )
                    if syncing then return end

                    -- ignore echoes of what the server already has (slider rounding)
                    if math.abs( ServerNumber( name ) - val ) <= 0.5 * 10 ^ -dec + 1e-9 then return end

                    -- wait until the slider stops moving before sending
                    timer.Create( "WeepingAngel_Send_" .. name, 0.3, 1, function()
                        SendValue( name, math.Round( val, dec ) )
                    end )
                end
            end

            c:SetEnabled( isAdmin )
            controls[ name ] = c
            panel:AddItem( c )
        end
    end

    -- ask the server for the real values
    net.Start( "WeepingAngel_RequestConVars" )
    net.SendToServer()
end

hook.Add( "PopulateToolMenu", "WeepingAngel_Settings", function()
    spawnmenu.AddToolMenuOption( "Utilities", "Weeping Angel", "WeepingAngelSettings", "Settings", "", "", BuildPanel )
end )

-- --------------------------------------------------------
-- FLASHLIGHT BLACKOUT (optional, weepingangel_flashlight_blackout 1 on the server)
-- The whole screen goes black together with each flashlight blink, so the angel's moves
-- stay hidden even on maps where the darkness threshold is hard to tune.
-- --------------------------------------------------------
local blackStart, blackEnd = 0, 0

net.Receive( "WeepingAngel_Blackout", function()
    local dur = math.Clamp( net.ReadFloat(), 0.1, 5 )
    blackStart = CurTime()
    blackEnd   = blackStart + dur
end )

hook.Add( "HUDPaint", "WeepingAngel_Blackout", function()
    local now = CurTime()
    if now >= blackEnd then return end

    local a = math.min( math.Clamp( ( now - blackStart ) / 0.06, 0, 1 ), math.Clamp( ( blackEnd - now ) / 0.2, 0, 1 ) )

    surface.SetDrawColor( 0, 0, 0, 255 * a )
    surface.DrawRect( 0, 0, ScrW(), ScrH() )
end )