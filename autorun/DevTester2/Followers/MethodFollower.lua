local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseFollower = require("DevTester2.Followers.BaseFollower")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local MethodFollower = {}

-- ========================================
-- Method Follower Node
-- ========================================

function MethodFollower.render(node)
    local parent_value = BaseFollower.check_parent_connection(node)
    if not parent_value then return end

    local parent_type = BaseFollower.get_parent_type(parent_value)
    if not parent_type then
        Nodes.render_disconnected_operation_node(node, "type_error")
        return
    end

    imnodes.begin_node(node.node_id)

    BaseFollower.render_title_bar(node, parent_type)

    BaseFollower.render_operation_dropdown(node, parent_value)

    -- Type dropdown (Run/Call)
    BaseFollower.render_action_type_dropdown(node, {"Run", "Call"})

    -- Method selection
    local methods = Nodes.get_methods_for_combo(parent_type)
    local returns_void = false  -- Declare at higher scope
    if #methods > 0 then
        -- Initialize to 1 if not set (imgui.combo is 1-based)
        if not node.selected_method_combo then
            node.selected_method_combo = 1
        end

        local has_children = Nodes.has_children(node)
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
                local current_method = Nodes.get_method_by_group_and_index(parent_type,
                    node.method_group_index, node.method_index)
                if current_method then
                    local success_return, return_type = pcall(function()
                        return current_method:get_return_type()
                    end)
                    if success_return and return_type then
                        local return_type_name = return_type:get_name()
                        if return_type_name == "Void" or return_type_name == "System.Void" then
                            node.action_type = Constants.ACTION_SET -- Switch to Call mode
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
                            if node.param_input_attrs and node.param_input_attrs[i] then
                                Nodes.remove_links_for_pin(node.param_input_attrs[i])
                            end
                        end
                    else
                        -- No parameters, remove all param links
                        if node.param_input_attrs then
                            for i, pin_id in pairs(node.param_input_attrs) do
                                Nodes.remove_links_for_pin(pin_id)
                            end
                        end
                    end
                end
            else
                -- No method selected, remove all param links
                if node.param_input_attrs then
                    for i, pin_id in pairs(node.param_input_attrs) do
                        Nodes.remove_links_for_pin(pin_id)
                    end
                end
            end

            State.mark_as_modified()
        end
        if has_children then
            imgui.end_disabled()
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Cannot change method while node has children")
            end
        end
        
        local selected_method = nil
        if node.method_group_index and node.method_index then
            selected_method = Nodes.get_method_by_group_and_index(parent_type, 
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
                    local param_pin_id = Nodes.get_param_pin_id(node, i)
                    imnodes.begin_input_attribute(param_pin_id)
                    local has_connection = Nodes.is_param_connected(node, i)
                    local label = string.format("Arg %d(%s)", i, param_type:get_name())
                    if has_connection then
                        local connected_value = Nodes.get_connected_param_value(node, i)
                        -- Display simplified value without address
                        local display_value = "Object"
                        if type(connected_value) == "userdata" then
                            local success, type_info = pcall(function() return connected_value:get_type_definition() end)
                            if success and type_info then
                                display_value = Utils.get_type_display_name(type_info)
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
                            State.mark_as_modified()
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
            result = MethodFollower.execute(node, parent_value, selected_method)
        elseif node.action_type == 1 then -- Call - manual button
            -- Show Call Method button
            if imgui.button("Call Method") then
                result = MethodFollower.execute(node, parent_value, selected_method)
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
                -- Nodes.unpause_child_nodes(node, result_type_name)
            end
        end
        -- Create output attribute only if we should show the pin
        local should_show_output_pin = (result ~= nil and not returns_void) or (node.output_attr and not returns_void)
        
        if should_show_output_pin then
            if not node.output_attr then
                node.output_attr = State.next_pin_id()
            end
            imgui.spacing()
            imnodes.begin_output_attribute(node.output_attr)
        else
            imgui.spacing()
        end
        
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
            local pos = Utils.get_right_cursor_pos(node.node_id, output_display)
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
        elseif returns_void then
            -- For void methods, show execution status
            if node.last_call_time then
                local elapsed = os.clock() - node.last_call_time
                local time_since_call
                if elapsed < 1 then
                    time_since_call = string.format("%.0fms ago", elapsed * 1000)
                else
                    time_since_call = string.format("%.1fs ago", elapsed)
                end
                local executed_text = "Executed | Last call: " .. time_since_call
                local pos = Utils.get_right_cursor_pos(node.node_id, executed_text)
                imgui.set_cursor_pos(pos)
                imgui.text(executed_text)
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
                local ready_text = "Ready"
                local pos = Utils.get_right_cursor_pos(node.node_id, ready_text)
                imgui.set_cursor_pos(pos)
                imgui.text(ready_text)
            end
        else
            -- Show nil state
            local output_text = "nil"
            local pos = Utils.get_right_cursor_pos(node.node_id, output_text)
            imgui.set_cursor_pos(pos)
            imgui.text(output_text)
        end
        
        if should_show_output_pin then
            imnodes.end_output_attribute()
        end
    else
        imgui.text("No methods available")
    end

    -- Action buttons
    BaseFollower.render_action_buttons(node, function(node) 
        return type(node.ending_value) == "userdata" and not returns_void 
    end)

    -- Debug info
    BaseFollower.render_debug_info(node)

    imnodes.end_node()
end

function MethodFollower.execute(node, parent_value, selected_method)
    if not selected_method then
        return nil
    end

    -- Resolve parameters
    local params = MethodFollower.resolve_method_parameters(node, selected_method)
    if params and #params > 0 then
        -- Output all the params for debugging
        log.debug(node.node_id.." MethodFollower: Executing method with params:".. json.dump_string(params))
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

function MethodFollower.resolve_method_parameters(node, selected_method)
    local params = {}

    -- Get method param types
    local success, param_types = pcall(function() return selected_method:get_param_types() end)
    if not success or not param_types then
        return params
    end

    for i, param_type in ipairs(param_types) do
        -- Check if parameter is connected
        if Nodes.is_param_connected(node, i) then
            -- Use connected value
            local connected_value = Nodes.get_connected_param_value(node, i)
            table.insert(params, connected_value)
        else
            -- Use manual input
            local manual_value = node.param_manual_values[i] or ""
            if manual_value ~= "" then
                -- Try to parse the value
                local parsed_value = Utils.parse_value_for_type(manual_value, param_type)
                table.insert(params, parsed_value)
            else
                -- Use nil as default
                table.insert(params, nil)
            end
        end
    end

    return params
end

return MethodFollower
