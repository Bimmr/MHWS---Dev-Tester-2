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
-- - exact_type_match: Boolean - When enabled, hook only fires for exact type matches (filters out derived types)
--
-- Pins:
-- - pins.inputs[1]: "return_override" - Optional return override input (only for non-void methods)
-- - pins.outputs[1]: "was_called" - Boolean signal that pulses true for one frame when PRE hook fires
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
-- - last_hook_time: Table - Timestamp of last hook execution {wall_time = os.time(), clock_time = os.clock()}
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

-- ========================================
-- History Snapshot Functions
-- ========================================

-- Add a complete call snapshot to history (circular buffer)
local function add_to_history(node, snapshot)
    if not node.history_enabled then return end
    if node.history_paused then return end  -- Don't record when paused
    if not node.history then
        node.history = {}
    end
    
    -- Write to circular buffer
    node.history[node.history_write_index] = snapshot
    
    -- Move write index forward (circular)
    node.history_write_index = (node.history_write_index % node.history_buffer_size) + 1
    
    -- Increment count up to buffer_size
    if node.history_count < node.history_buffer_size then
        node.history_count = node.history_count + 1
    end
    
    -- Update current_index to point to newest entry when not paused
    if not node.history_paused then
        node.history_current_index = node.history_count
    end
end

-- Get a history snapshot by index (1 = oldest, history_count = newest)
local function get_history_snapshot(node, index)
    if not node.history or node.history_count == 0 then
        return nil
    end
    
    -- Clamp index
    index = math.max(1, math.min(index, node.history_count))
    
    -- Calculate actual position in circular buffer
    local actual_index
    if node.history_count < node.history_buffer_size then
        actual_index = index
    else
        -- Buffer is full - calculate offset from oldest entry
        actual_index = ((node.history_write_index - 1 + index - 1) % node.history_buffer_size) + 1
    end
    
    return node.history[actual_index]
end

-- Clear history buffer
local function clear_history(node)
    node.history = {}
    node.history_count = 0
    node.history_write_index = 1
    node.history_current_index = 1
end

-- Get the current display values (either live or from history snapshot)
local function get_display_values(node)
    if node.history_enabled and node.history_paused and node.history_count > 0 then
        -- Return historical snapshot values
        local snapshot = get_history_snapshot(node, node.history_current_index)
        if snapshot then
            return {
                ending_value = snapshot.ending_value,
                return_value = snapshot.return_value,
                hook_arg_values = snapshot.hook_arg_values,
                timestamp = snapshot.timestamp,
                is_historical = true,
                snapshot_index = node.history_current_index,
                total_snapshots = node.history_count
            }
        end
    end
    
    -- Return live values
    return {
        ending_value = node.ending_value,
        return_value = node.return_value,
        hook_arg_values = node.hook_arg_values,
        timestamp = node.last_hook_time,
        is_historical = false
    }
end

-- Update pin values based on current display values (live or historical)
local function update_pin_values(node)
    local display = get_display_values(node)
    
    -- Update main output pin (index 2 - "this")
    if #node.pins.outputs >= 2 then
        node.pins.outputs[2].value = display.ending_value
    end
    
    -- Update return output pin (index 3 if non-void)
    if node.return_type_name and node.return_type_name ~= "Void" and #node.pins.outputs >= 3 then
        node.pins.outputs[3].value = display.return_value
    end
    
    -- Update arg output pins
    local arg_pin_start_index = 4
    if node.return_type_name == "Void" then
        arg_pin_start_index = 3
    end
    
    if display.hook_arg_values then
        for i, arg_value in ipairs(display.hook_arg_values) do
            local arg_pin_index = arg_pin_start_index + i - 1
            if #node.pins.outputs >= arg_pin_index then
                node.pins.outputs[arg_pin_index].value = arg_value
            end
        end
    end
end

-- Render history navigation UI
local function render_history_navigation(node)
    if not node.history_enabled then return end
    
    imgui.spacing()
    imgui.indent(5)
    
    -- History header with pause/resume toggle
    local pause_label = node.history_paused and " ▶ Resume" or "⏸ Pause"
    if imgui.button(pause_label .. "##history") then
        node.history_paused = not node.history_paused
        if not node.history_paused then
            -- When resuming, jump to newest
            node.history_current_index = node.history_count
        end
        update_pin_values(node)  -- Update pins when pause state changes
        State.mark_as_modified()
    end
    
    imgui.same_line()
    imgui.text(string.format("History: %d/%d", node.history_count, node.history_buffer_size))
    
    -- Clear button
    imgui.same_line()
    if imgui.button("Clear##history") then
        clear_history(node)
        State.mark_as_modified()
    end
    
    -- Navigation controls (only when paused and has history)
    if node.history_paused and node.history_count > 0 then
        imgui.spacing()
        
        -- Build dropdown options
        local dropdown_options = {}
        for i = 1, node.history_count do
            local snapshot = get_history_snapshot(node, i)
            if snapshot then
                local wall_time = snapshot.timestamp and snapshot.timestamp.wall_time or os.time()
                local clock_time = snapshot.timestamp and snapshot.timestamp.clock_time
                local milliseconds = clock_time and math.floor((clock_time - math.floor(clock_time)) * 1000) or 0
                local time_str = os.date("%H:%M:%S", wall_time) .. string.format(".%03d", milliseconds)
                local value_preview = Utils.get_value_display_string(snapshot.ending_value)
                table.insert(dropdown_options, string.format("%d. %s: %s", i, time_str, value_preview))
            else
                table.insert(dropdown_options, string.format("%d. <error>", i))
            end
        end
        
        -- Left arrow (older)
        local can_go_prev = node.history_current_index > 1
        if not can_go_prev then imgui.begin_disabled() end
        if imgui.arrow_button("history_left", 0) then
            node.history_current_index = node.history_current_index - 1
            update_pin_values(node)  -- Update pins when navigating
            State.mark_as_modified()
        end
        if not can_go_prev then imgui.end_disabled() end
        
        imgui.same_line()
        
        -- Dropdown for direct selection
        imgui.set_next_item_width(imgui.calc_item_width() - 50)
        local changed, new_index = imgui.combo("##history_nav", node.history_current_index, dropdown_options)
        if changed then
            node.history_current_index = new_index
            update_pin_values(node)  -- Update pins when navigating
            State.mark_as_modified()
        end
        
        imgui.same_line()
        
        -- Right arrow (newer)
        local can_go_next = node.history_current_index < node.history_count
        if not can_go_next then imgui.begin_disabled() end
        if imgui.arrow_button("history_right", 1) then
            node.history_current_index = node.history_current_index + 1
            update_pin_values(node)  -- Update pins when navigating
            State.mark_as_modified()
        end
        if not can_go_next then imgui.end_disabled() end
        
        -- Show viewing indicator
        imgui.text_colored(string.format("Viewing snapshot %d of %d", node.history_current_index, node.history_count), Constants.COLOR_TEXT_WARNING)
    end
    imgui.unindent(5)
end

-- Initialize hook-specific properties
local function ensure_initialized(node)
    node.path = node.path or ""
    node.method_name = node.method_name or ""
    node.selected_method_combo = node.selected_method_combo or nil
    node.method_group_index = node.method_group_index or nil
    node.method_index = node.method_index or nil
    node.is_initialized = node.is_initialized or false
    node.hook_id = node.hook_id or nil
    node.pre_hook_result = node.pre_hook_result or "CALL_ORIGINAL"
    node.exact_type_match = node.exact_type_match or false
    node.return_override_manual = node.return_override_manual or ""
    node.is_return_overridden = node.is_return_overridden or false
    node.hook_arg_values = node.hook_arg_values or {}
    node.last_hook_time = node.last_hook_time or {}
    node.hook_call_sequence = node.hook_call_sequence or 0
    node.hook_call_queue = node.hook_call_queue or {}
    node.param_types = node.param_types or nil
    node.return_type_name = node.return_type_name or nil
    node.return_type_full_name = node.return_type_full_name or nil
    node.retval_vtypename = node.retval_vtypename or nil
    
    -- History snapshot properties
    node.history_enabled = node.history_enabled or false
    node.history_buffer_size = node.history_buffer_size or 25
    node.history_paused = node.history_paused or false
    node.history_current_index = node.history_current_index or 1
    node.history = node.history or {}  -- Array of snapshots
    node.history_count = node.history_count or 0
    node.history_write_index = node.history_write_index or 1
end

-- Render the managed object output attribute
local function render_managed_output(node, is_placeholder)
    -- Get main output pin (always index 2)
    if #node.pins.outputs < 2 then return end
    local main_output_pin = node.pins.outputs[2]
    
    -- Hide when initialized (reduce visual noise, but pin still exists for connections)
    if not node.is_initialized then return end
    
    -- Get display values (live or historical)
    local display = get_display_values(node)
    
    imgui.spacing()
    imnodes.begin_output_attribute(main_output_pin.id)
    imgui.text("Managed (this):")
    imgui.same_line()
    
    if is_placeholder then
        local status_text = "Not hooked yet"
        local pos = Utils.get_right_cursor_pos(node.id, status_text)
        imgui.set_cursor_pos(pos)
        imgui.text_colored(status_text, Constants.COLOR_TEXT_WARNING)
    elseif display.ending_value then
        -- Display type info
        local type_info = Utils.get_type_info_for_display(display.ending_value, node.path)
        local display_text = type_info.display .. " (?)"
        local pos = Utils.get_right_cursor_pos(node.id, display_text)
        imgui.set_cursor_pos(pos)
        imgui.text(type_info.display)
        imgui.same_line()
        imgui.text("(?)")
        if imgui.is_item_hovered() then
            imgui.set_tooltip(type_info.tooltip)
        end
        
        local can_continue, _ = Nodes.validate_continuation(display.ending_value, nil)
        if can_continue then
            local button_pos = Utils.get_right_cursor_pos(node.id, "+ Add Child to Output", 25)
            imgui.set_cursor_pos(button_pos)
            if imgui.button("+ Add Child to Output") then
                Nodes.add_child_node_to_return(node, 2)
            end
            imgui.spacing()
        end
    else
        -- No ending_value - show as failed/not initialized or static
        local status_text
        if node.is_initialized and node.is_static then
            status_text = "Static (No Instance)"
        elseif node.is_initialized then
            status_text = "Failed to initialize"
        else
            status_text = "Not initialized"
        end
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
    
    -- Get display values (live or historical)
    local display = get_display_values(node)
    
    for i = 1, num_arg_pins do
        local current_pin_index = arg_pin_start_index + i - 1
        local arg_pin = node.pins.outputs[current_pin_index]
        imgui.spacing()
        local param_type = node.param_types and node.param_types[i]
        local param_type_name = param_type and param_type:get_name() or "Unknown"
        local param_full_name = param_type and param_type:get_full_name() or "Unknown"
        
        -- Get arg value from display values (live or historical)
        local arg_value = display.hook_arg_values and display.hook_arg_values[i]
        if not param_type and arg_value ~= nil and type(arg_value) == "userdata" then
            local success_type, value_type_def = pcall(function() 
                return arg_value:get_type_definition() 
            end)
            if success_type and value_type_def then
                local success_name, name = pcall(function() return value_type_def:get_name() end)
                local success_full_name, full_name = pcall(function() return value_type_def:get_full_name() end)
                if success_name and name then
                    param_type_name = name
                end
                if success_full_name and full_name then
                    param_full_name = full_name
                end
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
            if arg_value ~= nil and node.last_hook_time then
                -- Display simplified value without address
                local display_value = Utils.get_value_display_string(arg_value)
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
                        Utils.get_tooltip_for_value(arg_value)
                    )
                    imgui.set_tooltip(tooltip_text)
                end
                
                local can_continue, _ = Nodes.validate_continuation(arg_value, nil)
                if can_continue then
                    local arg_button_text = "+ Add Child to " .. arg_label
                    local arg_button_pos = Utils.get_right_cursor_pos(node.id, arg_button_text, 25)
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
    -- Get display values (live or historical)
    local display = get_display_values(node)
    
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
            imgui.same_line()
           
            -- Display return value if available (use display values for live/historical)
            if display.return_value ~= nil and display.timestamp then
                imgui.spacing()
                -- Display type info
                local type_info = Utils.get_type_info_for_display(display.return_value, node.retval_vtypename)
                
                -- Add context menu options with actual type as default
                Nodes.add_context_menu_option(node, "Copy return type", type_info.actual_type or node.return_type_full_name or "Unknown")
                if type_info.actual_type and node.return_type_full_name and type_info.actual_type ~= node.return_type_full_name then
                    Nodes.add_context_menu_option(node, "Copy return type (Expected)", node.return_type_full_name)
                end
                Nodes.add_context_menu_option(node, "Copy return value", tostring(display.return_value))
                
                local return_display = type_info.display .. " (?)"
                local return_pos = Utils.get_right_cursor_pos(node.id, return_display)
                imgui.set_cursor_pos(return_pos)
                imgui.text(type_info.display)
                imgui.same_line()
                imgui.text("(?)")
                if imgui.is_item_hovered() then
                    imgui.set_tooltip(type_info.tooltip)
                end
                
                local can_continue, _ = Nodes.validate_continuation(display.return_value, nil)
                if can_continue then
                    local button_pos = Utils.get_right_cursor_pos(node.id, "+ Add Child to Return", 25)
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
        
        -- Check if viewing historical snapshot
        local display = get_display_values(node)
        local was_called
        if display.is_historical then
            -- Historical snapshot - not a new call
            was_called = false
        else
            -- Live mode - use dirty flag
            was_called = node.was_called_dirty or false
            node.was_called_dirty = false -- Reset
        end
        
        -- Set pin value
        pin.value = was_called
        
        -- Label
        imgui.text("Was Called")
        
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
	
	-- If we successfully got a managed object, return it
	if success and mobj and type(mobj) == "userdata" then
		return mobj
	end

	local output
	-- 2. Fallback to basic conversions for primitive types
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
    ensure_initialized(node)
    
    -- Ensure output pins exist
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "was_called", nil)
    end
    if #node.pins.outputs == 1 then
        Nodes.add_output_pin(node, "main_output", nil)
    end

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
        imgui.spacing()

        -- Get display values to check if showing snapshot
        local display = get_display_values(node)
        local time_ago_str = display.timestamp 
            and Utils.format_time_ago(display.timestamp) 
            or "Never called"
        
        -- Show indicator if viewing snapshot
        if display.is_historical then
            imgui.text_colored(string.format("[Snapshot %d/%d]", display.snapshot_index, display.total_snapshots), Constants.COLOR_TEXT_WARNING)
        end
        
        imgui.text("Last call:")
        imgui.same_line()
        local pos = Utils.get_right_cursor_pos(node.id, time_ago_str)
        imgui.set_cursor_pos(pos)
        
        -- Render with hover effects
        if display.timestamp then
            Utils.render_time_ago(display.timestamp, false)
        else
            imgui.text_colored("Never called", Constants.COLOR_TEXT_DARK_GRAY)
        end
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
    
    -- Hook Options TreeNode
    --if imgui.tree_node("Hook Options") then -- Same issue as seperator where it goes outside of node width
        -- Initialize exact_type_match if not present
        if node.exact_type_match == nil then
            node.exact_type_match = false
        end
        
        local exact_type_changed, new_exact_type = imgui.checkbox("Exact Type Match", node.exact_type_match)
        if exact_type_changed then
            node.exact_type_match = new_exact_type
            State.mark_as_modified()
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("When enabled, hook only fires for exact type matches.\nFilters out calls from derived types.")
        end
        
        -- History enable/disable checkbox
        local history_changed, new_history_enabled = imgui.checkbox("Enable History", node.history_enabled)
        if history_changed then
            node.history_enabled = new_history_enabled
            if not new_history_enabled then
                -- Clear history and unpause when disabled
                clear_history(node)
                node.history_paused = false
            end
            State.mark_as_modified()
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("When enabled, captures complete snapshots of each hook call.\nAllows pausing and navigating through historical values.")
        end
        
        -- Buffer size control (only when history enabled)
        if node.history_enabled then
            imgui.same_line()
            imgui.set_next_item_width(100)
            local size_changed, new_size = imgui.drag_int("Buffer Size", node.history_buffer_size, 1, 1, 1000)
            if size_changed then
                node.history_buffer_size = new_size
                -- If new size is smaller than current count, clear history
                if node.history_buffer_size < node.history_count then
                    clear_history(node)
                end
                State.mark_as_modified()
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Drag to adjust buffer size (1-1000)")
            end
        end
        
        -- Render history navigation UI if enabled and initialized
        if node.is_initialized then
            render_history_navigation(node)
            -- Update pin values when paused to ensure connected nodes see historical data
            if node.history_paused then
                update_pin_values(node)
            end
        end
        
        --imgui.tree_pop()
    --end
    
    imgui.spacing()
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
    node.hook_call_sequence = 0
    node.hook_call_queue = {}
    node.return_value = nil  -- Initialize return value
    node.actual_return_value = nil  -- Initialize actual return value
    node.is_return_overridden = false  -- Initialize override flag
    
    -- Initialize dirty flag for "Was Called" pin
    node.was_called_dirty = false
    
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

            local managed = nil
            local success_managed, managed = pcall(function()
                return sdk.to_managed_object(args[2])
            end)
            if not success_managed then
                node.is_static = true
                managed = nil
            end

            -- Exact type matching - filter out derived types if enabled
            if managed and node.exact_type_match then
                local success_type_check, actual_type = pcall(function()
                    return managed:get_type_definition():get_full_name()
                end)
                if success_type_check and actual_type ~= node.path then
                    -- Type mismatch - skip processing this call silently
                    return sdk.PreHookResult.CALL_ORIGINAL
                end
            end

            local call_timestamp = {wall_time = os.time(), clock_time = os.clock()}
            node.hook_call_sequence = node.hook_call_sequence + 1
            node.was_called_dirty = true
            
            -- Determine argument offset and 'this' value
            local arg_offset = node.is_static and 2 or 3
            
            -- Build call data to queue
            local call_data = {
                sequence = node.hook_call_sequence,
                timestamp = call_timestamp,
                ending_value = nil,
                return_value = nil,
                hook_arg_values = {},
                pre_hook_info = nil
            }
            
            if managed or node.is_static then
                -- Add reference to prevent garbage collection
                if managed and type(managed) == "userdata" then
                    pcall(function() managed:add_ref() end)
                end
                call_data.ending_value = managed
                -- Store pre-hook info for combined status
                call_data.pre_hook_info = node.pre_hook_result == "SKIP_ORIGINAL" and "skipping original" or "calling original"
            else
                call_data.pre_hook_info = "managed object not found"
            end
            
            -- Convert and store method arguments
            local arg_count = #args - arg_offset + 1
            for i = 1, arg_count do
                local arg = args[i + arg_offset - 1]
                local type_name = "System.Object"
                if param_types and param_types[i] then
                    type_name = param_types[i]:get_full_name()
                end
                
                local converted_arg = convert_ptr(arg, type_name)
                
                -- Add reference to prevent garbage collection for managed objects
                if converted_arg and type(converted_arg) == "userdata" then
                    pcall(function() converted_arg:add_ref() end)
                end
                
                -- Fix value if needed
                local _, fixed_val = Nodes.validate_continuation(converted_arg, nil, type_name)
                if fixed_val ~= nil then
                    converted_arg = fixed_val
                end
                
                call_data.hook_arg_values[i] = converted_arg
            end
            
            -- Queue this call for buffer nodes to consume
            table.insert(node.hook_call_queue, call_data)
            
            -- Also update current node state with latest values (for UI display)
            node.last_hook_time = call_timestamp
            node.ending_value = call_data.ending_value
            node.hook_arg_values = call_data.hook_arg_values
            node.pre_hook_info = call_data.pre_hook_info
            
            -- Update pins with latest values
            if #node.pins.outputs >= 2 then
                node.pins.outputs[2].value = call_data.ending_value
            end
            for i = 1, #call_data.hook_arg_values do
                local arg_pin_index = 3 + i  -- After was_called, main_output and return_output
                if node.return_type_name == "Void" then
                    arg_pin_index = 2 + i  -- No return_output for void
                end
                if #node.pins.outputs >= arg_pin_index then
                    node.pins.outputs[arg_pin_index].value = call_data.hook_arg_values[i]
                end
            end
            
            -- Return the selected pre-hook result
            return sdk.PreHookResult[node.pre_hook_result]
        end, function(retval)
            -- Check if node still exists - if removed, don't override return value
            if not State.node_map[node.id] then
                return retval  -- Return original value unchanged
            end
            
            -- Convert return value to proper type if possible
            local ret_type = method:get_return_type()
            node.retval_vtypename = node.return_type_full_name  -- Pass the full type name for proper conversion
            local converted_retval = convert_ptr(retval, node.retval_vtypename)
            
            -- Add reference to prevent garbage collection for managed objects
            if converted_retval and type(converted_retval) == "userdata" then
                pcall(function() converted_retval:add_ref() end)
            end
            
            -- Fix value if needed
            local _, fixed_val = Nodes.validate_continuation(converted_retval, nil, node.retval_vtypename)
            if fixed_val ~= nil then
                converted_retval = fixed_val
            end
            
            -- Store actual runtime type for polymorphism support
            if converted_retval and type(converted_retval) == "userdata" then
                local actual_type_name = Utils.get_actual_type_name(converted_retval, node.retval_vtypename)
                if actual_type_name ~= node.retval_vtypename then
                    node.actual_return_type_name = actual_type_name
                end
            end
            
            node.actual_return_value = converted_retval
            
            -- Update the most recent call_data with return value
            if #node.hook_call_queue > 0 then
                node.hook_call_queue[#node.hook_call_queue].return_value = converted_retval
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
                
                -- Update queue entry with overridden value
                if #node.hook_call_queue > 0 then
                    node.hook_call_queue[#node.hook_call_queue].return_value = override_value
                end
            else
                table.insert(status_parts, "return unchanged")
                node.return_value = converted_retval
                node.is_return_overridden = false
            end
            
            -- Update return output pin (index 3, if exists and non-void)
            if node.return_type_name and node.return_type_name ~= "Void" and #node.pins.outputs >= 3 then
                node.pins.outputs[3].value = node.return_value
            end
            
            -- Capture history snapshot (complete call data including return value)
            if node.history_enabled and #node.hook_call_queue > 0 then
                local latest_call = node.hook_call_queue[#node.hook_call_queue]
                local snapshot = {
                    sequence = latest_call.sequence,
                    timestamp = latest_call.timestamp,
                    ending_value = latest_call.ending_value,
                    return_value = latest_call.return_value,
                    hook_arg_values = {}
                }
                -- Deep copy arg values
                for i, v in ipairs(latest_call.hook_arg_values or {}) do
                    snapshot.hook_arg_values[i] = v
                end
                add_to_history(node, snapshot)
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

-- ========================================
-- Serialization
-- ========================================

function HookStarter.serialize(node, Config)
    -- Get base serialization
    local data = BaseStarter.serialize(node, Config)
    
    -- Add hook-specific fields
    data.method_name = node.method_name
    
    -- Generate signature for method reconstruction
    if node.path and node.method_group_index and node.method_index then
        local type_def = sdk.find_type_definition(node.path)
        if type_def then
            local method = Nodes.get_method_by_group_and_index(type_def, node.method_group_index, node.method_index, false)
            if method then
                data.selected_method_signature = Nodes.get_method_signature(method)
            end
        end
    end
    
    data.pre_hook_result = node.pre_hook_result
    data.return_type_name = node.return_type_name
    data.return_type_full_name = node.return_type_full_name
    data.is_initialized = node.is_initialized
    data.return_override_manual = node.return_override_manual
    data.actual_return_value = node.actual_return_value
    data.is_return_overridden = node.is_return_overridden
    data.exact_type_match = node.exact_type_match
    
    -- History settings (not the history data itself - that's runtime only)
    data.history_enabled = node.history_enabled
    data.history_buffer_size = node.history_buffer_size
    
    return data
end

function HookStarter.deserialize(data, Config)
    -- Get base node structure
    local node = BaseStarter.deserialize(data, Config)
    
    -- Add hook-specific fields
    node.method_name = data.method_name or ""
    node.selected_method_combo = data.selected_method_combo
    node.selected_method_signature = data.selected_method_signature
    node.method_group_index = data.method_group_index
    node.method_index = data.method_index
    node.pre_hook_result = data.pre_hook_result or "CALL_ORIGINAL"
    node.return_type_name = data.return_type_name
    node.return_type_full_name = data.return_type_full_name
    node.hook_id = nil
    node.is_initialized = data.is_initialized or false
    node.return_override_manual = data.return_override_manual
    node.actual_return_value = data.actual_return_value
    node.is_return_overridden = data.is_return_overridden or false
    node.exact_type_match = data.exact_type_match or false
    
    -- History settings
    node.history_enabled = data.history_enabled or false
    node.history_buffer_size = data.history_buffer_size or 25
    
    return node
end

return HookStarter