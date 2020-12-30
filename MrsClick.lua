-- MouselookStop() prevents clicks on 3D models in the WorldFrame from setting the player's target (even if mouse look was never entered)

local mrsclick_frame = CreateFrame("Frame")

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

-- GUID is only easy way to distinguish pets/creatures/vehicles/etc.
-- If this and UnitCreatureType == "Not specified" aren't enough, we'll probably have to examine tooltips
local function guid_check(target)
    local guid = UnitGUID("mouseover")
    local first_dash_pos = strfind(guid, "-", 1, true)
    local guid_type = strsub(guid, 1, first_dash_pos - 1)
    return guid_type == "Vehicle" or guid_type == "GameObject"
end

mrsclick_frame:SetScript("OnEvent", function (self, event)
    if event == "CURSOR_UPDATE" then
        -- Unit had a special cursor (player can interact with it or autoattack it)
        if not UnitExists("mouseover") or -- allow right click for non-unit objects like portals or levers
           UnitIsDead("mouseover") or -- allow right click for lootable corpses
           not UnitCanAttack("player", "mouseover") or -- no right click for attackable units...
           UnitIsUnit("mouseover", "target") or -- ...unless they're the player's target
           UnitCreatureType("mouseover") == "Not specified" or -- some doors, totems, etc. "exist" and are "attackable" even though the player can't target or attack them
           guid_check("mouseover") then -- Some interactables (e.g., squirrel bombs) are "attackable" creatures, but get their interaction from being "Vehicles"
            interactable = true
        end
        mrsclick_frame:UnregisterEvent("CURSOR_UPDATE") -- If cursor is non-default, we get two CURSOR_UPDATE events, but we only need to check one of them
    end
end)
