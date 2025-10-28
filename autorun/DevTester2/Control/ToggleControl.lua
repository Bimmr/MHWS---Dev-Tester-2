-- DevTester v2.0 - Toggle Control
-- Control node that toggles data flow on/off based on user interaction

-- ToggleControl Node Properties:
-- This node controls data flow with a persistent on/off toggle.
-- The following properties define the state and configuration of a ToggleControl node:
--
-- Input/Output Pins:
-- - input_attr: Number - Pin ID for the input attribute (receives value to control)
-- - output_attr: Number - Pin ID for the output attribute (provides result when enabled)
--
-- Input Connections:
-- - input_connection: NodeID - ID of the node connected to input
--
-- Manual Input Values:
-- - input_manual_value: String - Manual text input for value when not connected
--
-- Runtime Values:
-- - ending_value: Any - The output value (input_value if enabled, nil if disabled)
-- - toggle_enabled: Boolean - Whether the toggle is currently enabled
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
    -- Get input value
    local input_value = Nodes.get_control_input_value(node, "input_attr")

    -- Apply toggle logic
    local result = nil
    if node.toggle_enabled then
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

    -- Get input value for display
    local input_value = Nodes.get_control_input_value(node, "input_attr")

    -- Execute to update ending_value
    ToggleControl.execute(node)

    -- Initialize toggle state if not set
    if node.toggle_enabled == nil then
        node.toggle_enabled = false
    end

    -- Input pin
    BaseControl.render_input_pin(node, "Input", "input_attr", input_value, input_value)

    -- Toggle checkbox (below input)
    local toggle_changed, new_toggle_state = imgui.checkbox("Enabled", node.toggle_enabled)
    if toggle_changed then
        node.toggle_enabled = new_toggle_state
        State.mark_as_modified()
        -- Re-execute to update status
        ToggleControl.execute(node)
    end

    -- Create tooltip for output
    local tooltip_text = nil
    if node.ending_value ~= nil then
        tooltip_text = string.format("Toggle Control\nEnabled: %s\nOutput: %s",
            tostring(node.toggle_enabled), tostring(node.ending_value))
    else
        tooltip_text = string.format("Toggle Control\nEnabled: %s\nOutput: nil (disabled)",
            tostring(node.toggle_enabled))
    end

    BaseControl.render_output_attribute(node, node.ending_value ~= nil and tostring(node.ending_value) or "nil", tooltip_text)

    BaseControl.render_action_buttons(node)
    BaseControl.render_debug_info(node)

    imnodes.end_node()
end

return ToggleControl