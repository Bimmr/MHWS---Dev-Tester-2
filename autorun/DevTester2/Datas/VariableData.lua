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
    
    imnodes.begin_node(node.node_id)
    imnodes.begin_node_titlebar()
    imgui.text("Variable")
    imnodes.end_node_titlebar()

    -- Variable name input
    if not node.variable_name then
        node.variable_name = ""
    end
    local changed, new_name = imgui.input_text("Name", node.variable_name)
    if changed then
        node.variable_name = new_name
        State.mark_as_modified()
    end

    -- Persistent checkbox (hidden for now)
    -- local persistent_changed, new_persistent = imgui.checkbox("Persistent", node.persistent or false)
    -- if persistent_changed then
    --     node.persistent = new_persistent
    --     State.mark_as_modified()
    -- end

    -- Check connection states
    local input_connected = node.input_connection ~= nil
    local output_connected = Nodes.is_output_connected(node)
    local neutral_mode = not input_connected and not output_connected
    local get_mode = output_connected and not input_connected
    local set_mode = input_connected and not output_connected

    -- Get mode: Show output attribute with current variable value and tooltip
        local current_value = VariableData.get_variable_value(node.variable_name, node.default_value)
        
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
            tooltip_text = string.format("Variable Value\nName: %s\nType: %s\nValue: %s",
                node.variable_name or "None",
                type_description,
                tostring(current_value))
        else
            tooltip_text = string.format("Variable\nName: %s\nValue: nil",
                node.variable_name or "None")
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

        -- Neutral mode: Show input attribute with disabled display of connected value
        if not node.input_attr then
            node.input_attr = State.next_pin_id()
        end

        imnodes.begin_input_attribute(node.input_attr)
        
        if not node.output_attr then
            node.output_attr = State.next_pin_id()
        end
        local display_value = tostring(node.ending_value or "nil")
        imgui.begin_disabled()
        imgui.input_text("Value", display_value)
        if imgui.is_item_hovered(1024) and tooltip_text then
            imgui.set_tooltip(tooltip_text)
        end
        imgui.end_disabled()

        imnodes.end_input_attribute()
        imgui.same_line()

        -- Neutral mode: Show output attribute with ending_valu
        imnodes.begin_output_attribute(node.output_attr)
        imgui.text("")
        imnodes.end_output_attribute()
        
    elseif get_mode then
        
        if not node.output_attr then
            node.output_attr = State.next_pin_id()
        end
        imnodes.begin_output_attribute(node.output_attr)
        local display_value = tostring(current_value or "nil")
        imgui.begin_disabled()
        imgui.input_text("Value", display_value)
        if imgui.is_item_hovered(1024) and tooltip_text then
            imgui.set_tooltip(tooltip_text)
        end
        imgui.end_disabled()
        imnodes.end_output_attribute()
        
    elseif set_mode then
        -- Set mode: Show input attribute with disabled display of connected value
        if not node.input_attr then
            node.input_attr = State.next_pin_id()
        end
        imnodes.begin_input_attribute(node.input_attr)
        
        -- Display connected value (disabled)
        local connected_node = Nodes.find_node_by_id(node.input_connection)
        local display_value = "Connected"
        if connected_node and connected_node.ending_value ~= nil then
            display_value = tostring(connected_node.ending_value)
        end
        imgui.begin_disabled()
        imgui.input_text("Value", display_value)
        imgui.end_disabled()
        
        imnodes.end_input_attribute()
    end
    if neutral_mode or get_mode then
        -- Reset button
        imgui.same_line()
        if imgui.button("Reset") then
            -- Set reset flag instead of immediately resetting
            node.pending_reset = true
            State.mark_as_modified()
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Reset variable to default value")
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

function VariableData.set_variable_value(variable_name, value, persistent)
    if not variable_name or variable_name == "" then
        return -- No variable name, ignore
    end

    -- Store in variables table
    State.variables[variable_name] = {
        value = value,
        persistent = persistent or false
    }
end

function VariableData.reset_to_default(node)
    if not node.variable_name or node.variable_name == "" then
        return -- No variable name, nothing to reset
    end
    
    -- Mark this variable as reset this frame to prevent updates
    State.reset_variables[node.variable_name] = true
    
    -- Remove the variable from State.variables to reset it to default state
    -- This allows all nodes sharing this variable name to fall back to their individual default_value
    State.variables[node.variable_name] = nil
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
        VariableData.set_variable_value(node.variable_name, input_value, node.persistent)
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
    
    -- Check if there's an input connection
    local input_value = nil
    if node.input_connection then
        local connected_node = Nodes.find_node_by_id(node.input_connection)
        if connected_node and connected_node.ending_value ~= nil then
            input_value = connected_node.ending_value
        end
    elseif node.input_manual_value and node.input_manual_value ~= "" then
        -- Use manual input value if no connection
        input_value = Utils.parse_primitive_value(node.input_manual_value)
    end
    
    -- Update the variable and get the current value
    node.ending_value = VariableData.update_from_input(node, input_value)
end

return VariableData
