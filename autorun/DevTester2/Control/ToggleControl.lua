-- DevTester v2.0 - Toggle Control
-- Control node that toggles data flow on/off based on user interaction

-- ToggleControl Node Properties:
-- This node controls data flow with a persistent on/off toggle.
--
-- Pins:
-- - pins.inputs[1]: "input" - The input value to control
-- - pins.inputs[2]: "enabled" - Boolean control for enabling/disabling output
-- - pins.outputs[1]: "output" - The output value (input if enabled, nil if disabled)
--
-- Manual Input Values:
-- - input_manual_value: String - Manual text input for value when not connected
-- - enabled_manual_value: Boolean - Manual checkbox value for enabled when not connected
--
-- Runtime Values:
-- - ending_value: Any - The output value (input_value if enabled, nil if disabled)
--
-- Inherits status property from BaseControl for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseControl = require("DevTester2.Control.BaseControl")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local ToggleControl = {}

-- ========================================
-- Toggle Control Node
-- ========================================

function ToggleControl.execute(node)
    -- Get input values using pin system
    local input_pin = node.pins.inputs[1]
    local enabled_pin = node.pins.inputs[2]
    
    -- Get input value - use manual value if not connected
    local input_value
    if input_pin.connection then
        input_value = Nodes.get_input_pin_value(node, 1)
    else
        input_value = node.input_manual_value
    end
    
    -- Get enabled value - use manual value if not connected
    local enabled_value
    if enabled_pin.connection then
        enabled_value = Nodes.get_input_pin_value(node, 2)
    else
        enabled_value = node.enabled_manual_value
    end

    -- Determine enabled state (convert to boolean)
    local is_enabled = not not enabled_value

    -- Apply toggle logic
    local result = nil
    if is_enabled then
        result = input_value
        node.status = "Enabled"
    else
        result = nil
        node.status = "Disabled"
    end

    -- Store the result
    node.ending_value = result
    return result
end

function ToggleControl.render(node)
    -- Ensure pins exist (2 inputs, 1 output)
    if #node.pins.inputs < 2 then
        if #node.pins.inputs == 0 then
            Nodes.add_input_pin(node, "input", nil)
        end
        if #node.pins.inputs == 1 then
            Nodes.add_input_pin(node, "enabled", nil)
        end
    end
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    local input_pin = node.pins.inputs[1]
    local enabled_pin = node.pins.inputs[2]
    local output_pin = node.pins.outputs[1]

    imnodes.begin_node(node.id)

    imnodes.begin_node_titlebar()
    imgui.text("Toggle")
    imnodes.end_node_titlebar()

    -- Execute to update ending_value
    ToggleControl.execute(node)

    -- Input pin
    imnodes.begin_input_attribute(input_pin.id)
    local has_input_connection = input_pin.connection ~= nil
    if has_input_connection then
        -- Look up connected pin via State.pin_map
        local source_pin_info = State.pin_map[input_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        local display_value = connected_value ~= nil and tostring(connected_value) or "nil"
        imgui.begin_disabled()
        imgui.input_text("Input", display_value)
        imgui.end_disabled()
    else
        local input_changed, new_value = imgui.input_text("Input", node.input_manual_value or "")
        if input_changed then
            node.input_manual_value = new_value
            State.mark_as_modified()
        end
    end
    imnodes.end_input_attribute()

    -- Enabled pin (checkbox)
    imnodes.begin_input_attribute(enabled_pin.id)
    local has_enabled_connection = enabled_pin.connection ~= nil
    if has_enabled_connection then
        -- Look up connected pin via State.pin_map
        local source_pin_info = State.pin_map[enabled_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        local display_value = not not connected_value
        imgui.begin_disabled()
        imgui.checkbox("Enabled", display_value)
        imgui.end_disabled()
    else
        local enabled_changed, new_value = imgui.checkbox("Enabled", node.enabled_manual_value or false)
        if enabled_changed then
            node.enabled_manual_value = new_value
            State.mark_as_modified()
        end
    end
    imnodes.end_input_attribute()

    -- Update output pin value
    output_pin.value = node.ending_value

    -- Output pin with tooltip
    imgui.spacing()
    imnodes.begin_output_attribute(output_pin.id)
    local display_value = Utils.get_value_display_string(node.ending_value)
    local output_display = display_value .. " (?)"
    local pos = Utils.get_right_cursor_pos(node.id, output_display)
    imgui.set_cursor_pos(pos)
    imgui.text(display_value)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() then
        local enabled_display = "false"
        if has_enabled_connection then
            local source_pin_info = State.pin_map[enabled_pin.connection.pin]
            local connected_value = source_pin_info and source_pin_info.pin.value
            enabled_display = tostring(connected_value)
        else
            enabled_display = node.enabled_manual_value and "true" or "false"
        end
        local tooltip_text = string.format("Toggle Control\nEnabled: %s\nOutput: %s",
            enabled_display, display_value)
        imgui.set_tooltip(tooltip_text)
    end
    imnodes.end_output_attribute()

    imgui.spacing()
    local pos = imgui.get_cursor_pos()
    if imgui.button("- Remove Node") then
        Nodes.remove_node(node)
    end 
    imgui.same_line()
    local display_width = imgui.calc_text_size("+ Add Child Node").x
    local node_width = imnodes.get_node_dimensions(node.id).x
    pos.x = pos.x + node_width - display_width - 20
    imgui.set_cursor_pos(pos)
    if imgui.button("+ Add Child Node") then
        Nodes.add_child_node(node)
    end

    imnodes.end_node()
end

return ToggleControl