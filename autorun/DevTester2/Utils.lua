local Constants = require("DevTester2.Constants")
local State = require("DevTester2.State")

local imgui = imgui
local imnodes = imnodes
local re = re


local Utils = {}

-- ========================================
-- imGUI Cursor alignment Helpers
-- ========================================
function Utils.get_right_cursor_pos(node_id, text, padding)
   local text_width = imgui.calc_text_size(text).x
    local node_width = imnodes.get_node_dimensions(node_id).x
    local pos = imgui.get_cursor_pos()
    local node_pos = imnodes.get_node_editor_space_pos(node_id)
    padding = padding or 15

    -- Multiline doesn't get the correct width so we'll just add more to it
    if imgui.calc_text_size(text).y > imgui.get_default_font_size() then
        padding = padding + 20
    end
    
    pos.x = node_pos.x + node_width - text_width - padding
    
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
-- Time Display Helpers
-- ========================================

-- Format a relative time display with consistent width formatting
-- timestamp: os.clock() value to format
-- Returns: formatted string
-- Format examples: 01ms, 11ms, 111ms, 1.1s, 11.1s, 1.1m, 11.1m
function Utils.format_time_ago(timestamp)
    if not timestamp then return "" end
    
    local time_ago = os.clock() - timestamp
    local time_text
    
    if time_ago < 0.01 then
        -- 0-9ms: pad to 2 digits
        time_text = string.format("%02.0fms", math.floor(time_ago * 1000))
    elseif time_ago < 0.1 then
        -- 10-99ms: 2 digits
        time_text = string.format("%02.0fms", math.floor(time_ago * 1000))
    elseif time_ago < 1 then
        -- 100-999ms: 3 digits
        time_text = string.format("%03.0fms", math.floor(time_ago * 1000))
    elseif time_ago < 60 then
        -- 1-59s: show seconds with 2 decimal places
        time_text = string.format("%.2fs", time_ago)
    elseif time_ago < 3600 then
        -- 1-59m: show minutes and seconds (e.g., 5m 23s)
        local minutes = math.floor(time_ago / 60)
        local seconds = math.floor(time_ago % 60)
        time_text = string.format("%dm %ds", minutes, seconds)
    else
        -- 1h+: show hours and minutes (e.g., 1h 15m)
        local hours = math.floor(time_ago / 3600)
        local minutes = math.floor((time_ago % 3600) / 60)
        time_text = string.format("%dh %dm", hours, minutes)
    end
    
    return time_text
end

-- Render a relative time display with hover tooltip showing exact time
-- timestamp: os.clock() value to display
function Utils.render_time_ago(timestamp)
    if not timestamp then return end
    
    local time_text = Utils.format_time_ago(timestamp)
    local time_ago = os.clock() - timestamp
    
    imgui.text(time_text)
    
    if imgui.is_item_hovered() then
        -- Calculate the actual wall clock time when the event occurred
        local current_time = os.time()
        local event_time = current_time - math.floor(time_ago)
        local absolute_time = os.date("%H:%M:%S", event_time)
        imgui.set_tooltip("Exact time: " .. absolute_time)
    end
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

-- Helper to extract type information from a value
-- Returns: type_info table with name, full_name, address (or nil for non-userdata)
function Utils.get_type_info(value)
    if value == nil then
        return nil
    end
    
    if type(value) ~= "userdata" then
        return {
            name = type(value),
            full_name = type(value),
            address = nil,
            type_def = nil,
            is_userdata = false
        }
    end
    
    local info = {
        name = nil,
        full_name = nil,
        address = nil,
        type_def = nil,
        is_userdata = true
    }
    
    local success, type_def = pcall(function() return value:get_type_definition() end)
    if success and type_def then
        info.type_def = type_def
        
        local success_name, name = pcall(function() return type_def:get_name() end)
        if success_name and name then
            info.name = name
        end
        
        local success_full, full_name = pcall(function() return type_def:get_full_name() end)
        if success_full and full_name then
            info.full_name = full_name
        end
        
        local success_addr, addr = pcall(function() return value:get_address() end)
        if success_addr and addr then
            info.address = addr
        end
    end
    
    return info
end

-- ========================================
-- Category/Type Parsing
-- ========================================
Utils.CATEGOREY_MAP = {}
Utils.TYPE_MAP = {}
local function create_maps()
    -- First pass: Map categories
    for k, v in pairs(Constants) do
        if k:find("NODE_CATEGORY_") then
            local category_name = k:match("NODE_CATEGORY_(.+)")
            Utils.CATEGOREY_MAP[v] = category_name
            -- Initialize type map for this category
            Utils.TYPE_MAP[v] = {}
        end
    end
    
    -- Second pass: Map types to categories
    for k, v in pairs(Constants) do
        if k:find("_TYPE_") then
            local category_prefix, type_name = k:match("(.+)_TYPE_(.+)")
            if category_prefix and type_name then
                -- Find the category ID for this prefix
                -- We need to look up NODE_CATEGORY_PREFIX
                local category_key = "NODE_CATEGORY_" .. category_prefix
                local category_id = Constants[category_key]
                
                if category_id and Utils.TYPE_MAP[category_id] then
                    Utils.TYPE_MAP[category_id][v] = type_name
                end
            end
        end
    end
end

function Utils.parse_category_and_type(category, type)
    if not next(Utils.CATEGOREY_MAP) then
        create_maps()
    end
    
    local category_name = Utils.CATEGOREY_MAP[category] or "Unknown"
    local type_name = "Unknown"
    
    if Utils.TYPE_MAP[category] and Utils.TYPE_MAP[category][type] then
        type_name = Utils.TYPE_MAP[category][type]
    end
    
    return category_name, type_name
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

-- Unified function to get all type display info for a value
-- Returns: { display = "TypeName" or "GameObject (Name)", tooltip = "...", actual_type = "full.name" }
function Utils.get_type_info_for_display(value, declared_type_name)
    local result = {
        display = "",
        tooltip = "nil",
        actual_type = nil
    }
   
    if value == nil then return result end
   
    local info = Utils.get_type_info(value)
    if not info then return result end
  
    -- For non-userdata, simple display
    if not info.is_userdata then
        result.display = tostring(value)
        result.tooltip = string.format("Value: %s\nType: %s", tostring(value), info.name)
        return result
    end
    
    -- Userdata handling - check for nil or empty string
    if not info.name or info.name == "" then
        -- Use full_name as fallback (works for arrays)
        if info.full_name and info.full_name ~= "" then
            -- Extract short name from full name (e.g., "app.EquipDef.BowBottleInfo[]" -> "BowBottleInfo[]")
            local short_name = info.full_name:match("([^%.]+)$") or info.full_name
            result.display = short_name
            result.actual_type = info.full_name
            result.tooltip = "Type: " .. short_name
            if info.address then
                result.tooltip = result.tooltip .. string.format("\nAddress: 0x%X", info.address)
            end
            if info.full_name then
                result.tooltip = result.tooltip .. "\nFull Name: " .. info.full_name
            end
        -- Then try declared type as fallback
        elseif declared_type_name and declared_type_name ~= "" then
            local short_declared = declared_type_name:match("([^%.]+)$") or declared_type_name
            result.display = short_declared
            result.tooltip = "Declared Type: " .. declared_type_name
            result.actual_type = declared_type_name
        else
            result.tooltip = "userdata (unknown type)"
        end
        return result
    end
    
    -- Build display string
    result.display = info.name
    result.actual_type = info.full_name
    
    -- Special handling for GameObject - show the object's name
    if info.full_name == "via.GameObject" then
        local success_name, obj_name = pcall(function() return value:call("get_Name") end)
        if success_name and obj_name then
            result.display = info.name .. " (" .. obj_name .. ")"
        else
            -- Fallback to ToString()
            local success_tostring, str_name = pcall(function() return value:call("ToString") end)
            if success_tostring and str_name then
                -- Parse ToString format: "GameObject[Name]" -> "Name"
                local parsed_name = str_name:match("GameObject%[(.+)%]")
                if parsed_name then
                    result.display = info.name .. " (" .. parsed_name .. ")"
                else
                    -- If parsing fails, use the full ToString result
                    result.display = info.name .. " (" .. str_name .. ")"
                end
            end
        end
    end
    
    -- Build tooltip
    local parts = {}
    parts[#parts + 1] = "Type: " .. info.name
    if info.address then
        parts[#parts + 1] = string.format("Address: 0x%X", info.address)
    end
    if info.full_name then
        parts[#parts + 1] = "Full Name: " .. info.full_name
    end
    -- Show declared type if provided and different from runtime type
    if declared_type_name and declared_type_name ~= info.full_name then
        parts[#parts + 1] = "Declared: " .. declared_type_name
    end
    result.tooltip = table.concat(parts, "\n")
    
    return result
end

-- Simple tooltip helper (for cases where you don't need full type_info)
function Utils.get_tooltip_for_value(value, declared_type_name)
    return Utils.get_type_info_for_display(value, declared_type_name).tooltip
end

-- Get the actual runtime type name of a value
function Utils.get_actual_type_name(value, fallback_type_or_name)
    if value and type(value) == "userdata" then
        local success, runtime_type = pcall(function() 
            return value:get_type_definition() 
        end)
        if success and runtime_type then
            local success_name, type_name = pcall(function() 
                return runtime_type:get_full_name() 
            end)
            if success_name and type_name then
                return type_name
            end
        end
    end
    
    -- Handle fallback
    if type(fallback_type_or_name) == "string" then
        return fallback_type_or_name
    elseif fallback_type_or_name and type(fallback_type_or_name) == "userdata" then
        local success, name = pcall(function() 
            return fallback_type_or_name:get_full_name() 
        end)
        if success and name then
            return name
        end
    end
    
    return "Unknown"
end

function Utils.get_value_display_string(value)
    if value == nil then return "nil" end
    
    local info = Utils.get_type_info(value)
    if not info then return "nil" end
    
    if not info.is_userdata then
        return tostring(value)
    end
    
    -- Userdata - need type name for special handling
    local type_name = info.name
    if not type_name then
        return "Unknown"
    end
    
    -- Handle Nullable types
    if type_name:find("Nullable") and info.type_def then
        local success_nullable, nullable_result = pcall(function()
            local field = info.type_def:get_field("_Value")
            local inner_type = field:get_type()
            local inner_name = inner_type:get_full_name()
            return "Nullable(" .. Utils.get_value_display_string(inner_name) .. ")"
        end)
        if success_nullable then
            return nullable_result
        end
    end
    
    -- Handle special display types (vectors, colors, etc.)
    local special_display = Utils.format_special_type(value, type_name)
    if special_display then
        return special_display
    end
    
    return Utils.get_type_display_name(info.type_def)
end

-- Format special types like vectors, colors, sizes for display
-- Returns formatted string or nil if not a special type
function Utils.format_special_type(value, type_name)
    if type_name == "vec3" then
        local x = value.x or 0
        local y = value.y or 0
        local z = value.z or 0
        return string.format("(%.2f, %.2f, %.2f)", x, y, z)
    elseif type_name == "vec2" then
        local x = value.x or 0
        local y = value.y or 0
        return string.format("(%.2f, %.2f)", x, y)
    elseif type_name == "vec4" then
        local x = value.x or 0
        local y = value.y or 0
        local z = value.z or 0
        local w = value.w or 0
        return string.format("(%.2f, %.2f, %.2f, %.2f)", x, y, z, w)
    elseif type_name == "Color" then
        local r = value.r or 0
        local g = value.g or 0
        local b = value.b or 0
        local a = value.a or 0
        return string.format("RGBA(%.0f, %.0f, %.0f, %.0f)", r, g, b, a)
    elseif type_name == "Size" then
        local w = value.w or 0
        local h = value.h or 0
        return string.format("Size(%.2f, %.2f)", w, h)
    end
    return nil
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
    elseif param_type:is_a("System.Enum") then
        -- Enum type - try to find matching enum value
        local enum_table = Utils.generate_enum(type_name)
        if enum_table then
            -- First try exact name match
            if enum_table[text_value] ~= nil then
                return enum_table[text_value]
            end
            -- Try case-insensitive match
            for name, value in pairs(enum_table) do
                if name:lower() == text_value:lower() then
                    return value
                end
            end
            -- Try numeric value match
            local num_value = tonumber(text_value)
            if num_value then
                for name, value in pairs(enum_table) do
                    if type(value) == "number" and value == num_value then
                        return value
                    end
                end
            end
        end
        return nil  -- Could not parse enum value
    else
        -- For unknown types, try primitive parsing
        return Utils.parse_primitive_value(text_value)
    end
end

-- ========================================
-- UI Components
-- ========================================

function Utils.hybrid_combo(label, current_index, items)
    -- Hybrid combo that combines input_text with popup window
    -- Returns: changed (boolean), new_index (number)
    -- API matches imgui.combo exactly

    if not items then
        items = {}
    end

    -- Ensure current_index is valid (allow 0 for empty state)
    if not current_index or current_index < 0 or current_index > #items then
        current_index = 0
    end

    local current_text = ""
    if current_index > 0 and current_index <= #items then
        current_text = items[current_index] or ""
    end

    local changed = false
    local new_index = current_index

    -- Push unique ID for this combo to avoid conflicts
    imgui.push_id("hybrid-"..label)

    -- Create unique ID for the popup (relative to the pushed ID)
    local popup_id = "hybrid-"..label

    -- Initialize persistent filter storage for this combo (separate from selected text)
    if not State.hybrid_combo_text[label] then
        State.hybrid_combo_text[label] = ""
    end

    -- Input text field shows selected item (read-only display)
    local cursor_pos = imgui.get_cursor_pos()
    imgui.set_next_item_width(imgui.calc_item_width()-imgui.calc_text_size("▼").x-5)
    local input_changed, new_text = imgui.input_text("##"..label, current_text, 128) -- Read-only flag

    -- Calculate popup width based on input field
    local input_width = imgui.calc_item_width()
    local label_width = imgui.calc_text_size(label).x
    local popup_width = input_width + label_width + 10

    -- Check if popup should open from input field
    local should_open_popup = false
    if imgui.is_item_active() then
        should_open_popup = true
    end

    -- Clear filter text when popup opens
    local popup_was_open = imgui.is_popup_open(popup_id)
    if should_open_popup and not popup_was_open then
        State.hybrid_combo_text[label] = ""
    end

    -- Position arrow button next to input text
    imgui.same_line()
    cursor_pos.x = cursor_pos.x + imgui.calc_item_width() - imgui.calc_text_size("▼").x -5
    imgui.set_cursor_pos(cursor_pos)

    -- Draw arrow button
    local popup_open = imgui.is_popup_open(popup_id)
    local arrow_clicked = imgui.arrow_button("arrow", 3) 

    imgui.same_line()
    local pos = imgui.get_cursor_pos()
    imgui.set_cursor_pos(Vector2f.new(pos.x - 2, pos.y))
    imgui.text(label)

    -- Handle popup opening/closing from arrow button
    if arrow_clicked then
        if popup_open then
            imgui.close_current_popup()
            should_open_popup = false
        else
            should_open_popup = true
        end
    end

    -- -- Position popup relative to input field
    local cursor_pos = imgui.get_cursor_screen_pos()
    imgui.set_next_window_pos(Vector2f.new(cursor_pos.x, cursor_pos.y), 1, nil)

    -- Set popup size constraints
    local visible_items = 0
    local visible_categorys = 0
    for i, item in ipairs(items) do
        local show_item = true
        if State.hybrid_combo_text[label] and State.hybrid_combo_text[label] ~= "" then
            local item_lower = item:lower()
            local text_lower = State.hybrid_combo_text[label]:lower()
            show_item = item_lower:find(text_lower, 1, true) ~= nil and not item:find("\n")
        elseif item:find("\n") then
            visible_categorys = visible_categorys + 1
        end
        if show_item then
            visible_items = visible_items + 1
        end
    end
    local popup_height = math.min(200, (visible_items * 20) + (visible_categorys * 40) + 110) -- Item height + padding for filter
    imgui.set_next_window_size(Vector2f.new(popup_width, popup_height), nil)

    -- Popup window with styled buttons
    if imgui.begin_popup_context_item(popup_id, 4096) then
        -- Create table with scrollable body and fixed header
        imgui.begin_table("combo_table_"..label, 1, imgui.TableFlags.ScrollY)

        -- Setup column with no visible header
        imgui.table_setup_column("Search", 16 + 4096, popup_width - 20)
        imgui.table_setup_scroll_freeze(0, 1)
        imgui.table_next_row(2) -- 2 = ImGuiTableRowFlags_Headers
        imgui.table_set_column_index(0)

        -- Filter input in header
        imgui.push_style_var(imgui.ImGuiStyleVar.FramePadding, Vector2f.new(10, 5))
        local filter_pos = imgui.get_cursor_pos()
        imgui.set_next_item_width(popup_width ) -- Fill column
        local filter_changed, filter_text = imgui.input_text("##Filter", State.hybrid_combo_text[label])
        if filter_text == nil or filter_text == "" and not imgui.is_item_active() then
            imgui.set_cursor_pos(Vector2f.new(filter_pos.x + 10, filter_pos.y + 5))
            imgui.text_colored("Enter text to search...", 0xAA888888)
        end
        if filter_changed then
            State.hybrid_combo_text[label] = filter_text
        end
        imgui.pop_style_var()


        -- Apply button styling
        imgui.push_style_var(imgui.ImGuiStyleVar.FramePadding, Vector2f.new(3, 0))
        imgui.push_style_var(imgui.ImGuiStyleVar.ItemSpacing, Vector2f.new(0, 0))
        imgui.push_style_var(imgui.ImGuiStyleVar.CellPadding, Vector2f.new(0, 1))
        imgui.push_style_var(imgui.ImGuiStyleVar.ItemInnerSpacing, Vector2f.new(0, 0))
        imgui.push_style_var(imgui.ImGuiStyleVar.ButtonTextAlign, Vector2f.new(0, 0.5))
        imgui.push_style_var(imgui.ImGuiStyleVar.FrameRounding, 0.0)

        imgui.push_style_color(21, 0x00714A29) -- Button color
        imgui.push_style_color(22, 0xFF5c5c5c) -- Button hover color

        for i, item in ipairs(items) do
            if item ~= "" then
                -- Filter items based on current input text (case-insensitive)
                -- Section titles (containing \n) are always shown
                local show_item = true
                if filter_text and filter_text ~= "" then
                    -- Always show section titles (items containing \n)
                    if item:find("\n") then
                        show_item = true
                    else
                        local item_lower = item:lower()
                        local text_lower = filter_text:lower()
                        show_item = item_lower:find(text_lower, 1, true) ~= nil
                    end
                end

                if show_item then

                    imgui.table_next_row()
                    imgui.table_set_column_index(0)

                    -- Push ID for each button to ensure uniqueness
                    imgui.push_id(i)

                    -- Highlight current selection by changing button color
                    if i == current_index then
                        imgui.push_style_color(21, 0xFF5c5c5c) -- Selection hover color
                    end

                    -- Create button for each item
                    local button_height = imgui.calc_text_size(item).y + 4 -- Small padding
                    if imgui.button(item, Vector2f.new(popup_width, button_height)) then
                        new_index = i
                        changed = true
                        imgui.close_current_popup()
                    end

                    -- Add tooltip for items that are wider than popup
                    local item_width = imgui.calc_text_size(item).x
                    if item_width > (popup_width - 40) and imgui.is_item_hovered() then
                        imgui.set_tooltip(item)
                    end

                    -- Pop the selection color if it was pushed
                    if i == current_index then
                        imgui.pop_style_color()
                    end

                    imgui.pop_id() -- Pop button ID
                end
            end
        end

        -- Pop the styling
        imgui.pop_style_color(2)
        imgui.pop_style_var(6)

        imgui.end_table()
        -- set whole table background to
        imgui.table_set_bg_color(0, 0x00714A29, 0)


        imgui.end_popup()
    end

     -- Open popup if needed
    if should_open_popup then
        imgui.open_popup(popup_id)
    end

    imgui.pop_id() -- Pop combo ID

    return changed, new_index
end

function Utils.hybrid_combo_with_manage(label, current_index, items)
    -- Hybrid combo that combines input_text with popup window, with an Add button
    -- Returns: changed (boolean), new_index (number), items (table)
    -- API matches imgui.combo, but allows adding new items

    -- Ensure items is a table
    if not items then
        items = {}
    end

    -- Ensure current_index is valid (allow 0 for empty state)
    if not current_index or current_index < 0 or current_index > #items then
        current_index = 0
    end

    local current_text = ""
    if current_index > 0 and current_index <= #items then
        current_text = items[current_index] or ""
    end

    local changed = false
    local new_index = current_index

    -- Push unique ID for this combo to avoid conflicts
    imgui.push_id("hybrid-add-"..label)

    -- Create unique ID for the popup (relative to the pushed ID)
    local popup_id = "hybrid-add-"..label

    -- Initialize persistent filter storage for this combo (separate from selected text)
    if not State.hybrid_combo_text[label] then
        State.hybrid_combo_text[label] = ""
    end

    -- Input text field shows selected item (read-only display)
    local cursor_pos = imgui.get_cursor_pos()
    imgui.set_next_item_width(imgui.calc_item_width()-imgui.calc_text_size("▼").x-5)
    local input_changed, new_text = imgui.input_text("##"..label, current_text, 128) -- Read-only flag

    -- Calculate popup width based on input field
    local input_width = imgui.calc_item_width()
    local label_width = imgui.calc_text_size(label).x
    local popup_width = input_width + label_width + 10

    -- Check if popup should open from input field
    local should_open_popup = false
    if imgui.is_item_active() then
        should_open_popup = true
    end

    -- Clear filter text when popup opens
    local popup_was_open = imgui.is_popup_open(popup_id)
    if should_open_popup and not popup_was_open then
        State.hybrid_combo_text[label] = ""
    end

    -- Position arrow button next to input text
    imgui.same_line()
    cursor_pos.x = cursor_pos.x + imgui.calc_item_width() - imgui.calc_text_size("▼").x -5
    imgui.set_cursor_pos(cursor_pos)

    -- Draw arrow button
    local popup_open = imgui.is_popup_open(popup_id)
    local arrow_clicked = imgui.arrow_button("arrow", 3) 

    imgui.same_line()
    local pos = imgui.get_cursor_pos()
    imgui.set_cursor_pos(Vector2f.new(pos.x - 2, pos.y))
    imgui.text(label)

    -- Handle popup opening/closing from arrow button
    if arrow_clicked then
        if popup_open then
            imgui.close_current_popup()
            should_open_popup = false
        else
            should_open_popup = true
        end
    end

    -- Position popup relative to input field
    local cursor_pos = imgui.get_cursor_screen_pos()
    imgui.set_next_window_pos(Vector2f.new(cursor_pos.x, cursor_pos.y), 1, nil)

    -- Set popup size constraints
    local visible_items = 0
    local visible_categorys = 0
    for i, item in ipairs(items) do
        local show_item = true
        if State.hybrid_combo_text[label] and State.hybrid_combo_text[label] ~= "" then
            local item_lower = item:lower()
            local text_lower = State.hybrid_combo_text[label]:lower()
            show_item = item_lower:find(text_lower, 1, true) ~= nil and not item:find("\n")
        elseif item:find("\n") then
            visible_categorys = visible_categorys + 1
        end
        if show_item then
            visible_items = visible_items + 1
        end
    end
    local popup_height = math.min(200, (visible_items * 20) + (visible_categorys * 40) + 110) -- Item height + padding for filter
    imgui.set_next_window_size(Vector2f.new(popup_width, popup_height), nil)

    -- Popup window with styled buttons
    if imgui.begin_popup_context_item(popup_id, 4096) then
        -- Create table with scrollable body and fixed header
        imgui.begin_table("combo_table_add_"..label, 1, imgui.TableFlags.ScrollY)

        -- Setup column with no visible header
        imgui.table_setup_column("Search", 16 + 4096, popup_width - 20)
        imgui.table_setup_scroll_freeze(0, 1)
        imgui.table_next_row(2) -- 2 = ImGuiTableRowFlags_Headers
        imgui.table_set_column_index(0)

        -- Filter input in header
        imgui.push_style_var(imgui.ImGuiStyleVar.FramePadding, Vector2f.new(10, 5))
        local filter_pos = imgui.get_cursor_pos()
        imgui.set_next_item_width(popup_width - imgui.calc_text_size("Add").x - 30) -- Leave space for Add button
        local filter_changed, filter_text = imgui.input_text("##Filter", State.hybrid_combo_text[label])
        
        -- Add button beside filter
        imgui.same_line()
        local pos = imgui.get_cursor_pos()
        imgui.set_cursor_pos(Vector2f.new(pos.x - 15, pos.y))
        local add_clicked = imgui.button("Add")
        
        if filter_text == nil or filter_text == "" and not imgui.is_item_active() then
            imgui.set_cursor_pos(Vector2f.new(filter_pos.x + 10, filter_pos.y + 5))
            imgui.text_colored("Enter text to search...", 0xAA888888)
        end
        if filter_changed then
            State.hybrid_combo_text[label] = filter_text
        end
        if add_clicked then
            local filter_text = State.hybrid_combo_text[label] or ""
            if filter_text ~= "" then
                -- Check if already exists
                local exists = false
                for _, item in ipairs(items) do
                    if item == filter_text then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(items, filter_text)
                    new_index = #items
                    changed = true
                    imgui.close_current_popup()
                end
            end
        end
        
        imgui.pop_style_var()

        -- Apply button styling
        imgui.push_style_var(imgui.ImGuiStyleVar.FramePadding, Vector2f.new(3, 0))
        imgui.push_style_var(imgui.ImGuiStyleVar.ItemSpacing, Vector2f.new(0, 0))
        imgui.push_style_var(imgui.ImGuiStyleVar.CellPadding, Vector2f.new(0, 1))
        imgui.push_style_var(imgui.ImGuiStyleVar.ItemInnerSpacing, Vector2f.new(0, 0))
        imgui.push_style_var(imgui.ImGuiStyleVar.ButtonTextAlign, Vector2f.new(0, 0.5))
        imgui.push_style_var(imgui.ImGuiStyleVar.FrameRounding, 0.0)

        imgui.push_style_color(21, 0x00714A29) -- Button color
        imgui.push_style_color(22, 0xFF5c5c5c) -- Button hover color

        for i, item in ipairs(items) do
            if item ~= "" then
                -- Filter items based on current input text (case-insensitive)
                -- Section titles (containing \n) are always shown
                local show_item = true
                if filter_text and filter_text ~= "" then
                    -- Always show section titles (items containing \n)
                    if item:find("\n") then
                        show_item = true
                    else
                        local item_lower = item:lower()
                        local text_lower = filter_text:lower()
                        show_item = item_lower:find(text_lower, 1, true) ~= nil
                    end
                end

                if show_item then

                    
                    imgui.table_next_row()
                    imgui.table_set_column_index(0)

                    -- Push ID for each button to ensure uniqueness
                    imgui.push_id(i)

                    -- Highlight current selection by changing button color
                    if i == current_index then
                        imgui.push_style_color(21, 0xFF5c5c5c) -- Selection hover color
                    end

                    -- Create button for each item
                    local button_height = imgui.calc_text_size(item).y + 4 -- Small padding
                    if imgui.button(item, Vector2f.new(popup_width - imgui.calc_text_size("X").x - 30, button_height)) then
                        new_index = i
                        changed = true
                        imgui.close_current_popup()
                    end

                    -- Add tooltip for items that are wider than popup
                    local item_width = imgui.calc_text_size(item).x
                    if item_width > (popup_width - 40) and imgui.is_item_hovered() then
                        imgui.set_tooltip(item)
                    end
                    imgui.same_line()
                    imgui.push_style_color(21, 0xFF714A29) -- Button color
                    imgui.push_style_color(22, 0xFFfa9642) -- Button hover color
                    imgui.push_style_var(imgui.ImGuiStyleVar.ButtonTextAlign, Vector2f.new(0.5, 0.5))
                    if imgui.button("X", Vector2f.new(imgui.calc_text_size("X").x + 10, button_height)) then
                        table.remove(items, i)
                        if current_index == i then
                            new_index = 0
                        elseif current_index > i then
                            new_index = current_index - 1
                        end
                        changed = true
                    end
                    if imgui.is_item_hovered() then
                        imgui.set_tooltip("Remove item")
                    end
                    imgui.pop_style_var()
                    imgui.pop_style_color(2)

                    -- Pop the selection color if it was pushed
                    if i == current_index then
                        imgui.pop_style_color()
                    end

                    imgui.pop_id() -- Pop button ID
                end
            end
        end

        if imgui.is_key_down(imgui.ImGuiKey.Key_Enter) or imgui.is_key_down(imgui.ImGuiKey.Key_KeypadEnter) then
            local filter_text = State.hybrid_combo_text[label] or ""
            if filter_text ~= "" then
                -- Check if already exists
                local exists = false
                for _, item in ipairs(items) do
                    if item == filter_text then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(items, filter_text)
                    new_index = #items
                    changed = true
                    imgui.close_current_popup()
                end
            end
        end


        -- Pop the styling
        imgui.pop_style_color(2)
        imgui.pop_style_var(6)

        imgui.end_table()
        -- set whole table background to
        imgui.table_set_bg_color(0, 0x00714A29, 0)


        imgui.end_popup()
    end

     -- Open popup if needed
    if should_open_popup then
        imgui.open_popup(popup_id)
    end

    imgui.pop_id() -- Pop combo ID

    return changed, new_index, items
end

-- ========================================
-- Enum Utilities
-- ========================================

function Utils.generate_enum(typename)
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

-- ========================================
-- Table Utilities
-- ========================================

function Utils.get_sorted_keys(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

function Utils.pretty_print_pins(pins)
    local str = ""
    if pins.inputs then
        str = str .. "\n  Inputs:"
        for _, pin in ipairs(pins.inputs) do
            str = str .. "\n    { id: " .. tostring(pin.id) .. ", name: \"" .. tostring(pin.name) .. "\""
            if pin.connection then
                 str = str .. ", connection: " .. tostring(pin.connection)
            end
            str = str .. " }"
        end
    end
    if pins.outputs then
        str = str .. "\n  Outputs:"
        for _, pin in ipairs(pins.outputs) do
             str = str .. "\n    { id: " .. tostring(pin.id) .. ", name: \"" .. tostring(pin.name) .. "\""
             if pin.connections and #pin.connections > 0 then
                 str = str .. ", connections: ["
                 for _, conn in ipairs(pin.connections) do
                     str = str .. "\n      { node: " .. tostring(conn.node) .. ", pin: " .. tostring(conn.pin) .. ", link: " .. tostring(conn.link) .. " },"
                 end
                 str = str .. "\n    ]"
             else
                 str = str .. ", connections: []"
             end
             str = str .. " }"
        end
    end
    return str
end

-- ========================================
-- Copy/Paste Helpers
-- ========================================

-- Deep copy a node, handling special types
function Utils.deep_copy_node(node)
    if type(node) ~= "table" then
        return node
    end
    
    local copy = {}
    for key, value in pairs(node) do
        if type(value) == "table" then
            -- Recursively copy tables
            copy[key] = Utils.deep_copy_node(value)
        elseif type(value) == "userdata" then
            -- Cannot copy userdata - will need to be re-evaluated on paste
            copy[key] = nil
        elseif type(value) == "function" then
            -- Keep function references
            copy[key] = value
        else
            -- Copy primitives directly
            copy[key] = value
        end
    end
    
    return copy
end

-- Generate new IDs for a node and build ID mapping
function Utils.generate_new_node_ids(node, id_map)
    local old_node_id = node.id
    local new_node_id = State.node_id_counter
    State.node_id_counter = State.node_id_counter + 1
    
    -- Map old to new node ID
    id_map.nodes[old_node_id] = new_node_id
    node.id = new_node_id
    
    -- Generate new pin IDs
    if node.input_pin_id then
        local new_input_pin = State.node_id_counter
        State.node_id_counter = State.node_id_counter + 1
        id_map.pins[node.input_pin_id] = new_input_pin
        node.input_pin_id = new_input_pin
    end
    
    if node.output_pin_id then
        local new_output_pin = State.node_id_counter
        State.node_id_counter = State.node_id_counter + 1
        id_map.pins[node.output_pin_id] = new_output_pin
        node.output_pin_id = new_output_pin
    end
    
    -- Handle pins.inputs and pins.outputs (standard pin structure)
    if node.pins then
        if node.pins.inputs then
            for _, pin in ipairs(node.pins.inputs) do
                local old_pin_id = pin.id
                local new_pin_id = State.node_id_counter
                State.node_id_counter = State.node_id_counter + 1
                id_map.pins[old_pin_id] = new_pin_id
                pin.id = new_pin_id
                
                -- Clear connection data (will be remapped from links)
                pin.connection = nil
            end
        end
        
        if node.pins.outputs then
            for _, pin in ipairs(node.pins.outputs) do
                local old_pin_id = pin.id
                local new_pin_id = State.node_id_counter
                State.node_id_counter = State.node_id_counter + 1
                id_map.pins[old_pin_id] = new_pin_id
                pin.id = new_pin_id
                
                -- Clear connections data (will be remapped from links)
                pin.connections = {}
            end
        end
    end
    
    return node
end

-- Remap link IDs based on ID mapping
-- Handles both internal links (both nodes in map) and external links (only target in map)
function Utils.remap_link_ids(link, id_map)
    -- Generate new link ID
    link.id = State.node_id_counter
    State.node_id_counter = State.node_id_counter + 1
    
    -- Remap node and pin IDs if they exist in mapping
    -- If not in mapping (external node), preserve original ID
    link.from_node = id_map.nodes[link.from_node] or link.from_node
    link.to_node = id_map.nodes[link.to_node] or link.to_node
    link.from_pin = id_map.pins[link.from_pin] or link.from_pin
    link.to_pin = id_map.pins[link.to_pin] or link.to_pin
    
    return link
end

return Utils