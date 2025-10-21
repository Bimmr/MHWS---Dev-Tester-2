-- DevTester v2.0 - Math Operation
-- Operations node that performs mathematical operations on two numbers

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Constants = require("DevTester2.Constants")
local BaseOperation = require("DevTester2.Operations.BaseOperation")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local MathOperation = {}

-- ========================================
-- Math Operation Node
-- ========================================

function MathOperation.execute(node)
    -- Get input values (already validated as numbers in render)
    local input1_value = Nodes.get_operation_input1_value(node)
    local input2_value = Nodes.get_operation_input2_value(node)
    local num1 = tonumber(input1_value)
    local num2 = tonumber(input2_value)

    -- Perform the operation only if both inputs are valid numbers
    local result = nil
    if num1 and num2 then
        if node.selected_operation == Constants.MATH_OPERATION_ADD then
            result = num1 + num2
        elseif node.selected_operation == Constants.MATH_OPERATION_SUBTRACT then
            result = num1 - num2
        elseif node.selected_operation == Constants.MATH_OPERATION_MULTIPLY then
            result = num1 * num2
        elseif node.selected_operation == Constants.MATH_OPERATION_DIVIDE then
            if num2 ~= 0 then
                result = num1 / num2
            else
                result = 0 -- Division by zero
            end
        elseif node.selected_operation == Constants.MATH_OPERATION_MODULO then
            result = num1 % num2
        elseif node.selected_operation == Constants.MATH_OPERATION_POWER then
            result = num1 ^ num2
        elseif node.selected_operation == Constants.MATH_OPERATION_MAX then
            result = math.max(num1, num2)
        elseif node.selected_operation == Constants.MATH_OPERATION_MIN then
            result = math.min(num1, num2)
        end
    end

    -- Store the result (nil if inputs invalid)
    node.ending_value = result
    return result
end

function MathOperation.render(node)
    
    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Math")
    imnodes.end_node_titlebar()

    -- Initialize operation if not set or invalid
    if not node.selected_operation or node.selected_operation == 0 then
        node.selected_operation = Constants.MATH_OPERATION_ADD
    end

    -- Operation dropdown
    local operations = {"Add (+)", "Subtract (-)", "Multiply (*)", "Divide (/)", "Modulo (%)", "Power (^)", "Max", "Min"}
    local changed, new_operation = imgui.combo("Operation", node.selected_operation, operations)
    if changed then
        node.selected_operation = new_operation
        State.mark_as_modified()
    end

    -- Get initial input values for display
    local input1_value = Nodes.get_operation_input1_value(node)
    local input2_value = Nodes.get_operation_input2_value(node)

    -- Convert to numbers for display
    local num1 = tonumber(input1_value)
    local num2 = tonumber(input2_value)

    -- Input pins
    BaseOperation.render_input_pin(node, "Input 1", "input1_attr", num1, input1_value)
    BaseOperation.render_input_pin(node, "Input 2", "input2_attr", num2, input2_value)

    -- Get updated input values after manual input processing
    input1_value = Nodes.get_operation_input1_value(node)
    input2_value = Nodes.get_operation_input2_value(node)

    -- Always execute to update output (after input pins so manual values are updated)
    MathOperation.execute(node) -- TODO: This still isn't working unless a dropdown is changed

    -- Create tooltip for output
    local tooltip_text = nil
    if node.ending_value ~= nil then
        local op_symbol = "+"
        if node.selected_operation == Constants.MATH_OPERATION_ADD then op_symbol = "+"
        elseif node.selected_operation == Constants.MATH_OPERATION_SUBTRACT then op_symbol = "-"
        elseif node.selected_operation == Constants.MATH_OPERATION_MULTIPLY then op_symbol = "*"
        elseif node.selected_operation == Constants.MATH_OPERATION_DIVIDE then op_symbol = "/"
        elseif node.selected_operation == Constants.MATH_OPERATION_MODULO then op_symbol = "%"
        elseif node.selected_operation == Constants.MATH_OPERATION_POWER then op_symbol = "^"
        elseif node.selected_operation == Constants.MATH_OPERATION_MAX then op_symbol = "max"
        elseif node.selected_operation == Constants.MATH_OPERATION_MIN then op_symbol = "min"
        end

        tooltip_text = string.format("Math Operation\n%s %s %s = %s",
            tostring(num1), op_symbol, tostring(num2), tostring(node.ending_value))
    else
        tooltip_text = "Math Operation\nWaiting for both inputs to be connected"
    end

    BaseOperation.render_output_attribute(node, node.ending_value and tostring(node.ending_value) or "(waiting)", tooltip_text)

    BaseOperation.render_action_buttons(node)
    BaseOperation.render_debug_info(node)

    imnodes.end_node()
    
end

return MathOperation