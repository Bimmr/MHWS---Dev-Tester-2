-- BaseData Node Properties:
-- This is the base class for all data nodes, providing common rendering and utility functions.
-- Data nodes inherit from BaseData but don't have their own specific properties beyond:
--
-- Common Properties (inherited by all data nodes):
-- - output_attr: Number - Pin ID for the output attribute (provides the node's data value)
-- - ending_value: Any - The current output value of the node
-- - status: String - Current status message for debugging
-- - node_id: Number - Unique identifier for the node in the graph

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes

local BaseData = {}

-- ========================================
-- Base Data Node Rendering Functions
-- ========================================

function BaseData.render_action_buttons(node)
    imgui.spacing()
    if imgui.button("- Remove Node") then
        Nodes.remove_node(node)
    end

    -- Data nodes typically don't add child nodes since they're data providers
    -- But we could add other data-specific actions here if needed
end

function BaseData.render_debug_info(node)
 
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

        -- Collect pin info
        local output_pins = {}
        if node.pins and node.pins.outputs then
            for _, pin in ipairs(node.pins.outputs) do
                table.insert(output_pins, tostring(pin.id))
            end
        end

        debug_info = debug_info .. string.format(
            "\n\nNode ID: %s\nOutput Pins: %s\nInput Links: %s\nOutput Links: %s",
            tostring(node.node_id),
            #output_pins > 0 and table.concat(output_pins, ", ") or "None",
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

function BaseData.render_node_hover_tooltip(node, tooltip_text)
    if imnodes.is_node_hovered(node.node_id) then
        imgui.set_tooltip(tooltip_text)
    end
end

-- ========================================
-- Node Creation
-- ========================================

function BaseData.create(node_type, position)
    local Constants = require("DevTester2.Constants")
    local node_id = State.next_node_id()

    local node = {
        id = node_id,
        node_id = node_id,
        category = Constants.NODE_CATEGORY_DATA,
        type = node_type,
        path = "",
        position = position or {x = 50, y = 50},
        ending_value = nil,
        status = nil,
        pins = { inputs = {}, outputs = {} },
        -- Enum-specific
        selected_enum_index = 1,
        enum_names = nil,
        enum_values = nil,
        -- Value-specific
        value = "",
        -- Variable-specific
        variable_name = "",
        default_value = "",
        input_manual_value = "",
        pending_reset = false
    }
    
    table.insert(State.all_nodes, node)
    State.node_map[node_id] = node  -- Add to hash map
    State.mark_as_modified()
    return node
end

return BaseData
