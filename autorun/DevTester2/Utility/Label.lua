-- Label Node Properties:
-- This node provides a text label/comment for documentation purposes.
-- The following properties define the state and configuration of a Label node:
--
-- Configuration:
-- - text: String - The text content of the label
--
-- This node has no input or output pins - it's purely for visual annotation.

local State = require("DevTester2.State")
local Constants = require("DevTester2.Constants")
local Nodes = require("DevTester2.Nodes")
local imgui = imgui
local imnodes = imnodes

local Label = {}

function Label.render(node)

    imnodes.begin_node(node.node_id)

    imnodes.begin_node_titlebar()
    imgui.text("Label")
    imnodes.end_node_titlebar()

    -- Text input for the label content
    if not node.text then
        node.text = ""
    end
    local width = math.max(imgui.calc_text_size(node.text).x + 20, Nodes.get_node_width(Constants.NODE_WIDTH_UTILITY, Constants.UTILITY_TYPE_LABEL)-10)
    imgui.set_next_item_width(width)
    local changed, new_text = imgui.input_text("##label_text", node.text)
    if changed then
        node.text = new_text
        State.mark_as_modified()
    end

    -- Simple remove button
    imgui.spacing()
    if imgui.button("- Remove Node") then
        -- Find and remove this node from State
        for i, state_node in pairs(State.all_nodes) do
            if state_node.node_id == node.node_id then
                table.remove(State.all_nodes, i)
                State.node_map[node.node_id] = nil
                State.mark_as_modified()
                break
            end
        end
    end

    imnodes.end_node()

end

function Label.execute(node)
    -- Label nodes don't need to execute anything
    -- They exist purely for visual annotation
end

return Label