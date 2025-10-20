-- DevTester v2.0 - Helper Functions
-- Utility functions for node management, validation, and UI
-- 
-- Note: get_node_by_id is an alias for find_node_by_id (for backward compatibility)

local State = require("DevTester2.State")
local sdk = sdk
local re = re

local Helpers = {}

-- ========================================
-- State Management
-- ========================================

function Helpers.mark_as_modified()
    State.is_modified = true
end

function Helpers.mark_as_saved()
    State.is_modified = false
end

function Helpers.has_unsaved_changes()
    return State.is_modified
end

-- ========================================
-- ID Generation
-- ========================================

function Helpers.next_node_id()
    local id = State.next_node_id
    State.next_node_id = State.next_node_id + 1
    return id
end

function Helpers.next_link_id()
    local id = State.next_link_id
    State.next_link_id = State.next_link_id + 1
    return id
end

function Helpers.get_link_by_id(link_id)
    for _, link in ipairs(State.all_links) do
        if link.id == link_id then
            return link
        end
    end
    return nil
end

function Helpers.next_pin_id()
    local id = State.next_pin_id
    State.next_pin_id = State.next_pin_id + 1
    return id
end

-- ========================================
-- UI Styling
-- ========================================

function Helpers.brighten_color(color, factor)
    -- Brighten a color by the given factor (1.0 = no change, >1.0 = brighter)
    -- Color is in AABBGGRR format (0xAABBGGRR)
    -- Extract components: AA BB GG RR
    
    -- Extract each byte using modulo and division
    local red = color % 256  -- RR (bits 0-7)
    local green = math.floor(color / 256) % 256  -- GG (bits 8-15)  
    local blue = math.floor(color / 65536) % 256  -- BB (bits 16-23)
    local alpha = math.floor(color / 16777216) % 256  -- AA (bits 24-31)
    
    -- Brighten each component (only RGB, keep alpha same)
    red = math.min(255, math.floor(red * factor))
    green = math.min(255, math.floor(green * factor))
    blue = math.min(255, math.floor(blue * factor))
    
    -- Reconstruct AABBGGRR: AA * 16777216 + BB * 65536 + GG * 256 + RR
    return alpha * 16777216 + blue * 65536 + green * 256 + red
end

function Helpers.set_node_titlebar_color(color)
    -- Set title bar colors for nodes using style indices 3, 4, 5
    -- 3 = normal, 4 = hovered, 5 = selected
    local hovered_color = Helpers.brighten_color(color, 1.2)  -- 20% brighter
    local selected_color = Helpers.brighten_color(color, 1.4) -- 40% brighter
    
    imnodes.push_color_style(4, color)        -- Normal
    imnodes.push_color_style(5, hovered_color) -- Hovered
    imnodes.push_color_style(6, selected_color) -- Selected
end

function Helpers.reset_node_titlebar_color()
    imnodes.pop_color_style() -- Selected (6)
    imnodes.pop_color_style() -- Hovered (5)
    imnodes.pop_color_style() -- Normal (4)
end

-- ========================================
-- Node Management
-- ========================================

function Helpers.create_starter_node(starter_type)
    local node_id = Helpers.next_node_id()
    local node = {
        id = node_id,
        node_id = node_id,
        node_category = "starter",
        type = starter_type or 1, -- Default to Managed (1) if not specified
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
    
    table.insert(State.starter_nodes, node)
    Helpers.mark_as_modified()
    return node
end

-- Alias for backward compatibility
function Helpers.get_node_by_id(node_id)
    return Helpers.find_node_by_id(node_id)
end

function Helpers.create_operation_node(position)
    local node_id = Helpers.next_node_id()
    local node = {
        id = node_id,
        node_id = node_id,
        node_category = "operation",
        position = position or {x = 0, y = 0},
        parent_node_id = nil,
        operation = 0, -- Default to Method (will be auto-detected)
        action_type = 0, -- Default to Get
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
    Helpers.mark_as_modified()
    return node
end

function Helpers.remove_starter_node(node)
    -- Remove child operation nodes first
    Helpers.remove_child_nodes(node)
    
    -- Remove connected links
    Helpers.remove_links_for_node(node)
    
    -- Remove from the list
    for i, n in ipairs(State.starter_nodes) do
        if n.id == node.id then
            table.remove(State.starter_nodes, i)
            break
        end
    end
    
    Helpers.mark_as_modified()
    -- Reset node positioning state so nodes are repositioned after node removal
    if State.nodes_positioned then
        for k in pairs(State.nodes_positioned) do
            State.nodes_positioned[k] = nil
        end
    end
end

function Helpers.remove_operation_node(node)
    -- Remove child operation nodes first
    Helpers.remove_child_nodes(node)
    
    -- Remove connected links
    Helpers.remove_links_for_node(node)
    
    -- Remove from the list
    for i, n in ipairs(State.all_nodes) do
        if n.id == node.id then
            table.remove(State.all_nodes, i)
            break
        end
    end
    
    Helpers.mark_as_modified()
    -- Reset node positioning state so nodes are repositioned after node removal
    if State.nodes_positioned then
        for k in pairs(State.nodes_positioned) do
            State.nodes_positioned[k] = nil
        end
    end
end

function Helpers.remove_links_for_node(node)
    -- Remove all links where the node being deleted is directly involved
    -- Use handle_link_destroyed to properly clean up connection references
    local i = 1
    while i <= #State.all_links do
        local link = State.all_links[i]
        if link.from_node == node.id or link.to_node == node.id then
            Helpers.handle_link_destroyed(link.id)
            -- Don't increment i since we removed an element
        else
            i = i + 1
        end
    end
end

function Helpers.remove_links_for_pin(pin_id)
    -- Remove all links connected to the specified pin
    -- Use handle_link_destroyed to properly clean up connection references
    local i = 1
    while i <= #State.all_links do
        local link = State.all_links[i]
        if link.from_pin == pin_id or link.to_pin == pin_id then
            Helpers.handle_link_destroyed(link.id)
            -- Don't increment i since we removed an element
        else
            i = i + 1
        end
    end
end

function Helpers.remove_child_nodes(parent_node)
    local children_to_remove = {}
    
    for i, node in ipairs(State.all_nodes) do
        if node.parent_node_id == parent_node.id then
            table.insert(children_to_remove, node)
        end
    end
    
    for _, child in ipairs(children_to_remove) do
        Helpers.remove_operation_node(child)
    end
end

function Helpers.has_children(node)
    for _, child in ipairs(State.all_nodes) do
        if child.parent_node_id == node.id then
            return true
        end
    end
    return false
end

function Helpers.get_node_count()
    return #State.starter_nodes + #State.all_nodes
end

function Helpers.clear_all_nodes()
    
    State.starter_nodes = {}
    State.all_nodes = {}
    State.all_links = {}
    
    -- Reset ID counters
    State.next_node_id = 1
    State.next_link_id = 1
    State.next_pin_id = 1
    
    -- Reset node positioning state
    State.nodes_positioned = {}
end

function Helpers.is_array(value)
    -- Check if Helpers.get_type_display_name on the ending value contains a []
    local type_def = value
    if type(value) == "userdata" then
        local success, td = pcall(function() return value:get_type_definition() end)
        if success and td then
            type_def = td
        end
    end
    local type_name = Helpers.get_type_display_name(type_def)
    if type_name and (type_name:find("%[%]") or type_name:find("Array")) then
        return true
    end
    return false
end

function Helpers.add_child_node(parent_node)
    -- Random Y offset between -150 and +150
    local random_y_offset = math.random(-150, 150)
    
    local child = Helpers.create_operation_node({
        x = parent_node.position.x + State.NODE_WIDTH + 100,
        y = parent_node.position.y + random_y_offset
    })
    child.parent_node_id = parent_node.id
    
    -- Auto-detect if parent value is an array and set operation to Array
    if parent_node.ending_value then
        if Helpers.is_array(parent_node.ending_value) then
            child.operation = 2 -- Array
        end
    end
    
    -- Ensure parent has output attribute
    if not parent_node.output_attr then
        parent_node.output_attr = Helpers.next_pin_id()
    end
    
    -- Ensure child has input attribute
    if not child.input_attr then
        child.input_attr = Helpers.next_pin_id()
    end
    
    -- Auto-create link from parent to child
    Helpers.create_link("main", parent_node, parent_node.output_attr, 
                child, child.input_attr)
end

function Helpers.add_child_node_to_arg(parent_node, arg_index)
    -- Random Y offset between -150 and +150
    local random_y_offset = math.random(-150, 150)
    
    local child = Helpers.create_operation_node({
        x = parent_node.position.x + State.NODE_WIDTH + 100,
        y = parent_node.position.y + random_y_offset
    })
    child.parent_node_id = parent_node.id
    
    -- Ensure parent has the specific arg output attribute
    if not parent_node.hook_arg_attrs or not parent_node.hook_arg_attrs[arg_index] then
        if not parent_node.hook_arg_attrs then
            parent_node.hook_arg_attrs = {}
        end
        parent_node.hook_arg_attrs[arg_index] = Helpers.next_pin_id()
    end
    
    -- Ensure child has input attribute
    if not child.input_attr then
        child.input_attr = Helpers.next_pin_id()
    end
    
    -- Auto-create link from parent arg to child
    Helpers.create_link("main", parent_node, parent_node.hook_arg_attrs[arg_index], 
                child, child.input_attr)
end

function Helpers.add_child_node_to_return(parent_node)
    -- Random Y offset between -150 and +150
    local random_y_offset = math.random(-150, 150)
    
    local child = Helpers.create_operation_node({
        x = parent_node.position.x + State.NODE_WIDTH + 100,
        y = parent_node.position.y + random_y_offset
    })
    child.parent_node_id = parent_node.id
    
    -- Ensure parent has return output attribute
    if not parent_node.return_attr then
        parent_node.return_attr = Helpers.next_pin_id()
    end
    
    -- Ensure child has input attribute
    if not child.input_attr then
        child.input_attr = Helpers.next_pin_id()
    end
    
    -- Auto-create link from parent return to child
    Helpers.create_link("main", parent_node, parent_node.return_attr, 
                child, child.input_attr)
end

-- ========================================
-- Link Management
-- ========================================

function Helpers.create_link(connection_type, from_node, from_pin, to_node, to_pin)
    local link = {
        id = Helpers.next_link_id(),
        connection_type = connection_type, -- "main" or "parameter" or "value"
        from_node = from_node.id,
        from_pin = from_pin,
        to_node = to_node.id,
        to_pin = to_pin,
        parameter_index = nil,
        field_name = nil
    }
    
    table.insert(State.all_links, link)
    Helpers.mark_as_modified()
    return link
end

function Helpers.handle_link_created(start_pin, end_pin)
    -- Find nodes and pins
    local from_node, from_pin_type = Helpers.find_node_by_pin(start_pin)
    local to_node, to_pin_type = Helpers.find_node_by_pin(end_pin)
    if not from_node or not to_node then
        return
    end

    -- Check for existing connections to this input and remove them
    for i = #State.all_links, 1, -1 do
        local link = State.all_links[i]
        if link.to_node == to_node.id and link.to_pin == end_pin then
            -- Remove the existing link
            Helpers.handle_link_destroyed(link.id)
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
        Helpers.create_link("main", from_node, start_pin, to_node, end_pin)
        to_node.parent_node_id = from_node.id
    elseif to_pin_type == "param_input" then
        -- Parameter connection
        local param_index = Helpers.get_param_index_from_pin(to_node, end_pin)
        local link = Helpers.create_link("parameter", from_node, start_pin, to_node, end_pin)
        link.parameter_index = param_index
        to_node.param_connections[param_index] = from_node.id
    elseif to_pin_type == "value_input" then
        -- Field value connection
        local link = Helpers.create_link("value", from_node, start_pin, to_node, end_pin)
        to_node.value_connection = from_node.id
    elseif to_pin_type == "return_override_input" then
        -- Return override connection
        local link = Helpers.create_link("return_override", from_node, start_pin, to_node, end_pin)
        to_node.return_override_connection = from_node.id
    end
end

function Helpers.handle_link_destroyed(link_id)
    for i, link in ipairs(State.all_links) do
        if link.id == link_id then
            -- Clean up connection references
            local to_node = Helpers.find_node_by_id(link.to_node)
            if to_node then
                if link.connection_type == "parameter" and link.parameter_index then
                    to_node.param_connections[link.parameter_index] = nil
                elseif link.connection_type == "value" then
                    to_node.value_connection = nil
                elseif link.connection_type == "return_override" then
                    to_node.return_override_connection = nil
                elseif link.connection_type == "main" then
                    to_node.parent_node_id = nil
                end
            end
            
            table.remove(State.all_links, i)
            Helpers.mark_as_modified()
            break
        end
    end
end

function Helpers.find_node_by_pin(pin_id)
    -- Search starter nodes
    for _, node in ipairs(State.starter_nodes) do
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

function Helpers.find_node_by_id(node_id)
    -- Search starter nodes
    for _, node in ipairs(State.starter_nodes) do
        if node.id == node_id then
            return node
        end
    end
    
    -- Search operation nodes
    for _, node in ipairs(State.all_nodes) do
        if node.id == node_id then
            return node
        end
    end
    
    return nil
end

-- ========================================
-- Value Resolution
-- ========================================

function Helpers.get_parent_value(node)
    if not node.parent_node_id then
        return nil
    end
    
    local parent = Helpers.find_node_by_id(node.parent_node_id)
    if not parent then
        return nil
    end
    
    -- For most nodes, just return ending_value
    if parent.node_category ~= "starter" or parent.type ~= 2 then -- Not a Hook starter
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

function Helpers.get_connected_param_value(node, param_index)
    local connected_node_id = node.param_connections[param_index]
    if not connected_node_id then
        return nil
    end
    
    local connected_node = Helpers.find_node_by_id(connected_node_id)
    if connected_node then
        return connected_node.ending_value
    end
    
    return nil
end

function Helpers.get_connected_field_value(node)
    if not node.value_connection then
        return nil
    end
    
    local connected_node = Helpers.find_node_by_id(node.value_connection)
    if connected_node then
        return connected_node.ending_value
    end
    
    return nil
end

function Helpers.is_param_connected(node, param_index)
    return node.param_connections[param_index] ~= nil
end

function Helpers.is_param_connected_for_return_override(node)
    return node.return_override_connection ~= nil
end

function Helpers.get_connected_return_override_value(node)
    if not node.return_override_connection then return nil end
    local connected_node = Helpers.find_node_by_id(node.return_override_connection)
    if connected_node then
        return connected_node.ending_value
    end
    return nil
end

function Helpers.is_field_value_connected(node)
    return node.value_connection ~= nil
end

-- ========================================
-- Type Parsing
-- ========================================

function Helpers.parse_primitive_value(text_value)
    if not text_value or text_value == "" then
        return text_value
    end
    
    -- Try to convert to number
    local num_value = tonumber(text_value)
    if num_value then
        return num_value
    end
    
    -- Try to convert to boolean
    if text_value == "true" then
        return true
    elseif text_value == "false" then
        return false
    end
    
    -- Otherwise return as string
    return text_value
end

function Helpers.parse_value_for_type(text_value, param_type)
    if not text_value or text_value == "" then
        return nil
    end
    
    -- Get the type name
    local type_name = param_type:get_name()
    
    -- Handle different types
    if type_name == "System.Int32" or type_name == "System.Int64" or 
       type_name == "System.UInt32" or type_name == "System.UInt64" or
       type_name == "System.Int16" or type_name == "System.UInt16" or
       type_name == "System.Byte" or type_name == "System.SByte" then
        -- Integer types
        local num = tonumber(text_value)
        return num and math.floor(num) or 0
    elseif type_name == "System.Single" or type_name == "System.Double" then
        -- Float types
        return tonumber(text_value) or 0.0
    elseif type_name == "System.Boolean" then
        -- Boolean type
        return text_value == "true"
    elseif type_name == "System.String" then
        -- String type
        return text_value
    elseif type_name == "System.Char" then
        -- Character type (take first character)
        return text_value:sub(1, 1)
    else
        -- For unknown types, try primitive parsing
        return Helpers.parse_primitive_value(text_value)
    end
end

-- ========================================
-- Display Formatting
-- ========================================

function Helpers.format_value_display(value)
    if value == nil then
        return "nil"
    end
    
    local value_type = type(value)
    
    if value_type == "userdata" then
        -- It's a managed object
        local success, type_def = pcall(function() return value:get_type_definition() end)
        if success and type_def then
            local type_name = type_def:get_name()
            local success2, address = pcall(function() return value:get_address() end)
            if success2 and address then
                return string.format("%s | 0x%X", type_name, address)
            else
                return type_name
            end
        else
            return "userdata"
        end
    elseif value_type == "number" then
        return string.format("%.2f", value)
    elseif value_type == "boolean" then
        return value and "true" or "false"
    elseif value_type == "string" then
        return string.format('"%s"', value)
    else
        return tostring(value)
    end
end

function Helpers.get_type_display_name(type_info)
    -- Get a simplified display name for a type definition
    -- First try the short name, fall back to extracting from full name if needed
    
    if not type_info then
        return "Unknown"
    end
    
    -- Try to get the short name first
    local success, name = pcall(function() return type_info:get_name() end)
    if success and name and name ~= "" then
        return name
    end
    
    -- If short name is empty, try to get full name and extract the last part
    local success2, full_name = pcall(function() return type_info:get_full_name() end)
    if success2 and full_name and full_name ~= "" then
        -- Find the last dot and extract everything after it
        local last_dot = full_name:match("^.*()%.") 
        if last_dot then
            return full_name:sub(last_dot + 1)
        else
            -- No dots found, return the full name
            return full_name
        end
    end
    
    -- Fallback if all else fails
    return "Unknown"
end

-- ========================================
-- Method/Field Helpers
-- ========================================

function Helpers.get_methods_for_combo(type_def)
    local combo_items = {""}  -- Start with empty item
    
    -- Walk inheritance chain and get methods from each type
    local current_type = type_def
    local level = 1
    
    while current_type do
        local success, methods = pcall(function() return current_type:get_methods() end)
        if not success or not methods then
            break
        end
        
        -- Get class name (get_name returns short name, better for generics)
        local short_name = current_type:get_name()
        
        -- Add class separator
        table.insert(combo_items, "\n" .. short_name)
        
        -- Add methods for this class
        for method_idx, method in ipairs(methods) do
            local name = method:get_name()
            local return_type = method:get_return_type()
            local return_name = return_type and Helpers.get_type_display_name(return_type) or "Void"
            
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
            table.insert(combo_items, display)
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
    
    return combo_items
end

function Helpers.get_method_by_group_and_index(type_def, group_index, method_index)
    -- Walk inheritance chain to find the specified group
    local current_type = type_def
    local level = 1
    
    while current_type do
        if level == group_index then
            -- Found the right inheritance level
            local success, methods = pcall(function() return current_type:get_methods() end)
            if success and methods and methods[method_index] then
                return methods[method_index]
            end
            return nil
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
    
    return nil
end

function Helpers.get_method_from_combo_index(type_def, combo_index)
    local combo_items = Helpers.get_methods_for_combo(type_def)
    
    -- combo_index is 0-based, but combo_items is 1-based array
    local item_index = combo_index + 1
    
    if item_index < 1 or item_index > #combo_items then
        return nil
    end
    
    local combo_item = combo_items[item_index]
    
    -- Parse the format: "level-methodIndex. methodName(params) | returnType"
    local level, method_idx = combo_item:match("^(%d+)%-(%d+)%. ")
    
    if level and method_idx then
        return Helpers.get_method_by_group_and_index(type_def, tonumber(level), tonumber(method_idx))
    end
    
    return nil
end

function Helpers.get_fields_for_combo(type_def)
    local combo_items = {""}  -- Start with empty item
    
    -- Walk inheritance chain and get fields from each type
    local current_type = type_def
    local level = 1
    
    while current_type do
        local success, fields = pcall(function() return current_type:get_fields() end)
        if not success or not fields then
            break
        end
        
        -- Get class name (get_name returns short name, better for generics)
        local short_name = current_type:get_name()
        
        -- Add class separator
        table.insert(combo_items, "\n" .. short_name)
        
        -- Add fields for this class
        for field_idx, field in ipairs(fields) do
            local name = field:get_name()
            local field_type = field:get_type()
            local type_name = Helpers.get_type_display_name(field_type)
            
            -- Format: classLevel-fieldIndex. fieldName | type
            local display = string.format("%d-%d. %s | %s", 
                level, field_idx, name, type_name)
            table.insert(combo_items, display)
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
    
    return combo_items
end

function Helpers.get_field_by_group_and_index(type_def, group_index, field_index)
    -- Walk inheritance chain to find the specified group
    local current_type = type_def
    local level = 1
    
    while current_type do
        if level == group_index then
            -- Found the right inheritance level
            local success, fields = pcall(function() return current_type:get_fields() end)
            if success and fields and fields[field_index] then
                return fields[field_index]
            end
            return nil
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
    
    return nil
end

function Helpers.get_field_from_combo_index(type_def, combo_index)
    local combo_items = Helpers.get_fields_for_combo(type_def)
    
    -- combo_index is 0-based, but combo_items is 1-based array
    local item_index = combo_index + 1
    
    if item_index < 1 or item_index > #combo_items then
        return nil
    end
    
    local combo_item = combo_items[item_index]
    
    -- Parse the format: "level-fieldIndex. fieldName | type"
    local level, field_idx = combo_item:match("^(%d+)%-(%d+)%. ")
    
    if level and field_idx then
        return Helpers.get_field_by_group_and_index(type_def, tonumber(level), tonumber(field_idx))
    end
    
    return nil
end

function Helpers.get_param_pin_id(node, param_index)
    if not node.param_input_attrs then
        node.param_input_attrs = {}
    end
    
    if not node.param_input_attrs[param_index] then
        node.param_input_attrs[param_index] = Helpers.next_pin_id()
    end
    
    return node.param_input_attrs[param_index]
end

function Helpers.set_param_pin_id(node, param_index, pin_id)
    if not node.param_input_attrs then
        node.param_input_attrs = {}
    end
    
    node.param_input_attrs[param_index] = pin_id
end

function Helpers.get_field_value_pin_id(node)
    if not node.value_input_attr then
        node.value_input_attr = Helpers.next_pin_id()
    end
    
    return node.value_input_attr
end

function Helpers.ensure_node_pin_ids(node)
    -- Ensure main input attribute exists
    if not node.input_attr then
        node.input_attr = Helpers.next_pin_id()
    end
    
    -- Ensure output attribute exists - preserve from config or create for operations
    if not node.output_attr then
        node.output_attr = Helpers.next_pin_id()
    end
    
    -- Ensure parameter input attributes exist based on stored data
    if node.param_manual_values then
        for i = 1, #node.param_manual_values do
            Helpers.get_param_pin_id(node, i) -- This creates the pin ID if it doesn't exist
        end
    end
    
    -- Ensure field value input attribute exists for Set operations
    if node.operation == 1 and node.action_type == 1 and not node.value_input_attr then
        node.value_input_attr = Helpers.next_pin_id()
    end
end

function Helpers.get_param_index_from_pin(node, pin_id)
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

-- ========================================
-- Validation
-- ========================================

function Helpers.is_valid_filename(name)
    if not name or name == "" then
        return false
    end
    
    -- Check for invalid characters
    if name:match('[<>:"/\\|?*]') then
        return false
    end
    
    -- Check for path traversal
    if name:match('%.%.') then
        return false
    end
    
    return true
end

function Helpers.validate_config_data(config)
    if not config then
        return false
    end
    
    if not config.name or config.name == "" then
        return false
    end
    
    if not config.nodes or type(config.nodes) ~= "table" then
        return false
    end
    
    if not config.links or type(config.links) ~= "table" then
        return false
    end
    
    return true
end

function Helpers.validate_and_restore_starter_node(node)
    if node.type == 0 then -- Type
        if node.path and node.path ~= "" then
            local type_def = sdk.find_type_definition(node.path)
            if type_def then
                node.ending_value = type_def
                node.status = "Success"
            else
                node.status = "Type not found"
            end
        end
    elseif node.type == 1 then -- Managed
        if node.path and node.path ~= "" then
            local managed_obj = sdk.get_managed_singleton(node.path)
            if managed_obj then
                node.ending_value = managed_obj
                node.status = "Success"
            else
                node.status = "Managed singleton not found"
            end
        end
    elseif node.type == 2 then -- Hook
        -- Hooks need to be re-initialized manually
        node.status = "Requires re-initialization"
    elseif node.type == 5 then -- Primitive
        -- Restore the value as ending_value
        node.ending_value = node.value
        node.status = "Ready"
    end
end

-- ========================================
-- UI Notifications
-- ========================================

function Helpers.show_error(message)
    re.msg("[DevTester Error] " .. message)
end

function Helpers.show_success(message)
    re.msg("[DevTester] " .. message)
end

function Helpers.show_info(message)
    re.msg("[DevTester] " .. message)
end

function Helpers.show_confirmation(message, on_confirm)
    -- Note: REFramework doesn't have built-in modal dialogs
    -- For now, use re.msg and assume user will proceed
    re.msg("[DevTester] " .. message)
    if on_confirm then
        on_confirm()
    end
end

-- ========================================
-- Shared Node Rendering Functions
-- ========================================

function Helpers.render_disconnected_operation_node(node, reason)
    -- Ensure all pin IDs exist before rendering
    Helpers.ensure_node_pin_ids(node)
    
    imnodes.begin_node(node.node_id)
    imnodes.begin_node_titlebar()
    local pos_for_debug = imgui.get_cursor_pos()
    imnodes.begin_input_attribute(node.input_attr)
    
    -- Show operation type with Disconnected status
    local operation_name = "Unknown"
    if node.operation == 0 then
        operation_name = "Method"
    elseif node.operation == 1 then
        operation_name = "Field"
    elseif node.operation == 2 then
        operation_name = "Array"
    end
    imgui.text(operation_name .. " (Disconnected)")
    
    imnodes.end_input_attribute()
    imnodes.end_node_titlebar()

    -- Show appropriate message based on disconnection reason
    local message = "Connect to parent node"
    if reason == "no_parent" then
        message = "Connect to parent node"
    elseif reason == "parent_nil" then
        message = "Parent node returns nil"
    elseif reason == "type_error" then
        message = "Parent returns unexpected type"
    end
    
    imgui.text_colored(
        message,
        0xFFFFFF00
    )

    imgui.spacing()

    -- Create placeholder attributes for links to reconnect
    -- Output attribute - always render if it exists (from config or created)
    if node.output_attr then
        imnodes.begin_output_attribute(node.output_attr)
        imgui.text("Output (Disconnected)")
        imnodes.end_output_attribute()
    end

    -- Parameter input attributes (placeholders)
    if node.param_manual_values then
        for i = 1, #node.param_manual_values do
            local param_pin_id = Helpers.get_param_pin_id(node, i)
            imnodes.begin_input_attribute(param_pin_id)
            imgui.text(string.format("Param %d (Disconnected)", i))
            imnodes.end_input_attribute()
        end
    end

    -- Field value input attribute for Set operations
    if node.operation == 1 and node.action_type == 1 then -- Field Set operation
        imnodes.begin_input_attribute(node.value_input_attr)
        imgui.text("Value (Disconnected)")
        imnodes.end_input_attribute()
    end

    if imgui.button("- Remove Node") then
        Helpers.remove_operation_node(node)
    end
    -- Debug info: Node ID, attributes, and connected Link IDs
    -- Collect all input attributes (main + params)
    local input_attrs = {}
    if node.input_attr then table.insert(input_attrs, tostring(node.input_attr)) end
    if node.param_manual_values then
        for i = 1, #(node.param_manual_values) do
            local param_pin_id = Helpers.get_param_pin_id(node, i)
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
    -- Code to align debug info to the top right of the node using stored pos
    local text_width = imgui.calc_text_size("[?]").x
    local node_width = imnodes.get_node_dimensions(node.node_id).x
    pos_for_debug.x = pos_for_debug.x + node_width - text_width - 16
    imgui.set_cursor_pos(pos_for_debug)
    imgui.text_colored("[?]", 0xFFDADADA)
    if imgui.is_item_hovered() then
        imgui.set_tooltip(debug_info)
    end

    imnodes.end_node()
end

function Helpers.reset_operation_data(node)
    node.selected_method_index = 0
    node.selected_field_index = 0
    node.selected_element_index = 0
    node.param_manual_values = {}
    node.value_manual_input = ""
    node.ending_value = nil
    node.status = nil
end

return Helpers
