-- TypeStarter Node Properties:
-- This node retrieves a type definition from a type path.
-- The following properties define the state and configuration of a TypeStarter node:
--
-- Configuration:
-- - path: String - The full type path (e.g., "app.SomeClass") of the type to retrieve
--
-- Runtime Values:
-- - ending_value: TypeDefinition - The type definition object retrieved from the specified path
--
-- UI/Debug:
-- - status: String - Current status message ("Success", "Type not found", "Enter a path")

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local BaseStarter = require("DevTester2.Starters.BaseStarter")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local TypeStarter = {}

function TypeStarter.render(node)

    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Type Starter")
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
            local success, type_def = pcall(function() return sdk.find_type_definition(node.path) end)
            if success and type_def then
                node.ending_value = type_def
                node.status = "Success"
            else
                node.ending_value = nil
                node.status = "Type not found"
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
        -- Display type information
        local display_value = node.ending_value:get_name()
        local tooltip_text = string.format(
            "Type: %s\nFull Name: %s\nNamespace: %s",
            node.ending_value:get_name(),
            node.ending_value:get_full_name(),
            node.ending_value:get_namespace() or "global"
        )

        BaseStarter.render_output_attribute(node, display_value, tooltip_text)
    elseif node.status == "Type not found" then
        imgui.text_colored("Type not found", Constants.COLOR_TEXT_WARNING)
    end

    imgui.spacing()

    BaseStarter.render_action_buttons(node)
    BaseStarter.render_debug_info(node)

    imnodes.end_node()
end

return TypeStarter