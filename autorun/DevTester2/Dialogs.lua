local Constants = require("DevTester2.Constants")
local imgui = imgui

local Dialogs = {}

Dialogs.confirmation = {
    open = false,
    title = "",
    message = "",
    callback = nil,
    cancel_callback = nil,
}

function Dialogs.show_confirmation(title, message, confirmation_callback, cancel_callback)
    Dialogs.confirmation.open = true
    Dialogs.confirmation.title = title
    Dialogs.confirmation.message = message
    Dialogs.confirmation.callback = confirmation_callback
    Dialogs.confirmation.cancel_callback = cancel_callback
end

function Dialogs.render()
    
    imgui.push_style_var(imgui.ImGuiStyleVar.WindowPadding, Constants.POP_PADDING)
    imgui.push_style_var(imgui.ImGuiStyleVar.PopupRounding, Constants.FRAME_ROUNDING)
    

    if Dialogs.confirmation.open then
       imgui.open_popup("dev_confirmation", 64)
    end
    if imgui.begin_popup_context_item("dev_confirmation") then
        log.debug("Showing confirmation popup")
        imgui.text_colored(Dialogs.confirmation.title, Constants.COLOR_TEXT_ERROR)
        imgui.spacing()
       
        imgui.text(Dialogs.confirmation.message)
        imgui.spacing()
        imgui.separator()
        imgui.spacing()
        if imgui.button("Confirm") then
            imgui.close_current_popup()
            Dialogs.confirmation.open = false
            if Dialogs.confirmation.callback then Dialogs.confirmation.callback() end
        end
        imgui.same_line()
        -- Right align cancel button in popup window
        local cancel_text_size = imgui.calc_text_size("Cancel")
        local cursor_pos = imgui.get_cursor_pos()
        local window_width = imgui.get_window_size().x
        cursor_pos.x = window_width - cancel_text_size.x - (Constants.POP_PADDING.x * 2)
        imgui.set_cursor_pos(cursor_pos)
        if imgui.button("Cancel") then
            imgui.close_current_popup()
            Dialogs.confirmation.open = false
            if Dialogs.confirmation.cancel_callback then Dialogs.confirmation.cancel_callback() end
        end
        imgui.end_popup()
    end
    imgui.pop_style_var(2)
    
    if imgui.is_key_pressed(imgui.ImGuiKey.Key_Escape) then
       Dialogs.close_all_popups()
    end
end

function Dialogs.close_all_popups()
    imgui.close_current_popup()
    Dialogs.confirmation.open = false
end

return Dialogs