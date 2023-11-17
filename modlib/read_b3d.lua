
--this reader has been heavily modified to implement additional needed features.
--implementations include:

--mtul.b3d.read_model()
--ignore_chunks parameter,
--node.parent,
--node.path
--b3d.node_paths

-- Localize globals

--- parse .b3d files into a lua table.
--- located in `mtul.b3d_reader`.
--@module b3d_reader

local read_int, read_single = mtul.binary.read_int, mtul.binary.read_single

--reads a model directly (based on name). Note that "node_only" abstracts chunks not necessary to finding the position/transform of a bone/node.

--- read b3d models by their name. This simplifies read_from_stream.
-- @function read_model
-- @param modelname string, the name of model you are trying to read.
-- @param node_only bool, specifies wether to ignore textures, meshes, or anything else. Use this if you're only trying to solve bone transforms.
-- @return b3d table (documentation needed!)
function mtul.b3d_reader.read_model(modelname, node_only)
	assert(modelname, "no modelname provided")
	-- @todo remove core dependancy on
	local path = assert(mtul.media_paths[modelname], "no model found by the name "..modelname.."'")
	local out
	local ignored
	if node_only then
		ignored = {"TEXS", "BRUS", "BONE", "MESH"}
	end
	local stream = io.open(path, "rb")
	if not stream then return end --if the file wasn't found we probably shouldnt just assert.
	out = mtul.b3d_reader.read_from_stream(stream, ignored)
	assert(stream:read(1)==nil, "MTUL b3d_reader: unknown error, EOF not reached")
	stream:close()
	return out
end

--"ignore_chunks" is a list of chunks to ignore when reading- as for various applications it may be uncessary or otherwise redundant
--note that this does not increase runtime spead as chunks still must be read before we know what they are (currently)
--chunk types: "BB3D", "TEXS", "BRUS", "TRIS", "MESH", "BONE", "ANIM", "KEYS", "VRTS", "NODE"
--this specifies what chunks can be found inside eachother
--MESH subtypes: VRTS, TRIS
--BB3D subtypes: TEXS, NODE
--NODE subtypes: KEYS, ANIM, NODE, BONE, MESH

--node_paths is a table of nodes indexed by a table containing a hierarchal list of nodes to get to that node (including itself).
--this is ideal if you need to, say, solve for the transform of a node- instead of iterating 100s of times to get every parent node
--it's all provided for you. Note that it's from highest to lowest, where lowest of course is the current node, the last element.

--made originally by appgurueu
-- See `b3d_specification.txt` as well as https://github.com/blitz-research/blitz3d/blob/master/blitz3d/loader_b3d.cpp

--- read directly from file
-- @function read_from_stream
-- @param stream the file object (from the io library) to read from. Make sure you open it as "rb" (read binary.)
-- @param ignore_chunks a list of chunks to be ignored (documentation needed)
-- @return b3d table (documentation needed!)

--- an unordered list of the following string chunks.
--- "NODE" and "BB3D" are ommitted as they are not allowed.
-- @field 1 "TEXS" texture information
-- @field 2 "BRUS" brushes (materials)
-- @field 3 "MESH" (sub-chunks of "MESH" include "VERTS" & "TRIS")
-- @field 4 "TRIS" sets of triangles
-- @field 5 "VRTS" vertices
-- @field 6 "BONE" node vertex weights
-- @field 7 "ANIM" animation information
-- @field 8 "KEYS" keyframes
-- @table ignore_chunks

function mtul.b3d_reader.read_from_stream(stream, ignore_chunks)
	local left = 8

	local ignored = {}
	if ignore_chunks then
		for i, v in pairs(ignore_chunks) do
			ignored[v] = true
		end
		assert(not ignored.BB3D, "reader cannot not ignore entire model. (ignore_chunks contained BB3D)")
		assert(not ignored.NODE, "reader cannot not ignore entire model. (ignore_chunks contained NODE)")
	end
	local function byte()
		left = left - 1
		return assert(stream:read(1):byte())
	end

	local function int()
		return read_int(byte, 4)
	end

	local function id()
		return int() + 1
	end

	local function optional_id()
		local id = int()
		if id == -1 then
			return
		end
		return id + 1
	end

	local function string()
		local rope = {}
		while true do
			left = left - 1
			local char = assert(stream:read(1))
			if char == "\0" then
				return table.concat(rope)
			end
			table.insert(rope, char)
		end
	end

	local function float()
		return read_single(byte)
	end

	local function float_array(length)
		local list = {}
		for index = 1, length do
			list[index] = float()
		end
		return list
	end

	local function color()
		local ret = {}
		ret.r = float()
		ret.g = float()
		ret.b = float()
		ret.a = float()
		return ret
	end

	local function vector3()
		return float_array(3)
	end

	local function quaternion()
		local w = float()
		local x = float()
		local y = float()
		local z = float()
		return {x, y, z, w}
	end

	local function content()
		if left < 0 then
			error(("unexpected EOF at position %d"):format(stream:seek()))
		end
		return left ~= 0
	end

	local node_chunk_types = {

	}

	local chunk
	local chunks = {
		TEXS = function()
			local textures = {}
			while content() do
				local tex = {}
				tex.file = string()
				tex.flags = int()
				tex.blend = int()
				tex.pos = float_array(2)
				tex.scale = float_array(2)
				tex.rotation = float()
				table.insert(textures, tex)
			end
			return textures
		end,
		BRUS = function()
			local brushes = {}
			local n_texs = int()
			assert(n_texs <= 8)
			while content() do
				local brush = {}
				brush.name = string()
				brush.color = color()
				brush.shininess = float()
				brush.blend = int()
				brush.fx = int()
				brush.texture_id = {}
				for index = 1, n_texs do
					brush.texture_id[index] = optional_id()
				end
				table.insert(brushes, brush)
			end
			return brushes
		end,
		VRTS = function()
			local vertices = {}
			vertices.flags = int()
			vertices.tex_coord_sets = int()
			vertices.tex_coord_set_size = int()
			assert(vertices.tex_coord_sets <= 8 and vertices.tex_coord_set_size <= 4)
			local has_normal = (vertices.flags % 2 == 1) or nil
			local has_color = (math.floor(vertices.flags / 2) % 2 == 1) or nil
			while content() do
				local vertex = {}
				vertex.pos = vector3()
				vertex.normal = has_normal and vector3()
				vertex.color = has_color and color()
				vertex.tex_coords = {}
				for tex_coord_set = 1, vertices.tex_coord_sets do
					local tex_coords = {}
					for tex_coord = 1, vertices.tex_coord_set_size do
						tex_coords[tex_coord] = float()
					end
					vertex.tex_coords[tex_coord_set] = tex_coords
				end
				table.insert(vertices, vertex)
			end
			return vertices
		end,
		TRIS = function()
			local tris = {}
			tris.brush_id = id()
			tris.vertex_ids = {}
			while content() do
				local i = id()
				local j = id()
				local k = id()
				table.insert(tris.vertex_ids, {i, j, k})
			end
			return tris
		end,
		MESH = function()
			local mesh = {}
			mesh.brush_id = optional_id()
			mesh.vertices = chunk{VRTS = true}
			mesh.triangle_sets = {}
			repeat
				local tris = chunk{TRIS = true}
				table.insert(mesh.triangle_sets, tris)
			until not content()
			return mesh
		end,
		BONE = function()
			local bone = {}
			while content() do
				local vertex_id = id()
				assert(not bone[vertex_id], "duplicate vertex weight")
				local weight = float()
				if weight > 0 then
					-- Many exporters include unneeded zero weights
					bone[vertex_id] = weight
				end
			end
			return bone
		end,
		KEYS = function()
			local flags = int()
			local _flags = flags % 8
			local rotation, scale, position
			if _flags >= 4 then
				rotation = true
				_flags = _flags - 4
			end
			if _flags >= 2 then
				scale = true
				_flags = _flags - 2
			end
			position = _flags >= 1
			local bone = {
				flags = flags
			}
			while content() do
				local frame = {}
				frame.frame = int()
				if position then
					frame.position = vector3()
				end
				if scale then
					frame.scale = vector3()
				end
				if rotation then
					frame.rotation = quaternion()
				end
				table.insert(bone, frame)
			end
			return bone
		end,
		ANIM = function()
			local ret = {}
			ret.flags = int() -- flags are unused
			ret.frames = int()
			ret.fps = float()
			return ret
		end,
		NODE = function()
			local node = {}
			node.name = string()
			node.position = vector3()
			node.scale = vector3()
			if not ignored.KEYS then
				node.keys = {}
			end
			node.rotation = quaternion()
			node.children = {}
			local node_type
			-- See https://github.com/blitz-research/blitz3d/blob/master/blitz3d/loader_b3d.cpp#L263
			-- Order is not validated; double occurrences of mutually exclusive node def are
			while content() do
				local elem, type = chunk()
				if type == "MESH" then
					assert(not node_type)
					node_type = "mesh"
					if not ignored[type] then
						node.mesh = elem
					end
				elseif type == "BONE" then
					assert(not node_type)
					node_type = "bone"
					if not ignored[type] then
						node.bone = elem
					end
				elseif type == "KEYS" then
					if not ignored[type] then
						mtul.tbl.append(node.keys, elem)
					end
				elseif type == "NODE" then
					elem.parent = node
					table.insert(node.children, elem)
				elseif type == "ANIM" then
					if not ignored[type] then
						node.animation = elem
					end
				else
					assert(not node_type, "Appgurueu decided to not put actual comments, so I'm not sure, but your .b3d file is fscked up lol. I dont even think this assert is needed.")
					node_type = "pivot"
				end
			end
			--added because ignored nodes may obfuscate the type of node- which could be necessary for finding bone "paths"
			node.type = node_type or "pivot"
			-- Ensure frames are sorted ascendingly
			table.sort(node.keys, function(a, b)
				assert(a.frame ~= b.frame, "duplicate frame")
				return a.frame < b.frame
			end)
			return node
		end,
		BB3D = function()
			local version = int()
			local self = {
				version = {
					major = math.floor(version / 100),
					minor = version % 100,
				},
			}
			if not ignored.TEXS then self.textures = {} end
			if not ignored.BRUS then self.brushes = {} end
			assert(self.version.major <= 2, "unsupported version: " .. self.version.major)
			while content() do
				local field, type = chunk{TEXS = true, BRUS = true, NODE = true}
				if not ignored[type] then
					if type == "TEXS" then
						mtul.tbl.append(self.textures, field)
					elseif type == "BRUS" then
						mtul.tbl.append(self.brushes, field)
					else
						self.node = field
					end
				end
			end
			return self
		end
	}

	local function chunk_header()
		left = left - 4
		return stream:read(4), int()
	end

	function chunk(possible_chunks)
		local type, new_left = chunk_header()
		local parent_left
		left, parent_left = new_left, left
		if possible_chunks and not possible_chunks[type] then
			error("expected one of " .. table.concat(mtul.tbl.keys(possible_chunks), ", ") .. ", found " .. type .. ". This is likely exporter error.")
		end
		local res = assert(chunks[type])()
		assert(left == 0)
		left = parent_left - new_left
		return res, type
	end

	--due to the nature of how the b3d is read, paths have to be built by recursively iterating the table in post.
	--luckily most of the ground work is layed out for us already.

	--also, Fatal here: for the sake of my reputation (which is nonexistent), typically I wouldn't nest these functions
	--because I am not a physcopath and or a german named Lars, but for the sake of consistency it has to happen.
	--(Not that its *always* a bad idea, but unless you're baking in parameters it's sort of useless and potentially wasteful)
	local copy_path = mtul.table and mtul.table.shallow_copy or function(tbl)
		local new_table = {}
		for i, v in pairs(tbl) do
			new_table[i] = v
		end
		return new_table
	end
	local function make_paths(node, path, node_paths)
		local new_path = copy_path(path)
		table.insert(new_path, node)
		node_paths[new_path] = node --this will create a list of paths
		for i, next_node in pairs(node.children) do
			make_paths(next_node, new_path, node_paths)
		end
		node.path = new_path
	end

	local self = chunk{BB3D = true}
	self.node_paths = {}
	self.excluded_chunks = ignore_chunks and table.copy(ignore_chunks) or {}
	assert(self.node, "no root node - model improperly exported. If using blender, ensure all objects are selected before exporting.")
	make_paths(self.node, {}, self.node_paths)

	--b3d metatable unimplemented
	return setmetatable(self, mtul._b3d_metatable or {})
end

--- b3d table
-- @field node_paths