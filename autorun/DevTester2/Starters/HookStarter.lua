-- HookStarter Node Properties:
-- This node represents a method hook that can intercept and modify method calls in the game.
-- The following properties define the state and configuration of a HookStarter node:
--
-- Core Configuration:
-- - path: String - The full type path (e.g., "app.SomeClass") to hook methods on
-- - method_name: String - The name of the specific method being hooked
-- - selected_method_combo: Number - Index for the method selection combo box UI
-- - method_group_index: Number - Group index for organizing overloaded methods
-- - method_index: Number - Index of the method within its overload group
--
-- Hook State:
-- - is_initialized: Boolean - Whether the hook is currently active and installed
-- - hook_id: Method object - Reference to the hooked method (used for identification)
-- - pre_hook_result: String - Either "CALL_ORIGINAL" or "SKIP_ORIGINAL" - determines if original method runs
--
-- Output Pins:
-- - output_attr: Number - Pin ID for the "Managed (this)" output (the object instance)
-- - return_attr: Number - Pin ID for the method return value output
-- - hook_arg_attrs: Array - Pin IDs for method parameter outputs (args[3], args[4], etc.)
--
-- Return Override:
-- - return_override_attr: Number - Pin ID for the return override input pin
-- - return_override_manual: String - Manual text input for return override value
-- - is_return_overridden: Boolean - Whether the return value was overridden on last call
--
-- Runtime Values:
-- - ending_value: Object - The managed object instance from the pre-hook (args[2])
-- - return_value: Any - The final return value (may be overridden)
-- - actual_return_value: Any - The original return value from the method before override
-- - hook_arg_values: Array - Converted values of method parameters (args[3], args[4], etc.)
-- - last_hook_time: Number - Timestamp (os.clock()) of the last hook execution
--
-- Type Information:
-- - param_types: Array - List of parameter type definitions for the hooked method
-- - return_type_name: String - Short name of the return type (e.g., "System.Int32")
-- - return_type_full_name: String - Full qualified name of the return type
-- - retval_vtypename: String - Type name used for value type conversion
--
-- UI/Debug:
-- - status: String - Current status message for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local BaseStarter = require("DevTester2.Starters.BaseStarter")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local HookStarter = {}

local function convert_ptr(arg, td_name)
	local output

	-- First try to convert to managed object
	local success, mobj = pcall(function() return sdk.to_managed_object(arg) end)
	if success and mobj then
		output = mobj:add_ref()
	else
		-- Fallback to basic conversions as per RE Engine documentation
		if td_name == "System.Single" or td_name == "Single" then
			output = sdk.to_float(arg)
		elseif td_name == "System.Double" or td_name == "Double" then
			output = sdk.to_double(arg)
		else
			output = sdk.to_int64(arg) or tostring(arg)
		end
	end

	-- For ValueTypes, try to create proper valuetype objects
	-- This provides better usability than raw field access
	if td_name and not success and tonumber(output) then
		local success_vt, vt = pcall(function() return sdk.to_valuetype(output, td_name) end)
		if success_vt and vt then
			local type_def = sdk.find_type_definition(td_name)
			if type_def and type_def:is_a("System.Enum") then
				-- For enums, return the valuetype directly
				output = vt
			elseif vt.mValue ~= nil then
				-- For other value types, return the underlying value
				output = vt.mValue
			else
				-- Fallback to the valuetype itself
				output = vt
			end
		end
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
    local has_children = Nodes.has_children(node)
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
        State.mark_as_modified()
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
                return Nodes.get_methods_for_combo(type_def) 
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
                local has_children = Nodes.has_children(node)
                if has_children then
                    imgui.begin_disabled()
                end
                local method_changed, new_combo_index = Utils.hybrid_combo("Method", 
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
                                return Nodes.get_method_by_group_and_index(type_def, 
                                    node.method_group_index, node.method_index)
                            end)
                            if success_get and selected_method then
                                node.method_name = selected_method:get_name()
                                -- Get param types and create arg placeholders
                                local success_params, method_param_types = pcall(function() return selected_method:get_param_types() end)
                                if success_params and method_param_types then
                                    node.param_types = method_param_types
                                    -- Create placeholder arg attributes
                                    if not node.hook_arg_attrs then
                                        node.hook_arg_attrs = {}
                                    end
                                    -- Clear existing and recreate for the new method
                                    node.hook_arg_attrs = {}
                                    for i = 1, #method_param_types do
                                        table.insert(node.hook_arg_attrs, State.next_pin_id())
                                    end
                                end
                            else
                                node.method_name = ""
                                node.param_types = nil
                                node.hook_arg_attrs = {}
                            end
                        else
                            node.method_group_index = nil
                            node.method_index = nil
                            node.method_name = ""
                            node.param_types = nil
                            node.hook_arg_attrs = {}
                        end
                    else
                        node.method_group_index = nil
                        node.method_index = nil
                        node.method_name = ""
                    end
                    State.mark_as_modified()
                end
                if has_children then
                    imgui.end_disabled()
                    if imgui.is_item_hovered() then
                        imgui.set_tooltip("Cannot change method while node has children")
                    end
                end
            else
                imgui.text("No methods available")
                node.status = "No methods available"
            end
        else
            imgui.text("Type not found")
            node.status = "Type not found"
        end
    end
    
    -- Create placeholder attributes for hooks that have a method selected
    -- This ensures attributes exist for saving/loading even if hook isn't initialized
    if node.method_name and node.method_name ~= "" then
        if not node.output_attr then
            node.output_attr = State.next_pin_id()
        end
        if not node.return_attr then
            node.return_attr = State.next_pin_id()
        end
        if not node.return_override_attr then
            node.return_override_attr = State.next_pin_id()
        end
        -- Create arg placeholders if param_types exist but hook_arg_attrs don't
        if node.param_types and (not node.hook_arg_attrs or #node.hook_arg_attrs ~= #node.param_types) then
            node.hook_arg_attrs = {}
            for i = 1, #node.param_types do
                table.insert(node.hook_arg_attrs, State.next_pin_id())
            end
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
        State.mark_as_modified()
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
        
        -- Display placeholder attributes if they exist (created during config loading for nodes with children)
        -- This allows follower nodes to reconnect properly when loading from config
        if node.output_attr or node.return_attr or node.return_override_attr then
            if node.output_attr then
                imgui.spacing()
                imnodes.begin_output_attribute(node.output_attr)
                imgui.text("Managed (this): Not initialized")
                imnodes.end_output_attribute()
            end
            
            if node.return_override_attr then
                imgui.spacing()
                imnodes.begin_input_attribute(node.return_override_attr)
                imgui.input_text("Return Override", "Not initialized")
                imnodes.end_input_attribute()
            end
            
            if node.return_attr then
                imgui.spacing()
                imnodes.begin_output_attribute(node.return_attr)
                imgui.text("Return: Not initialized")
                imnodes.end_output_attribute()
            end
            node.status = "Not called yet, placeholder attributes displayed"
        end
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
        local pos = Utils.get_right_cursor_pos(node.node_id, "Last call: " .. time_since_call)
        imgui.set_cursor_pos(pos)
        imgui.text("Last call: " .. time_since_call)
        imgui.spacing()
        imgui.spacing()
        
        -- Show attributes if they exist (either with ending_value or as placeholders)
        if node.output_attr then
            imgui.spacing()
            imnodes.begin_output_attribute(node.output_attr)
            local pos = imgui.get_cursor_pos()
            imgui.text("Managed (this):")
            imgui.same_line()
            if node.ending_value then
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
                local pos = Utils.get_right_cursor_pos(node.node_id, display)
                imgui.set_cursor_pos(pos)
                imgui.text(display_value)
                if imgui.is_item_hovered() then
                    if type(node.ending_value) == "userdata" then
                        local success, type_info = pcall(function() return node.ending_value:get_type_definition() end)
                        if success and type_info then
                            local address = string.format("0x%X", node.ending_value:get_address())
                            local tooltip_text = string.format(
                                "Type: %s\nAddress: %s",
                                type_info:get_full_name(), address
                            )
                            imgui.set_tooltip(tooltip_text)
                        else
                            imgui.set_tooltip("(ValueType or native pointer)")
                        end
                    else
                        imgui.set_tooltip("Return value: " .. tostring(node.ending_value))
                    end
                end
                if type(node.ending_value) == "userdata" then
                    imgui.spacing()
                    local button_pos = Utils.get_right_cursor_pos(node.node_id, "+ Add Child to Output")
                    imgui.set_cursor_pos(button_pos)
                    if imgui.button("+ Add Child to Output") then
                        Nodes.add_child_node(node)
                    end
                end
            else
                -- No ending_value - show as failed/not initialized
                local status_text = node.is_initialized and "Failed to initialize" or "Not initialized"
                local pos = Utils.get_right_cursor_pos(node.node_id, status_text)
                imgui.set_cursor_pos(pos)
                imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
            end
            imnodes.end_output_attribute()
        end
        
        -- Display argument outputs if they exist (either with values or as placeholders)
        if node.hook_arg_attrs and #node.hook_arg_attrs > 0 then
            for i, arg_attr in ipairs(node.hook_arg_attrs) do
                imgui.spacing()
                local param_type = node.param_types and node.param_types[i]
                local param_type_name = param_type and param_type:get_name() or "Unknown"
                local arg_pos = imgui.get_cursor_pos()
                imnodes.begin_output_attribute(arg_attr)
                imgui.text("Arg " .. i .. " (" .. param_type_name .. "):")
                imgui.same_line()
                
                if node.is_initialized then
                    -- Display arg value if available
                    if node.hook_arg_values and node.hook_arg_values[i] ~= nil and node.last_hook_time then
                        -- Display simplified value without address
                        local display_value = "Object"
                        local arg_type = type(node.hook_arg_values[i])
                        if arg_type == "userdata" then
                            local success, type_info = pcall(function() return node.hook_arg_values[i]:get_type_definition() end)
                            if success and type_info then
                                display_value = type_info:get_name()
                            end
                        else
                            display_value = tostring(node.hook_arg_values[i])
                        end
                        local arg_display = display_value .. " (?)"
                        local arg_pos = Utils.get_right_cursor_pos(node.node_id, arg_display)
                        imgui.set_cursor_pos(arg_pos)
                        imgui.text(display_value)
                        imgui.same_line()
                        imgui.text("(?)")
                        if imgui.is_item_hovered() then
                            -- Build tooltip
                            local tooltip_text = string.format("Type: %s", param_type and param_type:get_full_name() or "Unknown")
                            if arg_type == "userdata" then
                                local success, type_info = pcall(function() return node.hook_arg_values[i]:get_type_definition() end)
                                if success and type_info then
                                    local address = string.format("0x%X", node.hook_arg_values[i]:get_address())
                                    tooltip_text = tooltip_text .. string.format("\nValue: %s @ %s", type_info:get_name(), address)
                                else
                                    tooltip_text = tooltip_text .. "\nValue: (ValueType or native pointer)"
                                end
                            else
                                tooltip_text = tooltip_text .. string.format("\nValue: %s", tostring(node.hook_arg_values[i]))
                            end
                            imgui.set_tooltip(tooltip_text)
                        end
                        
                        if node.hook_arg_values[i] ~= nil and type(node.hook_arg_values[i]) == "userdata" then
                            imgui.spacing()
                            local arg_button_text = "+ Add Child to Arg " .. i
                            local arg_button_pos = Utils.get_right_cursor_pos(node.node_id, arg_button_text)
                            imgui.set_cursor_pos(arg_button_pos)
                            if imgui.button(arg_button_text) then
                                Nodes.add_child_node_to_arg(node, i)
                            end
                        end
                    else
                        -- No arg value yet
                        local status_text = "Not called yet"
                        local pos = Utils.get_right_cursor_pos(node.node_id, status_text)
                        imgui.set_cursor_pos(pos)
                        imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
                    end
                else
                    -- Not initialized - show placeholder
                    local status_text = "Not initialized"
                    local pos = Utils.get_right_cursor_pos(node.node_id, status_text)
                    imgui.set_cursor_pos(pos)
                    imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
                end
                imnodes.end_output_attribute()
            end
        end
        
        -- Display return attributes if they exist and hook is initialized
        if node.return_override_attr then
            imgui.spacing()
            imgui.spacing()
            imnodes.begin_input_attribute(node.return_override_attr)
            local has_return_override_connection = Nodes.is_param_connected_for_return_override(node)
            local return_override_label = "Return Override"
            if has_return_override_connection then
                local connected_value = Nodes.get_connected_return_override_value(node)
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
                    State.mark_as_modified()
                end
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Return override value (manual input)")
                end
            end
            imnodes.end_input_attribute()
        end
        
        if node.is_initialized and node.return_attr then
            imgui.spacing()
            local return_type = node.return_type_name or "Unknown"
            local return_pos = imgui.get_cursor_pos()
            imnodes.begin_output_attribute(node.return_attr)
            imgui.text("Return (" .. return_type .. "):")
            imgui.same_line()
           
            -- Display return value if available
            if node.return_value ~= nil and node.last_hook_time then
                -- Display simplified value without address
                local display_value = "Object"
                local return_type = type(node.return_value)
                if return_type == "userdata" then
                    local success, type_info = pcall(function() return node.return_value:get_type_definition() end)
                    if success and type_info then
                        display_value = type_info:get_name()
                    end
                else
                    display_value = tostring(node.return_value)
                end
                local return_display = display_value .. " (?)"
                local return_pos = Utils.get_right_cursor_pos(node.node_id, return_display)
                imgui.set_cursor_pos(return_pos)
                imgui.text(display_value)
                imgui.same_line()
                imgui.text("(?)")
                if imgui.is_item_hovered() then
                    -- Build consistent tooltip format
                    local tooltip_text = string.format("Type: %s", node.return_type_full_name or node.return_type_name)
                    
                    -- Always show the original value if available
                    if node.actual_return_value ~= nil then
                        if type(node.actual_return_value) == "userdata" then
                            local success, type_info = pcall(function() return node.actual_return_value:get_type_definition() end)
                            if success and type_info then
                                local address = string.format("0x%X", node.actual_return_value:get_address())
                                tooltip_text = tooltip_text .. string.format("\nValue: %s @ %s", type_info:get_name(), address)
                            else
                                tooltip_text = tooltip_text .. "\nValue: (ValueType or native pointer)"
                            end
                        else
                            tooltip_text = tooltip_text .. string.format("\nValue: %s", tostring(node.actual_return_value))
                        end
                    else
                        tooltip_text = tooltip_text .. "\nValue: (not yet called)"
                    end
                    
                    -- Show override value only if overridden
                    if node.is_return_overridden then
                        if type(node.return_value) == "userdata" then
                            local success, type_info = pcall(function() return node.return_value:get_type_definition() end)
                            if success and type_info then
                                local address = string.format("0x%X", node.return_value:get_address())
                                tooltip_text = tooltip_text .. string.format("\nOverride Value: %s @ %s", type_info:get_name(), address)
                            else
                                tooltip_text = tooltip_text .. "\nOverride Value: (ValueType or native pointer)"
                            end
                        else
                            tooltip_text = tooltip_text .. string.format("\nOverride Value: %s", tostring(node.return_value))
                        end
                    end
                    
                    imgui.set_tooltip(tooltip_text)
                end
                
                if node.return_value ~= nil and type(node.return_value) == "userdata" then
                    imgui.spacing()
                    local return_button_text = "+ Add Child to Return"
                    local return_button_pos = Utils.get_right_cursor_pos(node.node_id, return_button_text)
                    imgui.set_cursor_pos(return_button_pos)
                    if imgui.button(return_button_text) then
                        Nodes.add_child_node_to_return(node)
                    end
                end
            else
                -- No return value yet
                local status_text = "Not called yet"
                local pos = Utils.get_right_cursor_pos(node.node_id, status_text)
                imgui.set_cursor_pos(pos)
                imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
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
        Nodes.remove_starter_node(node)
    end
    BaseStarter.render_debug_info(node)
    imnodes.end_node()
end

function HookStarter.initialize_hook(node)
    if not node.path or node.path == "" then
        Utils.show_error("Path is required")
        return
    end
    if not node.method_name or node.method_name == "" then
        Utils.show_error("Method is required")
        return
    end
    local type_def = sdk.find_type_definition(node.path)
    if not type_def then
        Utils.show_error("Type not found: " .. node.path)
        return
    end
    local method = nil
    if node.method_group_index and node.method_index then
        method = Nodes.get_method_by_group_and_index(type_def, 
            node.method_group_index, node.method_index)
    else
        method = type_def:get_method(node.method_name)
    end
    if not method then
        Utils.show_error("Method not found: " .. node.method_name .. " (group:" .. tostring(node.method_group_index) .. ", index:" .. tostring(node.method_index) .. ")")
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
    
    -- Create arg output attributes if not already created
    if not node.hook_arg_attrs or #node.hook_arg_attrs ~= #param_types then
        node.hook_arg_attrs = {}
        for i = 1, #param_types do
            table.insert(node.hook_arg_attrs, State.next_pin_id())
        end
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
                -- Store pre-hook info for combined status
                node.pre_hook_info = node.pre_hook_result == "SKIP_ORIGINAL" and "skipping original" or "calling original"
            else
                node.pre_hook_info = "managed object not found"
            end
            
            -- Convert and store method arguments
            node.hook_arg_values = {}
            for i = 1, #param_types do
                local arg = args[i + 2]  -- args[3] is param 1, args[4] is param 2, etc.
                local param_type = param_types[i]
                local type_name = param_type:get_name()
                log.debug("Converting arg " .. i .. " of type " .. type_name)
                node.hook_arg_values[i] = convert_ptr(arg, type_name)
            end
            
            -- Return the selected pre-hook result
            return sdk.PreHookResult[node.pre_hook_result]
        end, function(retval)
            -- Convert return value to proper type if possible
            local ret_type = method:get_return_type()
            node.retval_vtypename = node.return_type_name  -- Pass the full type name for proper conversion
            node.actual_return_value = convert_ptr(retval, node.retval_vtypename)
            
            -- Build comprehensive status string with both pre and post hook info
            local status_parts = {}
            table.insert(status_parts, "Pre: " .. (node.pre_hook_info or "unknown"))
            table.insert(status_parts, "Post: called")
            
            -- Check for return override
            local override_value = nil
            if Nodes.is_param_connected_for_return_override(node) then
                override_value = Nodes.get_connected_return_override_value(node)
            elseif node.return_override_manual and node.return_override_manual ~= "" then
                override_value = Utils.parse_primitive_value(node.return_override_manual)
            end
            
            if override_value ~= nil then
                table.insert(status_parts, "return overridden")
                node.return_value = override_value  -- Use the parsed override value directly
                node.is_return_overridden = true
            else
                table.insert(status_parts, "return unchanged")
                node.return_value = node.actual_return_value
                node.is_return_overridden = false
            end
            
            node.status = "Hook: " .. table.concat(status_parts, ", ")
            
            if override_value ~= nil then
                return sdk.to_ptr(override_value)
            else
                return retval
            end
        end)
    end)
    if success then
        node.hook_id = method  -- Store the method itself since we can't unhook anyway
        node.is_initialized = true
        State.mark_as_modified()
    else
        Utils.show_error("Failed to initialize hook: " .. tostring(result))
    end
end

return HookStarter
