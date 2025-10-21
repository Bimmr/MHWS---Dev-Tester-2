-- DevTester v2.0 - Invert Operation
-- Operations node that inverts boolean values

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Constants = require("DevTester2.Constants")
local BaseOperation = require("DevTester2.Operations.BaseOperation")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local InvertOperation = {}

-- ========================================
-- Invert Operation Node
-- ========================================

function InvertOperation.render(node)
    
    imnodes.begin_node(node.node_id)
    
    imnodes.begin_node_titlebar()
    imgui.text("Invert")
    imnodes.end_node_titlebar()

    -- Input pin (renders first to update manual values)
    local input_value = Nodes.get_operation_input1_value(node)
    BaseOperation.render_input_pin(node, "Input", "input1_attr", input_value, input_value)

    -- Get updated input value after manual input processing
    input_value = Nodes.get_operation_input1_value(node)

    -- Process the inversion
    local output_value = nil
    if input_value ~= nil then
        -- Ensure it's a boolean
        if type(input_value) == "boolean" then
            output_value = not input_value
        else
            -- Try to convert to boolean if it's not already
            output_value = not (input_value == false or input_value == 0 or input_value == "" or input_value == nil)
        end
    end

    -- Create tooltip for output
    local tooltip_text = nil
    if output_value ~= nil then
        tooltip_text = string.format("Inverted Value\nInput: %s\nOutput: %s", 
            input_value ~= nil and tostring(input_value) or "none", 
            tostring(output_value))
    else
        tooltip_text = "Inverted Value\nConnect input or enter manual value"
    end

    BaseOperation.render_output_attribute(node, output_value ~= nil and tostring(output_value) or "(no input)", tooltip_text)

    BaseOperation.render_action_buttons(node)
    BaseOperation.render_debug_info(node)

    -- Store the output value for other nodes to use
    node.ending_value = output_value

    imnodes.end_node()
    
end

return InvertOperation