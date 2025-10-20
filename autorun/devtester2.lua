-- DevTester v2.0 - Visual Node-Based Editor for Monster Hunter Wilds
-- Main Entry Point

-- Dependencies
local Config = require("DevTester2.Config")
local Nodes = require("DevTester2.Nodes")
local Helpers = require("DevTester2.Helpers")
local State = require("DevTester2.State")

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


    -- Toggle button in main menu
    if imgui.button("DevTester v2.0") then
        State.window_open = not State.window_open
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
    imgui.push_style_var(3, 7.5) -- Rounded corners
    imgui.push_style_var(12, 5.0) -- Rounding
    imgui.push_style_var(11, Vector2f.new(5, 5)) -- Padding
    
    -- Static window title to preserve window position/size
    local window_title = "DevTester v2.0"
    
    -- Begin window with flags (1024 includes menu bar)
    State.window_open = imgui.begin_window(window_title, State.window_open, 1024)
    
    if State.window_open then
        -- Menu bar
        render_menu_bar()
        
        -- ImNode editor
        render_node_editor()
        
        imgui.end_window()
    end
    
    imgui.pop_id()
    imgui.pop_style_var(3)
    
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
    imgui.push_style_var(2, Vector2f.new(5, 5)) -- Extra padding on menu bar
    
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
                Helpers.create_starter_node(1) -- Managed = 1
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Managed node | sdk.get_managed_singleton")
            end
            if imgui.menu_item("Native") then
                Helpers.create_starter_node(4) -- Native = 4
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Native node | sdk.get_native_singleton")
            end
            if imgui.menu_item("Hook") then
                Helpers.create_starter_node(2) -- Hook = 2
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Create a Hook node to hook native functions")
            end
            imgui.end_menu()
        end
        
        -- Create Primitive button
        if imgui.menu_item("+ Primitive") then
            Helpers.create_starter_node(5) -- Primitive = 5
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Create a Primitive node for basic values (numbers, strings, booleans)")
        end
        
        -- Create Enum button
        if imgui.menu_item("+ Enum") then
            Helpers.create_starter_node(3) -- Enum = 3
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Create an Enum node for enumerated values")
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
    imgui.push_style_color(21, 0xFF714A29) -- Button color (AABBGGRR)
    imgui.push_style_color(22, 0xFFFA9642) -- Button hover color (AABBGGRR)
    imnodes.push_color_style(1, 0xFF3C3C3C) -- Node hover background (AABBGGRR)
    imnodes.push_color_style(2, 0xFF3C3C3C) -- Node selected background (AABBGGRR)
    imnodes.begin_node_editor()
    
    -- Set node width
    imgui.push_item_width(State.NODE_WIDTH)
    
    -- Render all starter nodes
    for _, node in ipairs(State.starter_nodes) do
        Nodes.render_starter_node(node)
        
        -- Position the starter node if it hasn't been positioned yet
        if not State.nodes_positioned[node.node_id] then
            if node.position then
                imnodes.set_node_editor_space_pos(node.node_id, node.position.x, node.position.y)
            end
            State.nodes_positioned[node.node_id] = true
        end
        
        -- Update stored position for starter nodes
        if not node.position then
            node.position = {}
        end
        local current_pos = imnodes.get_node_editor_space_pos(node.node_id)
        node.position.x = current_pos.x
        node.position.y = current_pos.y
    end
    
    -- Render all operation nodes
    for _, node in ipairs(State.all_nodes) do
        if node.node_category == "operation" then
            Nodes.render_operation_node(node)
            
            -- Position the node if it hasn't been positioned yet
            if not State.nodes_positioned[node.node_id] then
                if node.position then
                    imnodes.set_node_editor_space_pos(node.node_id, node.position.x, node.position.y)
                end
                State.nodes_positioned[node.node_id] = true
            end
            
            -- Update stored position
            if not node.position then
                node.position = {}
            end
            local current_pos = imnodes.get_node_editor_space_pos(node.node_id)
            node.position.x = current_pos.x
            node.position.y = current_pos.y
        end
    end
    
    -- Pop node width
    imgui.pop_item_width()
    
    -- Render all links
    for _, link in ipairs(State.all_links) do
        -- Check if the target node is paused
        local target_node = Helpers.get_node_by_id(link.to_node)
        if target_node and target_node.is_paused then
            -- Render paused link in dark red
            imnodes.push_color_style(7, 0x80142196) -- Link color (AABBGGRR) - Dark red
            imnodes.link(link.id, link.from_pin, link.to_pin)
            imnodes.pop_color_style()
        else
            -- Normal link
            imnodes.link(link.id, link.from_pin, link.to_pin)
        end
    end
    
    imnodes.minimap(0.2, 0) -- 0.2 = 20% size, 0 = bottom-left corner
    
    imnodes.end_node_editor()
    
    -- Pop styles
    imnodes.pop_color_style(2)
    imgui.pop_style_color(2)
    
    -- Handle link creation
    local link_created, start_node_id, start_pin, end_node_id, end_pin = imnodes.is_link_created()
    if link_created then
        Helpers.handle_link_created(start_pin, end_pin)
    end
    
    -- Handle link destruction
    local link_destroyed, link_id = imnodes.is_link_destroyed()
    
    if link_destroyed then
        log.debug("Link destroyed: " .. tostring(link_id))
        Helpers.handle_link_destroyed(link_id)
    end
    
    -- Handle delete key for selected links
    if imgui.is_key_pressed(imgui.ImGuiKey.Key_Delete) then
        local selected_links = imnodes.get_selected_links()
        for _, link_id in ipairs(selected_links) do
            -- Check if this link is connected to a title input attribute (main input pin)
            local link = Helpers.get_link_by_id(link_id)
            if link then
                local to_node = Helpers.get_node_by_id(link.to_node)
                if to_node and to_node.node_category == "operation" then
                    -- Check if the target pin is not the main input attribute (title input)
                    if link.to_pin ~= to_node.input_attr then
                        Helpers.handle_link_destroyed(link_id)
                    end
                else
                    Helpers.handle_link_destroyed(link_id)
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
                re.msg("Error trying to load configuration @ index " .. (State.selected_config_index ))
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
        Helpers.show_success("Configuration saved successfully")
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
        Helpers.show_error(error_msg or "Failed to save configuration")
    end
end

-- Handle load
function handle_load(config_path)
    -- Extract and display the config name
    local config_name = Config.get_filename_without_extension(config_path)
    
    if Helpers.has_unsaved_changes() then
        Helpers.show_info("Loading '" .. config_name .. "' (unsaved changes will be lost)")
    end
    
    local success, error_msg = Config.load_configuration(config_path)
    if success then
        Helpers.show_success("Configuration '" .. config_name .. "' loaded successfully")
        State.available_configs = {} -- Reset to force re-scan next time
    else
        Helpers.show_error(error_msg or "Failed to load configuration")
    end
end

-- Handle clear nodes
function handle_clear_nodes()
    if Helpers.get_node_count() == 0 then
        return
    end
    
    if Helpers.has_unsaved_changes() then
        Helpers.show_info("Clearing all nodes (unsaved changes will be lost)")
    end
    
    Helpers.clear_all_nodes()
    -- Reset node positioning state so nodes are repositioned after clear
    for k in pairs(State.nodes_positioned) do
        State.nodes_positioned[k] = nil
    end
    State.current_config_name = nil
    Helpers.mark_as_saved()
    Helpers.show_info("All nodes cleared")
end
