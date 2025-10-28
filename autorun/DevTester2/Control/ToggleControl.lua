-- DevTester v2.0 - Toggle Control
-- Control node that toggles data flow on/off based on user interaction

-- ToggleControl Node Properties:
-- This node controls data flow with a persistent on/off toggle.
-- The following properties define the state and configuration of a ToggleControl node:
--
-- Input/Output Pins:
-- - input_attr: Number - Pin ID for the input attribute (receives value to control)
-- - enabled_attr: Number - Pin ID for the enabled control attribute
-- - output_attr: Number - Pin ID for the output attribute (provides result when enabled)
--
-- Input Connections:
-- - input_connection: NodeID - ID of the node connected to input
-- - enabled_connection: NodeID - ID of the node connected to enabled input
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
    -- Get input values
    local input_value = Nodes.get_control_input_value(node, "input_attr")
    local enabled_value = Nodes.get_control_input_value(node, "enabled_attr")

    -- Determine enabled state: use input if connected, otherwise use manual checkbox
    local is_enabled = node.enabled_manual_value -- default to manual value
    if enabled_value ~= nil then
        is_enabled = not not enabled_value -- input takes precedence
    end

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

    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Toggle")
    imnodes.end_node_titlebar()

    -- Get input values for display
    local input_value = Nodes.get_control_input_value(node, "input_attr")
    local enabled_value = Nodes.get_control_input_value(node, "enabled_attr")

    -- Execute to update ending_value
    ToggleControl.execute(node)

    -- Input pins
    BaseControl.render_input_pin(node, "Input", "input_attr", input_value, input_value, "text")
    BaseControl.render_input_pin(node, "Enabled", "enabled_attr", enabled_value, enabled_value, "checkbox")

    -- Create tooltip for output
    local enabled_display = enabled_value ~= nil and tostring(enabled_value) or ("manual:" .. tostring(node.enabled_manual_value))
    local tooltip_text = nil
    if node.ending_value ~= nil then
        tooltip_text = string.format("Toggle Control\nEnabled: %s\nOutput: %s",
            enabled_display, tostring(node.ending_value))
    else
        tooltip_text = string.format("Toggle Control\nEnabled: %s\nOutput: nil (disabled)",
            enabled_display)
    end

    BaseControl.render_output_attribute(node, node.ending_value ~= nil and tostring(node.ending_value) or "nil", tooltip_text)

    BaseControl.render_action_buttons(node)
    BaseControl.render_debug_info(node)

    imnodes.end_node()
end

return ToggleControl