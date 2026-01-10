-- ManagedStarter Node Properties:
-- This node retrieves a managed singleton object from the game's memory.
--
-- Configuration:
-- - path: String - The full type path (e.g., "app.SomeClass") of the managed singleton
--
-- Pins:
-- - pins.outputs[1]: "output" - The managed singleton object
--
-- Runtime Values:
-- - ending_value: Object - The managed singleton object retrieved
--
-- UI/Debug:
-- - status: String - Current status message

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local BaseStarter = require("DevTester2.Starters.BaseStarter")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local ManagedStarter = {}

function ManagedStarter.render(node)
    -- Ensure pin exists
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    local output_pin = node.pins.outputs[1]
    
    -- Always sync output pin value with ending_value on every render
    output_pin.value = node.ending_value

    imnodes.begin_node(node.id)

    imnodes.begin_node_titlebar()
    imgui.text("Managed Starter")
    imnodes.end_node_titlebar()

    -- Path input - disable if node has children
    local has_children = Nodes.has_children(node)
    if has_children then
        imgui.begin_disabled()
    end
    local path_changed, new_path = imgui.input_text("Path", node.path)
    if path_changed then
        node.path = new_path
        State.mark_as_modified()
        -- Update ending_value when path changes
        if node.path and node.path ~= "" then
            local managed_obj = sdk.get_managed_singleton(node.path)
            if managed_obj then
                node.ending_value = managed_obj
                output_pin.value = managed_obj
                node.status = "Success"
            else
                node.ending_value = nil
                output_pin.value = nil
                node.status = "Managed singleton not found"
            end
        else
            node.ending_value = nil
            output_pin.value = nil
            node.status = "Path cannot be empty"
        end
    end
    if has_children then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Cannot change path while node has children")
        end
    end

    -- Try to fetch singleton if missing (e.g. level load or initialization)
    if not node.ending_value and node.path and node.path ~= "" then
        local managed_obj = sdk.get_managed_singleton(node.path)
        if managed_obj then
            node.ending_value = managed_obj
            output_pin.value = managed_obj
            node.status = "Success"
        end
    end

    if node.ending_value then
        local type_info = Utils.get_type_info_for_display(node.ending_value, node.path)
        
        Nodes.add_context_menu_option(node, "Copy output name", type_info.actual_type or "Unknown")

        -- Output pin
        imgui.spacing()
        imnodes.begin_output_attribute(output_pin.id)
        local debug_pos = Utils.get_right_cursor_pos(node.id, type_info.display .. " (?)")
        imgui.set_cursor_pos(debug_pos)
        imgui.text(type_info.display)        
        imgui.same_line()
        imgui.text("(?)")
        if imgui.is_item_hovered() then
            imgui.set_tooltip(type_info.tooltip)
        end
        imnodes.end_output_attribute()
    elseif node.status == "Managed singleton not found" then
        imgui.text_colored("Managed singleton not found", Constants.COLOR_TEXT_WARNING)
    end

    imgui.spacing()
    
    BaseStarter.render_action_buttons(node)
    BaseStarter.render_debug_info(node)

    imnodes.end_node()
end

-- ========================================
-- Serialization
-- ========================================

function ManagedStarter.serialize(node, Config)
    -- Get base serialization
    local data = BaseStarter.serialize(node, Config)
    -- ManagedStarter has no additional fields beyond BaseStarter
    return data
end

function ManagedStarter.deserialize(data, Config)
    -- ManagedStarter uses the base deserialize directly
    return BaseStarter.deserialize(data, Config)
end

return ManagedStarter