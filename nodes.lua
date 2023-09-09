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
    error("MTUL-b3d, b3d_nodes: no node found by the name '"..tostring(node_name).."'")
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
--param 3 (outputs) is either "rotation" or "transform"- determines what's calculated. You can use this if you dont want uncessary calculations. If nil outputs both
function b3d_nodes.get_node_global_transform(node, frame, outputs)
    local global_transform
    local rotation
    for i, current_node in pairs(node.path) do
        local pos_vec, rot_vec, scl_vec =  b3d_nodes.get_animated_local_transform(current_node, frame)

        --find the transform

        if not (outputs and outputs ~= "transform") then
            --rot_vec = {rot_vec[2], rot_vec[3], rot_vec[4], rot_vec[1]}
            local local_transform = mat4.identity()
            local_transform = local_transform:translate(local_transform, {-pos_vec[1], pos_vec[2], pos_vec[3]})--not sure why x has to be inverted,
            local_transform = local_transform*(mat4.from_quaternion(quat.new(-rot_vec[1], rot_vec[2], rot_vec[3], rot_vec[4]):normalize())) --W has to be inverted

            --for some reason the scaling has to be broken up, I can't be bothered to figure out why after the time I've spent trying.
            local identity = mat4.identity()
            local_transform = local_transform*identity:scale(identity, {scl_vec[1], scl_vec[2], scl_vec[3]})

            --get new global trasnform with the local.
            if global_transform then
                global_transform=global_transform*local_transform
            else
                global_transform=local_transform
            end
        end

        --find the rotation

        if not (outputs and outputs ~= "rotation") then
            --find the rotation. Please note that modlib's code (in the b3d reader from mtul-b3d-standalone) converts xyzw to wxyz when reading b3ds
            if not rotation then
                rotation = quat.new(-rot_vec[1], rot_vec[2], rot_vec[3], rot_vec[4])
            else
                rotation = rotation*quat.new(-rot_vec[1], rot_vec[2], rot_vec[3], rot_vec[4])
            end
        end
    end
    --x needs to be inverted (as mentioned earlier.)
    if global_transform then
        global_transform[13] = -global_transform[13]
    end
    return global_transform, rotation
end

--Returns X, Y, Z. is_bone is optional, if "node" is the name of a node (and not the node table), parameter 1 (self) and parameter 3 (is_bone) is used to find it.
function b3d_nodes.get_node_global_position(self, node, is_bone, frame)
    assert(self or not type(node)=="string")
    if type(node) == "string" then
        node = b3d_nodes.get_node_by_name(self, node, is_bone)
    end
    local transform = b3d_nodes.get_node_global_transform(node, frame, "transform")
    return transform[13], transform[14], transform[15]
end
--exactly like get_node_global_position, but it returns a vec3 quaternion.
function b3d_nodes.get_node_rotation(self, node, is_bone, frame)
    assert(self or not type(node)=="string")
    if type(node) == "string" then
        node = b3d_nodes.get_node_by_name(self, node, is_bone)
    end
    local _, rotation = b3d_nodes.get_node_global_transform(node, frame, "rotation")
    return rotation
end
return b3d_nodes