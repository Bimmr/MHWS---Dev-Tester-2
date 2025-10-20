local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local BaseStarter = require("DevTester2.Starters.BaseStarter")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local HookStarter = {}

local function convert_ptr(arg, td_name)
	local output
	local is_float = td_name and (td_name=="System.Single")
	if not pcall(function()
		local mobj = sdk.to_managed_object(arg)
		output = (mobj and mobj:add_ref()) or (is_float and sdk.to_float(arg)) or sdk.to_int64(arg) or tostring(arg)
	end) then
		output = (is_float and sdk.to_float(arg)) or sdk.to_int64(arg) or tostring(arg)
	end
	if td_name and not is_float and tonumber(output) then
		pcall(function()
			local vt = sdk.to_valuetype(output, td_name)
			if vt and vt.mValue ~= nil then
				output = vt.mValue
			else
				output = vt and (((vt["ToString"] and vt:call("ToString()")) or vt) or vt) or output
			end
		end)
	end
	return output
end

function HookStarter.render(node)
    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Hook Starter")
    imnodes.end_node_titlebar()

    if node.is_initialized then
        imgui.begin_disabled()
    end
    -- Path input - disable if node has children
    local has_children = Helpers.has_children(node)
    if has_children then
        imgui.begin_disabled()
    end
    local path_changed, new_path = imgui.input_text("Path", node.path)
    if path_changed then
        node.path = new_path
        node.method_name = ""  -- Reset method when path changes
        node.selected_method_combo = nil
        node.method_group_index = nil
        node.method_index = nil
        Helpers.mark_as_modified()
    end
    if has_children then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Cannot change path while node has children")
        end
    end
    if node.path and node.path ~= "" then
        local success_type, type_def = pcall(function() 
            return sdk.find_type_definition(node.path) 
        end)
        if success_type and type_def then
            local success_methods, methods = pcall(function() 
                return Helpers.get_methods_for_combo(type_def) 
            end)
            if success_methods and methods and #methods > 0 then
                -- Reconstruct selected_method_combo from saved method indices if needed
                if not node.selected_method_combo and node.method_group_index and node.method_index then
                    for i, method_combo in ipairs(methods) do
                        if i > 1 then  -- Skip the first "Select Method" entry
                            local group_idx, method_idx = method_combo:match("(%d+)%-(%d+)")
                            if group_idx and method_idx and 
                               tonumber(group_idx) == node.method_group_index and 
                               tonumber(method_idx) == node.method_index then
                                node.selected_method_combo = i
                                break
                            end
                        end
                    end
                end
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
        else
            imgui.text("Type not found")
        end
    end
    
    if node.is_initialized then
        imgui.end_disabled()
    end
    
    -- Pre-hook result selection
    if not node.pre_hook_result then
        node.pre_hook_result = "CALL_ORIGINAL"  -- Default
    end
    local pre_hook_options = {"CALL_ORIGINAL", "SKIP_ORIGINAL"}
    local current_option_index = (node.pre_hook_result == "CALL_ORIGINAL") and 1 or 2
    local result_changed, new_option_index = imgui.combo("Pre-hook Result", current_option_index, pre_hook_options)
    if result_changed then
        node.pre_hook_result = pre_hook_options[new_option_index]
        Helpers.mark_as_modified()
    end
    
    imgui.spacing()
    
    -- Auto-reinitialize hooks that were loaded from config as initialized
    if node.is_initialized and not node.hook_id and node.path and node.method_name then
        HookStarter.initialize_hook(node)
    end
    
    if not node.is_initialized then
        if imgui.button("Initialize Hook") then
            HookStarter.initialize_hook(node)
        end
        imgui.spacing()
    else
        local pos = imgui.get_cursor_pos()
        imgui.text_colored("✓ Hook Active", 0xFF00FF00)
        local time_since_call = "Never called"
        if node.last_hook_time then
            local elapsed = os.clock() - node.last_hook_time
            if elapsed < 1 then
                time_since_call = string.format("%.0fms ago", elapsed * 1000)
            else
                time_since_call = string.format("%.1fs ago", elapsed)
            end
        end
        imgui.same_line()
        local pos = Helpers.get_right_cursor_pos(node.node_id, "Last call: " .. time_since_call)
        imgui.set_cursor_pos(pos)
        imgui.text("Last call: " .. time_since_call)
        imgui.spacing()
        imgui.spacing()
        if node.ending_value then
            if not node.output_attr then
                node.output_attr = Helpers.next_pin_id()
            end
            imgui.spacing()
            imnodes.begin_output_attribute(node.output_attr)
            local pos = imgui.get_cursor_pos()
            imgui.text("Managed (this):")
            imgui.same_line()
            -- Display simplified value without address
            local display_value = "Object"
            if type(node.ending_value) == "userdata" then
                local success, type_info = pcall(function() return node.ending_value:get_type_definition() end)
                if success and type_info then
                    display_value = type_info:get_name()
                end
            else
                display_value = tostring(node.ending_value)
            end
            local display = display_value .. " (?)"
            local pos = Helpers.get_right_cursor_pos(node.node_id, display)
            imgui.set_cursor_pos(pos)
            imgui.text(display_value)
            imgui.same_line()
            imgui.text("(?)")
                if imgui.is_item_hovered() then
                    if type(node.ending_value) == "userdata" then
                        local success, type_info = pcall(function() return node.ending_value:get_type_definition() end)
                        if success and type_info then
                            local address = string.format("0x%X", node.ending_value:get_address())
                            local tooltip_text = string.format(
                                "Hooked object instance (this)\nType: %s\nAddress: %s",
                                type_info:get_full_name(), address
                            )
                            imgui.set_tooltip(tooltip_text)
                        else
                            imgui.set_tooltip("Hooked object instance (this)\n(ValueType or native pointer)")
                        end
                    else
                        imgui.set_tooltip("Return value: " .. tostring(node.ending_value))
                    end
                end
            if type(node.ending_value) == "userdata" then
                imgui.spacing()
                local button_pos = Helpers.get_right_cursor_pos(node.node_id, "+ Add Child to Output")
                imgui.set_cursor_pos(button_pos)
                if imgui.button("+ Add Child to Output") then
                    Helpers.add_child_node(node)
                end
            end
            imnodes.end_output_attribute()
            imgui.spacing()
            imgui.spacing()
        end
        
        imgui.spacing()
        imgui.spacing()
        -- Display return value if we have return type info and the hook has been called
        if node.return_type_name and node.last_hook_time then
            -- Return override input
            if not node.return_override_attr then
                node.return_override_attr = Helpers.next_pin_id()
            end
            imnodes.begin_input_attribute(node.return_override_attr)
            local has_return_override_connection = Helpers.is_param_connected_for_return_override(node)
            local return_override_label = "Return Override"
            if has_return_override_connection then
                local connected_value = Helpers.get_connected_return_override_value(node)
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
                imgui.input_text(return_override_label, display_value)
                imgui.end_disabled()
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Return override value (connected)")
                end
            else
                node.return_override_manual = node.return_override_manual or ""
                local input_changed, new_value = imgui.input_text(return_override_label, node.return_override_manual)
                if input_changed then
                    node.return_override_manual = new_value
                    Helpers.mark_as_modified()
                end
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Return override value (manual input)")
                end
            end
            imnodes.end_input_attribute()
            
            if not node.return_attr then
                node.return_attr = Helpers.next_pin_id()
            end
            imgui.spacing()
            local return_type = type(node.return_value)
            local return_type_display = node.return_type_name

            local pos_for_return = imgui.get_cursor_pos()

            local return_pos = imgui.get_cursor_pos()
            imnodes.begin_output_attribute(node.return_attr)
            imgui.text("Return (" .. return_type_display .. "):")
            imgui.same_line()
           
            -- Display simplified value without address
            local display_value = "Object"
            if return_type == "userdata" then
                local success, type_info = pcall(function() return node.return_value:get_type_definition() end)
                if success and type_info then
                    display_value = type_info:get_name()
                end
            else
                display_value = tostring(node.return_value)
            end
            local return_display = display_value .. " (?)"
            local return_pos = Helpers.get_right_cursor_pos(node.node_id, return_display)
            imgui.set_cursor_pos(return_pos)
            imgui.text(display_value)
            imgui.same_line()
            imgui.text("(?)")
            if imgui.is_item_hovered() then
                local tooltip_text
                if node.is_return_overridden then
                    tooltip_text = "Method return value (OVERRIDDEN)"
                    if type(node.return_value) == "userdata" then
                        local success, type_info = pcall(function() return node.return_value:get_type_definition() end)
                        if success and type_info then
                            local address = string.format("0x%X", node.return_value:get_address())
                            tooltip_text = string.format(
                                "Method return value (OVERRIDDEN)\nOverride Type: %s\nOverride Address: %s",
                                type_info:get_full_name(), address
                            )
                        else
                            tooltip_text = string.format(
                                "Method return value (OVERRIDDEN)\nOverride Type: %s\n(ValueType or native pointer)",
                                node.return_type_full_name or node.return_type_name
                            )
                        end
                    else
                        tooltip_text = string.format(
                            "Method return value (OVERRIDDEN)\nOverride Type: %s\nOverride Value: %s",
                            node.return_type_full_name or node.return_type_name, tostring(node.return_value)
                        )
                    end
                    
                    -- Add actual return value info
                    if node.actual_return_value ~= nil then
                        if type(node.actual_return_value) == "userdata" then
                            local success, type_info = pcall(function() return node.actual_return_value:get_type_definition() end)
                            if success and type_info then
                                local actual_address = string.format("0x%X", node.actual_return_value:get_address())
                                tooltip_text = tooltip_text .. string.format(
                                    "\n\nActual return value:\nType: %s\nAddress: %s",
                                    type_info:get_full_name(), actual_address
                                )
                            else
                                tooltip_text = tooltip_text .. string.format(
                                    "\n\nActual return value:\nType: %s\n(ValueType or native pointer)",
                                    node.return_type_full_name or node.return_type_name
                                )
                            end
                        else
                            tooltip_text = tooltip_text .. string.format(
                                "\n\nActual return value:\nType: %s\nValue: %s",
                                node.return_type_full_name or node.return_type_name, tostring(node.actual_return_value)
                            )
                        end
                    end
                else
                    tooltip_text = "Method return value"
                    if type(node.return_value) == "userdata" then
                        local success, type_info = pcall(function() return node.return_value:get_type_definition() end)
                        if success and type_info then
                            local address = string.format("0x%X", node.return_value:get_address())
                            tooltip_text = string.format(
                                "Method return value\nType: %s\nAddress: %s",
                                type_info:get_full_name(), address
                            )
                        else
                            tooltip_text = string.format(
                                "Method return value\nType: %s\n(ValueType or native pointer)",
                                node.return_type_full_name or node.return_type_name
                            )
                        end
                    else
                        tooltip_text = string.format(
                            "Method return value\nType: %s\nValue: %s",
                            node.return_type_full_name or node.return_type_name, tostring(node.return_value)
                        )
                    end
                end
                imgui.set_tooltip(tooltip_text)
            end
            
            if node.return_value ~= nil and type(node.return_value) == "userdata" then
                imgui.spacing()
                local return_button_text = "+ Add Child to Return"
                local return_button_pos = Helpers.get_right_cursor_pos(node.node_id, return_button_text)
                imgui.set_cursor_pos(return_button_pos)
                if imgui.button(return_button_text) then
                    Helpers.add_child_node_to_return(node)
                end
            end
            
            imnodes.end_output_attribute()
        end
        
    end
    imgui.spacing()
    imgui.spacing()
    if imgui.button("- Remove Node") then
        if node.is_initialized and node.hook_id then
            -- Note: REFramework doesn't support removing hooks, so we just remove the node
            -- The hook will remain active until the game restarts
            -- sdk.hook_remove(node.hook_id) -- Not supported
        end
        Helpers.remove_starter_node(node)
    end
    BaseStarter.render_debug_info(node)
    imnodes.end_node()
end

function HookStarter.initialize_hook(node)
    if not node.path or node.path == "" then
        Helpers.show_error("Path is required")
        return
    end
    if not node.method_name or node.method_name == "" then
        Helpers.show_error("Method is required")
        return
    end
    local type_def = sdk.find_type_definition(node.path)
    if not type_def then
        Helpers.show_error("Type not found: " .. node.path)
        return
    end
    local method = nil
    if node.method_group_index and node.method_index then
        method = Helpers.get_method_by_group_and_index(type_def, 
            node.method_group_index, node.method_index)
    else
        method = type_def:get_method(node.method_name)
    end
    if not method then
        Helpers.show_error("Method not found: " .. node.method_name .. " (group:" .. tostring(node.method_group_index) .. ", index:" .. tostring(node.method_index) .. ")")
        return
    end
    node.last_hook_time = nil
    node.return_value = nil  -- Initialize return value
    node.actual_return_value = nil  -- Initialize actual return value
    node.is_return_overridden = false  -- Initialize override flag
    local param_types = {}
    local success_params, method_param_types = pcall(function() return method:get_param_types() end)
    if success_params and method_param_types then
        param_types = method_param_types
        node.param_types = param_types  -- Store for display
    end
    
    -- Get return type for display
    local success_return, return_type = pcall(function() return method:get_return_type() end)
    if success_return and return_type then
        node.return_type_name = return_type:get_name()
        node.return_type_full_name = return_type:get_full_name()
    end
    
    local success, result
    -- Set up both pre and post hooks
    success, result = pcall(function()
        return sdk.hook(method, function(args)
            node.last_hook_time = os.clock()
            local managed = sdk.to_managed_object(args[2])
            if managed then
                node.ending_value = managed
                node.status = "Hook: Pre-hook called"
            else
                node.status = "Hook: Managed object not found"
            end
            -- Return the selected pre-hook result
            return sdk.PreHookResult[node.pre_hook_result]
        end, function(retval)
            -- Convert return value to proper type if possible
            local ret_type = method:get_return_type()
            node.retval_vtypename = node.return_type_name and ret_type:is_value_type() and not ret_type:is_a("System.Enum") and not node.return_type_name:find("System.U?Int") and node.return_type_name
            node.actual_return_value = convert_ptr(retval, node.retval_vtypename)
            node.status = "Hook: Post-hook called"
            
            -- Check for return override
            local override_value = nil
            if Helpers.is_param_connected_for_return_override(node) then
                override_value = Helpers.get_connected_return_override_value(node)
            elseif node.return_override_manual and node.return_override_manual ~= "" then
                override_value = Helpers.parse_value_for_type(node.return_override_manual, ret_type)
            end
            
            if override_value ~= nil then
                node.status = "Hook: Post-hook called (return overridden)"
                node.return_value = convert_ptr(override_value, node.retval_vtypename)
                node.is_return_overridden = true
                return sdk.to_ptr(override_value)
            else
                node.return_value = node.actual_return_value
                node.is_return_overridden = false
                return retval
            end
        end)
    end)
    if success then
        node.hook_id = method  -- Store the method itself since we can't unhook anyway
        node.is_initialized = true
        Helpers.mark_as_modified()
    else
        Helpers.show_error("Failed to initialize hook: " .. tostring(result))
    end
end

return HookStarter