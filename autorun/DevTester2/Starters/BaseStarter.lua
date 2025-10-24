local State = require("DevTester2.State")
local Utils = require("DevTester2.Utils")
local Nodes = require("DevTester2.Nodes")
local imgui = imgui
local imnodes = imnodes

local BaseStarter = {}

-- ========================================
-- Base Starter Node Rendering Functions
-- ========================================

function BaseStarter.render_output_attribute(node, display_value, tooltip_text)
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

function BaseStarter.render_action_buttons(node)
    imgui.spacing()
    if imgui.button("- Remove Node") then
        Nodes.remove_starter_node(node)
    end

    -- Only show Add Child Node if result is valid
    if node.ending_value then
        imgui.same_line()
        local pos = Utils.get_right_cursor_pos(node.node_id, "+ Add Child Node")
        imgui.set_cursor_pos(pos)
        if imgui.button("+ Add Child Node") then
            Nodes.add_child_node(node)
        end
    end
end

function BaseStarter.render_debug_info(node)

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

        debug_info = debug_info .. string.format("\n\nInput Links: %s\nOutput Links: %s",
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
    imgui.text_colored("[?]", 0xFFDADADA)
    if imgui.is_item_hovered() then
        imgui.set_tooltip(debug_info)
    end
end

function BaseStarter.render_node_hover_tooltip(node, tooltip_text)
    if imnodes.is_node_hovered(node.node_id) then
        imgui.set_tooltip(tooltip_text)
    end
end

return BaseStarter
