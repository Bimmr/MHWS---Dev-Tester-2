-- DevTester v2.0 - Configuration System
-- Save/Load functionality for node graphs

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Constants = require("DevTester2.Constants")
local Utils = require("DevTester2.Utils")
local BaseFollower = require("DevTester2.Followers.BaseFollower")
local json = json
local fs = fs
local sdk = sdk

local Config = {}

-- ========================================
-- Configuration Directory
-- ========================================

function Config.get_config_directory()
    return "DevTester2/Configs/"
end

-- ========================================
-- Save Implementation
-- ========================================

function Config.save_configuration(name, description)
    -- Validate name
    if not Config.is_valid_filename(name) then
        return false, "Invalid filename"
    end
    
    -- Build config data
    local config = {
        name = name,
        description = description or "",
        saved_date = os.date("%Y-%m-%d %H:%M:%S"),
        nodes = Config.serialize_all_nodes(),
        links = Config.serialize_all_links(),
        node_id_counter = State.node_id_counter,
        link_id_counter = State.link_id_counter
    }
    
    -- Save variables as simple key-value pairs since all are persistent
    local variables = {}
    for var_name, var_data in pairs(State.variables) do
        variables[var_name] = var_data.value
    end
    config.variables = variables
    
    -- Save using REFramework's json.dump_file
    local file_path = Config.get_config_directory() .. name .. ".json"
    local success = json.dump_file(file_path, config)
    
    if success then
        State.current_config_name = name
        State.current_config_description = description or ""
        State.mark_as_saved()
        return true, nil
    else
        return false, "Failed to write file"
    end
end

function Config.save_autosave()
    -- Build config data (simplified for autosave)
    local config = {
        nodes = Config.serialize_all_nodes(),
        links = Config.serialize_all_links(),
        node_id_counter = State.node_id_counter,
        link_id_counter = State.link_id_counter,
        pin_id_counter = State.pin_id_counter
    }
    
    -- Save variables
    local variables = {}
    for var_name, var_data in pairs(State.variables) do
        variables[var_name] = var_data.value
    end
    config.variables = variables
    
    local success = json.dump_file("DevTester2/autosave.json", config)
    
    if not success then
        log.debug("Autosave failed: could not write file")
    end
    
    return success
end

function Config.serialize_all_nodes()
    local nodes = {}
    
    -- Serialize all nodes
    for _, node in ipairs(State.all_nodes) do
        table.insert(nodes, Config.serialize_node(node))
    end
    
    return nodes
end

function Config.serialize_node(node)
    local data = {
        id = node.id,
        category = node.category,
        position = {x = node.position.x, y = node.position.y},
        pins = { inputs = {}, outputs = {} }
    }
    
    -- Serialize pins
    if node.pins then
        for _, pin in ipairs(node.pins.inputs) do
            table.insert(data.pins.inputs, {
                id = pin.id,
                name = pin.name,
                value = pin.value,
                connection = pin.connection
            })
        end
        for _, pin in ipairs(node.pins.outputs) do
            table.insert(data.pins.outputs, {
                id = pin.id,
                name = pin.name,
                value = pin.value,
                connections = pin.connections
            })
        end
    end
    
    -- Add type-specific data
    if node.category == Constants.NODE_CATEGORY_STARTER then
        data.category = node.category
        data.type = node.type
        data.path = node.path
        data.param_manual_values = node.param_manual_values

        if node.type == Constants.STARTER_TYPE_HOOK then
            data.method_name = node.method_name
            
            -- Generate signature
            if node.path and node.method_group_index and node.method_index then
                local type_def = sdk.find_type_definition(node.path)
                if type_def then
                    local method = Nodes.get_method_by_group_and_index(type_def, node.method_group_index, node.method_index, false)
                    if method then
                        data.selected_method_signature = Nodes.get_method_signature(method)
                    end
                end
            end

            data.pre_hook_result = node.pre_hook_result
            data.return_type_name = node.return_type_name
            data.return_type_full_name = node.return_type_full_name
            data.is_initialized = node.is_initialized
            data.return_override_manual = node.return_override_manual
            data.actual_return_value = node.actual_return_value
            data.is_return_overridden = node.is_return_overridden
            data.was_called_mode = node.was_called_mode
        elseif node.type == Constants.STARTER_TYPE_NATIVE then
            data.method_name = node.method_name
            data.action_type = node.action_type
            
            -- Generate signature
            if node.path and node.method_group_index and node.method_index then
                local type_def = sdk.find_type_definition(node.path)
                if type_def then
                    local method = Nodes.get_method_by_group_and_index(type_def, node.method_group_index, node.method_index, false)
                    if method then
                        data.selected_method_signature = Nodes.get_method_signature(method)
                    end
                end
            end

            data.native_method_result = node.native_method_result
        end
    elseif node.category == Constants.NODE_CATEGORY_DATA then
        data.category = node.category
        data.type = node.type

        if node.type == Constants.DATA_TYPE_PRIMITIVE then
            data.value = node.value
        elseif node.type == Constants.DATA_TYPE_ENUM then
            data.path = node.path
            data.selected_enum_index = node.selected_enum_index
        elseif node.type == Constants.DATA_TYPE_VARIABLE then
            data.variable_name = node.variable_name
            data.default_value = node.default_value
            data.input_manual_value = node.input_manual_value
            data.pending_reset = node.pending_reset
        end
    elseif node.category == Constants.NODE_CATEGORY_OPERATIONS then
        data.category = node.category
        data.type = node.type
        data.selected_operation = node.selected_operation  -- For math operations
        -- Manual values
        data.input1_manual_value = node.input1_manual_value
        data.input2_manual_value = node.input2_manual_value
    elseif node.category == Constants.NODE_CATEGORY_CONTROL then
        data.category = node.category
        data.type = node.type
        
        -- Type-specific attributes
        if node.type == Constants.CONTROL_TYPE_SWITCH then
            -- Enhanced Select Control properties
            data.num_conditions = node.num_conditions
            data.show_compare_input = node.show_compare_input
            -- Legacy manual values (for backward compatibility)
            data.condition_manual_value = node.condition_manual_value
            data.true_manual_value = node.true_manual_value
            data.false_manual_value = node.false_manual_value
        elseif node.type == Constants.CONTROL_TYPE_TOGGLE then
            -- Manual values
            data.input_manual_value = node.input_manual_value
            data.enabled_manual_value = node.enabled_manual_value
        elseif node.type == Constants.CONTROL_TYPE_COUNTER then
            -- Manual values
            data.max_manual_value = node.max_manual_value
            data.active_manual_value = node.active_manual_value
            data.restart_manual_value = node.restart_manual_value
            -- Runtime values
            data.current_count = node.current_count
            data.delay_ms = node.delay_ms
            data.last_increment_time = node.last_increment_time
        elseif node.type == Constants.CONTROL_TYPE_CONDITION then
            -- Manual values
            data.condition_manual_value = node.condition_manual_value
            data.true_manual_value = node.true_manual_value
            data.false_manual_value = node.false_manual_value
        end
    elseif node.category == Constants.NODE_CATEGORY_FOLLOWER then
        data.category = node.category
        data.type = node.type
        data.action_type = node.action_type

        if node.type == Constants.FOLLOWER_TYPE_METHOD then
            local parent_value = Nodes.get_parent_value(node)
            if parent_value then
                local parent_type = BaseFollower.get_parent_type(parent_value)
                if parent_type then
                    local is_static_context = BaseFollower.is_parent_type_definition(parent_value)
                    local method = Nodes.get_method_by_group_and_index(parent_type, node.method_group_index, node.method_index, is_static_context)
                    if method then
                        data.selected_method_signature = Nodes.get_method_signature(method)
                    end
                end
            end
            data.param_manual_values = node.param_manual_values
        elseif node.type == Constants.FOLLOWER_TYPE_FIELD then
            local parent_value = Nodes.get_parent_value(node)
            if parent_value then
                local parent_type = BaseFollower.get_parent_type(parent_value)
                if parent_type then
                    local is_static_context = BaseFollower.is_parent_type_definition(parent_value)
                    local field = Nodes.get_field_by_group_and_index(parent_type, node.field_group_index, node.field_index, is_static_context)
                    if field then
                        data.selected_field_signature = Nodes.get_field_signature(field)
                    end
                end
            end
            if node.action_type == 1 then -- Set
                data.value_manual_input = node.value_manual_input
                data.set_active = node.set_active
            end
        elseif node.type == Constants.FOLLOWER_TYPE_ARRAY then
            data.selected_element_index = node.selected_element_index
        end
    end
    
    return data
end

function Config.serialize_all_links()
    local links = {}
    for _, link in ipairs(State.all_links) do
        table.insert(links, {
            id = link.id,
            connection_type = link.connection_type,
            from_node = link.from_node,
            from_pin = link.from_pin,
            to_node = link.to_node,
            to_pin = link.to_pin,
            parameter_index = link.parameter_index,
            field_name = link.field_name
        })
    end
    return links
end

-- ========================================
-- Load Implementation
-- ========================================

function Config.scan_available_configs()
    -- Use REFramework's fs.glob to scan for JSON files
    -- Build pattern from config directory (replace / with \\ and add regex pattern)
    local dir = Config.get_config_directory():gsub("/", "\\\\")
    local pattern = dir .. ".*json"
    local files = fs.glob(pattern)
    
    local configs = {}
    for _, file_path in ipairs(files) do
        local name = Config.get_filename_without_extension(file_path)
        if name ~= "Data" then

            -- Load the JSON file to get the description
            local description = ""
            local success, config_data = pcall(function() 
                return json.load_file(file_path) 
            end)
            if success and config_data and config_data.description then
                description = config_data.description
            end
            
            -- Line wrap description at 60 chars, only at spaces
            local function wrap_text_space(text, max_len)
                local out = ""
                local line = ""
                for word in text:gmatch("%S+") do
                    if #line + #word + 1 > max_len then
                        out = out .. line .. "\n"
                        line = word
                    else
                        if #line > 0 then
                            line = line .. " " .. word
                        else
                            line = word
                        end
                    end
                end
                if #line > 0 then
                    out = out .. line
                end
                return out
            end
            local wrapped_desc = wrap_text_space(description, 60)
            -- Format display with title, newline, wrapped description, and 2 newlines
            local display = name .. "\n" .. wrapped_desc .. "\n\n"
            
            table.insert(configs, {
                name = name,
                path = file_path,
                display = display
            })
        end
    end
    
    -- Sort alphabetically
    table.sort(configs, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    
    return configs
end

function Config.load_configuration(config_path)
    -- Load using REFramework's json.load_file
    local config = json.load_file(config_path)
    
    if not config then
        return false, "Failed to read file or parse JSON"
    end
    
    -- Validate config data
    if not Config.validate_config_data(config) then
        return false, "Invalid configuration file"
    end
    
    -- Clear existing nodes
    Nodes.clear_all_nodes()
    
    -- Restore ID counters from config BEFORE creating nodes
    State.node_id_counter = config.node_id_counter or 1
    State.link_id_counter = config.link_id_counter or 1
    State.pin_id_counter = config.pin_id_counter or 1

    -- Calculate the correct next pin ID value based on the highest pin ID used in the config
    local max_pin_id = 0
    for _, node_data in ipairs(config.nodes or {}) do
        if node_data.pins then
            if node_data.pins.inputs then
                for _, pin in ipairs(node_data.pins.inputs) do
                    if pin.id > max_pin_id then max_pin_id = pin.id end
                end
            end
            if node_data.pins.outputs then
                for _, pin in ipairs(node_data.pins.outputs) do
                    if pin.id > max_pin_id then max_pin_id = pin.id end
                end
            end
        end
    end
    if max_pin_id > 0 then
        State.pin_id_counter = max_pin_id + 1
    end
    for _, node_data in ipairs(config.nodes or {}) do
        -- Check pins for max pin ID
        if node_data.pins then
            if node_data.pins.inputs then
                for _, pin in ipairs(node_data.pins.inputs) do
                    if pin.id > max_pin_id then
                        max_pin_id = pin.id
                    end
                end
            end
            if node_data.pins.outputs then
                for _, pin in ipairs(node_data.pins.outputs) do
                    if pin.id > max_pin_id then
                        max_pin_id = pin.id
                    end
                end
            end
        end
    end
    State.pin_id_counter = max_pin_id + 1
    
    -- Deserialize nodes
    local node_map = {} -- Map old IDs to new node instances
    for _, node_data in ipairs(config.nodes or {}) do
        local node = Config.deserialize_node(node_data)
        if node then
            -- Ensure all pin IDs exist for proper link restoration
            Nodes.ensure_node_pin_ids(node)
            
            -- Validate and restore node state (especially for starters that need to reconnect to managed objects)
            Nodes.validate_and_restore_starter_node(node)
            
            node_map[node_data.id] = node
            -- Add node to state
            table.insert(State.all_nodes, node)
            State.node_map[node.id] = node  -- Add to hash map
        end
    end
    
    -- Deserialize links
    for _, link_data in ipairs(config.links or {}) do
        Config.deserialize_link(link_data, node_map)
    end
    
    -- Apply node positions (must be done after nodes are created)
    for _, node_data in ipairs(config.nodes or {}) do
        local node = node_map[node_data.id]
        if node and node_data.position then
            imnodes.set_node_editor_space_pos(node.id, node_data.position.x, node_data.position.y)
            -- Mark as positioned so render function doesn't reposition
            State.nodes_positioned = State.nodes_positioned or {}
            State.nodes_positioned[node.id] = true
        end
    end
    
    -- Update state
    State.current_config_name = config.name
    State.current_config_description = config.description or ""
    
    -- Load variables as simple key-value pairs, convert to internal format
    local variables = config.variables or {}
    State.variables = {}
    for var_name, var_value in pairs(variables) do
        State.variables[var_name] = {value = var_value, persistent = true}
    end
    
    State.mark_as_saved()
    
    return true, nil
end

function Config.load_autosave()
    -- Check if autosave exists
    local config = json.load_file("DevTester2/autosave.json")
    
    -- If no config or empty, do nothing
    if not config or not next(config) then
        return false
    end
    
    -- Clear existing nodes
    Nodes.clear_all_nodes()
    
    -- Restore ID counters
    State.node_id_counter = config.node_id_counter or 1
    State.link_id_counter = config.link_id_counter or 1
    State.pin_id_counter = config.pin_id_counter or 1

    -- Calculate max pin ID if not saved (legacy support)
    if not config.pin_id_counter then
        local max_pin_id = 0
        for _, node_data in ipairs(config.nodes or {}) do
            if node_data.pins then
                if node_data.pins.inputs then
                    for _, pin in ipairs(node_data.pins.inputs) do
                        if pin.id > max_pin_id then max_pin_id = pin.id end
                    end
                end
                if node_data.pins.outputs then
                    for _, pin in ipairs(node_data.pins.outputs) do
                        if pin.id > max_pin_id then max_pin_id = pin.id end
                    end
                end
            end
        end
        State.pin_id_counter = max_pin_id + 1
    end
    
    -- Deserialize nodes
    local node_map = {}
    for _, node_data in ipairs(config.nodes or {}) do
        local node = Config.deserialize_node(node_data)
        if node then
            Nodes.ensure_node_pin_ids(node)
            Nodes.validate_and_restore_starter_node(node)
            node_map[node_data.id] = node
            table.insert(State.all_nodes, node)
            State.node_map[node.id] = node
        end
    end
    
    -- Deserialize links
    for _, link_data in ipairs(config.links or {}) do
        Config.deserialize_link(link_data, node_map)
    end
    
    -- Apply positions
    for _, node_data in ipairs(config.nodes or {}) do
        local node = node_map[node_data.id]
        if node and node_data.position then
            imnodes.set_node_editor_space_pos(node.id, node_data.position.x, node_data.position.y)
            State.nodes_positioned = State.nodes_positioned or {}
            State.nodes_positioned[node.id] = true
        end
    end
    
    -- Restore variables
    local variables = config.variables or {}
    State.variables = {}
    for var_name, var_value in pairs(variables) do
        State.variables[var_name] = {value = var_value, persistent = true}
    end
    
    State.mark_as_modified()
    
    -- Clear autosave file
    json.dump_file("DevTester2/autosave.json", {})
    
    return true
end

function Config.deserialize_node(data)
    local node
    
    -- Restore pins
    local pins = { inputs = {}, outputs = {} }
    if data.pins then
        if data.pins.inputs then
            for _, pin_data in ipairs(data.pins.inputs) do
                local pin = {
                    id = pin_data.id,
                    name = pin_data.name,
                    value = pin_data.value,
                    connection = pin_data.connection
                }
                table.insert(pins.inputs, pin)
                State.pin_map[pin.id] = { node_id = data.id, pin = pin }
            end
        end
        if data.pins.outputs then
            for _, pin_data in ipairs(data.pins.outputs) do
                local pin = {
                    id = pin_data.id,
                    name = pin_data.name,
                    value = pin_data.value,
                    connections = pin_data.connections or {}
                }
                table.insert(pins.outputs, pin)
                State.pin_map[pin.id] = { node_id = data.id, pin = pin }
            end
        end
    end
    
    if data.category == Constants.NODE_CATEGORY_STARTER then
        node = {
            id = data.id,
            category = data.category,
            pins = pins,
            type = data.type,
            path = data.path,
            position = data.position or {x = 0, y = 0},
            ending_value = nil,
            status = nil,
            param_manual_values = data.param_manual_values or {},
            -- Hook-specific
            method_name = data.method_name or "",
            selected_method_combo = data.selected_method_combo,
            selected_method_signature = data.selected_method_signature,
            method_group_index = data.method_group_index,
            method_index = data.method_index,
            pre_hook_result = data.pre_hook_result or "CALL_ORIGINAL",
            return_type_name = data.return_type_name,
            return_type_full_name = data.return_type_full_name,
            hook_id = nil,
            is_initialized = data.is_initialized or false,
            return_override_manual = data.return_override_manual,
            actual_return_value = data.actual_return_value,
            is_return_overridden = data.is_return_overridden or false,
            was_called_mode = data.was_called_mode or "PRE",
            -- Native-specific
            native_method_result = data.native_method_result,
            action_type = data.action_type
        }
    elseif data.category == Constants.NODE_CATEGORY_DATA then
        node = {
            id = data.id,
            category = data.category,
            pins = pins,
            type = data.type,
            path = data.path or "",
            position = data.position or {x = 0, y = 0},
            ending_value = nil,
            status = nil,
            -- Enum-specific
            selected_enum_index = data.selected_enum_index or 1,
            -- Value-specific
            value = data.value or "",
            -- Variable-specific
            variable_name = data.variable_name or "",
            default_value = data.default_value or "",
            input_manual_value = data.input_manual_value or "",
            pending_reset = data.pending_reset or false
        }
    elseif data.category == Constants.NODE_CATEGORY_OPERATIONS then
        node = {
            id = data.id,
            category = data.category,
            pins = pins,
            type = data.type,
            position = data.position or {x = 0, y = 0},
            selected_operation = data.selected_operation or 
                (data.type == Constants.OPERATIONS_TYPE_COMPARE and Constants.COMPARE_OPERATION_EQUALS) or
                (data.type == Constants.OPERATIONS_TYPE_LOGIC and Constants.LOGIC_OPERATION_AND) or
                (data.type == Constants.OPERATIONS_TYPE_INVERT and 0) or  -- Invert doesn't use selected_operation
                Constants.MATH_OPERATION_ADD,  -- Default for math operations
            ending_value = nil,
            status = nil,
            -- Manual values
            input1_manual_value = data.input1_manual_value or "",
            input2_manual_value = data.input2_manual_value or ""
        }
        
    elseif data.category == Constants.NODE_CATEGORY_CONTROL then
        node = {
            id = data.id,
            category = data.category,
            pins = pins,
            type = data.type,
            position = data.position or {x = 0, y = 0},
            ending_value = nil,
            status = nil
        }
        
        -- Type-specific attributes
        if data.type == Constants.CONTROL_TYPE_SWITCH then
            -- Enhanced Select Control properties
            node.num_conditions = data.num_conditions or 1
            node.show_compare_input = data.show_compare_input or false
            -- Legacy manual values (for backward compatibility)
            node.condition_manual_value = data.condition_manual_value or ""
            node.true_manual_value = data.true_manual_value or ""
            node.false_manual_value = data.false_manual_value or ""
        elseif data.type == Constants.CONTROL_TYPE_TOGGLE then
            -- Manual values
            node.input_manual_value = data.input_manual_value or ""
            node.enabled_manual_value = data.enabled_manual_value or false
        elseif data.type == Constants.CONTROL_TYPE_COUNTER then
            -- Manual values
            node.max_manual_value = data.max_manual_value or "10"
            node.active_manual_value = data.active_manual_value or false
            node.restart_manual_value = data.restart_manual_value or false
            -- Runtime values
            node.current_count = data.current_count or 0
            node.delay_ms = data.delay_ms or 1000
            node.last_increment_time = data.last_increment_time
        elseif data.type == Constants.CONTROL_TYPE_CONDITION then
            -- Manual values
            node.condition_manual_value = data.condition_manual_value or ""
            node.true_manual_value = data.true_manual_value or ""
            node.false_manual_value = data.false_manual_value or ""
        end
        
    elseif data.category == Constants.NODE_CATEGORY_FOLLOWER then
        node = {
            id = data.id,
            category = data.category,
            pins = pins,
            type = data.type or Constants.FOLLOWER_TYPE_METHOD,
            position = data.position or {x = 0, y = 0},
            action_type = data.action_type,
            -- Method-specific
            selected_method_combo = data.selected_method_combo or 1,
            selected_method_signature = data.selected_method_signature,
            method_group_index = data.method_group_index,
            method_index = data.method_index,
            param_manual_values = data.param_manual_values or {},
            -- Field-specific
            selected_field_combo = data.selected_field_combo or 1,
            selected_field_signature = data.selected_field_signature,
            field_group_index = data.field_group_index,
            field_index = data.field_index,
            value_manual_input = data.value_manual_input or "",
            set_active = data.set_active or false,
            -- Array-specific
            selected_element_index = data.selected_element_index or 0,
            index_manual_value = "",
            -- Common
            starting_value = nil,
            ending_value = nil,
            status = nil
        }
        
        -- Operation nodes will be validated after parent connections are restored
    end
    
    return node
end

function Config.add_node_to_graph(node)
    table.insert(State.all_nodes, node)
end

function Config.deserialize_link(data, node_map)
    local from_node = node_map[data.from_node]
    local to_node = node_map[data.to_node]
    
    if not from_node or not to_node then
        Utils.show_info("Skipping link: nodes not found")
        return
    end
    
    -- Create link with the original ID from the config
    local link = {
        id = data.id,  -- Use the original link ID from config
        connection_type = data.connection_type,
        from_node = from_node.id,
        from_pin = data.from_pin,
        to_node = to_node.id,
        to_pin = data.to_pin,
        parameter_index = data.parameter_index,
        field_name = data.field_name
    }
    
    table.insert(State.all_links, link)
    State.link_map[link.id] = link  -- Add to hash map
    
    -- Update pin connection fields (CRITICAL for new pin system)
    local from_pin_info = State.pin_map[data.from_pin]
    local to_pin_info = State.pin_map[data.to_pin]
    
    if to_pin_info and to_pin_info.pin then
        -- Set the input pin's connection field (overwrite, should only be one)
        to_pin_info.pin.connection = { 
            node = from_node.id, 
            pin = data.from_pin, 
            link = link.id 
        }
    end
    
    if from_pin_info and from_pin_info.pin then
        -- Check if this connection already exists to prevent duplicates
        local connection_exists = false
        if from_pin_info.pin.connections then
            for _, conn in ipairs(from_pin_info.pin.connections) do
                if conn.node == to_node.id and conn.pin == data.to_pin then
                    connection_exists = true
                    break
                end
            end
        else
            from_pin_info.pin.connections = {}
        end
        
        -- Only add if it doesn't already exist
        if not connection_exists then
            table.insert(from_pin_info.pin.connections, { 
                node = to_node.id, 
                pin = data.to_pin, 
                link = link.id 
            })
        end
    end
    
    return link
end

-- ========================================
-- Utilities
-- ========================================

function Config.get_filename_without_extension(path)
    -- Extract filename from path
    local name = path:match("([^/\\]+)$") or path
    -- Remove extension
    return name:match("(.+)%..+$") or name
end

-- ========================================
-- Validation
-- ========================================

function Config.is_valid_filename(name)
    if not name or name == "" then return false end
    
    -- Check for invalid characters
    if name:match('[<>:"/\\|?*]') then return false end
    
    -- Check for path traversal
    if name:match('%.%.') then return false end
    
    -- Prevent "Data" as a config name (reserved for Data.json)
    if name:lower() == "data" then return false end
    
    return true
end

function Config.validate_config_data(config)
    if not config then return false end
    if not config.name or config.name == "" then return false end
    if config.nodes and type(config.nodes) ~= "table" then return false end
    if config.links and type(config.links) ~= "table" then return false end
    return true
end

-- ========================================
-- Data.json Implementation
-- ========================================

function Config.save_data_config()
    local data = {
        window_open = State.window_open
    }
    
    local file_path = "DevTester2/Data.json"
    local success = json.dump_file(file_path, data)
    
    if success then
        return true, nil
    else
        return false, "Failed to write Data.json"
    end
end

function Config.load_data_config()
    local file_path = "DevTester2/Data.json"
    
    local data = json.load_file(file_path)
    
    if not data then
        return false, "Failed to read Data.json or parse JSON"
    end
    
    -- Restore window state
    if data.window_open ~= nil then
        State.window_open = data.window_open
    end
    
    return true, nil
end

return Config
