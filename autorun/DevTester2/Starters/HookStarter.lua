-- HookStarter Node Properties:
-- This node represents a method hook that can intercept and modify method calls in the game.
--
-- Configuration:
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
-- Pins:
-- - pins.inputs[1]: "return_override" - Optional return override input (only for non-void methods)
-- - pins.outputs[1]: "was_called" - Boolean signal indicating hook was called (PRE or POST mode)
-- - pins.outputs[2]: "main_output" - The object instance (this)
-- - pins.outputs[3]: "return_output" - The method return value (only if not void)
-- - pins.outputs[3+ or 4+]: "arg_N" - Dynamic argument outputs (starts at 3 for void, 4 for non-void)
--
-- Return Override:
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

-- Render the managed object output attribute
local function render_managed_output(node, is_placeholder)
    -- Get main output pin (always index 2)
    if #node.pins.outputs < 2 then return end
    local main_output_pin = node.pins.outputs[2]
    
    -- Hide when initialized (reduce visual noise, but pin still exists for connections)
    if not node.is_initialized then return end
    
    imgui.spacing()
    imnodes.begin_output_attribute(main_output_pin.id)
    imgui.text("Managed (this):")
    imgui.same_line()
    
    if is_placeholder then
        local status_text = "Not hooked yet"
        local pos = Utils.get_right_cursor_pos(node.id, status_text)
        imgui.set_cursor_pos(pos)
        imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
    elseif node.ending_value then
        -- Display simplified value without address
        local display_value = Utils.get_value_display_string(node.ending_value)
        local display = display_value .. " (?)"
        local pos = Utils.get_right_cursor_pos(node.id, display)
        imgui.set_cursor_pos(pos)
        imgui.text(display_value)
        imgui.same_line()
        imgui.text("(?)")
        if imgui.is_item_hovered() then
            imgui.set_tooltip(Utils.get_tooltip_for_value(node.ending_value))
        end
        
        local can_continue, _ = Nodes.validate_continuation(node.ending_value, nil)
        if can_continue then
            local button_pos = Utils.get_right_cursor_pos(node.id, "+ Add Child to Output")
            imgui.set_cursor_pos(button_pos)
            if imgui.button("+ Add Child to Output") then
                Nodes.add_child_node_to_return(node, 2)
            end
            imgui.spacing()
        end
    else
        -- No ending_value - show as failed/not initialized
        local status_text = node.is_initialized and "Failed to initialize" or "Not initialized"
        local pos = Utils.get_right_cursor_pos(node.id, status_text)
        imgui.set_cursor_pos(pos)
        imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
    end
    
    imnodes.end_output_attribute()
end

-- Render all argument output attributes
local function render_argument_outputs(node, is_placeholder)
    -- Get arg output pins (start at index 4, after was_called, main_output and return_output)
    local arg_pin_start_index = 4
    if node.return_type_name == "Void" then
        arg_pin_start_index = 3
    end
    local num_arg_pins = #node.pins.outputs - (arg_pin_start_index - 1)
    
    if num_arg_pins <= 0 then return end
    
    for i = 1, num_arg_pins do
        local current_pin_index = arg_pin_start_index + i - 1
        local arg_pin = node.pins.outputs[current_pin_index]
        imgui.spacing()
        local param_type = node.param_types and node.param_types[i]
        local param_type_name = param_type and param_type:get_name() or "Unknown"
        local param_full_name = param_type and param_type:get_full_name() or "Unknown"
        
        -- If param_type is unknown but we have a userdata value, try to extract type from the value
        local arg_value = node.hook_arg_values and node.hook_arg_values[i]
        if not param_type and arg_value ~= nil and type(arg_value) == "userdata" then
            local success_type, value_type_def = pcall(function() 
                return arg_value:get_type_definition() 
            end)
            if success_type and value_type_def then
                param_type_name = value_type_def:get_name()
                param_full_name = value_type_def:get_full_name()
            end
        end
        
        -- Determine label: "Param" if it matches param_types, "Arg" if beyond param_types
        local is_param = param_type ~= nil
        local arg_label = is_param and "Param " .. i or "Arg " .. i
        if not is_param and i == (#node.param_types or 0) + 1 then
            imgui.spacing()
            imgui.spacing()
            imgui.spacing()
        end
        
        Nodes.add_context_menu_option(node, "Copy param type " .. i , param_full_name)
        
        imnodes.begin_output_attribute(arg_pin.id)
        
        imgui.text(arg_label .. " (" .. param_type_name .. "):")
        imgui.same_line()
        
        if is_placeholder then
            local status_text = "Not initialized"
            local pos = Utils.get_right_cursor_pos(node.id, status_text)
            imgui.set_cursor_pos(pos)
            imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
        elseif node.is_initialized then
            -- Display arg value if available
            if node.hook_arg_values and node.hook_arg_values[i] ~= nil and node.last_hook_time then
                -- Display simplified value without address
                local display_value = Utils.get_value_display_string(node.hook_arg_values[i])
                local arg_display = display_value .. " (?)"
                local arg_pos = Utils.get_right_cursor_pos(node.id, arg_display)
                imgui.set_cursor_pos(arg_pos)
                imgui.text(display_value)
                imgui.same_line()
                imgui.text("(?)")
                if imgui.is_item_hovered() then
                    -- Build tooltip - use the dynamically extracted type if available
                    local tooltip_text = string.format("Param Type: %s\n%s", 
                        param_full_name,
                        Utils.get_tooltip_for_value(node.hook_arg_values[i])
                    )
                    imgui.set_tooltip(tooltip_text)
                end
                
                local can_continue, _ = Nodes.validate_continuation(node.hook_arg_values[i], nil)
                if can_continue then
                    local arg_button_text = "+ Add Child to " .. arg_label
                    local arg_button_pos = Utils.get_right_cursor_pos(node.id, arg_button_text)
                    imgui.set_cursor_pos(arg_button_pos)
                    if imgui.button(arg_button_text) then
                        Nodes.add_child_node_to_arg(node, current_pin_index)
                    end
                end
            else
                -- No arg value yet
                local status_text = "Not called yet"
                local pos = Utils.get_right_cursor_pos(node.id, status_text)
                imgui.set_cursor_pos(pos)
                imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
            end
        else
            -- Not initialized - show placeholder
            local status_text = "Not initialized"
            local pos = Utils.get_right_cursor_pos(node.id, status_text)
            imgui.set_cursor_pos(pos)
            imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
        end
        
        imnodes.end_output_attribute()
    end
end

-- Render return information (handles void vs non-void)
local function render_return_info(node, is_placeholder)
    -- Display return override input if it exists (only for non-void methods and initialized)
    local return_override_pin = #node.pins.inputs > 0 and node.pins.inputs[1] or nil
    if return_override_pin and (not node.return_type_name or node.return_type_name ~= "Void") and node.is_initialized then
        for _=1,5 do imgui.spacing() end
        imnodes.begin_input_attribute(return_override_pin.id)
        local has_return_override_connection = return_override_pin.connection ~= nil
        local return_override_label = "Return Override"
        if has_return_override_connection then
            local connected_value = Nodes.get_input_pin_value(node, 1)
            -- Display simplified value without address
            local display_value = Utils.get_value_display_string(connected_value)
            imgui.begin_disabled()
            imgui.input_text(return_override_label, display_value)
            imgui.end_disabled()
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Return override value (connected)\n" .. Utils.get_tooltip_for_value(connected_value))
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
    
    -- Display return type info
    -- Get return output pin (always index 3 if exists)
    local return_output_pin = #node.pins.outputs >= 3 and node.pins.outputs[3] or nil
    
    if is_placeholder then
        -- Show return info for placeholder state
        if return_output_pin and (not node.return_type_name or node.return_type_name ~= "Void") then
            imgui.spacing()
            imnodes.begin_output_attribute(return_output_pin.id)
            imgui.text("Return: (nil)")
            imgui.same_line()
            local status_text = "Not hooked yet"
            local pos = Utils.get_right_cursor_pos(node.id, status_text)
            imgui.set_cursor_pos(pos)
            imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
            imnodes.end_output_attribute()
        elseif node.return_type_name == "Void" then
            imgui.spacing()
            imgui.text("Return (void)")
        end
    else
        -- Show return info for active state
        if node.return_type_name == "Void" then
            imgui.spacing()
            imgui.text("Return (void)")
        elseif node.is_initialized and return_output_pin and (not node.return_type_name or node.return_type_name ~= "Void") then
            imgui.spacing()
            local return_type = node.return_type_name or "Unknown"
            local return_pos = imgui.get_cursor_pos()
            imnodes.begin_output_attribute(return_output_pin.id)
            imgui.text("Return (" .. return_type .. "):")
            Nodes.add_context_menu_option(node, "Copy return type", node.return_type_full_name)
            imgui.same_line()
           
            -- Display return value if available
            if node.return_value ~= nil and node.last_hook_time then
                imgui.spacing()
                -- Display simplified value without address
                local display_value = Utils.get_value_display_string(node.return_value)
                local return_display = display_value .. " (?)"
                local return_pos = Utils.get_right_cursor_pos(node.id, return_display)
                imgui.set_cursor_pos(return_pos)
                imgui.text(display_value)
                imgui.same_line()
                imgui.text("(?)")
                if imgui.is_item_hovered() then
                    imgui.set_tooltip(Utils.get_tooltip_for_value(node.return_value))
                end
                
                local can_continue, _ = Nodes.validate_continuation(node.return_value, nil)
                if can_continue then
                    local button_pos = Utils.get_right_cursor_pos(node.id, "+ Add Child to Return")
                    imgui.set_cursor_pos(button_pos)
                    if imgui.button("+ Add Child to Return") then
                        Nodes.add_child_node_to_return(node, 3)
                    end
                end
            else
                -- No return value yet
                local status_text = "Not called yet"
                local pos = Utils.get_right_cursor_pos(node.id, status_text)
                imgui.set_cursor_pos(pos)
                imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
            end
            imnodes.end_output_attribute()
        end
    end
end

local function render_was_called_output(node, is_placeholder)
    -- Get "Was Called" pin (always the first one)
    if #node.pins.outputs < 1 then return end
    
    local pin = node.pins.outputs[1]
    
    imgui.spacing()
    if node.is_initialized then
        imnodes.begin_output_attribute(pin.id)
    
        -- Ensure mode is set
        if not node.was_called_mode then node.was_called_mode = "PRE" end
        
        -- Update pin value based on dirty flags
        local was_called = false
        if node.was_called_mode == "PRE" then
            was_called = node.was_called_pre_dirty or false
            node.was_called_pre_dirty = false -- Reset
        else
            was_called = node.was_called_post_dirty or false
            node.was_called_post_dirty = false -- Reset
        end
        
        -- Set pin value
        pin.value = was_called
        
        -- Toggle button
        if imgui.button("Was Called (" .. node.was_called_mode .. ")") then
            if node.was_called_mode == "PRE" then
                node.was_called_mode = "POST"
            else
                node.was_called_mode = "PRE"
            end
            State.mark_as_modified()
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Click to toggle between Pre/Post for the Was Called pin")
        end
        
        -- Visual indicator
        imgui.same_line()
        local status_text = was_called and "TRUE" or "FALSE"
        local pos = Utils.get_right_cursor_pos(node.id, status_text)
        imgui.set_cursor_pos(pos)
        
        if was_called then
            imgui.text_colored("TRUE", Constants.COLOR_TEXT_SUCCESS)
        else
            imgui.text_colored("FALSE", Constants.COLOR_TEXT_DARK_GRAY)
        end
        
        imnodes.end_output_attribute()
    end
end

local function convert_ptr(arg, td_name)
	-- 1. Try to convert to managed object first
	local success, mobj = pcall(function() return sdk.to_managed_object(arg) end)

	local output
	-- 2. Fallback to basic conversions
	if td_name == "System.Single" or td_name == "Single" then
		output = sdk.to_float(arg)
	elseif td_name == "System.Double" or td_name == "Double" then
		output = sdk.to_double(arg)
	elseif td_name == "System.Boolean" or td_name == "Boolean" then
		output = (sdk.to_int64(arg) & 1) == 1
	elseif td_name == "System.Byte" or td_name == "Byte" then
		output = sdk.to_int64(arg) & 0xFF
	elseif td_name == "System.SByte" or td_name == "SByte" then
		local val = sdk.to_int64(arg) & 0xFF
		if val > 127 then val = val - 256 end
		output = val
	elseif td_name == "System.Int16" or td_name == "Int16" then
		local val = sdk.to_int64(arg) & 0xFFFF
		if val > 32767 then val = val - 65536 end
		output = val
	elseif td_name == "System.UInt16" or td_name == "UInt16" then
		output = sdk.to_int64(arg) & 0xFFFF
	elseif td_name == "System.Int32" or td_name == "Int32" then
		local val = sdk.to_int64(arg) & 0xFFFFFFFF
		if val > 2147483647 then val = val - 4294967296 end
		output = val
	elseif td_name == "System.UInt32" or td_name == "UInt32" then
		output = sdk.to_int64(arg) & 0xFFFFFFFF
	elseif td_name == "System.Char" or td_name == "Char" then
		output = sdk.to_int64(arg) & 0xFFFF
	else
		output = sdk.to_int64(arg) or tostring(arg)
	end

	-- 3. For ValueTypes, try to create proper valuetype objects
	-- This provides better usability than raw field access
	if td_name and tonumber(output) then
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
    -- Ensure output pins exist
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "was_called", nil)
    end
    if #node.pins.outputs == 1 then
        Nodes.add_output_pin(node, "main_output", nil)
    end
    
    local main_output_pin = node.pins.outputs[2]
    
    -- Always sync main output pin value with ending_value on every render
    main_output_pin.value = node.ending_value

    imnodes.begin_node(node.id)

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
            -- Resolve signature if present
            if node.selected_method_signature then
                local group, idx = Nodes.find_method_indices_by_signature(type_def, node.selected_method_signature, false)
                if group and idx then
                    node.method_group_index = group
                    node.method_index = idx
                    -- Update combo index
                    local combo_idx = Nodes.get_combo_index_for_method(type_def, group, idx, false)
                    if combo_idx > 0 then
                        node.selected_method_combo = combo_idx + 1
                    end
                    node.selected_method_signature = nil
                end
            end

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

                    -- Remove all output pins except the first two (was_called and main_output)
                    while #node.pins.outputs > 2 do
                        local pin = node.pins.outputs[3]
                        Nodes.remove_links_for_pin(pin.id)
                        table.remove(node.pins.outputs, 3)
                    end

                    -- Remove return override input pin if it exists
                    while #node.pins.inputs > 0 do
                        local pin = node.pins.inputs[1]
                        Nodes.remove_links_for_pin(pin.id)
                        table.remove(node.pins.inputs, 1)
                    end

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
                                -- Update signature for persistence
                                node.selected_method_signature = Nodes.get_method_signature(selected_method)
                                
                                -- Get param types to create arg output pins
                                local success_params, method_param_types = pcall(function() return selected_method:get_param_types() end)
                                if success_params and method_param_types then
                                    node.param_types = method_param_types
                                end
                                
                                -- Get return type
                                local success_return, return_type = pcall(function() return selected_method:get_return_type() end)
                                if success_return and return_type then
                                    node.return_type_name = return_type:get_name()
                                    node.return_type_full_name = return_type:get_full_name()
                                end
                            else
                                node.method_name = ""
                                node.param_types = nil
                                node.selected_method_signature = nil
                            end
                        else
                            node.method_group_index = nil
                            node.method_index = nil
                            node.method_name = ""
                            node.selected_method_signature = nil
                            node.param_types = nil
                        end
                    else
                        node.method_group_index = nil
                        node.method_index = nil
                        node.method_name = ""
                        node.param_types = nil
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

    if node.is_initialized then
        Nodes.add_context_menu_option(node, "Copy path", node.path)
    end
    
    -- Ensure pins exist based on method configuration
    if node.method_name and node.method_name ~= "" then
        
        local method = sdk.find_type_definition(node.path):get_method(node.method_name)
        Nodes.add_context_menu_option(node, "Copy method name", Nodes.get_method_signature(method, true))

        -- Calculate required pins: was_called, main_output, return_output (if non-void), arg outputs
        local required_outputs = 2  -- was_called and main_output always exist
        if node.return_type_name and node.return_type_name ~= "Void" then
            required_outputs = required_outputs + 1  -- return_output
        end
        
        local num_args = 0
        if node.hook_arg_values and #node.hook_arg_values > 0 then
             num_args = #node.hook_arg_values
        elseif node.param_types then
             num_args = #node.param_types
        end
        required_outputs = required_outputs + num_args
        
        -- Create output pins if needed
        while #node.pins.outputs < required_outputs do
            local pin_index = #node.pins.outputs + 1
            if pin_index == 1 then
                Nodes.add_output_pin(node, "was_called", nil)
            elseif pin_index == 2 then
                Nodes.add_output_pin(node, "main_output", nil)
            elseif pin_index == 3 and node.return_type_name and node.return_type_name ~= "Void" then
                Nodes.add_output_pin(node, "return_output", nil)
            else
                -- Arg output pins
                local arg_num = pin_index - 3
                if node.return_type_name == "Void" then
                    arg_num = pin_index - 2
                end
                Nodes.add_output_pin(node, "arg_" .. (arg_num - 1), nil)
            end
        end
        
        -- Ensure return override input pin exists for non-void methods
        if node.return_type_name and node.return_type_name ~= "Void" then
            if #node.pins.inputs == 0 then
                Nodes.add_input_pin(node, "return_override", nil)
            end
        else
            -- Void method - remove return override input if exists
            while #node.pins.inputs > 0 do
                local pin = node.pins.inputs[1]
                Nodes.remove_links_for_pin(pin.id)
                table.remove(node.pins.inputs, 1)
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
        local not_ready = false
        if not node.path or node.path == "" or
           not node.method_name or node.method_name == "" then
            not_ready = true
        end
        if not_ready then
            imgui.begin_disabled()
        end
        if imgui.button("Initialize Hook") then
            HookStarter.initialize_hook(node)
        end
        if not_ready then
            imgui.end_disabled()
            if imgui.is_item_hovered(1024) then
                imgui.set_tooltip("Path and Method must be set before initializing hook")
            end
        end
        imgui.spacing()
        
    -- Display placeholder attributes if they exist (created during config loading for nodes with children)
    -- This allows follower nodes to reconnect properly when loading from config
    if #node.pins.outputs > 0 then
        render_was_called_output(node, true)
        render_managed_output(node, true)
        render_argument_outputs(node, true)
        render_return_info(node, true)
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
        local pos = Utils.get_right_cursor_pos(node.id, "Last call: " .. time_since_call)
        imgui.set_cursor_pos(pos)
        imgui.text("Last call: " .. time_since_call)
        imgui.spacing()
        
        render_was_called_output(node, false)
        
        imgui.spacing()
        imgui.spacing()
        
        -- Show attributes with actual values
        render_managed_output(node, false)
        
        render_argument_outputs(node, false)
        render_return_info(node, false)
        
    end
    imgui.spacing()
    imgui.spacing()
    if imgui.button("- Remove Node") then
        if node.is_initialized and node.hook_id then
            -- Hook will be automatically disabled since node no longer exists in State.node_map
            -- The hook functions check State.node_map[node.id] and return default behavior if node is removed
        end
        Nodes.remove_node(node)
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
    
    -- Initialize dirty flags for "Was Called" pin
    node.was_called_pre_dirty = false
    node.was_called_post_dirty = false
    
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
            -- Check if node still exists - if removed, call original method
            if not State.node_map[node.id] then
                return sdk.PreHookResult.CALL_ORIGINAL
            end
            
            node.last_hook_time = os.clock()
            node.was_called_pre_dirty = true
            
            -- Determine argument offset and 'this' value
            local arg_offset = node.is_static and 2 or 3
            local managed = nil
            
            if not node.is_static then
                managed = sdk.to_managed_object(args[2])
            end
            
            if managed or node.is_static then
                node.ending_value = managed
                -- Update main output pin (index 2)
                if #node.pins.outputs >= 2 then
                    node.pins.outputs[2].value = managed
                end
                -- Store pre-hook info for combined status
                node.pre_hook_info = node.pre_hook_result == "SKIP_ORIGINAL" and "skipping original" or "calling original"
            else
                node.pre_hook_info = "managed object not found"
            end
            
            -- Convert and store method arguments
            node.hook_arg_values = {}
            local arg_count = #args - arg_offset + 1
            for i = 1, arg_count do
                local arg = args[i + arg_offset - 1]
                local type_name = "System.Object"
                if param_types and param_types[i] then
                    type_name = param_types[i]:get_full_name()
                end
                
                node.hook_arg_values[i] = convert_ptr(arg, type_name)
                
                -- Fix value if needed
                local _, fixed_val = Nodes.validate_continuation(node.hook_arg_values[i], nil, type_name)
                if fixed_val ~= nil then
                    node.hook_arg_values[i] = fixed_val
                end
                
                -- Update arg output pin
                local arg_pin_index = 3 + i  -- After was_called, main_output and return_output
                if node.return_type_name == "Void" then
                    arg_pin_index = 2 + i  -- No return_output for void
                end
                if #node.pins.outputs >= arg_pin_index then
                    node.pins.outputs[arg_pin_index].value = node.hook_arg_values[i]
                end
            end
            
            -- Return the selected pre-hook result
            return sdk.PreHookResult[node.pre_hook_result]
        end, function(retval)
            -- Check if node still exists - if removed, don't override return value
            if not State.node_map[node.id] then
                return retval  -- Return original value unchanged
            end
            node.was_called_post_dirty = true
            
            
            -- Convert return value to proper type if possible
            local ret_type = method:get_return_type()
            node.retval_vtypename = node.return_type_full_name  -- Pass the full type name for proper conversion
            node.actual_return_value = convert_ptr(retval, node.retval_vtypename)
            
            -- Fix value if needed
            local _, fixed_val = Nodes.validate_continuation(node.actual_return_value, nil, node.retval_vtypename)
            if fixed_val ~= nil then
                node.actual_return_value = fixed_val
            end
            
            -- Build comprehensive status string with both pre and post hook info
            local status_parts = {}
            table.insert(status_parts, "Pre: " .. (node.pre_hook_info or "unknown"))
            table.insert(status_parts, "Post: called")
            
            -- Check for return override using pin system
            local override_value = nil
            if #node.pins.inputs > 0 then
                local return_override_pin = node.pins.inputs[1]
                if return_override_pin.connection then
                    override_value = Nodes.get_input_pin_value(node, 1)
                elseif node.return_override_manual and node.return_override_manual ~= "" then
                    override_value = Utils.parse_primitive_value(node.return_override_manual)
                end
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
            
            -- Update return output pin (index 3, if exists and non-void)
            if node.return_type_name and node.return_type_name ~= "Void" and #node.pins.outputs >= 3 then
                node.pins.outputs[3].value = node.return_value
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
