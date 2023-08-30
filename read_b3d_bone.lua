

--INACTIVE FILE


local binary_search_frame = modlib.table.binary_search_comparator(function(a, b)
	return modlib.table.default_comparator(a, b.frame)
end)

--> list of { bone_name = string, parent_bone_name = string, position = vector, rotation = quaternion, scale = vector }
function mtul.b3d:get_bone_global_transform(self, node_name)

end
function mtul.b3d:get_bone