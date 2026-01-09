-- DevTester v2.0 - Node Rendering
-- Rendering functions for all node types

local State = require("DevTester2.State")
local Constants = require("DevTester2.Constants")
local Utils = require("DevTester2.Utils")

local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local Nodes = {}

function Nodes.is_terminal_type(type_name)
    if not type_name then return false end
    if type_name == "System.Boolean" or type_name == "Boolean" then return true end
    if type_name == "System.Byte" or type_name == "Byte" then return true end
    if type_name == "System.SByte" or type_name == "SByte" then return true end
    if type_name == "System.Int16" or type_name == "Int16" then return true end
    if type_name == "System.UInt16" or type_name == "UInt16" then return true end
    if type_name == "System.Int32" or type_name == "Int32" then return true end
    if type_name == "System.UInt32" or type_name == "UInt32" then return true end
    if type_name == "System.Int64" or type_name == "Int64" then return true end
    if type_name == "System.UInt64" or type_name == "UInt64" then return true end
    if type_name == "System.Single" or type_name == "Single" then return true end
    if type_name == "System.Double" or type_name == "Double" then return true end
    if type_name == "System.String" or type_name == "String" then return true end
    if type_name == "System.Void" or type_name == "Void" then return true end
    return false
end

function Nodes.get_object_type(obj)
    if not obj then return nil end
    -- Check if obj is already a type definition
    if type(obj) == "userdata" and obj.get_full_name then
        local success, test_name = pcall(function() return obj:get_full_name() end)
        if success and test_name then
            return obj
        end
    end

    -- Otherwise, try to get type definition from managed object
    local success, obj_type = pcall(function()
        return obj:get_type_definition()
    end)

    if not success or not obj_type then
        return nil
    end

    return obj_type
end

function Nodes.validate_continuation(result, parent_value, type_full_name)
    if result == nil then return false, nil end
    
    -- Attempt to fix value type if we have a type name and get_type_definition fails
    if type_full_name and type(result) == "userdata" then
         local success, _ = pcall(function() return result:get_type_definition() end)
         if not success then
             result = sdk.to_valuetype(result, type_full_name)
         end
    end
    
    local can_continue = false
    
    -- Check if userdata
    if type(result) == "userdata" then
        can_continue = true
        
        -- Check terminal type
        local success, type_def = pcall(function() return result:get_type_definition() end)
        if success and type_def then
            if Nodes.is_terminal_type(type_def:get_full_name()) then
                can_continue = false
            end
        end
    end
    
    -- Nullable check
    if can_continue and parent_value then
        local parent_type = Nodes.get_object_type(parent_value)
        if parent_type and parent_type:get_name():find("Nullable") then
            local has_value = parent_value:get_field("_HasValue")
            if not has_value then
                return false, nil -- Invalid result
            end
        end
    end
    
    return can_continue, result
end

-- ========================================
-- Node Titlebar Color and Width Helpers
-- ========================================
function Nodes.set_node_titlebar_color(color)
    local hovered_color = Utils.brighten_color(color, Constants.COLOR_BRIGHTEN_HOVER)
    local selected_color = Utils.brighten_color(color, Constants.COLOR_BRIGHTEN_SELECTED)

    imnodes.push_color_style(4, color)        -- Normal
    imnodes.push_color_style(5, hovered_color) -- Hovered
    imnodes.push_color_style(6, selected_color) -- Selected
end

function Nodes.reset_node_titlebar_color()
    imnodes.pop_color_style() -- Normal, Hovered, Selected
end

function Nodes.get_node_titlebar_color(category, type)
    if Constants["NODE_COLOR_" .. category .. "_" .. type] then
        return Constants["NODE_COLOR_" .. category .. "_" .. type]
    elseif Constants["NODE_COLOR_" .. category] then
        return Constants["NODE_COLOR_" .. category]
    end
    return Constants.NODE_COLOR_DEFAULT
end

function Nodes.get_node_width(category, type)
    if Constants["NODE_WIDTH_" .. category .. "_" .. type] then
        return Constants["NODE_WIDTH_" .. category .. "_" .. type]
    elseif Constants["NODE_WIDTH_" .. category] then
        return Constants["NODE_WIDTH_" .. category]
    end
    return Constants.NODE_WIDTH_DEFAULT
end

function Nodes.reset_operation_data(node)
    -- Clear method-specific data
    node.selected_method_combo = 1
    node.method_group_index = nil
    node.method_index = nil
    node.param_manual_values = {}
    
    -- Clear field-specific data
    node.selected_field_combo = 1
    node.field_group_index = nil
    node.field_index = nil
    node.value_manual_input = ""
    node.action_type = Constants.ACTION_GET -- Reset to default action
    
    -- Clear array-specific data
    node.selected_element_index = 0
    node.index_manual_value = ""
    
    -- Clear common data that might be operation-specific
    node.starting_value = nil
    node.ending_value = nil
    node.status = nil
end

-- ========================================
-- Node Rendering Helper Functions
-- ========================================

function Nodes.get_disconnection_message(reason)
    if reason == "no_parent" then
        return "Connect to parent node"
    elseif reason == "parent_nil" then
        return "Parent node returns nil"
    elseif reason == "type_error" then
        return "Parent returns unexpected type"
    else
        return "Connect to parent node"
    end
end

function Nodes.render_disconnected_titlebar(node, reason)
    imnodes.begin_node_titlebar()
    
    -- Get the first input pin (parent connection)
    local input_pin = node.pins and node.pins.inputs and node.pins.inputs[1]
    if input_pin then
        imnodes.begin_input_attribute(input_pin.id)
    end
    
    local operation_name = Utils.parse_category_and_type(node.category, node.type)
    imgui.text(operation_name .. " (Disconnected)")
    
    if input_pin then
        imnodes.end_input_attribute()
    end
    imnodes.end_node_titlebar()
end

function Nodes.render_disconnected_message(reason)
    local message = Nodes.get_disconnection_message(reason)
    imgui.text_colored(message, Constants.COLOR_TEXT_WARNING)
    imgui.spacing()
end

function Nodes.render_disconnected_attributes(node)
    -- Render all output pins if they exist
    if node.pins and node.pins.outputs then
        for _, output_pin in ipairs(node.pins.outputs) do
            imnodes.begin_output_attribute(output_pin.id)
            imgui.text(output_pin.name or "Output (Disconnected)")
            imnodes.end_output_attribute()
        end
    end

    -- Render parameter input pins (if any beyond the parent connection)
    if node.pins and node.pins.inputs then
        -- Skip first pin (parent connection), render the rest as params
        for i = 2, #node.pins.inputs do
            local input_pin = node.pins.inputs[i]
            imnodes.begin_input_attribute(input_pin.id)
            imgui.text(input_pin.name or string.format("Param %d (Disconnected)", i - 1))
            imnodes.end_input_attribute()
        end
    end
end

function Nodes.render_disconnected_operation_node(node, reason)
    -- Ensure all pin IDs exist before rendering
    Nodes.ensure_node_pin_ids(node)
    
    imnodes.begin_node(node.id)
    
    Nodes.render_disconnected_titlebar(node, reason)
    Nodes.render_disconnected_message(reason)
    Nodes.render_disconnected_attributes(node)
    
    if imgui.button("- Remove Node") then
        Nodes.remove_node(node)
    end
    
    imnodes.end_node()
end

function Nodes.render_disconnected_debug_info(node)
    -- Collect all input pin IDs
    local input_pins = {}
    if node.pins and node.pins.inputs then
        for _, pin in ipairs(node.pins.inputs) do
            table.insert(input_pins, tostring(pin.id))
        end
    end
    
    -- Collect all output pin IDs
    local output_pins = {}
    if node.pins and node.pins.outputs then
        for _, pin in ipairs(node.pins.outputs) do
            table.insert(output_pins, tostring(pin.id))
        end
    end
    
    -- Find input and output links, showing pin and link id
    local input_links, output_links = {}, {}
    for _, link in ipairs(State.all_links) do
        if link.to_node == node.id then
            table.insert(input_links, string.format("(Pin %s, Link %s)", tostring(link.to_pin), tostring(link.id)))
        end
        if link.from_node == node.id then
            table.insert(output_links, string.format("(Pin %s, Link %s)", tostring(link.from_pin), tostring(link.id)))
        end
    end
    
    local debug_info = string.format(
        "Node ID: %s\nInput Pins: %s\nOutput Pins: %s\nInput Links: %s\nOutput Links: %s",
        tostring(node.id),
        #input_pins > 0 and table.concat(input_pins, ", ") or "None",
        #output_pins > 0 and table.concat(output_pins, ", ") or "None",
        #input_links > 0 and table.concat(input_links, ", ") or "None",
        #output_links > 0 and table.concat(output_links, ", ") or "None"
    )
    
    -- Align debug info to the top right of the node
    local pos_for_debug = Utils.get_top_right_cursor_pos(node.id, "[?]")
    imgui.set_cursor_pos(pos_for_debug)
    imgui.text_colored("[?]", Constants.COLOR_TEXT_DEBUG)
    
    if imgui.is_item_hovered() then
        imgui.set_tooltip(debug_info)
    end
end

-- ========================================
-- Main Rendering Dispatcher
-- ========================================






-- ========================================
-- Node Management Functions
-- ========================================

function Nodes.add_child_node(parent_node)
    -- Random Y offset between -150 and +150
    local random_y_offset = math.random(Constants.CHILD_NODE_RANDOM_Y_MIN, Constants.CHILD_NODE_RANDOM_Y_MAX)
    
    local BaseFollower = require("DevTester2.Followers.BaseFollower")
    local child = BaseFollower.create({
        x = parent_node.position.x + imnodes.get_node_dimensions(parent_node.id).x + Constants.CHILD_NODE_OFFSET_X,
        y = parent_node.position.y + random_y_offset
    })
    
    -- Auto-detect if parent value is an array and set type to Array
    if parent_node.ending_value then
        if Utils.is_array(parent_node.ending_value) then
            child.type = Constants.FOLLOWER_TYPE_ARRAY
        end
    end
    
    -- Ensure parent has output pin
    if not parent_node.pins or not parent_node.pins.outputs or #parent_node.pins.outputs == 0 then
        -- Create output pin with parent's current ending_value
        Nodes.add_output_pin(parent_node, "Output", parent_node.ending_value)
    end
    local parent_output_pin = parent_node.pins.outputs[1]
    
    -- Sync output pin value with parent's ending_value
    parent_output_pin.value = parent_node.ending_value
    
    -- Ensure child has input pin
    if not child.pins or not child.pins.inputs or #child.pins.inputs == 0 then
        Nodes.add_input_pin(child, "Parent", nil)
    end
    local child_input_pin = child.pins.inputs[1]
    
    -- Auto-create link from parent to child
    local link = Nodes.create_link("main", parent_node, parent_output_pin.id, 
                child, child_input_pin.id)
    
    -- Update pin connection fields (same as handle_link_created does)
    child_input_pin.connection = { node = parent_node.id, pin = parent_output_pin.id, link = link.id }
    if not parent_output_pin.connections then
        parent_output_pin.connections = {}
    end
    table.insert(parent_output_pin.connections, { node = child.id, pin = child_input_pin.id, link = link.id })
end

function Nodes.add_child_node_to_arg(parent_node, pin_index)
    -- Random Y offset between -150 and +150
    local random_y_offset = math.random(Constants.CHILD_NODE_RANDOM_Y_MIN, Constants.CHILD_NODE_RANDOM_Y_MAX)
    
    local BaseFollower = require("DevTester2.Followers.BaseFollower")
    local child = BaseFollower.create({
        x = parent_node.position.x + imnodes.get_node_dimensions(parent_node.id).x + Constants.CHILD_NODE_OFFSET_X,
        y = parent_node.position.y + random_y_offset
    })
    
    -- Find the arg output pin
    local arg_pin_index = pin_index
    
    if not parent_node.pins or not parent_node.pins.outputs or not parent_node.pins.outputs[arg_pin_index] then
        -- Ensure the arg output pin exists - get value from hook_arg_values if available
        -- Note: We can't easily infer the arg index from pin_index here without more context, 
        -- but usually the pin should already exist if we are clicking a button on it.
        Nodes.add_output_pin(parent_node, "Arg", nil)
    end
    local parent_arg_pin = parent_node.pins.outputs[arg_pin_index]
    
    -- Sync arg pin value with hook_arg_values if available
    -- Note: This sync logic was relying on arg_index. 
    -- Since we are passing pin_index, we might skip this explicit sync here 
    -- and rely on the render loop to keep it synced.
    
    -- Ensure child has input pin
    if not child.pins or not child.pins.inputs or #child.pins.inputs == 0 then
        Nodes.add_input_pin(child, "Parent", nil)
    end
    local child_input_pin = child.pins.inputs[1]
    
    -- Auto-create link from parent arg to child
    local link = Nodes.create_link("main", parent_node, parent_arg_pin.id, 
                child, child_input_pin.id)
    
    -- Update pin connection fields
    child_input_pin.connection = { node = parent_node.id, pin = parent_arg_pin.id, link = link.id }
    if not parent_arg_pin.connections then
        parent_arg_pin.connections = {}
    end
    table.insert(parent_arg_pin.connections, { node = child.id, pin = child_input_pin.id, link = link.id })
end

function Nodes.add_child_node_to_return(parent_node, pin_index)
    pin_index = pin_index or 1
    -- Random Y offset between -150 and +150
    local random_y_offset = math.random(Constants.CHILD_NODE_RANDOM_Y_MIN, Constants.CHILD_NODE_RANDOM_Y_MAX)
    
    local BaseFollower = require("DevTester2.Followers.BaseFollower")
    local child = BaseFollower.create({
        x = parent_node.position.x + imnodes.get_node_dimensions(parent_node.id).x + Constants.CHILD_NODE_OFFSET_X,
        y = parent_node.position.y + random_y_offset
    })
    
    -- Find the return output pin (usually first output pin)
    if not parent_node.pins or not parent_node.pins.outputs or #parent_node.pins.outputs < pin_index then
        -- Create return pin with return_value or actual_return_value if available
        local return_val = parent_node.return_value or parent_node.actual_return_value or nil
        Nodes.add_output_pin(parent_node, "Return", return_val)
    end
    local parent_return_pin = parent_node.pins.outputs[pin_index]
    
    -- Sync return pin value - check multiple possible value sources
    if parent_node.return_value then
        parent_return_pin.value = parent_node.return_value
    elseif parent_node.actual_return_value then
        parent_return_pin.value = parent_node.actual_return_value
    elseif parent_node.ending_value then
        parent_return_pin.value = parent_node.ending_value
    end
    
    -- Ensure child has input pin
    if not child.pins or not child.pins.inputs or #child.pins.inputs == 0 then
        Nodes.add_input_pin(child, "Parent", nil)
    end
    local child_input_pin = child.pins.inputs[1]
    
    -- Auto-create link from parent return to child
    local link = Nodes.create_link("main", parent_node, parent_return_pin.id, 
                child, child_input_pin.id)
    
    -- Update pin connection fields
    child_input_pin.connection = { node = parent_node.id, pin = parent_return_pin.id, link = link.id }
    if not parent_return_pin.connections then
        parent_return_pin.connections = {}
    end
    table.insert(parent_return_pin.connections, { node = child.id, pin = child_input_pin.id, link = link.id })
end




-- ========================================
-- Node Management
-- ========================================

function Nodes.remove_node(node)
    -- Remove connected links (this will disconnect children without deleting them)
    Nodes.remove_links_for_node(node)
    
    -- Remove from all_nodes list
    for i, n in ipairs(State.all_nodes) do
        if n.id == node.id then
            table.remove(State.all_nodes, i)
            break
        end
    end
    
    -- Remove from hash map
    State.node_map[node.id] = nil
    
    State.mark_as_modified()
    -- Reset node positioning state so nodes are repositioned after node removal
    if State.nodes_positioned then
        for k in pairs(State.nodes_positioned) do
            State.nodes_positioned[k] = nil
        end
    end
end

-- Backwards compatibility aliases
Nodes.remove_starter_node = Nodes.remove_node
Nodes.remove_operation_node = Nodes.remove_node

function Nodes.remove_links_for_node(node)
    -- Remove all links where the node being deleted is directly involved
    -- Use handle_link_destroyed to properly clean up connection references
    local i = 1
    while i <= #State.all_links do
        local link = State.all_links[i]
        if link.from_node == node.id or link.to_node == node.id then
            Nodes.handle_link_destroyed(link.id)
            -- Don't increment i since we removed an element
        else
            i = i + 1
        end
    end
end

function Nodes.remove_links_for_pin(pin_id)
    -- Remove all links connected to the specified pin
    -- Use handle_link_destroyed to properly clean up connection references
    local i = 1
    while i <= #State.all_links do
        local link = State.all_links[i]
        if link.from_pin == pin_id or link.to_pin == pin_id then
            Nodes.handle_link_destroyed(link.id)
            -- Don't increment i since we removed an element
        else
            i = i + 1
        end
    end
end

function Nodes.remove_child_nodes(parent_node)
    local children_to_remove = {}
    
    -- Find all nodes with input pins connected to this parent's output pins
    for i, node in ipairs(State.all_nodes) do
        if node.pins and node.pins.inputs and #node.pins.inputs > 0 then
            local main_input = node.pins.inputs[1]
            if main_input.connection and main_input.connection.node == parent_node.id then
                table.insert(children_to_remove, node)
            end
        end
    end
    
    for _, child in ipairs(children_to_remove) do
        Nodes.remove_node(child)
    end
end

function Nodes.has_children(node)
    -- Check if any node has its first input pin connected to this node's output
    for _, child in ipairs(State.all_nodes) do
        if child.pins and child.pins.inputs and #child.pins.inputs > 0 then
            local main_input = child.pins.inputs[1]
            if main_input.connection and main_input.connection.node == node.id then
                return true
            end
        end
    end
    return false
end

function Nodes.get_node_count()
    return #State.all_nodes
end

function Nodes.clear_all_nodes()
    
    State.reset_nodes()
    State.reset_links()
    
    -- Clear hash maps
    State.reset_maps()
    
    -- Reset ID counters
    State.reset_id_counters()
    
    -- Reset node positioning state
    State.reset_positioning()

    -- Reset variables
    State.reset_variables()
end

-- ========================================
-- Link Management
-- ========================================

function Nodes.create_link(connection_type, from_node, from_pin, to_node, to_pin)
    local link = {
        id = State.next_link_id(),
        connection_type = connection_type, -- "main" or "parameter" or "value"
        from_node = from_node.id,
        from_pin = from_pin,
        to_node = to_node.id,
        to_pin = to_pin,
        parameter_index = nil,
        field_name = nil
    }
    
    table.insert(State.all_links, link)
    State.link_map[link.id] = link  -- Add to hash map
    State.mark_as_modified()
    return link
end

function Nodes.handle_link_created(start_pin, end_pin)
    -- Find nodes containing these pins
    local from_node, from_pin_type = Nodes.find_node_by_pin(start_pin)
    local to_node, to_pin_type = Nodes.find_node_by_pin(end_pin)
    if not from_node or not to_node then
        return
    end

    -- Check for existing connections to this input and remove them
    for i = #State.all_links, 1, -1 do
        local link = State.all_links[i]
        if link.to_node == to_node.id and link.to_pin == end_pin then
            -- Remove the existing link
            Nodes.handle_link_destroyed(link.id)
            break -- Only remove one link since inputs should only have one connection
        end
    end

    -- Create link and update pin connections
    local connection_type = to_pin_type or "generic"
    local link = Nodes.create_link(connection_type, from_node, start_pin, to_node, end_pin)
    
    -- Update pin connection fields
    local from_pin_info = State.pin_map[start_pin]
    local to_pin_info = State.pin_map[end_pin]
    
    if to_pin_info and to_pin_info.pin then
        to_pin_info.pin.connection = { node = from_node.id, pin = start_pin, link = link.id }
    end
    
    if from_pin_info and from_pin_info.pin then
        if not from_pin_info.pin.connections then
            from_pin_info.pin.connections = {}
        end
        table.insert(from_pin_info.pin.connections, { node = to_node.id, pin = end_pin, link = link.id })
    end
    
    -- Handle special cases that need extra tracking
    if to_pin_type == "param_input" then
        local param_index = Nodes.get_param_index_from_pin(to_node, end_pin)
        link.parameter_index = param_index
    end
end

function Nodes.handle_link_destroyed(link_id)
    -- Use the disconnect helper which handles pin.connection cleanup
    Nodes.disconnect_link(link_id)
    
    -- No additional cleanup needed - pins handle all connection tracking
    for i, link in ipairs(State.all_links) do
        if link.id == link_id then
            table.remove(State.all_links, i)
            State.link_map[link_id] = nil
            State.mark_as_modified()
            break
        end
    end
end

function Nodes.find_node_by_pin(pin_id)
    -- Search all nodes for matching pin
    for _, node in ipairs(State.all_nodes) do
        if node.pins then
            -- Check input pins
            if node.pins.inputs then
                for _, pin in ipairs(node.pins.inputs) do
                    if pin.id == pin_id then
                        return node, "input"
                    end
                end
            end
            -- Check output pins
            if node.pins.outputs then
                for _, pin in ipairs(node.pins.outputs) do
                    if pin.id == pin_id then
                        return node, "output"
                    end
                end
            end
        end
    end
    
    return nil, nil
end

function Nodes.find_node_by_id(node_id)
    return State.node_map[node_id]
end

function Nodes.get_link_by_id(link_id)
    return State.link_map[link_id]
end

-- ========================================
-- Connection Utilities
-- ========================================

-- Get the source output pin that a given input pin is connected to
-- Returns the from_pin (output pin ID) that the specified input pin is connected to, or nil if not connected
function Nodes.get_connected_output_pin(to_node_id, to_pin_attr)
    for _, link in ipairs(State.all_links) do
        if link.to_node == to_node_id and link.to_pin == to_pin_attr then
            return link.from_pin
        end
    end
    return nil
end

-- ========================================
-- Value Resolution
-- ========================================

function Nodes.get_parent_value(node)
    -- Get the first input pin (main parent connection)
    if not node.pins or not node.pins.inputs or #node.pins.inputs == 0 then
        return nil
    end
    
    local input_pin = node.pins.inputs[1]
    
    -- Check if this pin has a connection
    if not input_pin.connection then
        return nil
    end
    
    -- Look up the connected node and pin
    local parent_node = Nodes.find_node_by_id(input_pin.connection.node)
    if not parent_node then
        return nil
    end
    
    -- Find the output pin that's connected
    local output_pin_info = State.pin_map[input_pin.connection.pin]
    if output_pin_info and output_pin_info.pin then
        return output_pin_info.pin.value
    end
    
    -- No valid pin found
    return nil
end

function Nodes.get_pin_value(pin_id)
    if not pin_id then
        return nil
    end
    
    -- Find the link that connects to this pin
    for _, link in ipairs(State.all_links) do
        if link.to_pin == pin_id then
            -- Found a link to this pin, get the value from the source node
            local source_node = Nodes.find_node_by_id(link.from_node)
            if source_node then
                -- Get value from the source pin
                local from_pin = State.pin_map[link.from_pin]
                if from_pin and from_pin.pin then
                    return from_pin.pin.value
                end
            end
            break
        end
    end
    
    -- No connection found, check if the pin itself has a value stored
    local pin = State.pin_map[pin_id]
    if pin then
        return pin.value
    end
    
    return nil
end

-- Generic pin-based value retrieval
function Nodes.get_input_pin_value(node, pin_index)
    if type(pin_index) ~= "number" then
        return nil
    end
    
    local pin = node.pins.inputs[pin_index]
    
    if not pin then
        return nil
    end
    
    -- If pin has a connection, get value from source
    if pin.connection then
        local source_pin_info = State.pin_map[pin.connection.pin]
        if source_pin_info then
            local source_pin = source_pin_info.pin
            return source_pin.value
        end
    end
    
    -- No connection, return manual value
    return pin.value
end

function Nodes.is_output_connected(node)
    -- Check if any of the node's output pins have connections
    if not node.pins or not node.pins.outputs then
        return false
    end
    
    for _, output_pin in ipairs(node.pins.outputs) do
        for _, link in ipairs(State.all_links) do
            if link.from_node == node.id and link.from_pin == output_pin.id then
                return true
            end
        end
    end
    
    return false
end

-- ========================================
-- Cache Management
-- ========================================

function Nodes.get_cache_size(cache)
    local count = 0
    for _ in pairs(cache) do
        count = count + 1
    end
    return count
end

function Nodes.cleanup_cache(cache, max_size)
    if Nodes.get_cache_size(cache) <= max_size then
        return
    end
    
    -- Remove oldest entries (simple LRU approximation)
    local to_remove = {}
    local current_time = os.time()
    
    for key, entry in pairs(cache) do
        if entry.last_accessed and (current_time - entry.last_accessed) > Constants.MEMORY_CLEANUP_AGE_SECONDS then
            table.insert(to_remove, key)
        end
    end
    
    for _, key in ipairs(to_remove) do
        cache[key] = nil
    end
    
    -- If still too big, remove more aggressively
    if Nodes.get_cache_size(cache) > max_size then
        local keys = {}
        for key in pairs(cache) do
            table.insert(keys, key)
        end
        
        -- Remove half of the remaining entries
        local remove_count = math.floor(#keys / 2)
        for i = 1, remove_count do
            cache[keys[i]] = nil
        end
    end
end

function Nodes.get_cached_type_info(type_def, is_static_context)
    local type_name = type_def:get_full_name() .. (is_static_context and "_static" or "_instance")
    
    if not State.type_cache[type_name] then
        State.type_cache[type_name] = {
            methods = Nodes.build_method_list(type_def, is_static_context),
            fields = Nodes.build_field_list(type_def, is_static_context),
            last_accessed = os.time()
        }
        
        Nodes.cleanup_cache(State.type_cache, Constants.TYPE_CACHE_SIZE_LIMIT)
    else
        State.type_cache[type_name].last_accessed = os.time()
    end
    
    return State.type_cache[type_name]
end

function Nodes.build_method_list(type_def, is_static_context)
    local methods = {}
    
    -- Walk inheritance chain and get methods from each type
    local current_type = type_def
    local level = 1
    
    while current_type do
        local success, type_methods = pcall(function() 
            if is_static_context then
                return current_type:get_methods(true)  -- true = include static methods
            else
                return current_type:get_methods() 
            end
        end)
        if not success or not type_methods then
            break
        end
        
        -- Get class name (get_name returns short name, better for generics)
        local short_name = current_type:get_name()
        
        -- Add class separator
        table.insert(methods, {
            type = "separator",
            display = "\n" .. short_name,
            level = level
        })
        
        -- Add methods for this class
        for method_idx, method in ipairs(type_methods) do
            local name = method:get_name()
            local return_type = method:get_return_type()
            local return_name = return_type and Utils.get_type_display_name(return_type) or "Void"
            
            -- Build parameter type list using get_param_types()
            local param_type_names = {}
            local success_params, param_types = pcall(function()
                return method:get_param_types()
            end)
            
            if success_params and param_types then
                for _, param_type in ipairs(param_types) do
                    table.insert(param_type_names, param_type:get_name())
                end
            end
            
            local params_str = table.concat(param_type_names, ", ")
            
            -- Format: classLevel-methodIndex. methodName(params) | returnType
            local display = string.format("%d-%d. %s(%s) | %s", 
                level, method_idx, name, params_str, return_name)
            
            table.insert(methods, {
                type = "method",
                display = display,
                method = method,
                level = level,
                index = method_idx
            })
        end
        
        -- Move to parent type
        level = level + 1
        local success_parent, parent = pcall(function() return current_type:get_parent_type() end)
        if success_parent and parent then
            current_type = parent
        else
            break
        end
    end
    
    return methods
end

function Nodes.build_field_list(type_def, is_static_context)
    local fields = {}
    
    -- Walk inheritance chain and get fields from each type
    local current_type = type_def
    local level = 1
    
    while current_type do
        local success, type_fields = pcall(function() 
            if is_static_context then
                return current_type:get_fields(true)  -- true = include static fields
            else
                return current_type:get_fields() 
            end
        end)
        if not success or not type_fields then
            break
        end
        
        -- Get class name (get_name returns short name, better for generics)
        local short_name = current_type:get_name()
        
        -- Add class separator
        table.insert(fields, {
            type = "separator",
            display = "\n" .. short_name,
            level = level
        })
        
        -- Add fields for this class
        for field_idx, field in ipairs(type_fields) do
            local name = field:get_name()
            local field_type = field:get_type()
            local type_name = Utils.get_type_display_name(field_type)
            
            -- Format: classLevel-fieldIndex. fieldName | type
            local display = string.format("%d-%d. %s | %s", 
                level, field_idx, name, type_name)
            
            table.insert(fields, {
                type = "field",
                display = display,
                field = field,
                level = level,
                index = field_idx
            })
        end
        
        -- Move to parent type
        level = level + 1
        local success_parent, parent = pcall(function() return current_type:get_parent_type() end)
        if success_parent and parent then
            current_type = parent
        else
            break
        end
    end
    
    return fields
end

-- ========================================
-- Signature Generation & Matching
-- ========================================

function Nodes.get_method_signature(method, dont_include_type_def)
    local type_name = method:get_declaring_type():get_full_name()
    local name = method:get_name()
    local param_types = {}
    
    local success, params = pcall(function() return method:get_param_types() end)
    if success and params then
        for i, p in ipairs(params) do
            table.insert(param_types, p:get_full_name())
        end
    end

    if dont_include_type_def then
        return name .. "(" .. table.concat(param_types, ", ") .. ")"
    else
        return type_name .. ":" .. name .. "(" .. table.concat(param_types, ", ") .. ")"
    end
end

function Nodes.get_field_signature(field, dont_include_type_def)
    local type_name = field:get_declaring_type():get_full_name()
    if dont_include_type_def then
        return field:get_name()
    else
        return type_name .. ":" .. field:get_name()
    end
end

function Nodes.find_method_indices_by_signature(type_def, signature, is_static_context)
    local type_info = Nodes.get_cached_type_info(type_def, is_static_context)
    for _, item in ipairs(type_info.methods) do
        if item.type == "method" then
             if Nodes.get_method_signature(item.method) == signature then
                 return item.level, item.index
             end
        end
    end
    return nil, nil
end

function Nodes.find_field_indices_by_signature(type_def, signature, is_static_context)
    local type_info = Nodes.get_cached_type_info(type_def, is_static_context)
    for _, item in ipairs(type_info.fields) do
        if item.type == "field" then
             if Nodes.get_field_signature(item.field) == signature then
                 return item.level, item.index
             end
        end
    end
    return nil, nil
end

function Nodes.get_methods_for_combo(type_def, is_static_context)
    local cache_key = type_def:get_full_name() .. (is_static_context and "_static" or "_instance")
    
    if not State.combo_cache[cache_key] then
        local type_info = Nodes.get_cached_type_info(type_def, is_static_context)
        local combo_items = {""}  -- Start with empty item
        
        for _, item in ipairs(type_info.methods) do
            table.insert(combo_items, item.display)
        end
        
        State.combo_cache[cache_key] = combo_items
        Nodes.cleanup_cache(State.combo_cache, Constants.COMBO_CACHE_SIZE_LIMIT)
    end
    
    return State.combo_cache[cache_key]
end

function Nodes.get_method_by_group_and_index(type_def, group_index, method_index, is_static_context)
    local type_info = Nodes.get_cached_type_info(type_def, is_static_context)
    
    for _, item in ipairs(type_info.methods) do
        if item.type == "method" and item.level == group_index and item.index == method_index then
            return item.method
        end
    end
    
    return nil
end

function Nodes.get_method_from_combo_index(type_def, combo_index)
    local combo_items = Nodes.get_methods_for_combo(type_def)
    
    -- combo_index is 0-based, but combo_items is 1-based array
    local item_index = combo_index + 1
    
    if item_index < 1 or item_index > #combo_items then
        return nil
    end
    
    local combo_item = combo_items[item_index]
    
    -- Parse the format: "level-methodIndex. methodName(params) | returnType"
    local level, method_idx = combo_item:match("^(%d+)%-(%d+)%. ")
    
    if level and method_idx then
        return Nodes.get_method_by_group_and_index(type_def, tonumber(level), tonumber(method_idx))
    end
    
    return nil
end

function Nodes.get_combo_index_for_method(type_def, group_index, method_index, is_static_context)
    local combo_items = Nodes.get_methods_for_combo(type_def, is_static_context)
    local prefix = string.format("%d-%d. ", group_index, method_index)
    
    for i, item in ipairs(combo_items) do
        if item:sub(1, #prefix) == prefix then
            return i - 1 -- Return 0-based index for imgui
        end
    end
    return 0 -- Default to empty
end

function Nodes.get_fields_for_combo(type_def, is_static_context)
    local cache_key = type_def:get_full_name() .. (is_static_context and "_static" or "_instance") .. "_fields"
    
    if not State.combo_cache[cache_key] then
        local type_info = Nodes.get_cached_type_info(type_def, is_static_context)
        local combo_items = {""}  -- Start with empty item
        
        for _, item in ipairs(type_info.fields) do
            table.insert(combo_items, item.display)
        end
        
        State.combo_cache[cache_key] = combo_items
        Nodes.cleanup_cache(State.combo_cache, Constants.COMBO_CACHE_SIZE_LIMIT)
    end
    
    return State.combo_cache[cache_key]
end

function Nodes.get_field_by_group_and_index(type_def, group_index, field_index, is_static_context)
    local type_info = Nodes.get_cached_type_info(type_def, is_static_context)
    
    for _, item in ipairs(type_info.fields) do
        if item.type == "field" and item.level == group_index and item.index == field_index then
            return item.field
        end
    end
    
    return nil
end

function Nodes.get_field_from_combo_index(type_def, combo_index)
    local combo_items = Nodes.get_fields_for_combo(type_def)
    
    -- combo_index is 0-based, but combo_items is 1-based array
    local item_index = combo_index + 1
    
    if item_index < 1 or item_index > #combo_items then
        return nil
    end
    
    local combo_item = combo_items[item_index]
    
    -- Parse the format: "level-fieldIndex. fieldName | type"
    local level, field_idx = combo_item:match("^(%d+)%-(%d+)%. ")
    
    if level and field_idx then
        return Nodes.get_field_by_group_and_index(type_def, tonumber(level), tonumber(field_idx))
    end
    
    return nil
end

function Nodes.get_combo_index_for_field(type_def, group_index, field_index, is_static_context)
    local combo_items = Nodes.get_fields_for_combo(type_def, is_static_context)
    local prefix = string.format("%d-%d. ", group_index, field_index)
    
    for i, item in ipairs(combo_items) do
        if item:sub(1, #prefix) == prefix then
            return i - 1 -- Return 0-based index for imgui
        end
    end
    return 0 -- Default to empty
end

function Nodes.ensure_node_pin_ids(node)
    -- Initialize pin arrays if they don't exist
    if not node.pins then
        node.pins = {inputs = {}, outputs = {}}
    end
    if not node.pins.inputs then
        node.pins.inputs = {}
    end
    if not node.pins.outputs then
        node.pins.outputs = {}
    end
    
    -- Ensure at least one input pin exists (for parent connection)
    if #node.pins.inputs == 0 then
        Nodes.add_input_pin(node, "Parent", nil)
    end
    
    -- Ensure output pin exists for nodes that should have one
    if #node.pins.outputs == 0 and node.category ~= Constants.CATEGORY_CONTROL then
        Nodes.add_output_pin(node, "Output", nil)
    end
    
    -- Note: Parameter pins, value pins, and index pins are created dynamically
    -- by their respective node types during rendering
end

function Nodes.validate_and_restore_starter_node(node)
    if node.category == Constants.NODE_CATEGORY_STARTER then
        if node.type == Constants.STARTER_TYPE_MANAGED then
            if node.path and node.path ~= "" then
                local managed_obj = sdk.get_managed_singleton(node.path)
                if managed_obj then
                    node.ending_value = managed_obj
                    node.status = "Success"
                else
                    node.status = "Managed singleton not found"
                end
            end
        elseif node.type == Constants.STARTER_TYPE_HOOK then
            -- Hooks need to be re-initialized manually
            node.status = "Requires re-initialization"
            -- Create placeholder pins for hooks that were previously initialized
            if node.method_name and node.method_name ~= "" then
                Nodes.ensure_node_pin_ids(node)
            end
        elseif node.type == Constants.STARTER_TYPE_NATIVE then
            -- Native nodes need to be re-initialized manually
            node.status = "Requires re-initialization"
            -- Create placeholder pins for native starters that were previously executed
            if node.method_name and node.method_name ~= "" then
                Nodes.ensure_node_pin_ids(node)
            end
        elseif node.type == Constants.STARTER_TYPE_TYPE then
            if node.path and node.path ~= "" then
                local success, type_def = pcall(function() return sdk.find_type_definition(node.path) end)
                if success and type_def then
                    node.ending_value = type_def
                    node.status = "Success"
                else
                    node.status = "Type not found"
                end
            end
        end
    elseif node.category == Constants.NODE_CATEGORY_DATA then
        if node.type == Constants.DATA_TYPE_ENUM then
            -- Ensure pins exist for enum nodes
            Nodes.ensure_node_pin_ids(node)
        elseif node.type == Constants.DATA_TYPE_PRIMITIVE then
            -- Restore the value as ending_value
            node.ending_value = Utils.parse_primitive_value(node.value)
            node.status = "Ready"
        elseif node.type == Constants.DATA_TYPE_VARIABLE then
            -- For variables, ending_value will be determined by the VariableData.get_variable_value function
            node.ending_value = nil  -- Will be set during execution
            node.status = "Ready"
        end
    elseif node.category == Constants.NODE_CATEGORY_UTILITY then
        if node.type == Constants.UTILITY_TYPE_LABEL then
            -- Label nodes are ready to use immediately
            node.status = "Ready"
        elseif node.type == Constants.UTILITY_TYPE_HISTORY_BUFFER then
            -- History buffer nodes need pins
            if #node.pins.inputs == 0 then
                Nodes.add_input_pin(node, "input", nil)
            end
            if #node.pins.outputs == 0 then
                Nodes.add_output_pin(node, "output", nil)
            end
            node.status = "Ready"
        end
    end
end

-- ========================================
-- Pin Helper APIs
-- ========================================

function Nodes.create_pin(name, value)
    local pin = {
        id = State.next_pin_id(),
        name = name,
        value = value
    }
    return pin
end

function Nodes.add_input_pin(node, name, value)
    local pin = Nodes.create_pin(name, value)
    pin.connection = nil
    table.insert(node.pins.inputs, pin)
    State.pin_map[pin.id] = { node_id = node.id, pin = pin }
    return pin
end

function Nodes.add_output_pin(node, name, value)
    local pin = Nodes.create_pin(name, value)
    pin.connections = {}
    table.insert(node.pins.outputs, pin)
    State.pin_map[pin.id] = { node_id = node.id, pin = pin }
    return pin
end

function Nodes.find_pin_by_id(pin_id)
    return State.pin_map[pin_id]
end

function Nodes.find_pin_by_name(node, side, name)
    local pins = (side == "inputs") and node.pins.inputs or node.pins.outputs
    for i, pin in ipairs(pins) do
        if pin.name == name then
            return pin, i
        end
    end
    return nil
end

function Nodes.connect_pins(from_pin_id, to_pin_id)
    local from_info = State.pin_map[from_pin_id]
    local to_info = State.pin_map[to_pin_id]
    if not from_info or not to_info then return nil end
    
    local from_node = State.node_map[from_info.node_id]
    local to_node = State.node_map[to_info.node_id]
    local from_pin = from_info.pin
    local to_pin = to_info.pin
    
    local link = {
        id = State.next_link_id(),
        from_node = from_node.id,
        from_pin = from_pin.id,
        to_node = to_node.id,
        to_pin = to_pin.id
    }
    
    table.insert(State.all_links, link)
    State.link_map[link.id] = link
    
    to_pin.connection = { node = from_node.id, pin = from_pin.id, link = link.id }
    table.insert(from_pin.connections, { node = to_node.id, pin = to_pin.id, link = link.id })
    
    return link
end

function Nodes.disconnect_link(link_id)
    local link = State.link_map[link_id]
    if not link then return end
    
    local from_info = State.pin_map[link.from_pin]
    local to_info = State.pin_map[link.to_pin]
    
    if to_info and to_info.pin.connection and to_info.pin.connection.link == link_id then
        to_info.pin.connection = nil
    end
    
    if from_info then
        for i = #from_info.pin.connections, 1, -1 do
            if from_info.pin.connections[i].link == link_id then
                table.remove(from_info.pin.connections, i)
            end
        end
    end
    
    for i = #State.all_links, 1, -1 do
        if State.all_links[i].id == link_id then
            table.remove(State.all_links, i)
        end
    end
    State.link_map[link_id] = nil
end

-- ========================================
-- Context Menu Helpers
-- ========================================
function Nodes.add_context_menu_option(node, label, data)
    -- Accumulate options for the whole node context menu
    if not node._frame_context_options then
        node._frame_context_options = {}
    end

    table.insert(node._frame_context_options, { label = label, data = data })
end

function Nodes.add_context_menu_seperator(node)
    -- Accumulate options for the whole node context menu
    if not node._frame_context_options then
        node._frame_context_options = {}
    end

    table.insert(node._frame_context_options, { label = "---separator---", data = nil })
end

function Nodes.render_context_menu(node)
    
    -- Have to use selected nodes since imnodes.is_node_hovered() doesn't accept a node ID
    if imnodes.get_selected_nodes()[1] == node.id and imgui.is_mouse_clicked(1) and (node._frame_context_options and #node._frame_context_options > 0) then
        imgui.open_popup("NodeContextMenu_" .. node.id)
    end

    if imgui.begin_popup("NodeContextMenu_" .. node.id) then
        if node._frame_context_options and #node._frame_context_options > 0 then
            for _, option in ipairs(node._frame_context_options) do
                -- Display label with data preview to distinguish similar options
                local display_label = option.label

                if option.label == "---separator---" then
                    imgui.separator()
                    goto continue
                end
                
                if imgui.menu_item(display_label) then
                    if type(option.data) == "function" then
                        option.data()
                    else
                        sdk.copy_to_clipboard(tostring(option.data))
                    end
                end

                ::continue::
            end
        end
        imgui.end_popup()
    end
    
    -- Clear options for the next frame
    node._frame_context_options = nil
end

-- ========================================
-- Copy/Paste Functions
-- ========================================

-- Copy selected nodes to clipboard
function Nodes.copy_selected_nodes()
    -- Get selected nodes from imnodes
        
    local selected_ids = {}
    for _, selected_id in ipairs(imnodes.get_selected_nodes()) do
        table.insert(selected_ids, selected_id)
    end
    
    -- Clear clipboard
    State.clipboard.nodes = {}
    State.clipboard.links = {}
    
    -- Copy selected nodes
    for _, node_id in ipairs(selected_ids) do
        local node = State.node_map[node_id]
        if node then
            local node_copy = Utils.deep_copy_node(node)
            table.insert(State.clipboard.nodes, node_copy)
        end
    end
    
    -- Copy input links (links ending at selected nodes)
    for _, link in ipairs(State.all_links) do
        -- Check if link ends at a selected node
        local is_end_selected = false
        for _, node_id in ipairs(selected_ids) do
            if link.to_node == node_id then
                is_end_selected = true
                break
            end
        end
        
        if is_end_selected then
            local link_copy = Utils.deep_copy_node(link)
            table.insert(State.clipboard.links, link_copy)
        end
    end
end

-- Paste nodes from clipboard
function Nodes.paste_nodes()
    if #State.clipboard.nodes == 0 then
        return
    end
    
    -- Fixed offset for pasted nodes
    local offset_x = 50
    local offset_y = 50
    
    -- Create ID mapping table
    local id_map = {
        nodes = {},  -- old_node_id -> new_node_id
        pins = {}    -- old_pin_id -> new_pin_id
    }
    
    -- Track pasted node IDs (old IDs) for link filtering
    local pasted_node_ids = {}
    for _, node in ipairs(State.clipboard.nodes) do
        pasted_node_ids[node.id] = true
    end
    
    -- Paste nodes with new IDs
    local pasted_nodes = {}
    for _, clipboard_node in ipairs(State.clipboard.nodes) do
        local node = Utils.deep_copy_node(clipboard_node)
        
        -- Generate new IDs and build mapping
        Utils.generate_new_node_ids(node, id_map)
        
        -- Apply fixed offset
        node.position = node.position or {x = 0, y = 0}
        node.position.x = node.position.x + offset_x
        node.position.y = node.position.y + offset_y
        
        -- Add to state
        table.insert(State.all_nodes, node)
        State.node_map[node.id] = node
        
        -- Register pins in pin_map
        if node.pins then
            if node.pins.inputs then
                for _, pin in ipairs(node.pins.inputs) do
                    State.pin_map[pin.id] = { node_id = node.id, pin = pin }
                end
            end
            if node.pins.outputs then
                for _, pin in ipairs(node.pins.outputs) do
                    State.pin_map[pin.id] = { node_id = node.id, pin = pin }
                end
            end
        end
        
        table.insert(pasted_nodes, node)
    end
    
    -- Paste ALL links (both internal and external)
    for _, clipboard_link in ipairs(State.clipboard.links) do
        local link = Utils.deep_copy_node(clipboard_link)
        Utils.remap_link_ids(link, id_map)
        table.insert(State.all_links, link)
        State.link_map[link.id] = link
        
        -- Update pin connections for the new pins
        local from_pin_info = State.pin_map[link.from_pin]
        local to_pin_info = State.pin_map[link.to_pin]
        
        if to_pin_info and to_pin_info.pin then
            to_pin_info.pin.connection = { node = link.from_node, pin = link.from_pin, link = link.id }
        end
        
        if from_pin_info and from_pin_info.pin then
            if not from_pin_info.pin.connections then
                from_pin_info.pin.connections = {}
            end
            table.insert(from_pin_info.pin.connections, { node = link.to_node, pin = link.to_pin, link = link.id })
        end
    end
    
    State.mark_as_modified()
end

return Nodes
