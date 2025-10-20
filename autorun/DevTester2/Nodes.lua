-- DevTester v2.0 - Node Rendering
-- Rendering functions for all node types

local State = require("DevTester2.State")
local Helpers = require("DevTester2.Helpers")
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
        Helpers.set_node_titlebar_color(0xFF9C27B0) -- Purple
        TypeStarter.render(node)
    elseif node.type == 1 then -- Managed
        Helpers.set_node_titlebar_color(0xFF4CAF50) -- Green
        ManagedStarter.render(node)
    elseif node.type == 2 then -- Hook
        Helpers.set_node_titlebar_color(0xFF2196F3) -- Blue
        HookStarter.render(node)
    elseif node.type == 3 then -- Enum
        Helpers.set_node_titlebar_color(0xFFE91E63) -- Magenta
        EnumStarter.render(node)
    elseif node.type == 4 then -- Native
        Helpers.set_node_titlebar_color(0xFFFF9800) -- Orange
        NativeStarter.render(node)
    elseif node.type == 5 then -- Primitive
        
    imgui.push_item_width(200)
        Helpers.set_node_titlebar_color(0xFF0097A7) -- Dark Cyan
        PrimitiveStarter.render(node)
    imgui.pop_item_width()
    end
    
    -- Reset title bar color
    Helpers.reset_node_titlebar_color()
end

function Nodes.render_operation_node(node)
    -- Apply operation title bar color (dark gray)
    
    if node.operation == 0 then -- Method
        Helpers.set_node_titlebar_color(0xFFFFC107) -- Yellow
        MethodOperation.render(node)
    elseif node.operation == 1 then -- Field
        Helpers.set_node_titlebar_color(0xFF8BC34A) -- Lime
        FieldOperation.render(node)
    elseif node.operation == 2 then -- Array
        Helpers.set_node_titlebar_color(0xFFFF5722) -- Deep Orange
        ArrayOperation.render(node)
    end
    
    -- Reset title bar color
    Helpers.reset_node_titlebar_color()
end

return Nodes
