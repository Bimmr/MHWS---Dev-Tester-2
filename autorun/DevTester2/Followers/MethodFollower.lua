-- MethodFollower Node Properties:
-- This node calls methods on parent objects with optional parameters.
--
-- Pins:
-- - pins.inputs[1]: "parent" - Connection to parent object
-- - pins.inputs[2+]: "param_N" - Dynamic parameter inputs based on method signature
-- - pins.outputs[1]: "output" - The method return value
--
-- Method Selection:
-- - selected_method_combo: Number - Index in the method selection dropdown (1-based)
-- - method_group_index: Number - Group index for organizing overloaded methods
-- - method_index: Number - Index of the selected method within its overload group
--
-- Parameters:
-- - param_manual_values: Array - Manual text input values for method parameters (indexed by parameter position)
--
-- Runtime Values:
-- - ending_value: Any - The return value from the method call (nil for void methods)
--
-- Inherits all BaseFollower properties (type, action_type, status, last_call_time, etc.)

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseFollower = require("DevTester2.Followers.BaseFollower")
local BaseStarter = require("DevTester2.Starters.BaseStarter")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local HybridCombo = require("DevTester2.HybridCombo")
local MethodFollower = {}

-- ========================================
-- Method Follower Node
-- ========================================

-- Helper to get method info safely
local function get_method_info(parent_type, group_index, method_index, is_static_context)
    if not group_index or not method_index then return nil, nil, false end
    
    local method = Nodes.get_method_by_group_and_index(parent_type, group_index, method_index, is_static_context)
    if not method then return nil, nil, false end

    local success, return_type = pcall(function() return method:get_return_type() end)
    local returns_void = false
    
    if success and return_type then
        local type_name = return_type:get_name()
        returns_void = (type_name == "Void" or type_name == "System.Void")
    end

    return method, return_type, returns_void
end

function MethodFollower.render(node)
    -- Ensure parent input and output pins exist
    if #node.pins.inputs == 0 then
        Nodes.add_input_pin(node, "parent", nil)
    end
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    local parent_value = BaseFollower.check_parent_connection(node)
    if not parent_value then 
        node.status = "Waiting for parent connection"
        return 
    end

    local parent_type = BaseFollower.get_parent_type(parent_value)
    if parent_type then
        Nodes.add_context_menu_option(node, "Copy parent type", parent_type:get_full_name())
    end

    -- Determine if we're working with static methods (type definition) or instance methods (managed object)
    local is_static_context = BaseFollower.is_parent_type_definition(parent_value)

    imnodes.begin_node(node.id)

    BaseFollower.render_title_bar(node, parent_type)

    BaseFollower.render_operation_dropdown(node, parent_value)

    -- Type dropdown (Run/Call)
    BaseFollower.render_action_type_dropdown(node, {"Run", "Call"})
    
    local can_continue = false

    -- Get selected method info early
    local selected_method, return_type, returns_void = get_method_info(
        parent_type, 
        node.method_group_index, 
        node.method_index, 
        is_static_context
    )

    -- Method selection
    if parent_type then
        local methods = Nodes.get_methods_for_combo(parent_type, is_static_context)
        if #methods > 0 then
            -- Initialize to 1 if not set (imgui.combo is 1-based)
            if not node.selected_method_combo then
                node.selected_method_combo = 1
            end

            -- Resolve signature if present
            if node.selected_method_signature then
                local group, idx = Nodes.find_method_indices_by_signature(parent_type, node.selected_method_signature, is_static_context)
                if group and idx then
                    node.method_group_index = group
                    node.method_index = idx
                    -- Update combo index to match
                    local combo_idx = Nodes.get_combo_index_for_method(parent_type, group, idx, is_static_context)
                    if combo_idx > 0 then
                        node.selected_method_combo = combo_idx + 1 -- 1-based for combo
                    end
                    -- Clear signature after successful resolution
                    node.selected_method_signature = nil
                    
                    -- Refresh method info after resolution
                    selected_method, return_type, returns_void = get_method_info(
                        parent_type, 
                        node.method_group_index, 
                        node.method_index, 
                        is_static_context
                    )
                end
            end

            local has_children = Nodes.has_children(node)
            if has_children then
                imgui.begin_disabled()
            end
            
            local method_changed, new_combo_index = Utils.hybrid_combo("Methods",
                node.selected_method_combo, methods)
                
            if method_changed then
                node.selected_method_combo = new_combo_index

                -- Parse the group_index and method_index from the selected string
                if new_combo_index > 1 then
                    local combo_method = methods[new_combo_index]
                    local group_index, method_index = combo_method:match("(%d+)%-(%d+)")
                    if group_index and method_index then
                        node.method_group_index = tonumber(group_index)
                        node.method_index = tonumber(method_index)
                        
                        -- Update signature for persistence
                        local method = Nodes.get_method_by_group_and_index(parent_type, node.method_group_index, node.method_index, is_static_context)
                        if method then
                            node.selected_method_signature = Nodes.get_method_signature(method)
                        end
                    else
                        -- Selected a separator, not an actual method
                        node.method_group_index = nil
                        node.method_index = nil
                        node.selected_method_signature = nil
                    end
                else
                    node.method_group_index = nil
                    node.method_index = nil
                end

                node.param_manual_values = {} -- Reset params
                node.last_call_time = nil -- Reset Last Call timer when method changes

                -- Remove all parameter input pins (start from index 2, after parent)
                while #node.pins.inputs > 1 do
                    table.remove(node.pins.inputs, 2)
                end

                -- Refresh method info for the new selection
                selected_method, return_type, returns_void = get_method_info(
                    parent_type, 
                    node.method_group_index, 
                    node.method_index, 
                    is_static_context
                )

                -- Check if selected method returns void, if so switch to Call mode
                if selected_method and returns_void then
                    node.action_type = Constants.ACTION_SET -- Switch to Call mode
                end

                -- Add parameter input pins based on method signature
                if selected_method then
                    local success_param, param_types = pcall(function()
                        return selected_method:get_param_types()
                    end)
                    if success_param and param_types then
                        for i = 1, #param_types do
                            Nodes.add_input_pin(node, "param_" .. (i-1), nil)
                        end
                    end
                end

                State.mark_as_modified()
            end
            
            if has_children then
                imgui.end_disabled()
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Cannot change method while node has children")
                end
            end
            
            -- Handle parameters (show for both Run and Call)
            if selected_method then
                local success_param, param_types = pcall(function() 
                    return selected_method:get_param_types() 
                end)
                Nodes.add_context_menu_option(node, "Copy method name", Nodes.get_method_signature(selected_method, true))
                
                if success_param and param_types and #param_types > 0 then
                    -- Ensure correct number of parameter input pins exist
                    for i = 1, #param_types do
                        local pin_index = i + 1 -- Index 1 is parent
                        local pin_name = "param_" .. (i - 1)
                        
                        if pin_index > #node.pins.inputs then
                            Nodes.add_input_pin(node, pin_name, nil)
                        elseif node.pins.inputs[pin_index].name ~= pin_name then
                            -- Pin mismatch (likely trigger pin is in the way), insert correct pin
                            local new_pin = Nodes.add_input_pin(node, pin_name, nil)
                            -- Move it to correct position
                            table.remove(node.pins.inputs, #node.pins.inputs)
                            table.insert(node.pins.inputs, pin_index, new_pin)
                        end
                    end
                    
                    imgui.spacing()
                    
                    if not node.param_manual_values then
                        node.param_manual_values = {}
                    end
                    
                    for i, param_type in ipairs(param_types) do
                        Nodes.add_context_menu_option(node, "Copy param type " .. i, param_type:get_full_name())

                        -- Get parameter input pin (starts at index 2, after parent)
                        local param_pin = node.pins.inputs[i + 1]
                        
                        -- Parameter input pin
                        imnodes.begin_input_attribute(param_pin.id)
                        local has_connection = param_pin.connection ~= nil
                        local label = string.format("Param %d(%s)", i, param_type:get_name())
                        if has_connection then
                            -- Look up connected pin via State.pin_map
                            local source_pin_info = State.pin_map[param_pin.connection.pin]
                            local connected_value = source_pin_info and source_pin_info.pin.value
                            -- Display simplified value without address
                            local display_value = Utils.get_value_display_string(connected_value)
                            imgui.begin_disabled()
                            imgui.input_text(label, display_value)
                            imgui.end_disabled()
                            if imgui.is_item_hovered() then
                                imgui.set_tooltip(param_type:get_full_name() .. "\n" .. Utils.get_tooltip_for_value(connected_value))
                            end
                        else
                            node.param_manual_values[i] = node.param_manual_values[i] or ""
                            local input_changed, new_value = imgui.input_text(label, node.param_manual_values[i])
                            if input_changed then
                                node.param_manual_values[i] = new_value
                                State.mark_as_modified()
                            end
                            if imgui.is_item_hovered() then
                                imgui.set_tooltip(param_type:get_full_name())
                            end
                        end
                        imnodes.end_input_attribute()
                    end
                end
            end

            -- Manage Trigger Pin for Call mode
            local trigger_pin_name = "call_trigger"
            local trigger_pin = nil
            local trigger_pin_index = nil
            
            for i, pin in ipairs(node.pins.inputs) do
                if pin.name == trigger_pin_name then
                    trigger_pin = pin
                    trigger_pin_index = i
                    break
                end
            end

            if node.action_type == 1 then -- Call mode
                if not trigger_pin then
                    Nodes.add_input_pin(node, trigger_pin_name, nil)
                    trigger_pin = node.pins.inputs[#node.pins.inputs]
                else
                    -- Ensure it is at the end
                    if trigger_pin_index ~= #node.pins.inputs then
                        table.remove(node.pins.inputs, trigger_pin_index)
                        table.insert(node.pins.inputs, trigger_pin)
                    end
                end
            else -- Run mode
                if trigger_pin then
                    table.remove(node.pins.inputs, trigger_pin_index)
                    trigger_pin = nil
                    State.mark_as_modified()
                end
            end

            imgui.spacing()
            
            -- Execute and show output
            local result = nil
            
            Nodes.add_context_menu_option(node, "Copy output type", return_type and return_type:get_full_name() or "Unknown")
            
            if node.action_type == 0 then -- Run - auto execute
                result = MethodFollower.execute(node, parent_value, selected_method)
            elseif node.action_type == 1 then -- Call - manual button
                -- Check trigger pin status
                local triggered_by_pin = false
                if trigger_pin and trigger_pin.connection then
                    local source = State.pin_map[trigger_pin.connection.pin]
                    if source and source.pin.value == true then
                        triggered_by_pin = true
                    end
                end

                -- Render Call Method button with trigger pin
                if trigger_pin then
                    imnodes.begin_input_attribute(trigger_pin.id)
                end
                
                local button_disabled = triggered_by_pin or (trigger_pin and trigger_pin.connection ~= nil)
                if button_disabled then
                    imgui.begin_disabled()
                end

                local button_clicked = imgui.button("Call Method")
                
                if button_disabled then
                    imgui.end_disabled()
                    if imgui.is_item_hovered() then
                        if triggered_by_pin then
                            imgui.set_tooltip("Triggered by input pin")
                        else
                            imgui.set_tooltip("Disabled: Trigger pin connected")
                        end
                    end
                end

                if trigger_pin then
                    imnodes.end_input_attribute()
                end

                if button_clicked or triggered_by_pin then
                    result = MethodFollower.execute(node, parent_value, selected_method)
                    node.last_call_time = os.clock()  -- Record call time with high precision
                else
                    -- Keep previous result if button not clicked
                    result = node.ending_value
                end
            end
            
            -- Always store result, even if nil
            node.ending_value = result
            if result and return_type then
                node.ending_value_full_name = return_type:get_full_name()
            end
            
            if not returns_void then
                can_continue, result = Nodes.validate_continuation(result, parent_value, node.ending_value_full_name)
                node.ending_value = result
            end
            
            -- Update output pin value
            node.pins.outputs[1].value = result
            
            -- Render output pin
            local output_pin = node.pins.outputs[1]
            imgui.spacing()
            imnodes.begin_output_attribute(output_pin.id)
            
            if result ~= nil and not returns_void then
                -- Display the actual result
                local display_value = Utils.get_value_display_string(result)
                local output_display = display_value .. " (?)"
                local pos = Utils.get_right_cursor_pos(node.id, output_display)
                imgui.set_cursor_pos(pos)
                imgui.text(display_value)
                imgui.same_line()
                imgui.text("(?)")
                if imgui.is_item_hovered() then
                    imgui.set_tooltip(Utils.get_tooltip_for_value(result))
                end
                
                Nodes.add_context_menu_option(node, "Copy output value", tostring(result))
            elseif returns_void then
                -- For void methods, show execution status
                if node.action_type == 0 then -- Run mode - always executing
                    local executing_text = "Executing"
                    local pos = Utils.get_right_cursor_pos(node.id, executing_text)
                    imgui.set_cursor_pos(pos)
                    imgui.text(executing_text)
                    if imgui.is_item_hovered() then
                        -- Show tooltip with method info
                        local method_name = selected_method:get_name()
                        local return_type_name = "void"
                        local tooltip_text = string.format(
                            "Method: %s\nReturn Type: %s\nStatus: Executing (Run mode)",
                            method_name, return_type_name
                        )
                        imgui.set_tooltip(tooltip_text)
                    end
                elseif node.last_call_time then
                    local elapsed = os.clock() - node.last_call_time
                    local time_since_call
                    if elapsed < 1 then
                        time_since_call = string.format("%.0fms ago", elapsed * 1000)
                    else
                        time_since_call = string.format("%.1fs ago", elapsed)
                    end
                    local executed_text = "Executed | Last call: " .. time_since_call
                    local pos = Utils.get_right_cursor_pos(node.id, executed_text)
                    imgui.set_cursor_pos(pos)
                    imgui.text(executed_text)
                    if imgui.is_item_hovered() then
                        -- Show tooltip with method info
                        local method_name = selected_method:get_name()
                        local return_type_name = "void"
                        local tooltip_text = string.format(
                            "Method: %s\nReturn Type: %s\nStatus: Executed successfully",
                            method_name, return_type_name
                        )
                        imgui.set_tooltip(tooltip_text)
                    end
                else
                    -- Show ready status for void methods that haven't been called
                    local ready_text = "Ready"
                    local pos = Utils.get_right_cursor_pos(node.id, ready_text)
                    imgui.set_cursor_pos(pos)
                    imgui.text(ready_text)
                end
            else
                -- Show nil state
                local output_text = "nil"
                local pos = Utils.get_right_cursor_pos(node.id, output_text)
                imgui.set_cursor_pos(pos)
                imgui.text(output_text)
            end
            
            Nodes.add_context_menu_seperator(node)
            Nodes.add_context_menu_option(node, "Create Hook Starter for method", function()
                    local hook = BaseStarter.create(Constants.STARTER_TYPE_HOOK)
                    hook.path = parent_type:get_full_name()
                    hook.method_group_index = node.method_group_index
                    hook.method_index = node.method_index
                    hook.method_name = selected_method:get_name()
                end)

            imnodes.end_output_attribute()
        else
            imgui.text("No methods available")
        end
    else
        if node.selected_method_signature then
             imgui.text("Signature: " .. node.selected_method_signature)
        else
             imgui.text("Connect parent to select method")
        end
    end

    -- Action buttons
    BaseFollower.render_action_buttons(node)

    -- Debug info
    BaseFollower.render_debug_info(node)

    imnodes.end_node()
end

function MethodFollower.execute(node, parent_value, selected_method)
    if not selected_method then
        return nil
    end

    -- Resolve parameters
    local params = MethodFollower.resolve_method_parameters(node, selected_method)
    
    -- Determine if we're calling a static method
    local is_static_context = BaseFollower.is_parent_type_definition(parent_value)
    
    -- Execute method based on type and context
    local success, result
    if is_static_context then
        -- Static method call - call on the type definition
        success, result = pcall(function()
            return selected_method:call(nil, table.unpack(params))
        end)
    elseif node.action_type == 0 then -- Run (instance method)
        success, result = pcall(function()
            return selected_method:call(parent_value, table.unpack(params))
        end)
    else -- Call (instance method)
        success, result = pcall(function()
            return parent_value:call(selected_method:get_name(), table.unpack(params))
        end)
    end

    if not success then
        node.status = "Error: " .. tostring(result)
        return nil
    else
        -- Set success status based on operation type and context
        local operation = is_static_context and "Static " or "Instance "
        if node.action_type == 0 then
            operation = operation .. "Run"
        else
            operation = operation .. "Call"
        end
        
        local method_name = selected_method:get_name()
        local return_type = selected_method:get_return_type()
        local is_void = return_type and return_type:get_name() == "System.Void"
        
        if is_void then
            node.status = operation .. ": " .. method_name .. " (void)"
        else
            node.status = operation .. ": " .. method_name
        end
        
        return result
    end
end

function MethodFollower.resolve_method_parameters(node, selected_method)
    local params = {}

    -- Get method param types
    local success, param_types = pcall(function() return selected_method:get_param_types() end)
    if not success or not param_types then
        return params
    end

    for i, param_type in ipairs(param_types) do
        -- Parameter pins start at index 2 (after parent pin at index 1)
        local param_pin = node.pins.inputs[i + 1]
        
        if param_pin and param_pin.connection then
            -- Use connected value from pin system - look up via State.pin_map
            local source_pin_info = State.pin_map[param_pin.connection.pin]
            if source_pin_info then
                table.insert(params, source_pin_info.pin.value)
            end
        else
            -- Use manual input
            local manual_value = node.param_manual_values[i] or ""
            if manual_value ~= "" then
                -- Try to parse the value
                local parsed_value = Utils.parse_value_for_type(manual_value, param_type)
                table.insert(params, parsed_value)
            else
                -- Use nil as default
                table.insert(params, nil)
            end
        end
    end

    return params
end

return MethodFollower

