-- Put this file at: lua/autorun/server/weepingangel_resources.lua
-- Makes clients on a dedicated server download the angel models and materials.

local mdl = "models/the_sniper_9/doctorwho/extras/angels/"
for _, n in ipairs( { "angelidle", "angelpoint", "angelattack" } ) do
    for _, ext in ipairs( { ".mdl", ".vvd", ".phy", ".dx80.vtx", ".dx90.vtx", ".sw.vtx" } ) do
        resource.AddFile( mdl .. n .. ext )
    end
end

local mat = "materials/the_sniper_9/doctorwho/extras/angels/"
for _, f in ipairs( { "angelbody", "angelface", "angelwings" } ) do
    resource.AddFile( mat .. f .. ".vmt" )
    resource.AddFile( mat .. f .. ".vtf" )
    resource.AddFile( mat .. f .. "_nrm.vtf" )
end

resource.AddFile( "materials/vgui/entities/weepingangel.vmt" )
resource.AddFile( "materials/vgui/entities/weepingangel.vtf" )