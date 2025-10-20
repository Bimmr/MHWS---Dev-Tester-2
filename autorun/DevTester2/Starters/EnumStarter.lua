local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local EnumStarter = {}

local function generate_enum(typename)
    local t = sdk.find_type_definition(typename)
    if not t then
        return {}
    end
    local parent = t:get_parent_type()
    if not parent or parent:get_full_name() ~= "System.Enum" then
        return {}
    end
    local fields = t:get_fields()
    local enum = {}
    for i, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            local success, raw_value = pcall(function() return field:get_data(nil) end)
            if success then
                enum[name] = raw_value
            end
        end
    end
    return enum
end

function EnumStarter.render(node)
    imnodes.begin_node(node.node_id)
    imnodes.begin_node_titlebar()
    local pos_for_debug = imgui.get_cursor_pos()
    imgui.text("Enum Starter")
    imnodes.end_node_titlebar()
    local path_changed, new_path = imgui.input_text("Path", node.path or "")
    if path_changed then
        node.path = new_path
        node.selected_enum_index = 1
        node.enum_names = nil
        node.enum_values = nil
        node.enum_display_strings = nil
        node.sorted_to_original_index = nil
        Helpers.mark_as_modified()
    end
    if node.path and node.path ~= "" then
        if not node.enum_names or not node.enum_values or not node.enum_display_strings then
            local enum_table = generate_enum(node.path)
            node.enum_names = {}
            node.enum_values = {}
            node.enum_display_strings = {}
            for k, v in pairs(enum_table) do
                table.insert(node.enum_names, k)
                table.insert(node.enum_values, v)
            end
            
            -- Create display strings and sort by value
            local enum_items = {}
            for i, name in ipairs(node.enum_names) do
                local value = node.enum_values[i]
                table.insert(enum_items, {
                    name = name,
                    value = value,
                    display = name .. " = " .. tostring(value),
                    original_index = i
                })
            end
            
            -- Sort by value (only if all values are numbers)
            local all_numeric = true
            for _, item in ipairs(enum_items) do
                if type(item.value) ~= "number" then
                    all_numeric = false
                    break
                end
            end
            
            if all_numeric then
                table.sort(enum_items, function(a, b) return a.value < b.value end)
            end
            
            -- Create sorted arrays
            node.enum_display_strings = {}
            node.sorted_to_original_index = {}
            for i, item in ipairs(enum_items) do
                table.insert(node.enum_display_strings, item.display)
                node.sorted_to_original_index[i] = item.original_index
            end
        end
        if #node.enum_display_strings > 0 then
            node.selected_enum_index = node.selected_enum_index or 1
            local changed, new_index = imgui.combo("Value", node.selected_enum_index, node.enum_display_strings)
            if changed then
                node.selected_enum_index = new_index
                Helpers.mark_as_modified()
            end
            if not node.output_attr then
                node.output_attr = Helpers.next_pin_id()
            end
            imgui.spacing()
            imnodes.begin_output_attribute(node.output_attr)
            -- Get the original index for the selected sorted item
            local original_index = node.sorted_to_original_index[node.selected_enum_index]
            local display = node.enum_names[original_index] .. " = " .. tostring(node.enum_values[original_index])
            local pos = imgui.get_cursor_pos()
            local display_width = imgui.calc_text_size(display).x
            local node_width = imnodes.get_node_dimensions(node.node_id).x
            pos.x = pos.x + node_width - display_width - 26
            imgui.set_cursor_pos(pos)
            imgui.text(display)
            imnodes.end_output_attribute()
            node.ending_value = node.enum_names[original_index]  -- Output enum name instead of value
        else
            node.ending_value = nil
            imgui.text_colored("No enum values found", 0xFFFF0000)
        end
    end
    imgui.spacing()
    if imgui.button("- Remove Node") then
        Helpers.remove_starter_node(node)
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

return EnumStarter