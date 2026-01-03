-- DevTester v2.0 - Base Control
-- Base module for control nodes providing common rendering functionality

-- BaseControl Node Properties:
-- This is the base class for all control nodes (Select, etc.).
-- Control nodes make decisions based on input conditions and provide selected outputs.
-- The following properties define the state and configuration of control nodes:
--
-- Output Pins:
-- - output_attr: Number - Pin ID for the output attribute (provides selected result)
--
-- Runtime Values:
-- - ending_value: Any - The selected/output value based on control logic
--
-- UI/Debug:
-- - status: String - Current status message for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes

local BaseControl = {}

-- ========================================
-- Base Control Node Rendering Functions
-- ========================================

function BaseControl.render_output_attribute(node, display_value, tooltip_text)
    -- Get or create output pin
    if not node.pins or not node.pins.outputs or #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "Output", nil)
    end
    local output_pin = node.pins.outputs[1]

    imgui.spacing()
    imnodes.begin_output_attribute(output_pin.id)

    -- Display value with tooltip
    local display = display_value .. " (?)"
    local debug_pos = Utils.get_right_cursor_pos(node.id, display)
    imgui.set_cursor_pos(debug_pos)
    imgui.text(display_value)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() and tooltip_text then
        imgui.set_tooltip(tooltip_text)
    end

    imnodes.end_output_attribute()
end

function BaseControl.render_action_buttons(node)
    imgui.spacing()
    if imgui.button("- Remove Node") then
        Nodes.remove_node(node)
    end

    -- Control nodes typically don't add child nodes since they're control flow providers
    -- But we could add other control-specific actions here if needed
end

function BaseControl.render_debug_info(node)

    local holding_ctrl = imgui.is_key_down(imgui.ImGuiKey.Key_LeftCtrl) or imgui.is_key_down(imgui.ImGuiKey.Key_RightCtrl)
    local debug_info = ""
    if holding_ctrl then
            
        debug_info = debug_info .. "-- All Node Info --"
        -- Collect all node information for debugging and display
        local keys = Utils.get_sorted_keys(node)
        for _, key in ipairs(keys) do
            local value = node[key]
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

function BaseControl.render_input_pin(node, label, attr_name, converted_value, original_value, input_type)
    -- Create input attribute if needed
    if not node[attr_name] then
        node[attr_name] = State.next_pin_id()
    end

    -- Check if this input is connected
    local connection_name = attr_name:gsub("_attr", "_connection")
    local manual_name = attr_name:gsub("_attr", "_manual_value")
    local has_connection = node[connection_name] ~= nil

    imnodes.begin_input_attribute(node[attr_name])
    imgui.text(label)
    imnodes.end_input_attribute()
    
    imgui.same_line()
    
    if input_type == "checkbox" then
        -- Handle checkbox input
        if has_connection then
            -- Show connected value in disabled checkbox
            local bool_value = original_value ~= nil and not not converted_value
            imgui.begin_disabled()
            imgui.checkbox("##" .. attr_name, bool_value)
            imgui.end_disabled()
        else
            -- Show manual checkbox
            node[manual_name] = node[manual_name] or false
            local checkbox_changed, new_value = imgui.checkbox("##" .. attr_name, node[manual_name])
            if checkbox_changed then
                node[manual_name] = new_value
                State.mark_as_modified()
            end
        end
    elseif input_type == "text" then
        -- Handle text input (default behavior)
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
            if input_changed then
                node[manual_name] = new_value
                State.mark_as_modified()
            end
        end
    end
end

-- ========================================
-- Control Node Creation
-- ========================================

function BaseControl.create(node_type, position)
    local Constants = require("DevTester2.Constants")
    local node_id = State.next_node_id()

    local node = {
        id = node_id,
        category = Constants.NODE_CATEGORY_CONTROL,
        type = node_type,
        position = position or {x = 50, y = 50},
        ending_value = nil,
        status = nil,
        pins = { inputs = {}, outputs = {} }
    }

    -- Set type-specific properties
    if node_type == Constants.CONTROL_TYPE_SWITCH then
        node.condition_manual_value = ""
        node.true_value_manual_value = ""
        node.false_value_manual_value = ""
    elseif node_type == Constants.CONTROL_TYPE_TOGGLE then
        node.input_manual_value = ""
        node.enabled_manual_value = false
        node.toggle_state = false
    elseif node_type == Constants.CONTROL_TYPE_COUNTER then
        node.max_manual_value = "10"
        node.active_manual_value = false
        node.restart_manual_value = false
        node.counter_value = 0
    elseif node_type == Constants.CONTROL_TYPE_CONDITION then
        node.condition_manual_value = ""
        node.true_manual_value = ""
        node.false_manual_value = ""
    end

    table.insert(State.all_nodes, node)
    State.node_map[node_id] = node
    State.mark_as_modified()
    return node
end

return BaseControl
