
mtul.b3d = {}

local modpath = minetest.get_modpath("mtul_b3d")
--placed in a seperate directory for the license
dofile(modpath.."/modlib/read_b3d.lua")
dofile(modpath.."/modlib/write_b3d.lua") --this is untested, could be very broken.
--these modules are disabled, refactoring is needed.
if mtul.math.cpml_loaded then
   dofile(modpath.."/read_b3d_bone")
end
--dofile(modpath.."/read_b3d_bone.lua"