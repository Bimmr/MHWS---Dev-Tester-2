-- DevTester v2.0 - Base Follower
-- Common functionality for all follower nodes

-- BaseFollower Node Properties:
-- This is the base class for all follower nodes (Field, Method, Array followers).
-- Follower nodes access properties/methods/elements of parent objects.
-- The following properties define the state and configuration of follower nodes:
--
-- Core Configuration:
-- - type: Number - Operation type (Constants.FOLLOWER_TYPE_METHOD, FIELD, or ARRAY)
-- - action_type: Number - Action mode (Constants.ACTION_GET/SET for fields, ACTION_RUN/CALL for methods)
--
-- Input/Output Pins:
-- - input_attr: Number - Pin ID for the main input attribute (receives parent object)
-- - output_attr: Number - Pin ID for the output attribute (provides result value)
--
-- Parameters (for methods):
-- - param_manual_values: Array - Manual text input values for method parameters (indexed by parameter position)
-- - param_input_attrs: Array - Pin IDs for parameter input attributes
--
-- Runtime Values:
-- - ending_value: Any - The result of the follower operation (field value, method return, or array element)
--
-- UI/Debug:
-- - status: String - Current status message for debugging
-- - last_call_time: Number - Timestamp when the operation was last executed

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

    if parent_value == nil then
        -- Clear output pins so children also see nil
        if node.pins and node.pins.outputs then
            for _, output_pin in ipairs(node.pins.outputs) do
                output_pin.value = nil
            end
        end
        
        -- Also clear ending_value
        node.ending_value = nil

        -- Check if there's actually a connection
        if not node.pins or not node.pins.inputs or #node.pins.inputs == 0 or not node.pins.inputs[1].connection then
            Nodes.render_disconnected_operation_node(node, "no_parent")
        else
            Nodes.render_disconnected_operation_node(node, "parent_nil")
        end
        return nil
    end

    return parent_value
end

function BaseFollower.get_parent_type(parent_value)
    -- Check if parent_value is already a type definition
    if type(parent_value) == "userdata" and parent_value.get_full_name then
        -- This is likely a type definition object
        local success, test_name = pcall(function() return parent_value:get_full_name() end)
        if success and test_name then
            return parent_value
        end
    end

    -- Otherwise, try to get type definition from managed object
    local success, parent_type = pcall(function()
        return parent_value:get_type_definition()
    end)

    if not success or not parent_type then
        return nil
    end

    return parent_type
end

function BaseFollower.handle_parent_type_change(node, parent_type)
    if not parent_type then return end

    local current_type_name = parent_type:get_full_name()
    
    if node.last_parent_type_name and node.last_parent_type_name ~= current_type_name then
        -- Type changed, reset selection
        
        if node.type == Constants.FOLLOWER_TYPE_METHOD then
            node.selected_method_combo = nil
            node.method_group_index = nil
            node.method_index = nil
            node.param_manual_values = {}
            
            -- Keep first input (parent)
            if node.pins and node.pins.inputs and #node.pins.inputs > 0 then
                local parent_pin = node.pins.inputs[1]
                node.pins.inputs = { parent_pin }
            end
            
        elseif node.type == Constants.FOLLOWER_TYPE_FIELD then
            node.selected_field_combo = nil
            node.field_group_index = nil
            node.field_index = nil
        elseif node.type == Constants.FOLLOWER_TYPE_ARRAY then
            node.selected_element_index = 0
        end
    end
    
    node.last_parent_type_name = current_type_name
end

function BaseFollower.is_parent_type_definition(parent_value)
    -- Check if parent_value is already a type definition
    if type(parent_value) == "userdata" and parent_value.get_full_name then
        local success, test_name = pcall(function() return parent_value:get_full_name() end)
        return success and test_name ~= nil
    end
    return false
end

function BaseFollower.render_title_bar(node, parent_type, custom_title)
    imnodes.begin_node_titlebar()

    -- Main input pin with type name inside
    local parent_pin = node.pins.inputs[1]
    if not parent_pin then
        -- Should not happen if node is properly initialized, but handle gracefully
        if custom_title then
            imgui.text(custom_title)
        else
            imgui.text("Follower")
        end
        imnodes.end_node_titlebar()
        return
    end

    imnodes.begin_input_attribute(parent_pin.id)

    if custom_title then
        imgui.text(custom_title)
    elseif parent_type then
        local full_name = parent_type:get_full_name()
        local is_long = #full_name > 50
        local display_name = is_long and ("..." .. string.sub(full_name, -50)) or full_name
        imgui.text(display_name)
        if is_long and imgui.is_item_hovered() then
            imgui.set_tooltip(full_name)
        end
    else
        imgui.text("Waiting for Type...")
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

    -- Align debug info to the top right of the node
    local pos_for_debug = Utils.get_top_right_cursor_pos(node.id, "[?]")
    imgui.set_cursor_pos(pos_for_debug)
    imgui.text_colored("[?]", Constants.COLOR_TEXT_DEBUG)

    if imgui.is_item_hovered() then
        imgui.set_tooltip(debug_info)
    end
end

function BaseFollower.render_action_buttons(node)
    imgui.spacing()
    local pos = imgui.get_cursor_pos()
    if imgui.button("- Remove Node") then
        Nodes.remove_node(node)
    end
    
    -- Calculate can_continue internally
    local parent_value = Nodes.get_parent_value(node)
    local can_continue, _ = Nodes.validate_continuation(node.ending_value, parent_value)
    
    if can_continue then
        imgui.same_line()
        local display_width = imgui.calc_text_size("+ Add Child Node").x
        local node_width = imnodes.get_node_dimensions(node.id).x
        pos.x = pos.x + node_width - display_width - 20
        imgui.set_cursor_pos(pos)
        if imgui.button("+ Add Child Node") then
            Nodes.add_child_node(node)
        end
    end
end

-- ========================================
-- Node Creation
-- ========================================

function BaseFollower.create(position)
    local Constants = require("DevTester2.Constants")
    local node_id = State.next_node_id()
    local node = {
        id = node_id,
        category = Constants.NODE_CATEGORY_FOLLOWER,
        type = Constants.FOLLOWER_TYPE_METHOD, -- Default to Method
        position = position or {x = 0, y = 0},
        pins = { inputs = {}, outputs = {} },
        -- Method-specific
        selected_method_combo = 1, -- 1-based indexing for combo
        method_group_index = nil, -- Parsed from selection
        method_index = nil, -- Parsed from selection
        param_manual_values = {},
        -- Field-specific
        selected_field_combo = 1, -- 1-based indexing for combo
        field_group_index = nil, -- Parsed from selection
        field_index = nil, -- Parsed from selection
        value_manual_input = "",
        -- Array-specific
        selected_element_index = 0,
        index_manual_value = "",
        -- Common
        starting_value = nil,
        ending_value = nil,
        status = nil
    }
    
    table.insert(State.all_nodes, node)
    State.node_map[node_id] = node  -- Add to hash map
    State.mark_as_modified()
    return node
end

return BaseFollower


