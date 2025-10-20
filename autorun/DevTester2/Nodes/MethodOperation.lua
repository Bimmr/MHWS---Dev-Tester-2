local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local MethodOperation = {}

-- ========================================
-- Method Operation Node
-- ========================================

function MethodOperation.render(node)
    local parent_value = Helpers.get_parent_value(node)

    if not node.parent_node_id then
        Helpers.render_disconnected_operation_node(node, "no_parent")
        return
    elseif parent_value == nil then
        Helpers.render_disconnected_operation_node(node, "parent_nil")
        return
    end

    -- Get parent type for method enumeration
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
    imgui.text(parent_type:get_full_name())
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

    -- Type dropdown (Run/Call)
    if not node.action_type then
        node.action_type = 0 -- Default to Run
    end
    local has_children = Helpers.has_children(node)
    if has_children then
        imgui.begin_disabled()
    end
    local type_changed, new_type = imgui.combo("Type",
        node.action_type + 1, {"Run", "Call"})
    if type_changed then
        node.action_type = new_type - 1
        -- Selective reset for type changes - preserve parameter values
        node.ending_value = nil
        node.status = nil
        node.last_call_time = nil  -- Reset call timer when changing modes

        Helpers.mark_as_modified()
    end
    if has_children then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Cannot change type while node has children")
        end
    end

    -- Method selection
    local methods = Helpers.get_methods_for_combo(parent_type)
    local returns_void = false  -- Declare at higher scope
    if #methods > 0 then
        -- Initialize to 1 if not set (imgui.combo is 1-based)
        if not node.selected_method_combo then
            node.selected_method_combo = 1
        end
        
        local has_children = Helpers.has_children(node)
        if has_children then
            imgui.begin_disabled()
        end
        local method_changed, new_combo_index = imgui.combo("Methods", 
            node.selected_method_combo, methods)
        if method_changed then
            node.selected_method_combo = new_combo_index
            
            -- Parse the group_index and method_index from the selected string
            if new_combo_index > 1 then
                local combo_method = methods[new_combo_index]
                local group_index, method_index = combo_method:match("(%d+)%-(%d+)")
                if group_index and method_index then
                    node.method_group_index = tonumber(group_index)
                    node.method_index = tonumber(method_index)
                else
                    -- Selected a separator, not an actual method
                    node.method_group_index = nil
                    node.method_index = nil
                end
            else
                node.method_group_index = nil
                node.method_index = nil
            end
            
            node.param_manual_values = {} -- Reset params
            
            -- Check if selected method returns void, if so switch to Call mode
            if node.method_group_index and node.method_index then
                local current_method = Helpers.get_method_by_group_and_index(parent_type, 
                    node.method_group_index, node.method_index)
                if current_method then
                    local success_return, return_type = pcall(function()
                        return current_method:get_return_type()
                    end)
                    if success_return and return_type then
                        local return_type_name = return_type:get_name()
                        if return_type_name == "Void" or return_type_name == "System.Void" then
                            node.action_type = 1 -- Switch to Call mode
                        end
                    end
                    
                    -- Disconnect links for parameters that no longer exist
                    local success_param, param_types = pcall(function() 
                        return current_method:get_param_types() 
                    end)
                    if success_param and param_types then
                        local new_param_count = #param_types
                        -- Remove links for parameter pins beyond the new count
                        for i = new_param_count + 1, 100 do -- Arbitrary high number to cover old params
                            local old_param_pin = Helpers.get_param_pin_id(node, i)
                            Helpers.remove_links_for_pin(old_param_pin)
                        end
                    else
                        -- No parameters, remove all param links
                        for i = 1, 100 do
                            local param_pin = Helpers.get_param_pin_id(node, i)
                            Helpers.remove_links_for_pin(param_pin)
                        end
                    end
                end
            else
                -- No method selected, remove all param links
                for i = 1, 100 do
                    local param_pin = Helpers.get_param_pin_id(node, i)
                    Helpers.remove_links_for_pin(param_pin)
                end
            end
            
            Helpers.mark_as_modified()
        end
        if has_children then
            imgui.end_disabled()
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Cannot change method while node has children")
            end
        end
        
        local selected_method = nil
        if node.method_group_index and node.method_index then
            selected_method = Helpers.get_method_by_group_and_index(parent_type, 
                node.method_group_index, node.method_index)
        end

        -- Handle parameters (show for both Run and Call)
        if selected_method then
            local success_param, param_types = pcall(function() 
                return selected_method:get_param_types() 
            end)
            
            if success_param and param_types and #param_types > 0 then
                imgui.spacing()
                
                if not node.param_manual_values then
                    node.param_manual_values = {}
                end
                
                for i, param_type in ipairs(param_types) do
                    -- Get parameter type name
                    local param_type_name = param_type:get_name()
                    
                    -- Parameter input pin
                    local param_pin_id = Helpers.get_param_pin_id(node, i)
                    imnodes.begin_input_attribute(param_pin_id)
                    local has_connection = Helpers.is_param_connected(node, i)
                    local label = string.format("Arg %d(%s)", i, param_type:get_name())
                    if has_connection then
                        local connected_value = Helpers.get_connected_param_value(node, i)
                        -- Display simplified value without address
                        local display_value = "Object"
                        if type(connected_value) == "userdata" then
                            local success, type_info = pcall(function() return connected_value:get_type_definition() end)
                            if success and type_info then
                                display_value = Helpers.get_type_display_name(type_info)
                            end
                        else
                            display_value = tostring(connected_value)
                        end
                        imgui.begin_disabled()
                        imgui.input_text(label, display_value)
                        imgui.end_disabled()
                        if imgui.is_item_hovered() then
                            imgui.set_tooltip(param_type:get_full_name())
                        end
                    else
                        node.param_manual_values[i] = node.param_manual_values[i] or ""
                        local input_changed, new_value = imgui.input_text(label, node.param_manual_values[i])
                        if input_changed then
                            node.param_manual_values[i] = new_value
                            Helpers.mark_as_modified()
                        end
                        if imgui.is_item_hovered() then
                            imgui.set_tooltip(param_type:get_full_name())
                        end
                    end
                    imnodes.end_input_attribute()
                end
            end
        end

        imgui.spacing()
        
        -- Execute and show output
        local result = nil
        
        -- Check if method returns void
        if selected_method then
            local success_return, return_type = pcall(function()
                return selected_method:get_return_type()
            end)
            if success_return and return_type then
                local return_type_name = return_type:get_name()
                returns_void = (return_type_name == "Void" or return_type_name == "System.Void")
            end
        end
        
        if node.action_type == 0 then -- Run - auto execute
            result = MethodOperation.execute(node, parent_value, selected_method)
        elseif node.action_type == 1 then -- Call - manual button
            -- Show Call Method button
            if imgui.button("Call Method") then
                result = MethodOperation.execute(node, parent_value, selected_method)
                node.last_call_time = os.clock()  -- Record call time with high precision
            else
                -- Keep previous result if button not clicked
                result = node.ending_value
            end
        end
        
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
        -- Create output attribute if result is not nil and method doesn't return void, OR if we already have one from config (but not for void methods)
        local should_show_output = (result ~= nil and not returns_void) or (node.output_attr and not returns_void)
        if should_show_output then
            if not node.output_attr then
                node.output_attr = Helpers.next_pin_id()
            end
            imgui.spacing()
            imnodes.begin_output_attribute(node.output_attr)
            
            if result ~= nil and not returns_void then
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
                    if type(result) == "userdata" then
                        local type_info = result:get_type_definition()
                        local address = string.format("0x%X", result:get_address())
                        local tooltip_text = string.format(
                            "Type: %s\nAddress: %s\nFull Name: %s",
                            type_info:get_name(), address, type_info:get_full_name()
                        )
                        imgui.set_tooltip(tooltip_text)
                    else
                        imgui.set_tooltip("Result: " .. tostring(result))
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
        elseif returns_void then
            -- For void methods, show execution status with tooltip only if executed
            if node.last_call_time then
                imgui.spacing()
                local elapsed = os.clock() - node.last_call_time
                local time_since_call
                if elapsed < 1 then
                    time_since_call = string.format("%.0fms ago", elapsed * 1000)
                else
                    time_since_call = string.format("%.1fs ago", elapsed)
                end
                local executed_text = "Executed | Last call: " .. time_since_call
                local pos = imgui.get_cursor_pos()
                local display_width = imgui.calc_text_size(executed_text).x
                local node_width = imnodes.get_node_dimensions(node.node_id).x
                pos.x = pos.x + node_width - display_width - 26
                imgui.set_cursor_pos(pos)
                imgui.text("Executed | Last call: " .. time_since_call)
                if imgui.is_item_hovered() then
                    -- Show tooltip with method info
                    local method_name = selected_method:get_name()
                    local return_type_name = "void"
                    local tooltip_text = string.format(
                        "Method: %s\nReturn Type: %s\nStatus: Executed successfully",
                        method_name, return_type_name
                    )
                    imgui.set_tooltip(tooltip_text)
                end
            else
                -- Show ready status for void methods that haven't been called
                imgui.spacing()
                local ready_text = "Ready"
                local pos = imgui.get_cursor_pos()
                local display_width = imgui.calc_text_size(ready_text).x
                local node_width = imnodes.get_node_dimensions(node.node_id).x
                pos.x = pos.x + node_width - display_width - 26
                imgui.set_cursor_pos(pos)
                imgui.text(ready_text)
            end
        end
    else
        imgui.text("No methods available")
    end

    -- Action buttons
    imgui.spacing()
    local pos = imgui.get_cursor_pos()
    if imgui.button("- Remove Node") then
        Helpers.remove_operation_node(node)
    end
    -- Only show Add Child Node if result is userdata and method doesn't return void
    if type(node.ending_value) == "userdata" and not returns_void then
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

function MethodOperation.execute(node, parent_value, selected_method)
    if not selected_method then
        return nil
    end

    -- Resolve parameters
    local params = MethodOperation.resolve_method_parameters(node, selected_method)
    if params and #params > 0 then
        -- Output all the params for debugging
        log.debug(node.node_id.." MethodOperation: Executing method with params:".. json.dump_string(params))
    end
    -- Execute method based on type
    local success, result
    if node.action_type == 0 then -- Run
        success, result = pcall(function()
            return selected_method:call(parent_value, table.unpack(params))
        end)
    else -- Call
        success, result = pcall(function()
            return parent_value:call(selected_method:get_name(), table.unpack(params))
        end)
    end

    if not success then
        node.status = "Error: " .. tostring(result)
        return nil
    else
        node.status = nil
        return result
    end
end

function MethodOperation.resolve_method_parameters(node, selected_method)
    local params = {}

    -- Get method param types
    local success, param_types = pcall(function() return selected_method:get_param_types() end)
    if not success or not param_types then
        return params
    end

    for i, param_type in ipairs(param_types) do
        -- Check if parameter is connected
        if Helpers.is_param_connected(node, i) then
            -- Use connected value
            local connected_value = Helpers.get_connected_param_value(node, i)
            table.insert(params, connected_value)
        else
            -- Use manual input
            local manual_value = node.param_manual_values[i] or ""
            if manual_value ~= "" then
                -- Try to parse the value
                local parsed_value = Helpers.parse_value_for_type(manual_value, param_type)
                table.insert(params, parsed_value)
            else
                -- Use nil as default
                table.insert(params, nil)
            end
        end
    end

    return params
end

return MethodOperation