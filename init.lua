
--[[
   this library provides two modules:
   b3d
   b3d_nodes

   b3d_nodes is for reading and interperetting b3d objects from the b3d module.
   the b3d module is a heavily modified version of Modlib's b3d reader, and as such
   has it's own respective directory for licensing purposes.
]]

mtul.b3d = {}
mtul.loaded_modules.b3d = true

local modpath = minetest.get_modpath("mtul_b3d")
--placed in a seperate directory for the license
dofile(modpath.."/modlib/read_b3d.lua")
dofile(modpath.."/modlib/write_b3d.lua") --this is untested, could be very broken.

--prevent accidental access of unavailable features:
if mtul.loaded_modules.cpml then
   mtul.b3d_nodes = dofile(modpath.."/nodes.lua")
   mtul.loaded_modules.b3d_nodes = true
   mtul.b3d_nodes.loaded = true
else
   mtul.b3d_nodes = {}
   setmetatable(mtul.b3d_nodes, {
      __index = function(_, k)
         if k ~= "loaded" then
            error("MTUL-CPML not present, b3d_nodes module inaccessible.")
         else
            return false
         end
      end
   })
end
--dofile(modpath.."/read_b3d_bone.lua"