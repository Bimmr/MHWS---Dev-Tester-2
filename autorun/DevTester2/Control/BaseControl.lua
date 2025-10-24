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

function BaseControl.render_action_buttons(node)
    imgui.spacing()
    if imgui.button("- Remove Node") then
        Nodes.remove_operation_node(node)  -- Control nodes are stored in all_nodes like operations
    end

    -- Control nodes typically don't add child nodes since they're control flow providers
    -- But we could add other control-specific actions here if needed
end

function BaseControl.render_debug_info(node)

    local holding_ctrl = imgui.is_key_down(imgui.ImGuiKey.Key_LeftCtrl) or imgui.is_key_down(imgui.ImGuiKey.Key_RightCtrl)
    local debug_info = string.format("Status: %s", tostring(node.status or "None"))
    if holding_ctrl then
        
        
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

        debug_info = debug_info .. string.format(
            "\n\nNode ID: %s\nOutput Attr: %s\nInput Links: %s\nOutput Links: %s",
            tostring(node.node_id),
            tostring(node.output_attr or "None"),
            #input_links > 0 and table.concat(input_links, ", ") or "None",
            #output_links > 0 and table.concat(output_links, ", ") or "None"
        )
            
            debug_info = debug_info .. "\n\n-- All Node Info --"
            -- Collect all node information for debugging and display
            for key, value in pairs(node) do
                if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
                        value = tostring(value)
                elseif type(value) == "table" then
                    value = json.dump_string(value)
                end
                if tostring(value) ~= "" then
                    debug_info = debug_info .. string.format("\n%s: %s", tostring(key), tostring(value))
                end
            end
        end

    -- Position debug info in top right
    local pos_for_debug = Utils.get_top_right_cursor_pos(node.node_id, "[?]")
    imgui.set_cursor_pos(pos_for_debug)
    imgui.text_colored("[?]", Constants.COLOR_TEXT_DEBUG)
    if imgui.is_item_hovered() then
        imgui.set_tooltip(debug_info)
    end
end

function BaseControl.render_input_pin(node, label, attr_name, converted_value, original_value)
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
        if input_changed then
            node[manual_name] = new_value
            State.mark_as_modified()
        end
    end
end

return BaseControl
