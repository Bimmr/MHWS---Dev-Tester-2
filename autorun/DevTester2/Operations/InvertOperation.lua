-- DevTester v2.0 - Invert Operation
-- Operations node that inverts boolean values

-- InvertOperation Node Properties:
-- This node inverts boolean values (logical NOT operation).
-- The following properties define the state and configuration of an InvertOperation node:
--
-- Pins:
-- - pins.inputs[1]: "input" - The value to invert
-- - pins.outputs[1]: "output" - The inverted result
--
-- Runtime Values:
-- - ending_value: Boolean - The inverted boolean result
--
-- UI/Debug:
-- - status: String - Current status message for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Constants = require("DevTester2.Constants")
local BaseOperation = require("DevTester2.Operations.BaseOperation")
local Utils = require("DevTester2.Utils")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local InvertOperation = {}

-- ========================================
-- Invert Operation Node
-- ========================================

function InvertOperation.render(node)
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
    imgui.text("Invert")
    imnodes.end_node_titlebar()

    -- Input pin
    imnodes.begin_input_attribute(input_pin.id)
    imgui.text("Input")
    imnodes.end_input_attribute()
    
    imgui.same_line()
    
    -- Manual value input if not connected
    if not input_pin.connection then
        local current_value = input_pin.value
        if current_value == nil then current_value = "" end
        if type(current_value) ~= "string" then
            current_value = tostring(current_value)
        end
        local changed, new_value = imgui.input_text("##input", current_value)
        if changed then
            input_pin.value = Utils.parse_primitive_value(new_value)
            State.mark_as_modified()
        end
    else
        -- Show connected value from source pin
        local source_pin_info = State.pin_map[input_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        local display_value = connected_value ~= nil and tostring(connected_value) or "(no input)"
        imgui.begin_disabled()
        imgui.input_text("##input", display_value)
        imgui.end_disabled()
    end

    -- Get input value and process inversion
    local input_value = Nodes.get_input_pin_value(node, 1)
    local output_value = nil
    
    if input_value ~= nil then
        if type(input_value) == "boolean" then
            output_value = not input_value
        else
            output_value = not (input_value == false or input_value == 0 or input_value == "" or input_value == nil)
        end
        node.status = "Inverted value successfully"
    else
        node.status = "No valid input"
    end

    -- Update output pin value
    output_pin.value = output_value
    node.ending_value = output_value
    
    -- Output pin
    imgui.spacing()
    imnodes.begin_output_attribute(output_pin.id)
    
    local display_text = Utils.get_value_display_string(node.ending_value)
    local tooltip_text = nil
    if output_value ~= nil then
        tooltip_text = string.format("Inverted Value\nInput: %s\nOutput: %s", 
            input_value ~= nil and tostring(input_value) or "none", 
            tostring(output_value))
    else
        tooltip_text = "Inverted Value\nConnect input or enter manual value"
    end
    
    local debug_pos = Utils.get_right_cursor_pos(node.id, display_text .. " (?)")
    imgui.set_cursor_pos(debug_pos)
    imgui.text(display_text)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() and tooltip_text then
        imgui.set_tooltip(tooltip_text)
    end
    
    imnodes.end_output_attribute()

    BaseOperation.render_action_buttons(node)
    BaseOperation.render_debug_info(node)

    imnodes.end_node()
end

-- ========================================
-- Serialization
-- ========================================

function InvertOperation.serialize(node, Config)
    return BaseOperation.serialize(node, Config)
end

function InvertOperation.deserialize(data, Config)
    return BaseOperation.deserialize(data, Config)
end

return InvertOperation