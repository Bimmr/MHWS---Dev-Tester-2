-- CallBuffer Node Properties:
-- This control node captures multiple hook calls and allows selection of a specific call.
-- Automatically updates existing entries when the same object address is seen again (On Repeat mode).
--
-- Configuration:
-- - buffer_size: Number - Maximum number of calls to store (default: 25)
-- - current_call_index: Number - Current selected call position (1 = first call, call_count = last)
--
-- Buffer State:
-- - call_buffer: Array - Array of {value, timestamp, absolute_time, address} entries
-- - call_count: Number - Number of unique calls captured
-- - seen_addresses: Table - Set of addresses seen (for repeat detection)
--
-- Pins:
-- - pins.inputs[1]: "input" - Hook output or value to capture
-- - pins.inputs[2]: "index" - Index value (optional connection)
-- - pins.outputs[1]: "output" - Selected call value
-- - pins.outputs[2]: "call_count" - Number of unique calls captured
--
-- Runtime Values:
-- - ending_value: Any - The selected call value
-- - status: String - Current status for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local BaseUtility = require("DevTester2.Utility.BaseUtility")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes

local CallBuffer = {}

-- Initialize call buffer properties
local function ensure_buffer_initialized(node)
    node.buffer_size = node.buffer_size or 25
    node.current_call_index = node.current_call_index or 1
    
    if not node.call_buffer then
        node.call_buffer = {}
    end
    node.call_count = node.call_count or 0
    if not node.seen_addresses then
        node.seen_addresses = {}
    end
end

-- Get address/pointer from a value
local function get_value_address(value)
    if value == nil then
        return "nil"
    end
    
    if type(value) == "userdata" then
        -- Try to get pointer address for managed objects
        local success, address = pcall(function()
            return tostring(sdk.to_ptr(value))
        end)
        if success and address then
            return address
        end
        -- Fallback to tostring which includes address for userdata
        return tostring(value)
    end
    
    -- For primitives, use the value itself as identifier
    return tostring(type(value)) .. ":" .. tostring(value)
end

-- Clear the buffer
local function clear_buffer(node)
    node.call_buffer = {}
    node.call_count = 0
    node.current_call_index = 1
    node.seen_addresses = {}
end

-- Clean up stale entries (replace with nil if not updated in last 1 second)
local function cleanup_stale_entries(node)
    local current_time = os.clock()
    local timeout = 10.0 -- 10 seconds
    
    for i = 1, node.call_count do
        local entry = node.call_buffer[i]
        if entry and entry.value ~= nil then
            local time_since_update = current_time - entry.timestamp
            if time_since_update > timeout then
                -- Entry is stale - replace value with nil
                entry.value = nil
                entry.absolute_time = os.time()
                entry.timestamp = current_time
            end
        end
    end
end

-- Add a call to the buffer
local function add_to_buffer(node, value)
    if not node.call_buffer then
        node.call_buffer = {}
    end
    
    -- Get address for cycle detection
    local address = get_value_address(value)

    -- If adding first non-nil value and buffer only has one nil entry, remove the nil
    if value ~= nil and node.call_count == 1 then
        local first_entry = node.call_buffer[1]
        if first_entry and first_entry.value == nil then
            -- Clear the buffer before adding the non-nil value
            node.call_buffer = {}
            node.call_count = 0
            node.seen_addresses = {}
        end
    end

    -- Check if this address was already seen (repeat detected)
    if node.seen_addresses[address] then
        -- Same address seen again - find and replace the existing entry
        for i = 1, node.call_count do
            if node.call_buffer[i] and node.call_buffer[i].address == address then
                -- Replace the existing entry with updated value
                node.call_buffer[i].value = value
                node.call_buffer[i].timestamp = os.clock()
                node.call_buffer[i].absolute_time = os.time()
                node.status = string.format("Updated call %d (repeat)", i)
                return
            end
        end
    end
    
    -- Check buffer capacity
    if node.call_count >= node.buffer_size then
        node.status = string.format("Buffer full (%d/%d)", node.call_count, node.buffer_size)
        return
    end
    
    local entry = {
        value = value,
        timestamp = os.clock(),
        absolute_time = os.time(),
        address = address
    }
    
    node.call_count = node.call_count + 1
    node.call_buffer[node.call_count] = entry
    
    -- Mark address as seen
    node.seen_addresses[address] = true
    
    -- Clamp current_call_index to valid range
    if node.current_call_index > node.call_count then
        node.current_call_index = node.call_count
    end
end

-- Get a call entry by index (1-based)
local function get_call_entry(node, index)
    if not node.call_buffer or node.call_count == 0 then
        return nil
    end
    
    -- Clamp index
    index = math.max(1, math.min(index, node.call_count))
    return node.call_buffer[index]
end

-- Detect and handle frame changes
local function handle_frame_change(node)
    local success, current_frame = pcall(function()
        return re.get_frame_count()
    end)
    
    if not success then
        -- Frame detection failed, use fallback
        current_frame = node.current_frame or 0
    end
    
    -- Check if frame changed
    if current_frame ~= node.current_frame then
        node.current_frame = current_frame
        
        -- Clear buffer if in Per Frame mode
        if node.reset_mode == 1 then
            clear_buffer(node)
        end
    end
end

-- Render the call navigation UI (arrows + combo)
local function render_call_navigation(node)
    if node.call_count == 0 then
        return
    end
    
    imgui.spacing()
    imgui.spacing()
    
    -- Build dropdown options for all calls
    local dropdown_options = {}
    for i = 1, node.call_count do
        local entry = get_call_entry(node, i)
        if entry then
            local time_str = os.date("%H:%M:%S", entry.absolute_time or os.time())
            local value_name = Utils.get_value_display_string(entry.value)
            table.insert(dropdown_options, string.format("%d. %s:  %s",  i, time_str, value_name))
        else
            table.insert(dropdown_options, string.format("Call %d: <error>", i))
        end
    end
    
    -- Determine which index to use for display: connected value takes priority
    local display_index = node.current_call_index -- Default from manual selection
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
    elseif display_index > node.call_count and node.call_count > 0 then
        display_index = node.call_count
    end
    
    -- Display current index and navigation controls within input attribute
    imnodes.begin_input_attribute(index_pin.id)
    
    -- Left arrow button (disabled if at first call or index input is provided)
    local left_disabled = display_index <= 1 or has_index_input
    if left_disabled then
        imgui.begin_disabled()
    end
    if imgui.arrow_button("call_left", 0) then
        if display_index > 1 then
            node.current_call_index = display_index - 1
            -- Update ending_value immediately
            local selected_entry = get_call_entry(node, node.current_call_index)
            node.ending_value = selected_entry and selected_entry.value or nil
            if node.pins.outputs[1] then
                node.pins.outputs[1].value = node.ending_value
            end
            State.mark_as_modified()
        end
    end
    if left_disabled then
        imgui.end_disabled()
    end
    
    imgui.same_line()
    imgui.set_next_item_width(imgui.calc_item_width() - 24)
    
    -- Call selection dropdown (disabled when index input is provided)
    if has_index_input then
        imgui.begin_disabled()
    end

    local dropdown_changed, new_selection = imgui.combo("##CallEntry", display_index, dropdown_options)
    if dropdown_changed then
        State.mark_as_modified()
    end
    if not has_index_input then
        node.current_call_index = new_selection
    end
    
    -- Update ending_value immediately
    local selected_entry = get_call_entry(node, node.current_call_index)
    node.ending_value = selected_entry and selected_entry.value or nil
    if node.pins.outputs[1] then
        node.pins.outputs[1].value = node.ending_value
    end

    if has_index_input then
        imgui.end_disabled()
    end
    
    imgui.same_line()
    
    -- Right arrow button (disabled if at last call or index input is provided)
    local right_disabled = display_index >= node.call_count or has_index_input
    if right_disabled then
        imgui.begin_disabled()
    end
    if imgui.arrow_button("call_right", 1) then
        if display_index < node.call_count then
            node.current_call_index = display_index + 1
            -- Update ending_value immediately
            local selected_entry = get_call_entry(node, node.current_call_index)
            node.ending_value = selected_entry and selected_entry.value or nil
            if node.pins.outputs[1] then
                node.pins.outputs[1].value = node.ending_value
            end
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
    imgui.text("Navigate")
    if has_index_input then
        imgui.end_disabled()
    end
    
    imnodes.end_input_attribute()
    imgui.spacing()
    
    -- Update node's current_call_index and ending_value if using connected index
    if has_index_input then
        node.current_call_index = display_index
        local selected_entry = get_call_entry(node, node.current_call_index)
        node.ending_value = selected_entry and selected_entry.value or nil
        if node.pins.outputs[1] then
            node.pins.outputs[1].value = node.ending_value
        end
    end
end

function CallBuffer.execute(node)
    ensure_buffer_initialized(node)
    
    -- Check if input pin is connected
    local input_pin = node.pins.inputs[1]
    local is_connected = input_pin and input_pin.connection ~= nil
    
    if not is_connected then
        -- No connection - reset the buffer
        if node.call_count > 0 then
            clear_buffer(node)
            node.status = "Disconnected - buffer cleared"
        else
            node.status = "Waiting for connection..."
        end
    else
        -- Connected - clean up stale entries first
        if node.cleanup_stale_entries then 
            cleanup_stale_entries(node)
        end
        
        -- Get input value and hook time (if applicable)
        local input_value = Nodes.get_input_pin_value(node, 1)
        local parent_node = nil
        
        -- Check if input is from a HookStarter and get its last_hook_time
        if input_pin.connection then
            local source_pin_info = State.pin_map[input_pin.connection.pin]
            if source_pin_info then
                parent_node = Nodes.find_node_by_id(source_pin_info.node_id)
            end
        end

        
        -- For hooks, only add if this is a new call (hook_time changed)
        if parent_node and parent_node.category == Constants.NODE_CATEGORY_STARTER and parent_node.type == Constants.STARTER_TYPE_HOOK then
            local last_hook_time = parent_node.last_hook_time
            if not node.last_processed_hook_time or last_hook_time > node.last_processed_hook_time then
                add_to_buffer(node, input_value)
                node.last_processed_hook_time = last_hook_time
            end
        else
           -- For non-hook sources, add normally
           add_to_buffer(node, input_value)
        end
    end
    
    -- Get selected call
    local selected_entry = get_call_entry(node, node.current_call_index)
    node.ending_value = selected_entry and selected_entry.value or nil
    
    -- Update status (only if we haven't set it above)
    if is_connected then
        if node.call_count == 0 then
            node.status = "Waiting for calls..."
        else
            node.status = string.format("Call %d of %d", node.current_call_index, node.call_count)
        end
    end
    
    -- Set call_count output (output pin 2)
    if node.pins.outputs[2] then
        node.pins.outputs[2].value = node.call_count
    end
    
    return node.ending_value
end

function CallBuffer.render(node)
    ensure_buffer_initialized(node)
    
    -- Ensure pins exist (2 inputs, 2 outputs)
    if #node.pins.inputs < 2 then
        if #node.pins.inputs == 0 then
            Nodes.add_input_pin(node, "input", nil)
        end
        if #node.pins.inputs == 1 then
            Nodes.add_input_pin(node, "index", nil)
        end
    end
    if #node.pins.outputs < 2 then
        if #node.pins.outputs == 0 then
            Nodes.add_output_pin(node, "output", nil)
        end
        if #node.pins.outputs == 1 then
            Nodes.add_output_pin(node, "call_count", nil)
        end
    end
    
    local input_pin = node.pins.inputs[1]
    local index_pin = node.pins.inputs[2]
    local output_pin = node.pins.outputs[1]
    local call_count_pin = node.pins.outputs[2]

    imnodes.begin_node(node.id)

    -- Execute to update buffer and values
    CallBuffer.execute(node)

    imnodes.begin_node_titlebar()
    imnodes.begin_input_attribute(input_pin.id)
    imgui.text("Call Buffer" .. string.format("  (%d / %d)", node.call_count, node.buffer_size))
    imnodes.end_input_attribute()
    imnodes.end_node_titlebar()

    imgui.spacing()

    -- Buffer size configuration
    local size_changed, new_size = imgui.slider_int("Buffer Size", node.buffer_size, 1, 200)
    if size_changed then
        node.buffer_size = new_size
        -- Trim buffer if needed
        if node.call_count > new_size then
            local new_buffer = {}
            for i = 1, new_size do
                new_buffer[i] = node.call_buffer[i]
            end
            node.call_buffer = new_buffer
            node.call_count = new_size
            node.current_call_index = math.min(node.current_call_index, new_size)
        end
        State.mark_as_modified()
    end

    imgui.spacing()

    -- Call navigation UI
    render_call_navigation(node)

    if imgui.button("Clear Buffer") then
        clear_buffer(node)
        State.mark_as_modified()
    end
    imgui.spacing()
    imgui.spacing()


    -- Status display
    if node.call_count == 0 and node.status then
        imgui.text(node.status)
    end

    imgui.spacing()

    -- Output attribute
    local display_value = "nil"
    local tooltip_text = "No call selected"
    
    if node.ending_value ~= nil then
        display_value = Utils.get_value_display_string(node.ending_value)
        tooltip_text = Utils.get_tooltip_for_value(node.ending_value)
    end

     -- Call count output
    imnodes.begin_output_attribute(call_count_pin.id)
    local count_display = string.format("Call Count: %d", node.call_count)
    local count_pos = Utils.get_right_cursor_pos(node.id, count_display)
    imgui.set_cursor_pos(count_pos)
    imgui.text(string.format("Call Count: %d", node.call_count))
    imnodes.end_output_attribute()

    -- Output attribute
    imnodes.begin_output_attribute(output_pin.id)
    local pos = Utils.get_right_cursor_pos(node.id, display_value .. " (?)")
    imgui.set_cursor_pos(pos)
    imgui.text(display_value)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() then
        imgui.set_tooltip(tooltip_text)
    end
    imnodes.end_output_attribute()

    imgui.spacing()

    local changed, new_cleanup = imgui.checkbox("Cleanup Stale Entries", node.cleanup_stale_entries or false)
    if changed then
        node.cleanup_stale_entries = new_cleanup
        State.mark_as_modified()
    end

    BaseUtility.render_action_buttons(node)

    imnodes.end_node()
end

-- ========================================
-- Serialization
-- ========================================

function CallBuffer.serialize(node, Config)
    local data = BaseUtility.serialize(node, Config)
    data.buffer_size = node.buffer_size
    data.current_call_index = node.current_call_index
    -- Don't serialize call_buffer (runtime data) - will be rebuilt
    return data
end

function CallBuffer.deserialize(data, Config)
    local node = BaseUtility.deserialize(data, Config)
    node.buffer_size = data.buffer_size or 10
    node.current_call_index = data.current_call_index or 1
    node.call_buffer = {}
    node.call_count = 0
    node.seen_addresses = {}
    return node
end

return CallBuffer
