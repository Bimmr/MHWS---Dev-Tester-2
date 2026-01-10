-- HistoryBuffer Node Properties:
-- This utility node captures and stores a history of values passing through it.
-- Allows pausing the display and navigating through past values.
--
-- Pins:
-- - pins.inputs[1]: "input" - Value to track in history
-- - pins.outputs[1]: "output" - Current or historical value based on pause state
-- - pins.outputs[2]: "history_count" - Number of entries in history
--
-- Buffer Configuration:
-- - buffer_size: Number - Maximum number of history entries to store (default: 10)
-- - is_paused: Boolean - When true, outputs historical value instead of current input
-- - current_history_index: Number - Current position in history (1 = oldest, history_count = newest)
--
-- History Data:
-- - history: Array - Circular buffer of {timestamp, absolute_time, value} entries
-- - history_write_index: Number - Next write position in circular buffer
-- - history_count: Number - Current number of entries (max buffer_size)
--
-- Runtime:
-- - output_value: Any - The value being output (input when running, historical when paused)
--
-- Pins:
-- - pins.inputs[1]: "input" - Value to capture
-- - pins.inputs[2]: "index" - Index value (optional connection)
-- - pins.outputs[1]: "output" - Input value (running) or historical value (paused)

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local BaseUtility = require("DevTester2.Utility.BaseUtility")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes

local HistoryBuffer = {}

-- Initialize history buffer properties
local function ensure_initialized(node)
    node.buffer_size = node.buffer_size or 10
    node.is_paused = node.is_paused or false
    node.current_history_index = node.current_history_index or 1
    
    if not node.history then
        node.history = {}
    end
    node.history_write_index = node.history_write_index or 1
    node.history_count = node.history_count or 0
    node.last_processed_sequence = node.last_processed_sequence or 0
end

-- Add a value to the history buffer (circular buffer logic)
local function add_to_history(node, value)
    if not node.history then
        node.history = {}
    end
    
    local entry = {
        timestamp = {wall_time = os.time(), clock_time = os.clock()},
        value = value
    }
    
    -- Write to circular buffer
    node.history[node.history_write_index] = entry
    
    -- Move write index forward (circular)
    node.history_write_index = (node.history_write_index % node.buffer_size) + 1
    
    -- Increment count up to buffer_size
    if node.history_count < node.buffer_size then
        node.history_count = node.history_count + 1
    end
    
    -- Update current_history_index to point to newest entry when not paused
    if not node.is_paused then
        node.current_history_index = node.history_count
    end
end

-- Get a history entry by index (1 = oldest, history_count = newest)
local function get_history_entry(node, index)
    if not node.history or node.history_count == 0 then
        return nil
    end
    
    -- Clamp index
    index = math.max(1, math.min(index, node.history_count))
    
    -- Calculate actual position in circular buffer
    -- If buffer is not full, entries are at indices 1..history_count
    -- If buffer is full, oldest entry is at history_write_index
    local actual_index
    if node.history_count < node.buffer_size then
        actual_index = index
    else
        -- Buffer is full - calculate offset from oldest entry
        actual_index = ((node.history_write_index - 1 + index - 1) % node.buffer_size) + 1
    end
    
    return node.history[actual_index]
end

-- Render the history navigation UI (only when paused and history exists)
local function render_history_navigation(node)
    imgui.spacing()
    imgui.spacing()
    
    -- Build dropdown options for all history entries (oldest to newest)
    local dropdown_options = {}
    for i = 1, node.history_count do
        local entry = get_history_entry(node, i)
        if entry then
            local wall_time = type(entry.timestamp) == "table" and entry.timestamp.wall_time or (entry.absolute_time or os.time())
            local clock_time = Utils.get_clock_time(entry.timestamp)
            local milliseconds = clock_time and math.floor((clock_time - math.floor(clock_time)) * 1000) or 0
            local time_str = os.date("%H:%M:%S", wall_time) .. string.format(".%03d", milliseconds)
            local value_name = Utils.get_value_display_string(entry.value)
            table.insert(dropdown_options, string.format("%d. %s:  %s", i, time_str, value_name))
        else
            table.insert(dropdown_options, string.format("%d. <error>", i))
        end
    end
    
    -- Determine which index to use for display: connected value takes priority
    local display_index = node.current_history_index -- Default from manual selection
    local has_index_input = false
    
    -- Check for connected index value using pin system
    local index_pin = node.pins.inputs[2]
    if index_pin and index_pin.connection then
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
    end
    
    -- Ensure display index is within bounds
    if display_index < 1 then
        display_index = 1
    elseif display_index > node.history_count and node.history_count > 0 then
        display_index = node.history_count
    end
    
    -- Display current index and navigation controls within input attribute
    imnodes.begin_input_attribute(index_pin.id)
    
    -- Left arrow button (go to older entry) - disabled when index input is provided
    local can_go_prev = display_index > 1
    local left_disabled = not can_go_prev or has_index_input
    if left_disabled then
        imgui.begin_disabled()
    end
    if imgui.arrow_button("history_left", 0) then
        if can_go_prev then
            node.current_history_index = display_index - 1
            State.mark_as_modified()
        end
    end
    if left_disabled then
        imgui.end_disabled()
    end
    
    imgui.same_line()
    imgui.set_next_item_width(imgui.calc_item_width() - 24)
    
    -- History entry dropdown (disabled when index input is provided)
    if has_index_input then
        imgui.begin_disabled()
    end
    local dropdown_changed, new_selection = imgui.combo("##HistoryEntry", display_index, dropdown_options)
    if dropdown_changed and not has_index_input then
        node.current_history_index = new_selection
        State.mark_as_modified()
    end
    if has_index_input then
        imgui.end_disabled()
    end
    
    imgui.same_line()
    
    -- Right arrow button (go to newer entry) - disabled when index input is provided
    local can_go_next = display_index < node.history_count
    local right_disabled = not can_go_next or has_index_input
    if right_disabled then
        imgui.begin_disabled()
    end
    if imgui.arrow_button("history_right", 1) then
        if can_go_next then
            node.current_history_index = display_index + 1
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
    imgui.text("History")
    if has_index_input then
        imgui.end_disabled()
    end
    
    imnodes.end_input_attribute()
    
    -- Update node's current_history_index if using connected index
    if has_index_input then
        node.current_history_index = display_index
    end
end

function HistoryBuffer.render(node)
    ensure_initialized(node)
    
    -- Ensure pins exist (2 inputs, 1 output)
    if #node.pins.inputs < 2 then
        if #node.pins.inputs == 0 then
            Nodes.add_input_pin(node, "input", nil)
        end
        if #node.pins.inputs == 1 then
            Nodes.add_input_pin(node, "index", nil)
        end
    end
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    local input_pin = node.pins.inputs[1]
    local index_pin = node.pins.inputs[2]
    local output_pin = node.pins.outputs[1]
    local input_value = Nodes.get_input_pin_value(node, 1)
    input_pin.value = input_value
    
    -- Core logic: get output value and update history
    local output_value
    local display_entry
    
    if node.is_paused then
        -- When paused, check for connected index pin
        local display_index = node.current_history_index
        local has_index_input = false
        
        if index_pin and index_pin.connection then
            -- Look up connected pin via State.pin_map
            local source_pin_info = State.pin_map[index_pin.connection.pin]
            local connected_index = source_pin_info and source_pin_info.pin.value
            if connected_index ~= nil then
                local num_index = tonumber(connected_index)
                if num_index then
                    display_index = math.floor(num_index)
                    has_index_input = true
                end
            end
        end
        
        -- Ensure display index is within bounds
        if display_index < 1 then
            display_index = 1
        elseif display_index > node.history_count and node.history_count > 0 then
            display_index = node.history_count
        end
        
        -- Update node's current_history_index if using connected index
        if has_index_input then
            node.current_history_index = display_index
        end
        
        -- Use historical value
        display_entry = get_history_entry(node, display_index)
        output_value = display_entry and display_entry.value or nil
    else
        local parent_node = nil
        
        -- Check if input is from a HookStarter and get its last_hook_time
        if input_pin.connection then
            local source_pin_info = State.pin_map[input_pin.connection.pin]
            if source_pin_info then
                parent_node = Nodes.find_node_by_id(source_pin_info.node_id)
            end
        end

        
        -- For hooks, process entire call queue
        if parent_node and parent_node.category == Constants.NODE_CATEGORY_STARTER and parent_node.type == Constants.STARTER_TYPE_HOOK then
            local hook_queue = parent_node.hook_call_queue or {}
            
            -- Determine which pin we're connected to
            local source_pin_id = input_pin.connection and input_pin.connection.pin
            local source_pin_info = source_pin_id and State.pin_map[source_pin_id]
            local source_pin_index = nil
            if source_pin_info then
                -- Find pin index in parent's outputs
                for i, pin in ipairs(parent_node.pins.outputs) do
                    if pin.id == source_pin_id then
                        source_pin_index = i
                        break
                    end
                end
            end
            
            -- Process all unprocessed calls in the queue
            for _, call_data in ipairs(hook_queue) do
                if call_data.sequence > node.last_processed_sequence then
                    -- Get the value from the correct pin
                    local value_to_add = nil
                    if source_pin_index == 2 then
                        -- Main output (managed object)
                        value_to_add = call_data.ending_value
                    elseif source_pin_index == 3 and parent_node.return_type_name ~= "Void" then
                        -- Return value
                        value_to_add = call_data.return_value
                    elseif source_pin_index then
                        -- Argument pin
                        local arg_start_index = parent_node.return_type_name == "Void" and 3 or 4
                        local arg_index = source_pin_index - arg_start_index + 1
                        if arg_index >= 1 and arg_index <= #call_data.hook_arg_values then
                            value_to_add = call_data.hook_arg_values[arg_index]
                        end
                    end
                    
                    -- Add this specific call's value to history
                    add_to_history(node, value_to_add)
                    node.last_processed_sequence = call_data.sequence
                end
            end
            
            -- Clean up processed calls from queue (keep only unprocessed)
            local new_queue = {}
            for _, call_data in ipairs(hook_queue) do
                if call_data.sequence > node.last_processed_sequence then
                    table.insert(new_queue, call_data)
                end
            end
            parent_node.hook_call_queue = new_queue
        else
            add_to_history(node, input_value)
        end
        output_value = input_value
        display_entry = { timestamp = {wall_time = os.time(), clock_time = os.clock()}, value = input_value }
    end
    
    output_pin.value = output_value
    node.ending_value = output_value  -- Set ending_value for BaseUtility.render_action_buttons
    
    -- Begin node rendering
    imnodes.begin_node(node.id)
    
    imnodes.begin_node_titlebar()
    imnodes.begin_input_attribute(input_pin.id)
    imgui.text("History Buffer")
    imnodes.end_input_attribute()
    imnodes.end_node_titlebar()
    
    -- Buffer size configuration
    local size_changed, new_size = imgui.slider_int("Buffer Size", node.buffer_size, 1, 50)
    if size_changed then
        node.buffer_size = new_size
        -- Trim history if needed
        if node.history_count > new_size then
            local new_history = {}
            for i = 1, new_size do
                local old_index = node.history_count - new_size + i
                new_history[i] = get_history_entry(node, old_index)
            end
            node.history = new_history
            node.history_count = new_size
            node.history_write_index = 1
            node.current_history_index = math.min(node.current_history_index, new_size)
        end
        State.mark_as_modified()
    end
    
    imgui.spacing()
    
    -- Pause/Resume button
    local pause_button_text = node.is_paused and " ▶ Resume" or "⏸ Pause"
    local has_data = node.history_count > 0
    if not has_data then imgui.begin_disabled() end
    if imgui.button(pause_button_text) then
        node.is_paused = not node.is_paused
        if not node.is_paused then
            node.current_history_index = node.history_count
        end
        State.mark_as_modified()
    end
    if not has_data then
        imgui.end_disabled()
        if imgui.is_item_hovered(1024) then
            imgui.set_tooltip("No data to pause")
        end
    end
    
    imgui.same_line()
    -- State indicator
    if node.is_paused then
        imgui.text_colored("PAUSED", Constants.COLOR_TEXT_WARNING)
        imgui.same_line()
        imgui.text(string.format("(Entry %d)", node.current_history_index))
    else
        imgui.text_colored("LIVE", Constants.COLOR_TEXT_SUCCESS)
    end
    
    -- History navigation
    if node.is_paused and node.history_count > 0 then
        render_history_navigation(node)
    end
    
    imgui.spacing()
    
    -- Time display
    if node.is_paused and display_entry and display_entry.timestamp then
        imgui.text("Time:")
        imgui.same_line()
        local time_str = Utils.format_time_ago(display_entry.timestamp)
        local pos = Utils.get_right_cursor_pos(node.id, time_str)
        imgui.set_cursor_pos(pos)
        Utils.render_time_ago(display_entry.timestamp)
    end
    
    -- Output section
    imnodes.begin_output_attribute(output_pin.id)
    imgui.text("Output")
    local display_value = Utils.get_value_display_string(output_value)
    imgui.same_line()
    local pos = Utils.get_right_cursor_pos(node.id, display_value .. " (?)")
    imgui.set_cursor_pos(pos)
    imgui.text(display_value)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() then
        imgui.set_tooltip(Utils.get_tooltip_for_value(output_value))
    end
    imnodes.end_output_attribute()
    
    imgui.spacing()
    BaseUtility.render_action_buttons(node)
    BaseUtility.render_debug_info(node)
    
    imnodes.end_node()
end

function HistoryBuffer.execute(node)
    return Nodes.get_input_pin_value(node, 1)
end

-- ========================================
-- Serialization
-- ========================================

function HistoryBuffer.serialize(node, Config)
    local data = BaseUtility.serialize(node, Config)
    data.buffer_size = node.buffer_size
    data.is_paused = node.is_paused
    data.current_history_index = node.current_history_index
    data.history_write_index = node.history_write_index
    data.history_count = node.history_count
    -- Note: We don't serialize the actual history entries as they're runtime data
    return data
end

function HistoryBuffer.deserialize(data, Config)
    local node = BaseUtility.deserialize(data, Config)
    node.buffer_size = data.buffer_size or 10
    node.is_paused = data.is_paused or false
    node.current_history_index = data.current_history_index or 1
    node.history_write_index = data.history_write_index or 1
    node.history_count = data.history_count or 0
    node.history = {}
    node.display_value = nil
    return node
end

return HistoryBuffer
