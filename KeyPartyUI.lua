-- KeyPartyUI.lua
-- Modern UI frame for Key Party. Loaded after KeyParty.lua.

local KL_UI = {}
_G.KL_UI = KL_UI

-- ── Constants ─────────────────────────────────────────────────────────────────

local FRAME_W   = 620
local FRAME_H   = 450
local ROW_H     = 18     -- pixels per member row
local MAX_ROWS  = 25     -- pool size per section (handles raids)
local COL_NAME_X  = 14
local COL_VALUE_X = 400
local TITLE_ICON_PATH = "Interface\\AddOns\\KeyParty\\media\\title-icon"
local TITLE_WORDMARK_PATH = "Interface\\AddOns\\KeyParty\\media\\title-wordmark"
local TITLE_ICON_FALLBACK = 134419
local TITLE_BAR_H = 110
local TITLE_ICON_SIZE = 100
local TITLE_WORDMARK_SIZE = 100

-- Raider.io-style rating colour thresholds
local RATING_COLORS = {
    { threshold = 2500, r = 0.90, g = 0.80, b = 0.50 }, -- gold
    { threshold = 2000, r = 1.00, g = 0.50, b = 0.00 }, -- orange
    { threshold = 1500, r = 0.64, g = 0.21, b = 0.93 }, -- purple
    { threshold = 1000, r = 0.00, g = 0.44, b = 0.87 }, -- blue
    { threshold = 500,  r = 0.12, g = 1.00, b = 0.00 }, -- green
    { threshold = 0,    r = 0.62, g = 0.62, b = 0.62 }, -- gray
}

local function RatingColor(rating)
    for _, entry in ipairs(RATING_COLORS) do
        if rating >= entry.threshold then
            return entry.r, entry.g, entry.b
        end
    end
    return 0.62, 0.62, 0.62
end

local function ColoredRating(rating)
    local r, g, b = RatingColor(math.floor(rating or 0))
    return string.format("|cff%02x%02x%02x%d|r",
        math.floor(r * 255), math.floor(g * 255), math.floor(b * 255),
        math.floor(rating or 0))
end

local function ColoredPlayerName(name, member)
    local classToken = member and member.classToken
    local classColors = rawget(_G, "CUSTOM_CLASS_COLORS") or rawget(_G, "RAID_CLASS_COLORS")
    local c = classToken and classColors and classColors[classToken]
    if c then
        local r = math.floor((c.r or 1) * 255)
        local g = math.floor((c.g or 1) * 255)
        local b = math.floor((c.b or 1) * 255)
        return string.format("|cff%02x%02x%02x%s|r", r, g, b, tostring(name or "Unknown"))
    end
    return tostring(name or "Unknown")
end

local function GetMapIcon(mapID)
    if not mapID or not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then
        return 134400 -- INV_Misc_QuestionMark
    end

    -- In modern builds this is typically: name, id, timeLimit, texture
    local _, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
    if texture then
        return texture
    end

    return 134400
end

local function GetGroupPlayerNames()
    local names = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) then
                local name = GetUnitName(unit, true) or UnitName(unit)
                if name and name ~= "" then
                    names[#names + 1] = name
                end
            end
        end
    elseif IsInGroup() then
        local playerName = GetUnitName("player", true) or UnitName("player")
        if playerName and playerName ~= "" then
            names[#names + 1] = playerName
        end
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            if UnitExists(unit) then
                local name = GetUnitName(unit, true) or UnitName(unit)
                if name and name ~= "" then
                    names[#names + 1] = name
                end
            end
        end
    else
        local playerName = GetUnitName("player", true) or UnitName("player")
        if playerName and playerName ~= "" then
            names[#names + 1] = playerName
        end
    end

    table.sort(names)
    return names
end

local function GetSeasonDungeons()
    local result = {}
    local mapTable = C_ChallengeMode.GetMapTable() or {}
    local seen = {}

    for _, mapID in ipairs(mapTable) do
        if not seen[mapID] then
            seen[mapID] = true
            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            result[#result + 1] = {
                mapID = mapID,
                name = (name and name ~= "") and name or ("Map " .. tostring(mapID)),
            }
        end
    end

    table.sort(result, function(a, b)
        return a.name < b.name
    end)

    return result
end

-- ── Frame builder helpers ─────────────────────────────────────────────────────

local function ApplyBackdrop(f, bgR, bgG, bgB, bgA, brR, brG, brB, brA)
    f:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(bgR, bgG, bgB, bgA)
    f:SetBackdropBorderColor(brR, brG, brB, brA)
end

local function Separator(parent, yOffset)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  12, yOffset)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    t:SetHeight(1)
    t:SetColorTexture(0.28, 0.28, 0.36, 0.80)
    return t
end

local function SectionLabel(parent, yOffset, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)
    fs:SetText(text)
    return fs
end

-- ── Build the main frame ──────────────────────────────────────────────────────

local function BuildFrame()
    local f = CreateFrame("Frame", "KeyLotteryMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:Hide()
    ApplyBackdrop(f, 0.08, 0.08, 0.11, 0.97, 0.38, 0.38, 0.48, 1)

    -- ── Title bar ─────────────────────────────────────────────────────────────
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(TITLE_BAR_H)
    ApplyBackdrop(titleBar, 0.04, 0.04, 0.06, 1, 0.38, 0.38, 0.48, 1)

    local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(TITLE_ICON_SIZE, TITLE_ICON_SIZE)
    titleIcon:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    titleIcon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    titleIcon:SetTexture(TITLE_ICON_FALLBACK)
    titleIcon:SetTexture(TITLE_ICON_PATH)
    f.titleIcon = titleIcon

    local titleWordmark = titleBar:CreateTexture(nil, "ARTWORK")
    titleWordmark:SetSize(TITLE_WORDMARK_SIZE, TITLE_WORDMARK_SIZE)
    titleWordmark:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
    titleWordmark:SetTexCoord(0.02, 0.98, 0.02, 0.98)
    titleWordmark:SetTexture(TITLE_ICON_FALLBACK)
    titleWordmark:SetTexture(TITLE_WORDMARK_PATH)
    f.titleWordmark = titleWordmark

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -2, -4)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        if KL_UI.OnRefresh then KL_UI.OnRefresh() end
    end)

    local setKeyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    setKeyBtn:SetSize(80, 22)
    setKeyBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -6, 0)
    setKeyBtn:SetText("Set Key")

    -- ── Layout anchors ────────────────────────────────────────────────────────
    -- Section yOffsets from top of f (all negative)
    local Y_RATING_LABEL  = -(TITLE_BAR_H + 4)
    local Y_RATING_ROWS   = Y_RATING_LABEL - 18
    local RATING_H        = ROW_H * 5          -- default visible height (5 rows)
    local Y_SEP1          = Y_RATING_ROWS - RATING_H - 6
    local Y_KEY_LABEL     = Y_SEP1 - 8
    local Y_KEY_ROWS      = Y_KEY_LABEL - 18
    local KEY_H           = ROW_H * 5
    local Y_SEP2          = Y_KEY_ROWS - KEY_H - 6
    local Y_BEST_LABEL    = Y_SEP2 - 8
    local Y_BEST_BOX      = Y_BEST_LABEL - 18

    -- ── GROUP RATINGS section ─────────────────────────────────────────────────
    SectionLabel(f, Y_RATING_LABEL, "|cffFFD100GROUP RATINGS|r")

    f._ratingRows = {}
    for i = 1, MAX_ROWS do
        local y = Y_RATING_ROWS - (i - 1) * ROW_H
        local left = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        left:SetPoint("TOPLEFT", f, "TOPLEFT", COL_NAME_X, y)
        left:SetJustifyH("LEFT")
        left:Hide()

        local right = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        right:SetPoint("TOPLEFT", f, "TOPLEFT", COL_VALUE_X, y)
        right:SetJustifyH("LEFT")
        right:Hide()

        f._ratingRows[i] = { name = left, value = right }
    end

    Separator(f, Y_SEP1)

    -- ── AVAILABLE KEYSTONES section ───────────────────────────────────────────
    SectionLabel(f, Y_KEY_LABEL, "|cffFFD100AVAILABLE KEYSTONES|r")

    f._keyRows = {}
    for i = 1, MAX_ROWS do
        local y = Y_KEY_ROWS - (i - 1) * ROW_H
        local left = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        left:SetPoint("TOPLEFT", f, "TOPLEFT", COL_NAME_X, y)
        left:SetJustifyH("LEFT")
        left:Hide()

        local right = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        right:SetPoint("TOPLEFT", f, "TOPLEFT", COL_VALUE_X, y)
        right:SetJustifyH("LEFT")
        right:Hide()

        f._keyRows[i] = { name = left, value = right }
    end

    Separator(f, Y_SEP2)

    -- ── BEST PROGRESSION KEY section ──────────────────────────────────────────
    SectionLabel(f, Y_BEST_LABEL, "|cffFFD100BEST PROGRESSION KEY|r")

    local bestBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bestBox:SetPoint("TOPLEFT",  f, "TOPLEFT",  12, Y_BEST_BOX)
    bestBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, Y_BEST_BOX)
    bestBox:SetHeight(80)
    ApplyBackdrop(bestBox, 0.05, 0.05, 0.07, 1, 0.80, 0.65, 0.00, 0.90)

    local bestContent = CreateFrame("Frame", nil, bestBox)
    bestContent:SetPoint("TOPLEFT", bestBox, "TOPLEFT", 12, -10)
    bestContent:SetPoint("TOPRIGHT", bestBox, "TOPRIGHT", -12, -10)
    bestContent:SetHeight(54)

    local bestIconButton = CreateFrame("Button", nil, bestContent, "SecureActionButtonTemplate")
    bestIconButton:SetPoint("TOPLEFT", bestContent, "TOPLEFT", 0, 0)
    bestIconButton:SetSize(bestContent:GetHeight(), bestContent:GetHeight())

    local bestIcon = bestIconButton:CreateTexture(nil, "ARTWORK")
    bestIcon:SetAllPoints()
    bestIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bestIcon:SetTexture(134400)
    f.bestKeyIconButton = bestIconButton
    f.bestKeyIcon = bestIcon

    bestIconButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Best Progression Dungeon", 1, 0.82, 0)
        if btn.mapName then
            GameTooltip:AddLine(btn.mapName, 1, 1, 1)
        end
        if btn.portalSpellName then
            GameTooltip:AddLine("Click to teleport", 0.2, 1, 0.2)
            GameTooltip:AddLine(btn.portalSpellName, 0.8, 0.8, 1)
        else
            GameTooltip:AddLine("No teleport available", 1, 0.2, 0.2)
            GameTooltip:AddLine("Tip: /kp setportal <mapID> <spellID>", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    bestIconButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local textAnchor = CreateFrame("Frame", nil, bestContent)
    textAnchor:SetPoint("TOPLEFT", bestIcon, "TOPRIGHT", 10, 0)
    textAnchor:SetPoint("BOTTOMRIGHT", bestContent, "BOTTOMRIGHT", 0, 0)

    local bestKeyName = textAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bestKeyName:SetPoint("TOPLEFT", textAnchor, "TOPLEFT", 0, 0)
    f.bestKeyName = bestKeyName

    local bestKeyOwner = textAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bestKeyOwner:SetPoint("TOPLEFT", bestKeyName, "BOTTOMLEFT", 0, -4)
    f.bestKeyOwner = bestKeyOwner

    local bestKeyReason = textAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bestKeyReason:SetPoint("TOPLEFT", bestKeyOwner, "BOTTOMLEFT", 0, -2)
    f.bestKeyReason = bestKeyReason

    -- ── Status bar ────────────────────────────────────────────────────────────
    local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 8)
    statusText:SetTextColor(0.45, 0.45, 0.50, 1)
    statusText:SetText("No data yet. Click Refresh or use /kp refresh.")
    f.statusText = statusText

    -- ── Manual Set Key popup ─────────────────────────────────────────────────
    local popup = CreateFrame("Frame", nil, f, "BackdropTemplate")
    popup:SetSize(390, 180)
    popup:SetPoint("CENTER", f, "CENTER", 0, 0)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:Hide()
    ApplyBackdrop(popup, 0.06, 0.06, 0.09, 0.98, 0.55, 0.55, 0.65, 1)

    local popupTitle = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popupTitle:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -10)
    popupTitle:SetText("Manual Key Entry")

    local function MakeLabel(y, text)
        local fs = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, y)
        fs:SetText(text)
        return fs
    end

    local function MakeInput(y)
        local eb = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        eb:SetSize(245, 20)
        eb:SetPoint("TOPLEFT", popup, "TOPLEFT", 130, y)
        eb:SetAutoFocus(false)
        return eb
    end

    local function MakeDropdown(y)
        local dd = CreateFrame("Frame", nil, popup, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", popup, "TOPLEFT", 114, y)
        UIDropDownMenu_SetWidth(dd, 240)
        UIDropDownMenu_SetText(dd, "Select")
        return dd
    end

    MakeLabel(-42, "Player")
    MakeLabel(-70, "Dungeon")
    MakeLabel(-98, "Level")

    local playerDropdown = MakeDropdown(-33)
    local dungeonDropdown = MakeDropdown(-61)
    local levelInput = MakeInput(-94)
    f.manualPlayerDropdown = playerDropdown
    f.manualDungeonDropdown = dungeonDropdown
    f.manualLevelInput = levelInput

    local selectedPlayer = nil
    local selectedDungeonID = nil

    local function RefreshPlayerDropdown()
        local players = GetGroupPlayerNames()

        UIDropDownMenu_Initialize(playerDropdown, function(self, level)
            if level ~= 1 then
                return
            end
            for _, name in ipairs(players) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.func = function()
                    selectedPlayer = name
                    UIDropDownMenu_SetSelectedName(playerDropdown, name)
                    UIDropDownMenu_SetText(playerDropdown, name)
                end
                info.checked = (selectedPlayer == name)
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        if (not selectedPlayer or selectedPlayer == "") and #players > 0 then
            selectedPlayer = players[1]
        end

        if selectedPlayer then
            UIDropDownMenu_SetText(playerDropdown, selectedPlayer)
            UIDropDownMenu_SetSelectedName(playerDropdown, selectedPlayer)
        else
            UIDropDownMenu_SetText(playerDropdown, "No players")
        end
    end

    local function RefreshDungeonDropdown()
        local dungeons = GetSeasonDungeons()

        UIDropDownMenu_Initialize(dungeonDropdown, function(self, level)
            if level ~= 1 then
                return
            end
            for _, dungeon in ipairs(dungeons) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = dungeon.name
                info.func = function()
                    selectedDungeonID = dungeon.mapID
                    UIDropDownMenu_SetSelectedValue(dungeonDropdown, dungeon.mapID)
                    UIDropDownMenu_SetText(dungeonDropdown, dungeon.name)
                end
                info.checked = (selectedDungeonID == dungeon.mapID)
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        if (not selectedDungeonID) and #dungeons > 0 then
            selectedDungeonID = dungeons[1].mapID
        end

        if selectedDungeonID then
            local selectedName = nil
            for _, dungeon in ipairs(dungeons) do
                if dungeon.mapID == selectedDungeonID then
                    selectedName = dungeon.name
                    break
                end
            end
            if selectedName then
                UIDropDownMenu_SetSelectedValue(dungeonDropdown, selectedDungeonID)
                UIDropDownMenu_SetText(dungeonDropdown, selectedName)
            else
                UIDropDownMenu_SetText(dungeonDropdown, "Select dungeon")
            end
        else
            UIDropDownMenu_SetText(dungeonDropdown, "No dungeons")
        end
    end

    local hint = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -122)
    hint:SetText("Map can be ID or exact dungeon name")
    hint:SetTextColor(0.7, 0.7, 0.75)

    local saveBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    saveBtn:SetSize(84, 22)
    saveBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -12, 10)
    saveBtn:SetText("Save")

    local cancelBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    cancelBtn:SetSize(84, 22)
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -6, 0)
    cancelBtn:SetText("Cancel")

    cancelBtn:SetScript("OnClick", function()
        popup:Hide()
    end)

    saveBtn:SetScript("OnClick", function()
        if not KL_UI.OnManualSetKey then
            f.statusText:SetText("Manual key handler is not available.")
            return
        end

        if not selectedPlayer or not selectedDungeonID then
            f.statusText:SetText("Select player and dungeon first.")
            return
        end

        local ok = KL_UI.OnManualSetKey(
            selectedPlayer,
            selectedDungeonID,
            levelInput:GetText()
        )
        if ok then
            popup:Hide()
            levelInput:SetText("")
        end
    end)

    setKeyBtn:SetScript("OnClick", function()
        RefreshPlayerDropdown()
        RefreshDungeonDropdown()
        popup:Show()
        levelInput:SetFocus()
    end)

    return f
end

local mainFrame = BuildFrame()
KL_UI.frame = mainFrame

-- ── Public: populate the frame with current data ──────────────────────────────

function KL_UI:Populate(members, best)
    local f    = self.frame
    local rows = f._ratingRows
    local keys = f._keyRows

    -- Hide all pre-created rows
    for i = 1, MAX_ROWS do
        rows[i].name:Hide()
        rows[i].value:Hide()
        keys[i].name:Hide()
        keys[i].value:Hide()
    end

    local names = {}
    for name in pairs(members) do
        names[#names + 1] = name
    end
    table.sort(names)

    local addonTable = _G.KeyLottery
    local GetMapName = (addonTable and addonTable.GetMapName) or function(id)
        return "Map " .. tostring(id)
    end

    -- Rating rows
    for i, name in ipairs(names) do
        if i > MAX_ROWS then break end
        local m   = members[name]
        local rat = m.totalRating or 0
        rows[i].name:SetText(ColoredPlayerName(name, m))
        rows[i].value:SetText(ColoredRating(rat))
        rows[i].name:Show()
        rows[i].value:Show()
    end

    -- Keystone rows
    for i, name in ipairs(names) do
        if i > MAX_ROWS then break end
        local m = members[name]
        keys[i].name:SetText(ColoredPlayerName(name, m))
        if m.key and m.key.level and m.key.level > 0 then
            keys[i].value:SetText(string.format(
                "|cff00ff96%s +%d|r",
                GetMapName(m.key.mapID), m.key.level))
        else
            keys[i].value:SetText("|cff606060no key shared|r")
        end
        keys[i].name:Show()
        keys[i].value:Show()
    end

    -- Best key box
    if best then
        local spellID = addonTable and addonTable.GetTeleportSpellIDForMap and addonTable.GetTeleportSpellIDForMap(best.mapID)
        local spellName = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or nil

        f.bestKeyIconButton.mapName = GetMapName(best.mapID)
        f.bestKeyIconButton.portalSpellName = spellName

        if not InCombatLockdown() then
            if spellID then
                f.bestKeyIconButton:SetAttribute("type", "spell")
                f.bestKeyIconButton:SetAttribute("spell", spellID)
                f.bestKeyIconButton:EnableMouse(true)
            else
                f.bestKeyIconButton:SetAttribute("type", nil)
                f.bestKeyIconButton:SetAttribute("spell", nil)
                f.bestKeyIconButton:EnableMouse(true)
            end
        end

        f.bestKeyIcon:SetTexture(GetMapIcon(best.mapID))
        f.bestKeyName:SetText(string.format(
            "|cffffd100%s|r  |cff00ff96+%d|r", GetMapName(best.mapID), best.level))
        local ownerData = best.owner and members[best.owner] or nil
        f.bestKeyOwner:SetText("Owner: " .. ColoredPlayerName(best.owner, ownerData))
        f.bestKeyReason:SetText(string.format(
            "%d / %d players missing score on this dungeon   *   Group avg  %.0f",
            best.missingCount, best.memberCount, best.avgScore))
    else
        f.bestKeyIconButton.mapName = nil
        f.bestKeyIconButton.portalSpellName = nil
        if not InCombatLockdown() then
            f.bestKeyIconButton:SetAttribute("type", nil)
            f.bestKeyIconButton:SetAttribute("spell", nil)
            f.bestKeyIconButton:EnableMouse(true)
        end
        f.bestKeyIcon:SetTexture(134400)
        f.bestKeyName:SetText("|cff808080No keystones available|r")
        f.bestKeyOwner:SetText("")
        f.bestKeyReason:SetText(
            "|cff606060Ask group members to run Key Party and use /kp refresh.|r")
    end

    f.statusText:SetText(string.format(
        "Last refresh: %s   *   /kp refresh to update", date("%H:%M:%S")))

    f:Show()
    f:Raise()
end

function KL_UI:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end
