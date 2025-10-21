local Constants = require("DevTester2.Constants")

local imgui = imgui
local imnodes = imnodes
local re = re


local Utils = {}


-- ========================================
-- imGUI Cursor alignment Helpers
-- ========================================
function Utils.get_right_cursor_pos(node_id, text)
    local text_width = imgui.calc_text_size(text).x
    local node_width = imnodes.get_node_dimensions(node_id).x
    local pos = imgui.get_cursor_pos()
    local node_pos = imnodes.get_node_editor_space_pos(node_id)
    pos.x = node_pos.x + node_width - text_width - 15
    return pos
end

function Utils.get_top_right_cursor_pos(node_id, text)
    local text_width = imgui.calc_text_size(text).x
    local node_width = imnodes.get_node_dimensions(node_id).x
    local node_pos = imnodes.get_node_editor_space_pos(node_id)
    node_pos.x = node_pos.x + node_width - text_width - 10
    node_pos.y = node_pos.y + 7
    return node_pos
end

-- ========================================
-- UI Notifications
-- ========================================

function Utils.show_error(message)
    re.msg("[DevTester Error] " .. message)
end

function Utils.show_success(message)
    re.msg("[DevTester] " .. message)
end

function Utils.show_info(message)
    re.msg("[DevTester] " .. message)
end

-- ========================================
-- UI Styling
-- ========================================

function Utils.brighten_color(color, factor)
    -- Brighten a color by the given factor (1.0 = no change, >1.0 = brighter)
    -- Color is in AABBGGRR format (0xAABBGGRR)
    -- Extract components: AA BB GG RR
    
    -- Extract each byte using modulo and division
    local red = color % 256  -- RR (bits 0-7)
    local green = math.floor(color / 256) % 256  -- GG (bits 8-15)  
    local blue = math.floor(color / 65536) % 256  -- BB (bits 16-23)
    local alpha = math.floor(color / 16777216) % 256  -- AA (bits 24-31)
    
    -- Brighten each component (only RGB, keep alpha same)
    red = math.min(255, math.floor(red * factor))
    green = math.min(255, math.floor(green * factor))
    blue = math.min(255, math.floor(blue * factor))
    
    -- Reconstruct AABBGGRR: AA * 16777216 + BB * 65536 + GG * 256 + RR
    return alpha * 16777216 + blue * 65536 + green * 256 + red
end

-- ========================================
-- Display Formatting
-- ========================================

function Utils.format_value_display(value)
    if value == nil then
        return "nil"
    end
    
    local value_type = type(value)
    
    if value_type == "userdata" then
        -- It's a managed object
        local success, type_def = pcall(function() return value:get_type_definition() end)
        if success and type_def then
            local type_name = type_def:get_name()
            local success2, address = pcall(function() return value:get_address() end)
            if success2 and address then
                return string.format("%s | 0x%X", type_name, address)
            else
                return type_name
            end
        else
            return "userdata"
        end
    elseif value_type == "number" then
        return string.format("%.2f", value)
    elseif value_type == "boolean" then
        return value and "true" or "false"
    elseif value_type == "string" then
        return string.format('"%s"', value)
    else
        return tostring(value)
    end
end

-- ========================================
-- Category/Type Parsing
-- ========================================
function Utils.parse_category_and_type(category, type)
    if category == Constants.NODE_CATEGORY_STARTER then
        if type == Constants.STARTER_TYPE_NATIVE then
            return "STARTER", "NATIVE"
        elseif type == Constants.STARTER_TYPE_MANAGED then
            return "STARTER", "MANAGED"
        elseif type == Constants.STARTER_TYPE_HOOK then
            return "STARTER", "HOOK"
        end
    elseif category == Constants.NODE_CATEGORY_DATA then
        if type == Constants.DATA_TYPE_PRIMITIVE then
            return "DATA", "PRIMITIVE"
        elseif type == Constants.DATA_TYPE_ENUM then
            return "DATA", "ENUM"
        elseif type == Constants.DATA_TYPE_VARIABLE then
            return "DATA", "VARIABLE"
        end
    elseif category == Constants.NODE_CATEGORY_FOLLOWER then
        if type == Constants.FOLLOWER_TYPE_METHOD then
            return "FOLLOWER", "METHOD"
        elseif type == Constants.FOLLOWER_TYPE_FIELD then
            return "FOLLOWER", "FIELD"
        elseif type == Constants.FOLLOWER_TYPE_ARRAY then
            return "FOLLOWER", "ARRAY"
        end
    elseif category == Constants.NODE_CATEGORY_OPERATIONS then
        if type == Constants.OPERATIONS_TYPE_INVERT then
            return "OPERATIONS", "INVERT"
        elseif type == Constants.OPERATIONS_TYPE_MATH then
            return "OPERATIONS", "MATH"
        elseif type == Constants.OPERATIONS_TYPE_LOGIC then
            return "OPERATIONS", "LOGIC"
        elseif type == Constants.OPERATIONS_TYPE_COMPARE then
            return "OPERATIONS", "COMPARE"
        end
    elseif category == Constants.NODE_CATEGORY_CONTROL then
        if type == Constants.CONTROL_TYPE_SELECT then
            return "CONTROL", "SELECT"
        end
    end
    return "Unknown", "Unknown"
end


function Utils.get_type_display_name(type_info)
    -- Get a simplified display name for a type definition
    -- First try the short name, fall back to extracting from full name if needed

    if not type_info then return "Unknown" end

    -- Try to get the short name first
    local success, name = pcall(function() return type_info:get_name() end)
    if success and name and name ~= "" then
        return name
    end
    
    -- If short name is empty, try to get full name and extract the last part
    local success2, full_name = pcall(function() return type_info:get_full_name() end)
    if success2 and full_name and full_name ~= "" then
        -- Find the last dot and extract everything after it
        local last_dot = full_name:match("^.*()%.") 
        if last_dot then
            return full_name:sub(last_dot + 1)
        else
            -- No dots found, return the full name
            return full_name
        end
    end
    
    -- Fallback if all else fails
    return "Unknown"
end

function Utils.is_array(value)
    local type_def = value
    if type(value) == "userdata" then
        local success, td = pcall(function() return value:get_type_definition() end)
        if success and td then
            type_def = td
        end
    end
    local type_name = Utils.get_type_display_name(type_def)
    if type_name and (type_name:find("%[%]") or type_name:find("Array")) then
        return true
    end
    return false
end


-- ========================================
-- Type Parsing
-- ========================================

function Utils.parse_primitive_value(text_value)
    if not text_value or text_value == "" then
        return text_value
    end
    
    -- Try to convert to number
    local num_value = tonumber(text_value)
    if num_value then
        return num_value
    end
    
    -- Try to convert to boolean
    if text_value == "true" then
        return true
    elseif text_value == "false" then
        return false
    end
    
    -- Otherwise return as string
    return text_value
end

function Utils.parse_value_for_type(text_value, param_type)
    if not text_value or text_value == "" then
        return nil
    end
    
    -- Get the type name
    local type_name = param_type:get_name()
    
    -- Handle different types
    if type_name == "System.Int32" or type_name == "System.Int64" or 
       type_name == "System.UInt32" or type_name == "System.UInt64" or
       type_name == "System.Int16" or type_name == "System.UInt16" or
       type_name == "System.Byte" or type_name == "System.SByte" then
        -- Integer types
        local num = tonumber(text_value)
        return num and math.floor(num) or 0
    elseif type_name == "System.Single" or type_name == "System.Double" then
        -- Float types
        return tonumber(text_value) or 0.0
    elseif type_name == "System.Boolean" then
        -- Boolean type
        return text_value == "true"
    elseif type_name == "System.String" then
        -- String type
        return text_value
    elseif type_name == "System.Char" then
        -- Character type (take first character)
        return text_value:sub(1, 1)
    else
        -- For unknown types, try primitive parsing
        return Utils.parse_primitive_value(text_value)
    end
end

return Utils