

--INACTIVE FILE


local binary_search_frame = modlib.table.binary_search_comparator(function(a, b)
	return modlib.table.default_comparator(a, b.frame)
end)

--> list of { bone_name = string, parent_bone_name = string, position = vector, rotation = quaternion, scale = vector }
function get_animated_bone_properties(self, keyframe, interpolate)
	local function get_frame_values(keys)
		local values = keys[keyframe]
		if values and values.frame == keyframe then
			return {
				position = values.position,
				rotation = values.rotation,
				scale = values.scale
			}
		end
		local index = binary_search_frame(keys, keyframe)
		if index > 0 then
			return keys[index]
		end
		index = -index
		assert(index > 1 and index <= #keys)
		local a, b = keys[index - 1], keys[index]
		if not interpolate then
			return a
		end
		local ratio = (keyframe - a.frame) / (b.frame - a.frame)
		return {
			position = (a.position and b.position and modlib.vector.interpolate(a.position, b.position, ratio)) or a.position or b.position,
			rotation = (a.rotation and b.rotation and modlib.quaternion.slerp(a.rotation, b.rotation, ratio)) or a.rotation or b.rotation,
			scale = (a.scale and b.scale and modlib.vector.interpolate(a.scale, b.scale, ratio)) or a.scale or b.scale,
		}
	end
	local bone_properties = {}
	local function get_props(node, parent_bone_name)
		local properties = {parent_bone_name = parent_bone_name}

		if keyframe > 0 and node.keys and next(node.keys) ~= nil then
			modlib.table.add_all(properties, get_frame_values(node.keys))
		end

		if not properties.position then -- animation not present, fall back to node position
			properties.position = modlib.table.copy(node.position)
		end

		if properties.rotation then -- animation is relative to node rotation
			properties.rotation = modlib.quaternion.compose(node.rotation, properties.rotation)
		else
			properties.rotation = modlib.table.copy(node.rotation)
		end

		if not properties.scale then -- animation not present, fall back to node scale
			properties.scale = modlib.table.copy(node.scale)
		end

		if node.bone then
			properties.bone_name = node.name
			table.insert(bone_properties, properties)
		end
		for _, child in pairs(node.children or {}) do
			get_props(child, properties.bone_name)
		end
	end
	get_props(self.node)
	return bone_properties
end