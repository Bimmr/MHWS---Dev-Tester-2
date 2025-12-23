local State = require("DevTester2.State")
local Utils = require("DevTester2.Utils")
local Nodes = require("DevTester2.Nodes")
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
    if node.ending_value then
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
            -- Make sure key doesn't start with a _ (private)
            if tostring(key):sub(1,1) == "_" then
                goto continue
            end

            if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
                    value = tostring(value)
            elseif type(value) == "table" then
                value = json.dump_string(value)
            end
            if tostring(value) ~= "" then
                debug_info = debug_info .. string.format("\n%s: %s", tostring(key), tostring(value))
            end
            
            ::continue::
        end        
    end

    -- Position debug info in top right
    local pos_for_debug = Utils.get_top_right_cursor_pos(node.id, "[?]")
    imgui.set_cursor_pos(pos_for_debug)
    imgui.text_colored("[?]", 0xFFDADADA)
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
    local Constants = require("DevTester2.Constants")
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
        -- Enum-specific
        selected_enum_index = 1,
        enum_names = nil,
        enum_values = nil,
        -- Hook-specific
        method_name = "",
        hook_id = nil,
        is_initialized = false,
        return_override_manual = "",
        is_return_overridden = false
    }
    
    table.insert(State.all_nodes, node)
    State.node_map[node_id] = node  -- Add to hash map
    State.mark_as_modified()
    return node
end

return BaseStarter


