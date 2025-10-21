-- DevTester v2.0 - Base Follower
-- Common functionality for all follower nodes

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local BaseFollower = {}

-- ========================================
-- Common Rendering Functions
-- ========================================

function BaseFollower.check_parent_connection(node)
    local parent_value = Nodes.get_parent_value(node)

    if not node.parent_node_id then
        Nodes.render_disconnected_operation_node(node, "no_parent")
        return nil
    elseif parent_value == nil then
        Nodes.render_disconnected_operation_node(node, "parent_nil")
        return nil
    end

    return parent_value
end

function BaseFollower.get_parent_type(parent_value)
    local success, parent_type = pcall(function()
        return parent_value:get_type_definition()
    end)

    if not success or not parent_type then
        return nil
    end

    return parent_type
end

function BaseFollower.render_title_bar(node, parent_type, custom_title)
    imnodes.begin_node_titlebar()

    -- Main input pin with type name inside
    if not node.input_attr then
        node.input_attr = State.next_pin_id()
    end

    imnodes.begin_input_attribute(node.input_attr)

    if custom_title then
        imgui.text(custom_title)
    else
        local type_name = parent_type:get_full_name()
        if #type_name > 35 then
            type_name = "..." .. string.sub(type_name, -32)
        end
        imgui.text(type_name)
    end

    imnodes.end_input_attribute()
    imnodes.end_node_titlebar()
end

function BaseFollower.render_operation_dropdown(node, parent_value)
    -- Operation dropdown
    -- Note: imgui.combo uses 1-based indexing
    local has_children = Nodes.has_children(node)
    if has_children then
        imgui.begin_disabled()
    end

    -- Build operation options dynamically based on parent value type
    local operation_options = {"Method", "Field"}
    local operation_values = {Constants.FOLLOWER_TYPE_METHOD, Constants.FOLLOWER_TYPE_FIELD}

    -- Only add Array option if parent value is an array
    if parent_value and Utils.is_array(parent_value) then
        table.insert(operation_options, "Array")
        table.insert(operation_values, Constants.FOLLOWER_TYPE_ARRAY)
    end

    -- If current operation is not available, reset to first available option
    local current_option_index = 1
    for i, op_value in ipairs(operation_values) do
        if op_value == node.type then
            current_option_index = i
            break
        end
    end

    local op_changed, new_option_index = imgui.combo("Operation", current_option_index, operation_options)
    if op_changed then
        node.type = operation_values[new_option_index]
        Nodes.reset_operation_data(node)
        State.mark_as_modified()
    end

    if has_children then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Cannot change operation while node has children")
        end
    end
end

function BaseFollower.render_action_type_dropdown(node, action_options)
    if not node.action_type then
        node.action_type = Constants.ACTION_GET -- Default to Get
    end

    local has_children = Nodes.has_children(node)
    if has_children then
        imgui.begin_disabled()
    end

    local type_changed, new_type = imgui.combo("Type", node.action_type + 1, action_options)

    if type_changed then
        node.action_type = new_type - 1
        -- Selective reset for type changes - preserve parameter values
        node.ending_value = nil
        node.status = nil
        node.last_call_time = nil  -- Reset call timer when changing modes
        State.mark_as_modified()
    end

    if has_children then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Cannot change type while node has children")
        end
    end
end

function BaseFollower.render_debug_info(node)
    -- Collect all input attributes (main + params)
    local input_attrs = {}
    if node.input_attr then table.insert(input_attrs, tostring(node.input_attr)) end
    if node.param_manual_values then
        for i = 1, #(node.param_manual_values) do
            local param_pin_id = Nodes.get_param_pin_id(node, i)
            if param_pin_id then table.insert(input_attrs, tostring(param_pin_id)) end
        end
    end

    -- Find input and output links, showing pin/attr and link id
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
        "Node ID: %s\nInput Attrs: %s\nOutput Attr: %s\nInput Links: %s\nOutput Links: %s",
        tostring(node.node_id),
        #input_attrs > 0 and table.concat(input_attrs, ", ") or "None",
        tostring(node.output_attr or "None"),
        #input_links > 0 and table.concat(input_links, ", ") or "None",
        #output_links > 0 and table.concat(output_links, ", ") or "None"
    )

    -- Align debug info to the top right of the node
    local pos_for_debug = Utils.get_top_right_cursor_pos(node.node_id, "[?]")
    imgui.set_cursor_pos(pos_for_debug)
    imgui.text_colored("[?]", Constants.COLOR_TEXT_DEBUG)

    if imgui.is_item_hovered() then
        imgui.set_tooltip(debug_info)
    end
end

function BaseFollower.render_action_buttons(node, can_add_child)
    imgui.spacing()
    local pos = imgui.get_cursor_pos()
    if imgui.button("- Remove Node") then
        Nodes.remove_operation_node(node)
    end
    
    -- Show Add Child Node if condition is met (can_add_child can be a function or boolean)
    local should_show_add = false
    if type(can_add_child) == "function" then
        should_show_add = can_add_child(node)
    else
        should_show_add = can_add_child
    end
    
    if should_show_add then
        imgui.same_line()
        local display_width = imgui.calc_text_size("+ Add Child Node").x
        local node_width = imnodes.get_node_dimensions(node.node_id).x
        pos.x = pos.x + node_width - display_width - 20
        imgui.set_cursor_pos(pos)
        if imgui.button("+ Add Child Node") then
            Nodes.add_child_node(node)
        end
    end
end

function BaseFollower.render_output_attribute(node, result, can_continue)
    -- Create output attribute only if we should show the pin
    local should_show_output_pin = result ~= nil or node.output_attr
    
    if should_show_output_pin then
        if not node.output_attr then
            node.output_attr = State.next_pin_id()
        end
        imgui.spacing()
        imnodes.begin_output_attribute(node.output_attr)
    else
        imgui.spacing()
    end
    
    if result ~= nil then
        -- Display the actual result
        local display_value = "Object"
        if type(result) == "userdata" then
            local success, type_info = pcall(function() return result:get_type_definition() end)
            if success and type_info then
                display_value = type_info:get_name()
            end
        else
            display_value = tostring(result)
        end
        local output_display = display_value .. " (?)"
        local pos = Utils.get_right_cursor_pos(node.node_id, output_display)
        imgui.set_cursor_pos(pos)
        imgui.text(display_value)
        if can_continue then
            imgui.same_line()
            imgui.text("(?)")
            if imgui.is_item_hovered() then
                if type(result) == "userdata" and result.get_type_definition then
                    local type_info = result:get_type_definition()
                    local address = result.get_address and string.format("0x%X", result:get_address()) or "N/A"
                    local tooltip_text = string.format(
                        "Type: %s\nAddress: %s\nFull Name: %s",
                        type_info:get_name(), address, type_info:get_full_name()
                    )
                    imgui.set_tooltip(tooltip_text)
                else
                    imgui.set_tooltip(tostring(result))
                end
            end
        end
    else
        -- Display "nil" when result is nil
        local display_value = "nil"
        local output_display = display_value .. " (?)"
        local pos = Utils.get_right_cursor_pos(node.node_id, output_display)
        imgui.set_cursor_pos(pos)
        imgui.text(display_value)
        imgui.same_line()
        imgui.text("(?)")
        if imgui.is_item_hovered() then
            imgui.set_tooltip("nil")
        end
    end
    
    if should_show_output_pin then
        imnodes.end_output_attribute()
    end
end

return BaseFollower
