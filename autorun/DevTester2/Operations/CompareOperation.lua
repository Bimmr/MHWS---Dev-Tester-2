-- DevTester v2.0 - Compare Operation
-- Operations node that performs comparison operations on two values

-- CompareOperation Node Properties:
-- This node performs comparison operations on two inputs and returns boolean results.
-- The following properties define the state and configuration of a CompareOperation node:
--
-- Inherits all BaseOperation properties (selected_operation, input/output pins, connections, manual values, ending_value, status)
--
-- Operation Types (selected_operation values):
-- - Constants.COMPARE_OPERATION_EQUALS: Equality check (==)
-- - Constants.COMPARE_OPERATION_NOT_EQUALS: Inequality check (!=)
-- - Constants.COMPARE_OPERATION_GREATER: Greater than (>) - requires numeric inputs
-- - Constants.COMPARE_OPERATION_LESS: Less than (<) - requires numeric inputs

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Constants = require("DevTester2.Constants")
local BaseOperation = require("DevTester2.Operations.BaseOperation")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local CompareOperation = {}

-- ========================================
-- Compare Operation Node
-- ========================================

function CompareOperation.execute(node)
    -- Get input values (already validated in render)
    local input1_value = Nodes.get_operation_input1_value(node)
    local input2_value = Nodes.get_operation_input2_value(node)

    -- Perform the comparison only if inputs are valid for the operation
    local result = nil
    if input1_value ~= nil and input2_value ~= nil then
        -- For equals/not equals, any types can be compared
        if node.selected_operation == Constants.COMPARE_OPERATION_EQUALS or 
           node.selected_operation == Constants.COMPARE_OPERATION_NOT_EQUALS then
            if node.selected_operation == Constants.COMPARE_OPERATION_EQUALS then
                result = input1_value == input2_value
            elseif node.selected_operation == Constants.COMPARE_OPERATION_NOT_EQUALS then
                result = input1_value ~= input2_value
            end
        -- For greater/less, inputs must be numbers
        elseif node.selected_operation == Constants.COMPARE_OPERATION_GREATER or 
               node.selected_operation == Constants.COMPARE_OPERATION_LESS then
            if (type(input1_value) == "number") and (type(input2_value) == "number") then
                if node.selected_operation == Constants.COMPARE_OPERATION_GREATER then
                    result = input1_value > input2_value
                elseif node.selected_operation == Constants.COMPARE_OPERATION_LESS then
                    result = input1_value < input2_value
                end
            end
        end
    end

    -- Store the result (nil if inputs invalid)
    node.ending_value = result
    return result
end

function CompareOperation.render(node)
     
    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Compare")
    imnodes.end_node_titlebar()

    -- Initialize operation if not set or invalid
    if not node.selected_operation or node.selected_operation == 0 then
        node.selected_operation = Constants.COMPARE_OPERATION_EQUALS
    end

    -- Operation dropdown
    local operations = {"Equals (==)", "Not Equals (!=)", "Greater (>)", "Less (<)"}
    local changed, new_operation = imgui.combo("Operation", node.selected_operation, operations)
    if changed then
        node.selected_operation = new_operation
        State.mark_as_modified()
    end

    -- Get initial input values for display
    local input1_value = Nodes.get_operation_input1_value(node)
    local input2_value = Nodes.get_operation_input2_value(node)

    -- Input pins
    BaseOperation.render_input_pin(node, "Input 1", "input1_attr", input1_value, input1_value)
    BaseOperation.render_input_pin(node, "Input 2", "input2_attr", input2_value, input2_value)

    -- Get updated input values after manual input processing
    input1_value = Nodes.get_operation_input1_value(node)
    input2_value = Nodes.get_operation_input2_value(node)

    -- Always execute to update output (after input pins so manual values are updated)
    CompareOperation.execute(node)

    -- Create tooltip for output
    local tooltip_text = nil
    if node.ending_value ~= nil then
        local op_symbol = "=="
        if node.selected_operation == Constants.COMPARE_OPERATION_EQUALS then op_symbol = "=="
        elseif node.selected_operation == Constants.COMPARE_OPERATION_NOT_EQUALS then op_symbol = "!="
        elseif node.selected_operation == Constants.COMPARE_OPERATION_GREATER then op_symbol = ">"
        elseif node.selected_operation == Constants.COMPARE_OPERATION_LESS then op_symbol = "<"
        end

        tooltip_text = string.format("Compare Operation\n%s %s %s = %s",
            tostring(input1_value), op_symbol, tostring(input2_value), tostring(node.ending_value))
        node.status = "Comparison successful"
    else
        tooltip_text = "Compare Operation\nWaiting for both inputs to be connected"
        node.status = "Waiting for valid inputs"
    end

    BaseOperation.render_output_attribute(node, node.ending_value ~= nil and tostring(node.ending_value) or "(waiting)", tooltip_text)

    BaseOperation.render_action_buttons(node)
    BaseOperation.render_debug_info(node)

    imnodes.end_node()
    
end

return CompareOperation