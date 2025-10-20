-- DevTester v2.0 - Node Rendering
-- Rendering functions for all node types

local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local TypeStarter = require("DevTester2.Starters.TypeStarter")
local ManagedStarter = require("DevTester2.Starters.ManagedStarter")
local HookStarter = require("DevTester2.Starters.HookStarter")
local EnumStarter = require("DevTester2.Starters.EnumStarter")
local NativeStarter = require("DevTester2.Starters.NativeStarter")
local PrimitiveStarter = require("DevTester2.Starters.PrimitiveStarter")

local MethodOperation = require("DevTester2.Nodes.MethodOperation")
local FieldOperation = require("DevTester2.Nodes.FieldOperation")
local ArrayOperation = require("DevTester2.Nodes.ArrayOperation")

local Nodes = {}

-- ========================================
-- Main Rendering Dispatcher
-- ========================================

function Nodes.render_starter_node(node)
    
    if node.type == 0 then -- Type
        Helpers.set_node_titlebar_color(Constants.COLOR_NODE_TYPE) -- Purple
        TypeStarter.render(node)
    elseif node.type == 1 then -- Managed
        Helpers.set_node_titlebar_color(Constants.COLOR_NODE_MANAGED) -- Green
        ManagedStarter.render(node)
    elseif node.type == 2 then -- Hook
        Helpers.set_node_titlebar_color(Constants.COLOR_NODE_HOOK) -- Blue
        HookStarter.render(node)
    elseif node.type == 3 then -- Enum
        Helpers.set_node_titlebar_color(Constants.COLOR_NODE_ENUM) -- Magenta
        EnumStarter.render(node)
    elseif node.type == 4 then -- Native
        Helpers.set_node_titlebar_color(Constants.COLOR_NODE_NATIVE) -- Orange
        NativeStarter.render(node)
    elseif node.type == 5 then -- Primitive
        
        imgui.push_item_width(Constants.PRIMITIVE_NODE_WIDTH)
        Helpers.set_node_titlebar_color(Constants.COLOR_NODE_PRIMITIVE) -- Dark Cyan
        PrimitiveStarter.render(node)
        imgui.pop_item_width()
    end
    
    -- Reset title bar color
    Helpers.reset_node_titlebar_color()
end

function Nodes.render_operation_node(node)
    if node.operation == 0 then -- Method
        Helpers.set_node_titlebar_color(Constants.COLOR_NODE_METHOD) -- Yellow
        MethodOperation.render(node)
    elseif node.operation == 1 then -- Field
        Helpers.set_node_titlebar_color(Constants.COLOR_NODE_FIELD) -- Lime
        FieldOperation.render(node)
    elseif node.operation == 2 then -- Array
        Helpers.set_node_titlebar_color(Constants.COLOR_NODE_ARRAY) -- Deep Orange
        ArrayOperation.render(node)
    end
    
    -- Reset title bar color
    Helpers.reset_node_titlebar_color()
end

return Nodes
