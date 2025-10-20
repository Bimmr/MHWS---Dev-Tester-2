local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local TypeStarter = {}

function TypeStarter.render(node)
    imnodes.begin_node(node.node_id)
    imnodes.begin_node_titlebar()
    local pos_for_debug = imgui.get_cursor_pos()
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
    end

    -- Try to resolve the type
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

    -- Create output attribute
    if not node.output_attr then
        node.output_attr = Helpers.next_pin_id()
    end
    imgui.spacing()
    imnodes.begin_output_attribute(node.output_attr)

    local display_text = node.status or "No type"
    local pos = imgui.get_cursor_pos()
    local display_width = imgui.calc_text_size(display_text).x
    local node_width = imnodes.get_node_dimensions(node.node_id).x
    pos.x = pos.x + node_width - display_width - 26
    imgui.set_cursor_pos(pos)
    imgui.text(display_text)

    imnodes.end_output_attribute()

    -- Action buttons
    imgui.spacing()
    local pos = imgui.get_cursor_pos()
    if imgui.button("- Remove Node") then
        Helpers.remove_starter_node(node)
    end

    -- Debug tooltip
    if imgui.is_item_hovered() then
        imgui.set_tooltip("Remove this starter node")
    end

    imnodes.end_node()

    -- Debug tooltip for the node
    if imnodes.is_node_hovered(node.node_id) then
        local tooltip = string.format("Type Starter\nID: %d\nPath: %s\nStatus: %s",
            node.node_id,
            node.path or "None",
            node.status or "Unknown")
        imgui.set_tooltip(tooltip)
    end
end

return TypeStarter