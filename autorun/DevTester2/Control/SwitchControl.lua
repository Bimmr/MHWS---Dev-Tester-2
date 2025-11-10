-- DevTester v2.0 - Switch Control
-- Control node that works like a switch statement, comparing an input against multiple cases

-- SwitchControl Node Properties (Switch):
-- This node compares an input value against multiple case values and returns
-- the value associated with the first matching case, or the else value.
--
-- Properties:
-- - num_conditions: Number - Count of case/value pairs
--
-- Pin Structure:
-- - pins.inputs[1]: "switch_input" - Value to switch on
-- - pins.inputs[N]: "case_0" through "case_N-1" - Values to compare against
-- - pins.inputs[N+1]: "value_0" through "value_N-1" - Values to return if case matches
-- - pins.inputs[last]: "else" - Fallback value if no cases match
-- - pins.outputs[1]: "output" - The selected value
--
-- Runtime Values:
-- - ending_value: Any - The selected value

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseControl = require("DevTester2.Control.BaseControl")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local SwitchControl = {}

-- ========================================
-- Helper Functions
-- ========================================

function SwitchControl.add_condition(node)
    local index = node.num_conditions
    
    -- Create case pin
    Nodes.add_input_pin(node, "case_" .. index, nil)
    
    -- Create value pin - insert before else pin
    -- Find else pin index
    local else_index = nil
    for i, pin in ipairs(node.pins.inputs) do
        if pin.name == "else" then
            else_index = i
            break
        end
    end
    
    -- Insert value pin before else
    if else_index then
        local value_pin = Nodes.create_pin("value_" .. index, nil)
        value_pin.connection = nil
        table.insert(node.pins.inputs, else_index, value_pin)
        State.pin_map[value_pin.id] = { node_id = node.id, pin = value_pin }
    else
        -- Fallback: append to end
        Nodes.add_input_pin(node, "value_" .. index, nil)
    end
    
    node.num_conditions = node.num_conditions + 1
    State.mark_as_modified()
end

function SwitchControl.remove_condition(node, index)
    if node.num_conditions <= 1 then
        return -- Don't allow removing the last condition
    end
    
    local case_name = "case_" .. index
    local value_name = "value_" .. index
    
    -- Remove from pins array and disconnect
    for i = #node.pins.inputs, 1, -1 do
        local pin = node.pins.inputs[i]
        if pin.name == case_name or pin.name == value_name then
            -- Disconnect any links
            if pin.connection then
                -- Find and remove the link
                for j = #State.all_links, 1, -1 do
                    local link = State.all_links[j]
                    if link.to_pin == pin.id then
                        Nodes.handle_link_destroyed(link.id)
                        break
                    end
                end
            end
            
            -- Remove from pin_map
            State.pin_map[pin.id] = nil
            
            -- Remove from array
            table.remove(node.pins.inputs, i)
        end
    end
    
    node.num_conditions = node.num_conditions - 1
    State.mark_as_modified()
end

-- ========================================
-- Execute Function
-- ========================================

function SwitchControl.execute(node)
    -- Initialize num_conditions if not set
    if not node.num_conditions then
        node.num_conditions = 1
    end
    
    -- Get switch input value (first pin)
    local switch_pin = nil
    for _, pin in ipairs(node.pins.inputs) do
        if pin.name == "switch_input" then
            switch_pin = pin
            break
        end
    end
    
    local switch_value = nil
    if switch_pin then
        local switch_index = nil
        for idx, pin in ipairs(node.pins.inputs) do
            if pin.id == switch_pin.id then
                switch_index = idx
                break
            end
        end
        if switch_index then
            switch_value = Nodes.get_input_pin_value(node, switch_index)
        end
    end
    
    -- Evaluate cases in order
    for i = 0, node.num_conditions - 1 do
        -- Find case and value pins by name
        local case_pin = nil
        local value_pin = nil
        
        for _, pin in ipairs(node.pins.inputs) do
            if pin.name == "case_" .. i then
                case_pin = pin
            elseif pin.name == "value_" .. i then
                value_pin = pin
            end
        end
        
        if case_pin and value_pin then
            -- Get case value
            local case_index = nil
            for idx, pin in ipairs(node.pins.inputs) do
                if pin.id == case_pin.id then
                    case_index = idx
                    break
                end
            end
            
            local case_value = nil
            if case_index then
                case_value = Nodes.get_input_pin_value(node, case_index)
            end
            
            -- Compare switch_value with case_value
            local matches = false
            if switch_value == case_value then
                matches = true
            elseif type(switch_value) == "string" and type(case_value) == "string" then
                matches = switch_value == case_value
            elseif type(switch_value) == "number" and type(case_value) == "string" then
                matches = tostring(switch_value) == case_value
            elseif type(switch_value) == "string" and type(case_value) == "number" then
                matches = switch_value == tostring(case_value)
            end
            
            if matches then
                -- Get value
                local value_index = nil
                for idx, pin in ipairs(node.pins.inputs) do
                    if pin.id == value_pin.id then
                        value_index = idx
                        break
                    end
                end
                
                local selected_value = nil
                if value_index then
                    selected_value = Nodes.get_input_pin_value(node, value_index)
                end
                
                node.ending_value = selected_value
                node.status = "Matched case " .. i
                return selected_value
            end
        end
    end
    
    -- No cases matched, use else value
    local else_pin = nil
    local else_index = nil
    for idx, pin in ipairs(node.pins.inputs) do
        if pin.name == "else" then
            else_pin = pin
            else_index = idx
            break
        end
    end
    
    if else_pin and else_index then
        local else_value = Nodes.get_input_pin_value(node, else_index)
        node.ending_value = else_value
        node.status = "No cases matched, using else"
        return else_value
    end
    
    -- Fallback
    node.status = "No match and no else value"
    node.ending_value = nil
    return nil
end

-- ========================================
-- Render Function
-- ========================================

function SwitchControl.render(node)
    -- Initialize defaults for enhanced node
    if not node.num_conditions then
        node.num_conditions = 1
    end
    
    -- Migrate legacy nodes (has condition/true_value/false_value pins)
    local needs_migration = false
    if #node.pins.inputs > 0 then
        for _, pin in ipairs(node.pins.inputs) do
            if pin.name == "condition" or pin.name == "true_value" or pin.name == "false_value" then
                needs_migration = true
                break
            end
        end
    end
    
    if needs_migration then
        -- Migrate legacy structure
        local old_pins = {}
        for _, pin in ipairs(node.pins.inputs) do
            old_pins[pin.name] = pin
        end
        
        node.pins.inputs = {}
        
        -- Add switch_input pin at the beginning
        Nodes.add_input_pin(node, "switch_input", nil)
        
        -- Rename condition to case_0
        if old_pins["condition"] then
            old_pins["condition"].name = "case_0"
            table.insert(node.pins.inputs, old_pins["condition"])
        end
        
        -- Rename true_value to value_0
        if old_pins["true_value"] then
            old_pins["true_value"].name = "value_0"
            table.insert(node.pins.inputs, old_pins["true_value"])
        end
        
        -- Rename false_value to else
        if old_pins["false_value"] then
            old_pins["false_value"].name = "else"
            table.insert(node.pins.inputs, old_pins["false_value"])
        end
        
        node.num_conditions = 1
    end
    
    -- Migrate nodes with old condition_N naming to case_N
    local needs_case_migration = false
    for _, pin in ipairs(node.pins.inputs) do
        if pin.name and pin.name:match("^condition_%d+$") then
            needs_case_migration = true
            break
        end
    end
    
    if needs_case_migration then
        for _, pin in ipairs(node.pins.inputs) do
            local cond_num = pin.name and pin.name:match("^condition_(%d+)$")
            if cond_num then
                pin.name = "case_" .. cond_num
            end
        end
    end
    
    -- Ensure minimum pins exist
    local has_switch_input = false
    local has_case_0 = false
    local has_value_0 = false
    local has_else = false
    
    for _, pin in ipairs(node.pins.inputs) do
        if pin.name == "switch_input" then has_switch_input = true end
        if pin.name == "case_0" then has_case_0 = true end
        if pin.name == "case_0" then has_case_0 = true end
        if pin.name == "value_0" then has_value_0 = true end
        if pin.name == "else" then has_else = true end
    end
    
    if not has_switch_input then
        -- Insert switch_input at the beginning
        local switch_pin = Nodes.create_pin("switch_input", nil)
        switch_pin.connection = nil
        table.insert(node.pins.inputs, 1, switch_pin)
        State.pin_map[switch_pin.id] = { node_id = node.id, pin = switch_pin }
    end
    if not has_case_0 then
        Nodes.add_input_pin(node, "case_0", nil)
    end
    if not has_value_0 then
        Nodes.add_input_pin(node, "value_0", nil)
    end
    if not has_else then
        Nodes.add_input_pin(node, "else", nil)
    end
    
    -- Ensure output pin exists
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    local output_pin = node.pins.outputs[1]
    
    imnodes.begin_node(node.id)
    
    imnodes.begin_node_titlebar()
    imgui.text("Switch")
    imnodes.end_node_titlebar()
    
    -- Switch Input
    local switch_pin = nil
    for _, pin in ipairs(node.pins.inputs) do
        if pin.name == "switch_input" then
            switch_pin = pin
            break
        end
    end
    
    if switch_pin then
        imnodes.begin_input_attribute(switch_pin.id)
        imgui.text("Value")
        imnodes.end_input_attribute()
        imgui.same_line()
        
        if not switch_pin.connection then
            local current = switch_pin.value
            if current == nil then current = "" end
            if type(current) ~= "string" then current = tostring(current) end
            local changed, new_val = imgui.input_text("##switch_input", current)
            if changed then
                switch_pin.value = Utils.parse_primitive_value(new_val)
                State.mark_as_modified()
            end
        else
            -- Look up connected pin via State.pin_map
            local source_pin_info = State.pin_map[switch_pin.connection.pin]
            local connected_value = source_pin_info and source_pin_info.pin.value
            imgui.begin_disabled()
            imgui.input_text("##switch_input", tostring(connected_value or ""))
            imgui.end_disabled()
        end
    end
    
    
    -- Render case/value pairs
    for i = 0, node.num_conditions - 1 do
        local case_pin = nil
        local value_pin = nil
        
        for _, pin in ipairs(node.pins.inputs) do
            if pin.name == "case_" .. i then
                case_pin = pin
            elseif pin.name == "value_" .. i then
                value_pin = pin
            end
        end
        
        if case_pin and value_pin then
            imgui.spacing()
            
            -- Case pin
            imnodes.begin_input_attribute(case_pin.id)
            imgui.text("Case " .. i .. ":")
            imnodes.end_input_attribute()
            imgui.same_line()
            
            if not case_pin.connection then
                local current = case_pin.value
                if current == nil then current = "" end
                if type(current) ~= "string" then current = tostring(current) end
                local changed, new_val = imgui.input_text("##case_" .. i, current)
                if changed then
                    case_pin.value = Utils.parse_primitive_value(new_val)
                    State.mark_as_modified()
                end
            else
                -- Look up connected pin via State.pin_map
                local source_pin_info = State.pin_map[case_pin.connection.pin]
                local connected_value = source_pin_info and source_pin_info.pin.value
                imgui.begin_disabled()
                imgui.input_text("##case_" .. i, tostring(connected_value or ""))
                imgui.end_disabled()
            end

            -- Remove button (only if more than 1 condition)
            if node.num_conditions > 1 then
                imgui.same_line()
                if imgui.button("X##remove_" .. i) then
                    SwitchControl.remove_condition(node, i)
                end
            end
            
            -- Value pin
            imnodes.begin_input_attribute(value_pin.id)
            imgui.text("Value " .. i .. ":")
            imnodes.end_input_attribute()
            imgui.same_line()
            
            if not value_pin.connection then
                local current = value_pin.value
                if current == nil then current = "" end
                if type(current) ~= "string" then current = tostring(current) end
                local changed, new_val = imgui.input_text("##val_" .. i, current)
                if changed then
                    value_pin.value = Utils.parse_primitive_value(new_val)
                    State.mark_as_modified()
                end
            else
                -- Look up connected pin via State.pin_map
                local source_pin_info = State.pin_map[value_pin.connection.pin]
                local connected_value = source_pin_info and source_pin_info.pin.value
                imgui.begin_disabled()
                imgui.input_text("##val_" .. i, tostring(connected_value or ""))
                imgui.end_disabled()
            end
            
            imgui.spacing()
        end
    end
    
    -- Add Case button
    imgui.spacing()
    if imgui.button("+ Add Case") then
        SwitchControl.add_condition(node)
    end
    
    imgui.spacing()
    imgui.spacing()
    
    -- Else pin (fallback value)
    local else_pin = nil
    for _, pin in ipairs(node.pins.inputs) do
        if pin.name == "else" then
            else_pin = pin
            break
        end
    end
    
    if else_pin then
        imnodes.begin_input_attribute(else_pin.id)
        imgui.text("Else")
        imnodes.end_input_attribute()
        imgui.same_line()
        
        if not else_pin.connection then
            local current = else_pin.value
            if current == nil then current = "" end
            if type(current) ~= "string" then current = tostring(current) end
            local changed, new_val = imgui.input_text("##else", current)
            if changed then
                else_pin.value = Utils.parse_primitive_value(new_val)
                State.mark_as_modified()
            end
        else
            -- Look up connected pin via State.pin_map
            local source_pin_info = State.pin_map[else_pin.connection.pin]
            local connected_value = source_pin_info and source_pin_info.pin.value
            imgui.begin_disabled()
            imgui.input_text("##else", tostring(connected_value or ""))
            imgui.end_disabled()
        end
    end
    
    -- Execute
    SwitchControl.execute(node)
    output_pin.value = node.ending_value
    
    -- Create tooltip
    local tooltip_text = string.format("Switch Control\n%s\nSelected: %s",
        node.status or "Ready", tostring(node.ending_value))
    
    -- Output pin
    imgui.spacing()
    imgui.spacing()
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
    
    BaseControl.render_action_buttons(node)
    BaseControl.render_debug_info(node)
    
    imnodes.end_node()
end

return SwitchControl
