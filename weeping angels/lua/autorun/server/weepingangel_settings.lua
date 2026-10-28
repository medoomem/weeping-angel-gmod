-- Put this file at: lua/autorun/server/weepingangel_settings.lua
-- Lets superadmins change the Weeping Angel convars from the Q-menu panel
-- (Utilities > Weeping Angel > Settings), including on a dedicated server.

util.AddNetworkString( "WeepingAngel_RequestConVars" )
util.AddNetworkString( "WeepingAngel_ConVarSync" )
util.AddNetworkString( "WeepingAngel_SetConVar" )

-- Only these convars can be read or changed through the panel
local NAMES =
{
    "weepingangel_speed", "weepingangel_patience", "weepingangel_allow_touch", "weepingangel_touch_mode", "weepingangel_instant_move", "weepingangel_smart_target", "weepingangel_lag_comp", "weepingangel_fit_space",
    "weepingangel_scares", "weepingangel_scare_scale",
    "weepingangel_angel_lock", "weepingangel_bots_see", "weepingangel_lights", "weepingangel_breadcrumbs",
    "weepingangel_move_sounds", "weepingangel_aspect",
    "weepingangel_dormant", "weepingangel_dormant_wake_dist", "weepingangel_dormant_wake_time",
    "weepingangel_feeding", "weepingangel_feeding_step", "weepingangel_feeding_max",
    "weepingangel_double_touch", "weepingangel_double_touch_window",
    "weepingangel_past_filter", "weepingangel_past_filter_time",
    "weepingangel_darkness", "weepingangel_dark_level", "weepingangel_dark_flashlight",
    "weepingangel_flashlight_drain", "weepingangel_flashlight_dist", "weepingangel_flashlight_block",
    "weepingangel_flashlight_blackout",
    "weepingangel_max_range", "weepingangel_tardis_shelter", "weepingangel_tardis_siege", "weepingangel_tardis_knock", "weepingangel_tardis_door_look", "weepingangel_tardis_knock_volume", "weepingangel_tardis_grace",
    "weepingangel_debug",
}

local ALLOWED = {}
for _, n in ipairs( NAMES ) do ALLOWED[ n ] = true end

local function SendValues( ply )
    local list = {}

    for _, n in ipairs( NAMES ) do
        local cv = GetConVar( n )
        if cv then list[ #list + 1 ] = { n, cv:GetString() } end
    end

    net.Start( "WeepingAngel_ConVarSync" )
    net.WriteUInt( #list, 8 )
    for _, p in ipairs( list ) do
        net.WriteString( p[ 1 ] )
        net.WriteString( p[ 2 ] )
    end
    net.Send( ply )
end

-- anyone opening the panel can see the current values
net.Receive( "WeepingAngel_RequestConVars", function( _, ply )
    if IsValid( ply ) then SendValues( ply ) end
end )

-- only superadmins can change them
net.Receive( "WeepingAngel_SetConVar", function( _, ply )
    if not IsValid( ply ) or not ply:IsSuperAdmin() then return end

    local name = net.ReadString()
    local num  = tonumber( net.ReadString() )

    if not ALLOWED[ name ] or not num or not GetConVar( name ) then return end

    -- Set it directly so the new value is in place immediately (the convar's own
    -- min/max still apply). RunConsoleCommand only queues the change, so a reply
    -- sent right after it still carried the OLD value and flipped the checkbox back.
    GetConVar( name ):SetString( tostring( num ) )

    -- send the (possibly clamped) values back so the panel shows what is really set
    SendValues( ply )
end )