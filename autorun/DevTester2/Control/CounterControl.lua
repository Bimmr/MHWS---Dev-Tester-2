-- DevTester v2.0 - Counter Control
-- Control node that counts up to a maximum value and can be restarted

-- CounterControl Node Properties:
-- This node provides a counter that increments up to a maximum value.
--
-- Pins:
-- - pins.inputs[1]: "max" - Maximum count value
-- - pins.inputs[2]: "active" - Boolean control for enabling/disabling counting
-- - pins.inputs[3]: "restart" - Boolean trigger to restart counter when at max
-- - pins.outputs[1]: "output" - The current count value
--
-- Manual Input Values:
-- - max_manual_value: String - Manual text input for max count when not connected
-- - active_manual_value: Boolean - Manual checkbox for active control when not connected
-- - restart_manual_value: Boolean - Manual checkbox for restart trigger when not connected
-- - delay_ms: Number - Delay in milliseconds between increments (manual input only)
--
-- Runtime Values:
-- - ending_value: Number - The current count value
-- - current_count: Number - Internal counter state
-- - last_increment_time: Number - Timestamp of last increment for delay tracking
--
-- Inherits status property from BaseControl for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseControl = require("DevTester2.Control.BaseControl")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local CounterControl = {}

-- ========================================
-- Counter Control Node
-- ========================================

function CounterControl.execute(node)
    -- Get input pins
    local max_pin = node.pins.inputs[1]
    local active_pin = node.pins.inputs[2]
    local restart_pin = node.pins.inputs[3]
    
    -- Get input values using pin system
    local max_value = Nodes.get_input_pin_value(node, 1)  -- First input pin
    local active_value = Nodes.get_input_pin_value(node, 2)  -- Second input pin
    local restart_value = Nodes.get_input_pin_value(node, 3)  -- Third input pin

    -- Initialize counter if not set
    if node.current_count == nil then
        node.current_count = 0
    end

    -- Initialize delay_ms if not set
    if node.delay_ms == nil then
        node.delay_ms = 1000 -- default 1 second
    end

    -- Convert max_value to number
    local max_count = 10 -- default
    if max_pin.connection then
        max_count = tonumber(max_value) or 10
    elseif node.max_manual_value then
        max_count = tonumber(node.max_manual_value) or 10
    end

    -- Determine active state
    -- If pin is connected, use the connected value
    -- If not connected, use manual checkbox value (defaults to false)
    local is_active = false
    if active_pin.connection then
        is_active = not not active_value
    else
        is_active = not not node.active_manual_value
    end

    -- Determine restart state
    -- If pin is connected, use the connected value
    -- If not connected, use manual checkbox value (defaults to false)
    local should_restart = false
    if restart_pin.connection then
        should_restart = not not restart_value
    else
        should_restart = not not node.restart_manual_value
    end

    -- Handle restart - only when triggered AND counter reached max
    if should_restart and node.current_count >= max_count then
        node.current_count = 0
        node.last_increment_time = nil -- Reset timing
        node.status = "Restarted"
        node.restart_triggered = false -- Reset manual trigger
    elseif is_active then
        -- Check if enough time has passed for increment
        local current_time = os.clock() * 1000 -- Convert to milliseconds
        local delay_ms = tonumber(node.delay_ms) or 1000
        
        if node.last_increment_time == nil or (current_time - node.last_increment_time) >= delay_ms then
            -- Increment counter if not at max
            if node.current_count < max_count then
                node.current_count = node.current_count + 1
                node.last_increment_time = current_time
                node.status = "Counting"
            else
                node.status = "At Max"
            end
        else
            -- Still waiting for delay
            local remaining_ms = delay_ms - (current_time - node.last_increment_time)
            node.status = string.format("Waiting (%.0fms)", remaining_ms)
        end
    else
        node.status = "Inactive"
    end

    -- Set output value
    node.ending_value = node.current_count
    return node.ending_value
end

function CounterControl.render(node)
    -- Ensure pins exist (3 inputs, 1 output)
    if #node.pins.inputs < 3 then
        if #node.pins.inputs == 0 then
            Nodes.add_input_pin(node, "max", nil)
        end
        if #node.pins.inputs == 1 then
            Nodes.add_input_pin(node, "active", nil)
        end
        if #node.pins.inputs == 2 then
            Nodes.add_input_pin(node, "restart", nil)
        end
    end
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    local max_pin = node.pins.inputs[1]
    local active_pin = node.pins.inputs[2]
    local restart_pin = node.pins.inputs[3]
    local output_pin = node.pins.outputs[1]

    imnodes.begin_node(node.id)

    imnodes.begin_node_titlebar()
    imgui.text("Counter")
    imnodes.end_node_titlebar()

    -- Execute to update ending_value
    CounterControl.execute(node)

    -- Max count input pin
    imnodes.begin_input_attribute(max_pin.id)
    local has_max_connection = max_pin.connection ~= nil
    if has_max_connection then
        -- Look up connected pin via State.pin_map
        local source_pin_info = State.pin_map[max_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        local display_value = connected_value ~= nil and tostring(connected_value) or "10"
        imgui.begin_disabled()
        imgui.input_text("Max Count", display_value)
        imgui.end_disabled()
    else
        node.max_manual_value = node.max_manual_value or "10"
        local max_changed, new_value = imgui.input_text("Max Count", node.max_manual_value)
        if max_changed then
            node.max_manual_value = new_value
            State.mark_as_modified()
        end
    end
    imnodes.end_input_attribute()

    -- Active input pin (checkbox)
    imnodes.begin_input_attribute(active_pin.id)
    local has_active_connection = active_pin.connection ~= nil
    if has_active_connection then
        -- Look up connected pin via State.pin_map
        local source_pin_info = State.pin_map[active_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        local display_value = not not connected_value
        imgui.begin_disabled()
        imgui.checkbox("Active", display_value)
        imgui.end_disabled()
    else
        local active_changed, new_value = imgui.checkbox("Active", node.active_manual_value or false)
        if active_changed then
            node.active_manual_value = new_value
            State.mark_as_modified()
        end
    end
    imnodes.end_input_attribute()

    -- Restart input pin (checkbox)
    imnodes.begin_input_attribute(restart_pin.id)
    local has_restart_connection = restart_pin.connection ~= nil
    if has_restart_connection then
        -- Look up connected pin via State.pin_map
        local source_pin_info = State.pin_map[restart_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        local display_value = not not connected_value
        imgui.begin_disabled()
        imgui.checkbox("Restart", display_value)
        imgui.end_disabled()
    else
        local restart_changed, new_value = imgui.checkbox("Restart", node.restart_manual_value or false)
        if restart_changed then
            node.restart_manual_value = new_value
            State.mark_as_modified()
        end
    end
    imnodes.end_input_attribute()

    -- Manual delay input (no linking)
    imgui.spacing()
    local delay_changed, new_delay = imgui.input_text("Delay (ms):", tostring(node.delay_ms or 1000))
    if delay_changed then
        local num_delay = tonumber(new_delay)
        if num_delay and num_delay >= 0 then
            node.delay_ms = num_delay
            State.mark_as_modified()
        end
    end
    if imgui.is_item_hovered() then
        imgui.set_tooltip("Delay in milliseconds between counter increments.\nManual input only - cannot be linked to other nodes.")
    end

    -- Update output pin value
    output_pin.value = node.ending_value

    -- Output pin with tooltip
    imgui.spacing()
    imnodes.begin_output_attribute(output_pin.id)
    local display_value = Utils.get_value_display_string(node.ending_value)
    local output_display = display_value .. " (?)"
    local pos = Utils.get_right_cursor_pos(node.id, output_display)
    imgui.set_cursor_pos(pos)
    imgui.text(display_value)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() then
        local max_display = "10"
        if has_max_connection then
            local source_pin_info = State.pin_map[max_pin.connection.pin]
            local connected_value = source_pin_info and source_pin_info.pin.value
            max_display = tostring(connected_value or "10")
        else
            max_display = node.max_manual_value or "10"
        end
        
        local active_display = "false"
        if has_active_connection then
            local source_pin_info = State.pin_map[active_pin.connection.pin]
            local connected_value = source_pin_info and source_pin_info.pin.value
            active_display = tostring(connected_value)
        else
            active_display = tostring(node.active_manual_value or false)
        end
        
        local restart_display = "false"
        if has_restart_connection then
            local source_pin_info = State.pin_map[restart_pin.connection.pin]
            local connected_value = source_pin_info and source_pin_info.pin.value
            restart_display = tostring(connected_value)
        else
            restart_display = tostring(node.restart_manual_value or false)
        end
        
        local tooltip_text = string.format("Counter Control\nCurrent: %s\nMax: %s\nActive: %s\nRestart: %s\nDelay: %sms\nStatus: %s",
            tostring(node.current_count or 0), max_display, active_display, restart_display, tostring(node.delay_ms or 1000), tostring(node.status or "Ready"))
        imgui.set_tooltip(tooltip_text)
    end
    imnodes.end_output_attribute()

    imgui.spacing()
    if imgui.button("- Remove Node") then
        Nodes.remove_control_node(node)
    end

    imnodes.end_node()
end

return CounterControl