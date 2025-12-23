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
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local HybridCombo = require("DevTester2.HybridCombo")
local MethodFollower = {}

-- ========================================
-- Method Follower Node
-- ========================================

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
    -- if not parent_type then
    --     Nodes.render_disconnected_operation_node(node, "type_error")
    --     return
    -- end

    -- Determine if we're working with static methods (type definition) or instance methods (managed object)
    local is_static_context = false
    if parent_value then
        is_static_context = BaseFollower.is_parent_type_definition(parent_value)
    end

    imnodes.begin_node(node.id)

    BaseFollower.render_title_bar(node, parent_type)

    BaseFollower.render_operation_dropdown(node, parent_value)

    -- Type dropdown (Run/Call)
    BaseFollower.render_action_type_dropdown(node, {"Run", "Call"})

    -- Method selection
    if parent_type then
        local methods = Nodes.get_methods_for_combo(parent_type, is_static_context)
        local returns_void = false  -- Declare at higher scope
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

            -- Check if selected method returns void, if so switch to Call mode
            if node.method_group_index and node.method_index then
                local current_method = Nodes.get_method_by_group_and_index(parent_type,
                    node.method_group_index, node.method_index, is_static_context)
                if current_method then
                    local success_return, return_type = pcall(function()
                        return current_method:get_return_type()
                    end)
                    if success_return and return_type then
                        local return_type_name = return_type:get_name()
                        if return_type_name == "Void" or return_type_name == "System.Void" then
                            node.action_type = Constants.ACTION_SET -- Switch to Call mode
                        end
                    end

                    -- Add parameter input pins based on method signature
                    local success_param, param_types = pcall(function()
                        return current_method:get_param_types()
                    end)
                    if success_param and param_types then
                        for i = 1, #param_types do
                            Nodes.add_input_pin(node, "param_" .. (i-1), nil)
                        end
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
        
        local selected_method = nil
        if node.method_group_index and node.method_index then
            selected_method = Nodes.get_method_by_group_and_index(parent_type, 
                node.method_group_index, node.method_index, is_static_context)
        end

        -- Handle parameters (show for both Run and Call)
        if selected_method then
            local success_param, param_types = pcall(function() 
                return selected_method:get_param_types() 
            end)
            Nodes.add_context_menu_option(node, "Copy method name", Nodes.get_method_signature(selected_method, true))
            
            if success_param and param_types and #param_types > 0 then
                -- Ensure correct number of parameter input pins exist
                local needed_pins = 1 + #param_types  -- parent + parameters
                while #node.pins.inputs < needed_pins do
                    local param_idx = #node.pins.inputs - 1 + 1  -- -1 for parent, +1 for 1-based
                    Nodes.add_input_pin(node, "param_" .. (param_idx - 1), nil)
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
                    local label = string.format("Arg %d(%s)", i, param_type:get_name())
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

        imgui.spacing()
        
        -- Execute and show output
        local result = nil
        
        -- Check if method returns void
        if selected_method then
            local success_return, return_type = pcall(function()
                return selected_method:get_return_type()
            end)
            if success_return and return_type then
                local return_type_name = return_type:get_name()
                returns_void = (return_type_name == "Void" or return_type_name == "System.Void")
            end
            Nodes.add_context_menu_option(node, "Copy output type", return_type and return_type:get_full_name() or "Unknown")
        end
        
        if node.action_type == 0 then -- Run - auto execute
            result = MethodFollower.execute(node, parent_value, selected_method)
        elseif node.action_type == 1 then -- Call - manual button
            -- Show Call Method button
            if imgui.button("Call Method") then
                result = MethodFollower.execute(node, parent_value, selected_method)
                node.last_call_time = os.clock()  -- Record call time with high precision
            else
                -- Keep previous result if button not clicked
                result = node.ending_value
            end
        end
        
        -- Always store result, even if nil
        node.ending_value = result
        if result then
            node.ending_value_full_name = selected_method:get_return_type():get_full_name()
        end
        
        -- Update output pin value
        node.pins.outputs[1].value = result
        
        -- Check if result is userdata (can continue to child nodes)
        local can_continue = true
        
        if returns_void then
            can_continue = false
        elseif selected_method then
            local success_return, return_type = pcall(function()
                return selected_method:get_return_type()
            end)
            if success_return and return_type then
                local return_type_name = return_type:get_full_name()
                if Nodes.is_terminal_type(return_type_name) then
                    can_continue = false
                end
            end
        end
        
        if can_continue and result ~= nil then
            can_continue = type(result) == "userdata"
        end

        -- If result is valid, check if we should unpause child nodes
        if can_continue then
            local success, result_type = pcall(function() 
                return result:get_type_definition() 
            end)
            if success and result_type then
                local result_type_name = result_type:get_full_name()
                -- Try to unpause children if the type matches their expectations
                -- Nodes.unpause_child_nodes(node, result_type_name)
            end
        else
            Nodes.add_context_menu_option(node, "Copy output value", tostring(result))
        end
        
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
    BaseFollower.render_action_buttons(node, function(node) 
        return type(node.ending_value) == "userdata"
    end)

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
    if params and #params > 0 then
        -- Output all the params for debugging
        log.debug(node.id.." MethodFollower: Executing method with params:".. json.dump_string(params))
    end
    
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

