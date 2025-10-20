local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local ArrayOperation = {}

-- ========================================
-- Array Operation Node
-- ========================================

function ArrayOperation.render(node)
    local parent_value = Helpers.get_parent_value(node)

    if not node.parent_node_id then
        Helpers.render_disconnected_operation_node(node, "no_parent")
        return
    elseif parent_value == nil then
        Helpers.render_disconnected_operation_node(node, "parent_nil")
        return
    end

    -- Verify it's an array by trying to get size
   if not Helpers.is_array(parent_value) then
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
    -- Get actual array size for display
    local display_size = 0
    local success_size, size_result = pcall(function()
        return parent_value:get_Length()
    end)
    if success_size and size_result then
        display_size = size_result
    end
    imgui.text(string.format("%s [%d]", parent_value:get_type_definition():get_full_name(), display_size))
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
    
    -- Create output attribute only if can continue
    if can_continue and not node.output_attr then
        node.output_attr = Helpers.next_pin_id()
    end
    
    -- Display output
    if can_continue then
        imnodes.begin_output_attribute(node.output_attr)
        
        -- Display simplified value without address
        local display_value = "Object"
        local success, type_info = pcall(function() return result:get_type_definition() end)
        if success and type_info then
            display_value = Helpers.get_type_display_name(type_info)
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
            -- Show tooltip with detailed info including address
            local address = string.format("0x%X", result:get_address())
            local tooltip_text = string.format(
                "Type: %s\nAddress: %s\nFull Name: %s",
                type_info:get_name(), address, type_info:get_full_name()
            )
            imgui.set_tooltip(tooltip_text)
        end
        
        imnodes.end_output_attribute()
    else
        -- Show nil or non-userdata result
        local output_text = result == nil and "nil" or tostring(result)
        local pos = imgui.get_cursor_pos()
        local display_width = imgui.calc_text_size(output_text).x
        local node_width = imnodes.get_node_dimensions(node.node_id).x
        pos.x = pos.x + node_width - display_width - 26
        imgui.set_cursor_pos(pos)
        imgui.text(output_text)
    end
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
    if node.param_manual_values then
        for i = 1, #(node.param_manual_values) do
            local param_pin_id = Helpers.get_param_pin_id(node, i)
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
        "Status: %s\nNode ID: %s\nInput Attrs: %s\nOutput Attr: %s\nInput Links: %s\nOutput Links: %s",
        tostring(node.status or "None"),
        tostring(node.node_id),
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