-- DevTester v2.0 - Visual Node-Based Editor for Monster Hunter Wilds
-- Main Entry Point

-- Dependencies
local Config = require("DevTester2.Config")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local State = require("DevTester2.State")
local Constants = require("DevTester2.Constants")
local Dialogs = require("DevTester2.Dialogs")

-- Node type modules
local ManagedStarter = require("DevTester2.Starters.ManagedStarter")
local HookStarter = require("DevTester2.Starters.HookStarter")
local NativeStarter = require("DevTester2.Starters.NativeStarter")
local EnumData = require("DevTester2.Datas.EnumData")
local PrimitiveData = require("DevTester2.Datas.PrimitiveData")
local MethodFollower = require("DevTester2.Followers.MethodFollower")
local FieldFollower = require("DevTester2.Followers.FieldFollower")
local ArrayFollower = require("DevTester2.Followers.ArrayFollower")
local InvertOperation = require("DevTester2.Operations.InvertOperation")
local MathOperation = require("DevTester2.Operations.MathOperation")
local LogicOperation = require("DevTester2.Operations.LogicOperation")
local CompareOperation = require("DevTester2.Operations.CompareOperation")
local SelectControl = require("DevTester2.Control.SelectControl")

-- Local references
local re = re
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

-- Initialization flag
local initialized = false

-- Initialize the mod
local function initialize()
    if initialized then
        return -- Already initialized
    end
    
    initialized = true
end

-- Main draw function
re.on_draw_ui(function()

    -- Load Data.json on first draw to restore window state
    if not initialized then
        Config.load_data_config()
        initialized = true
    end
    if imgui.button("DevTester v2.0") then
        State.window_open = not State.window_open
        -- Save window state to Data.json
        Config.save_data_config()
    end
    
    if not State.window_open then
        return
    end
    
    -- Initialize on first open
    if not initialized then
        initialize()
    end
    
    imgui.push_id("DevTester2")

    -- Main window
    imgui.push_style_var(imgui.ImGuiStyleVar.Alpha, 0.9) -- Window transparency
    imgui.push_style_var(imgui.ImGuiStyleVar.WindowRounding, Constants.WINDOW_ROUNDING) -- Window rounded corners
    imgui.push_style_var(imgui.ImGuiStyleVar.FrameRounding, Constants.FRAME_ROUNDING) -- Frame rounded corners
    imgui.push_style_var(imgui.ImGuiStyleVar.FramePadding, Constants.FRAME_PADDING) -- Frame padding

    -- Static window title to preserve window position/size
    local window_title = "DevTester v2.0"
    

    -- Begin window with flags (1024 includes menu bar)
    local was_open = State.window_open
    State.window_open = imgui.begin_window(window_title, State.window_open, 1024)
    
    -- Save window state if it changed (closed via X button)
    if was_open and not State.window_open then
        Config.save_data_config()
    end
    
    if State.window_open then
        -- Menu bar
        render_menu_bar()
        
        -- ImNode editor
        render_node_editor()
        
        imgui.end_window()
    end

    Dialogs.render()
    
    imgui.pop_style_var(4)
    imgui.pop_id()
    
end)

-- Cleanup on script unload
re.on_script_reset(function()
    -- Remove all hooks
    for _, node in ipairs(State.starter_nodes) do
        if node.type == 2 and node.hook_id then -- Hook type
            -- sdk.hook_remove(node.hook_id)
        end
    end
end)

-- Menu bar rendering
function render_menu_bar()
    imgui.push_style_var(2, Constants.MENU_PADDING) -- Extra padding on menu bar
    
    if imgui.begin_menu_bar() then
        -- File menu
        if imgui.begin_menu("File  ▼") then
            -- Save submenu
            if imgui.begin_menu("Save") then
                render_save_menu()
                imgui.end_menu()
            end
            
            -- Load submenu
            if imgui.begin_menu("Load") then
                render_load_menu()
                imgui.end_menu()
            end
            
            -- Clear Nodes
            if imgui.menu_item("Clear Nodes") then
                handle_clear_nodes()
            end
            
            imgui.end_menu()
        end
        
        -- Create Starter dropdown menu
        if imgui.begin_menu("+ Create Starter  ▼") then
            if imgui.menu_item("Managed") then
                Nodes.create_starter_node(Constants.NODE_CATEGORY_STARTER, Constants.STARTER_TYPE_MANAGED) -- Managed
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Managed node | sdk.get_managed_singleton")
            end
            if imgui.menu_item("Native") then
                Nodes.create_starter_node(Constants.NODE_CATEGORY_STARTER, Constants.STARTER_TYPE_NATIVE) -- Native
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Native node | sdk.get_native_singleton")
            end
            if imgui.menu_item("Hook") then
                Nodes.create_starter_node(Constants.NODE_CATEGORY_STARTER, Constants.STARTER_TYPE_HOOK) -- Hook
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Hook node to hook native functions")
            end
            imgui.end_menu()
        end
        
        -- Create Data dropdown menu
        if imgui.begin_menu("+ Create Data  ▼") then
            if imgui.menu_item("Primitive") then
                Nodes.create_starter_node(Constants.NODE_CATEGORY_DATA, Constants.DATA_TYPE_PRIMITIVE) -- Primitive
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Primitive node for basic values (numbers, strings, booleans)")
            end
            
            if imgui.menu_item("Enum") then
                Nodes.create_starter_node(Constants.NODE_CATEGORY_DATA, Constants.DATA_TYPE_ENUM) -- Enum
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create an Enum node for enumerated values")
            end
            imgui.end_menu()
        end
        
        -- Create Operations dropdown menu
        if imgui.begin_menu("+ Create Operations  ▼") then
            if imgui.menu_item("Invert") then
                Nodes.create_operations_node(Constants.NODE_CATEGORY_OPERATIONS, Constants.OPERATIONS_TYPE_INVERT) -- Invert
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create an Invert node that inverts boolean values")
            end
            
            if imgui.menu_item("Math") then
                Nodes.create_operations_node(Constants.NODE_CATEGORY_OPERATIONS, Constants.OPERATIONS_TYPE_MATH) -- Math
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Math node that performs mathematical operations on two numbers")
            end
            
            if imgui.menu_item("Logic") then
                Nodes.create_operations_node(Constants.NODE_CATEGORY_OPERATIONS, Constants.OPERATIONS_TYPE_LOGIC) -- Logic
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Logic node that performs boolean logic operations (AND/OR/NAND/NOR)")
            end
            
            if imgui.menu_item("Compare") then
                Nodes.create_operations_node(Constants.NODE_CATEGORY_OPERATIONS, Constants.OPERATIONS_TYPE_COMPARE) -- Compare
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Compare node that performs comparison operations (Equals/Not Equals/Greater/Less)")
            end
            imgui.end_menu()
        end
        
        -- Create Control dropdown menu
        if imgui.begin_menu("+ Create Control  ▼") then
            if imgui.menu_item("Select") then
                Nodes.create_operations_node(Constants.NODE_CATEGORY_CONTROL, Constants.CONTROL_TYPE_SELECT) -- Select
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Select node that selects between two values based on a condition")
            end
            imgui.end_menu()
        end
        
        imgui.end_menu_bar()
    end
    
    imgui.pop_style_var(1)
end

-- Node editor rendering
-- Use State for node positioning tracking
State.nodes_positioned = State.nodes_positioned or {}

function render_node_editor()
    -- Add some styling for the node editor
    imgui.push_style_color(21, Constants.COLOR_BUTTON_NORMAL)
    imgui.push_style_color(22, Constants.COLOR_BUTTON_HOVER)
    imnodes.push_color_style(1, Constants.NODE_COLOR_DEFAULT_HOVER)
    imnodes.push_color_style(2, Constants.NODE_COLOR_DEFAULT_SELECTED)

    imnodes.begin_node_editor()
    
    -- Set node width
    imgui.push_item_width(Constants.NODE_WIDTH)
    
    -- Create combined list of all nodes for unified rendering
    local all_nodes_to_render = {}
    
    -- Add starter nodes
    for _, node in ipairs(State.starter_nodes) do
        table.insert(all_nodes_to_render, node)
    end
    
    -- Add data nodes
    for _, node in ipairs(State.data_nodes) do
        table.insert(all_nodes_to_render, node)
    end
    
    -- Add operation/follower/control nodes
    for _, node in ipairs(State.all_nodes) do
        table.insert(all_nodes_to_render, node)
    end
    
    -- Unified rendering loop for all nodes
    for _, node in ipairs(all_nodes_to_render) do
        -- Render based on category
        if node.category == Constants.NODE_CATEGORY_STARTER then
            local category, type = Utils.parse_category_and_type(node.category, node.type)
            imgui.push_item_width(Nodes.get_node_width(category, type))
            Nodes.set_node_titlebar_color(Nodes.get_node_titlebar_color(category, type))

            if node.type == Constants.STARTER_TYPE_MANAGED then
                ManagedStarter.render(node)
            elseif node.type == Constants.STARTER_TYPE_HOOK then
                HookStarter.render(node)
            elseif node.type == Constants.STARTER_TYPE_NATIVE then
                NativeStarter.render(node)
            end

            imgui.pop_item_width()
            Nodes.reset_node_titlebar_color()
            
        elseif node.category == Constants.NODE_CATEGORY_DATA then
            local category, type = Utils.parse_category_and_type(node.category, node.type)
            imgui.push_item_width(Nodes.get_node_width(category, type))
            Nodes.set_node_titlebar_color(Nodes.get_node_titlebar_color(category, type))

            if node.type == Constants.DATA_TYPE_ENUM then
                EnumData.render(node)
            elseif node.type == Constants.DATA_TYPE_PRIMITIVE then
                PrimitiveData.render(node)
            end

            imgui.pop_item_width()
            Nodes.reset_node_titlebar_color()
            
        elseif node.category == Constants.NODE_CATEGORY_FOLLOWER then
            local category, type = Utils.parse_category_and_type(node.category, node.type)
            imgui.push_item_width(Nodes.get_node_width(category, type))
            Nodes.set_node_titlebar_color(Nodes.get_node_titlebar_color(category, type))

            if node.type == Constants.FOLLOWER_TYPE_METHOD then
                MethodFollower.render(node)
            elseif node.type == Constants.FOLLOWER_TYPE_FIELD then
                FieldFollower.render(node)
            elseif node.type == Constants.FOLLOWER_TYPE_ARRAY then
                ArrayFollower.render(node)
            end

            imgui.pop_item_width()
            Nodes.reset_node_titlebar_color()
            
        elseif node.category == Constants.NODE_CATEGORY_OPERATIONS then
            local category, type = Utils.parse_category_and_type(node.category, node.type)
            imgui.push_item_width(Nodes.get_node_width(category, type))
            Nodes.set_node_titlebar_color(Nodes.get_node_titlebar_color(category, type))

            if node.type == Constants.OPERATIONS_TYPE_INVERT then
                InvertOperation.render(node)
            elseif node.type == Constants.OPERATIONS_TYPE_MATH then
                MathOperation.render(node)
            elseif node.type == Constants.OPERATIONS_TYPE_LOGIC then
                LogicOperation.render(node)
            elseif node.type == Constants.OPERATIONS_TYPE_COMPARE then
                CompareOperation.render(node)
            end

            imgui.pop_item_width()
            Nodes.reset_node_titlebar_color()
            
        elseif node.category == Constants.NODE_CATEGORY_CONTROL then
            local category, type = Utils.parse_category_and_type(node.category, node.type)
            imgui.push_item_width(Nodes.get_node_width(category, type))
            Nodes.set_node_titlebar_color(Nodes.get_node_titlebar_color(category, type))

            if node.type == Constants.CONTROL_TYPE_SELECT then
                SelectControl.render(node)
            end

            imgui.pop_item_width()
            Nodes.reset_node_titlebar_color()
        end
        
        -- Unified positioning logic for all nodes
        if not State.nodes_positioned[node.node_id] then
            if node.position then
                imnodes.set_node_editor_space_pos(node.node_id, node.position.x, node.position.y)
            end
            State.nodes_positioned[node.node_id] = true
        end
        
        -- Update stored position for all nodes
        if not node.position then
            node.position = {}
        end
        local current_pos = imnodes.get_node_editor_space_pos(node.node_id)
        node.position.x = current_pos.x
        node.position.y = current_pos.y
    end
    
    -- Pop node width
    imgui.pop_item_width()
    
    -- Render all links
    for _, link in ipairs(State.all_links) do
        -- Check if the target node is paused
        local target_node = Nodes.find_node_by_id(link.to_node)
        if target_node and target_node.is_paused then
            -- Render paused link in dark red
            imnodes.push_color_style(7, Constants.COLOR_DISABLED) -- Link color
            imnodes.link(link.id, link.from_pin, link.to_pin)
            imnodes.pop_color_style()
        else
            -- Normal link
            imnodes.link(link.id, link.from_pin, link.to_pin)
        end
    end
    
    imnodes.minimap(Constants.MINIMAP_SIZE, Constants.MINIMAP_POSITION) -- Size and position
    
    imnodes.end_node_editor()
    
    -- Pop styles
    imnodes.pop_color_style(2)
    imgui.pop_style_color(2)
    
    -- Handle link creation
    local link_created, start_node_id, start_pin, end_node_id, end_pin = imnodes.is_link_created()
    if link_created then
        Nodes.handle_link_created(start_pin, end_pin)
    end
    
    -- Handle link destruction
    local link_destroyed, link_id = imnodes.is_link_destroyed()
    
    if link_destroyed then
        log.debug("Link destroyed: " .. tostring(link_id))
        Nodes.handle_link_destroyed(link_id)
    end
    
    -- Handle delete key for selected links
    if imgui.is_key_pressed(imgui.ImGuiKey.Key_Delete) then
        local selected_links = imnodes.get_selected_links()
        for _, link_id in ipairs(selected_links) do
            local link = Nodes.get_link_by_id(link_id)
            if link then
                local to_node = Nodes.find_node_by_id(link.to_node)
                if to_node and to_node.category == Constants.NODE_CATEGORY_FOLLOWER then
                    -- Check if the target pin is not the main input attribute (title input)
                    if link.to_pin ~= to_node.input_attr then
                        Nodes.handle_link_destroyed(link_id)
                    end
                else
                    Nodes.handle_link_destroyed(link_id)
                end
            end
        end
        -- Clear selection after deletion
        imnodes.clear_link_selection()
    end
end

-- Save menu rendering
function render_save_menu()
    imgui.spacing()
    imgui.text("Enter a save name:")
    
    -- Initialize save name with current config name
    if State.save_name_input == "" and State.current_config_name then
        State.save_name_input = State.current_config_name
    end
    
    local name_changed, new_name = imgui.input_text("##FileName", State.save_name_input)
    if name_changed then
        State.save_name_input = new_name
    end
    
    imgui.text("Description:")
    local desc_changed, new_desc = imgui.input_text("##description", 
        State.save_description_input)
    if desc_changed then
        State.save_description_input = new_desc
    end
    
    if imgui.button("Save") then
        handle_save(State.save_name_input, State.save_description_input)
    end
    
    imgui.spacing()
end

-- Load menu rendering
function render_load_menu()
    imgui.spacing()
    imgui.text("Select a file to load:")
    
    -- Scan for configs if not already done
    if #State.available_configs == 0 then
        State.available_configs = Config.scan_available_configs()
    end
    
    -- Build display names
    local config_names = {}
    for _, config in ipairs(State.available_configs) do
        table.insert(config_names, config.display)
    end
    
    if #config_names > 0 then
        -- Always default to first config if not set or out of range
        if not State.selected_config_index or State.selected_config_index < 1 or State.selected_config_index > #config_names then
            State.selected_config_index = 1
        end
        local changed, new_index = imgui.combo("Files", State.selected_config_index, config_names)
        if changed then
            State.selected_config_index = new_index
        end
        
        if imgui.button("Load") then
            local config = State.available_configs[State.selected_config_index]
            if config then
                handle_load(config.path)
            else
                Utils.show_error("Error trying to load configuration @ index " .. (State.selected_config_index ))
            end
        end
    else
        imgui.text("No saved configurations found")
    end
    
    imgui.spacing()
end

-- Handle save
function handle_save(name, description)
    local success, error_msg = Config.save_configuration(name, description)
    if success then
        Utils.show_info("Configuration saved successfully")
        State.save_description_input = "" -- Clear description
        -- Refresh config list after save
        State.available_configs = Config.scan_available_configs()
        -- Set selected index to the newly saved config if possible
        for i, config in ipairs(State.available_configs) do
            if config.name == name then
                State.selected_config_index = i
                break
            end
        end
        -- Keep name for easy re-save
    else
        Utils.show_error(error_msg or "Failed to save configuration")
    end
end

-- Handle load
function handle_load(config_path)
    -- Extract and display the config name
    local config_name = Config.get_filename_without_extension(config_path)
    
    local function perform_load()
        local success, error_msg = Config.load_configuration(config_path)
        if success then
            Utils.show_info("Configuration '" .. config_name .. "' loaded successfully")
            State.available_configs = {} -- Reset to force re-scan next time
        else
            Utils.show_error(error_msg or "Failed to load configuration")
        end
    end
    
    if State.has_unsaved_changes() then
        Dialogs.show_confirmation(
            "Load Configuration",
            "Loading '" .. config_name .. "' will discard unsaved changes. Are you sure?",
            perform_load
        )
    else
        perform_load()
    end
end

-- Handle clear nodes
function handle_clear_nodes()
    if Nodes.get_node_count() == 0 then
        return
    end
    
    local function perform_clear()
        Nodes.clear_all_nodes()
        -- Reset node positioning state so nodes are repositioned after clear
        for k in pairs(State.nodes_positioned) do
            State.nodes_positioned[k] = nil
        end
        State.current_config_name = nil
        State.mark_as_saved()
        Utils.show_info("All nodes cleared")
    end
    
    if State.has_unsaved_changes() then
        log.debug("Prompting confirmation to clear nodes with unsaved changes")
        Dialogs.show_confirmation(
            "Clear All Nodes",
            "Are you sure you want to clear all nodes?\nUnsaved changes will be lost.",
            function() log.debug("Clearing all nodes confirmed by user") perform_clear() end,
            function() log.debug("Clear nodes cancelled by user") end
        )
    else
        perform_clear()
    end
end

function handle_context_menu()

end
