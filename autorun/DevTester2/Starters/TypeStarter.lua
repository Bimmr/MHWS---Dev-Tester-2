local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local BaseStarter = require("DevTester2.Starters.BaseStarter")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local TypeStarter = {}

function TypeStarter.render(node)
    imnodes.begin_node(node.node_id)
    
    imnodes.begin_node_titlebar()
    imgui.text("Type Starter")
    imnodes.end_node_titlebar()

    -- Type path input
    if not node.path then
        node.path = ""
    end
    local path_changed, new_path = imgui.input_text("Type Path", node.path)
    if path_changed then
        node.path = new_path
        Helpers.mark_as_modified()
        -- Only update ending_value when path changes
        if node.path and node.path ~= "" then
            node.ending_value = sdk.find_type_definition(node.path)
            if not node.ending_value then
                node.status = "Type not found: " .. node.path
            else
                node.status = "Type resolved: " .. node.path
            end
        else
            node.ending_value = nil
            node.status = "Enter a type path"
        end
    end

    -- Render output if we have a valid type
    if node.ending_value then
        BaseStarter.render_output_attribute(node, node.status or "No type")
    end

    BaseStarter.render_action_buttons(node)
    BaseStarter.render_debug_info(node)

    imnodes.end_node()

    -- Node hover tooltip
    BaseStarter.render_node_hover_tooltip(node, string.format("Type Starter\nID: %d\nPath: %s\nStatus: %s",
        node.node_id,
        node.path or "None",
        node.status or "Unknown"))
end

return TypeStarter