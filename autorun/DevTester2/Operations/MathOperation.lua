-- DevTester v2.0 - Math Operation
-- Operations node that performs mathematical operations on two numbers

-- MathOperation Node Properties:
-- This node performs mathematical operations on two numeric inputs.
-- The following properties define the state and configuration of a MathOperation node:
--
-- Inherits all BaseOperation properties (selected_operation, input/output pins, connections, manual values, ending_value, status)
--
-- Operation Types (selected_operation values):
-- - Constants.MATH_OPERATION_ADD: Addition (+)
-- - Constants.MATH_OPERATION_SUBTRACT: Subtraction (-)
-- - Constants.MATH_OPERATION_MULTIPLY: Multiplication (*)
-- - Constants.MATH_OPERATION_DIVIDE: Division (/)
-- - Constants.MATH_OPERATION_MODULO: Modulo (%)
-- - Constants.MATH_OPERATION_POWER: Power (^)
-- - Constants.MATH_OPERATION_MAX: Maximum value
-- - Constants.MATH_OPERATION_MIN: Minimum value

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Constants = require("DevTester2.Constants")
local BaseOperation = require("DevTester2.Operations.BaseOperation")
local Utils = require("DevTester2.Utils")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local MathOperation = {}

-- ========================================
-- Math Operation Node
-- ========================================

function MathOperation.execute(node)
    -- Get input values (already validated as numbers in render)
    local input1_value = Nodes.get_input_pin_value(node, 1)
    local input2_value = Nodes.get_input_pin_value(node, 2)
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
    -- Ensure pins exist
    if #node.pins.inputs < 2 then
        if #node.pins.inputs == 0 then
            Nodes.add_input_pin(node, "input1", nil)
        end
        if #node.pins.inputs == 1 then
            Nodes.add_input_pin(node, "input2", nil)
        end
    end
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    local input1_pin = node.pins.inputs[1]
    local input2_pin = node.pins.inputs[2]
    local output_pin = node.pins.outputs[1]
    
    imnodes.begin_node(node.id)

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

    -- Input 1 pin
    imnodes.begin_input_attribute(input1_pin.id)
    imgui.text("Input 1")
    imnodes.end_input_attribute()
    imgui.same_line()
    if not input1_pin.connection then
        local current_value = input1_pin.value
        if current_value == nil then current_value = "" end
        if type(current_value) ~= "string" then current_value = tostring(current_value) end
        local changed1, new_value1 = imgui.input_text("##input1", current_value)
        if changed1 then
            input1_pin.value = Utils.parse_primitive_value(new_value1)
            State.mark_as_modified()
        end
    else
        -- Show connected value from source pin
        local source_pin_info = State.pin_map[input1_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        local display_val = ""
        if connected_value ~= nil then
            display_val = tostring(connected_value)
        end
        imgui.begin_disabled()
        imgui.input_text("##input1", display_val)
        imgui.end_disabled()
    end

    -- Input 2 pin
    imnodes.begin_input_attribute(input2_pin.id)
    imgui.text("Input 2")
    imnodes.end_input_attribute()
    imgui.same_line()
    if not input2_pin.connection then
        local current_value = input2_pin.value
        if current_value == nil then current_value = "" end
        if type(current_value) ~= "string" then current_value = tostring(current_value) end
        local changed2, new_value2 = imgui.input_text("##input2", current_value)
        if changed2 then
            input2_pin.value = Utils.parse_primitive_value(new_value2)
            State.mark_as_modified()
        end
    else
        -- Show connected value from source pin
        local source_pin_info = State.pin_map[input2_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        local display_val = ""
        if connected_value ~= nil then
            display_val = tostring(connected_value)
        end
        imgui.begin_disabled()
        imgui.input_text("##input2", display_val)
        imgui.end_disabled()
    end

    -- Execute to get result
    MathOperation.execute(node)
    output_pin.value = node.ending_value

    -- Create tooltip
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

        local num1 = tonumber(Nodes.get_input_pin_value(node, 1))
        local num2 = tonumber(Nodes.get_input_pin_value(node, 2))
        tooltip_text = string.format("Math Operation\n%s %s %s = %s",
            tostring(num1), op_symbol, tostring(num2), tostring(node.ending_value))
        node.status = "Math operation successful"
    else
        tooltip_text = "Math Operation\nWaiting for both inputs"
        node.status = "Waiting for valid inputs"
    end

    -- Output pin
    imgui.spacing()
    imnodes.begin_output_attribute(output_pin.id)
    local display = Utils.get_value_display_string(node.ending_value)
    local debug_pos = Utils.get_right_cursor_pos(node.id, display .. " (?)")
    imgui.set_cursor_pos(debug_pos)
    imgui.text(display)
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

return MathOperation