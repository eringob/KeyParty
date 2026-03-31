-- KeyPartyUI.lua
-- Modern UI frame for Key Party. Loaded after KeyParty.lua.

local KL_UI = {}
_G.KL_UI = KL_UI

-- ── Constants ─────────────────────────────────────────────────────────────────

local FRAME_W   = 620
local FRAME_H   = 780
local ROW_H     = 18     -- pixels per member row
local MAX_ROWS  = 25     -- pool size per section (handles raids)
local COL_NAME_X  = 14
local COL_VALUE_X = 400
local TITLE_BANNER_PATH = "Interface\\AddOns\\KeyParty\\media\\title-banner"
local TITLE_ICON_FALLBACK = 134419
local TITLE_BANNER_SOURCE_W = 1536
local TITLE_BANNER_SOURCE_H = 483
local TITLE_BAR_H = math.floor((FRAME_W * TITLE_BANNER_SOURCE_H) / TITLE_BANNER_SOURCE_W + 0.5)
local HEADER_ICON_BUTTON_W = 28
local HEADER_ICON_BUTTON_H = 22
local HEADER_ICON_SIZE = 14
local HEADER_ICON_BUTTON_MARGIN = 4
local HEADER_ICON_BUTTON_GAP = 2
local CLOSE_ICON_TEXTURE = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local REFRESH_ICON_ATLAS = "transmog-icon-revert"
local EMPTY_ICON_TEXTURE = 134400
local KEYSTONE_ICON_ITEM_CANDIDATES = { 180653, 158923, 138019 }
local YOUR_SCORES_ICON_COUNT = 8
local PARTY_KEYSTONE_ICON_COUNT = 5
local KEY_AREA_COLUMN_COUNT = 6
local BEST_KEY_ICON_SIZE = 74
local WEEKLY_AFFIX_LEVEL_LABELS = { "+4", "+7", "+10", "+12" }
local OPTION_CHECKBOX_SCALE = 0.72
local STATUS_TEXT_BOTTOM_OFFSET = 48
local AUTO_OPEN_OPTION_BOTTOM_OFFSET = 28
local PARTY_CHAT_OPTION_BOTTOM_OFFSET = 8

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

local function InstanceScoreColor(score)
    local value = tonumber(score) or 0
    if value <= 0 then
        return 0.85, 0.85, 0.85, "zero-score"
    end

    local function NormalizeRGB(r, g, b)
        if not r or not g or not b then
            return nil
        end
        if r > 1 or g > 1 or b > 1 then
            return r / 255, g / 255, b / 255
        end
        return r, g, b
    end

    local function IsPureWhite(r, g, b)
        return r and g and b and r >= 0.999 and g >= 0.999 and b >= 0.999
    end

    local function ExtractColorFromApiResult(result1, result2, result3)
        local r, g, b = NormalizeRGB(result1, result2, result3)
        if r and g and b then
            return r, g, b
        end

        if type(result1) == "table" then
            local c = result1
            if c.GetRGB then
                r, g, b = NormalizeRGB(c:GetRGB())
                if r and g and b then
                    return r, g, b
                end
            end

            r, g, b = NormalizeRGB(c.r, c.g, c.b)
            if r and g and b then
                return r, g, b
            end

            r, g, b = NormalizeRGB(rawget(c, "red"), rawget(c, "green"), rawget(c, "blue"))
            if r and g and b then
                return r, g, b
            end

            local colorObj = rawget(c, "color")
            if type(colorObj) == "table" then
                r, g, b = NormalizeRGB(rawget(colorObj, "r"), rawget(colorObj, "g"), rawget(colorObj, "b"))
                if r and g and b then
                    return r, g, b
                end
            end
        end

        return nil
    end

    if C_ChallengeMode then
        local candidates = {
            "GetSpecificDungeonOverallScoreRarityColor",
            "GetSpecificDungeonScoreRarityColor",
            "GetDungeonScoreRarityColor",
        }

        local whiteFallback = nil
        for _, fnName in ipairs(candidates) do
            local fn = C_ChallengeMode[fnName]
            if type(fn) == "function" then
                local a, b, c = fn(value)
                local r, g, bl = ExtractColorFromApiResult(a, b, c)
                if r and g and bl then
                    if not IsPureWhite(r, g, bl) then
                        return r, g, bl, fnName
                    end
                    whiteFallback = { r = r, g = g, b = bl }
                end
            end
        end

        if whiteFallback then
            return whiteFallback.r, whiteFallback.g, whiteFallback.b, "white-api-fallback"
        end
    end

    local r, g, b = RatingColor(math.floor(value))
    return r, g, b, "local-threshold-fallback"
end

local function ApplyIconScoreText(slot, score)
    if not slot or not slot.scoreText then
        return
    end

    local value = tonumber(score) or 0
    local label = "-"
    if value > 0 then
        label = string.format("%.0f", value)
    end

    if slot.scoreOutline then
        for _, outline in ipairs(slot.scoreOutline) do
            outline:SetText(label)
        end
    end

    slot.scoreText:SetText(label)
    if value > 0 then
        local r, g, b, source = InstanceScoreColor(value)
        slot.lastScoreValue = value
        slot.lastScoreColor = { r = r, g = g, b = b }
        slot.lastScoreColorSource = source or "unknown"
        slot.scoreText:SetTextColor(r, g, b, 1)
    else
        slot.lastScoreValue = 0
        slot.lastScoreColor = { r = 0.85, g = 0.85, b = 0.85 }
        slot.lastScoreColorSource = "zero-score"
        slot.scoreText:SetTextColor(0.85, 0.85, 0.85, 1)
    end
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

local function GroupRatingDisplayName(name, member)
    if type(member) == "table" and member.displayName and member.displayName ~= "" then
        return member.displayName
    end
    return tostring(name or "Unknown")
end

local function CanonicalName(name)
    local n = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if n == "" then
        return "Unknown"
    end
    return Ambiguate(n, "short")
end

local function AbbreviateDungeonName(name)
    local text = tostring(name or "")
    if text == "" then
        return "N/A"
    end

    local stopWords = {
        ["the"] = true,
        ["of"] = true,
        ["and"] = true,
        ["to"] = true,
        ["in"] = true,
        ["a"] = true,
        ["an"] = true,
    }

    local letters = {}
    for word in text:gmatch("[%a%d']+") do
        local lower = strlower(word)
        if not stopWords[lower] then
            letters[#letters + 1] = strupper(word:sub(1, 1))
        end
    end

    if #letters >= 2 then
        return table.concat(letters, "", 1, math.min(4, #letters))
    end

    local compact = text:gsub("[^%a%d]", "")
    if compact == "" then
        return "N/A"
    end
    return strupper(compact:sub(1, 4))
end

local function EllipsizeTextToWidth(fontString, text, maxWidth)
    if not fontString then
        return tostring(text or "")
    end

    local raw = tostring(text or "")
    if raw == "" or not maxWidth or maxWidth <= 0 then
        return raw
    end

    fontString:SetText(raw)
    if (fontString:GetStringWidth() or 0) <= maxWidth then
        return raw
    end

    local ellipsis = "..."
    fontString:SetText(ellipsis)
    if (fontString:GetStringWidth() or 0) > maxWidth then
        return ""
    end

    local low, high = 0, #raw
    while low < high do
        local mid = math.floor((low + high + 1) / 2)
        local candidate = raw:sub(1, mid) .. ellipsis
        fontString:SetText(candidate)
        if (fontString:GetStringWidth() or 0) <= maxWidth then
            low = mid
        else
            high = mid - 1
        end
    end

    return raw:sub(1, low) .. ellipsis
end

local function ConfigureHeaderIconButton(button, iconTexture, tooltipText, tooltipAnchor, iconGlyph, iconAtlas)
    if not button then
        return
    end

    button:SetText("")

    local icon = button._iconTexture
    if not icon then
        icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(HEADER_ICON_SIZE, HEADER_ICON_SIZE)
        icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        button._iconTexture = icon
    end

    local glyph = button._iconGlyph
    if not glyph then
        glyph = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        glyph:SetPoint("CENTER", button, "CENTER", 0, 0)
        button._iconGlyph = glyph
    end

    if iconAtlas and icon.SetAtlas then
        icon:SetAtlas(iconAtlas, true)
        icon:SetVertexColor(0.92, 0.92, 0.95, 1)
        icon:Show()
        glyph:SetText("")
        glyph:Hide()
    elseif iconTexture then
        icon:SetTexture(iconTexture)
        icon:SetVertexColor(0.92, 0.92, 0.95, 1)
        icon:Show()
        glyph:SetText("")
        glyph:Hide()
    else
        icon:SetTexture(nil)
        icon:Hide()
        glyph:SetText(iconGlyph or "")
        glyph:SetTextColor(0.92, 0.92, 0.95, 1)
        glyph:Show()
    end

    button:SetScript("OnEnter", function(btn)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btn, tooltipAnchor or "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipText or "", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function GetMapIcon(mapID)
    if not mapID or not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then
        return EMPTY_ICON_TEXTURE -- INV_Misc_QuestionMark
    end

    -- In modern builds this is typically: name, id, timeLimit, texture
    local _, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
    if texture then
        return texture
    end

    return EMPTY_ICON_TEXTURE
end

local function GetEmptyKeystoneIcon()
    if KL_UI._emptyKeystoneIcon then
        return KL_UI._emptyKeystoneIcon
    end

    local icon = nil
    local itemApi = C_Item and C_Item.GetItemIconByID

    for _, itemID in ipairs(KEYSTONE_ICON_ITEM_CANDIDATES) do
        if itemApi then
            icon = itemApi(itemID)
        end

        if icon then
            KL_UI._emptyKeystoneIcon = icon
            return icon
        end
    end

    KL_UI._emptyKeystoneIcon = EMPTY_ICON_TEXTURE
    return KL_UI._emptyKeystoneIcon
end

local function GetCurrentAffixList()
    local out = {}
    if not (C_MythicPlus and C_MythicPlus.GetCurrentAffixes and C_ChallengeMode and C_ChallengeMode.GetAffixInfo) then
        return out
    end

    local active = C_MythicPlus.GetCurrentAffixes() or {}
    for _, item in ipairs(active) do
        local candidate = item
        if type(item) == "table" then
            candidate = rawget(item, "id") or rawget(item, "keystoneAffixID") or rawget(item, "affixID")
        end
        local affixID = tonumber(candidate)
        if affixID and affixID > 0 then
            local name, description, icon = C_ChallengeMode.GetAffixInfo(affixID)
            out[#out + 1] = {
                id = affixID,
                name = name or ("Affix " .. tostring(affixID)),
                description = description or "",
                icon = icon or 134400,
            }
        end
    end

    return out
end

local function ClearCooldownFrame(cooldown)
    if not cooldown then
        return
    end
    if CooldownFrame_Clear then
        CooldownFrame_Clear(cooldown)
    elseif cooldown.Clear then
        cooldown:Clear()
    else
        cooldown:SetCooldown(0, 0, 1)
    end
    cooldown:Hide()
end

local function GetSpellCooldownData(spellID)
    if not spellID then
        return 0, 0, 0, 1
    end

    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if type(info) == "table" then
            return tonumber(info.startTime) or 0,
                   tonumber(info.duration) or 0,
                   tonumber(info.isEnabled) or 0,
                   tonumber(info.modRate) or 1
        end

        local s, d, e, m = C_Spell.GetSpellCooldown(spellID)
        if s ~= nil then
            return tonumber(s) or 0,
                   tonumber(d) or 0,
                   tonumber(e) or 0,
                   tonumber(m) or 1
        end
    end

    ---@diagnostic disable-next-line: deprecated
    local s, d, e, m = GetSpellCooldown(spellID)
    return tonumber(s) or 0,
           tonumber(d) or 0,
           tonumber(e) or 0,
           tonumber(m) or 1
end

local function ApplySpellCooldown(cooldown, spellID, debugEndTime, debugDuration)
    if not cooldown then
        return
    end

    if debugEndTime and debugEndTime > GetTime() then
        local total = tonumber(debugDuration) or (debugEndTime - GetTime())
        if not total or total <= 0 then
            total = 30
        end
        local start = debugEndTime - total
        cooldown:Show()
        cooldown:SetCooldown(start, total, 1)
        return
    end

    if not spellID then
        ClearCooldownFrame(cooldown)
        return
    end

    local startTime, duration, isEnabled, modRate = GetSpellCooldownData(spellID)
    if isEnabled == 0 or startTime <= 0 or duration <= 1.5 then
        ClearCooldownFrame(cooldown)
        return
    end

    cooldown:Show()
    cooldown:SetCooldown(startTime, duration, modRate or 1)
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
        local an = strlower(a.name or "")
        local bn = strlower(b.name or "")
        if an == bn then
            return (a.name or "") < (b.name or "")
        end
        return an < bn
    end)

    return result
end

local function GetDisplayedSeasonDungeons()
    local dungeons = GetSeasonDungeons()
    local out = {}
    for i = 1, math.min(YOUR_SCORES_ICON_COUNT, #dungeons) do
        out[#out + 1] = dungeons[i]
    end
    return out
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

local function CreateIconEdgeBorder(parent, iconTexture)
    local border = {}
    local thickness = 1

    border.top = parent:CreateTexture(nil, "OVERLAY")
    border.top:SetColorTexture(0.45, 0.45, 0.45, 0.95)
    border.top:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -1, 1)
    border.top:SetPoint("TOPRIGHT", iconTexture, "TOPRIGHT", 1, 1)
    border.top:SetHeight(thickness)

    border.bottom = parent:CreateTexture(nil, "OVERLAY")
    border.bottom:SetColorTexture(0.45, 0.45, 0.45, 0.95)
    border.bottom:SetPoint("BOTTOMLEFT", iconTexture, "BOTTOMLEFT", -1, -1)
    border.bottom:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 1, -1)
    border.bottom:SetHeight(thickness)

    border.left = parent:CreateTexture(nil, "OVERLAY")
    border.left:SetColorTexture(0.45, 0.45, 0.45, 0.95)
    border.left:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -1, 1)
    border.left:SetPoint("BOTTOMLEFT", iconTexture, "BOTTOMLEFT", -1, -1)
    border.left:SetWidth(thickness)

    border.right = parent:CreateTexture(nil, "OVERLAY")
    border.right:SetColorTexture(0.45, 0.45, 0.45, 0.95)
    border.right:SetPoint("TOPRIGHT", iconTexture, "TOPRIGHT", 1, 1)
    border.right:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 1, -1)
    border.right:SetWidth(thickness)

    function border:SetColor(r, g, b, a)
        self.top:SetColorTexture(r, g, b, a)
        self.bottom:SetColorTexture(r, g, b, a)
        self.left:SetColorTexture(r, g, b, a)
        self.right:SetColorTexture(r, g, b, a)
    end

    return border
end

local function SectionLabel(parent, yOffset, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)
    fs:SetText(text)
    return fs
end

-- ── Build the main frame ──────────────────────────────────────────────────────

local function BuildFrame()
    local f = CreateFrame("Frame", "KeyPartyMainFrame", UIParent, "BackdropTemplate")
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

    local titleBanner = titleBar:CreateTexture(nil, "ARTWORK")
    titleBanner:SetAllPoints(titleBar)
    titleBanner:SetTexCoord(0, 1, 0, 1)
    titleBanner:SetTexture(TITLE_ICON_FALLBACK)
    titleBanner:SetTexture(TITLE_BANNER_PATH)
    f.titleBanner = titleBanner

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(HEADER_ICON_BUTTON_W, HEADER_ICON_BUTTON_H)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -HEADER_ICON_BUTTON_MARGIN, -HEADER_ICON_BUTTON_MARGIN)
    ConfigureHeaderIconButton(closeBtn, CLOSE_ICON_TEXTURE, "Close", "ANCHOR_LEFT")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetSize(HEADER_ICON_BUTTON_W, HEADER_ICON_BUTTON_H)
    refreshBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -HEADER_ICON_BUTTON_GAP, 0)
    ConfigureHeaderIconButton(refreshBtn, nil, "Refresh", "ANCHOR_RIGHT", nil, REFRESH_ICON_ATLAS)
    refreshBtn:SetScript("OnClick", function()
        if KL_UI.OnRefresh then KL_UI.OnRefresh() end
    end)


    -- ── Layout anchors ────────────────────────────────────────────────────────
    -- Section yOffsets from top of f (all negative)
    local Y_RATING_LABEL  = -(TITLE_BAR_H + 4)
    local Y_RATING_ROWS   = Y_RATING_LABEL - 18
    local RATING_H        = ROW_H * 5          -- default visible height (5 rows)
    local Y_SEP1          = Y_RATING_ROWS - RATING_H - 6
    local Y_KEY_LABEL     = Y_SEP1 - 8
    local Y_KEY_ROWS      = Y_KEY_LABEL - 18
    local KEY_H           = BEST_KEY_ICON_SIZE + 28
    local Y_SEP2          = Y_KEY_ROWS - KEY_H - 6
    local Y_SCORE_LABEL   = Y_SEP2 - 8
    local Y_SCORE_ROW     = Y_SCORE_LABEL - 18
    local SCORE_H         = 84
    local Y_SEP3          = Y_SCORE_ROW - SCORE_H - 6
    local Y_BEST_LABEL    = Y_SEP3 - 8
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

    local keyArea = CreateFrame("Frame", nil, f)
    keyArea:SetPoint("TOPLEFT", f, "TOPLEFT", 12, Y_KEY_ROWS)
    keyArea:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, Y_KEY_ROWS)
    keyArea:SetHeight(KEY_H)
    f.keyArea = keyArea

    local keyAreaEmpty = keyArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    keyAreaEmpty:SetPoint("CENTER", keyArea, "CENTER", 0, 0)
    keyAreaEmpty:SetText("No party keystones shared")
    keyAreaEmpty:SetTextColor(0.5, 0.5, 0.5, 1)
    keyAreaEmpty:Hide()
    f.keyAreaEmpty = keyAreaEmpty

    f._keySlots = {}
    for i = 1, PARTY_KEYSTONE_ICON_COUNT do
        local slot = CreateFrame("Frame", nil, keyArea)
        slot:SetSize(BEST_KEY_ICON_SIZE + 8, KEY_H)
        slot:Hide()

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOP", slot, "TOP", 0, 0)
        icon:SetSize(BEST_KEY_ICON_SIZE, BEST_KEY_ICON_SIZE)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetTexture(GetEmptyKeystoneIcon())

        local border = CreateIconEdgeBorder(slot, icon)

        local levelText = slot:CreateFontString(nil, "OVERLAY")
        levelText:SetDrawLayer("OVERLAY", 5)
        levelText:SetPoint("CENTER", icon, "CENTER", 0, 0)
        do
            local fontPath = select(1, GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF"
            levelText:SetFont(fontPath, 34, "OUTLINE")
        end
        levelText:SetTextColor(1, 1, 1, 1)
        levelText:SetText("")

        local abbrText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        abbrText:SetDrawLayer("OVERLAY", 6)
        abbrText:SetPoint("TOP", icon, "TOP", 0, -4)
        abbrText:SetTextColor(1, 1, 1, 1)
        abbrText:SetText("")

        local ownerText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ownerText:SetPoint("TOP", icon, "BOTTOM", 0, -3)
        ownerText:SetWidth(BEST_KEY_ICON_SIZE)
        ownerText:SetJustifyH("CENTER")
        ownerText:SetTextColor(0.92, 0.92, 0.95, 1)
        ownerText:SetText("")

        slot.icon = icon
        slot.border = border
        slot.levelText = levelText
        slot.abbrText = abbrText
        slot.ownerText = ownerText
        f._keySlots[i] = slot
    end

    local weeklyAffixSlot = CreateFrame("Frame", nil, keyArea)
    weeklyAffixSlot:SetSize(BEST_KEY_ICON_SIZE + 8, KEY_H)
    weeklyAffixSlot:Hide()

    local weeklyAffixIcons = {}
    local affixCellSize = math.floor((BEST_KEY_ICON_SIZE - 6) / 2)
    local affixOffsets = {
        { x = 0, y = 0 },
        { x = affixCellSize + 2, y = 0 },
        { x = 0, y = -(affixCellSize + 2) },
        { x = affixCellSize + 2, y = -(affixCellSize + 2) },
    }
    for idx, pos in ipairs(affixOffsets) do
        local icon = weeklyAffixSlot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", weeklyAffixSlot, "TOPLEFT", pos.x, pos.y)
        icon:SetSize(affixCellSize, affixCellSize)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetTexture(134400)
        icon:Hide()

        local border = CreateIconEdgeBorder(weeklyAffixSlot, icon)

        local levelText = weeklyAffixSlot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        levelText:SetDrawLayer("OVERLAY", 5)
        levelText:SetPoint("CENTER", icon, "CENTER", 0, 0)
        levelText:SetTextColor(1, 1, 1, 1)
        levelText:SetText("")
        levelText:Hide()

        local hitbox = CreateFrame("Frame", nil, weeklyAffixSlot)
        hitbox:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        hitbox:SetSize(affixCellSize, affixCellSize)
        hitbox:EnableMouse(true)
        hitbox:Hide()
        hitbox:SetScript("OnEnter", function(self)
            if not self.affixName then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.affixName, 1, 0.82, 0)
            if self.affixLevel and self.affixLevel ~= "" then
                GameTooltip:AddLine("Activated at " .. self.affixLevel, 0.85, 0.85, 1)
            end
            if self.affixDescription and self.affixDescription ~= "" then
                GameTooltip:AddLine(self.affixDescription, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        hitbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        weeklyAffixIcons[idx] = {
            icon = icon,
            border = border,
            levelText = levelText,
            hitbox = hitbox,
        }
    end

    f.weeklyAffixSlot = weeklyAffixSlot
    f.weeklyAffixIcons = weeklyAffixIcons

    Separator(f, Y_SEP2)

    -- ── YOUR SCORES section ───────────────────────────────────────────────────
    SectionLabel(f, Y_SCORE_LABEL, "|cffFFD100YOUR SCORES|r")

    local scoreArea = CreateFrame("Frame", nil, f)
    scoreArea:SetPoint("TOPLEFT", f, "TOPLEFT", 12, Y_SCORE_ROW)
    scoreArea:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, Y_SCORE_ROW)
    scoreArea:SetHeight(SCORE_H)
    f.scoreArea = scoreArea

    f._scoreSlots = {}
    for i = 1, YOUR_SCORES_ICON_COUNT do
        local slot = CreateFrame("Button", nil, scoreArea, "SecureActionButtonTemplate")
        slot:SetHeight(SCORE_H)
        slot:EnableMouse(true)

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOP", slot, "TOP", 0, 0)
        icon:SetSize(52, 52)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetTexture(134400)

        local border = CreateIconEdgeBorder(slot, icon)

        local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)
        cooldown:SetFrameLevel(slot:GetFrameLevel() + 30)
        cooldown:SetDrawSwipe(true)
        cooldown:SetDrawEdge(true)
        if cooldown.SetHideCountdownNumbers then
            cooldown:SetHideCountdownNumbers(false)
        end
        cooldown:Hide()

        slot:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Your Dungeon Score", 1, 0.82, 0)
            if btn.mapName then
                GameTooltip:AddLine(btn.mapName, 1, 1, 1)
            end
            if btn.portalSpellName then
                GameTooltip:AddLine("Click to teleport", 0.2, 1, 0.2)
                GameTooltip:AddLine(btn.portalSpellName, 0.8, 0.8, 1)
            else
                GameTooltip:AddLine("No teleport available", 1, 0.2, 0.2)
            end
            GameTooltip:Show()
        end)

        slot:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local scoreOutline = {}
        local outlineOffsets = {
            { x = -1, y = 0 },
            { x = 1, y = 0 },
            { x = 0, y = -1 },
            { x = 0, y = 1 },
        }
        for _, o in ipairs(outlineOffsets) do
            local fs = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            fs:SetDrawLayer("OVERLAY", 1)
            fs:SetPoint("CENTER", icon, "CENTER", o.x, o.y)
            fs:SetText("-")
            fs:SetTextColor(0, 0, 0, 0.95)
            scoreOutline[#scoreOutline + 1] = fs
        end

        local scoreText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        scoreText:SetDrawLayer("OVERLAY", 5)
        scoreText:SetPoint("CENTER", icon, "CENTER", 0, 0)
        scoreText:SetText("-")
        scoreText:SetShadowColor(0, 0, 0, 0)
        scoreText:SetShadowOffset(0, 0)

        local abbrText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        abbrText:SetPoint("TOP", icon, "BOTTOM", 0, -3)
        abbrText:SetTextColor(0.85, 0.85, 0.90, 1)
        abbrText:SetText("-")

        local keyLevelText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        keyLevelText:SetDrawLayer("OVERLAY", 5)
        keyLevelText:SetPoint("TOP", icon, "TOP", 0, -3)
        keyLevelText:SetTextColor(1, 1, 1, 1)
        keyLevelText:SetText("")

        slot.icon = icon
        slot.border = border
        slot.cooldown = cooldown
        slot.scoreOutline = scoreOutline
        slot.scoreText = scoreText
        slot.abbrText = abbrText
        slot.keyLevelText = keyLevelText
        f._scoreSlots[i] = slot
    end

    f:SetScript("OnSizeChanged", function(frame)
        if not frame._scoreSlots or not frame.scoreArea then
            return
        end
        local width = frame.scoreArea:GetWidth() or 0
        if width <= 0 then
            return
        end

        local slotW = width / YOUR_SCORES_ICON_COUNT
        local iconSize = math.floor(math.min(54, math.max(40, slotW - 10)))

        for i = 1, YOUR_SCORES_ICON_COUNT do
            local slot = frame._scoreSlots[i]
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", frame.scoreArea, "TOPLEFT", (i - 1) * slotW, 0)
            slot:SetWidth(slotW)
            slot.icon:SetSize(iconSize, iconSize)
        end
    end)

    Separator(f, Y_SEP3)

    -- ── BEST PROGRESSION KEY section ──────────────────────────────────────────
    SectionLabel(f, Y_BEST_LABEL, "|cffFFD100BEST PROGRESSION KEY|r")

    local bestBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bestBox:SetPoint("TOPLEFT",  f, "TOPLEFT",  12, Y_BEST_BOX)
    bestBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, Y_BEST_BOX)
    bestBox:SetHeight(100)
    ApplyBackdrop(bestBox, 0.05, 0.05, 0.07, 1, 0.80, 0.65, 0.00, 0.90)

    local bestContent = CreateFrame("Frame", nil, bestBox)
    bestContent:SetPoint("TOPLEFT", bestBox, "TOPLEFT", 12, -10)
    bestContent:SetPoint("TOPRIGHT", bestBox, "TOPRIGHT", -12, -10)
    bestContent:SetHeight(BEST_KEY_ICON_SIZE)

    local bestIconButton = CreateFrame("Button", nil, bestContent, "SecureActionButtonTemplate")
    bestIconButton:SetPoint("TOPLEFT", bestContent, "TOPLEFT", 0, 0)
    bestIconButton:SetSize(bestContent:GetHeight(), bestContent:GetHeight())

    local bestIcon = bestIconButton:CreateTexture(nil, "ARTWORK")
    bestIcon:SetAllPoints()
    bestIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bestIcon:SetTexture(GetEmptyKeystoneIcon())

    local bestIconBorder = CreateIconEdgeBorder(bestIconButton, bestIcon)

    local bestCooldown = CreateFrame("Cooldown", nil, bestIconButton, "CooldownFrameTemplate")
    bestCooldown:SetAllPoints(bestIcon)
    bestCooldown:SetFrameLevel(bestIconButton:GetFrameLevel() + 30)
    bestCooldown:SetDrawSwipe(true)
    bestCooldown:SetDrawEdge(true)
    if bestCooldown.SetHideCountdownNumbers then
        bestCooldown:SetHideCountdownNumbers(false)
    end
    bestCooldown:Hide()

    local bestKeyLevelText = bestIconButton:CreateFontString(nil, "OVERLAY")
    bestKeyLevelText:SetDrawLayer("OVERLAY", 5)
    bestKeyLevelText:SetPoint("CENTER", bestIcon, "CENTER", 0, 0)
    do
        local fontPath = select(1, GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF"
        bestKeyLevelText:SetFont(fontPath, 34, "OUTLINE")
    end
    bestKeyLevelText:SetTextColor(1, 1, 1, 1)
    bestKeyLevelText:SetText("")

    f.bestKeyIconButton = bestIconButton
    f.bestKeyIcon = bestIcon
    f.bestKeyIconBorder = bestIconBorder
    f.bestKeyCooldown = bestCooldown
    f.bestKeyLevelText = bestKeyLevelText

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
    statusText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, STATUS_TEXT_BOTTOM_OFFSET)
    statusText:SetTextColor(0.45, 0.45, 0.50, 1)
    statusText:SetText("No data yet. Click Refresh.")
    f.statusText = statusText

    local autoOpenCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    autoOpenCheck:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, AUTO_OPEN_OPTION_BOTTOM_OFFSET)
    autoOpenCheck:SetScale(OPTION_CHECKBOX_SCALE)
    autoOpenCheck:SetChecked(false)

    local autoOpenLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    autoOpenLabel:SetPoint("LEFT", autoOpenCheck, "RIGHT", -1, 0)
    autoOpenLabel:SetText("Auto open after dungeon finish")
    autoOpenLabel:SetTextColor(0.78, 0.78, 0.82, 1)

    autoOpenCheck:SetScript("OnClick", function(btn)
        if KL_UI.OnToggleAutoOpenAtDungeonEnd then
            KL_UI.OnToggleAutoOpenAtDungeonEnd(btn:GetChecked() == true)
        end
    end)

    local partyAnnouncementCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    partyAnnouncementCheck:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, PARTY_CHAT_OPTION_BOTTOM_OFFSET)
    partyAnnouncementCheck:SetScale(OPTION_CHECKBOX_SCALE)
    partyAnnouncementCheck:SetChecked(false)

    local partyAnnouncementLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    partyAnnouncementLabel:SetPoint("TOPLEFT", partyAnnouncementCheck, "TOPRIGHT", -1, -1)
    partyAnnouncementLabel:SetWidth(FRAME_W - 56)
    partyAnnouncementLabel:SetJustifyH("LEFT")
    partyAnnouncementLabel:SetJustifyV("TOP")
    partyAnnouncementLabel:SetText("Party chat announcement Best Progression Key after dungeon finish")
    partyAnnouncementLabel:SetTextColor(0.78, 0.78, 0.82, 1)

    partyAnnouncementCheck:SetScript("OnClick", function(btn)
        if KL_UI.OnTogglePartyChatAnnouncementAtDungeonEnd then
            KL_UI.OnTogglePartyChatAnnouncementAtDungeonEnd(btn:GetChecked() == true)
        end
    end)

    f.autoOpenAtDungeonEndCheck = autoOpenCheck
    f.autoOpenAtDungeonEndLabel = autoOpenLabel
    f.partyChatAnnouncementAtDungeonEndCheck = partyAnnouncementCheck
    f.partyChatAnnouncementAtDungeonEndLabel = partyAnnouncementLabel

    return f
end

local mainFrame = BuildFrame()
KL_UI.frame = mainFrame

function KL_UI:RefreshCooldownIndicators()
    local f = self.frame
    if not f then
        return
    end

    local debugEndTime = nil
    local debugDuration = nil
    if self.debugCooldownEndTime and self.debugCooldownEndTime > GetTime() then
        debugEndTime = self.debugCooldownEndTime
        debugDuration = self.debugCooldownDuration
    end

    if f._scoreSlots then
        for _, slot in ipairs(f._scoreSlots) do
            ApplySpellCooldown(slot.cooldown, slot.teleportSpellID, debugEndTime, debugDuration)
        end
    end

    ApplySpellCooldown(f.bestKeyCooldown, f.bestKeyTeleportSpellID, debugEndTime, debugDuration)
end

function KL_UI:SetDebugCooldown(seconds)
    local sec = tonumber(seconds)
    if sec and sec > 0 then
        sec = math.floor(sec)
        self.debugCooldownDuration = sec
        self.debugCooldownEndTime = GetTime() + sec
    else
        self.debugCooldownDuration = nil
        self.debugCooldownEndTime = nil
    end

    self:RefreshCooldownIndicators()
end

function KL_UI:StartCooldownTicker()
    if self._cooldownTicker then
        return
    end

    self._cooldownTicker = C_Timer.NewTicker(0.15, function()
        if self.frame and self.frame:IsShown() then
            self:RefreshCooldownIndicators()
        end
    end)
end

function KL_UI:StopCooldownTicker()
    if self._cooldownTicker then
        self._cooldownTicker:Cancel()
        self._cooldownTicker = nil
    end
end

mainFrame:SetScript("OnShow", function()
    KL_UI:StartCooldownTicker()
    KL_UI:RefreshCooldownIndicators()
    if KL_UI.ShouldRefreshOnShow and KL_UI.ShouldRefreshOnShow() and KL_UI.OnRefreshOnShow then
        KL_UI.OnRefreshOnShow()
    end
end)

mainFrame:SetScript("OnHide", function()
    KL_UI:StopCooldownTicker()
end)

-- ── Public: populate the frame with current data ──────────────────────────────

function KL_UI:Populate(members, best)
    local f    = self.frame
    local rows = f._ratingRows
    local keySlots = f._keySlots

    -- Hide all pre-created rows
    for i = 1, MAX_ROWS do
        rows[i].name:Hide()
        rows[i].value:Hide()
    end
    for i = 1, PARTY_KEYSTONE_ICON_COUNT do
        keySlots[i]:Hide()
    end
    if f.weeklyAffixSlot then
        f.weeklyAffixSlot:Hide()
    end

    local names = {}
    for name in pairs(members) do
        names[#names + 1] = name
    end
    table.sort(names)

    local addonTable = _G.KeyParty
    local GetMapName = (addonTable and addonTable.GetMapName) or function(id)
        return "Map " .. tostring(id)
    end

    local function FindPlayerMember()
        local playerFull = GetUnitName("player", true) or UnitName("player")
        local playerShort = CanonicalName(playerFull)
        if members[playerShort] then
            return members[playerShort]
        end

        for name, data in pairs(members) do
            if CanonicalName(name) == playerShort then
                return data
            end
        end
        return nil
    end

    -- Rating rows
    for i, name in ipairs(names) do
        if i > MAX_ROWS then break end
        local m   = members[name]
        local rat = m.totalRating or 0
        rows[i].name:SetText(ColoredPlayerName(GroupRatingDisplayName(name, m), m))
        rows[i].value:SetText(ColoredRating(rat))
        rows[i].name:Show()
        rows[i].value:Show()
    end

    -- Party keystone icons (horizontal)
    local keyedMembers = {}
    for _, name in ipairs(names) do
        local m = members[name]
        if m and m.key and m.key.level and m.key.level > 0 and m.key.mapID then
            keyedMembers[#keyedMembers + 1] = {
                owner = name,
                mapID = m.key.mapID,
                level = m.key.level,
            }
        end
    end

    local slotCount = math.min(PARTY_KEYSTONE_ICON_COUNT, #keyedMembers)
    if slotCount == 0 then
        if f.keyAreaEmpty then
            f.keyAreaEmpty:Show()
        end
    else
        if f.keyAreaEmpty then
            f.keyAreaEmpty:Hide()
        end

        local keyAreaWidth = (f.keyArea and f.keyArea:GetWidth()) or 0
        if keyAreaWidth <= 0 then
            keyAreaWidth = FRAME_W - 24
        end
        local slotW = keyAreaWidth / KEY_AREA_COLUMN_COUNT

        for i = 1, slotCount do
            local slot = keySlots[i]
            local info = keyedMembers[i]
            local ownerData = members[info.owner]

            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", f.keyArea, "TOPLEFT", (i - 1) * slotW, 0)
            slot:SetWidth(slotW)
            slot.icon:SetTexture(GetMapIcon(info.mapID))
            slot.levelText:SetText("+" .. tostring(info.level))
            if slot.abbrText then
                slot.abbrText:SetText(AbbreviateDungeonName(GetMapName(info.mapID)))
            end
            do
                local displayName = CanonicalName(info.owner)
                local classToken = ownerData and ownerData.classToken
                local classColors = rawget(_G, "CUSTOM_CLASS_COLORS") or rawget(_G, "RAID_CLASS_COLORS")
                local classColor = classToken and classColors and classColors[classToken]
                if classColor then
                    slot.ownerText:SetTextColor(classColor.r or 1, classColor.g or 1, classColor.b or 1, 1)
                else
                    slot.ownerText:SetTextColor(0.92, 0.92, 0.95, 1)
                end
                slot.ownerText:SetText(EllipsizeTextToWidth(slot.ownerText, displayName, BEST_KEY_ICON_SIZE))
            end
            slot.border:SetColor(0.45, 0.45, 0.45, 0.95)
            slot:Show()
        end
    end

    if f.weeklyAffixSlot and f.weeklyAffixIcons then
        local keyAreaWidth = (f.keyArea and f.keyArea:GetWidth()) or 0
        if keyAreaWidth <= 0 then
            keyAreaWidth = FRAME_W - 24
        end
        local slotW = keyAreaWidth / KEY_AREA_COLUMN_COUNT
        local currentAffixes = GetCurrentAffixList()

        f.weeklyAffixSlot:ClearAllPoints()
        f.weeklyAffixSlot:SetPoint("TOPLEFT", f.keyArea, "TOPLEFT", (KEY_AREA_COLUMN_COUNT - 1) * slotW, 0)
        f.weeklyAffixSlot:SetWidth(slotW)
        f.weeklyAffixSlot:Show()

        for idx = 1, 4 do
            local cell = f.weeklyAffixIcons[idx]
            local affix = currentAffixes[idx]
            if affix then
                cell.icon:SetTexture(affix.icon)
                cell.icon:Show()
                cell.border:SetColor(0.45, 0.45, 0.45, 0.95)
                cell.levelText:SetText(WEEKLY_AFFIX_LEVEL_LABELS[idx] or "")
                cell.levelText:Show()
                if cell.hitbox then
                    cell.hitbox.affixName = affix.name
                    cell.hitbox.affixDescription = affix.description
                    cell.hitbox.affixLevel = WEEKLY_AFFIX_LEVEL_LABELS[idx] or ""
                    cell.hitbox:Show()
                end
            else
                cell.icon:Hide()
                cell.levelText:Hide()
                if cell.hitbox then
                    cell.hitbox.affixName = nil
                    cell.hitbox.affixDescription = nil
                    cell.hitbox.affixLevel = nil
                    cell.hitbox:Hide()
                end
            end
        end
    end

    -- Your scores row (8 dungeons from current season list)
    local playerMember = FindPlayerMember()
    local playerScores = (playerMember and playerMember.dungeonScores) or {}
    local playerLevels = (playerMember and playerMember.dungeonLevels) or {}
    local dungeons = GetDisplayedSeasonDungeons()

    for i = 1, YOUR_SCORES_ICON_COUNT do
        local slot = f._scoreSlots[i]
        local dungeon = dungeons[i]

        if dungeon then
            local score = tonumber(playerScores[dungeon.mapID]) or 0
            local spellID = addonTable and addonTable.GetTeleportSpellIDForMap and addonTable.GetTeleportSpellIDForMap(dungeon.mapID)
            local spellName = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or nil

            slot.mapName = dungeon.name
            slot.portalSpellName = spellName
            slot.teleportSpellID = spellID

            if not InCombatLockdown() then
                if spellID then
                    slot:SetAttribute("type", "spell")
                    slot:SetAttribute("spell", spellID)
                    slot:EnableMouse(true)
                    slot.border:SetColor(0.45, 0.45, 0.45, 0.95)
                else
                    slot:SetAttribute("type", nil)
                    slot:SetAttribute("spell", nil)
                    slot:EnableMouse(true)
                    slot.border:SetColor(1.00, 0.20, 0.20, 0.95)
                end
            else
                if spellID then
                    slot.border:SetColor(0.45, 0.45, 0.45, 0.95)
                else
                    slot.border:SetColor(1.00, 0.20, 0.20, 0.95)
                end
            end

            local level = tonumber(playerLevels[dungeon.mapID]) or 0
            slot.icon:SetTexture(GetMapIcon(dungeon.mapID))
            ApplyIconScoreText(slot, score)
            slot.abbrText:SetText(AbbreviateDungeonName(dungeon.name))
            if slot.keyLevelText then
                slot.keyLevelText:SetText(level > 0 and ("+" .. level) or "")
            end
        else
            slot.mapName = nil
            slot.portalSpellName = nil
            slot.teleportSpellID = nil
            if not InCombatLockdown() then
                slot:SetAttribute("type", nil)
                slot:SetAttribute("spell", nil)
                slot:EnableMouse(true)
            end
            slot.border:SetColor(0.45, 0.45, 0.45, 0.95)
            slot.icon:SetTexture(134400)
            ApplyIconScoreText(slot, 0)
            slot.abbrText:SetText("-")
            if slot.keyLevelText then
                slot.keyLevelText:SetText("")
            end
        end
    end

    f:GetScript("OnSizeChanged")(f)

    -- Best key box
    if best then
        local spellID = addonTable and addonTable.GetTeleportSpellIDForMap and addonTable.GetTeleportSpellIDForMap(best.mapID)
        local spellName = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or nil

        f.bestKeyIconButton.mapName = GetMapName(best.mapID)
        f.bestKeyIconButton.portalSpellName = spellName
        f.bestKeyTeleportSpellID = spellID

        if not InCombatLockdown() then
            if spellID then
                f.bestKeyIconButton:SetAttribute("type", "spell")
                f.bestKeyIconButton:SetAttribute("spell", spellID)
                f.bestKeyIconButton:EnableMouse(true)
                f.bestKeyIconBorder:SetColor(0.45, 0.45, 0.45, 0.95)
            else
                f.bestKeyIconButton:SetAttribute("type", nil)
                f.bestKeyIconButton:SetAttribute("spell", nil)
                f.bestKeyIconButton:EnableMouse(true)
                f.bestKeyIconBorder:SetColor(1.00, 0.20, 0.20, 0.95)
            end
        else
            if spellID then
                f.bestKeyIconBorder:SetColor(0.45, 0.45, 0.45, 0.95)
            else
                f.bestKeyIconBorder:SetColor(1.00, 0.20, 0.20, 0.95)
            end
        end

        f.bestKeyIcon:SetTexture(GetMapIcon(best.mapID))
        if f.bestKeyLevelText then
            f.bestKeyLevelText:SetText("+" .. best.level)
        end
        f.bestKeyName:SetText(string.format("|cffffd100%s|r", GetMapName(best.mapID)))
        local ownerData = best.owner and members[best.owner] or nil
        f.bestKeyOwner:SetText("Owner: " .. ColoredPlayerName(best.owner, ownerData))
        f.bestKeyReason:SetText(string.format(
            "%d / %d players missing score on this dungeon   *   Group avg  %.0f",
            best.missingCount, best.memberCount, best.avgScore))
    else
        f.bestKeyIconButton.mapName = nil
        f.bestKeyIconButton.portalSpellName = nil
        f.bestKeyTeleportSpellID = nil
        if not InCombatLockdown() then
            f.bestKeyIconButton:SetAttribute("type", nil)
            f.bestKeyIconButton:SetAttribute("spell", nil)
            f.bestKeyIconButton:EnableMouse(true)
        end
        f.bestKeyIconBorder:SetColor(0.45, 0.45, 0.45, 0.95)
        f.bestKeyIcon:SetTexture(GetEmptyKeystoneIcon())
        if f.bestKeyLevelText then
            f.bestKeyLevelText:SetText("")
        end
        f.bestKeyName:SetText("|cff808080No keystones available|r")
        f.bestKeyOwner:SetText("")
        f.bestKeyReason:SetText(
            "|cff606060Ask group members to run Key Party and use /kp refresh.|r")
    end

    f.statusText:SetText(string.format("Last refresh: %s", date("%H:%M:%S")))

    self:RefreshCooldownIndicators()

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

function KL_UI:SetAutoOpenAtDungeonEndChecked(enabled)
    if self.frame and self.frame.autoOpenAtDungeonEndCheck then
        self.frame.autoOpenAtDungeonEndCheck:SetChecked(enabled and true or false)
    end
end

function KL_UI:SetPartyChatAnnouncementAtDungeonEndChecked(enabled)
    if self.frame and self.frame.partyChatAnnouncementAtDungeonEndCheck then
        self.frame.partyChatAnnouncementAtDungeonEndCheck:SetChecked(enabled and true or false)
    end
end

function KL_UI:GetInstanceScoreColorDebugLines()
    local lines = {}
    if not self.frame or not self.frame._scoreSlots then
        return lines
    end

    for _, slot in ipairs(self.frame._scoreSlots) do
        if slot.mapName then
            local score = tonumber(slot.lastScoreValue) or 0
            local color = slot.lastScoreColor
            if color and color.r and color.g and color.b then
                local source = tostring(slot.lastScoreColorSource or "unknown")
                lines[#lines + 1] = string.format(
                    "%s: score=%d rgb=%.3f/%.3f/%.3f source=%s",
                    tostring(slot.mapName),
                    math.floor(score),
                    tonumber(color.r) or 0,
                    tonumber(color.g) or 0,
                    tonumber(color.b) or 0,
                    source
                )
            else
                lines[#lines + 1] = string.format(
                    "%s: score=%d rgb=n/a source=n/a",
                    tostring(slot.mapName),
                    math.floor(score)
                )
            end
        end
    end

    return lines
end
