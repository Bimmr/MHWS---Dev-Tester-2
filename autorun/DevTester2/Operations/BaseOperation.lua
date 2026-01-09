-- DevTester v2.0 - Base Operation
-- Base module for operation nodes providing common rendering functionality

-- BaseOperation Node Properties:
-- This is the base class for all operation nodes (Math, Compare, Logic, Invert).
-- Operation nodes perform computations on input values and provide results.
-- The following properties define the state and configuration of operation nodes:
--
-- Operation Selection:
-- - selected_operation: Number - The currently selected operation type (varies by operation node)
--
-- Input/Output Pins:
-- - input1_attr: Number - Pin ID for the first input attribute
-- - input2_attr: Number - Pin ID for the second input attribute (not used by InvertOperation)
-- - output_attr: Number - Pin ID for the output attribute (provides operation result)
--
-- Manual Input Values:
-- - input1_manual_value: String - Manual text input for input1 when not connected
-- - input2_manual_value: String - Manual text input for input2 when not connected
--
-- Runtime Values:
-- - ending_value: Any - The result of the operation (number, boolean, etc.)
--
-- UI/Debug:
-- - status: String - Current status message for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes

local BaseOperation = {}

-- ========================================
-- Base Operation Node Rendering Functions
-- ========================================

function BaseOperation.render_action_buttons(node)
    imgui.spacing()
    if imgui.button("- Remove Node") then
        Nodes.remove_node(node)
    end

    -- Operations nodes typically don't add child nodes since they're operation providers
    -- But we could add other operation-specific actions here if needed
end

function BaseOperation.render_debug_info(node)
    
    local holding_ctrl = imgui.is_key_down(imgui.ImGuiKey.Key_LeftCtrl) or imgui.is_key_down(imgui.ImGuiKey.Key_RightCtrl)
    local debug_info = ""
    if holding_ctrl then

        debug_info = debug_info .. "-- All Node Info --"
        -- Collect all node information for debugging and display
        local keys = Utils.get_sorted_keys(node)
        for _, key in ipairs(keys) do
            local value = node[key]
            if tostring(key):sub(1,1) == "_" then
                goto continue
            end
            if key == "pins" and type(value) == "table" then
                value = Utils.pretty_print_pins(value)
            elseif type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
                    value = tostring(value)
            elseif type(value) == "table" then
                value = json.dump_string(value)
            end
            if tostring(value) ~= "" then
                debug_info = debug_info .. string.format("\n%s: %s", tostring(key), tostring(value))
            end
            ::continue::
        end
    else
        debug_info = string.format("Status: %s", tostring(node.status or "None"))
    end

    -- Position debug info in top right
    local pos_for_debug = Utils.get_top_right_cursor_pos(node.id, "[?]")
    imgui.set_cursor_pos(pos_for_debug)
    imgui.text_colored("[?]", Constants.COLOR_TEXT_DEBUG)
    if imgui.is_item_hovered() then
        imgui.set_tooltip(debug_info)
    end
end

function BaseOperation.render_operation_dropdown(node, operations, default_operation)
    -- Initialize operation if not set
    if not node.selected_operation then
        node.selected_operation = default_operation
    end

    -- Operation dropdown
    local changed, new_operation = imgui.combo("Operation", node.selected_operation, operations)
    if changed then
        node.selected_operation = new_operation
        State.mark_as_modified()
    end

    return node.selected_operation
end

-- ========================================
-- Operation Node Creation
-- ========================================

function BaseOperation.create(node_type, position)
    local Constants = require("DevTester2.Constants")
    local node_id = State.next_node_id()

    local node = {
        id = node_id,
        category = Constants.NODE_CATEGORY_OPERATIONS,
        type = node_type,
        position = position or {x = 50, y = 50},
        ending_value = nil,
        status = nil,
        pins = { inputs = {}, outputs = {} },
        selected_operation = 0,
        input1_manual_value = "",
        input2_manual_value = ""
    }

    table.insert(State.all_nodes, node)
    State.node_map[node_id] = node
    State.mark_as_modified()
    return node
end

-- ========================================
-- Serialization
-- ========================================

function BaseOperation.serialize(node, Config)
    return {
        id = node.id,
        category = node.category,
        type = node.type,
        position = {x = node.position.x, y = node.position.y},
        selected_operation = node.selected_operation,
        input1_manual_value = node.input1_manual_value,
        input2_manual_value = node.input2_manual_value,
        pins = Config.serialize_pins(node.pins)
    }
end

function BaseOperation.deserialize(data, Config)
    local Constants = require("DevTester2.Constants")
    return {
        id = data.id,
        category = data.category,
        type = data.type,
        position = data.position or {x = 0, y = 0},
        selected_operation = data.selected_operation or 
            (data.type == Constants.OPERATIONS_TYPE_COMPARE and Constants.COMPARE_OPERATION_EQUALS) or
            (data.type == Constants.OPERATIONS_TYPE_LOGIC and Constants.LOGIC_OPERATION_AND) or
            (data.type == Constants.OPERATIONS_TYPE_INVERT and 0) or
            Constants.MATH_OPERATION_ADD,
        ending_value = nil,
        status = nil,
        input1_manual_value = data.input1_manual_value or "",
        input2_manual_value = data.input2_manual_value or "",
        pins = Config.deserialize_pins(data.pins, data.id)
    }
end

return BaseOperation

