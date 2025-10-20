local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local imgui = imgui
local imnodes = imnodes

local ValueStarter = {}

function ValueStarter.render(node)
    imnodes.begin_node(node.node_id)
    imnodes.begin_node_titlebar()
    local pos_for_debug = imgui.get_cursor_pos()
    imgui.text("Primitive Starter")
    imnodes.end_node_titlebar()

    -- Value input as text
    if not node.value then
        node.value = ""
    end
    local changed, new_value = imgui.input_text("Value", node.value)
    if changed then
        node.value = new_value
        Helpers.mark_as_modified()
    end

    -- Set ending value and create output
    node.ending_value = Helpers.parse_primitive_value(node.value)

    -- Create output attribute
    if not node.output_attr then
        node.output_attr = Helpers.next_pin_id()
    end
    imgui.spacing()
    imnodes.begin_output_attribute(node.output_attr)

    local display_value = tostring(node.value)
    local pos = imgui.get_cursor_pos()
    local display_width = imgui.calc_text_size(display_value .. " (?)").x
    local node_width = imnodes.get_node_dimensions(node.node_id).x
    pos.x = pos.x + node_width - display_width - 26
    imgui.set_cursor_pos(pos)
    imgui.text(display_value)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() then
        local value_type = type(node.ending_value)
        local type_description = "Unknown"
        if value_type == "number" then
            type_description = "Number"
        elseif value_type == "boolean" then
            type_description = "Boolean"
        elseif value_type == "string" then
            type_description = "String"
        end
        imgui.set_tooltip(string.format("Primitive Value\nType: %s\nValue: %s", type_description, tostring(node.ending_value)))
    end

    imnodes.end_output_attribute()

    -- Action buttons
    imgui.spacing()
    local pos = imgui.get_cursor_pos()
    if imgui.button("- Remove Node") then
        Helpers.remove_starter_node(node)
    end
    if node.ending_value then
        imgui.same_line()
        local display_width = imgui.calc_text_size("+ Add Child Node").x
        local node_width = imnodes.get_node_dimensions(node.node_id).x
        pos.x = pos.x + node_width - display_width - 20
        imgui.set_cursor_pos(pos)
        if imgui.button("+ Add Child Node") then
            Helpers.add_child_node(node)
        end
    end

    -- Debug info
    local input_links, output_links = {}, {}
    for _, link in ipairs(State.all_links) do
        if link.to_node == node.id then
            table.insert(input_links, string.format("(Pin %s, Link %s)", tostring(link.to_pin), tostring(link.id)))
        end
        if link.from_node == node.id then
            table.insert(output_links, string.format("(Pin %s, Link %s)", tostring(link.from_pin), tostring(link.id)))
        end
    end
    local debug_info = string.format(
        "Node ID: %s\nStatus: %s\nOutput Attr: %s\nInput Links: %s\nOutput Links: %s",
        tostring(node.node_id),
        tostring(node.status or "None"),
        tostring(node.output_attr or "None"),
        #input_links > 0 and table.concat(input_links, ", ") or "None",
        #output_links > 0 and table.concat(output_links, ", ") or "None"
    )
    local text_width = imgui.calc_text_size("[?]").x
    local node_width = imnodes.get_node_dimensions(node.node_id).x
    pos_for_debug.x = pos_for_debug.x + node_width - text_width - 16
    imgui.set_cursor_pos(pos_for_debug)
    imgui.text_colored("[?]", 0xFFDADADA)
    if imgui.is_item_hovered() then
        imgui.set_tooltip(debug_info)
    end
    imnodes.end_node()
end

return ValueStarter