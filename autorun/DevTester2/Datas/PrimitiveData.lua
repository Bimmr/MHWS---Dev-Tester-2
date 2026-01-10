-- PrimitiveData Node Properties:
-- This node provides primitive values (numbers, booleans, strings) that can be entered manually.
-- The following properties define the state and configuration of a PrimitiveData node:
--
-- Configuration:
-- - value: String - The text input value that gets parsed into a primitive
--
-- Pins:
-- - pins.outputs[1]: "output" - The output pin (provides parsed primitive value)
--
-- Runtime Values:
-- - ending_value: Any - The parsed primitive value (number, boolean, or string)
--
-- UI/Debug:
-- - status: String - Current status message for debugging

local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local Constants = require("DevTester2.Constants")
local BaseData = require("DevTester2.Datas.BaseData")
local imgui = imgui
local imnodes = imnodes

local PrimitiveData = {}

-- Initialize primitive-specific properties
local function ensure_initialized(node)
    node.value = node.value or ""
end

function PrimitiveData.render(node)
    ensure_initialized(node)
    
    -- Execute the node to update ending_value
    PrimitiveData.execute(node)
    
    -- Ensure output pin exists
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end
    
    imnodes.begin_node(node.id)
    
    imnodes.begin_node_titlebar()
    imgui.text("Primitive Data")
    imnodes.end_node_titlebar()

    -- Value input as text
    local changed, new_value = imgui.input_text("Value", node.value)
    if changed then
        node.value = new_value
        State.mark_as_modified()
        -- Only update ending_value when value changes
        node.ending_value = Utils.parse_primitive_value(node.value)
    end

    -- Render output pin with value and type info
    local output_pin = node.pins.outputs[1]
    output_pin.value = node.ending_value
    
    imgui.spacing()
    imnodes.begin_output_attribute(output_pin.id)
    
    local display_value = Utils.get_value_display_string(node.ending_value)
    local debug_pos = Utils.get_right_cursor_pos(node.id, display_value .. " (?)")
    imgui.set_cursor_pos(debug_pos)
    imgui.text(display_value)
    imgui.same_line()
    imgui.text("(?)")
    
    if imgui.is_item_hovered() then
        imgui.set_tooltip(Utils.get_tooltip_for_value(node.ending_value))
    end
    
    imnodes.end_output_attribute()

    BaseData.render_action_buttons(node)
    BaseData.render_debug_info(node)

    imnodes.end_node()
    
end

function PrimitiveData.execute(node)
    -- Parse the value to set ending_value
    node.ending_value = Utils.parse_primitive_value(node.value)
end

-- ========================================
-- Serialization
-- ========================================

function PrimitiveData.serialize(node, Config)
    local data = BaseData.serialize(node, Config)
    data.value = node.value
    return data
end

function PrimitiveData.deserialize(data, Config)
    local node = BaseData.deserialize(data, Config)
    node.value = data.value or ""
    return node
end

return PrimitiveData