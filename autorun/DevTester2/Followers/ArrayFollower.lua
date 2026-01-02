-- ArrayFollower Node Properties:
-- This node accesses elements of array/collection objects by index.
--
-- Pins:
-- - pins.inputs[1]: "parent" - Connection to parent array
-- - pins.inputs[2]: "index" - Index value (optional connection)
-- - pins.outputs[1]: "output" - The array element value
--
-- Array Navigation:
-- - selected_element_index: Number - Index of the currently selected array element (0-based)
-- - index_manual_value: String - Manual text input for the array index
--
-- Runtime Values:
-- - ending_value: Any - The value of the selected array element
--
-- Inherits all BaseFollower properties (type, status, etc.)

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseFollower = require("DevTester2.Followers.BaseFollower")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local ArrayFollower = {}

-- ========================================
-- Array Follower Node
-- ========================================

function ArrayFollower.render(node)
    -- Ensure pins exist
    if #node.pins.inputs < 2 then
        if #node.pins.inputs == 0 then
            Nodes.add_input_pin(node, "parent", nil)
        end
        if #node.pins.inputs == 1 then
            Nodes.add_input_pin(node, "index", nil)
        end
    end
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    local parent_value = BaseFollower.check_parent_connection(node)
    if not parent_value then 
        node.status = "Waiting for parent connection"
        return 
    end

    -- Verify it's an array by trying to get size
    if not Utils.is_array(parent_value) then
        -- Clear output pins so children also see nil
        if node.pins and node.pins.outputs then
            for _, output_pin in ipairs(node.pins.outputs) do
                output_pin.value = nil
            end
        end
        node.ending_value = nil
        
        node.status = "Parent is not an array"
        Nodes.render_disconnected_operation_node(node, "type_error")
        return
    end

    imnodes.begin_node(node.id)

    -- Get actual array size for display
    local display_size = 0
    local success_size, size_result = pcall(function()
        return parent_value:get_Length()
    end)
    if success_size and size_result then
        display_size = size_result
    end

    local custom_title = string.format("%s [%d]", parent_value:get_type_definition():get_full_name(), display_size)
    if parent_value:get_type_definition() then
        BaseFollower.handle_parent_type_change(node, parent_value:get_type_definition())
        Nodes.add_context_menu_option(node, "Copy parent type", parent_value:get_type_definition():get_full_name())
    end

    BaseFollower.render_title_bar(node, nil, custom_title)

    BaseFollower.render_operation_dropdown(node, parent_value)

    -- Array navigation
    imgui.spacing()
    
    -- Get array size
    local array_size = 0
    local success_size, size_result = pcall(function()
        return parent_value:get_Length()
    end)
    if success_size and size_result then
        array_size = size_result
    end
    
    -- Initialize selected element index if not set
    if not node.selected_element_index then
        node.selected_element_index = 0
    end
    
    -- Ensure index is within bounds
    if node.selected_element_index >= array_size then
        node.selected_element_index = math.max(0, array_size - 1)
    end
    if node.selected_element_index < 0 then
        node.selected_element_index = 0
    end
    
    -- Build dropdown options for all array elements
    local dropdown_options = {}
    for i = 0, array_size - 1 do
        local success, element = pcall(function()
            return parent_value:get_element(i)
        end)
        if success and element then
            -- Format as "index. VALUE_NAME"
            local value_name = "null"
            if element ~= nil then
                if type(element) == "userdata" then
                    -- Try to get type name for objects
                    local type_success, type_info = pcall(function() return element:get_type_definition() end)
                    if type_success and type_info then
                        value_name = Utils.get_type_display_name(type_info)
                    else
                        value_name = "Object"
                    end
                else
                    -- For primitive types, show the actual value
                    value_name = tostring(element)
                    -- Truncate long strings
                    if #value_name > 20 then
                        value_name = value_name:sub(1, 17) .. "..."
                    end
                end
            end
            table.insert(dropdown_options, string.format("%d. %s", i, value_name))
        else
            table.insert(dropdown_options, string.format("%d. <error>", i))
        end
    end
    
    -- Determine which index to use for display: connected value takes priority over manual input, which takes priority over dropdown
    local display_index = node.selected_element_index -- Default from dropdown
    local has_index_input = false
    
    -- Check for connected index value using pin system
    local index_pin = node.pins.inputs[2]
    if index_pin.connection then
        -- Look up connected pin via State.pin_map
        local source_pin_info = State.pin_map[index_pin.connection.pin]
        local connected_index = source_pin_info and source_pin_info.pin.value
        if connected_index ~= nil then
            -- Try to convert to number
            local num_index = tonumber(connected_index)
            if num_index then
                display_index = math.floor(num_index)
                has_index_input = true
            end
        end
    -- Check for manual index input
    elseif node.index_manual_value and node.index_manual_value ~= "" then
        local num_index = tonumber(node.index_manual_value)
        if num_index then
            display_index = math.floor(num_index)
            has_index_input = true
        end
    end
    
    -- Ensure display index is within bounds for the dropdown
    if display_index < 0 then
        display_index = 0
    elseif display_index >= array_size and array_size > 0 then
        display_index = array_size - 1
    end
    
    -- Display current index and navigation controls within input attribute
    imnodes.begin_input_attribute(index_pin.id)
        
    -- Left arrow button (disabled if at first element, array is empty, or index input is provided)
    local left_disabled = display_index <= 0 or array_size == 0 or has_index_input
    if left_disabled then
        imgui.begin_disabled()
    end
    if imgui.arrow_button("left", 0) then -- 0 = Left
        if display_index > 0 then
            node.selected_element_index = display_index - 1
            State.mark_as_modified()
        end
    end
    if left_disabled then
        imgui.end_disabled()
    end
    
    imgui.same_line()
    local width = imgui.calc_item_width()
    imgui.set_next_item_width(width - 24)
    
    -- Element dropdown (1-based for imgui combo, disabled when index input is provided)
    if has_index_input then
        imgui.begin_disabled()
    end
    local dropdown_changed, new_selection = imgui.combo("##Element", display_index + 1, dropdown_options)
    if dropdown_changed and not has_index_input then
        node.selected_element_index = new_selection - 1 -- Convert back to 0-based
        State.mark_as_modified()
    end
    if has_index_input then
        imgui.end_disabled()
    end
    
    imgui.same_line()
    
    -- Right arrow button (disabled if at last element, array is empty, or index input is provided)
    local right_disabled = display_index >= array_size - 1 or array_size == 0 or has_index_input
    if right_disabled then
        imgui.begin_disabled()
    end
    if imgui.arrow_button("right", 1) then -- 1 = Right
        if display_index < array_size - 1 then
            node.selected_element_index = display_index + 1
            State.mark_as_modified()
        end
    end
    if right_disabled then
        imgui.end_disabled()
    end
    if has_index_input then
        imgui.begin_disabled()
    end
    imgui.same_line()
    imgui.text("Element")
    if has_index_input then
        imgui.end_disabled()
    end
    
    imnodes.end_input_attribute()
    Nodes.add_context_menu_option(node, "Copy index", tostring(node.selected_element_index))

    imgui.spacing()
    
    -- Execute and show output
    local result = ArrayFollower.execute(node, parent_value)
    
    -- Always store result, even if nil
    node.ending_value = result
    if result and result:get_type_definition() then
        node.ending_value_full_name = result:get_type_definition():get_full_name()
        Nodes.add_context_menu_option(node, "Copy output name", node.ending_value_full_name)
    end
    
    local can_continue
    can_continue, result = Nodes.validate_continuation(result, parent_value)
    node.ending_value = result
    
    -- Update output pin value
    node.pins.outputs[1].value = result
    
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
            imgui.same_line()
            imgui.text("(?)")
            if imgui.is_item_hovered() then
                imgui.set_tooltip(Utils.get_tooltip_for_value(result))
            end
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
    
    -- Action buttons
    BaseFollower.render_action_buttons(node)

    BaseFollower.render_debug_info(node)
    
    imnodes.end_node()
end

function ArrayFollower.execute(node, parent_value)
    if not parent_value then
        return nil
    end
    
    -- Get array size to validate index
    local array_size = 0
    local success_size, size_result = pcall(function()
        return parent_value:get_Length()
    end)
    if success_size and size_result then
        array_size = size_result
    else
        node.status = "Error: Cannot get array size"
        return nil
    end
    
    -- Determine which index to use: connected value takes priority over manual input, which takes priority over dropdown
    local selected_index = node.selected_element_index -- Default from dropdown
    
    -- Check for connected index value using pin system
    if #node.pins.inputs >= 2 then
        local index_pin = node.pins.inputs[2]
        if index_pin.connection then
            -- Look up connected pin via State.pin_map
            local source_pin_info = State.pin_map[index_pin.connection.pin]
            local connected_index = source_pin_info and source_pin_info.pin.value
            if connected_index ~= nil then
                -- Try to convert to number
                local num_index = tonumber(connected_index)
                if num_index then
                    selected_index = math.floor(num_index)
                end
            end
        -- Check for manual index input
        elseif node.index_manual_value and node.index_manual_value ~= "" then
            local num_index = tonumber(node.index_manual_value)
            if num_index then
                selected_index = math.floor(num_index)
            end
        end
    end
    
    -- Validate index is within bounds
    if selected_index < 0 or selected_index >= array_size then
        node.status = string.format("Error: Index %d out of bounds (0-%d)", 
            selected_index, array_size - 1)
        return nil
    end
    
    -- Get the element at the selected index
    local success, result = pcall(function()
        return parent_value:get_element(selected_index)
    end)
    
    if not success then
        node.status = "Error: " .. tostring(result)
        return nil
    else
        node.status = "Array access: index " .. selected_index
        
        -- Update output pin value
        if #node.pins.outputs > 0 then
            node.pins.outputs[1].value = result
        end
        
        return result
    end
end

return ArrayFollower
