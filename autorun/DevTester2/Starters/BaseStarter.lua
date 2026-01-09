local State = require("DevTester2.State")
local Utils = require("DevTester2.Utils")
local Nodes = require("DevTester2.Nodes")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes

local BaseStarter = {}

-- ========================================
-- Base Starter Node Rendering Functions
-- ========================================

function BaseStarter.render_action_buttons(node)
    imgui.spacing()
    if imgui.button("- Remove Node") then
        Nodes.remove_node(node)
    end

    -- Only show Add Child Node if result is valid
    local can_continue, _ = Nodes.validate_continuation(node.ending_value, nil)
    if can_continue then
        imgui.same_line()
        local pos = Utils.get_right_cursor_pos(node.id, "+ Add Child Node")
        imgui.set_cursor_pos(pos)
        if imgui.button("+ Add Child Node") then
            Nodes.add_child_node(node)
        end
    end
end

function BaseStarter.render_debug_info(node)

    local holding_ctrl = imgui.is_key_down(imgui.ImGuiKey.Key_LeftCtrl) or imgui.is_key_down(imgui.ImGuiKey.Key_RightCtrl)
    local debug_info = ""
    if holding_ctrl then

        debug_info = debug_info .. "-- All Node Info --"
        -- Collect all node information for debugging and display
        local keys = Utils.get_sorted_keys(node)
        for _, key in ipairs(keys) do
            local value = node[key]
            -- Make sure key doesn't start with a _ (private)
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

function BaseStarter.render_node_hover_tooltip(node, tooltip_text)
    if imnodes.is_node_hovered(node.id) then
        imgui.set_tooltip(tooltip_text)
    end
end

-- ========================================
-- Node Creation
-- ========================================

function BaseStarter.create(node_type, position)
    local node_id = State.next_node_id()

    local node = {
        id = node_id,
        category = Constants.NODE_CATEGORY_STARTER,
        type = node_type,
        path = "",
        position = position or {x = 50, y = 50},
        ending_value = nil,
        status = nil,
        pins = { inputs = {}, outputs = {} },
        -- Parameter support for starters that need it (like Native)
        param_manual_values = {},
    }
    
    table.insert(State.all_nodes, node)
    State.node_map[node_id] = node  -- Add to hash map
    State.mark_as_modified()
    return node
end

-- ========================================
-- Serialization
-- ========================================

function BaseStarter.serialize(node, Config)
    return {
        id = node.id,
        category = node.category,
        type = node.type,
        position = {x = node.position.x, y = node.position.y},
        path = node.path,
        param_manual_values = node.param_manual_values,
        pins = Config.serialize_pins(node.pins)
    }
end

function BaseStarter.deserialize(data, Config)
    return {
        id = data.id,
        category = data.category,
        type = data.type,
        path = data.path or "",
        position = data.position or {x = 0, y = 0},
        ending_value = nil,
        status = nil,
        param_manual_values = data.param_manual_values or {},
        pins = Config.deserialize_pins(data.pins, data.id)
    }
end

return BaseStarter


