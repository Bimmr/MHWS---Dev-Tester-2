-- DevTester v2.0 - Logic Operation
-- Operations node that performs logical operations on two boolean values

-- LogicOperation Node Properties:
-- This node performs logical operations on two boolean inputs.
-- The following properties define the state and configuration of a LogicOperation node:
--
-- Inherits all BaseOperation properties (selected_operation, input/output pins, connections, manual values, ending_value, status)
--
-- Operation Types (selected_operation values):
-- - Constants.LOGIC_OPERATION_AND: Logical AND
-- - Constants.LOGIC_OPERATION_OR: Logical OR
-- - Constants.LOGIC_OPERATION_NAND: Logical NAND (NOT AND)
-- - Constants.LOGIC_OPERATION_NOR: Logical NOR (NOT OR)

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Constants = require("DevTester2.Constants")
local BaseOperation = require("DevTester2.Operations.BaseOperation")
local Utils = require("DevTester2.Utils")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local LogicOperation = {}

-- ========================================
-- Logic Operation Node
-- ========================================

function LogicOperation.execute(node)
    -- Get input values
    local input1_value = Nodes.get_input_pin_value(node, 1)
    local input2_value = Nodes.get_input_pin_value(node, 2)

    -- Perform the operation only if both inputs have values
    local result = nil
    if input1_value ~= nil and input2_value ~= nil then
        -- Convert to booleans
        local bool1 = not not input1_value  -- Convert to boolean (nil becomes false)
        local bool2 = not not input2_value  -- Convert to boolean (nil becomes false)

        if node.selected_operation == Constants.LOGIC_OPERATION_AND then
            result = bool1 and bool2
        elseif node.selected_operation == Constants.LOGIC_OPERATION_OR then
            result = bool1 or bool2
        elseif node.selected_operation == Constants.LOGIC_OPERATION_NAND then
            result = not (bool1 and bool2)
        elseif node.selected_operation == Constants.LOGIC_OPERATION_NOR then
            result = not (bool1 or bool2)
        end
    end

    -- Store the result (nil if inputs invalid)
    node.ending_value = result
    return result
end

function LogicOperation.render(node)
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
    imgui.text("Logic")
    imnodes.end_node_titlebar()

    -- Initialize operation if not set or invalid
    if not node.selected_operation or node.selected_operation == 0 then
        node.selected_operation = Constants.LOGIC_OPERATION_AND
    end

    -- Operation dropdown
    local operations = {"AND", "OR", "NAND", "NOR"}
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
    LogicOperation.execute(node)
    output_pin.value = node.ending_value

    -- Create tooltip
    local tooltip_text = nil
    if node.ending_value ~= nil then
        local op_name = "AND"
        if node.selected_operation == Constants.LOGIC_OPERATION_AND then op_name = "AND"
        elseif node.selected_operation == Constants.LOGIC_OPERATION_OR then op_name = "OR"
        elseif node.selected_operation == Constants.LOGIC_OPERATION_NAND then op_name = "NAND"
        elseif node.selected_operation == Constants.LOGIC_OPERATION_NOR then op_name = "NOR"
        end

        local input1_value = Nodes.get_input_pin_value(node, 1)
        local input2_value = Nodes.get_input_pin_value(node, 2)
        local bool1 = not not input1_value
        local bool2 = not not input2_value
        tooltip_text = string.format("Logic Operation\n%s %s %s = %s",
            tostring(bool1), op_name, tostring(bool2), tostring(node.ending_value))
        node.status = "Logic operation successful"
    else
        tooltip_text = "Logic Operation\nWaiting for both inputs"
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

return LogicOperation
