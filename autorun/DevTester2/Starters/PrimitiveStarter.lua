local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local BaseStarter = require("DevTester2.Starters.BaseStarter")
local imgui = imgui
local imnodes = imnodes

local ValueStarter = {}

function ValueStarter.render(node)
    imnodes.begin_node(node.node_id)
    
    imnodes.begin_node_titlebar()
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
        -- Only update ending_value when value changes
        node.ending_value = Helpers.parse_primitive_value(node.value)
    end

    -- Create tooltip for output
    local tooltip_text = nil
    if node.ending_value then
        local value_type = type(node.ending_value)
        local type_description = "Unknown"
        if value_type == "number" then
            type_description = "Number"
        elseif value_type == "boolean" then
            type_description = "Boolean"
        elseif value_type == "string" then
            type_description = "String"
        end
        tooltip_text = string.format("Primitive Value\nType: %s\nValue: %s", type_description, tostring(node.ending_value))
    end

    BaseStarter.render_output_attribute(node, tostring(node.value), tooltip_text)

    BaseStarter.render_action_buttons(node)
    BaseStarter.render_debug_info(node)

    imnodes.end_node()
end

return ValueStarter