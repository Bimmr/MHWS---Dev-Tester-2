-- DevTester v2.0 - Counter Control
-- Control node that counts up to a maximum value and can be restarted

-- CounterControl Node Properties:
-- This node provides a counter that increments up to a maximum value.
-- The following properties define the state and configuration of a CounterControl node:
--
-- Input/Output Pins:
-- - max_attr: Number - Pin ID for the max count input attribute
-- - active_attr: Number - Pin ID for the active control input attribute
-- - restart_attr: Number - Pin ID for the restart trigger input attribute
-- - output_attr: Number - Pin ID for the output attribute (provides current count)
--
-- Input Connections:
-- - max_connection: NodeID - ID of the node connected to max input
-- - active_connection: NodeID - ID of the node connected to active input
-- - restart_connection: NodeID - ID of the node connected to restart input
--
-- Manual Input Values:
-- - max_manual_value: String - Manual text input for max count when not connected
-- - active_manual_value: String - Manual text input for active control when not connected
-- - restart_manual_value: String - Manual text input for restart trigger when not connected
-- - delay_ms: Number - Delay in milliseconds between increments (manual input only)
--
-- Runtime Values:
-- - ending_value: Number - The current count value
-- - current_count: Number - Internal counter state
-- - last_increment_time: Number - Timestamp of last increment for delay tracking
--
-- Runtime Values:
-- - ending_value: Number - The current count value
-- - current_count: Number - Internal counter state
-- - last_increment_time: Number - Timestamp of last increment for delay tracking
--
-- Inherits status property from BaseControl for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
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
    -- Get input values
    local max_value = Nodes.get_control_input_value(node, "max_attr")
    local active_value = Nodes.get_control_input_value(node, "active_attr")
    local restart_value = Nodes.get_control_input_value(node, "restart_attr")

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
    if max_value ~= nil then
        max_count = tonumber(max_value) or 10
    end

    -- Determine active state: use input if connected, otherwise use manual checkbox
    local is_active = node.active_manual_value -- default to manual value
    if active_value ~= nil then
        is_active = not not active_value -- input takes precedence
    end

    -- Determine restart state: use input if connected, otherwise use manual checkbox
    local should_restart = node.restart_manual_value -- default to manual value
    if restart_value ~= nil then
        should_restart = not not restart_value -- input takes precedence
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

    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Counter")
    imnodes.end_node_titlebar()

    -- Get input values for display
    local max_value = Nodes.get_control_input_value(node, "max_attr")
    local active_value = Nodes.get_control_input_value(node, "active_attr")
    local restart_value = Nodes.get_control_input_value(node, "restart_attr")

    -- Execute to update ending_value
    CounterControl.execute(node)

    -- Input pins
    BaseControl.render_input_pin(node, "Max Count", "max_attr", max_value, max_value, "text")
    BaseControl.render_input_pin(node, "Active", "active_attr", active_value, active_value, "checkbox")
    BaseControl.render_input_pin(node, "Restart", "restart_attr", restart_value, restart_value, "checkbox")

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

    -- Create tooltip for output
    local active_display = active_value ~= nil and tostring(active_value) or ("manual:" .. tostring(node.active_manual_value))
    local restart_display = restart_value ~= nil and tostring(restart_value) or ("manual:" .. tostring(node.restart_manual_value))
    local tooltip_text = string.format("Counter Control\nCurrent: %s\nMax: %s\nActive: %s\nRestart: %s\nDelay: %sms\nStatus: %s",
        tostring(node.current_count or 0), tostring(max_value or 10), active_display, restart_display, tostring(node.delay_ms or 1000), tostring(node.status or "Ready"))

    BaseControl.render_output_attribute(node, tostring(node.ending_value or 0), tooltip_text)

    BaseControl.render_action_buttons(node)
    BaseControl.render_debug_info(node)

    imnodes.end_node()
end

return CounterControl