-- FieldFollower Node Properties:
-- This node accesses or modifies fields/properties of parent objects.
--
-- Pins:
-- - pins.inputs[1]: "parent" - Connection to parent node
-- - pins.inputs[2]: "value" - Value to set (only in Set mode)
-- - pins.outputs[1]: "output" - The field value result
--
-- Field Selection:
-- - selected_field_combo: Number - Index in the field selection dropdown (1-based)
-- - field_group_index: Number - Group index for organizing overloaded fields
-- - field_index: Number - Index of the selected field within its overload group
--
-- Field Setting (for Set mode):
-- - value_manual_input: String - Manual text input for the value to set
-- - set_active: Boolean - Whether the set operation is currently active/enabled
--
-- Runtime Values:
-- - ending_value: Any - The current field value (or the value that was just set)
-- - ending_value_full_name: String - Full type name of the ending value
--
-- Inherits all BaseFollower properties (type, action_type, status, etc.)

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseFollower = require("DevTester2.Followers.BaseFollower")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local FieldFollower = {}

-- ========================================
-- Field Follower Node
-- ========================================
-- TODO: Putting an array in a set field will crash the game - need to handle that case
function FieldFollower.render(node)
    -- Ensure pins exist
    if #node.pins.inputs == 0 then
        Nodes.add_input_pin(node, "parent", nil)
    end
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    local parent_value = BaseFollower.check_parent_connection(node)
    if not parent_value then 
        node.status = "Waiting for parent connection"
        return 
    end

    local parent_type = BaseFollower.get_parent_type(parent_value)
    -- if not parent_type then
    --     Nodes.render_disconnected_operation_node(node, "type_error")
    --     return
    -- end

    -- Determine if we're working with static fields (type definition) or instance fields (managed object)
    local is_static_context = BaseFollower.is_parent_type_definition(parent_value)

    imnodes.begin_node(node.id)

    BaseFollower.render_title_bar(node, parent_type)
    local has_children = Nodes.has_children(node)

    BaseFollower.render_operation_dropdown(node, parent_value)

    -- Type dropdown (Get/Set)
    local type_changed = BaseFollower.render_action_type_dropdown(node, {"Get", "Set"})
    if type_changed then
        -- If switching to Get, remove value input pin
        if node.action_type == 0 and #node.pins.inputs > 1 then
            table.remove(node.pins.inputs, 2)
        elseif node.action_type == 1 and #node.pins.inputs == 1 then
            -- Switching to Set, add value input pin
            Nodes.add_input_pin(node, "value", nil)
        end
    end

    -- Build field list
    if parent_type then
    local fields = Nodes.get_fields_for_combo(parent_type, is_static_context)
    if #fields > 0 then
        -- Initialize to 1 if not set (imgui.combo is 1-based)
        if not node.selected_field_combo then
            node.selected_field_combo = 1
        end
        
        -- Resolve signature if present
        if node.selected_field_signature then
            local group, idx = Nodes.find_field_indices_by_signature(parent_type, node.selected_field_signature, is_static_context)
            if group and idx then
                node.field_group_index = group
                node.field_index = idx
                -- Update combo index to match
                local combo_idx = Nodes.get_combo_index_for_field(parent_type, group, idx, is_static_context)
                if combo_idx > 0 then
                    node.selected_field_combo = combo_idx + 1 -- 1-based for combo
                end
                -- Clear signature after successful resolution
                node.selected_field_signature = nil
            end
        end

        local has_children = Nodes.has_children(node)
        if has_children then
            imgui.begin_disabled()
        end
        local field_changed, new_combo_index = Utils.hybrid_combo("Fields", 
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
                    
                    -- Update signature for persistence
                    local field = Nodes.get_field_by_group_and_index(parent_type, node.field_group_index, node.field_index, is_static_context)
                    if field then
                        node.selected_field_signature = Nodes.get_field_signature(field)
                    end
                else
                    -- Selected a separator, not an actual field
                    node.field_group_index = nil
                    node.field_index = nil
                    node.selected_field_signature = nil
                end
            else
                -- Selected empty/none
                node.field_group_index = nil
                node.field_index = nil
                node.selected_field_signature = nil
            end
            
            node.value_manual_input = "" -- Reset value
            
            -- Remove value input pin if it exists
            if #node.pins.inputs > 1 then
                table.remove(node.pins.inputs, 2)
            end
            
            -- Re-add value input pin if in Set mode
            if node.action_type == 1 then
                if #node.pins.inputs == 1 then
                    Nodes.add_input_pin(node, "value", nil)
                end
            end
            
            -- If we have a valid field selection, initialize manual input with current value
            if node.field_group_index and node.field_index then
                local current_field = Nodes.get_field_by_group_and_index(parent_type, 
                    node.field_group_index, node.field_index, is_static_context)
                if current_field then
                    local success, current_value
                    if is_static_context then
                        success, current_value = pcall(function()
                            return current_field:get_data(nil)
                        end)
                    else
                        success, current_value = pcall(function()
                            return current_field:get_data(parent_value)
                        end)
                    end
                    if success and current_value ~= nil then
                        node.value_manual_input = tostring(current_value)
                    end
                end
            end
            
            State.mark_as_modified()
        end
        if has_children then
            imgui.end_disabled()
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Cannot change field while node has children")
            end
        end
        
        local selected_field = nil
        if node.field_group_index and node.field_index then
            selected_field = Nodes.get_field_by_group_and_index(parent_type, 
                node.field_group_index, node.field_index, is_static_context)
        end        
        -- Handle value input for Set
        if node.action_type == 1 and selected_field then -- Set

            -- Ensure value input pin exists
            if #node.pins.inputs == 1 then
                Nodes.add_input_pin(node, "value", nil)
            end
            
            imgui.spacing()
            local field_type = selected_field:get_type()
            local value_pin = node.pins.inputs[2]
            
            -- Value input pin
            imnodes.begin_input_attribute(value_pin.id)
            local has_connection = value_pin.connection ~= nil
            if has_connection then
                -- Look up connected pin via State.pin_map
                local source_pin_info = State.pin_map[value_pin.connection.pin]
                local connected_value = source_pin_info and source_pin_info.pin.value
                -- Display simplified value without address
                local display_value = Utils.get_value_display_string(connected_value)
                imgui.begin_disabled()
                imgui.input_text("Value (" .. field_type:get_name() .. ")", display_value)
                imgui.end_disabled()
                if imgui.is_item_hovered() then
                    imgui.set_tooltip(field_type:get_full_name() .. "\n" .. Utils.get_tooltip_for_value(connected_value))
                end
            else
                node.value_manual_input = node.value_manual_input or ""
                local input_changed, new_value = imgui.input_text("Value (" .. field_type:get_name() .. ")", node.value_manual_input)
                if input_changed then
                    node.value_manual_input = new_value
                    State.mark_as_modified()
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
                State.mark_as_modified()
            end
        else
            -- Get mode - ensure only parent input pin exists
            if #node.pins.inputs > 1 then
                table.remove(node.pins.inputs, 2)
            end
        end
        if selected_field then
            Nodes.add_context_menu_option(node, "Copy field name", selected_field and selected_field:get_name() or "Unknown")
            Nodes.add_context_menu_option(node, "Copy field type", selected_field:get_type():get_full_name() or "Unknown")
        end
        imgui.spacing()
        
        -- Execute and show output
        local result = FieldFollower.execute(node, parent_value, selected_field)
        
        -- Always store result, even if nil
        node.ending_value = result
        if result then
            node.ending_value_full_name = selected_field:get_type():get_full_name()
        end
        
        -- Update output pin value
        node.pins.outputs[1].value = result

        -- Check if result is userdata (can continue to child nodes)
        local can_continue = true
        
        if selected_field then
            local field_type = selected_field:get_type()
            if field_type then
                local field_type_name = field_type:get_full_name()
                if Nodes.is_terminal_type(field_type_name) then
                    can_continue = false
                end
            end
        end
        
        if can_continue and result ~= nil then
            can_continue = type(result) == "userdata"
        end
        
        -- If result is valid, check if we should unpause child nodes
        if can_continue then
            local success, result_type = pcall(function() 
                return result:get_type_definition() 
            end)
            if success and result_type then
                local result_type_name = result_type:get_full_name()
                -- Try to unpause children if the type matches their expectations
                -- Nodes.unpause_child_nodes(node, result_type_name)
            end
        end
        
        -- Render output pin
        local output_pin = node.pins.outputs[1]
        imgui.spacing()
        imnodes.begin_output_attribute(output_pin.id)
        
        if result ~= nil then
            -- Display the actual result
            local display_value = Utils.get_value_display_string(result)
            local output_display = display_value .. " (?)"
            local pos = Utils.get_right_cursor_pos(node.id, output_display)
            imgui.set_cursor_pos(pos)
            imgui.text(display_value)
            if can_continue then
                Nodes.add_context_menu_option(node, "Copy output type", 
                    result:get_type_definition():get_full_name() or "Unknown")
                imgui.same_line()
                imgui.text("(?)")
                if imgui.is_item_hovered() then
                    imgui.set_tooltip(Utils.get_tooltip_for_value(result))
                end
            else
                Nodes.add_context_menu_option(node, "Copy output value", tostring(result))
            end
        else
            -- Display "nil" when result is nil
            local display_value = "nil"
            local output_display = display_value .. " (?)"
            local pos = Utils.get_right_cursor_pos(node.id, output_display)
            imgui.set_cursor_pos(pos)
            imgui.text(display_value)
            imgui.same_line()
            imgui.text("(?)")
            if imgui.is_item_hovered() then
                imgui.set_tooltip("nil")
            end
        end
        
        imnodes.end_output_attribute()
    else
        imgui.text("No fields available")
    end
    else
        if node.selected_field_signature then
             imgui.text("Signature: " .. node.selected_field_signature)
        else
             imgui.text("Connect parent to select field")
        end
    end

    -- Action buttons
    BaseFollower.render_action_buttons(node, type(node.ending_value) == "userdata")

    -- Debug info
    BaseFollower.render_debug_info(node)

    imnodes.end_node()
end

function FieldFollower.execute(node, parent_value, selected_field)
    if not selected_field then
        return nil
    end

    -- Determine if we're working with static fields
    local is_static_context = BaseFollower.is_parent_type_definition(parent_value)

    local success, result

    if node.action_type == 0 then -- Get
        if is_static_context then
            -- Static field get - call on nil (type definition context)
            success, result = pcall(function()
                return selected_field:get_data(nil)
            end)
        else
            -- Instance field get
            success, result = pcall(function()
                return selected_field:get_data(parent_value)
            end)
        end
    else -- Set
        -- Check if setting is active
        if not node.set_active then
            -- Return current field value without setting
            if is_static_context then
                success, result = pcall(function()
                    return selected_field:get_data(nil)
                end)
            else
                success, result = pcall(function()
                    return selected_field:get_data(parent_value)
                end)
            end
        else
            -- Try to get value from connected input first using pin system
            local set_value = nil

            -- Check if value input pin exists and is connected (pin 2)
            if #node.pins.inputs >= 2 then
                local value_pin = node.pins.inputs[2]
                if value_pin.connection then
                    -- Look up connected pin via State.pin_map
                    local source_pin_info = State.pin_map[value_pin.connection.pin]
                    if source_pin_info then
                        set_value = source_pin_info.pin.value
                    end
                end
            end

            -- If not connected, use manual input directly
            if set_value == nil then
                local manual_input = node.value_manual_input or ""
                if manual_input ~= "" then
                    set_value = Utils.parse_primitive_value(manual_input)
                else
                    -- Use current field value
                    if is_static_context then
                        set_value = selected_field:get_data(nil)
                    else
                        set_value = selected_field:get_data(parent_value)
                    end
                end
            end

            -- Execute set operation
            if is_static_context then
                -- Static field set - call on nil (type definition context)
                success, result = pcall(function()
                    parent_value:set_field(selected_field:get_name(), set_value)
                    return selected_field:get_data(nil) -- Return the new value
                end)
            else
                -- Instance field set
                success, result = pcall(function()
                    parent_value:set_field(selected_field:get_name(), set_value)
                    return selected_field:get_data(parent_value) -- Return the new value
                end)
            end
        end
    end

    if not success then
        node.status = "Error: " .. tostring(result)
        return nil
    else
        -- Set success status based on operation type and context
        local operation = is_static_context and "Static " or "Instance "
        if node.action_type == 0 then
            operation = operation .. "Get"
        else
            operation = operation .. "Set"
        end
        
        local field_name = selected_field:get_name()
        node.status = operation .. ": " .. field_name
        
        -- Update output pin value
        if #node.pins.outputs > 0 then
            node.pins.outputs[1].value = result
        end
        
        return result
    end
end

return FieldFollower
