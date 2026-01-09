-- PlayerStarter Hook properties
-- This node retrieves the HunterCharacter object for the player.
--
-- Configuration:
-- - path: String - The SDK path to the HunterCharacter object (default: "app.HunterCharacter")
--
-- Pins:
-- - pins.outputs[1]: "output" - The HunterCharacter object
--
-- Runtime Values:
-- - ending_value: Object - The HunterCharacter object retrieved
--
-- UI/Debug:
-- - status: String - Current status message


local State = require("DevTester2.State")
local Nodes = require("DevTester2.Nodes")
local Utils = require("DevTester2.Utils")
local BaseStarter = require("DevTester2.Starters.BaseStarter")
local Constants = require("DevTester2.Constants")
local imgui = imgui
local imnodes = imnodes
local sdk = sdk

local PlayerStarter = {}
local game = reframework:get_game_name()
log.debug("Loading PlayerStarter for " .. game)


function PlayerStarter.render(node)

    

    -- Ensure output pin exists
    if #node.pins.outputs == 0 then
        Nodes.add_output_pin(node, "output", nil)
    end

    local output_pin = node.pins.outputs[1]

    -- Logic to get HunterCharacter
    node.ending_value = nil
    node.status = "Unknown"
    local player_manager = nil

    -- MH WILDS
    if game == "mhwilds" then 
        player_manager = sdk.get_managed_singleton("app.PlayerManager")
        node.path = "app.HunterCharacter"
        node.process_path = "app.PlayerManager|getMasterPlayerInfo():get_Character()"
        if player_manager then
            local player = player_manager:getMasterPlayerInfo()
            if player then
                local character = player:get_Character()
                if character then
                    node.ending_value = character
                    node.status = "Success"
                else
                    node.status = "HunterCharacter not found"
                end
            else
                node.status = "MasterPlayerInfo not found"
            end
        else
            node.status = "PlayerManager singleton not found"
        end

    -- MH RISE
    elseif game == "mhrise" then 
        player_manager = sdk.get_managed_singleton("snow.player.PlayerManager")
        if player_manager then
            local player = player_manager:findMasterPlayer()
            node.path = "snow.Player.PlayerManager"
            node.process_path = "snow.Player.PlayerManager|findMasterPlayer()"
            if player then
                node.ending_value = player
                node.status = "Success"
            else
                node.status = "MasterPlayer not found"
            end
        else
            node.status = "PlayerManager singleton not found"
        end
    else
        node.status = "Unsupported game: " .. game
    end
    

    -- Always sync output pin value with ending_value on every render
    output_pin.value = node.ending_value

    imnodes.begin_node(node.id)

    imnodes.begin_node_titlebar()
    imgui.text("Player Starter")
    imnodes.end_node_titlebar()

    imgui.begin_disabled()
    imgui.input_text("##Path", node.process_path)
    imgui.end_disabled()
    imgui.spacing()
    imgui.spacing()

    imnodes.begin_output_attribute(output_pin.id)

    if node.ending_value then
        local display_value = Utils.get_value_display_string(node.ending_value)
        local type_info = node.ending_value:get_type_definition()

        Nodes.add_context_menu_option(node, "Copy output name", type_info:get_full_name())
        
        -- Output pin
        local debug_pos = Utils.get_right_cursor_pos(node.id, display_value .. " (?)")
        imgui.set_cursor_pos(debug_pos)
        imgui.text(display_value)
        imgui.same_line()
        imgui.text("(?)")
        if imgui.is_item_hovered() then
            imgui.set_tooltip(Utils.get_tooltip_for_value(node.ending_value))
        end
    else
        local text = "Output: nil"
        local debug_pos = Utils.get_right_cursor_pos(node.id, text)
        imgui.set_cursor_pos(debug_pos)
        imgui.text(text)
    end
    imnodes.end_output_attribute()

    imgui.spacing()

    BaseStarter.render_action_buttons(node)
    BaseStarter.render_debug_info(node)

    imnodes.end_node()
end

-- ========================================
-- Serialization
-- ========================================

function PlayerStarter.serialize(node, Config)
    -- PlayerStarter has no additional fields beyond BaseStarter
    return BaseStarter.serialize(node, Config)
end

function PlayerStarter.deserialize(data, Config)
    local node = BaseStarter.deserialize(data, Config)
    -- Add any PlayerStarter-specific fields here if needed
    node.process_path = "" -- Initialize process_path
    return node
end

return PlayerStarter
