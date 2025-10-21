local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseData = require("DevTester2.Datas.BaseData")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local EnumData = {}

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

function EnumData.render(node)
    
    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Enum Data")
    imnodes.end_node_titlebar()

    local path_changed, new_path = imgui.input_text("Path", node.path or "")
    if path_changed then
        node.path = new_path
        node.selected_enum_index = 1
        node.enum_names = nil
        node.enum_values = nil
        node.enum_display_strings = nil
        node.sorted_to_original_index = nil
        State.mark_as_modified()
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
                State.mark_as_modified()
            end
            if not node.output_attr then
                node.output_attr = State.next_pin_id()
            end
            imgui.spacing()
            imnodes.begin_output_attribute(node.output_attr)
            -- Get the original index for the selected sorted item
            local original_index = node.sorted_to_original_index[node.selected_enum_index]
            local display = node.enum_names[original_index] .. " = " .. tostring(node.enum_values[original_index])
            local pos = Utils.get_right_cursor_pos(node.node_id, display)
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
    
    BaseData.render_action_buttons(node)
    BaseData.render_debug_info(node)
    imnodes.end_node()
    
    -- Reset appearance
    Nodes.reset_node_titlebar_color()
end

return EnumData
