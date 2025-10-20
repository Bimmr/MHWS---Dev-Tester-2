-- DevTester v2.0 - Configuration System
-- Save/Load functionality for node graphs

local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local json = json
local fs = fs
local sdk = sdk

local Config = {}

-- ========================================
-- Configuration Directory
-- ========================================

function Config.get_config_directory()
    return "DevTester2/"
end

-- ========================================
-- Save Implementation
-- ========================================

function Config.save_configuration(name, description)
    -- Validate name
    if not Helpers.is_valid_filename(name) then
        return false, "Invalid filename"
    end
    
    -- Build config data
    local config = {
        name = name,
        description = description or "",
        saved_date = os.date("%Y-%m-%d %H:%M:%S"),
        nodes = Config.serialize_all_nodes(),
        links = Config.serialize_all_links(),
        next_node_id = State.next_node_id,
        next_link_id = State.next_link_id,
        next_pin_id = State.next_pin_id
    }
    
    -- Save using REFramework's json.dump_file
    local file_path = Config.get_config_directory() .. name .. ".json"
    local success = json.dump_file(file_path, config)
    
    if success then
        State.current_config_name = name
        Helpers.mark_as_saved()
        return true, nil
    else
        return false, "Failed to write file"
    end
end

function Config.serialize_all_nodes()
    local nodes = {}
    
    -- Serialize starter nodes
    for _, node in ipairs(State.starter_nodes) do
        table.insert(nodes, Config.serialize_node(node))
    end
    
    -- Serialize operation nodes
    for _, node in ipairs(State.all_nodes) do
        table.insert(nodes, Config.serialize_node(node))
    end
    
    return nodes
end

function Config.serialize_node(node)
    local data = {
        id = node.id,
        node_id = node.node_id,
        node_category = node.node_category,
        position = {x = node.position.x, y = node.position.y},
        input_attr = node.input_attr,
        output_attr = node.output_attr
    }
    
    -- Add type-specific data
    if node.node_category == "starter" then
        data.type = node.type
        data.path = node.path
        -- Parameter support for starters that need it (like Native)
        data.param_connections = node.param_connections
        data.param_input_attrs = node.param_input_attrs
        data.param_manual_values = node.param_manual_values
        
        if node.type == 2 then -- Hook
            data.method_name = node.method_name
            data.selected_method_combo = node.selected_method_combo
            data.method_group_index = node.method_group_index
            data.method_index = node.method_index
            data.pre_hook_result = node.pre_hook_result
            data.return_type_name = node.return_type_name
            data.return_type_full_name = node.return_type_full_name
            data.is_initialized = node.is_initialized
            data.return_override_manual = node.return_override_manual
            data.return_override_connection = node.return_override_connection
            data.return_override_attr = node.return_override_attr
            data.actual_return_value = node.actual_return_value
            data.is_return_overridden = node.is_return_overridden
        elseif node.type == 5 then -- Primitive
            data.value = node.value
        end
    elseif node.node_category == "operation" then
        data.parent_node_id = node.parent_node_id
        data.operation = node.operation
        data.action_type = node.action_type
        
        if node.operation == 0 then -- Method
            data.selected_method_combo = node.selected_method_combo
            data.method_group_index = node.method_group_index
            data.method_index = node.method_index
            if node.action_type == 1 and node.param_manual_values then -- Call
                data.param_manual_values = node.param_manual_values
            end
        elseif node.operation == 1 then -- Field
            data.selected_field_combo = node.selected_field_combo
            data.field_group_index = node.field_group_index
            data.field_index = node.field_index
            if node.action_type == 1 and node.value_manual_input then -- Set
                data.value_manual_input = node.value_manual_input
            end
        elseif node.operation == 2 then -- Array
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
    if not Helpers.validate_config_data(config) then
        return false, "Invalid configuration file"
    end
    
    -- Clear existing nodes
    Helpers.clear_all_nodes()
    
    -- Deserialize nodes
    local node_map = {} -- Map old IDs to new node instances
    for _, node_data in ipairs(config.nodes or {}) do
        local node = Config.deserialize_node(node_data)
        if node then
            -- Ensure all pin IDs exist for proper link restoration
            Helpers.ensure_node_pin_ids(node)
            
            -- Special handling for operations: if the config data indicates this node should have an output
            -- (either from saved output_attr or from operation type), ensure it exists
            if node.node_category == "operation" and not node.output_attr then
                -- Check if this operation type should have output
                if node.operation == 0 or node.operation == 2 or (node.operation == 1 and node.action_type == 0) then
                    node.output_attr = Helpers.next_pin_id()
                end
            end
            
            node_map[node_data.id] = node
            -- Add node to appropriate state array
            if node.node_category == "starter" then
                table.insert(State.starter_nodes, node)
            elseif node.node_category == "operation" then
                table.insert(State.all_nodes, node)
            end
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
            imnodes.set_node_editor_space_pos(node.node_id, node_data.position.x, node_data.position.y)
            -- Mark as positioned so render function doesn't reposition
            State.nodes_positioned = State.nodes_positioned or {}
            State.nodes_positioned[node.node_id] = true
        end
    end
    
    -- Update state
    State.current_config_name = config.name
    State.current_config_description = config.description or ""
    State.next_node_id = config.next_node_id or 1
    State.next_link_id = config.next_link_id or 1
    State.next_pin_id = config.next_pin_id or 1
    Helpers.mark_as_saved()
    
    return true, nil
end

function Config.deserialize_node(data)
    local node
    
    if data.node_category == "starter" then
        node = {
            id = data.id,
            node_id = data.node_id or data.id,
            node_category = "starter",
            type = data.type,
            path = data.path,
            position = data.position or {x = 0, y = 0},
            input_attr = data.input_attr,
            output_attr = data.output_attr,
            ending_value = nil,
            status = nil,
            -- Parameter support for starters that need it (like Native)
            param_connections = data.param_connections or {},
            param_input_attrs = data.param_input_attrs or {},
            param_manual_values = data.param_manual_values or {},
            -- Hook-specific
            method_name = data.method_name or "",
            selected_method_combo = data.selected_method_combo,
            method_group_index = data.method_group_index,
            method_index = data.method_index,
            pre_hook_result = data.pre_hook_result or "CALL_ORIGINAL",
            return_type_name = data.return_type_name,
            return_type_full_name = data.return_type_full_name,
            hook_id = nil,
            is_initialized = data.is_initialized or false,
            return_override_manual = data.return_override_manual,
            return_override_connection = data.return_override_connection,
            return_override_attr = data.return_override_attr,
            actual_return_value = data.actual_return_value,
            is_return_overridden = data.is_return_overridden or false,
            -- Value-specific
            value = data.value or ""
        }
        
        -- Validate and restore result
        Helpers.validate_and_restore_starter_node(node)
        
    elseif data.node_category == "operation" then
        node = {
            id = data.id,
            node_id = data.node_id or data.id,
            node_category = "operation",
            position = data.position or {x = 0, y = 0},
            input_attr = data.input_attr,
            output_attr = data.output_attr,
            parent_node_id = data.parent_node_id,
            operation = data.operation,
            action_type = data.action_type,
            -- Method-specific
            selected_method_combo = data.selected_method_combo or 1,
            method_group_index = data.method_group_index,
            method_index = data.method_index,
            param_manual_values = data.param_manual_values or {},
            param_connections = {},
            param_input_attrs = {},
            -- Field-specific
            selected_field_combo = data.selected_field_combo or 1,
            field_group_index = data.field_group_index,
            field_index = data.field_index,
            value_manual_input = data.value_manual_input or "",
            value_connection = nil,
            value_input_attr = nil,
            -- Array-specific
            selected_element_index = data.selected_element_index or 0,
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
    if node.node_category == "starter" then
        table.insert(State.starter_nodes, node)
    elseif node.node_category == "operation" then
        table.insert(State.all_nodes, node)
    end
end

function Config.deserialize_link(data, node_map)
    local from_node = node_map[data.from_node]
    local to_node = node_map[data.to_node]
    
    if not from_node or not to_node then
        Helpers.show_info("Skipping link: nodes not found")
        return
    end
    
    -- Create link
    local link = {
        id = Helpers.next_link_id(),
        connection_type = data.connection_type,
        from_node = from_node.id,
        from_pin = data.from_pin,
        to_node = to_node.id,
        to_pin = data.to_pin,
        parameter_index = data.parameter_index,
        field_name = data.field_name
    }
    
    table.insert(State.all_links, link)
    
    -- Update node connections
    if data.connection_type == "parameter" and data.parameter_index then
        to_node.param_connections[data.parameter_index] = from_node.id
    elseif data.connection_type == "value" then
        to_node.value_connection = from_node.id
    elseif data.connection_type == "main" then
        to_node.parent_node_id = from_node.id
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

return Config
