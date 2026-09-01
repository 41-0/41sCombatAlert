-- 41sCombatAlert
-- World of Warcraft 1.12.1 / Lua 5.0
-- No SuperWoW required.
--
-- Pattern:
--   * = any number of characters
-- Matching is case-insensitive.
-- Special token:
--   currentpet = current pet name
--
-- Example:
--   currentpet * torment * resisted *

FortyOneSCombatAlertDB = FortyOneSCombatAlertDB or {}
FortyOneSCombatAlertDB.alerts = FortyOneSCombatAlertDB.alerts or {}

local ALERT_TIME = 3
local SOUND_FILES = {
    [1] = "Interface\\AddOns\\41sCombatAlert\\Sounds\\SoundA.wav",
    [2] = "Interface\\AddOns\\41sCombatAlert\\Sounds\\SoundB.wav"
}

local function EnsureDefaults()
    if table.getn(FortyOneSCombatAlertDB.alerts) == 0 then
        table.insert(FortyOneSCombatAlertDB.alerts, {
            enabled = true,
            pattern = "currentpet * torment * resisted *",
            textEnabled = true,
            soundEnabled = true,
            soundChoice = 1,
            customSoundPath = "Sound\\Interface\\RaidWarning.wav",
            chatParty = false,
            chatRaid = false,
            chatSay = false,
            chatYell = false,
            text = "TORMENT RESISTED!"
        })
    end

    if not FortyOneSCombatAlertDB.tauntExampleAdded then
        table.insert(FortyOneSCombatAlertDB.alerts, {
            enabled = true,
            pattern = "your taunt was resisted *",
            textEnabled = true,
            soundEnabled = true,
            soundChoice = 1,
            customSoundPath = "Sound\\Interface\\RaidWarning.wav",
            chatParty = true,
            chatRaid = false,
            chatSay = false,
            chatYell = false,
            text = "TAUNT RESISTED!"
        })
        FortyOneSCombatAlertDB.tauntExampleAdded = true
    end

    -- Add new options to alerts saved by older versions.
    local i
    for i = 1, table.getn(FortyOneSCombatAlertDB.alerts) do
        local alert = FortyOneSCombatAlertDB.alerts[i]
        if alert.chatParty == nil then alert.chatParty = false end
        if alert.chatRaid == nil then alert.chatRaid = false end
        if alert.chatSay == nil then alert.chatSay = false end
        if alert.chatYell == nil then alert.chatYell = false end
        if alert.soundChoice == nil then alert.soundChoice = 1 end
        if alert.customSoundPath == nil then
            alert.customSoundPath = "Sound\\Interface\\RaidWarning.wav"
        end
    end
end

-- Case-insensitive wildcard matcher.
-- Only '*' has special meaning; all other characters are literal.
local function WildcardMatch(text, pattern)
    text = string.lower(text or "")
    pattern = string.lower(pattern or "")

    if pattern == "" then
        return false
    end
    if pattern == "*" then
        return true
    end

    local p = 1
    local t = 1
    local plen = string.len(pattern)
    local tlen = string.len(text)
    local lastStar = 0
    local lastMatch = 0

    while t <= tlen do
        if p <= plen then
            local pc = string.sub(pattern, p, p)

            if pc ~= "*" and pc == string.sub(text, t, t) then
                p = p + 1
                t = t + 1
            elseif pc == "*" then
                lastStar = p
                p = p + 1
                lastMatch = t
            elseif lastStar > 0 then
                p = lastStar + 1
                lastMatch = lastMatch + 1
                t = lastMatch
            else
                return false
            end
        elseif lastStar > 0 then
            p = lastStar + 1
            lastMatch = lastMatch + 1
            t = lastMatch
        else
            return false
        end
    end

    while p <= plen and string.sub(pattern, p, p) == "*" do
        p = p + 1
    end

    return p > plen
end

local function ExpandPattern(pattern)
    local petName = UnitName("pet")

    if string.find(string.lower(pattern or ""), "currentpet", 1, true) then
        if not petName or petName == "" then
            return nil
        end
        return string.gsub(pattern, "currentpet", petName)
    end

    return pattern
end

local function Matches(alert, message)
    if not alert.enabled or not alert.pattern or alert.pattern == "" then
        return false
    end

    local pattern = ExpandPattern(alert.pattern)
    if not pattern then
        return false
    end

    return WildcardMatch(message, pattern)
end

-- ============================================================
-- On-screen alert
-- ============================================================

local alertFrame = CreateFrame("Frame", "FortyOneSCombatAlertTextFrame", UIParent)
alertFrame:SetWidth(800)
alertFrame:SetHeight(120)
alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
alertFrame:Hide()

local alertText = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alertText:SetPoint("CENTER", alertFrame, "CENTER", 0, 0)
alertText:SetWidth(800)
alertText:SetJustifyH("CENTER")
alertText:SetTextColor(1, 0.2, 0.2)

local alertUntil = 0

alertFrame:SetScript("OnUpdate", function()
    if GetTime() >= alertUntil then
        this:Hide()
    end
end)

local function ShowAlert(text)
    alertText:SetText(text)
    alertUntil = GetTime() + ALERT_TIME
    alertFrame:Show()
end

local function PlayAlertSound(alert)
    local soundChoice = 1
    if alert and alert.soundChoice then
        soundChoice = alert.soundChoice
    end
    if soundChoice == 3 then
        if alert and alert.customSoundPath and alert.customSoundPath ~= "" then
            PlaySoundFile(alert.customSoundPath)
        end
    else
        PlaySoundFile(SOUND_FILES[soundChoice] or SOUND_FILES[1])
    end
end

-- Send the alert text to every selected chat channel.
-- Party and raid messages are skipped when the player is not in that type of group.
local function SendChatReport(alert)
    local text = alert.text or ""
    if text == "" then
        return
    end

    if alert.chatParty and GetNumPartyMembers() > 0 then
        SendChatMessage(text, "PARTY")
    end
    if alert.chatRaid and GetNumRaidMembers() > 0 then
        SendChatMessage(text, "RAID")
    end
    if alert.chatSay then
        SendChatMessage(text, "SAY")
    end
    if alert.chatYell then
        SendChatMessage(text, "YELL")
    end
end

-- ============================================================
-- Vanilla 1.12.1 combat/spell events
-- ============================================================

local combatEvents = {
    "CHAT_MSG_COMBAT_SELF_HITS",
    "CHAT_MSG_COMBAT_SELF_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS",
    "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS",
    "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS",
    "CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES",
    "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS",
    "CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES",
    "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS",
    "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES",
    "CHAT_MSG_COMBAT_PARTY_HITS",
    "CHAT_MSG_COMBAT_PARTY_MISSES",
    "CHAT_MSG_COMBAT_PET_HITS",
    "CHAT_MSG_COMBAT_PET_MISSES",
    "CHAT_MSG_COMBAT_HOSTILE_DEATH",
    "CHAT_MSG_COMBAT_FRIENDLY_DEATH",

    "CHAT_MSG_SPELL_SELF_DAMAGE",
    "CHAT_MSG_SPELL_SELF_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF",
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
    "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
    "CHAT_MSG_SPELL_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_PARTY_BUFF",
    "CHAT_MSG_SPELL_PET_DAMAGE",
    "CHAT_MSG_SPELL_PET_BUFF",

    "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS",

    "CHAT_MSG_SPELL_AURA_GONE_SELF",
    "CHAT_MSG_SPELL_AURA_GONE_PARTY",
    "CHAT_MSG_SPELL_AURA_GONE_OTHER",
    "CHAT_MSG_SPELL_BREAK_AURA",
    "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF",
    "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS",
    "CHAT_MSG_SPELL_FAILED_LOCALPLAYER"
}

local eventFrame = CreateFrame("Frame", "FortyOneSCombatAlertEventFrame", UIParent)

local i
for i = 1, table.getn(combatEvents) do
    eventFrame:RegisterEvent(combatEvents[i])
end

eventFrame:SetScript("OnEvent", function()
    local message = arg1
    if not message then
        return
    end

    local i
    for i = 1, table.getn(FortyOneSCombatAlertDB.alerts) do
        local alert = FortyOneSCombatAlertDB.alerts[i]

        if Matches(alert, message) then
            if alert.textEnabled and alert.text ~= "" then
                ShowAlert(alert.text)
            end

            if alert.soundEnabled then
                PlayAlertSound(alert)
            end

            SendChatReport(alert)
        end
    end
end)

-- ============================================================
-- Configuration GUI
-- ============================================================

local config = CreateFrame("Frame", "FortyOneSCombatAlertConfigFrame", UIParent)
config:SetWidth(800)
config:SetHeight(620)
config:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
config:SetFrameStrata("DIALOG")
config:SetMovable(true)
config:EnableMouse(true)
config:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 11, top = 12, bottom = 11 }
})
config:Hide()

config:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then this:StartMoving() end
end)
config:SetScript("OnMouseUp", function()
    this:StopMovingOrSizing()
end)

local title = config:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", config, "TOP", 0, -20)
title:SetText("41sCombatAlert")

local info = config:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
info:SetPoint("TOPLEFT", config, "TOPLEFT", 25, -48)
info:SetWidth(750)
info:SetJustifyH("LEFT")
info:SetText("Use * as a wildcard. Matching is case-insensitive. currentpet will be replaced by your current pet's name.")

local close = CreateFrame("Button", nil, config, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", config, "TOPRIGHT", -5, -5)
close:SetScript("OnClick", function() config:Hide() end)

local listFrame = CreateFrame("Frame", "FortyOneSCombatAlertListFrame", config)
listFrame:SetPoint("TOPLEFT", config, "TOPLEFT", 20, -70)
listFrame:SetPoint("BOTTOMRIGHT", config, "BOTTOMRIGHT", -20, 62)

local scrollChild = CreateFrame("Frame", "FortyOneSCombatAlertListChild", listFrame)
scrollChild:SetWidth(735)
scrollChild:SetHeight(488)
scrollChild:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)

local rows = {}
local rowHeight = 122
local ROWS_PER_PAGE = 4
local currentPage = 1
local pageLabel
local previousPage
local nextPage

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetWidth(720)
    row:SetHeight(rowHeight)

    row.number = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.number:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -7)

    row.patternLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.patternLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -7)
    row.patternLabel:SetText("Pattern:")

    row.pattern = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.pattern:SetWidth(450)
    row.pattern:SetHeight(24)
    row.pattern:SetPoint("TOPLEFT", row, "TOPLEFT", 90, -4)
    row.pattern:SetAutoFocus(false)

    row.textLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.textLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -39)
    row.textLabel:SetText("Text:")

    row.text = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.text:SetWidth(450)
    row.text:SetHeight(24)
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 90, -36)
    row.text:SetAutoFocus(false)

    row.enabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.enabled:SetPoint("TOPLEFT", row, "TOPLEFT", 550, -4)
    row.enabledLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.enabledLabel:SetPoint("LEFT", row.enabled, "RIGHT", 0, 0)
    row.enabledLabel:SetText("Enable")

    row.textEnabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.textEnabled:SetPoint("TOPLEFT", row, "TOPLEFT", 550, -34)
    row.textEnabledLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.textEnabledLabel:SetPoint("LEFT", row.textEnabled, "RIGHT", 0, 0)
    row.textEnabledLabel:SetText("Text")

    row.soundEnabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.soundEnabled:SetPoint("TOPLEFT", row, "TOPLEFT", 650, -34)
    row.soundEnabledLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.soundEnabledLabel:SetPoint("LEFT", row.soundEnabled, "RIGHT", 0, 0)
    row.soundEnabledLabel:SetText("Sound")

    row.chatLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -96)
    row.chatLabel:SetText("Report to:")

    row.chatParty = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chatParty:SetPoint("TOPLEFT", row, "TOPLEFT", 105, -89)
    row.chatPartyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatPartyLabel:SetPoint("LEFT", row.chatParty, "RIGHT", 0, 0)
    row.chatPartyLabel:SetText("Party")

    row.chatRaid = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chatRaid:SetPoint("TOPLEFT", row, "TOPLEFT", 190, -89)
    row.chatRaidLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatRaidLabel:SetPoint("LEFT", row.chatRaid, "RIGHT", 0, 0)
    row.chatRaidLabel:SetText("Raid")

    row.chatSay = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chatSay:SetPoint("TOPLEFT", row, "TOPLEFT", 265, -89)
    row.chatSayLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatSayLabel:SetPoint("LEFT", row.chatSay, "RIGHT", 0, 0)
    row.chatSayLabel:SetText("Say")

    row.chatYell = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chatYell:SetPoint("TOPLEFT", row, "TOPLEFT", 335, -89)
    row.chatYellLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatYellLabel:SetPoint("LEFT", row.chatYell, "RIGHT", 0, 0)
    row.chatYellLabel:SetText("Yell")

    row.soundA = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.soundA:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -59)
    row.soundALabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.soundALabel:SetPoint("LEFT", row.soundA, "RIGHT", 0, 0)
    row.soundALabel:SetText("Sound A")

    row.soundB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.soundB:SetPoint("TOPLEFT", row, "TOPLEFT", 128, -59)
    row.soundBLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.soundBLabel:SetPoint("LEFT", row.soundB, "RIGHT", 0, 0)
    row.soundBLabel:SetText("Sound B")

    row.soundCustom = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.soundCustom:SetPoint("TOPLEFT", row, "TOPLEFT", 218, -59)
    row.soundCustomLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.soundCustomLabel:SetPoint("LEFT", row.soundCustom, "RIGHT", 0, 0)
    row.soundCustomLabel:SetText("Custom")

    row.customSoundLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.customSoundLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 305, -66)
    row.customSoundLabel:SetText("Path:")

    row.customSoundPath = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.customSoundPath:SetWidth(190)
    row.customSoundPath:SetHeight(24)
    row.customSoundPath:SetPoint("TOPLEFT", row, "TOPLEFT", 345, -57)
    row.customSoundPath:SetAutoFocus(false)

    row.delete = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.delete:SetWidth(75)
    row.delete:SetHeight(22)
    row.delete:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -5, 5)
    row.delete:SetText("Delete")

    row.pattern:SetScript("OnTextChanged", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            FortyOneSCombatAlertDB.alerts[r.index].pattern=this:GetText()
        end
    end)

    row.text:SetScript("OnTextChanged", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            FortyOneSCombatAlertDB.alerts[r.index].text=this:GetText()
        end
    end)

    row.enabled:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            FortyOneSCombatAlertDB.alerts[r.index].enabled=this:GetChecked()
        end
    end)

    row.textEnabled:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            FortyOneSCombatAlertDB.alerts[r.index].textEnabled=this:GetChecked()
        end
    end)

    row.soundEnabled:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            FortyOneSCombatAlertDB.alerts[r.index].soundEnabled=this:GetChecked()
        end
    end)

    row.soundA:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            local alert=FortyOneSCombatAlertDB.alerts[r.index]
            alert.soundChoice=1
            r.soundA:SetChecked(true)
            r.soundB:SetChecked(false)
            r.soundCustom:SetChecked(false)
        end
    end)

    row.soundB:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            local alert=FortyOneSCombatAlertDB.alerts[r.index]
            alert.soundChoice=2
            r.soundA:SetChecked(false)
            r.soundB:SetChecked(true)
            r.soundCustom:SetChecked(false)
        end
    end)

    row.soundCustom:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            local alert=FortyOneSCombatAlertDB.alerts[r.index]
            alert.soundChoice=3
            r.soundA:SetChecked(false)
            r.soundB:SetChecked(false)
            r.soundCustom:SetChecked(true)
        end
    end)

    row.customSoundPath:SetScript("OnTextChanged", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            FortyOneSCombatAlertDB.alerts[r.index].customSoundPath=this:GetText()
        end
    end)

    row.chatParty:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            FortyOneSCombatAlertDB.alerts[r.index].chatParty=this:GetChecked()
        end
    end)

    row.chatRaid:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            FortyOneSCombatAlertDB.alerts[r.index].chatRaid=this:GetChecked()
        end
    end)

    row.chatSay:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            FortyOneSCombatAlertDB.alerts[r.index].chatSay=this:GetChecked()
        end
    end)

    row.chatYell:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            FortyOneSCombatAlertDB.alerts[r.index].chatYell=this:GetChecked()
        end
    end)

    row.delete:SetScript("OnClick", function()
        local r=this.caRow
        if r and FortyOneSCombatAlertDB.alerts[r.index] then
            table.remove(FortyOneSCombatAlertDB.alerts,r.index)
            RefreshRows()
        end
    end)

    row.pattern.caRow=row
    row.text.caRow=row
    row.enabled.caRow=row
    row.textEnabled.caRow=row
    row.soundEnabled.caRow=row
    row.soundA.caRow=row
    row.soundB.caRow=row
    row.soundCustom.caRow=row
    row.customSoundPath.caRow=row
    row.chatParty.caRow=row
    row.chatRaid.caRow=row
    row.chatSay.caRow=row
    row.chatYell.caRow=row
    row.delete.caRow=row
    row.index=index
    return row
end

function RefreshRows()
    local count=table.getn(FortyOneSCombatAlertDB.alerts)
    local pageCount=math.max(1,math.ceil(count/ROWS_PER_PAGE))
    local slot

    if currentPage>pageCount then currentPage=pageCount end
    if currentPage<1 then currentPage=1 end

    for slot=1,ROWS_PER_PAGE do
        local index=((currentPage-1)*ROWS_PER_PAGE)+slot
        if not rows[slot] then rows[slot]=CreateRow(index) end
        local row=rows[slot]

        if index<=count then
            row.index=index
            row:SetPoint("TOPLEFT",scrollChild,"TOPLEFT",0,-((slot-1)*rowHeight))

            local a=FortyOneSCombatAlertDB.alerts[index]
            row.number:SetText(tostring(index))
            row.pattern:SetText(a.pattern or "")
            row.text:SetText(a.text or "")
            row.enabled:SetChecked(a.enabled)
            row.textEnabled:SetChecked(a.textEnabled)
            row.soundEnabled:SetChecked(a.soundEnabled)
            row.soundA:SetChecked((a.soundChoice or 1)==1)
            row.soundB:SetChecked((a.soundChoice or 1)==2)
            row.soundCustom:SetChecked((a.soundChoice or 1)==3)
            row.customSoundPath:SetText(a.customSoundPath or "Sound\\Interface\\RaidWarning.wav")
            row.chatParty:SetChecked(a.chatParty)
            row.chatRaid:SetChecked(a.chatRaid)
            row.chatSay:SetChecked(a.chatSay)
            row.chatYell:SetChecked(a.chatYell)
            row:Show()
        else
            row:Hide()
        end
    end

    if pageLabel then pageLabel:SetText("Page "..currentPage.."/"..pageCount) end
    if previousPage then
        if currentPage>1 then previousPage:Enable() else previousPage:Disable() end
    end
    if nextPage then
        if currentPage<pageCount then nextPage:Enable() else nextPage:Disable() end
    end
end

local add=CreateFrame("Button",nil,config,"UIPanelButtonTemplate")
add:SetWidth(120)
add:SetHeight(28)
add:SetPoint("BOTTOMLEFT",config,"BOTTOMLEFT",25,18)
add:SetText("Add Alert")
add:SetScript("OnClick",function()
    table.insert(FortyOneSCombatAlertDB.alerts,{
        enabled=true, pattern="", textEnabled=true,
        soundEnabled=true, soundChoice=1,
        customSoundPath="Sound\\Interface\\RaidWarning.wav",
        chatParty=false, chatRaid=false,
        chatSay=false, chatYell=false, text="ALERT!"
    })
    currentPage=math.ceil(table.getn(FortyOneSCombatAlertDB.alerts)/ROWS_PER_PAGE)
    RefreshRows()
end)

previousPage=CreateFrame("Button",nil,config,"UIPanelButtonTemplate")
previousPage:SetWidth(80)
previousPage:SetHeight(28)
previousPage:SetPoint("BOTTOMLEFT",config,"BOTTOMLEFT",145,18)
previousPage:SetText("Previous")
previousPage:SetScript("OnClick",function()
    if currentPage>1 then
        currentPage=currentPage-1
        RefreshRows()
    end
end)

pageLabel=config:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
pageLabel:SetWidth(80)
pageLabel:SetPoint("LEFT",previousPage,"RIGHT",5,0)
pageLabel:SetJustifyH("CENTER")

nextPage=CreateFrame("Button",nil,config,"UIPanelButtonTemplate")
nextPage:SetWidth(80)
nextPage:SetHeight(28)
nextPage:SetPoint("LEFT",pageLabel,"RIGHT",5,0)
nextPage:SetText("Next")
nextPage:SetScript("OnClick",function()
    local pageCount=math.max(1,math.ceil(table.getn(FortyOneSCombatAlertDB.alerts)/ROWS_PER_PAGE))
    if currentPage<pageCount then
        currentPage=currentPage+1
        RefreshRows()
    end
end)

local function ShowConfig()
    RefreshRows()
    config:Show()
end

-- ============================================================
-- Minimap button
-- ============================================================

local minimapButton = CreateFrame("Button", "FortyOneSCombatAlertMinimapButton", Minimap)
minimapButton:SetWidth(32)
minimapButton:SetHeight(32)
minimapButton:SetFrameStrata("HIGH")
minimapButton:SetPoint("CENTER", UIParent, "CENTER")

local minimapIcon = minimapButton:CreateTexture(nil, "BORDER")
minimapIcon:SetTexture("Interface\\Icons\\Ability_Warrior_RallyingCry")
minimapIcon:SetWidth(20)
minimapIcon:SetHeight(20)
minimapIcon:SetPoint("CENTER", minimapButton, "CENTER")

local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapBorder:SetWidth(52)
minimapBorder:SetHeight(52)
minimapBorder:SetPoint("TOPLEFT", minimapButton, "TOPLEFT")

local function UpdateMinimapButtonPosition(angle)
    local centerX, centerY = Minimap:GetCenter()
    local radius = 80
    angle = angle or FortyOneSCombatAlertDB.minimapAngle or (math.pi * 0.75)

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        centerX + (math.cos(angle) * radius),
        centerY + (math.sin(angle) * radius))
    FortyOneSCombatAlertDB.minimapAngle = angle
end

minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetMovable(true)
minimapButton:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
        local cursorX, cursorY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local centerX, centerY = Minimap:GetCenter()
        UpdateMinimapButtonPosition(math.atan2((cursorY / scale) - centerY,
            (cursorX / scale) - centerX))
    end)
end)
minimapButton:SetScript("OnDragStop", function()
    this:SetScript("OnUpdate", nil)
end)
minimapButton:SetScript("OnClick", function()
    if config:IsShown() then
        config:Hide()
    else
        ShowConfig()
    end
end)
minimapButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("41sCombatAlert")
    GameTooltip:AddLine("Click to open settings.", 1, 1, 1)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

SLASH_FOCASCOMBATALERT1="/foca"

SlashCmdList["FOCASCOMBATALERT"]=function(msg)
    msg=string.lower(msg or "")
    if msg=="" or msg=="show" or msg=="config" then
        ShowConfig()
    elseif msg=="test" then
        ShowAlert("TEST ALERT")
        PlayAlertSound()
    elseif msg=="hide" then
        alertFrame:Hide()
    else
        DEFAULT_CHAT_FRAME:AddMessage("41sCombatAlert: /foca - open configuration")
        DEFAULT_CHAT_FRAME:AddMessage("41sCombatAlert: /foca test - test alert")
        DEFAULT_CHAT_FRAME:AddMessage("41sCombatAlert: /foca hide - hide alert")
    end
end

-- Startup
local startup=CreateFrame("Frame","FortyOneSCombatAlertStartupFrame",UIParent)
startup:RegisterEvent("PLAYER_LOGIN")
startup:SetScript("OnEvent",function()
    EnsureDefaults()
    UpdateMinimapButtonPosition()
    RefreshRows()
    DEFAULT_CHAT_FRAME:AddMessage("|cffff333341sCombatAlert|r loaded. Type |cff66ccff/foca|r.")
end)
