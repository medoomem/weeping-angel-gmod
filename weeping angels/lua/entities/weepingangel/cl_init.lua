include( "shared.lua" )

function ENT:Initialize()

end

function ENT:Draw()
    self:DrawModel()
end

-- --------------------------------------------------------
-- DEBUG OVERLAY
-- Shown to admins only, and only while the server has weepingangel_debug 1.
-- The server sends the numbers (see ENT:UpdateDebugNW in init.lua).
-- Drawn through walls so you can see where an angel is that you can't see.
-- --------------------------------------------------------
surface.CreateFont( "WeepingAngelDebug", {
    font   = "Tahoma",
    size   = 32,
    weight = 800,
} )

local COL_HAUNT  = Color( 120, 200, 255 )
local COL_STRIKE = Color( 255, 80, 80 )
local COL_SEEN   = Color( 255, 210, 60 )
local COL_DORMANT = Color( 170, 170, 170 )
local COL_TEXT   = Color( 255, 255, 255 )
local LINE_H     = 36

hook.Add( "PostDrawTranslucentRenderables", "WeepingAngel_DebugOverlay", function( depth, skybox )
    if skybox then return end

    local lp = LocalPlayer()
    if not IsValid( lp ) or not lp:IsAdmin() then return end

    for _, ent in ipairs( ents.FindByClass( "weepingangel" ) ) do
        if ent:GetNW2Bool( "WADebug", false ) then
            local mode    = ent:GetNW2String( "WAMode", "?" )
            local observed = ent:GetNW2Bool( "WAObserved", false )
            local victim  = ent:GetNW2Entity( "WAVictim" )
            local col     = ( mode == "strike" ) and COL_STRIKE or ( ( mode == "dormant" ) and COL_DORMANT or COL_HAUNT )

            local dist = IsValid( victim ) and math.floor( ent:GetPos():Distance( victim:GetPos() ) ) or -1

            local lines =
            {
                { string.format( "ANGEL #%d  %s", ent:EntIndex(), string.upper( mode ) ), col },
                { string.format( "tension %.2f   point %.1f   hunger %d", ent:GetNW2Float( "WATension", 0 ), ent:GetNW2Float( "WAPoint", 0 ), ent:GetNW2Int( "WAHunger", 0 ) ), COL_TEXT },
                { string.format( "dist %d   blind %.1fs", dist, ent:GetNW2Float( "WABlind", 0 ) ), COL_TEXT },
                { string.format( "scare %s   next %.1fs   fails %d", ent:GetNW2String( "WAScare", "nil" ), ent:GetNW2Float( "WANextScare", 0 ), ent:GetNW2Int( "WAFails", 0 ) ), COL_TEXT },
                { observed and ( ent:GetNW2Bool( "WAByAngel", false ) and "FROZEN BY ANOTHER ANGEL" or "SEEN - FROZEN" ) or "unobserved - free to move", observed and COL_SEEN or COL_TEXT },
            }

            lines[ #lines + 1 ] = { "flash: " .. ent:GetNW2String( "WAFlash", "?" ), COL_SEEN }

            local scores = ent:GetNW2String( "WAScores", "" )
            if scores ~= "" then lines[ #lines + 1 ] = { "targets (lower wins): " .. scores, COL_TEXT } end

            local siege = ent:GetNW2String( "WASiege", "-" )
            if siege ~= "-" then lines[ #lines + 1 ] = { "tardis: " .. siege, COL_SEEN } end

            -- measured light (only while the darkness feature is on)
            local dcv = GetConVar( "weepingangel_darkness" )
            if dcv and dcv:GetBool() and ent.WALight then
                lines[ #lines + 1 ] = { string.format( "light %.3f   %s", ent.WALight, ent.WADark and "DARK - unseen by you" or "lit" ),
                    ent.WADark and COL_DORMANT or COL_TEXT }
            end

            local eyeDist = lp:EyePos():Distance( ent:GetPos() )
            local scale   = math.Clamp( eyeDist * 0.0009, 0.1, 0.9 )
            local height  = #lines * LINE_H * scale
            local origin  = ent:GetPos() + Vector( 0, 0, ent:OBBMaxs().z + 10 + height )

            cam.IgnoreZ( true )
            cam.Start3D2D( origin, Angle( 0, lp:EyeAngles().yaw - 90, 90 ), scale )
                for i, l in ipairs( lines ) do
                    draw.SimpleTextOutlined( l[ 1 ], "WeepingAngelDebug", 0, ( i - 1 ) * LINE_H, l[ 2 ],
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, color_black )
                end
            cam.End3D2D()

            -- line from the angel to the player it is hunting
            if IsValid( victim ) then
                render.SetColorMaterial()
                render.DrawLine( ent:GetPos() + Vector( 0, 0, 36 ), victim:GetPos() + Vector( 0, 0, 36 ), observed and COL_SEEN or col, true )
            end
            cam.IgnoreZ( false )
        end
    end
end )