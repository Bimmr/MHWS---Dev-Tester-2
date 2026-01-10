-- DevTester v2.0 - Base Utility
-- Base module for utility nodes providing common rendering functionality

-- BaseUtility Node Properties:
-- This is the base class for all utility nodes (Label, etc.).
-- Utility nodes provide visual aids and annotations for the node graph.
-- The following properties define the state and configuration of utility nodes:
--
-- Configuration:
-- - text: String - The text content for text-based utility nodes like Label
--
-- Runtime Values:
-- - ending_value: Any - Output value if the utility node produces data
--
-- UI/Debug:
-- - status: String - Current status message for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes

local BaseUtility = {}

-- ========================================
-- Base Utility Node Rendering Functions
-- ========================================

function BaseUtility.render_action_buttons(node)
    imgui.spacing()
    if imgui.button("- Remove Node") then
        Nodes.remove_node(node)
    end
    
    -- Only show Add Child Node if result is valid
    local can_continue, _ = Nodes.validate_continuation(node.ending_value, nil)
    if can_continue then
        imgui.same_line()
        local pos = Utils.get_right_cursor_pos(node.id, "+ Add Child Node", 25)
        imgui.set_cursor_pos(pos)
        if imgui.button("+ Add Child Node") then
            Nodes.add_child_node(node)
        end
    end
end

function BaseUtility.render_debug_info(node)
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

-- ========================================
-- Utility Node Creation
-- ========================================

function BaseUtility.create(node_type, position)
    local Constants = require("DevTester2.Constants")
    local node_id = State.next_node_id()

    local node = {
        id = node_id,
        category = Constants.NODE_CATEGORY_UTILITY,
        type = node_type,
        position = position or {x = 50, y = 50},
        ending_value = nil,
        status = nil,
        pins = { inputs = {}, outputs = {} },
        -- Label-specific
        text = ""
    }

    table.insert(State.all_nodes, node)
    State.node_map[node_id] = node
    State.mark_as_modified()
    return node
end

-- ========================================
-- Serialization
-- ========================================

function BaseUtility.serialize(node, Config)
    return {
        id = node.id,
        category = node.category,
        type = node.type,
        position = {x = node.position.x, y = node.position.y},
        pins = Config.serialize_pins(node.pins)
    }
end

function BaseUtility.deserialize(data, Config)
    return {
        id = data.id,
        category = data.category,
        type = data.type,
        position = data.position or {x = 0, y = 0},
        ending_value = nil,
        status = nil,
        pins = Config.deserialize_pins(data.pins, data.id)
    }
end

return BaseUtility
