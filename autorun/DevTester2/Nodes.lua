-- DevTester v2.0 - Node Rendering
-- Rendering functions for all node types

local State = require("DevTester2.State")
local Constants = require("DevTester2.Constants")
local Utils = require("DevTester2.Utils")

local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local Nodes = {}

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
    return Constants.COLOR_NODE_DEFAULT
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
    node.param_connections = {}
    node.param_input_attrs = {}
    
    -- Clear field-specific data
    node.selected_field_combo = 1
    node.field_group_index = nil
    node.field_index = nil
    node.value_manual_input = ""
    node.value_connection = nil
    node.value_input_attr = nil
    node.action_type = Constants.ACTION_GET -- Reset to default action
    
    -- Clear array-specific data
    node.selected_element_index = 0
    
    -- Clear common data that might be operation-specific
    node.starting_value = nil
    node.ending_value = nil
    node.status = nil
end

-- ========================================
-- Node Creation Functions
-- ========================================

function Nodes.create_starter_node(category, node_type)
    local node_id = State.next_node_id()

    local node = {
        id = node_id,
        node_id = node_id,
        category = category,
        type = node_type,
        path = "",
        position = {x = 50, y = 50},
        ending_value = nil,
        status = nil,
        output_attr = nil,
        -- Parameter support for starters that need it (like Native)
        param_connections = {},
        param_input_attrs = {},
        param_manual_values = {},
        -- Enum-specific
        selected_enum_index = 1,
        enum_names = nil,
        enum_values = nil,
        -- Hook-specific
        method_name = "",
        hook_id = nil,
        is_initialized = false
    }
    
    if category == Constants.NODE_CATEGORY_DATA then
        table.insert(State.data_nodes, node)
    else
        table.insert(State.starter_nodes, node)
    end
    State.node_map[node_id] = node  -- Add to hash map
    State.mark_as_modified()
    return node
end

function Nodes.create_follower_node(position)
    local node_id = State.next_node_id()
    local node = {
        id = node_id,
        node_id = node_id,
        category = Constants.NODE_CATEGORY_FOLLOWER,
        type = Constants.FOLLOWER_TYPE_METHOD, -- Default to Method
        position = position or {x = 0, y = 0},
        parent_node_id = nil,
        -- Method-specific
        selected_method_combo = 1, -- 1-based indexing for combo
        method_group_index = nil, -- Parsed from selection
        method_index = nil, -- Parsed from selection
        param_manual_values = {},
        param_connections = {},
        param_input_attrs = {},
        -- Field-specific
        selected_field_combo = 1, -- 1-based indexing for combo
        field_group_index = nil, -- Parsed from selection
        field_index = nil, -- Parsed from selection
        value_manual_input = "",
        value_connection = nil,
        value_input_attr = nil,
        -- Array-specific
        selected_element_index = 0,
        -- Common
        starting_value = nil,
        ending_value = nil,
        status = nil,
        input_attr = nil,
        output_attr = nil
    }
    
    table.insert(State.all_nodes, node)
    State.node_map[node_id] = node  -- Add to hash map
    State.mark_as_modified()
    return node
end

function Nodes.create_operations_node(category, node_type)
    local node_id = State.next_node_id()

    local node = {
        id = node_id,
        node_id = node_id,
        category = category,
        type = node_type,
        path = "",
        position = {x = 50, y = 50},
        ending_value = nil,
        status = nil,
        output_attr = State.next_pin_id(),
        input_attr = nil,
    }

    -- Operations-specific fields
    if category == Constants.NODE_CATEGORY_OPERATIONS then
        node.input1_attr = State.next_pin_id()
        node.input2_attr = State.next_pin_id()
        node.selected_operation = 0
        node.input1_connection = nil
        node.input2_connection = nil
        node.input1_manual_value = ""
        node.input2_manual_value = ""
    -- Control-specific fields
    elseif category == Constants.NODE_CATEGORY_CONTROL then
        node.condition_attr = State.next_pin_id()
        node.true_attr = State.next_pin_id()
        node.false_attr = State.next_pin_id()
        node.condition_connection = nil
        node.true_connection = nil
        node.false_connection = nil
        node.condition_manual_value = ""
        node.true_manual_value = ""
        node.false_manual_value = ""
    end

    table.insert(State.all_nodes, node)
    State.node_map[node_id] = node  -- Add to hash map
    State.mark_as_modified()
    return node
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
    imnodes.begin_input_attribute(node.input_attr)
    
    local operation_name = Utils.parse_category_and_type(node.category, node.type)
    imgui.text(operation_name .. " (Disconnected)")
    
    imnodes.end_input_attribute()
    imnodes.end_node_titlebar()
end

function Nodes.render_disconnected_message(reason)
    local message = Nodes.get_disconnection_message(reason)
    imgui.text_colored(message, Constants.COLOR_TEXT_WARNING)
    imgui.spacing()
end

function Nodes.render_disconnected_attributes(node)
    -- Output attribute - always render if it exists (from config or created)
    if node.output_attr then
        imnodes.begin_output_attribute(node.output_attr)
        imgui.text("Output (Disconnected)")
        imnodes.end_output_attribute()
    end

    -- Parameter input attributes (placeholders)
    if node.param_manual_values then
        for i = 1, #node.param_manual_values do
            local param_pin_id = Nodes.get_param_pin_id(node, i)
            imnodes.begin_input_attribute(param_pin_id)
            imgui.text(string.format("Param %d (Disconnected)", i))
            imnodes.end_input_attribute()
        end
    end

    -- Field value input attribute for Set operations
    if node.type == Constants.FOLLOWER_TYPE_FIELD and node.action_type == Constants.ACTION_SET then
        imnodes.begin_input_attribute(node.value_input_attr)
        imgui.text("Value (Disconnected)")
        imnodes.end_input_attribute()
    end
end

function Nodes.render_disconnected_operation_node(node, reason)
    -- Ensure all pin IDs exist before rendering
    Nodes.ensure_node_pin_ids(node)
    
    imnodes.begin_node(node.node_id)
    
    Nodes.render_disconnected_titlebar(node, reason)
    Nodes.render_disconnected_message(reason)
    Nodes.render_disconnected_attributes(node)
    
    if imgui.button("- Remove Node") then
        Nodes.remove_operation_node(node)
    end
    
    imnodes.end_node()
end

function Nodes.render_disconnected_debug_info(node)
    -- Collect all input attributes (main + params)
    local input_attrs = {}
    if node.input_attr then table.insert(input_attrs, tostring(node.input_attr)) end
    if node.param_manual_values then
        for i = 1, #(node.param_manual_values) do
            local param_pin_id = Nodes.get_param_pin_id(node, i)
            if param_pin_id then table.insert(input_attrs, tostring(param_pin_id)) end
        end
    end
    
    -- Find input and output links, showing pin/attr and link id
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
        "Node ID: %s\nInput Attrs: %s\nOutput Attr: %s\nInput Links: %s\nOutput Links: %s",
        tostring(node.node_id),
        #input_attrs > 0 and table.concat(input_attrs, ", ") or "None",
        tostring(node.output_attr or "None"),
        #input_links > 0 and table.concat(input_links, ", ") or "None",
        #output_links > 0 and table.concat(output_links, ", ") or "None"
    )
    
    -- Align debug info to the top right of the node
    local pos_for_debug = Utils.get_top_right_cursor_pos(node.node_id, "[?]")
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
    
    local child = Nodes.create_follower_node({
        x = parent_node.position.x + imnodes.get_node_dimensions(parent_node.node_id).x + Constants.CHILD_NODE_OFFSET_X,
        y = parent_node.position.y + random_y_offset
    })
    child.parent_node_id = parent_node.id
    
    -- Auto-detect if parent value is an array and set type to Array
    if parent_node.ending_value then
        if Utils.is_array(parent_node.ending_value) then
            child.type = Constants.FOLLOWER_TYPE_ARRAY
        end
    end
    
    -- Ensure parent has output attribute
    if not parent_node.output_attr then
        parent_node.output_attr = State.next_pin_id()
    end
    
    -- Ensure child has input attribute
    if not child.input_attr then
        child.input_attr = State.next_pin_id()
    end
    
    -- Auto-create link from parent to child
    Nodes.create_link("main", parent_node, parent_node.output_attr, 
                child, child.input_attr)
end

function Nodes.add_child_node_to_arg(parent_node, arg_index)
    -- Random Y offset between -150 and +150
    local random_y_offset = math.random(Constants.CHILD_NODE_RANDOM_Y_MIN, Constants.CHILD_NODE_RANDOM_Y_MAX)
    
    local child = Nodes.create_follower_node({
        x = parent_node.position.x + imnodes.get_node_dimensions(parent_node.node_id).x + Constants.CHILD_NODE_OFFSET_X,
        y = parent_node.position.y + random_y_offset
    })
    child.parent_node_id = parent_node.id
    
    -- Ensure parent has the specific arg output attribute
    if not parent_node.hook_arg_attrs or not parent_node.hook_arg_attrs[arg_index] then
        if not parent_node.hook_arg_attrs then
            parent_node.hook_arg_attrs = {}
        end
        parent_node.hook_arg_attrs[arg_index] = State.next_pin_id()
    end
    
    -- Ensure child has input attribute
    if not child.input_attr then
        child.input_attr = State.next_pin_id()
    end
    
    -- Auto-create link from parent arg to child
    Nodes.create_link("main", parent_node, parent_node.hook_arg_attrs[arg_index], 
                child, child.input_attr)
end

function Nodes.add_child_node_to_return(parent_node)
    -- Random Y offset between -150 and +150
    local random_y_offset = math.random(Constants.CHILD_NODE_RANDOM_Y_MIN, Constants.CHILD_NODE_RANDOM_Y_MAX)
    
    local child = Nodes.create_follower_node({
        x = parent_node.position.x + imnodes.get_node_dimensions(parent_node.node_id).x + Constants.CHILD_NODE_OFFSET_X,
        y = parent_node.position.y + random_y_offset
    })
    child.parent_node_id = parent_node.id
    
    -- Ensure parent has return output attribute
    if not parent_node.return_attr then
        parent_node.return_attr = State.next_pin_id()
    end
    
    -- Ensure child has input attribute
    if not child.input_attr then
        child.input_attr = State.next_pin_id()
    end
    
    -- Auto-create link from parent return to child
    Nodes.create_link("main", parent_node, parent_node.return_attr, 
                child, child.input_attr)
end




-- ========================================
-- Node Management
-- ========================================

function Nodes.remove_starter_node(node)
    -- Remove child operation nodes first
    Nodes.remove_child_nodes(node)
    
    -- Remove connected links
    Nodes.remove_links_for_node(node)
    
    -- Remove from the appropriate list
    if node.category == Constants.NODE_CATEGORY_DATA then
        for i, n in ipairs(State.data_nodes) do
            if n.id == node.id then
                table.remove(State.data_nodes, i)
                break
            end
        end
    elseif node.category == Constants.NODE_CATEGORY_OPERATIONS then
        for i, n in ipairs(State.all_nodes) do
            if n.id == node.id then
                table.remove(State.all_nodes, i)
                break
            end
        end
    else
        for i, n in ipairs(State.starter_nodes) do
            if n.id == node.id then
                table.remove(State.starter_nodes, i)
                break
            end
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

function Nodes.remove_operation_node(node)
    -- Remove child operation nodes first
    Nodes.remove_child_nodes(node)
    
    -- Remove connected links
    Nodes.remove_links_for_node(node)
    
    -- Remove from the list
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
    
    for i, node in ipairs(State.all_nodes) do
        if node.parent_node_id == parent_node.id then
            table.insert(children_to_remove, node)
        end
    end
    
    for _, child in ipairs(children_to_remove) do
        Nodes.remove_operation_node(child)
    end
end

function Nodes.has_children(node)
    for _, child in ipairs(State.all_nodes) do
        if child.parent_node_id == node.id then
            return true
        end
    end
    return false
end

function Nodes.get_node_count()
    return #State.starter_nodes + #State.data_nodes + #State.all_nodes
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
    -- Find nodes and pins
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

    -- Prevent multiple connections to main input
    if to_pin_type == "main_input" then
        if to_node.parent_node_id ~= nil then
            -- Already connected, do not allow another link
            return
        end
        -- Main connection
        Nodes.create_link("main", from_node, start_pin, to_node, end_pin)
        to_node.parent_node_id = from_node.id
    elseif to_pin_type == "param_input" then
        -- Parameter connection
        local param_index = Nodes.get_param_index_from_pin(to_node, end_pin)
        local link = Nodes.create_link("parameter", from_node, start_pin, to_node, end_pin)
        link.parameter_index = param_index
        to_node.param_connections[param_index] = from_node.id
    elseif to_pin_type == "value_input" then
        -- Field value connection
        local link = Nodes.create_link("value", from_node, start_pin, to_node, end_pin)
        to_node.value_connection = from_node.id
    elseif to_pin_type == "operation_input1" then
        -- Operation input 1 connection
        local link = Nodes.create_link("operation_input1", from_node, start_pin, to_node, end_pin)
        to_node.input1_connection = from_node.id
    elseif to_pin_type == "operation_input2" then
        -- Operation input 2 connection
        local link = Nodes.create_link("operation_input2", from_node, start_pin, to_node, end_pin)
        to_node.input2_connection = from_node.id
    elseif to_pin_type == "control_condition_input" then
        -- Control condition input connection
        local link = Nodes.create_link("control_condition", from_node, start_pin, to_node, end_pin)
        to_node.condition_connection = from_node.id
    elseif to_pin_type == "control_true_input" then
        -- Control true value input connection
        local link = Nodes.create_link("control_true", from_node, start_pin, to_node, end_pin)
        to_node.true_connection = from_node.id
    elseif to_pin_type == "control_false_input" then
        -- Control false value input connection
        local link = Nodes.create_link("control_false", from_node, start_pin, to_node, end_pin)
        to_node.false_connection = from_node.id
    elseif to_pin_type == "return_override_input" then
        -- Return override connection
        local link = Nodes.create_link("return_override", from_node, start_pin, to_node, end_pin)
        to_node.return_override_connection = from_node.id
    end
end

function Nodes.handle_link_destroyed(link_id)
    for i, link in ipairs(State.all_links) do
        if link.id == link_id then
            -- Clean up connection references
            local to_node = Nodes.find_node_by_id(link.to_node)
            if to_node then
                if link.connection_type == "parameter" and link.parameter_index then
                    to_node.param_connections[link.parameter_index] = nil
                elseif link.connection_type == "value" then
                    to_node.value_connection = nil
                elseif link.connection_type == "operation_input1" then
                    to_node.input1_connection = nil
                elseif link.connection_type == "operation_input2" then
                    to_node.input2_connection = nil
                elseif link.connection_type == "control_condition" then
                    to_node.condition_connection = nil
                elseif link.connection_type == "control_true" then
                    to_node.true_connection = nil
                elseif link.connection_type == "control_false" then
                    to_node.false_connection = nil
                elseif link.connection_type == "return_override" then
                    to_node.return_override_connection = nil
                elseif link.connection_type == "main" then
                    to_node.parent_node_id = nil
                end
            end
            
            table.remove(State.all_links, i)
            State.link_map[link_id] = nil  -- Remove from hash map
            State.mark_as_modified()
            break
        end
    end
end

function Nodes.find_node_by_pin(pin_id)
    -- Search starter nodes
    for _, node in ipairs(State.starter_nodes) do
        if node.output_attr == pin_id then
            return node, "output"
        elseif node.return_override_attr == pin_id then
            return node, "return_override_input"
        end
    end
    
    -- Search data nodes
    for _, node in ipairs(State.data_nodes) do
        if node.output_attr == pin_id then
            return node, "output"
        elseif node.return_override_attr == pin_id then
            return node, "return_override_input"
        end
    end
    
    -- Search operation nodes
    for _, node in ipairs(State.all_nodes) do
        if node.input_attr == pin_id then
            return node, "main_input"
        elseif node.output_attr == pin_id then
            return node, "output"
        elseif node.input1_attr == pin_id then
            return node, "operation_input1"
        elseif node.input2_attr == pin_id then
            return node, "operation_input2"
        elseif node.condition_attr == pin_id then
            return node, "control_condition_input"
        elseif node.true_attr == pin_id then
            return node, "control_true_input"
        elseif node.false_attr == pin_id then
            return node, "control_false_input"
        else
            -- Check parameter pins
            if node.param_input_attrs then
                for i, pin in pairs(node.param_input_attrs) do
                    if pin == pin_id then
                        return node, "param_input"
                    end
                end
            end
            -- Check value pin
            if node.value_input_attr == pin_id then
                return node, "value_input"
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
-- Value Resolution
-- ========================================

function Nodes.get_parent_value(node)
    if not node.parent_node_id then
        return nil
    end
    
    local parent = Nodes.find_node_by_id(node.parent_node_id)
    if not parent then
        return nil
    end
    
    -- For most nodes, just return ending_value
    if parent.category ~= Constants.NODE_CATEGORY_STARTER or parent.type ~= Constants.STARTER_TYPE_HOOK then -- Not a Hook starter
        return parent.ending_value
    end
    
    -- For Hook starters, determine which output we're connected to
    -- Find the link connecting this node to its parent
    local connection_pin = nil
    for _, link in ipairs(State.all_links) do
        if link.to_node == node.id and link.to_pin == node.input_attr then
            connection_pin = link.from_pin
            break
        end
    end
    
    if not connection_pin then
        return parent.ending_value -- Fallback
    end
    
    -- Determine which output pin we're connected to
    if connection_pin == parent.output_attr then
        -- Connected to managed object output
        return parent.ending_value
    elseif connection_pin == parent.return_attr then
        -- Connected to return value output
        return parent.return_value
    end
    
    -- Fallback
    return parent.ending_value
end

function Nodes.get_pin_value(pin_id)
    if not pin_id then
        return nil
    end
    
    -- Find the link that connects to this pin
    for _, link in ipairs(State.all_links) do
        if link.to_pin == pin_id then
            -- Found a link to this pin, get the value from the source
            local source_node = Nodes.find_node_by_id(link.from_node)
            if source_node then
                -- Return the ending_value of the source node
                return source_node.ending_value
            end
            break
        end
    end
    
    return nil
end

function Nodes.get_connected_param_value(node, param_index)
    local connected_node_id = node.param_connections[param_index]
    if not connected_node_id then
        return nil
    end
    
    local connected_node = Nodes.find_node_by_id(connected_node_id)
    if connected_node then
        return connected_node.ending_value
    end
    
    return nil
end

function Nodes.get_connected_field_value(node)
    if not node.value_connection then
        return nil
    end
    
    local connected_node = Nodes.find_node_by_id(node.value_connection)
    if connected_node then
        return connected_node.ending_value
    end
    
    return nil
end

function Nodes.get_operation_input1_value(node)
    if node.input1_connection then
        local connected_node = Nodes.find_node_by_id(node.input1_connection)
        if connected_node then
            return connected_node.ending_value
        end
    elseif node.input1_manual_value and node.input1_manual_value ~= "" then
        return Utils.parse_primitive_value(node.input1_manual_value)
    end
    
    return nil
end

function Nodes.get_operation_input2_value(node)
    if node.input2_connection then
        local connected_node = Nodes.find_node_by_id(node.input2_connection)
        if connected_node then
            return connected_node.ending_value
        end
    elseif node.input2_manual_value and node.input2_manual_value ~= "" then
        return Utils.parse_primitive_value(node.input2_manual_value)
    end
    
    return nil
end

function Nodes.get_control_input_value(node, attr_name)
    local connection_name = attr_name:gsub("_attr", "_connection")
    local manual_name = attr_name:gsub("_attr", "_manual_value")
    
    if node[connection_name] then
        local connected_node = Nodes.find_node_by_id(node[connection_name])
        if connected_node then
            return connected_node.ending_value
        end
    elseif node[manual_name] and node[manual_name] ~= "" then
        return Utils.parse_primitive_value(node[manual_name])
    end
    
    return nil
end

function Nodes.is_param_connected(node, param_index)
    return node.param_connections[param_index] ~= nil
end

function Nodes.is_param_connected_for_return_override(node)
    return node.return_override_connection ~= nil
end

function Nodes.get_connected_return_override_value(node)
    if not node.return_override_connection then return nil end
    local connected_node = Nodes.find_node_by_id(node.return_override_connection)
    if connected_node then
        return connected_node.ending_value
    end
    return nil
end

function Nodes.is_field_value_connected(node)
    return node.value_connection ~= nil
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

function Nodes.get_cached_type_info(type_def)
    local type_name = type_def:get_full_name()
    
    if not State.type_cache[type_name] then
        State.type_cache[type_name] = {
            methods = Nodes.build_method_list(type_def),
            fields = Nodes.build_field_list(type_def),
            last_accessed = os.time()
        }
        
        Nodes.cleanup_cache(State.type_cache, Constants.TYPE_CACHE_SIZE_LIMIT)
    else
        State.type_cache[type_name].last_accessed = os.time()
    end
    
    return State.type_cache[type_name]
end

function Nodes.build_method_list(type_def)
    local methods = {}
    
    -- Walk inheritance chain and get methods from each type
    local current_type = type_def
    local level = 1
    
    while current_type do
        local success, type_methods = pcall(function() return current_type:get_methods() end)
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

function Nodes.build_field_list(type_def)
    local fields = {}
    
    -- Walk inheritance chain and get fields from each type
    local current_type = type_def
    local level = 1
    
    while current_type do
        local success, type_fields = pcall(function() return current_type:get_fields() end)
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

function Nodes.get_methods_for_combo(type_def)
    local cache_key = type_def:get_full_name()
    
    if not State.combo_cache[cache_key] then
        local type_info = Nodes.get_cached_type_info(type_def)
        local combo_items = {""}  -- Start with empty item
        
        for _, item in ipairs(type_info.methods) do
            table.insert(combo_items, item.display)
        end
        
        State.combo_cache[cache_key] = combo_items
        Nodes.cleanup_cache(State.combo_cache, Constants.COMBO_CACHE_SIZE_LIMIT)
    end
    
    return State.combo_cache[cache_key]
end

function Nodes.get_method_by_group_and_index(type_def, group_index, method_index)
    local type_info = Nodes.get_cached_type_info(type_def)
    
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

function Nodes.get_fields_for_combo(type_def)
    local cache_key = type_def:get_full_name()
    
    if not State.combo_cache[cache_key .. "_fields"] then
        local type_info = Nodes.get_cached_type_info(type_def)
        local combo_items = {""}  -- Start with empty item
        
        for _, item in ipairs(type_info.fields) do
            table.insert(combo_items, item.display)
        end
        
        State.combo_cache[cache_key .. "_fields"] = combo_items
        Nodes.cleanup_cache(State.combo_cache, Constants.COMBO_CACHE_SIZE_LIMIT)
    end
    
    return State.combo_cache[cache_key .. "_fields"]
end

function Nodes.get_field_by_group_and_index(type_def, group_index, field_index)
    local type_info = Nodes.get_cached_type_info(type_def)
    
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

function Nodes.get_param_pin_id(node, param_index)
    if not node.param_input_attrs then
        node.param_input_attrs = {}
    end
    
    if not node.param_input_attrs[param_index] then
        node.param_input_attrs[param_index] = State.next_pin_id()
    end
    
    return node.param_input_attrs[param_index]
end

function Nodes.set_param_pin_id(node, param_index, pin_id)
    if not node.param_input_attrs then
        node.param_input_attrs = {}
    end
    
    node.param_input_attrs[param_index] = pin_id
end

function Nodes.get_field_value_pin_id(node)
    if not node.value_input_attr then
        node.value_input_attr = State.next_pin_id()
    end
    
    return node.value_input_attr
end

function Nodes.ensure_node_pin_ids(node)
    -- Ensure main input attribute exists
    if not node.input_attr then
        node.input_attr = State.next_pin_id()
    end
    
    -- Ensure output attribute exists - preserve from config or create for operations
    if not node.output_attr then
        node.output_attr = State.next_pin_id()
    end
    
    -- Ensure parameter input attributes exist based on stored data
    if node.param_manual_values then
        for i = 1, #node.param_manual_values do
            Nodes.get_param_pin_id(node, i) -- This creates the pin ID if it doesn't exist
        end
    end
    
    -- Ensure field value input attribute exists for Set operations
    if node.type == Constants.FOLLOWER_TYPE_FIELD and node.action_type == Constants.ACTION_SET then
        if not node.value_input_attr then
            node.value_input_attr = State.next_pin_id()
        end
    end
end

function Nodes.get_param_index_from_pin(node, pin_id)
    if not node.param_input_attrs then
        return nil
    end
    
    for index, pin in pairs(node.param_input_attrs) do
        if pin == pin_id then
            return index
        end
    end
    return nil
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
        elseif node.type == Constants.STARTER_TYPE_NATIVE then
            -- Native nodes need to be re-initialized manually
            node.status = "Requires re-initialization"
        end
    elseif node.category == Constants.NODE_CATEGORY_DATA then
        if node.type == Constants.DATA_TYPE_ENUM then
            if node.path and node.path ~= "" then
                -- For enums, we need to generate the enum data and set the ending_value
                -- This is complex, so we'll just set a placeholder and let the render function handle it
                node.status = "Enum loaded - needs refresh"
            end
        elseif node.type == Constants.DATA_TYPE_PRIMITIVE then
            -- Restore the value as ending_value
            node.ending_value = node.value
            node.status = "Ready"
        end
    end
end


return Nodes
