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
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local LogicOperation = {}

-- ========================================
-- Logic Operation Node
-- ========================================

function LogicOperation.execute(node)
    -- Get input values
    local input1_value = Nodes.get_operation_input1_value(node)
    local input2_value = Nodes.get_operation_input2_value(node)

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
    
    imnodes.begin_node(node.node_id)

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

    -- Get initial input values for display
    local input1_value = Nodes.get_operation_input1_value(node)
    local input2_value = Nodes.get_operation_input2_value(node)

    -- Convert to booleans for display
    local bool1 = not not input1_value  -- Convert to boolean (nil becomes false)
    local bool2 = not not input2_value  -- Convert to boolean (nil becomes false)

    -- Input pins
    BaseOperation.render_input_pin(node, "Input 1", "input1_attr", bool1, input1_value)
    BaseOperation.render_input_pin(node, "Input 2", "input2_attr", bool2, input2_value)

    -- Get updated input values after manual input processing
    input1_value = Nodes.get_operation_input1_value(node)
    input2_value = Nodes.get_operation_input2_value(node)

    -- Always execute to update output (after input pins so manual values are updated)
    LogicOperation.execute(node)

    -- Create tooltip for output
    local tooltip_text = nil
    if node.ending_value ~= nil then
        local op_name = "AND"
        if node.selected_operation == Constants.LOGIC_OPERATION_AND then op_name = "AND"
        elseif node.selected_operation == Constants.LOGIC_OPERATION_OR then op_name = "OR"
        elseif node.selected_operation == Constants.LOGIC_OPERATION_NAND then op_name = "NAND"
        elseif node.selected_operation == Constants.LOGIC_OPERATION_NOR then op_name = "NOR"
        end

        tooltip_text = string.format("Logic Operation\n%s %s %s = %s",
            tostring(bool1), op_name, tostring(bool2), tostring(node.ending_value))
        node.status = "Logic operation successful"
    else
        tooltip_text = "Logic Operation\nWaiting for both inputs to be connected"
        node.status = "Waiting for valid inputs"
    end

    BaseOperation.render_output_attribute(node, node.ending_value ~= nil and tostring(node.ending_value) or "(waiting)", tooltip_text)

    BaseOperation.render_action_buttons(node)
    BaseOperation.render_debug_info(node)

    imnodes.end_node()
    
end

return LogicOperation
