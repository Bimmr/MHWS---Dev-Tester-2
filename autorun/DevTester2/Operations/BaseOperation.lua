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
-- Input Connections:
-- - input1_connection: NodeID - ID of the node connected to input1
-- - input2_connection: NodeID - ID of the node connected to input2
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

function BaseOperation.render_output_attribute(node, display_value, tooltip_text)
    -- Create output attribute if needed
    if not node.output_attr then
        node.output_attr = State.next_pin_id()
    end

    imgui.spacing()
    imnodes.begin_output_attribute(node.output_attr)

    -- Display value with tooltip
    local display = display_value .. " (?)"
    local debug_pos = Utils.get_right_cursor_pos(node.node_id, display)
    imgui.set_cursor_pos(debug_pos)
    imgui.text(display_value)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() and tooltip_text then
        imgui.set_tooltip(tooltip_text)
    end

    imnodes.end_output_attribute()
end

function BaseOperation.render_action_buttons(node)
    imgui.spacing()
    if imgui.button("- Remove Node") then
        Nodes.remove_starter_node(node)  -- Operations nodes use the same removal logic as data nodes
    end

    -- Operations nodes typically don't add child nodes since they're operation providers
    -- But we could add other operation-specific actions here if needed
end

function BaseOperation.render_debug_info(node)
    -- Collect link information
    local input_links, output_links = {}, {}
    for _, link in ipairs(State.all_links) do
        if link.to_node == node.id then
            table.insert(input_links, string.format("(Pin %s, Link %s)", tostring(link.to_pin), tostring(link.id)))
        end
        if link.from_node == node.id then
            table.insert(output_links, string.format("(Pin %s, Link %s)", tostring(link.from_pin), tostring(link.id)))
        end
    end

    local debug_info = string.format(
        "Node ID: %s\nStatus: %s\nSelected Operation: %s\nInput1 Attr: %s\nInput2 Attr: %s\nOutput Attr: %s\nInput Links: %s\nOutput Links: %s",
        tostring(node.node_id),
        tostring(node.status or "None"),
        tostring(node.selected_operation or "None"),
        tostring(node.input1_attr or "None"),
        tostring(node.input2_attr or "None"),
        tostring(node.output_attr or "None"),
        #input_links > 0 and table.concat(input_links, ", ") or "None",
        #output_links > 0 and table.concat(output_links, ", ") or "None"
    )

    -- Position debug info in top right
   local pos_for_debug = Utils.get_top_right_cursor_pos(node.node_id, "[?]")
    imgui.set_cursor_pos(pos_for_debug)
    imgui.text_colored("[?]", Constants.COLOR_TEXT_DEBUG)
    if imgui.is_item_hovered() then
        imgui.set_tooltip(debug_info)
    end
end

function BaseOperation.render_input_pin(node, label, attr_name, converted_value, original_value)
    -- Create input attribute if needed
    if not node[attr_name] then
        node[attr_name] = State.next_pin_id()
    end

    imnodes.begin_input_attribute(node[attr_name])
    imgui.text(label)
    imnodes.end_input_attribute()

    imgui.same_line()
    
    -- Check if this input is connected
    local connection_name = attr_name:gsub("_attr", "_connection")
    local manual_name = attr_name:gsub("_attr", "_manual_value")
    local has_connection = node[connection_name] ~= nil
    
    if has_connection then
        -- Show connected value in disabled input
        local display_value = original_value ~= nil and tostring(converted_value) or "(no input)"
        imgui.begin_disabled()
        imgui.input_text("##" .. attr_name, display_value)
        imgui.end_disabled()
    else
        -- Show manual input field
        node[manual_name] = node[manual_name] or ""
        local input_changed, new_value = imgui.input_text("##" .. attr_name, node[manual_name])
        -- Always update the stored value with the current input text
        if new_value ~= node[manual_name] then
            node[manual_name] = new_value
            State.mark_as_modified()
        end
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

return BaseOperation
