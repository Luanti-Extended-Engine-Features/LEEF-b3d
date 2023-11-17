--- allows you to get information about nodes (bones or meshes) within a b3d table (generated with `b3d_reader`)
--- located in `mtul.b3d_nodes`.
--- WARNING! mtul-cpml must be present for this module to run!
--@module b3d_nodes
--@warning for this module mtul_cpml is required, trying to use these functions without mtul_cpml ran will error.

--gets node by name
--this breaks if you have multiple nodes with the same name.
--if there are meshes that go by the same name, you can set "bone" param to true.
local b3d_nodes = {}
local mat4 = mtul.math.mat4
local quat = mtul.math.quat

--- get a node by it's name
-- @function get_node_by_name
-- @param self the b3d table (from b3d_reader)
-- @param node_name the name of the node to fine
-- @param is_bone (optional) bool to indicate wether the node is a bone or not (incase there's a mesh named the same thing). False will only return meshes and pivots, true will only return bones. Nil will return any.
-- @return node (from b3d table, documentation needed)
function b3d_nodes.get_node_by_name(self, node_name, is_bone)
    for i, this_node in pairs(self.node_paths) do
        if is_bone ~= nil then
            if (this_node.name == node_name) and ( ((this_node.type == "bone") and is_bone) or (this_node.type ~= "bone" and not is_bone) ) then
                return this_node
            end
        elseif (this_node.name == node_name) then
            return this_node
        end
    end
    --don't know why I'd ever just not return nil?
    --error("MTUL-b3d, b3d_nodes: no node found by the name '"..tostring(node_name).."'")
end

--non-methods:
local interpolate = function(a, b, ratio)
    local out = {}
    for i, v in pairs(a) do
        out[i] = a[i]-((a[i]-b[i])*ratio)
    end
    return out
end
--keep in mind that this returns *raw* info, other then vectorizing quaternions (as slerp has to be performed to interpolate).
--further, quaternions need to have their w inverted.

--- get the local "TRS" (translation, rotation, scale) of a bone in animation. This is used for global transformation calculations.
--- quaternion is returned as a string indexed table because it needs to be a cpml object to be interpolated, also has to be usable anyway.
-- @function get_animated_local_trs
-- @param node table, the node from within a b3d table to read (as outputed by b3d_reader).
-- @param target_frame float, the frame to find the TRS in, can be inbetween frames/keyframes (of course).
-- @return `position` ordered table: {x, y, z}
-- @return `rotation` quat from `mtul_cpml`: (example) {w=0,x=0,y=0,z=1}
-- @return `scale` ordered table: {x, y, z}
--outputs need cleaning up.
function b3d_nodes.get_animated_local_trs(node, target_frame)
    assert(target_frame, "no frame specified for TRS calculations")
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
            quat.new(unpack(frame_before_tbl.rotation)):slerp(quat.new(unpack(frame_after_tbl.rotation)), ratio),
            interpolate(frame_before_tbl.scale, frame_after_tbl.scale, ratio)
    else
        return
            table.copy(frame_before_tbl.position),
            quat.new(unpack(frame_before_tbl.rotation)),
            table.copy(frame_before_tbl.scale)
    end
end
--param 3 (outputs) is either "rotation" or "transform"- determines what's calculated. You can use this if you dont want uncessary calculations. If nil outputs both

--- get a node's global mat4 transform and rotation.
-- @function get_node_global_transform
-- @param node table, the node from within a b3d table to read (as outputed by `b3d_reader`).
-- @param frame float, the frame to find the transform and rotation in.
-- @param outputs (optional) string, either "rotation" or "transform". Set to nil to return both.
-- @return `global_transform`, a matrix 4x4, note that CPML's tranforms are column major (i.e. 1st column is 1, 2, 3, 4). (see `mtul_cpml` docs)
-- @return `rotation quat`, the quaternion rotation in global space. (cannot be assumed to be normalized, this uses raw interpolated data from the b3d reader)
function b3d_nodes.get_node_global_transform(node, frame, outputs)
    local global_transform
    local rotation
    for i, current_node in pairs(node.path) do
        local pos_vec, rot_vec, scl_vec =  b3d_nodes.get_animated_local_trs(current_node, frame)
        rot_vec.w = -rot_vec.w --b3d rotates the opposite way around the axis (I guess)
        --find the transform
        if not (outputs and outputs ~= "transform") then
            --rot_vec = {rot_vec[2], rot_vec[3], rot_vec[4], rot_vec[1]}
            local local_transform = mat4.identity()
            local_transform = local_transform:translate(local_transform, pos_vec)
            local_transform = local_transform*(mat4.from_quaternion(rot_vec:normalize())) --W has to be inverted

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
            if not rotation then
                rotation = rot_vec
            else
                rotation = rotation*rot_vec
            end
        end
    end
    return global_transform, rotation
end

--Returns X, Y, Z. is_bone is optional, if "node" is the name of a node (and not the node table), parameter 1 (self) and parameter 3 (is_bone) is used to find it.

--- find the position of a node in global model space.
--@function get_node_global_position
--@param self b3d table, (optional if node is a node table and not name)
--@param node string or table, either the node from b3d table or a the name of the node to find.
--@param is_bone (optional) if node is string, this is used to find it (see `get_node_by_name`)
--@param frame the frame to find the global position of the node at.
--@return `x`
--@return `y`
--@return `z`
function b3d_nodes.get_node_global_position(self, node, is_bone, frame)
    assert(self or not type(node)=="string")
    assert(node, "cannot get position of a nil node")
    assert(frame, "no frame specified!")
    if type(node) == "string" then
        node = b3d_nodes.get_node_by_name(self, node, is_bone)
    end
    local transform = b3d_nodes.get_node_global_transform(node, frame, "transform")
    return transform[13], transform[14], transform[15]
end
--- find the global rotation of a node in model space.
--@function get_node_rotation
--@param self b3d table, (optional if node is a node table and not name)
--@param node string or table, either the node from b3d table or a the name of the node to find.
--@param is_bone (optional) if node is string, this is used to find it (see `get_node_by_name`)
--@param frame the frame to find the global rotation of the node at.
--@return `rotation` quaternion rotation of the node (may not be normalized)
function b3d_nodes.get_node_rotation(self, node, is_bone, frame)
    assert(self or not type(node)=="string")
    assert(node, "cannot get rotation of a nil node")
    assert(frame, "no frame specified!")
    if type(node) == "string" then
        node = b3d_nodes.get_node_by_name(self, node, is_bone)
    end
    local _, rotation = b3d_nodes.get_node_global_transform(node, frame, "rotation")
    return rotation
end
return b3d_nodes