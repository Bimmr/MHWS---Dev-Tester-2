-- FieldFollower Node Properties:
-- This node accesses or modifies fields/properties of parent objects.
-- The following properties define the state and configuration of a FieldFollower node:
--
-- Field Selection:
-- - selected_field_combo: Number - Index in the field selection dropdown (1-based)
-- - field_group_index: Number - Group index for organizing overloaded fields
-- - field_index: Number - Index of the selected field within its overload group
--
-- Field Setting (for Set mode):
-- - value_manual_input: String - Manual text input for the value to set
-- - set_active: Boolean - Whether the set operation is currently active/enabled
-- - value_input_attr: Number - Pin ID for the value input attribute (for connected set values)
--
-- Runtime Values:
-- - ending_value: Any - The current field value (or the value that was just set)
-- - ending_value_full_name: String - Full type name of the ending value
--
-- Inherits all BaseFollower properties (input_attr, output_attr, type, action_type, status, etc.)

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
    local parent_value = BaseFollower.check_parent_connection(node)
    if not parent_value then return end

    local parent_type = BaseFollower.get_parent_type(parent_value)
    if not parent_type then
        Nodes.render_disconnected_operation_node(node, "type_error")
        return
    end

    imnodes.begin_node(node.node_id)

    BaseFollower.render_title_bar(node, parent_type)
    local has_children = Nodes.has_children(node)

    BaseFollower.render_operation_dropdown(node, parent_value)

    -- Type dropdown (Get/Set)
    local type_changed = BaseFollower.render_action_type_dropdown(node, {"Get", "Set"})
    if type_changed then
        -- If switching to Get, disconnect value input links
        if node.action_type == 0 then
            local value_pin = Nodes.get_field_value_pin_id(node)
            Nodes.remove_links_for_pin(value_pin)
        end
    end

    -- Build field list
    local fields = Nodes.get_fields_for_combo(parent_type)
    if #fields > 0 then
        -- Initialize to 1 if not set (imgui.combo is 1-based)
        if not node.selected_field_combo then
            node.selected_field_combo = 1
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
            local value_pin = Nodes.get_field_value_pin_id(node)
            Nodes.remove_links_for_pin(value_pin)
            
            -- If we have a valid field selection, initialize manual input with current value
            if node.field_group_index and node.field_index then
                local current_field = Nodes.get_field_by_group_and_index(parent_type, 
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
                node.field_group_index, node.field_index)
        end
        
        -- Handle value input for Set
        if node.action_type == 1 and selected_field then -- Set
            imgui.spacing()
            local field_type = selected_field:get_type()
            -- Value input pin
            local value_pin_id = Nodes.get_field_value_pin_id(node)
            imnodes.begin_input_attribute(value_pin_id)
            local has_connection = Nodes.is_field_value_connected(node)
            if has_connection then
                local connected_value = Nodes.get_connected_field_value(node)
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
        end
        
        imgui.spacing()
        
        -- Execute and show output
        local result = FieldFollower.execute(node, parent_value, selected_field)
        
        -- Always store result, even if nil
        node.ending_value = result
        if result then
            node.ending_value_full_name = selected_field:get_type():get_full_name()
        end

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
                -- Nodes.unpause_child_nodes(node, result_type_name)
            end
        end
        
        BaseFollower.render_output_attribute(node, result, can_continue)
    else
        imgui.text("No fields available")
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
                        local source_node = Nodes.find_node_by_id(link.from_node)
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
                    set_value = Utils.parse_primitive_value(manual_input)
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

return FieldFollower