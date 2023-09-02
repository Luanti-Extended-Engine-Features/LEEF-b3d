--gets node by name
--this breaks if you have multiple nodes with the same name.
--if there are meshes that go by the same name, you can set "bone" param to true.
local b3d_nodes = {}
function b3d_nodes.get_node_by_name(self, node_name, is_bone)
    for i, this_node in pairs(self.node_paths) do
        if ( (not is_bone) or (this_node.type=="bone") ) and (this_node.name == node_name) then
            return this_node
        end
    end
    error("MTUL-b3d, b3d_nodes: no node found by the name '"..node_name.."'")
end

--non-methods:
local interpolate = function(a, b, ratio)
    local out = {}
    for i, v in pairs(a) do
        out[i] = a[i]-((a[i]-b[i])*ratio)
    end
    return out
end
function b3d_nodes.get_animated_local_transform(node, target_frame)
    local frames = node.keys
    local key_index_before = 0 --index of the key before the target_frame.
    for i, key in ipairs(frames) do
        --pick the closest frame we find that's less then the target
        if key.frame < target_frame then
            key_index_before = i
        else
            break --we've reached the end of our possible frames to use.
        end
    end
    --need this so we can replace it if before doesnt exist
    local frame_before_tbl = frames[key_index_before]
    local frame_after_tbl = frames[key_index_before+1] --frame to interpolate will be out immediate neighbor since we know its either the frame or after the frame.
    print(target_frame)
    --it may still be zero, indicating that the frame before doesnt exist.
    if not frame_before_tbl then
        frame_before_tbl = node --set it to the node so it pulls from PRS directly as that's it's default state.
    end
    --no point in interpolating if it's all the same...
    if frame_after_tbl then
        local f1 = frame_before_tbl.frame or -1
        local f2 = frame_after_tbl.frame --if there's no frame after that then
        local ratio = (f1-target_frame)/(f1-f2) --find the interpolation ratio
        return
            interpolate(frame_before_tbl.position, frame_after_tbl.position, ratio),
            interpolate(frame_before_tbl.rotation, frame_after_tbl.rotation, ratio),
            interpolate(frame_before_tbl.scale, frame_after_tbl.scale, ratio)
    else
        return
            table.copy(frame_before_tbl.position),
            table.copy(frame_before_tbl.rotation),
            table.copy(frame_before_tbl.scale)
    end
end
local mat4 = mtul.math.mat4
local quat = mtul.math.quat
function b3d_nodes.get_node_global_transform(node, frame)
    local global_transform
    for i, current_node in pairs(node.path) do
        local pos_vec, rot_vec, scl_vec =  b3d_nodes.get_animated_local_transform(current_node, frame)
        --rot_vec = {rot_vec[2], rot_vec[3], rot_vec[4], rot_vec[1]}
        local local_transform = mat4.identity()
        --translate rotation by position
        local_transform = local_transform:translate(local_transform, {-pos_vec[1], pos_vec[2], pos_vec[3]})
        local_transform = local_transform*(mat4.from_quaternion(quat.new(-rot_vec[1], rot_vec[2], rot_vec[3], rot_vec[4]):normalize()))
        --scale the mat4.
        --local_transform = local_transform:scale(local_transform, {scl_vec[1], scl_vec[2], scl_vec[3]})
        --I dont really know why this works and the above doesn't, but at this point I'm done trying to figure it out...
        local identity = mat4.identity()
        local_transform = local_transform*identity:scale(identity, {scl_vec[1], scl_vec[2], scl_vec[3]})

        --get new global trasnform with the local.
        if global_transform then
            global_transform=global_transform*local_transform
        else
            global_transform=local_transform
        end
    end
    --pos = global_transform:apply({pos[1], pos[2], pos[3], 1})
    --print(dump(global_transform))
    --return vector.new(pos[1], pos[2], pos[3])
    return global_transform
end

--Returns X, Y, Z. is_bone is optional, if "node" is the name of a node (and not the node table), this is used to find it.
function b3d_nodes.get_node_position(self, node, is_bone, frame)
    if type(node) == "string" then
        node = b3d_nodes.get_node_by_name(self, node)
    end
    local transform = b3d_nodes.get_node_global_transform(node, frame)
    return transform[13], transform[14], transform[15]
end

--since it's impossible to determine the difference between rotation
--and non-uniform scaling, we have to use a different method for this.
function b3d_nodes.get_node_rotation()
end
return b3d_nodes