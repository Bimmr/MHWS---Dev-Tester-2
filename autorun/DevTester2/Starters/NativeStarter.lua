local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local BaseStarter = require("DevTester2.Starters.BaseStarter")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local NativeStarter = {}

function NativeStarter.render(node)
    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Native Starter")
    imnodes.end_node_titlebar()
    
    -- Path input - disable if node has children
    local has_children = Helpers.has_children(node)
    if has_children then
        imgui.begin_disabled()
    end
    local path_changed, new_path = imgui.input_text("Path", node.path or "")
    if path_changed then
        node.path = new_path
        node.method_name = ""  -- Reset method when path changes
        node.selected_method_combo = nil
        node.method_group_index = nil
        node.method_index = nil
        node.native_method_result = nil
        Helpers.mark_as_modified()
    end
    if has_children then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Cannot change path while node has children")
        end
    end
    local type_def, native_obj
    if node.path and node.path ~= "" then
        native_obj = sdk.get_native_singleton(node.path)
        type_def = sdk.find_type_definition(node.path)
        if type_def then
            local success_methods, methods = pcall(function() 
                return Helpers.get_methods_for_combo(type_def) 
            end)
            if success_methods and methods and #methods > 0 then
                if not node.selected_method_combo then
                    node.selected_method_combo = 1
                end
                
                -- Method selection - disable if node has children
                local has_children = Helpers.has_children(node)
                if has_children then
                    imgui.begin_disabled()
                end
                local method_changed, new_combo_index = imgui.combo("Method", 
                    node.selected_method_combo, methods)
                if method_changed then
                    node.selected_method_combo = new_combo_index
                    if new_combo_index > 1 then
                        local combo_method = methods[new_combo_index]
                        local group_index, method_index = combo_method:match("(%d+)%-(%d+)")
                        if group_index and method_index then
                            node.method_group_index = tonumber(group_index)
                            node.method_index = tonumber(method_index)
                            local success_get, selected_method = pcall(function()
                                return Helpers.get_method_by_group_and_index(type_def, 
                                    node.method_group_index, node.method_index)
                            end)
                            if success_get and selected_method then
                                node.method_name = selected_method:get_name()
                            else
                                node.method_name = ""
                            end
                        else
                            node.method_group_index = nil
                            node.method_index = nil
                            node.method_name = ""
                        end
                    else
                        node.method_group_index = nil
                        node.method_index = nil
                        node.method_name = ""
                    end
                    node.native_method_result = nil
                    Helpers.mark_as_modified()
                end
                if has_children then
                    imgui.end_disabled()
                    if imgui.is_item_hovered() then
                        imgui.set_tooltip("Cannot change method while node has children")
                    end
                end
            else
                imgui.text("No methods available")
            end
        end
    end
    if native_obj and type_def and node.method_name and node.method_name ~= "" then
        -- Get the selected method to check for parameters
        local selected_method = nil
        if node.method_group_index and node.method_index then
            local success_get, method = pcall(function()
                return Helpers.get_method_by_group_and_index(type_def, 
                    node.method_group_index, node.method_index)
            end)
            if success_get and method then
                selected_method = method
            end
        end

        -- Handle parameters if the method has any
        local param_values = {}
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
                                display_value = type_info:get_name()
                            end
                        else
                            display_value = tostring(connected_value)
                        end
                        imgui.begin_disabled()
                        imgui.input_text(label, display_value)
                        imgui.end_disabled()
                        table.insert(param_values, connected_value)
                    else
                        node.param_manual_values[i] = node.param_manual_values[i] or ""
                        local input_changed, new_value = imgui.input_text(label, node.param_manual_values[i])
                        if input_changed then
                            node.param_manual_values[i] = new_value
                            Helpers.mark_as_modified()
                        end
                        -- Parse the parameter value
                        local param_value = Helpers.parse_value_for_type(node.param_manual_values[i], param_type)
                        table.insert(param_values, param_value)
                    end
                    imnodes.end_input_attribute()
                end
            end
        end

        -- Call the native method with parameters
        local success, result = pcall(function()
            if #param_values > 0 then
                return sdk.call_native_func(native_obj, type_def, node.method_name, table.unpack(param_values))
            else
                return sdk.call_native_func(native_obj, type_def, node.method_name)
            end
        end)
        if success then
            node.native_method_result = result
            node.status = "Success"
        else
            node.native_method_result = nil
            node.status = "Error calling method"
        end
    end
    if node.native_method_result ~= nil then
        -- Always store result, even if nil
        node.ending_value = node.native_method_result
        
        -- Check if result is userdata (can continue to child nodes)
        local can_continue = type(node.native_method_result) == "userdata"
        
        -- Only create output attribute if result is not nil
        if node.native_method_result ~= nil then
            if not node.output_attr then
                node.output_attr = Helpers.next_pin_id()
            end
            imgui.spacing()
            imnodes.begin_output_attribute(node.output_attr)
            -- Display simplified value without address
            local display_value = "Object"
            if can_continue then
                local success, type_info = pcall(function() return node.native_method_result:get_type_definition() end)
                if success and type_info then
                    display_value = Helpers.get_type_display_name(type_info)
                end
            else
                display_value = tostring(node.native_method_result)
            end
            local output_display = display_value .. " (?)"
            local pos = Helpers.get_right_cursor_pos(node.node_id, output_display)
            imgui.set_cursor_pos(pos)
            imgui.text(display_value)
            if can_continue then
                imgui.same_line()
                imgui.text("(?)")
                if imgui.is_item_hovered() then
                    if type(node.native_method_result) == "userdata" and node.native_method_result.get_type_definition then
                        local type_info = node.native_method_result:get_type_definition()
                        local address = node.native_method_result.get_address and string.format("0x%X", node.native_method_result:get_address()) or "N/A"
                        local tooltip_text = string.format(
                            "Type: %s\nAddress: %s\nFull Name: %s",
                            type_info:get_name(), address, type_info:get_full_name()
                        )
                        imgui.set_tooltip(tooltip_text)
                    else
                        imgui.set_tooltip(tostring(node.native_method_result))
                    end
                end
            end
            imnodes.end_output_attribute()
        end
    else
        node.ending_value = nil
        if node.status == "Error calling method" then
            imgui.text_colored("Error calling method", 0xFFFF0000)
        end
    end
    imgui.spacing()
    
    BaseStarter.render_action_buttons(node)
    BaseStarter.render_debug_info(node)
    
    imnodes.end_node()
end

return NativeStarter