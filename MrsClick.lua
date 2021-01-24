-- MouselookStop() prevents clicks on 3D models in the WorldFrame from setting the player's target (even if mouse look was never started)

local mrsclick_frame = CreateFrame("Frame")
mrsclick_frame.name = "Mrs Click"

local saved_variables_per_character = {
    -- At startup, before user config is loaded, ignore configurable behavior
    allow_autoattack = true,
    autoattack_only_outside_instances = false
}

local interactable = false

-- Have to check for interactables on mousedown because "mouseover" UnitId is nil during mouseup
WorldFrame:HookScript("OnMouseDown", function (self, button)
    if button == "RightButton" then
        interactable = false
        mrsclick_frame:RegisterEvent("CURSOR_UPDATE")
        ResetCursor() -- Produces CURSOR_UPDATE event (actually produces two) iff cursor is non-default (interactable or attackable)
        mrsclick_frame:UnregisterEvent("CURSOR_UPDATE") -- in case we didn't get a CURSOR_EVENT
    end
end)
    
WorldFrame:HookScript("OnMouseUp", function (self, button)
    if button == "RightButton" and not interactable then
        MouselookStop()
    end
end)

-- some doors, totems, bombs, etc. "exist", are "alive", are "attackable", and even have a level from UnitLevel, but their tooltips don't include "Level (\d+|\?\?)"
local function no_level_in_tooltip()
    local tooltip = GameTooltip
    local tooltip_text_left_string = "GameTooltipTextLeft"
    local lines = tooltip:NumLines()
    for i = 1, lines do
        local line = _G[tooltip_text_left_string .. i]:GetText()
        if strfind(line, "Level ??", 1, true) or strfind(line, "Level %d+") then
            return false
        end
    end
    return true
end

local function on_cursor_update(frame)
    -- Unit had a non-default cursor (player can interact with it or autoattack it)
    interactable = (saved_variables_per_character.allow_autoattack and
                       (not saved_variables_per_character.autoattack_only_outside_instances or
                       select(2, IsInInstance()) == "none")) or
                   -- Check to see if it's a non-autoattack interaction
                   not UnitExists("mouseover") or -- interactables that aren't units
                   UnitIsDead("mouseover") or -- lootable corpses
                   not UnitCanAttack("player", "mouseover") or -- interaction isn't attack
                   -- Let autoattack through for existing target
                   UnitIsUnit("mouseover", "target") or
                   no_level_in_tooltip() -- this catches other misc interactables

    frame:UnregisterEvent("CURSOR_UPDATE") -- If cursor is non-default, we get two CURSOR_UPDATE events, but we only need to check one of them
end

local function enable_disable_nested_check_button(check_button, child_check_button)
    if check_button:GetChecked() then
        child_check_button.isDisabled = false
        child_check_button:Enable()
        child_check_button.label:SetTextColor(WHITE_FONT_COLOR.r, WHITE_FONT_COLOR.g, WHITE_FONT_COLOR.b)
    else
        child_check_button.isDisabled = true
        child_check_button:Disable()
        child_check_button.label:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
    end
end

-- Build options pane
do
    local title = mrsclick_frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetJustifyH("LEFT")
    title:SetJustifyV("TOP")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Mrs Click")

    local desc = mrsclick_frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetNonSpaceWrap(true)
    desc:SetMaxLines(3)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetSize(0, 32)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", -32, 0)
    desc:SetText("Prevents accidental target changes from right clicks.")

    local function check_button_enter(self)
        if not self.isDisabled then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
        end
    end

    local function check_button_sound(check_button)
        if check_button:GetChecked() then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        else
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        end
    end

    local function check_button_click(check_button)
        check_button_sound(check_button)
        if check_button.enable_disable_child then
            enable_disable_nested_check_button(check_button, check_button.enable_disable_child)
        end
    end

    local function create_check_button(text, tooltip, parent)
        local check_button = CreateFrame("CheckButton", nil, parent)
        check_button:SetSize(26, 26)
		check_button:SetHitRectInsets(0, -100, 0, 0)
		check_button:SetNormalTexture("Interface/Buttons/UI-CheckBox-Up")
		check_button:SetPushedTexture("Interface/Buttons/UI-CheckBox-Down")
		check_button:SetHighlightTexture("Interface/Buttons/UI-CheckBox-Highlight", "ADD")
		check_button:SetCheckedTexture("Interface/Buttons/UI-CheckBox-Check")
		check_button:SetDisabledCheckedTexture("Interface/Buttons/UI-CheckBox-Check-Disabled")

		check_button:SetScript("OnClick", check_button_click)

        check_button.tooltip = tooltip
        check_button:SetScript("OnEnter", check_button_enter)
        check_button:SetScript("OnLeave", GameTooltip_Hide)

        local label = check_button:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
		label:SetPoint("LEFT", check_button, "RIGHT", 2, 1)
		label:SetText(text)
        check_button.label = label

		return check_button
    end

    -- Create check buttons
    mrsclick_frame.check_buttons = {
        allow_autoattack = create_check_button("Allow Auto Attack", "Allow right-click auto attacks against untargeted enemies (which will change your target).", mrsclick_frame),
        autoattack_only_outside_instances = create_check_button("Only Outside Instances", "Inside instances, block right-click auto attacks against untargeted enemies to prevent accidental target changes.", mrsclick_frame)
    }

    -- Arrange check buttons
    local mrsclick_frame_check_buttons = mrsclick_frame.check_buttons
    local allow_autoattack_check_button = mrsclick_frame_check_buttons.allow_autoattack
    allow_autoattack_check_button:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -2, -8)
    local autoattack_only_outside_instances_check_button = mrsclick_frame_check_buttons.autoattack_only_outside_instances
    autoattack_only_outside_instances_check_button:SetPoint("TOPLEFT", allow_autoattack_check_button, "BOTTOMLEFT", 16, -8)

    -- "Only outside instances" option is disabled if "allow autoattack" is false
    allow_autoattack_check_button.enable_disable_child = autoattack_only_outside_instances_check_button
end

local event_handlers = {
    CURSOR_UPDATE = on_cursor_update
}

local function on_addon_loaded(frame)
    -- Default options
    local default_saved_variables_per_character = {
        allow_autoattack = false, -- allow right click to auto-attack new targets
        autoattack_only_outside_instances = false -- only allow_autoattack outside instances
    }

    -- Load config
    do
        local mrs_click_saved_variables_per_character = MrsClickSavedVariablesPerCharacter
        if mrs_click_saved_variables_per_character then
            for name, default in pairs(default_saved_variables_per_character) do
                local saved = mrs_click_saved_variables_per_character[name]
                if saved == nil then
                    -- Adds the default value for a new option when user updates
                    saved_variables_per_character = default
                else
                    saved_variables_per_character[name] = saved
                end
            end
        else
            for name, default in pairs(default_saved_variables_per_character) do
                saved_variables_per_character[name] = default
            end
        end
    end

    -- Save config
    event_handlers["PLAYER_LOGOUT"] = function ()
        MrsClickSavedVariablesPerCharacter = saved_variables_per_character
    end
    frame:RegisterEvent("PLAYER_LOGOUT")

    -- Options pane
    function frame:okay()
        for option, check_button in pairs(frame.check_buttons) do
            saved_variables_per_character[option] = check_button:GetChecked()
        end
    end

    function frame:default()
        for name, default in pairs(default_saved_variables_per_character) do
            saved_variables_per_character[name] = default
        end
    end

    function frame:refresh()
        for option, check_button in pairs(frame.check_buttons) do
            check_button:SetChecked(saved_variables_per_character[option])
            if check_button.enable_disable_child then
                enable_disable_nested_check_button(check_button, check_button.enable_disable_child)
            end
        end
    end

    InterfaceOptions_AddCategory(mrsclick_frame)
end

event_handlers["ADDON_LOADED"] = function (frame, addon)
    if addon == "MrsClick" then
        frame:UnregisterEvent("ADDON_LOADED")
        on_addon_loaded(frame)
        event_handlers.addon_loaded = nil
    end
end

mrsclick_frame:SetScript("OnEvent", function(frame, event, addon)
    event_handlers[event](frame, addon)
end)

mrsclick_frame:RegisterEvent("ADDON_LOADED")
