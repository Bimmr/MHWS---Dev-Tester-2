-- EnumData Node Properties:
-- This node provides enum values that can be selected manually or received via input connections.
-- When connected to another EnumData node's output or a HookStarter's return output, it automatically detects and uses the source enum type.
-- The following properties define the state and configuration of an EnumData node:
--
-- Configuration:
-- - path: String - The full type path (e.g., "app.SomeEnum") of the enum type (auto-detected from connected path input or manual entry)
--
-- Input/Output Pins:
-- - path_input_attr: Number - Pin ID for the path input attribute (receives enum type connections for auto-detection)
-- - value_input_attr: Number - Pin ID for the value input attribute (receives enum values to select)
-- - output_attr: Number - Pin ID for the output attribute (provides selected enum value)
--
-- Enum Data:
-- - selected_enum_index: Number - Index of the currently selected enum value in the sorted display list
-- - enum_names: Array - Array of enum field names
-- - enum_values: Array - Array of enum field values (parallel to enum_names)
-- - enum_display_strings: Array - Display strings for the combo box (name = value format)
-- - sorted_to_original_index: Array - Mapping from sorted display indices to original enum indices
--
-- Connections:
-- - path_input_connection: NodeID - ID of the connected path input node (for auto-detecting enum types)
-- - value_input_connection: NodeID - ID of the connected value input node (for setting selected enum value)
--
-- Runtime Values:
-- - ending_value: Any - The currently selected enum value (output)

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseData = require("DevTester2.Datas.BaseData")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local EnumData = {}

local function generate_enum(typename)
    local t = sdk.find_type_definition(typename)
    if not t then
        return {}
    end
    local parent = t:get_parent_type()
    if not parent or parent:get_full_name() ~= "System.Enum" then
        return {}
    end
    local fields = t:get_fields()
    local enum = {}
    for i, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            local success, raw_value = pcall(function() return field:get_data(nil) end)
            if success then
                enum[name] = raw_value
            end
        end
    end
    return enum
end

function EnumData.render(node)
    
    -- Execute the node to update ending_value
    EnumData.execute(node)
    
    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Enum Data")
    imnodes.end_node_titlebar()

    -- Path input pin
    if not node.path_input_attr then
        node.path_input_attr = State.next_pin_id()
    end

    imnodes.begin_input_attribute(node.path_input_attr)
    -- Disable path input if there's a path input connection
    local path_connected = node.path_input_connection ~= nil
    if path_connected then
        imgui.begin_disabled()
    end
    local path_changed, new_path = imgui.input_text("Path", node.path or "")
    if path_changed then
        node.path = new_path
        node.selected_enum_index = 1
        node.enum_names = nil
        node.enum_values = nil
        node.enum_display_strings = nil
        node.sorted_to_original_index = nil
        State.mark_as_modified()
    end
    if path_connected then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Path is controlled by input connection")
        end
    end
    imnodes.end_input_attribute()
    if node.path and node.path ~= "" then
        if not node.enum_names or not node.enum_values or not node.enum_display_strings then
            local enum_table = generate_enum(node.path)
            node.enum_names = {}
            node.enum_values = {}
            node.enum_display_strings = {}
            for k, v in pairs(enum_table) do
                table.insert(node.enum_names, k)
                table.insert(node.enum_values, v)
            end
            
            -- Create display strings and sort by value
            local enum_items = {}
            for i, name in ipairs(node.enum_names) do
                local value = node.enum_values[i]
                table.insert(enum_items, {
                    name = name,
                    value = value,
                    display = tostring(value) .. ". " .. name,
                    original_index = i
                })
            end
            
            -- Sort by value (only if all values are numbers)
            local all_numeric = true
            for _, item in ipairs(enum_items) do
                if type(item.value) ~= "number" then
                    all_numeric = false
                    break
                end
            end
            
            if all_numeric then
                table.sort(enum_items, function(a, b) return a.value < b.value end)
            end
            
            -- Create sorted arrays
            node.enum_display_strings = {}
            node.sorted_to_original_index = {}
            for i, item in ipairs(enum_items) do
                table.insert(node.enum_display_strings, item.display)
                node.sorted_to_original_index[i] = item.original_index
            end
        end
        if #node.enum_display_strings > 0 then
            node.selected_enum_index = node.selected_enum_index or 1
            
            -- Value input pin
            if not node.value_input_attr then
                node.value_input_attr = State.next_pin_id()
            end
            imnodes.begin_input_attribute(node.value_input_attr)
            
            -- Disable value selection if there's a value input connection
            local value_connected = node.value_input_connection ~= nil
            if value_connected then
                imgui.begin_disabled()
            end
            local changed, new_index = imgui.combo("Value", node.selected_enum_index, node.enum_display_strings)
            if changed then
                node.selected_enum_index = new_index
                State.mark_as_modified()
            end
            if value_connected then
                imgui.end_disabled()
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Value is controlled by input connection")
                end
            end
            imnodes.end_input_attribute()
            if not node.output_attr then
                node.output_attr = State.next_pin_id()
            end
            imgui.spacing()
            imnodes.begin_output_attribute(node.output_attr)
            -- Get the original index for the selected sorted item
            local original_index = node.sorted_to_original_index[node.selected_enum_index]
            local display = tostring(node.enum_values[original_index]) .. ". " .. node.enum_names[original_index]
            local pos = Utils.get_right_cursor_pos(node.node_id, display)
            imgui.set_cursor_pos(pos)
            imgui.text(display)
            imnodes.end_output_attribute()
            -- node.ending_value = node.enum_names[original_index]  -- Moved to execute function
        else
            imgui.text_colored("No enum values found", Constants.COLOR_TEXT_WARNING)
        end
    end

    imgui.spacing()
    
    BaseData.render_action_buttons(node)
    BaseData.render_debug_info(node)
    imnodes.end_node()
    
    -- Reset appearance
    Nodes.reset_node_titlebar_color()
end

function EnumData.execute(node)
    -- Check if there's a path input connection for type detection
    local path_input_value = nil
    local input_type_name = nil
    if node.path_input_connection then
        local connected_node = Nodes.find_node_by_id(node.path_input_connection)
        if connected_node then
            -- Check if connected to a HookStarter with return value
            if connected_node.return_value and connected_node.return_type_full_name then
                input_type_name = connected_node.return_type_full_name
                path_input_value = connected_node.return_value
            elseif connected_node.ending_value and connected_node.ending_value_full_name then
                input_type_name = connected_node.ending_value_full_name
                path_input_value = connected_node.ending_value
            else
                -- Fallback to checking the input value's type
                path_input_value = Nodes.get_pin_value(node.path_input_attr)
                if path_input_value ~= nil then
                    local success, type_def = pcall(function() return path_input_value:get_type_definition() end)
                    if success and type_def then
                        local parent = type_def:get_parent_type()
                        if parent and parent:get_full_name() == "System.Enum" then
                            input_type_name = type_def:get_full_name()
                        end
                    elseif type(path_input_value) == "number" then
                        -- For primitive enum values, we can't determine the type, so we'll use the current path
                        input_type_name = node.path
                    end
                end
            end
        end
    end
    
    -- If we have an input type, update the path
    if input_type_name and input_type_name ~= node.path then
        node.path = input_type_name
        node.selected_enum_index = 1
        node.enum_names = nil
        node.enum_values = nil
        node.enum_display_strings = nil
        node.sorted_to_original_index = nil
        State.mark_as_modified()
    end
    
    -- Check if there's a value input connection for setting the selected value
    local value_input_value = nil
    if node.value_input_connection then
        value_input_value = Nodes.get_pin_value(node.value_input_attr)
    end
    
    -- If we have a value input and enum data, try to find the matching enum value
    if value_input_value ~= nil and node.enum_values and node.sorted_to_original_index then
        -- Find the enum value that matches the input
        local found_index = nil
        for sorted_idx, original_idx in ipairs(node.sorted_to_original_index) do
            if node.enum_values[original_idx] == value_input_value then
                found_index = sorted_idx
                break
            end
        end
        if found_index then
            node.selected_enum_index = found_index
        end
    end
    
    -- Set ending_value based on selected enum (original logic)
    if node.enum_names and node.enum_values and node.selected_enum_index and 
       node.sorted_to_original_index and node.selected_enum_index <= #node.sorted_to_original_index then
        local original_index = node.sorted_to_original_index[node.selected_enum_index]
        if original_index and node.enum_names[original_index] then
            node.ending_value = node.enum_values[original_index]  -- Output enum value instead of name
        else
            node.ending_value = nil
        end
    else
        node.ending_value = nil
    end
end

return EnumData
