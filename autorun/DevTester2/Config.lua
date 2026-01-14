-- DevTester v2.0 - Configuration System
-- Save/Load functionality for node graphs

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Constants = require("DevTester2.Constants")
local Utils = require("DevTester2.Utils")
local BaseFollower = require("DevTester2.Followers.BaseFollower")

-- Require all node types for serialization
local HookStarter = require("DevTester2.Starters.HookStarter")
local ManagedStarter = require("DevTester2.Starters.ManagedStarter")
local NativeStarter = require("DevTester2.Starters.NativeStarter")
local PlayerStarter = require("DevTester2.Starters.PlayerStarter")
local TypeStarter = require("DevTester2.Starters.TypeStarter")

local PrimitiveData = require("DevTester2.Datas.PrimitiveData")
local EnumData = require("DevTester2.Datas.EnumData")
local VariableData = require("DevTester2.Datas.VariableData")

local MathOperation = require("DevTester2.Operations.MathOperation")
local CompareOperation = require("DevTester2.Operations.CompareOperation")
local LogicOperation = require("DevTester2.Operations.LogicOperation")
local InvertOperation = require("DevTester2.Operations.InvertOperation")

local SwitchControl = require("DevTester2.Control.SwitchControl")
local ToggleControl = require("DevTester2.Control.ToggleControl")
local CounterControl = require("DevTester2.Control.CounterControl")
local ConditionControl = require("DevTester2.Control.ConditionControl")

local MethodFollower = require("DevTester2.Followers.MethodFollower")
local FieldFollower = require("DevTester2.Followers.FieldFollower")
local ArrayFollower = require("DevTester2.Followers.ArrayFollower")

local Label = require("DevTester2.Utility.Label")
local HistoryBuffer = require("DevTester2.Utility.HistoryBuffer")
local CallBuffer = require("DevTester2.Utility.CallBuffer")

local json = json
local fs = fs
local sdk = sdk

local Config = {}

-- ========================================
-- Shared Pin Serialization Utilities
-- ========================================

function Config.serialize_pins(pins)
    local data = { inputs = {}, outputs = {} }
    
    if pins then
        for _, pin in ipairs(pins.inputs) do
            table.insert(data.inputs, {
                id = pin.id,
                name = pin.name,
                value = pin.value,
                connection = pin.connection
            })
        end
        for _, pin in ipairs(pins.outputs) do
            table.insert(data.outputs, {
                id = pin.id,
                name = pin.name,
                value = pin.value,
                connections = pin.connections
            })
        end
    end
    
    return data
end

function Config.deserialize_pins(data, node_id)
    local pins = { inputs = {}, outputs = {} }
    
    if data then
        if data.inputs then
            for _, pin_data in ipairs(data.inputs) do
                local pin = {
                    id = pin_data.id,
                    name = pin_data.name,
                    value = pin_data.value,
                    connection = pin_data.connection
                }
                table.insert(pins.inputs, pin)
                State.pin_map[pin.id] = { node_id = node_id, pin = pin }
            end
        end
        if data.outputs then
            for _, pin_data in ipairs(data.outputs) do
                local pin = {
                    id = pin_data.id,
                    name = pin_data.name,
                    value = pin_data.value,
                    connections = pin_data.connections or {}
                }
                table.insert(pins.outputs, pin)
                State.pin_map[pin.id] = { node_id = node_id, pin = pin }
            end
        end
    end
    
    return pins
end

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
    -- Dispatch to appropriate node type's serialize method
    if node.category == Constants.NODE_CATEGORY_STARTER then
        if node.type == Constants.STARTER_TYPE_HOOK then
            return HookStarter.serialize(node, Config)
        elseif node.type == Constants.STARTER_TYPE_MANAGED then
            return ManagedStarter.serialize(node, Config)
        elseif node.type == Constants.STARTER_TYPE_NATIVE then
            return NativeStarter.serialize(node, Config)
        elseif node.type == Constants.STARTER_TYPE_PLAYER then
            return PlayerStarter.serialize(node, Config)
        elseif node.type == Constants.STARTER_TYPE_TYPE then
            return TypeStarter.serialize(node, Config)
        end
    elseif node.category == Constants.NODE_CATEGORY_DATA then
        if node.type == Constants.DATA_TYPE_PRIMITIVE then
            return PrimitiveData.serialize(node, Config)
        elseif node.type == Constants.DATA_TYPE_ENUM then
            return EnumData.serialize(node, Config)
        elseif node.type == Constants.DATA_TYPE_VARIABLE then
            return VariableData.serialize(node, Config)
        end
    elseif node.category == Constants.NODE_CATEGORY_OPERATIONS then
        if node.type == Constants.OPERATIONS_TYPE_MATH then
            return MathOperation.serialize(node, Config)
        elseif node.type == Constants.OPERATIONS_TYPE_COMPARE then
            return CompareOperation.serialize(node, Config)
        elseif node.type == Constants.OPERATIONS_TYPE_LOGIC then
            return LogicOperation.serialize(node, Config)
        elseif node.type == Constants.OPERATIONS_TYPE_INVERT then
            return InvertOperation.serialize(node, Config)
        end
    elseif node.category == Constants.NODE_CATEGORY_CONTROL then
        if node.type == Constants.CONTROL_TYPE_SWITCH then
            return SwitchControl.serialize(node, Config)
        elseif node.type == Constants.CONTROL_TYPE_TOGGLE then
            return ToggleControl.serialize(node, Config)
        elseif node.type == Constants.CONTROL_TYPE_COUNTER then
            return CounterControl.serialize(node, Config)
        elseif node.type == Constants.CONTROL_TYPE_CONDITION then
            return ConditionControl.serialize(node, Config)
        end
    elseif node.category == Constants.NODE_CATEGORY_FOLLOWER then
        if node.type == Constants.FOLLOWER_TYPE_METHOD then
            return MethodFollower.serialize(node, Config)
        elseif node.type == Constants.FOLLOWER_TYPE_FIELD then
            return FieldFollower.serialize(node, Config)
        elseif node.type == Constants.FOLLOWER_TYPE_ARRAY then
            return ArrayFollower.serialize(node, Config)
        end
    elseif node.category == Constants.NODE_CATEGORY_UTILITY then
        if node.type == Constants.UTILITY_TYPE_LABEL then
            return Label.serialize(node, Config)
        elseif node.type == Constants.UTILITY_TYPE_HISTORY_BUFFER then
            return HistoryBuffer.serialize(node, Config)
        elseif node.type == Constants.UTILITY_TYPE_CALL_BUFFER then
            return CallBuffer.serialize(node, Config)
        end
    end
    
    -- Fallback - should never reach here
    log.debug("Warning: Unknown node type during serialization")
    return {
        id = node.id,
        category = node.category,
        type = node.type,
        position = {x = node.position.x, y = node.position.y},
        pins = Config.serialize_pins(node.pins)
    }
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
    State.current_config_description = config.description ~= nil and config.description or ""
    
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
    -- Dispatch to appropriate node type's deserialize method
    if data.category == Constants.NODE_CATEGORY_STARTER then
        if data.type == Constants.STARTER_TYPE_HOOK then
            return HookStarter.deserialize(data, Config)
        elseif data.type == Constants.STARTER_TYPE_MANAGED then
            return ManagedStarter.deserialize(data, Config)
        elseif data.type == Constants.STARTER_TYPE_NATIVE then
            return NativeStarter.deserialize(data, Config)
        elseif data.type == Constants.STARTER_TYPE_PLAYER then
            return PlayerStarter.deserialize(data, Config)
        elseif data.type == Constants.STARTER_TYPE_TYPE then
            return TypeStarter.deserialize(data, Config)
        end
    elseif data.category == Constants.NODE_CATEGORY_DATA then
        if data.type == Constants.DATA_TYPE_PRIMITIVE then
            return PrimitiveData.deserialize(data, Config)
        elseif data.type == Constants.DATA_TYPE_ENUM then
            return EnumData.deserialize(data, Config)
        elseif data.type == Constants.DATA_TYPE_VARIABLE then
            return VariableData.deserialize(data, Config)
        end
    elseif data.category == Constants.NODE_CATEGORY_OPERATIONS then
        if data.type == Constants.OPERATIONS_TYPE_MATH then
            return MathOperation.deserialize(data, Config)
        elseif data.type == Constants.OPERATIONS_TYPE_COMPARE then
            return CompareOperation.deserialize(data, Config)
        elseif data.type == Constants.OPERATIONS_TYPE_LOGIC then
            return LogicOperation.deserialize(data, Config)
        elseif data.type == Constants.OPERATIONS_TYPE_INVERT then
            return InvertOperation.deserialize(data, Config)
        end
    elseif data.category == Constants.NODE_CATEGORY_CONTROL then
        if data.type == Constants.CONTROL_TYPE_SWITCH then
            return SwitchControl.deserialize(data, Config)
        elseif data.type == Constants.CONTROL_TYPE_TOGGLE then
            return ToggleControl.deserialize(data, Config)
        elseif data.type == Constants.CONTROL_TYPE_COUNTER then
            return CounterControl.deserialize(data, Config)
        elseif data.type == Constants.CONTROL_TYPE_CONDITION then
            return ConditionControl.deserialize(data, Config)
        end
    elseif data.category == Constants.NODE_CATEGORY_FOLLOWER then
        if data.type == Constants.FOLLOWER_TYPE_METHOD then
            return MethodFollower.deserialize(data, Config)
        elseif data.type == Constants.FOLLOWER_TYPE_FIELD then
            return FieldFollower.deserialize(data, Config)
        elseif data.type == Constants.FOLLOWER_TYPE_ARRAY then
            return ArrayFollower.deserialize(data, Config)
        end
    elseif data.category == Constants.NODE_CATEGORY_UTILITY then
        if data.type == Constants.UTILITY_TYPE_LABEL then
            return Label.deserialize(data, Config)
        elseif data.type == Constants.UTILITY_TYPE_HISTORY_BUFFER then
            return HistoryBuffer.deserialize(data, Config)
        elseif data.type == Constants.UTILITY_TYPE_CALL_BUFFER then
            return CallBuffer.deserialize(data, Config)
        end
    end
    
    -- Fallback - should never reach here
    log.debug("Warning: Unknown node type during deserialization")
    return {
        id = data.id,
        category = data.category,
        type = data.type,
        position = data.position or {x = 0, y = 0},
        ending_value = nil,
        status = nil,
        pins = Config.deserialize_pins(data.pins, data.id)
    }
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
