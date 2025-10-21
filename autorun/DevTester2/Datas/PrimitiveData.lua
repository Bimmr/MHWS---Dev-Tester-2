local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseData = require("DevTester2.Datas.BaseData")
local imgui = imgui
local imnodes = imnodes

local PrimitiveData = {}

function PrimitiveData.render(node)
    
    -- Execute the node to update ending_value
    PrimitiveData.execute(node)
    
    imnodes.begin_node(node.node_id)
    
    imnodes.begin_node_titlebar()
    imgui.text("Primitive Data")
    imnodes.end_node_titlebar()

    -- Value input as text
    if not node.value then
        node.value = ""
    end
    local changed, new_value = imgui.input_text("Value", node.value)
    if changed then
        node.value = new_value
        State.mark_as_modified()
        -- Only update ending_value when value changes
        node.ending_value = Utils.parse_primitive_value(node.value)
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

    BaseData.render_output_attribute(node, tostring(node.value), tooltip_text)

    BaseData.render_action_buttons(node)
    BaseData.render_debug_info(node)

    imnodes.end_node()
    
end

function PrimitiveData.execute(node)
    -- Parse the value to set ending_value
    node.ending_value = Utils.parse_primitive_value(node.value)
end

return PrimitiveData