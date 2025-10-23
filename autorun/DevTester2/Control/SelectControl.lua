-- DevTester v2.0 - Select Control
-- Control node that selects between two values based on a condition

-- SelectControl Node Properties:
-- This node selects between two values based on a boolean condition.
-- The following properties define the state and configuration of a SelectControl node:
--
-- Input/Output Pins:
-- - condition_attr: Number - Pin ID for the condition input attribute (boolean)
-- - true_attr: Number - Pin ID for the "true" value input attribute
-- - false_attr: Number - Pin ID for the "false" value input attribute
-- - output_attr: Number - Pin ID for the output attribute (provides selected result)
--
-- Input Connections:
-- - condition_connection: NodeID - ID of the node connected to condition input
-- - true_connection: NodeID - ID of the node connected to true value input
-- - false_connection: NodeID - ID of the node connected to false value input
--
-- Manual Input Values:
-- - condition_manual_value: String - Manual text input for condition when not connected
-- - true_manual_value: String - Manual text input for true value when not connected
-- - false_manual_value: String - Manual text input for false value when not connected
--
-- Runtime Values:
-- - ending_value: Any - The selected value (true_value if condition is true, false_value if false)
--
-- Inherits status property from BaseControl for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Constants = require("DevTester2.Constants")
local BaseControl = require("DevTester2.Control.BaseControl")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local SelectControl = {}

-- ========================================
-- Select Control Node
-- ========================================

function SelectControl.execute(node)
    -- Get input values
    local condition_value = Nodes.get_control_input_value(node, "condition_attr")
    local true_value = Nodes.get_control_input_value(node, "true_attr")
    local false_value = Nodes.get_control_input_value(node, "false_attr")

    -- Convert condition to boolean
    local condition = not not condition_value  -- Convert to boolean (nil becomes false)

    -- Select the appropriate value
    local result = nil
    if condition then
        result = true_value
    else
        result = false_value
    end

    -- Store the result
    node.ending_value = result
    return result
end

function SelectControl.render(node)

    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Select")
    imnodes.end_node_titlebar()

    -- Get input values for display
    local condition_value = Nodes.get_control_input_value(node, "condition_attr")
    local true_value = Nodes.get_control_input_value(node, "true_attr")
    local false_value = Nodes.get_control_input_value(node, "false_attr")

    -- Execute when all inputs are connected
    local all_connected = (condition_value ~= nil) and (true_value ~= nil) and (false_value ~= nil)
    if all_connected then
        SelectControl.execute(node)
    else
        node.ending_value = nil
    end

    -- Convert condition to boolean for display
    local condition_bool = not not condition_value  -- Convert to boolean (nil becomes false)

    -- Input pins
    BaseControl.render_input_pin(node, "Condition", "condition_attr", condition_bool, condition_value)
    BaseControl.render_input_pin(node, "True", "true_attr", true_value, true_value)
    BaseControl.render_input_pin(node, "False", "false_attr", false_value, false_value)

    -- Create tooltip for output
    local tooltip_text = nil
    if node.ending_value ~= nil then
        tooltip_text = string.format("Select Control\nCondition: %s\nSelected: %s",
            tostring(condition_bool), tostring(node.ending_value))
    else
        tooltip_text = "Select Control\nWaiting for all inputs to be connected"
    end

    BaseControl.render_output_attribute(node, node.ending_value ~= nil and tostring(node.ending_value) or "(waiting)", tooltip_text)

    BaseControl.render_action_buttons(node)
    BaseControl.render_debug_info(node)

    imnodes.end_node()
    
end

return SelectControl