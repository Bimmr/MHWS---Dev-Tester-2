-- DevTester v2.0 - Condition Control
-- Simple condition-based value selector (if-then-else logic)

local State = require("DevTester2.State")
local Constants = require("DevTester2.Constants")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local BaseControl = require("DevTester2.Control.BaseControl")

local imgui = imgui
local imnodes = imnodes

local ConditionControl = {}

-- ========================================
-- Rendering
-- ========================================

function ConditionControl.render(node)
    Nodes.ensure_node_pin_ids(node)
    
    -- Ensure we have the required pins
    if #node.pins.inputs < 3 then
        -- Need 3 input pins: condition, true_value, false_value
        while #node.pins.inputs < 3 do
            if #node.pins.inputs == 0 then
                Nodes.add_input_pin(node, "Condition", nil)
            elseif #node.pins.inputs == 1 then
                Nodes.add_input_pin(node, "True Value", nil)
            elseif #node.pins.inputs == 2 then
                Nodes.add_input_pin(node, "False Value", nil)
            end
        end
    end
    
    -- Ensure we have an output pin
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "Output", nil)
    end
    
    local condition_pin = node.pins.inputs[1]
    local true_value_pin = node.pins.inputs[2]
    local false_value_pin = node.pins.inputs[3]
    local output_pin = node.pins.outputs[1]
    
    -- Get connected values or manual inputs
    local condition_value = nil
    local true_value = nil
    local false_value = nil
    
    -- Get condition value
    if condition_pin.connection then
        local source_pin_info = State.pin_map[condition_pin.connection.pin]
        if source_pin_info and source_pin_info.pin then
            condition_value = source_pin_info.pin.value
        end
    else
        -- Manual input for condition
        condition_value = condition_pin.value
    end
    
    -- Get true value
    if true_value_pin.connection then
        local source_pin_info = State.pin_map[true_value_pin.connection.pin]
        if source_pin_info and source_pin_info.pin then
            true_value = source_pin_info.pin.value
        end
    else
        -- Manual input for true value
        true_value = true_value_pin.value
    end
    
    -- Get false value
    if false_value_pin.connection then
        local source_pin_info = State.pin_map[false_value_pin.connection.pin]
        if source_pin_info and source_pin_info.pin then
            false_value = false_value_pin.pin.value
        end
    else
        -- Manual input for false value
        false_value = false_value_pin.value
    end
    
    -- Execute the condition logic
    local result = nil
    local status = "Waiting"
    
    if condition_value ~= nil then
        -- Evaluate condition (truthy values)
        local is_true = false
        if type(condition_value) == "boolean" then
            is_true = condition_value
        elseif type(condition_value) == "number" then
            is_true = condition_value ~= 0
        elseif type(condition_value) == "string" then
            is_true = condition_value ~= "" and condition_value ~= "false" and condition_value ~= "0"
        else
            is_true = condition_value ~= nil
        end
        
        result = is_true and true_value or false_value
        status = is_true and "Condition: True" or "Condition: False"
    end
    
    -- Update output pin and node values
    output_pin.value = result
    node.ending_value = result
    node.status = status
    
    -- Start rendering
    imnodes.begin_node(node.id)
    
    -- Title bar
    imnodes.begin_node_titlebar()
    imgui.text("Condition")
    imnodes.end_node_titlebar()
    
    -- Condition Input
    imnodes.begin_input_attribute(condition_pin.id)
    imgui.text("Condition:")
    imnodes.end_input_attribute()
    
    if not condition_pin.connection then
        imgui.same_line()
        imgui.push_item_width(100)
        local current = condition_pin.value
        if current == nil then current = "" end
        if type(current) ~= "string" then current = tostring(current) end
        local changed, new_value = imgui.input_text("##condition_manual", current)
        if changed then
            condition_pin.value = Utils.parse_primitive_value(new_value)
            State.mark_as_modified()
        end
        imgui.pop_item_width()
    else
        imgui.same_line()
        local source_pin_info = State.pin_map[condition_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        imgui.begin_disabled()
        imgui.input_text("##condition_display", tostring(connected_value or ""))
        imgui.end_disabled()
    end
    
    imgui.spacing()
    
    -- True Value Input
    imnodes.begin_input_attribute(true_value_pin.id)
    imgui.text("True:")
    imnodes.end_input_attribute()
    
    if not true_value_pin.connection then
        imgui.same_line()
        local current = true_value_pin.value
        if current == nil then current = "" end
        if type(current) ~= "string" then current = tostring(current) end
        local changed, new_value = imgui.input_text("##true_manual", current)
        if changed then
            true_value_pin.value = Utils.parse_primitive_value(new_value)
            State.mark_as_modified()
        end
    else
        imgui.same_line()
        local source_pin_info = State.pin_map[true_value_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        imgui.begin_disabled()
        imgui.input_text("##true_display", tostring(connected_value or ""))
        imgui.end_disabled()
    end
    
    -- False Value Input
    imnodes.begin_input_attribute(false_value_pin.id)
    imgui.text("False:")
    imnodes.end_input_attribute()
    
    if not false_value_pin.connection then
        imgui.same_line()
        local current = false_value_pin.value
        if current == nil then current = "" end
        if type(current) ~= "string" then current = tostring(current) end
        local changed, new_value = imgui.input_text("##false_manual", current)
        if changed then
            false_value_pin.value = Utils.parse_primitive_value(new_value)
            State.mark_as_modified()
        end
    else
        imgui.same_line()
        local source_pin_info = State.pin_map[false_value_pin.connection.pin]
        local connected_value = source_pin_info and source_pin_info.pin.value
        imgui.begin_disabled()
        imgui.input_text("##false_display", tostring(connected_value or ""))
        imgui.end_disabled()
    end
    
    imgui.spacing()
    imgui.spacing()
    
    -- Create tooltip
    local tooltip_text = string.format("Condition Control\n%s\nResult: %s",
        node.status or "Ready", tostring(node.ending_value))
    
    -- Output
    imnodes.begin_output_attribute(output_pin.id)
    local display = node.ending_value ~= nil and tostring(node.ending_value) or "nil"
    local debug_pos = Utils.get_right_cursor_pos(node.id, display .. " (?)")
    imgui.set_cursor_pos(debug_pos)
    imgui.text(display)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() and tooltip_text then
        imgui.set_tooltip(tooltip_text)
    end
    imnodes.end_output_attribute()
    
    imgui.spacing()
    
    -- Remove button
    if imgui.button("- Remove Node") then
        Nodes.remove_node(node)
    end
    
    imnodes.end_node()
end

-- ========================================
-- Execution
-- ========================================

function ConditionControl.execute(node)
    -- Execution happens during rendering for real-time updates
    return node.ending_value
end

-- ========================================
-- Creation
-- ========================================

function ConditionControl.create(position)
    local node_id = State.next_node_id()
    local node = {
        id = node_id,
        category = Constants.NODE_CATEGORY_CONTROL,
        type = Constants.CONTROL_TYPE_CONDITION,
        position = position or {x = 0, y = 0},
        pins = { inputs = {}, outputs = {} },
        -- Runtime values
        ending_value = nil,
        status = nil
    }
    
    -- Create pins
    Nodes.add_input_pin(node, "Condition", nil)
    Nodes.add_input_pin(node, "True Value", nil)
    Nodes.add_input_pin(node, "False Value", nil)
    Nodes.add_output_pin(node, "Output", nil)
    
    table.insert(State.all_nodes, node)
    State.node_map[node.id] = node
    State.mark_as_modified()
    
    return node
end

return ConditionControl
