-- VariableData Node Properties:
-- This node provides access to persistent variables that can be set, get, or reset.
-- The following properties define the state and configuration of a VariableData node:
--
-- Configuration:
-- - variable_name: String - Name of the variable in the global variables store
-- - default_value: String - Default value as string (parsed to primitive when used)
--
-- Pins:
-- - pins.inputs[1]: "input" - Receives values to set the variable (optional)
-- - pins.outputs[1]: "output" - Provides current variable value (optional)
--
-- State:
-- - pending_reset: Boolean - Whether a reset operation was requested this frame
--
-- Runtime Values:
-- - ending_value: Any - Current value of the variable (or default if not set)

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseData = require("DevTester2.Datas.BaseData")
local imgui = imgui
local imnodes = imnodes

local VariableData = {}

function VariableData.render(node)
    
    -- Execute the node to update ending_value based on inputs
    VariableData.execute(node)
    
    -- Ensure pins exist
    if #node.pins.inputs == 0 then
        Nodes.add_input_pin(node, "input", nil)
    end
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    local input_pin = node.pins.inputs[1]
    local output_pin = node.pins.outputs[1]
    
    imnodes.begin_node(node.id)
    imnodes.begin_node_titlebar()
    imgui.text("Variable")
    imnodes.end_node_titlebar()

    -- Variable name input
    if not node.variable_name then
        node.variable_name = ""
    end
    
    -- Collect existing variable names for the combo
    local items = {}
    for name, _ in pairs(State.variables) do
        table.insert(items, name)
    end
    
    -- Find current index
    local current_index = 0
    for i, name in ipairs(items) do
        if name == node.variable_name then
            current_index = i
            break
        end
    end
    
   local changed, new_index, new_items = Utils.hybrid_combo_with_manage("Name", current_index, items)
    if changed then
        items = new_items

        -- Remove variables from State.variables that are no longer in items
        local item_set = {}
        for _, name in ipairs(items) do
            item_set[name] = true
        end
        for name, _ in pairs(State.variables) do
            if not item_set[name] then
            State.variables[name] = nil
            end
        end
        node.variable_name = items[new_index] or ""
        State.variables[node.variable_name] = State.variables[node.variable_name] or {value = nil, persistent = true}
        State.mark_as_modified()
    end

    -- Check connection states
    local input_connected = input_pin.connection ~= nil
    local output_connected = Nodes.is_output_connected(node)
    local neutral_mode = not input_connected and not output_connected
    local get_mode = output_connected and not input_connected
    local set_mode = input_connected and not output_connected

    -- Get mode: Show output attribute with current variable value and tooltip
    local current_value = VariableData.get_variable_value(node.variable_name, node.default_value)
    output_pin.value = current_value
    node.ending_value = current_value
        
    -- Create tooltip for output
    local tooltip_text = nil
    if current_value ~= nil then
        local value_type = type(current_value)
        local type_description = "Unknown"
        if value_type == "number" then
            type_description = "Number"
        elseif value_type == "boolean" then
            type_description = "Boolean"
        elseif value_type == "string" then
            type_description = "String"
        end
        tooltip_text = string.format("Name: %s\nType: %s\nValue: %s",
            node.variable_name or "None",
            type_description,
            tostring(current_value))
    else
        tooltip_text = string.format("Variable\nName: %s\nValue: nil",
            node.variable_name or "None")
    end
    if node.variable_name ~= "" then
        Nodes.add_context_menu_option(node, "Copy variable name", node.variable_name)
        Nodes.add_context_menu_option(node, "Copy variable value", tostring(current_value))
    end

    -- Default value input with Reset button (only show in neutral or get mode)
    if neutral_mode or get_mode then
        if not node.default_value then
            node.default_value = ""
        end
        local default_changed, new_default = imgui.input_text("Default Value", node.default_value)
        if default_changed then
            node.default_value = new_default
            State.mark_as_modified()
            -- Update ending_value when default changes
            node.ending_value = Utils.parse_primitive_value(node.default_value)
        end

    end
    imgui.spacing()

    -- Value display/input based on mode
    if neutral_mode then
        -- Neutral mode: Show input and output
        imnodes.begin_input_attribute(input_pin.id)
        
        local display_value = tostring(node.ending_value or "nil")
        imgui.begin_disabled()
        imgui.input_text("Value", display_value)
        if imgui.is_item_hovered(1024) and tooltip_text then
            imgui.set_tooltip(tooltip_text)
        end
        imgui.end_disabled()

        imnodes.end_input_attribute()
        imgui.same_line()

        imnodes.begin_output_attribute(output_pin.id)
        imgui.text("")
        imnodes.end_output_attribute()
        
    elseif get_mode then
        -- Get mode: Show output only
        imnodes.begin_output_attribute(output_pin.id)
        local display_value = tostring(current_value or "nil")
        imgui.begin_disabled()
        imgui.input_text("Value", display_value)
        if imgui.is_item_hovered(1024) and tooltip_text then
            imgui.set_tooltip(tooltip_text)
        end
        imgui.end_disabled()
        imnodes.end_output_attribute()
        
    elseif set_mode then
        -- Set mode: Show input only
        imnodes.begin_input_attribute(input_pin.id)
        
        -- Display connected value (disabled)
        local connected_value = Nodes.get_input_pin_value(node, 1)
        local display_value = "Connected"
        if connected_value ~= nil then
            display_value = tostring(connected_value)
        end
        imgui.begin_disabled()
        imgui.input_text("Value", display_value) 
        if imgui.is_item_hovered(1024) and tooltip_text then
            imgui.set_tooltip(tooltip_text)
        end
        imgui.end_disabled()
        
        imnodes.end_input_attribute()
    end
    
    if neutral_mode or get_mode then
        -- Reset button
        imgui.same_line()
        if node.default_value and node.ending_value == nil then
            if imgui.button("Set") then
                -- Set variable to default value
                local default_parsed = Utils.parse_primitive_value(node.default_value)
                VariableData.set_variable_value(node.variable_name, default_parsed, node.persistent)
                State.mark_as_modified()
                -- Update ending_value
                node.ending_value = default_parsed
            end
        else
            if imgui.button("Reset") then
                -- Set reset flag instead of immediately resetting
                node.pending_reset = true
                State.mark_as_modified()
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Reset variable to default value")
            end
        end
    end

    BaseData.render_action_buttons(node)
    BaseData.render_debug_info(node)

    imnodes.end_node()

end

-- ========================================
-- Variable Management Functions
-- ========================================

function VariableData.get_variable_value(variable_name, default_value)
    if not variable_name or variable_name == "" then
        -- No variable name, return parsed default
        return Utils.parse_primitive_value(default_value)
    end

    -- Check if variable exists in storage
    local var_data = State.variables[variable_name]
    if var_data then
        return var_data.value
    else
        -- Variable doesn't exist, return parsed default
        return Utils.parse_primitive_value(default_value)
    end
end

function VariableData.set_variable_value(variable_name, value)
    if not variable_name or variable_name == "" then
        return -- No variable name, ignore
    end

    -- Store in variables table
    State.variables[variable_name] = {
        value = value,
        persistent = true
    }
end

function VariableData.reset_to_default(node)
    if not node.variable_name or node.variable_name == "" then
        return -- No variable name, nothing to reset
    end
    
    -- Mark this variable as reset this frame to prevent updates
    State.reset_variables[node.variable_name] = true
    
    -- Reset the variable to nothing (nil)
    State.variables[node.variable_name] = {value = node.default_value, persistent = true}
end

function VariableData.update_from_input(node, input_value)
    if input_value ~= nil then
        -- Check if this variable was reset this frame - if so, don't update it
        if State.reset_variables[node.variable_name] then
            -- Variable was reset this frame, don't override the reset
            State.reset_variables[node.variable_name] = nil  -- Clear the flag
            return VariableData.get_variable_value(node.variable_name, node.default_value)
        end
        
        -- Set input overwrites the variable
        VariableData.set_variable_value(node.variable_name, input_value, true)
    end
    -- Return current value (either the input that was just set, or existing value)
    return VariableData.get_variable_value(node.variable_name, node.default_value)
end

function VariableData.execute(node)
    -- Check if reset was requested - this takes precedence over input processing
    if node.pending_reset then
        VariableData.reset_to_default(node)
        node.pending_reset = false
        -- After reset, return the default value
        node.ending_value = VariableData.get_variable_value(node.variable_name, node.default_value)
        return
    end
    
    -- Check if there's an input via pins
    local input_value = nil
    if #node.pins.inputs > 0 then
        input_value = Nodes.get_input_pin_value(node, 1)
    end
    
    -- Fallback to legacy connection check for nodes not yet migrated
    if not input_value and node.input_connection then
        local connected_node = Nodes.find_node_by_id(node.input_connection)
        if connected_node and connected_node.ending_value ~= nil then
            input_value = connected_node.ending_value
        end
    elseif not input_value and node.input_manual_value and node.input_manual_value ~= "" then
        -- Use manual input value if no connection
        input_value = Utils.parse_primitive_value(node.input_manual_value)
    end
    
    -- Update the variable and get the current value
    node.ending_value = VariableData.update_from_input(node, input_value)
end

return VariableData
