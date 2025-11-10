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
local Utils = require("DevTester2.Utils")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local CompareOperation = {}

-- ========================================
-- Compare Operation Node
-- ========================================

function CompareOperation.execute(node)
    -- Get input values (already validated in render)
    local input1_value = Nodes.get_input_pin_value(node, 1)
    local input2_value = Nodes.get_input_pin_value(node, 2)

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
        imgui.begin_disabled()
        imgui.input_text("##input1", tostring(connected_value or ""))
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
        imgui.begin_disabled()
        imgui.input_text("##input2", tostring(connected_value or ""))
        imgui.end_disabled()
    end

    -- Execute to get result
    CompareOperation.execute(node)
    output_pin.value = node.ending_value

    -- Create tooltip
    local tooltip_text = nil
    if node.ending_value ~= nil then
        local op_symbol = "=="
        if node.selected_operation == Constants.COMPARE_OPERATION_EQUALS then op_symbol = "=="
        elseif node.selected_operation == Constants.COMPARE_OPERATION_NOT_EQUALS then op_symbol = "!="
        elseif node.selected_operation == Constants.COMPARE_OPERATION_GREATER then op_symbol = ">"
        elseif node.selected_operation == Constants.COMPARE_OPERATION_LESS then op_symbol = "<"
        end

        local input1_value = Nodes.get_input_pin_value(node, 1)
        local input2_value = Nodes.get_input_pin_value(node, 2)
        tooltip_text = string.format("Compare Operation\n%s %s %s = %s",
            tostring(input1_value), op_symbol, tostring(input2_value), tostring(node.ending_value))
        node.status = "Comparison successful"
    else
        tooltip_text = "Compare Operation\nWaiting for both inputs"
        node.status = "Waiting for valid inputs"
    end

    -- Output pin
    imgui.spacing()
    imnodes.begin_output_attribute(output_pin.id)
    local display = node.ending_value ~= nil and tostring(node.ending_value) or "(waiting)"
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

return CompareOperation