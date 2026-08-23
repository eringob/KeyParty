-- KeyPartyUI.lua
-- Modern UI frame for Key Party. Loaded after KeyParty.lua.

local KL_UI = {}
_G.KL_UI = KL_UI

-- ── Constants ─────────────────────────────────────────────────────────────────

local FRAME_W   = 620
local ROW_H     = 18     -- pixels per member row
local MAX_ROWS  = 25     -- pool size per section (handles raids)
local COL_NAME_X  = 14
local COL_VALUE_X = 400
local COL_BEST_X  = 455   -- best-dungeon icon+abbr column in GROUP RATINGS
local TITLE_BANNER_PATH = "Interface\\AddOns\\KeyParty\\media\\title-banner.png"
local TITLE_ICON_FALLBACK = 134419
local TITLE_BANNER_FALLBACK_W = 1418
local TITLE_BANNER_FALLBACK_H = 389
local function GetBannerSourceDimensions()
    local w = TITLE_BANNER_FALLBACK_W
    local h = TITLE_BANNER_FALLBACK_H

    local getTextureFileDimensions = rawget(_G, "GetTextureFileDimensions")
    if type(getTextureFileDimensions) == "function" then
        local ok, fileW, fileH = pcall(getTextureFileDimensions, TITLE_BANNER_PATH)
        fileW = tonumber(fileW)
        fileH = tonumber(fileH)
        if ok and fileW and fileH and fileW > 0 and fileH > 0 then
            w = fileW
            h = fileH
        end
    end

    return w, h
end
local TITLE_BANNER_SOURCE_W, TITLE_BANNER_SOURCE_H = GetBannerSourceDimensions()
local FRAME_BODY_H = 540
local HEADER_ICON_BUTTON_W = 28
local HEADER_ICON_BUTTON_H = 22
local HEADER_ICON_SIZE = 14
local HEADER_ICON_BUTTON_MARGIN = 4
local HEADER_ICON_BUTTON_GAP = 2
local TITLE_CONTROL_STRIP_H = HEADER_ICON_BUTTON_H + (HEADER_ICON_BUTTON_MARGIN * 2)
local TITLE_BANNER_H = math.floor((FRAME_W * TITLE_BANNER_SOURCE_H) / TITLE_BANNER_SOURCE_W + 0.5)
local TITLE_BAR_H = TITLE_CONTROL_STRIP_H + TITLE_BANNER_H
local FRAME_H = FRAME_BODY_H + TITLE_BAR_H
local FRAME_SCALE_DEFAULT = 1.0
local FRAME_SCALE_MIN     = 0.5
local FRAME_SCALE_MAX     = 2.0
local RESIZE_GRIP_TEXTURE = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local CLOSE_ICON_TEXTURE = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local REFRESH_ICON_ATLAS = "transmog-icon-revert"
local OPTIONS_ICON_TEXTURE = "Interface\\Buttons\\UI-OptionsButton"
local OPTIONS_ICON_ATLAS_CANDIDATES = {
    "services-icon-settings",
    "common-icon-gear",
}
local EMPTY_ICON_TEXTURE = 134400
local KEYSTONE_ICON_ITEM_CANDIDATES = { 180653, 158923, 138019 }
local YOUR_SCORES_ICON_COUNT = 8
local PARTY_KEYSTONE_ICON_COUNT = 5
local KEY_AREA_COLUMN_COUNT = 6
local BEST_KEY_ICON_SIZE = 74
local WEEKLY_AFFIX_LEVEL_LABELS = { "+2", "+4", "+7", "+10", "+12" }
local WEEKLY_AFFIX_COUNT = #WEEKLY_AFFIX_LEVEL_LABELS
local STATUS_TEXT_BOTTOM_OFFSET = 24
local PORTAL_BUTTON_SIZE = 52
local PORTAL_BUTTON_GAP = 4
local PORTAL_FRAME_GAP = 8
local PORTAL_SCALE_MIN = 0.6
local PORTAL_SCALE_MAX = 2.0
local PORTAL_SCALE_STEP = 0.1
local ALT_PANEL_W = 200
local ALT_PANEL_GAP = 8
local ALT_PANEL_MAX_ROWS = 10
local ALT_PANEL_ICON_SIZE = math.floor((BEST_KEY_ICON_SIZE * 0.50) + 0.5)
local ALT_PANEL_ROW_H = ALT_PANEL_ICON_SIZE + 6
local ALT_TOGGLE_BUTTON_W = 20
local ALT_TOGGLE_BUTTON_H = 72

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

local function GetBestDungeonMapID(member)
    local levels = member and member.dungeonLevels or {}
    local scores = member and member.dungeonScores or {}
    local function GetMapValue(values, mapID)
        return values[mapID] or values[tostring(mapID)]
    end
    local bestMapID = nil
    local bestLevel = 0
    local bestScore = 0
    for mapID, level in pairs(levels) do
        local score = tonumber(GetMapValue(scores, mapID)) or 0
        if level > bestLevel or (level == bestLevel and score > bestScore) then
            bestLevel = level
            bestScore = score
            bestMapID = mapID
        end
    end
    return bestMapID
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

local function ResolveFirstAvailableAtlas(candidates)
    if type(candidates) ~= "table" then
        return nil
    end

    local getAtlasInfo = C_Texture and C_Texture.GetAtlasInfo
    if type(getAtlasInfo) ~= "function" then
        return nil
    end

    for _, atlasName in ipairs(candidates) do
        if type(atlasName) == "string" and atlasName ~= "" then
            local info = getAtlasInfo(atlasName)
            if info then
                return atlasName
            end
        end
    end

    return nil
end

local function GetMapIcon(mapID, mapName)
    if not mapID or not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then
        return EMPTY_ICON_TEXTURE -- INV_Misc_QuestionMark
    end

    -- In modern builds this is typically: name, id, timeLimit, texture
    local apiName, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
    if texture then
        return texture
    end

    -- Some clients expose the current dungeon artwork under another map ID.
    -- Reuse that artwork by matching the explicit season name.
    if mapName and apiName ~= mapName then
        local mapTable = C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapTable() or {}
        for _, candidateMapID in ipairs(mapTable) do
            local candidateName, _, _, candidateTexture = C_ChallengeMode.GetMapUIInfo(candidateMapID)
            if candidateTexture and candidateName == mapName then
                return candidateTexture
            end
        end
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
            local enabledValue = 0
            if type(info.isEnabled) == "boolean" then
                enabledValue = info.isEnabled and 1 or 0
            else
                enabledValue = tonumber(info.isEnabled) or 0
            end
            return tonumber(info.startTime) or 0,
                   tonumber(info.duration) or 0,
                   enabledValue,
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

local function GetSharedTeleportCooldown(spellIDs)
    if type(spellIDs) ~= "table" then
        return nil
    end

    for _, spellID in ipairs(spellIDs) do
        local startTime, duration, isEnabled, modRate = GetSpellCooldownData(spellID)
        if isEnabled ~= 0 and startTime > 0 and duration > 1.5 then
            return {
                startTime = startTime,
                duration = duration,
                modRate = modRate or 1,
            }
        end
    end

    return nil
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
    local seen = {}
    local seenNames = {}

    local function NormalizeDungeonName(name)
        return strlower(tostring(name or "")):gsub("[^%a%d]", "")
    end

    local function ResolveCurrentMapID(mapID, name)
        if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
            local apiName = C_ChallengeMode.GetMapUIInfo(mapID)
            if apiName and NormalizeDungeonName(apiName) == NormalizeDungeonName(name) then
                return mapID
            end

            local mapTable = C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapTable() or {}
            for _, candidateMapID in ipairs(mapTable) do
                local candidateName = C_ChallengeMode.GetMapUIInfo(candidateMapID)
                if candidateName and NormalizeDungeonName(candidateName) == NormalizeDungeonName(name) then
                    return tonumber(candidateMapID) or candidateMapID
                end
            end
        end
        return mapID
    end

    -- Season data is authoritative. GetMapTable also contains legacy map IDs,
    -- which can represent the same dungeon a second time.
    local seasonData = (type(KeyParty_SeasonDungeons) == "table" and KeyParty_SeasonDungeons) or {}
    for _, entry in ipairs(seasonData) do
        local mapID = tonumber(entry.mapID)
        local entryName = tostring(entry.name or "")
        local nameKey = NormalizeDungeonName(entryName)
        if mapID and mapID > 0 and not seen[mapID] and nameKey ~= "" and not seenNames[nameKey] then
            local currentMapID = ResolveCurrentMapID(mapID, entryName)
            seen[currentMapID] = true
            seenNames[nameKey] = true
            result[#result + 1] = {
                mapID = currentMapID,
                name = entryName,
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
    f:SetScript("OnDragStart", function(frame)
        if InCombatLockdown and InCombatLockdown() then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff98Key Party|r: cannot move the window while in combat.")
            end
            return
        end
        frame:StartMoving()
    end)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:Hide()
    if UISpecialFrames then
        table.insert(UISpecialFrames, "KeyPartyMainFrame")
    end
    ApplyBackdrop(f, 0.08, 0.08, 0.11, 0.97, 0.38, 0.38, 0.48, 1)

    -- ── Title bar ─────────────────────────────────────────────────────────────
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(TITLE_BAR_H)
    ApplyBackdrop(titleBar, 0.04, 0.04, 0.06, 1, 0.38, 0.38, 0.48, 1)

    local titleBanner = titleBar:CreateTexture(nil, "ARTWORK")
    titleBanner:SetPoint("TOPLEFT",  titleBar, "TOPLEFT",  4, -TITLE_CONTROL_STRIP_H)
    titleBanner:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -4, -TITLE_CONTROL_STRIP_H)
    titleBanner:SetPoint("BOTTOM",   titleBar, "BOTTOM",    0, 4)
    titleBanner:SetTexCoord(0, 1, 0, 1)
    titleBanner:SetTexture(TITLE_ICON_FALLBACK)
    titleBanner:SetTexture(TITLE_BANNER_PATH)
    f.titleBanner = titleBanner

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    closeBtn:SetSize(HEADER_ICON_BUTTON_W, HEADER_ICON_BUTTON_H)
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -HEADER_ICON_BUTTON_MARGIN, -HEADER_ICON_BUTTON_MARGIN)
    ConfigureHeaderIconButton(closeBtn, CLOSE_ICON_TEXTURE, "Close", "ANCHOR_LEFT")
    closeBtn:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff98Key Party|r: cannot close the window while in combat.")
            end
            return
        end
        f:Hide()
    end)

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    refreshBtn:SetSize(HEADER_ICON_BUTTON_W, HEADER_ICON_BUTTON_H)
    refreshBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -HEADER_ICON_BUTTON_GAP, 0)
    ConfigureHeaderIconButton(refreshBtn, nil, "Refresh", "ANCHOR_RIGHT", nil, REFRESH_ICON_ATLAS)
    refreshBtn:SetScript("OnClick", function()
        if KL_UI.OnRefresh then KL_UI.OnRefresh() end
    end)

    local optionsBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    optionsBtn:SetSize(HEADER_ICON_BUTTON_W, HEADER_ICON_BUTTON_H)
    optionsBtn:SetPoint("TOPRIGHT", refreshBtn, "TOPLEFT", -HEADER_ICON_BUTTON_GAP, 0)
    local optionsAtlas = ResolveFirstAvailableAtlas(OPTIONS_ICON_ATLAS_CANDIDATES)
    ConfigureHeaderIconButton(
        optionsBtn,
        optionsAtlas and nil or OPTIONS_ICON_TEXTURE,
        "Open settings",
        "ANCHOR_RIGHT",
        nil,
        optionsAtlas
    )
    optionsBtn:SetScript("OnClick", function()
        local addonTable = _G.KeyParty
        if addonTable and addonTable.OpenOptionsPanel then
            addonTable.OpenOptionsPanel()
        end
    end)

    -- Scale buttons (- / +)
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

    local highestKeyRunHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    highestKeyRunHeader:SetPoint("TOPLEFT", f, "TOPLEFT", COL_BEST_X, Y_RATING_LABEL)
    highestKeyRunHeader:SetJustifyH("LEFT")
    highestKeyRunHeader:SetTextColor(1.0, 0.82, 0.0, 1)
    highestKeyRunHeader:SetText("HIGHEST KEY RUN")

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

        local bestAbbr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bestAbbr:SetPoint("TOPLEFT", f, "TOPLEFT", COL_BEST_X, y)
        bestAbbr:SetJustifyH("LEFT")
        bestAbbr:SetTextColor(0.85, 0.85, 0.90, 1)
        bestAbbr:Hide()

        local bestLevel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bestLevel:SetPoint("TOPLEFT", f, "TOPLEFT", COL_BEST_X + 40, y)
        bestLevel:SetJustifyH("LEFT")
        bestLevel:Hide()

        f._ratingRows[i] = { name = left, value = right, bestAbbr = bestAbbr, bestLevel = bestLevel }
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
        local slot = CreateFrame("Button", nil, keyArea, "SecureActionButtonTemplate")
        slot:SetSize(BEST_KEY_ICON_SIZE + 8, KEY_H)
        slot:RegisterForClicks("AnyUp", "AnyDown")
        slot:EnableMouse(true)
        slot:Hide()

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOP", slot, "TOP", 0, 0)
        icon:SetSize(BEST_KEY_ICON_SIZE, BEST_KEY_ICON_SIZE)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetTexture(GetEmptyKeystoneIcon())

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

        slot:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Party Keystone", 1, 0.82, 0)
            if btn.mapName then
                GameTooltip:AddLine(btn.mapName, 1, 1, 1)
            end
            if btn.keyLevel and btn.keyLevel > 0 then
                GameTooltip:AddLine("Keystone: +" .. tostring(btn.keyLevel), 0.9, 0.9, 1)
            end
            if btn.ownerName and btn.ownerName ~= "" then
                GameTooltip:AddLine("Owner: " .. tostring(btn.ownerName), 0.8, 0.8, 1)
            end
            if btn.teleportSpellID then
                GameTooltip:AddLine("Click to teleport", 0.2, 1, 0.2)
                if btn.portalSpellName then
                    GameTooltip:AddLine(btn.portalSpellName, 0.8, 0.8, 1)
                else
                    GameTooltip:AddLine("Known teleport spell", 0.8, 0.8, 1)
                end
            else
                GameTooltip:AddLine("No teleport available", 1, 0.2, 0.2)
            end
            GameTooltip:Show()
        end)

        slot:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        slot.icon = icon
        slot.border = border
        slot.cooldown = cooldown
        slot.levelText = levelText
        slot.abbrText = abbrText
        slot.ownerText = ownerText
        f._keySlots[i] = slot
    end

    local weeklyAffixSlot = CreateFrame("Frame", nil, keyArea)
    weeklyAffixSlot:SetSize(BEST_KEY_ICON_SIZE + 8, KEY_H)
    weeklyAffixSlot:Hide()

    local weeklyAffixTitle = weeklyAffixSlot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weeklyAffixTitle:SetPoint("TOP", weeklyAffixSlot, "TOP", 0, -2)
    weeklyAffixTitle:SetText("|cffFFD100AFFIXES|r")

    local weeklyAffixIcons = {}
    for idx = 1, WEEKLY_AFFIX_COUNT do
        local icon = weeklyAffixSlot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", weeklyAffixSlot, "TOPLEFT", 0, 0)
        icon:SetSize(22, 22)
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
        hitbox:SetSize(22, 22)
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

    local function LayoutWeeklyAffixIcons(slotWidth)
        local width = tonumber(slotWidth) or (weeklyAffixSlot:GetWidth() or (BEST_KEY_ICON_SIZE + 8))
        local titleTopOffset = 16
        local innerPadX = 4
        local colGap = 4
        local rowGap = 4
        local availableW = math.max(30, width - (innerPadX * 2))
        local availableH = math.max(30, KEY_H - titleTopOffset - 6)

        local cellByWidth = math.floor((availableW - colGap) / 2)
        local cellByHeight = math.floor((availableH - (rowGap * 2)) / 3)
        local cell = math.max(20, math.min(30, math.min(cellByWidth, cellByHeight)))

        local pairWidth = (cell * 2) + colGap
        local leftX = math.floor((width - pairWidth) / 2)
        local row1Y = -titleTopOffset
        local row2Y = row1Y - cell - rowGap
        local row3Y = row2Y - cell - rowGap
        local centerX = math.floor((width - cell) / 2)

        local positions = {
            { x = leftX, y = row1Y },
            { x = leftX + cell + colGap, y = row1Y },
            { x = leftX, y = row2Y },
            { x = leftX + cell + colGap, y = row2Y },
            { x = centerX, y = row3Y },
        }

        for idx = 1, WEEKLY_AFFIX_COUNT do
            local cellData = weeklyAffixIcons[idx]
            local pos = positions[idx]
            if cellData and pos then
                cellData.icon:ClearAllPoints()
                cellData.icon:SetPoint("TOPLEFT", weeklyAffixSlot, "TOPLEFT", pos.x, pos.y)
                cellData.icon:SetSize(cell, cell)

                cellData.hitbox:ClearAllPoints()
                cellData.hitbox:SetPoint("TOPLEFT", cellData.icon, "TOPLEFT", 0, 0)
                cellData.hitbox:SetSize(cell, cell)

                local fontPath = select(1, GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF"
                cellData.levelText:SetFont(fontPath, math.max(10, math.floor(cell * 0.34)), "OUTLINE")
            end
        end
    end

    weeklyAffixSlot.LayoutIcons = LayoutWeeklyAffixIcons
    LayoutWeeklyAffixIcons(BEST_KEY_ICON_SIZE + 8)

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
        slot:RegisterForClicks("AnyUp", "AnyDown")
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
            if btn.teleportSpellID then
                GameTooltip:AddLine("Click to teleport", 0.2, 1, 0.2)
                if btn.portalSpellName then
                    GameTooltip:AddLine(btn.portalSpellName, 0.8, 0.8, 1)
                else
                    GameTooltip:AddLine("Known teleport spell", 0.8, 0.8, 1)
                end
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
            fs:SetPoint("BOTTOM", icon, "BOTTOM", o.x, o.y + 2)
            fs:SetText("-")
            fs:SetTextColor(0, 0, 0, 0.95)
            scoreOutline[#scoreOutline + 1] = fs
        end

        local scoreText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        scoreText:SetDrawLayer("OVERLAY", 5)
        scoreText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 2)
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
    bestIconButton:RegisterForClicks("AnyUp", "AnyDown")

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
        if btn.teleportSpellID then
            GameTooltip:AddLine("Click to teleport", 0.2, 1, 0.2)
            if btn.portalSpellName then
                GameTooltip:AddLine(btn.portalSpellName, 0.8, 0.8, 1)
            else
                GameTooltip:AddLine("Known teleport spell", 0.8, 0.8, 1)
            end
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

    -- Bottom-right resize grip: drag horizontally to scale the whole frame.
    local resizeGrip = CreateFrame("Button", nil, f)
    resizeGrip:SetSize(18, 18)
    resizeGrip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    resizeGrip:EnableMouse(true)
    resizeGrip:RegisterForDrag("LeftButton")

    local resizeIcon = resizeGrip:CreateTexture(nil, "OVERLAY")
    resizeIcon:SetAllPoints(resizeGrip)
    resizeIcon:SetTexture(RESIZE_GRIP_TEXTURE)
    resizeIcon:SetVertexColor(0.80, 0.80, 0.85, 0.85)

    resizeGrip:SetScript("OnEnter", function()
        resizeIcon:SetVertexColor(1.00, 0.82, 0.00, 0.95)
        GameTooltip:SetOwner(resizeGrip, "ANCHOR_LEFT")
        GameTooltip:AddLine("Drag to scale UI", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    resizeGrip:SetScript("OnLeave", function()
        resizeIcon:SetVertexColor(0.80, 0.80, 0.85, 0.85)
        GameTooltip:Hide()
    end)

    resizeGrip:SetScript("OnDragStart", function()
        if InCombatLockdown and InCombatLockdown() then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff98Key Party|r: cannot resize the window while in combat.")
            end
            return
        end

        local cursorX = GetCursorPosition()
        local uiScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        f._scaleDragStartCursorX = (tonumber(cursorX) or 0) / (uiScale > 0 and uiScale or 1)
        f._scaleDragStartScale = KL_UI:GetFrameScale()
        f._isDraggingScale = true

        resizeGrip:SetScript("OnUpdate", function()
            if not f._isDraggingScale then
                return
            end
            local currentX = GetCursorPosition()
            currentX = (tonumber(currentX) or 0) / (uiScale > 0 and uiScale or 1)
            local dx = currentX - (f._scaleDragStartCursorX or currentX)
            local newScale = (f._scaleDragStartScale or FRAME_SCALE_DEFAULT) + (dx / FRAME_W)
            KL_UI:SetFrameScale(newScale)
        end)
    end)

    local function StopScaleDrag()
        f._isDraggingScale = false
        resizeGrip:SetScript("OnUpdate", nil)
    end

    resizeGrip:SetScript("OnDragStop", StopScaleDrag)
    resizeGrip:SetScript("OnMouseUp", StopScaleDrag)

    f.resizeGrip = resizeGrip
    f.resizeGripIcon = resizeIcon

    return f
end

local mainFrame = BuildFrame()
KL_UI.frame = mainFrame

local function BuildAltKeystonePanel(anchorFrame)
    local panel = CreateFrame("Frame", "KeyPartyAltKeystonePanel", UIParent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", ALT_PANEL_GAP, 0)
    panel:SetPoint("BOTTOMLEFT", anchorFrame, "BOTTOMRIGHT", ALT_PANEL_GAP, 0)
    panel:SetWidth(ALT_PANEL_W)
    panel:SetFrameStrata("DIALOG")
    ApplyBackdrop(panel, 0.08, 0.08, 0.11, 0.97, 0.38, 0.38, 0.48, 1)
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
    title:SetTextColor(1.0, 0.82, 0.0, 1)
    title:SetText("ALTS WITH KEYS")
    panel.title = title

    local emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    emptyText:SetWidth(ALT_PANEL_W - 24)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText("No alt keystones stored yet.")
    emptyText:Hide()
    panel.emptyText = emptyText

    panel.rows = {}
    for i = 1, ALT_PANEL_MAX_ROWS do
        local y = -36 - ((i - 1) * ALT_PANEL_ROW_H)

        local rowFrame = CreateFrame("Frame", nil, panel)
        rowFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
        rowFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y)
        rowFrame:SetHeight(ALT_PANEL_ROW_H)
        rowFrame:Hide()

        local rowName = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowName:SetPoint("LEFT", rowFrame, "LEFT", 4, 0)
        rowName:SetWidth(ALT_PANEL_W - ALT_PANEL_ICON_SIZE - 34)
        rowName:SetJustifyH("LEFT")
        rowName:SetJustifyV("MIDDLE")
        rowName:SetTextColor(0.92, 0.92, 0.95, 1)
        rowName:Hide()

        local iconFrame = CreateFrame("Frame", nil, rowFrame)
        iconFrame:SetSize(ALT_PANEL_ICON_SIZE, ALT_PANEL_ICON_SIZE)
        iconFrame:SetPoint("RIGHT", rowFrame, "RIGHT", -4, 0)
        iconFrame:Hide()

        local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
        iconTexture:SetPoint("CENTER")
        iconTexture:SetSize(ALT_PANEL_ICON_SIZE, ALT_PANEL_ICON_SIZE)
        iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconTexture:SetTexture(EMPTY_ICON_TEXTURE)
        local iconBorder = CreateIconEdgeBorder(iconFrame, iconTexture)
        iconFrame.icon = iconTexture

        local levelText = iconFrame:CreateFontString(nil, "OVERLAY")
        levelText:SetDrawLayer("OVERLAY", 5)
        levelText:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
        do
            local fontPath = select(1, GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF"
            levelText:SetFont(fontPath, math.max(14, math.floor(ALT_PANEL_ICON_SIZE * 0.46)), "OUTLINE")
        end
        levelText:SetTextColor(1, 1, 1, 1)
        levelText:SetText("")
        iconFrame.levelText = levelText

        local abbrText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        abbrText:SetDrawLayer("OVERLAY", 6)
        abbrText:SetPoint("TOP", iconFrame, "TOP", 0, -4)
        abbrText:SetTextColor(1, 1, 1, 1)
        abbrText:SetText("")

        panel.rows[i] = {
            frame = rowFrame,
            name = rowName,
            iconFrame = iconFrame,
            icon = iconTexture,
            iconBorder = iconBorder,
            levelText = levelText,
            abbrText = abbrText,
        }
    end

    return panel
end

KL_UI.altKeystonePanel = BuildAltKeystonePanel(mainFrame)

function KL_UI:IsAltPanelVisible()
    if type(KeyPartyDB) ~= "table" then
        return false
    end
    return KeyPartyDB.altPanelVisible == true
end

local function SetAltPanelToggleGlyph(button, show)
    if not button then
        return
    end
    local glyph = show and "<" or ">"
    if button.glyph then
        button.glyph:SetText(glyph)
    else
        button:SetText(glyph)
    end
end

function KL_UI:SetAltPanelVisible(visible)
    local show = not not visible
    if type(KeyPartyDB) == "table" then
        KeyPartyDB.altPanelVisible = show
    end
    self.altPanelVisible = show
    if self.altPanelToggleButton then
        SetAltPanelToggleGlyph(self.altPanelToggleButton, show)
    end
end

local function BuildAltPanelToggleButton(anchorFrame)
    local button = CreateFrame("Button", nil, anchorFrame, "BackdropTemplate")
    button:SetSize(ALT_TOGGLE_BUTTON_W, ALT_TOGGLE_BUTTON_H)
    button:SetPoint("RIGHT", anchorFrame, "RIGHT", -4, 0)
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel((anchorFrame and anchorFrame:GetFrameLevel() or 1) + 20)
    ApplyBackdrop(button, 0.07, 0.08, 0.12, 0.98, 0.30, 0.35, 0.48, 1)

    local hoverGlow = button:CreateTexture(nil, "HIGHLIGHT")
    hoverGlow:SetAllPoints()
    hoverGlow:SetColorTexture(0.28, 0.55, 0.95, 0.20)

    local glyph = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    glyph:SetPoint("CENTER", button, "CENTER", 1, 0)
    glyph:SetTextColor(0.85, 0.90, 1.00, 1)
    glyph:SetText("<")
    button.glyph = glyph

    SetAltPanelToggleGlyph(button, KL_UI:IsAltPanelVisible())

    button:SetScript("OnClick", function()
        KL_UI:SetAltPanelVisible(not KL_UI:IsAltPanelVisible())
        KL_UI:RefreshAltKeystonePanel()
    end)

    button:SetScript("OnEnter", function(btn)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        if KL_UI:IsAltPanelVisible() then
            GameTooltip:SetText("Hide alt keystones", 1, 1, 1)
        else
            GameTooltip:SetText("Show alt keystones", 1, 1, 1)
        end
        GameTooltip:Show()

        button:SetBackdropBorderColor(0.40, 0.55, 0.90, 1)
        if button.glyph then
            button.glyph:SetTextColor(1, 1, 1, 1)
        end
    end)

    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end

        button:SetBackdropBorderColor(0.30, 0.35, 0.48, 1)
        if button.glyph then
            button.glyph:SetTextColor(0.85, 0.90, 1.00, 1)
        end
    end)

    button:SetScript("OnMouseDown", function()
        if button.glyph then
            button.glyph:SetPoint("CENTER", button, "CENTER", 2, -1)
        end
    end)

    button:SetScript("OnMouseUp", function()
        if button.glyph then
            button.glyph:SetPoint("CENTER", button, "CENTER", 1, 0)
        end
    end)

    return button
end

KL_UI.altPanelToggleButton = BuildAltPanelToggleButton(mainFrame)
KL_UI:SetAltPanelVisible(KL_UI:IsAltPanelVisible())

function KL_UI:RefreshAltKeystonePanel()
    local panel = self.altKeystonePanel
    if not panel then
        return
    end

    local shouldShow = self:IsAltPanelVisible()
    if self.altPanelToggleButton then
        SetAltPanelToggleGlyph(self.altPanelToggleButton, shouldShow)
    end

    if not (self.frame and self.frame:IsShown()) then
        panel:Hide()
        return
    end

    if not shouldShow then
        panel:Hide()
        return
    end

    local addonTable = _G.KeyParty
    local entries = (addonTable and addonTable.GetAltKeystoneEntries and addonTable.GetAltKeystoneEntries()) or {}
    local GetMapName = (addonTable and addonTable.GetMapName) or function(id)
        return "Map " .. tostring(id)
    end

    panel:Show()
    panel:Raise()

    local visibleRows = 0
    for i = 1, math.min(#entries, ALT_PANEL_MAX_ROWS) do
        local row = panel.rows[i]
        local entry = entries[i]
        local mapName = GetMapName(entry.mapID)
        local mapLevel = tonumber(entry.level) or 0
        row.name:SetText(ColoredPlayerName(tostring(entry.shortName or "Unknown"), { classToken = entry.classToken }))
        row.icon:SetTexture(GetMapIcon(entry.mapID, mapName))
        row.levelText:SetText((mapLevel > 0) and tostring(mapLevel) or "")
        row.abbrText:SetText(AbbreviateDungeonName(mapName))
        row.iconBorder:SetColor(0.45, 0.45, 0.45, 0.95)
        row.frame:Show()
        row.name:Show()
        row.iconFrame:Show()
        visibleRows = i
    end

    for i = visibleRows + 1, ALT_PANEL_MAX_ROWS do
        local row = panel.rows[i]
        row.frame:Hide()
        row.name:Hide()
        row.iconFrame:Hide()
    end

    panel.emptyText:SetShown(visibleRows == 0)
end

local function ClampPortalScale(scale)
    local n = tonumber(scale) or 1.0
    n = math.max(PORTAL_SCALE_MIN, math.min(PORTAL_SCALE_MAX, n))
    return math.floor(n * 10 + 0.5) / 10
end

local function BuildPortalFrame(anchorFrame)
    local frame = CreateFrame("Frame", "KeyPartyPortalFrame", UIParent)
    frame:SetSize(PORTAL_BUTTON_SIZE, PORTAL_BUTTON_SIZE)
    frame:SetPoint("TOP", UIParent, "TOP", FRAME_W / 2 + PORTAL_FRAME_GAP + PORTAL_BUTTON_SIZE / 2, -200)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouseWheel(true)
    frame:SetClampedToScreen(true)
    frame:SetScale(1.0)

    local savedPosition = type(KeyPartyDB) == "table" and KeyPartyDB.portalBarPosition or nil
    if type(savedPosition) == "table"
        and type(savedPosition.point) == "string"
        and type(savedPosition.relativePoint) == "string" then
        local savedPoint = savedPosition.point
        local savedRelativePoint = savedPosition.relativePoint
        local savedX = tonumber(savedPosition.x) or 0
        local savedY = tonumber(savedPosition.y) or 0
        if savedPoint == "CENTER" and savedRelativePoint == "CENTER" then
            savedPoint = "TOP"
            savedRelativePoint = "TOP"
            savedY = savedY + (PORTAL_BUTTON_SIZE / 2)
        end
        frame:ClearAllPoints()
        frame:SetPoint(
            savedPoint,
            UIParent,
            savedRelativePoint,
            savedX,
            savedY
        )
    end

    local function SavePortalPosition(container)
        local point, _, relativePoint, x, y = container:GetPoint(1)
        if type(KeyPartyDB) ~= "table" or not point or not relativePoint then
            return
        end

        KeyPartyDB.portalBarPosition = {
            point = point,
            relativePoint = relativePoint,
            x = tonumber(x) or 0,
            y = tonumber(y) or 0,
        }
    end

    frame:SetScript("OnDragStart", function(container)
        if not InCombatLockdown() then
            container:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(container)
        container:StopMovingOrSizing()
        SavePortalPosition(container)
    end)
    frame:SetScript("OnMouseWheel", function(container, delta)
        local scale = container:GetScale() + (delta > 0 and PORTAL_SCALE_STEP or -PORTAL_SCALE_STEP)
        KL_UI:SetPortalBarScale(scale)
    end)
    frame.buttons = {}
    frame:Show()

    local function ShouldHidePortalBar()
        local db = type(KeyPartyDB) == "table" and KeyPartyDB or nil
        if db and db.portalBarHideAlways == true then
            return true
        end

        if db and db.portalBarHideInRaid == true and IsInRaid() then
            return true
        end

        if db and db.portalBarHideInPvP == true then
            local inInstance, instanceType = IsInInstance()
            if inInstance and (instanceType == "pvp" or instanceType == "arena") then
                return true
            end
        end

        if db and db.portalBarHideInSolo == true then
            local isGrouped = IsInGroup() or IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
            if not isGrouped then
                return true
            end
        end

        return false
    end

    function frame:Refresh()
        if ShouldHidePortalBar() then
            self:Hide()
            return
        end

        local sourceSlots = KL_UI.frame and KL_UI.frame._keySlots or {}
        local availableKeys = {}
        for i = 1, PARTY_KEYSTONE_ICON_COUNT do
            local source = sourceSlots[i]
            if source and source:IsShown() and source.mapName then
                availableKeys[#availableKeys + 1] = source
            end
        end

        local playerName = CanonicalName(GetUnitName("player", true) or UnitName("player"))
        table.sort(availableKeys, function(left, right)
            local leftIsPlayer = CanonicalName(left.ownerName) == playerName
            local rightIsPlayer = CanonicalName(right.ownerName) == playerName
            if leftIsPlayer ~= rightIsPlayer then
                return leftIsPlayer
            end
            return tostring(left.ownerName or "") < tostring(right.ownerName or "")
        end)

        local isHorizontal = type(KeyPartyDB) == "table" and KeyPartyDB.portalBarHorizontal == true
        local growUp = type(KeyPartyDB) == "table" and KeyPartyDB.portalBarGrowUp == true
        local growLeft = type(KeyPartyDB) == "table" and KeyPartyDB.portalBarGrowLeft == true

        -- Keep the container at one-button size so the anchor position of the
        -- first (local player) button never shifts while the bar grows.
        self:SetSize(PORTAL_BUTTON_SIZE, PORTAL_BUTTON_SIZE)

        for i, source in ipairs(availableKeys) do
            local button = self.buttons[i]
            if not button then
                button = CreateFrame("Button", nil, self, "SecureActionButtonTemplate")
                button:SetSize(PORTAL_BUTTON_SIZE, PORTAL_BUTTON_SIZE)
                button:RegisterForClicks("LeftButtonUp")
                button:RegisterForDrag("RightButton")
                button:EnableMouse(true)
                button:EnableMouseWheel(true)
                button:SetScript("OnDragStart", function(btn)
                    if not InCombatLockdown() then
                        btn:GetParent():StartMoving()
                    end
                end)
                button:SetScript("OnDragStop", function(btn)
                    local container = btn:GetParent()
                    container:StopMovingOrSizing()
                    SavePortalPosition(container)
                end)
                button:SetScript("OnMouseWheel", function(btn, delta)
                    local container = btn:GetParent()
                    local scale = container:GetScale() + (delta > 0 and PORTAL_SCALE_STEP or -PORTAL_SCALE_STEP)
                    KL_UI:SetPortalBarScale(scale)
                end)

                local icon = button:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints(button)
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                button.icon = icon
                button.border = CreateIconEdgeBorder(button, icon)

                local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                cooldown:SetAllPoints(icon)
                cooldown:SetFrameLevel(button:GetFrameLevel() + 30)
                cooldown:SetDrawSwipe(true)
                cooldown:SetDrawEdge(true)
                cooldown:Hide()
                button.cooldown = cooldown

                local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                label:SetPoint("TOP", button, "TOP", 0, -2)
                label:SetTextColor(1, 1, 1, 1)
                button.label = label

                local levelText = button:CreateFontString(nil, "OVERLAY")
                levelText:SetPoint("CENTER", button, "CENTER", 0, 0)
                levelText:SetFont(select(1, GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
                levelText:SetTextColor(1, 1, 1, 1)
                button.levelText = levelText

                local ownerText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                ownerText:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
                ownerText:SetWidth(PORTAL_BUTTON_SIZE - 4)
                ownerText:SetJustifyH("CENTER")
                ownerText:SetTextColor(0.92, 0.92, 0.95, 1)
                button.ownerText = ownerText

                button:SetScript("OnEnter", function(btn)
                    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(btn.mapName or "Dungeon portal", 1, 0.82, 0)
                    if btn.ownerName then
                        GameTooltip:AddLine(string.format("%s: +%s", btn.ownerName, tostring(btn.keyLevel or "?")), 0.92, 0.92, 0.95)
                    end
                    GameTooltip:AddLine("Right-drag to move, mouse wheel to scale", 0.65, 0.65, 0.70)
                    if btn.teleportSpellID then
                        GameTooltip:AddLine("Click to teleport", 0.2, 1, 0.2)
                        GameTooltip:AddLine(btn.portalSpellName or "Known teleport spell", 0.8, 0.8, 1)
                    else
                        GameTooltip:AddLine("No teleport available", 1, 0.2, 0.2)
                    end
                    GameTooltip:Show()
                end)
                button:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)

                self.buttons[i] = button
            end

            button:ClearAllPoints()
            local offset = (i - 1) * (PORTAL_BUTTON_SIZE + PORTAL_BUTTON_GAP)
            if isHorizontal then
                if growLeft then
                    button:SetPoint("LEFT", self, "LEFT", -offset, 0)
                else
                    button:SetPoint("LEFT", self, "LEFT", offset, 0)
                end
            else
                if growUp then
                    button:SetPoint("TOP", self, "TOP", 0, offset)
                else
                    button:SetPoint("TOP", self, "TOP", 0, -offset)
                end
            end
            button.mapID = source.mapID
            button.mapName = source.mapName
            button.ownerName = source.ownerName
            button.keyLevel = source.keyLevel
            button.portalSpellName = source.portalSpellName
            button.teleportSpellID = source.teleportSpellID
            button.icon:SetTexture(source.mapID and GetMapIcon(source.mapID, source.mapName) or EMPTY_ICON_TEXTURE)
            button.label:SetText(AbbreviateDungeonName(source.mapName))
            button.levelText:SetText(source.keyLevel and ("+" .. tostring(source.keyLevel)) or "")
            button.ownerText:SetText(EllipsizeTextToWidth(button.ownerText, source.ownerName or "", PORTAL_BUTTON_SIZE - 4))
            local spellID = source.teleportSpellID
            button.border:SetColor(spellID and 0.20 or 1.00, spellID and 1.00 or 0.20, 0.20, 0.95)

            if not InCombatLockdown() then
                if spellID then
                    button:SetAttribute("type", "spell")
                    button:SetAttribute("spell", button.portalSpellName or spellID)
                else
                    button:SetAttribute("type", nil)
                    button:SetAttribute("spell", nil)
                end
            end
            button:Show()
        end

        for i = #availableKeys + 1, #self.buttons do
            self.buttons[i]:Hide()
        end

        self:Show()
        self:Raise()
    end

    return frame
end

KL_UI.portalFrame = BuildPortalFrame()
KL_UI.portalFrame:Refresh()

function KL_UI:GetFrameScale()
    if type(KeyPartyDB) == "table" and type(KeyPartyDB.frameScale) == "number" then
        return KeyPartyDB.frameScale
    end
    return FRAME_SCALE_DEFAULT
end

function KL_UI:GetPortalBarScale()
    if type(KeyPartyDB) == "table" and type(KeyPartyDB.portalBarScale) == "number" then
        return ClampPortalScale(KeyPartyDB.portalBarScale)
    end
    return 1.0
end

function KL_UI:SetPortalBarScale(scale)
    local normalized = ClampPortalScale(scale)
    if type(KeyPartyDB) == "table" then
        KeyPartyDB.portalBarScale = normalized
    end
    if self.portalFrame then
        self.portalFrame:SetScale(normalized)
    end
end

function KL_UI:SetFrameScale(scale)
    scale = math.max(FRAME_SCALE_MIN, math.min(FRAME_SCALE_MAX, tonumber(scale) or FRAME_SCALE_DEFAULT))
    scale = math.floor(scale * 10 + 0.5) / 10  -- round to 1 decimal
    if type(KeyPartyDB) == "table" then
        KeyPartyDB.frameScale = scale
    end
    if self.frame then
        self.frame:SetScale(scale)
    end
    if self.altKeystonePanel then
        self.altKeystonePanel:SetScale(scale)
    end
end

-- Apply saved scale on startup (after SavedVariables are loaded).
C_Timer.After(0, function()
    if KL_UI.frame then
        KL_UI.frame:SetScale(KL_UI:GetFrameScale())
    end
    if KL_UI.altKeystonePanel then
        KL_UI.altKeystonePanel:SetScale(KL_UI:GetFrameScale())
    end
    if KL_UI.portalFrame then
        KL_UI.portalFrame:SetScale(KL_UI:GetPortalBarScale())
    end
end)

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

    local teleportSpellIDs = {}
    local seenSpellIDs = {}

    if f._keySlots then
        for _, slot in ipairs(f._keySlots) do
            local spellID = slot and slot.teleportSpellID
            if spellID and not seenSpellIDs[spellID] then
                seenSpellIDs[spellID] = true
                teleportSpellIDs[#teleportSpellIDs + 1] = spellID
            end
        end
    end

    if f._scoreSlots then
        for _, slot in ipairs(f._scoreSlots) do
            local spellID = slot and slot.teleportSpellID
            if spellID and not seenSpellIDs[spellID] then
                seenSpellIDs[spellID] = true
                teleportSpellIDs[#teleportSpellIDs + 1] = spellID
            end
        end
    end

    if f.bestKeyTeleportSpellID and not seenSpellIDs[f.bestKeyTeleportSpellID] then
        seenSpellIDs[f.bestKeyTeleportSpellID] = true
        teleportSpellIDs[#teleportSpellIDs + 1] = f.bestKeyTeleportSpellID
    end

    local portalFrame = self.portalFrame
    if portalFrame and portalFrame.buttons then
        for _, button in ipairs(portalFrame.buttons) do
            local spellID = button and button.teleportSpellID
            if spellID and not seenSpellIDs[spellID] then
                seenSpellIDs[spellID] = true
                teleportSpellIDs[#teleportSpellIDs + 1] = spellID
            end
        end
    end

    local sharedCooldown = nil
    if not debugEndTime then
        sharedCooldown = GetSharedTeleportCooldown(teleportSpellIDs)
    end

    if f._keySlots then
        for _, slot in ipairs(f._keySlots) do
            if sharedCooldown and slot.teleportSpellID then
                slot.cooldown:Show()
                slot.cooldown:SetCooldown(sharedCooldown.startTime, sharedCooldown.duration, sharedCooldown.modRate)
            else
                ApplySpellCooldown(slot.cooldown, slot.teleportSpellID, debugEndTime, debugDuration)
            end
        end
    end

    if f._scoreSlots then
        for _, slot in ipairs(f._scoreSlots) do
            if sharedCooldown and slot.teleportSpellID then
                slot.cooldown:Show()
                slot.cooldown:SetCooldown(sharedCooldown.startTime, sharedCooldown.duration, sharedCooldown.modRate)
            else
                ApplySpellCooldown(slot.cooldown, slot.teleportSpellID, debugEndTime, debugDuration)
            end
        end
    end

    if sharedCooldown and f.bestKeyTeleportSpellID then
        f.bestKeyCooldown:Show()
        f.bestKeyCooldown:SetCooldown(sharedCooldown.startTime, sharedCooldown.duration, sharedCooldown.modRate)
    else
        ApplySpellCooldown(f.bestKeyCooldown, f.bestKeyTeleportSpellID, debugEndTime, debugDuration)
    end

    if portalFrame and portalFrame.buttons then
        for _, button in ipairs(portalFrame.buttons) do
            if sharedCooldown and button.teleportSpellID then
                button.cooldown:Show()
                button.cooldown:SetCooldown(sharedCooldown.startTime, sharedCooldown.duration, sharedCooldown.modRate)
            else
                ApplySpellCooldown(button.cooldown, button.teleportSpellID, debugEndTime, debugDuration)
            end
        end
    end
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
        if (self.frame and self.frame:IsShown()) or (self.portalFrame and self.portalFrame:IsShown()) then
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
    KL_UI.portalFrame:Refresh()
    KL_UI:RefreshAltKeystonePanel()
    KL_UI:StartCooldownTicker()
    KL_UI:RefreshCooldownIndicators()
    if KL_UI.ShouldRefreshOnShow and KL_UI.ShouldRefreshOnShow() and KL_UI.OnRefreshOnShow then
        KL_UI.OnRefreshOnShow()
    end
end)

mainFrame:SetScript("OnHide", function()
    if KL_UI and KL_UI.altKeystonePanel then
        KL_UI.altKeystonePanel:Hide()
    end
end)

KL_UI:StartCooldownTicker()

local portalVisibilityEvents = CreateFrame("Frame")
portalVisibilityEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
portalVisibilityEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
portalVisibilityEvents:RegisterEvent("GROUP_ROSTER_UPDATE")
portalVisibilityEvents:SetScript("OnEvent", function()
    if KL_UI and KL_UI.portalFrame and KL_UI.portalFrame.Refresh then
        KL_UI.portalFrame:Refresh()
    end
end)

local cooldownEvents = CreateFrame("Frame")
cooldownEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
cooldownEvents:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
cooldownEvents:RegisterEvent("SPELLS_CHANGED")
cooldownEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
cooldownEvents:SetScript("OnEvent", function()
    if KL_UI and ((KL_UI.frame and KL_UI.frame:IsShown()) or (KL_UI.portalFrame and KL_UI.portalFrame:IsShown())) then
        KL_UI:RefreshCooldownIndicators()
    end
end)

-- ── Public: populate the frame with current data ──────────────────────────────

function KL_UI:Populate(members, best, keepFrameHidden)
    local f    = self.frame
    local rows = f._ratingRows
    local keySlots = f._keySlots

    members = members or {}
    if IsInRaid() then
        local playerName = CanonicalName(GetUnitName("player", true) or UnitName("player"))
        local playerMember = members[playerName]
        if not playerMember then
            for name, data in pairs(members) do
                if CanonicalName(name) == playerName then
                    playerMember = data
                    break
                end
            end
        end

        members = {}
        if playerMember then
            members[playerName] = playerMember
        end

        if best and (not best.owner or CanonicalName(best.owner) ~= playerName) then
            best = nil
        end
    end

    -- Hide all pre-created rows
    for i = 1, MAX_ROWS do
        rows[i].name:Hide()
        rows[i].value:Hide()
        rows[i].bestAbbr:Hide()
        rows[i].bestLevel:Hide()
    end
    for i = 1, PARTY_KEYSTONE_ICON_COUNT do
        local slot = keySlots[i]
        slot.mapName = nil
        slot.mapID = nil
        slot.ownerName = nil
        slot.keyLevel = nil
        slot.portalSpellName = nil
        slot.teleportSpellID = nil
        if not InCombatLockdown() then
            slot:SetAttribute("type", nil)
            slot:SetAttribute("spell", nil)
            slot:EnableMouse(true)
        end
        if slot.border then
            slot.border:SetColor(0.45, 0.45, 0.45, 0.95)
        end
        if slot.cooldown then
            ClearCooldownFrame(slot.cooldown)
        end
        slot:Hide()
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

        -- Best completed dungeon column
        local bestMapID = GetBestDungeonMapID(m)
        if bestMapID then
            local dungeonName = GetMapName(bestMapID)
            local level  = ((m.dungeonLevels or {})[bestMapID] or 0)
            local isTimed = (m.dungeonTimed or {})[bestMapID]
            rows[i].bestAbbr:SetText(AbbreviateDungeonName(dungeonName or ""))
            rows[i].bestAbbr:Show()
            if level > 0 then
                rows[i].bestLevel:SetText("+" .. level)
                if isTimed then
                    rows[i].bestLevel:SetTextColor(1, 1, 1, 1)
                else
                    rows[i].bestLevel:SetTextColor(0.75, 0.75, 0.75, 0.35)
                end
                rows[i].bestLevel:Show()
            end
        end
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
            local mapName = GetMapName(info.mapID)
            local spellID = addonTable and addonTable.GetTeleportSpellIDForMap and addonTable.GetTeleportSpellIDForMap(info.mapID)
            if not spellID and addonTable and addonTable.GetTeleportSpellIDForMapName then
                spellID = addonTable.GetTeleportSpellIDForMapName(mapName)
            end
            local spellName = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or nil

            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", f.keyArea, "TOPLEFT", (i - 1) * slotW, 0)
            slot:SetWidth(slotW)
            slot.icon:SetTexture(GetMapIcon(info.mapID, mapName))
            slot.levelText:SetText("+" .. tostring(info.level))
            slot.mapName = mapName
            slot.mapID = info.mapID
            slot.ownerName = CanonicalName(info.owner)
            slot.keyLevel = info.level
            slot.portalSpellName = spellName
            slot.teleportSpellID = spellID
            if slot.abbrText then
                slot.abbrText:SetText(AbbreviateDungeonName(mapName))
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

            if not InCombatLockdown() then
                if spellID then
                    local castSpell = spellName or spellID
                    slot:SetAttribute("type", "spell")
                    slot:SetAttribute("spell", castSpell)
                    slot:EnableMouse(true)
                    slot.border:SetColor(0.20, 1.00, 0.20, 0.95)
                else
                    slot:SetAttribute("type", nil)
                    slot:SetAttribute("spell", nil)
                    slot:EnableMouse(true)
                    slot.border:SetColor(1.00, 0.20, 0.20, 0.95)
                end
            else
                if spellID then
                    slot.border:SetColor(0.20, 1.00, 0.20, 0.95)
                else
                    slot.border:SetColor(1.00, 0.20, 0.20, 0.95)
                end
            end

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
        if f.weeklyAffixSlot.LayoutIcons then
            f.weeklyAffixSlot:LayoutIcons(slotW)
        end
        f.weeklyAffixSlot:Show()

        for idx = 1, WEEKLY_AFFIX_COUNT do
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

    -- Your scores row (8 dungeons, sorted low → high score; re-sorted on every Populate call)
    local playerMember = FindPlayerMember()
    local playerScores = (playerMember and playerMember.dungeonScores) or {}
    local playerLevels = (playerMember and playerMember.dungeonLevels) or {}
    local function GetPlayerMapValue(values, mapID)
        return values[mapID] or values[tostring(mapID)] or 0
    end
    local dungeons = GetDisplayedSeasonDungeons()
    table.sort(dungeons, function(a, b)
        local sa = tonumber(GetPlayerMapValue(playerScores, a.mapID)) or 0
        local sb = tonumber(GetPlayerMapValue(playerScores, b.mapID)) or 0
        if sa ~= sb then return sa < sb end
        return strlower(a.name or "") < strlower(b.name or "")
    end)

    for i = 1, YOUR_SCORES_ICON_COUNT do
        local slot = f._scoreSlots[i]
        local dungeon = dungeons[i]

        if dungeon then
            local score = tonumber(GetPlayerMapValue(playerScores, dungeon.mapID)) or 0
            local spellID = addonTable and addonTable.GetTeleportSpellIDForMap and addonTable.GetTeleportSpellIDForMap(dungeon.mapID)
            if not spellID and addonTable and addonTable.GetTeleportSpellIDForMapName then
                spellID = addonTable.GetTeleportSpellIDForMapName(dungeon.name)
            end
            local spellName = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or nil

            slot.mapName = dungeon.name
            slot.portalSpellName = spellName
            slot.teleportSpellID = spellID

            if not InCombatLockdown() then
                if spellID then
                    local castSpell = spellName or spellID
                    slot:SetAttribute("type", "spell")
                    slot:SetAttribute("spell", castSpell)
                    slot:EnableMouse(true)
                    slot.border:SetColor(0.20, 1.00, 0.20, 0.95)
                else
                    slot:SetAttribute("type", nil)
                    slot:SetAttribute("spell", nil)
                    slot:EnableMouse(true)
                    slot.border:SetColor(1.00, 0.20, 0.20, 0.95)
                end
            else
                if spellID then
                    slot.border:SetColor(0.20, 1.00, 0.20, 0.95)
                else
                    slot.border:SetColor(1.00, 0.20, 0.20, 0.95)
                end
            end

            local level = tonumber(GetPlayerMapValue(playerLevels, dungeon.mapID)) or 0
            slot.icon:SetTexture(GetMapIcon(dungeon.mapID, dungeon.name))
            ApplyIconScoreText(slot, score)
            slot.abbrText:SetText(AbbreviateDungeonName(dungeon.name))
            if slot.keyLevelText then
                slot.keyLevelText:SetText(level > 0 and ("+" .. level) or "")
                if level > 0 and slot.lastScoreColor then
                    local c = slot.lastScoreColor
                    slot.keyLevelText:SetTextColor(c.r, c.g, c.b, 1)
                else
                    slot.keyLevelText:SetTextColor(0.85, 0.85, 0.90, 1)
                end
            end
        else
            slot.mapName = nil
            slot.mapID = nil
            slot.portalSpellName = nil
            slot.teleportSpellID = nil
            ClearCooldownFrame(slot.cooldown)
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
        if not spellID and addonTable and addonTable.GetTeleportSpellIDForMapName then
            spellID = addonTable.GetTeleportSpellIDForMapName(GetMapName(best.mapID))
        end
        local spellName = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or nil

        f.bestKeyIconButton.mapName = GetMapName(best.mapID)
        f.bestKeyIconButton.portalSpellName = spellName
        f.bestKeyIconButton.teleportSpellID = spellID
        f.bestKeyTeleportSpellID = spellID

        if not InCombatLockdown() then
            if spellID then
                local castSpell = spellName or spellID
                f.bestKeyIconButton:SetAttribute("type", "spell")
                f.bestKeyIconButton:SetAttribute("spell", castSpell)
                f.bestKeyIconButton:EnableMouse(true)
                f.bestKeyIconBorder:SetColor(0.20, 1.00, 0.20, 0.95)
            else
                f.bestKeyIconButton:SetAttribute("type", nil)
                f.bestKeyIconButton:SetAttribute("spell", nil)
                f.bestKeyIconButton:EnableMouse(true)
                f.bestKeyIconBorder:SetColor(1.00, 0.20, 0.20, 0.95)
            end
        else
            if spellID then
                f.bestKeyIconBorder:SetColor(0.20, 1.00, 0.20, 0.95)
            else
                f.bestKeyIconBorder:SetColor(1.00, 0.20, 0.20, 0.95)
            end
        end

        f.bestKeyIcon:SetTexture(GetMapIcon(best.mapID, GetMapName(best.mapID)))
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
        f.bestKeyIconButton.teleportSpellID = nil
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

    do
        local addonName = "KeyParty"
        local version = (C_AddOns and C_AddOns.GetAddOnMetadata)
            and C_AddOns.GetAddOnMetadata(addonName, "Version")
            or "?"
        f.statusText:SetText(string.format("v%s  |  Last refresh: %s", tostring(version or "?"), date("%H:%M:%S")))
    end

    if self.portalFrame then
        self.portalFrame:Refresh()
    end
    if self.RefreshAltKeystonePanel then
        self:RefreshAltKeystonePanel()
    end
    self:RefreshCooldownIndicators()

    if not keepFrameHidden then
        f:Show()
        f:Raise()
    end
end

function KL_UI:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
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
