-- ManagedStarter Node Properties:
-- This node retrieves a managed singleton object from the game's memory.
-- The following properties define the state and configuration of a ManagedStarter node:
--
-- Configuration:
-- - path: String - The full type path (e.g., "app.SomeClass") of the managed singleton to retrieve
--
-- Runtime Values:
-- - ending_value: Object - The managed singleton object retrieved from the specified path
--
-- UI/Debug:
-- - status: String - Current status message ("Success", "Managed singleton not found", "Enter a path")

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

    imnodes.begin_node(node.node_id)

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
        -- Only update ending_value when path changes
        if node.path and node.path ~= "" then
            local managed_obj = sdk.get_managed_singleton(node.path)
            if managed_obj then
                node.ending_value = managed_obj
                node.status = "Success"
            else
                node.ending_value = nil
                node.status = "Managed singleton not found"
            end
        else
            node.ending_value = nil
            node.status = "Path cannot be empty"
        end
    end
    if has_children then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Cannot change path while node has children")
        end
    end

    if node.ending_value then
        -- Display simplified value without address
        local display_value = "Object"
        local type_info = node.ending_value:get_type_definition()
        if type_info then
            display_value = Utils.get_type_display_name(type_info)
        end

        local tooltip_text = string.format(
            "Type: %s\nAddress: %s\nFull Name: %s",
            node.path,
            string.format("0x%X", node.ending_value:get_address()),
            type_info:get_full_name()
        )

        BaseStarter.render_output_attribute(node, display_value, tooltip_text)
    elseif node.status == "Managed singleton not found" then
        imgui.text_colored("Managed singleton not found", Constants.COLOR_TEXT_WARNING)
    end

    imgui.spacing()

    BaseStarter.render_action_buttons(node)
    BaseStarter.render_debug_info(node)

    imnodes.end_node()
end

return ManagedStarter