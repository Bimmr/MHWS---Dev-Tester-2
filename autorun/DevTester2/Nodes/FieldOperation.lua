local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local FieldOperation = {}

-- ========================================
-- Field Operation Node
-- ========================================

function FieldOperation.render(node)
    local parent_value = Helpers.get_parent_value(node)

    if not node.parent_node_id then
        Helpers.render_disconnected_operation_node(node, "no_parent")
        return
    elseif parent_value == nil then
        Helpers.render_disconnected_operation_node(node, "parent_nil")
        return
    end

    -- Get parent type for field enumeration
    local success, parent_type = pcall(function()
        return parent_value:get_type_definition()
    end)

    if not success or not parent_type then
        Helpers.render_disconnected_operation_node(node, "type_error")
        return
    end

    imnodes.begin_node(node.node_id)

    local pos_for_debug = imgui.get_cursor_pos()

    -- Title bar with type name and input pin
    imnodes.begin_node_titlebar()
    -- Main input pin with type name inside
    if not node.input_attr then
        node.input_attr = Helpers.next_pin_id()
    end

    imnodes.begin_input_attribute(node.input_attr)
    local type_name = parent_type:get_full_name()
    if #type_name > 35 then
        type_name = "..." .. string.sub(type_name, -32)
    end
    imgui.text(type_name)
    imnodes.end_input_attribute()
    imnodes.end_node_titlebar()

    -- Operation dropdown
    -- Note: imgui.combo uses 1-based indexing
    local has_children = Helpers.has_children(node)
    if has_children then
        imgui.begin_disabled()
    end
    
    -- Build operation options dynamically based on parent value type
    local operation_options = {"Method", "Field"}
    local operation_values = {0, 1} -- Corresponding operation values
    
    -- Only add Array option if parent value is an array
    if parent_value and Helpers.is_array(parent_value) then
        table.insert(operation_options, "Array")
        table.insert(operation_values, 2)
    end
    
    -- If current operation is not available, reset to first available option
    local current_option_index = 1
    for i, op_value in ipairs(operation_values) do
        if op_value == node.operation then
            current_option_index = i
            break
        end
    end
    
    local op_changed, new_option_index = imgui.combo("Operation", current_option_index, operation_options)
    if op_changed then
        node.operation = operation_values[new_option_index]
        Helpers.reset_operation_data(node)
        Helpers.mark_as_modified()
    end
    
    if has_children then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Cannot change operation while node has children")
        end
    end

    -- Type dropdown (Get/Set)
    if not node.action_type then
        node.action_type = 0 -- Default to Get
    end
    local has_children = Helpers.has_children(node)
    if has_children then
        imgui.begin_disabled()
    end
    local type_changed, new_type = imgui.combo("Type",
        node.action_type + 1, {"Get", "Set"})
    if type_changed then
        node.action_type = new_type - 1
        Helpers.reset_operation_data(node)
        
        -- If switching to Get, disconnect value input links
        if node.action_type == 0 then
            local value_pin = Helpers.get_field_value_pin_id(node)
            Helpers.remove_links_for_pin(value_pin)
        end

        Helpers.mark_as_modified()
    end
    if has_children then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Cannot change type while node has children")
        end
    end

    -- Build field list
    local fields = Helpers.get_fields_for_combo(parent_type)
    if #fields > 0 then
        -- Initialize to 1 if not set (imgui.combo is 1-based)
        if not node.selected_field_combo then
            node.selected_field_combo = 1
        end
        
        local has_children = Helpers.has_children(node)
        if has_children then
            imgui.begin_disabled()
        end
        local field_changed, new_combo_index = imgui.combo("Fields", 
            node.selected_field_combo, fields)
        if field_changed then
            node.selected_field_combo = new_combo_index
            
            -- Parse the group_index and field_index from the selected string
            if new_combo_index > 1 then
                local combo_field = fields[new_combo_index]
                local group_index, field_index = combo_field:match("(%d+)%-(%d+)")
                if group_index and field_index then
                    node.field_group_index = tonumber(group_index)
                    node.field_index = tonumber(field_index)
                else
                    -- Selected a separator, not an actual field
                    node.field_group_index = nil
                    node.field_index = nil
                end
            else
                node.field_group_index = nil
                node.field_index = nil
            end
            
            node.value_manual_input = "" -- Reset value
            
            -- Disconnect value input links since field type may have changed
            local value_pin = Helpers.get_field_value_pin_id(node)
            Helpers.remove_links_for_pin(value_pin)
            
            -- If we have a valid field selection, initialize manual input with current value
            if node.field_group_index and node.field_index then
                local current_field = Helpers.get_field_by_group_and_index(parent_type, 
                    node.field_group_index, node.field_index)
                if current_field then
                    local success, current_value = pcall(function()
                        return current_field:get_data(parent_value)
                    end)
                    if success and current_value ~= nil then
                        node.value_manual_input = tostring(current_value)
                    end
                end
            end
            
            Helpers.mark_as_modified()
        end
        if has_children then
            imgui.end_disabled()
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Cannot change field while node has children")
            end
        end
        
        local selected_field = nil
        if node.field_group_index and node.field_index then
            selected_field = Helpers.get_field_by_group_and_index(parent_type, 
                node.field_group_index, node.field_index)
        end
        
        -- Handle value input for Set
        if node.action_type == 1 and selected_field then -- Set
            imgui.spacing()
            local field_type = selected_field:get_type()
            -- Value input pin
            local value_pin_id = Helpers.get_field_value_pin_id(node)
            imnodes.begin_input_attribute(value_pin_id)
            local has_connection = Helpers.is_field_value_connected(node)
            if has_connection then
                local connected_value = Helpers.get_connected_field_value(node)
                -- Display simplified value without address
                local display_value = "Object"
                if type(connected_value) == "userdata" then
                    local success, type_info = pcall(function() return connected_value:get_type_definition() end)
                    if success and type_info then
                        display_value = type_info:get_name()
                    end
                else
                    display_value = tostring(connected_value)
                end
                imgui.begin_disabled()
                imgui.input_text("Value (" .. field_type:get_name() .. ")", display_value)
                imgui.end_disabled()
                if imgui.is_item_hovered() then
                    imgui.set_tooltip(field_type:get_full_name())
                end
            else
                node.value_manual_input = node.value_manual_input or ""
                local input_changed, new_value = imgui.input_text("Value (" .. field_type:get_name() .. ")", node.value_manual_input)
                if input_changed then
                    node.value_manual_input = new_value
                    Helpers.mark_as_modified()
                end
                if imgui.is_item_hovered() then
                    imgui.set_tooltip(field_type:get_full_name())
                end
            end
            imnodes.end_input_attribute()
            -- Active checkbox for setting the field
            node.set_active = node.set_active or false
            local active_changed, new_active = imgui.checkbox("Active", node.set_active)
            if active_changed then
                node.set_active = new_active
                Helpers.mark_as_modified()
            end
        end
        
        imgui.spacing()
        
        -- Execute and show output
        local result = FieldOperation.execute(node, parent_value, selected_field)
        
        -- Always store result, even if nil
        node.ending_value = result
        
        -- Check if result is userdata (can continue to child nodes)
        local can_continue = type(result) == "userdata"
        
        -- If result is valid, check if we should unpause child nodes
        if can_continue then
            local success, result_type = pcall(function() 
                return result:get_type_definition() 
            end)
            if success and result_type then
                local result_type_name = result_type:get_full_name()
                -- Try to unpause children if the type matches their expectations
                -- Helpers.unpause_child_nodes(node, result_type_name)
            end
        end
        
        -- Create output attribute if result is not nil, OR if we already have one from config
        local should_show_output = result ~= nil or node.output_attr
        if should_show_output then
            if not node.output_attr then
                node.output_attr = Helpers.next_pin_id()
            end
            
            -- Display output
            imnodes.begin_output_attribute(node.output_attr)
            
            if result ~= nil then
                -- Display the actual result
                local display_value = "Object"
                if type(result) == "userdata" then
                    local success, type_info = pcall(function() return result:get_type_definition() end)
                    if success and type_info then
                        display_value = Helpers.get_type_display_name(type_info)
                    end
                else
                    display_value = tostring(result)
                end
                local output_display = display_value .. " (?)"
                local pos = imgui.get_cursor_pos()
                local display_width = imgui.calc_text_size(output_display).x
                local node_width = imnodes.get_node_dimensions(node.node_id).x
                pos.x = pos.x + node_width - display_width - 26
                imgui.set_cursor_pos(pos)
                imgui.text(display_value)
                imgui.same_line()
                imgui.text("(?)")
                if imgui.is_item_hovered() then
                    if type(result) == "userdata" then
                        -- Show tooltip with detailed info including address
                        local address = string.format("0x%X", result:get_address())
                        local tooltip_text = string.format(
                            "Type: %s\nAddress: %s\nFull Name: %s",
                            type_info:get_name(), address, type_info:get_full_name()
                        )
                        imgui.set_tooltip(tooltip_text)
                    else
                        imgui.set_tooltip("Value: " .. tostring(result))
                    end
                end
            else
                -- Show nil/disconnected state
                local output_text = "nil"
                local pos = imgui.get_cursor_pos()
                local display_width = imgui.calc_text_size(output_text).x
                local node_width = imnodes.get_node_dimensions(node.node_id).x
                pos.x = pos.x + node_width - display_width - 26
                imgui.set_cursor_pos(pos)
                imgui.text(output_text)
            end
            
            imnodes.end_output_attribute()
        end
    else
        imgui.text("No fields available")
    end

    -- Action buttons
    imgui.spacing()
    local pos = imgui.get_cursor_pos()
    if imgui.button("- Remove Node") then
        Helpers.remove_operation_node(node)
    end
    -- Only show Add Child Node if result is userdata (can continue)
    if type(node.ending_value) == "userdata" then
        imgui.same_line()
        local display_width = imgui.calc_text_size("+ Add Child Node").x
        local node_width = imnodes.get_node_dimensions(node.node_id).x
        pos.x = pos.x + node_width - display_width - 20
        imgui.set_cursor_pos(pos)
        if imgui.button("+ Add Child Node") then
            Helpers.add_child_node(node)
        end
    end

    -- Debug info: Node ID, attributes, and connected Link IDs
    -- Collect all input attributes (main + params)
    local input_attrs = {}
    if node.input_attr then table.insert(input_attrs, tostring(node.input_attr)) end
    if node.value_input_attr then table.insert(input_attrs, tostring(node.value_input_attr)) end
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
        "Node ID: %s\nStatus: %s\nInput Attrs: %s\nOutput Attr: %s\nInput Links: %s\nOutput Links: %s",
        tostring(node.node_id),
        tostring(node.status or "None"),
        #input_attrs > 0 and table.concat(input_attrs, ", ") or "None",
        tostring(node.output_attr or "None"),
        #input_links > 0 and table.concat(input_links, ", ") or "None",
        #output_links > 0 and table.concat(output_links, ", ") or "None"
    )
    -- Code to align debug info to the top right of the node using stored pos
    local text_width = imgui.calc_text_size("[?]").x
    local node_width = imnodes.get_node_dimensions(node.node_id).x
    pos_for_debug.x = pos_for_debug.x + node_width - text_width - 16
    imgui.set_cursor_pos(pos_for_debug)
    imgui.text_colored("[?]", 0xFFDADADA)
    if imgui.is_item_hovered() then
        imgui.set_tooltip(debug_info)
    end
    imnodes.end_node()
end

function FieldOperation.execute(node, parent_value, selected_field)
    if not selected_field then
        return nil
    end

    local success, result

    if node.action_type == 0 then -- Get
        success, result = pcall(function()
            return selected_field:get_data(parent_value)
        end)
    else -- Set
        -- Check if setting is active
        if not node.set_active then
            -- Return current field value without setting
            success, result = pcall(function()
                return selected_field:get_data(parent_value)
            end)
        else
            -- Try to get value from connected input first
            local set_value = nil

            if node.value_input_attr then
                for _, link in ipairs(State.all_links) do
                    if link.to_pin == node.value_input_attr then
                        -- Find the source node
                        local source_node = Helpers.find_node_by_id(link.from_node)
                        if source_node and source_node.ending_value ~= nil then
                            set_value = source_node.ending_value
                            break
                        end
                    end
                end
            end

            -- If not connected, use manual input directly
            if set_value == nil then
                local manual_input = node.value_manual_input or ""
                if manual_input ~= "" then
                    set_value = Helpers.parse_primitive_value(manual_input)
                else
                    -- Use current field value
                    set_value = selected_field:get_data(parent_value)
                end
            end

            -- Execute set operation
            
            success, result = pcall(function()
                parent_value:set_field(selected_field:get_name(), set_value)
                return selected_field:get_data(parent_value) -- Return the new value
            end)
        end
    end

    if not success then
        node.status = "Error: " .. tostring(result)
        return nil
    else
        node.status = nil
        return result
    end
end

return FieldOperation