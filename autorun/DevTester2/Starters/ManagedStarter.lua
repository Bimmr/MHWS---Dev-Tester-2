local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local ManagedStarter = {}

function ManagedStarter.render(node)
    imnodes.begin_node(node.node_id)
    imnodes.begin_node_titlebar()
    local pos_for_debug = imgui.get_cursor_pos()
    imgui.text("Managed Starter")
    imnodes.end_node_titlebar()
    
    -- Path input - disable if node has children
    local has_children = Helpers.has_children(node)
    if has_children then
        imgui.begin_disabled()
    end
    local path_changed, new_path = imgui.input_text("Path", node.path)
    if path_changed then
        node.path = new_path
        Helpers.mark_as_modified()
    end
    if has_children then
        imgui.end_disabled()
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Cannot change path while node has children")
        end
    end
    if node.path and node.path ~= "" then
        local managed_obj = sdk.get_managed_singleton(node.path)
        if managed_obj then
            node.ending_value = managed_obj
            node.status = "Success"
            if not node.output_attr then
                node.output_attr = Helpers.next_pin_id()
            end
            imgui.spacing()
            imnodes.begin_output_attribute(node.output_attr)
            -- Display simplified value without address
            local display_value = "Object"
            local type_info = managed_obj:get_type_definition()
            if type_info then
                display_value = Helpers.get_type_display_name(type_info)
            end
            local display = display_value .. " (?)"
            local pos = imgui.get_cursor_pos()
            local display_width = imgui.calc_text_size(display).x
            local node_width = imnodes.get_node_dimensions(node.node_id).x
            pos.x = pos.x + node_width - display_width - 26
            imgui.set_cursor_pos(pos)
            imgui.text(display_value)
            imgui.same_line()
            imgui.text("(?)")
            if imgui.is_item_hovered() then
                local address = string.format("0x%X", managed_obj:get_address())
                local tooltip_text = string.format(
                    "Type: %s\nAddress: %s\nFull Name: %s",
                    node.path, address, type_info:get_full_name()
                )
                imgui.set_tooltip(tooltip_text)
            end
            imnodes.end_output_attribute()
        else
            node.ending_value = nil
            node.status = "Managed singleton not found"
            imgui.text_colored("Managed singleton not found", 0xFFFF0000)
        end
    end
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
        "Node ID: %s\nStatus: %s\nInput Attr: %s\nOutput Attr: %s\nInput Links: %s\nOutput Links: %s",
        tostring(node.node_id),
        tostring(node.status or "None"),
        tostring(node.input_attr or "None"),
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

return ManagedStarter