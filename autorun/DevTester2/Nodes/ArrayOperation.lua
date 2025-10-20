local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local Constants = require("DevTester2.Constants")
local BaseOperation = require("DevTester2.Nodes.BaseOperation")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local ArrayOperation = {}

-- ========================================
-- Array Operation Node
-- ========================================

function ArrayOperation.render(node)
    local parent_value = BaseOperation.check_parent_connection(node)
    if not parent_value then return end

    -- Verify it's an array by trying to get size
    if not Helpers.is_array(parent_value) then
        Helpers.render_disconnected_operation_node(node, "type_error")
        return
    end

    imnodes.begin_node(node.node_id)

    -- Get actual array size for display
    local display_size = 0
    local success_size, size_result = pcall(function()
        return parent_value:get_Length()
    end)
    if success_size and size_result then
        display_size = size_result
    end

    local custom_title = string.format("%s [%d]", parent_value:get_type_definition():get_full_name(), display_size)
    BaseOperation.render_title_bar(node, nil, custom_title)

    BaseOperation.render_operation_dropdown(node, parent_value)

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
                        value_name = Helpers.get_type_display_name(type_info)
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
    
    -- Array navigation controls
    imgui.push_id("array_nav")
    
    -- Left arrow button (disabled if at first element or array is empty)
    local left_disabled = node.selected_element_index <= 0 or array_size == 0
    if left_disabled then
        imgui.begin_disabled()
    end
    if imgui.arrow_button("left", 0) then -- 0 = Left
        if node.selected_element_index > 0 then
            node.selected_element_index = node.selected_element_index - 1
            Helpers.mark_as_modified()
        end
    end
    if left_disabled then
        imgui.end_disabled()
    end
    
    imgui.same_line()
    
    -- Element dropdown (1-based for imgui combo)
    local dropdown_changed, new_selection = imgui.combo("Element", node.selected_element_index + 1, dropdown_options)
    if dropdown_changed then
        node.selected_element_index = new_selection - 1 -- Convert back to 0-based
        Helpers.mark_as_modified()
    end
    
    imgui.same_line()
    
    -- Right arrow button (disabled if at last element or array is empty)
    local right_disabled = node.selected_element_index >= array_size - 1 or array_size == 0
    if right_disabled then
        imgui.begin_disabled()
    end
    if imgui.arrow_button("right", 1) then -- 1 = Right
        if node.selected_element_index < array_size - 1 then
            node.selected_element_index = node.selected_element_index + 1
            Helpers.mark_as_modified()
        end
    end
    if right_disabled then
        imgui.end_disabled()
    end
    
    imgui.pop_id()

    imgui.spacing()
    
    -- Execute and show output
    local result = ArrayOperation.execute(node, parent_value)
    
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
    
    BaseOperation.render_output_attribute(node, result, can_continue)
    
    -- Action buttons
    BaseOperation.render_action_buttons(node, type(node.ending_value) == "userdata")

    BaseOperation.render_debug_info(node)
    
    imnodes.end_node()
end

function ArrayOperation.execute(node, parent_value)
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
    
    -- Validate index is within bounds
    if node.selected_element_index < 0 or node.selected_element_index >= array_size then
        node.status = string.format("Error: Index %d out of bounds (0-%d)", 
            node.selected_element_index, array_size - 1)
        return nil
    end
    
    -- Get the element at the selected index
    local success, result = pcall(function()
        return parent_value:get_element(node.selected_element_index)
    end)
    
    if not success then
        node.status = "Error: " .. tostring(result)
        return nil
    else
        node.status = nil
        return result
    end
end

return ArrayOperation