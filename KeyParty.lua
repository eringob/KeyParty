local ADDON_NAME = ...
local LEGACY_SAVED_VARIABLE_NAME = "Key" .. "LotteryDB"
local LEGACY_ADDON_PREFIX = "KEY" .. "LOTTERY1"

if type(KeyPartyDB) ~= "table" then
    local legacySavedVariables = _G[LEGACY_SAVED_VARIABLE_NAME]
    if type(legacySavedVariables) == "table" then
        KeyPartyDB = legacySavedVariables
    else
        KeyPartyDB = {}
    end
end
_G[LEGACY_SAVED_VARIABLE_NAME] = nil

local function NormalizePortalSpellMap()
    if type(KeyPartyDB) ~= "table" then
        KeyPartyDB = {}
    end

    local target = KeyPartyDB.portalSpellByMap
    if type(target) ~= "table" then
        target = {}
    end

    local legacyKeys = {
        "PortalSpellbyMap",
        "PortalSpellByMap",
        "portalspellbymap",
    }

    for _, key in ipairs(legacyKeys) do
        local legacy = KeyPartyDB[key]
        if type(legacy) == "table" then
            for mapID, spellID in pairs(legacy) do
                local m = tonumber(mapID)
                local s = tonumber(spellID)
                if m and s and m > 0 and s > 0 and not target[m] then
                    target[m] = s
                end
            end
            KeyPartyDB[key] = nil
        end
    end

    KeyPartyDB.portalSpellByMap = target
end

NormalizePortalSpellMap()

local KeyParty = CreateFrame("Frame")
_G.KeyParty = KeyParty
KeyParty.prefix = "KEYPARTY1"
KeyParty.legacyPrefix = LEGACY_ADDON_PREFIX
KeyParty.members = {}
KeyParty.lastReportTime = 0

local EnsureMember
local DetectAddonChannel
local IsGroupCommunicationAllowed
local CanonicalName
local Print
local SafeName
local GroupUnits
local inspectQueue = {}
local inspectQueuedByGUID = {}
local inspectMetaByGUID = {}
local inspectInFlightGUID = nil
local postDungeonRefreshSerial = 0
local addonPresenceByName = {}
local addonPresenceProbeToken = 0
local addonPresenceProbePendingUntil = 0
local lastVersionProbeTime = 0
local highestNewerAddonVersionSeen = nil
local initialFrameRefreshPending = true

local function GetAddonVersion()
    local version = nil
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    end
    version = tostring(version or "0.0.0")
    if version == "" then
        return "0.0.0"
    end
    return version
end

local function ParseVersionParts(version)
    local parts = {}
    for token in tostring(version or "0.0.0"):gmatch("(%d+)") do
        parts[#parts + 1] = tonumber(token) or 0
    end
    return parts
end

local function CompareVersions(left, right)
    local leftParts = ParseVersionParts(left)
    local rightParts = ParseVersionParts(right)
    local count = math.max(#leftParts, #rightParts, 3)

    for i = 1, count do
        local l = leftParts[i] or 0
        local r = rightParts[i] or 0
        if l ~= r then
            return l < r and -1 or 1
        end
    end

    return 0
end

local function SendAddonVersion(channel, target)
    local payload = "VERSION_ACK|" .. GetAddonVersion()
    C_ChatInfo.SendAddonMessage(KeyParty.prefix, payload, channel, target)
end

local function MaybeNotifyOutdatedAddonVersion(remoteVersion, senderName)
    local localVersion = GetAddonVersion()
    if CompareVersions(remoteVersion, localVersion) <= 0 then
        return
    end

    if highestNewerAddonVersionSeen and CompareVersions(remoteVersion, highestNewerAddonVersionSeen) <= 0 then
        return
    end

    highestNewerAddonVersionSeen = remoteVersion
    Print(string.format(
        "a newer addon version was detected in your group (%s from %s). You are using %s.",
        tostring(remoteVersion),
        tostring(senderName or "Unknown"),
        localVersion
    ))
end

local function IsAutoOpenAtDungeonEndEnabled()
    if type(KeyPartyDB) ~= "table" then
        KeyPartyDB = {}
    end
    return KeyPartyDB.autoOpenAtDungeonEnd == true
end

local function SetAutoOpenAtDungeonEndEnabled(enabled)
    if type(KeyPartyDB) ~= "table" then
        KeyPartyDB = {}
    end
    KeyPartyDB.autoOpenAtDungeonEnd = enabled and true or false
end

local function IsPartyChatAnnouncementAtDungeonEndEnabled()
    if type(KeyPartyDB) ~= "table" then
        KeyPartyDB = {}
    end
    return KeyPartyDB.partyChatAnnouncementAtDungeonEnd == true
end

local function SetPartyChatAnnouncementAtDungeonEndEnabled(enabled)
    if type(KeyPartyDB) ~= "table" then
        KeyPartyDB = {}
    end
    KeyPartyDB.partyChatAnnouncementAtDungeonEnd = enabled and true or false
end

local function MarkAddonPresence(name)
    local canonical = CanonicalName(name)
    if canonical ~= "Unknown" then
        addonPresenceByName[canonical] = true
    end
end

local function AreAllGroupMembersUsingAddon()
    local units = GroupUnits()
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name = SafeName(unit)
            if name ~= "Unknown" and not addonPresenceByName[name] then
                return false
            end
        end
    end
    return true
end

local function TriggerAddonPresenceProbe()
    if not IsGroupCommunicationAllowed() then
        return
    end

    local channel = DetectAddonChannel()
    if channel == "WHISPER" then
        return
    end

    addonPresenceProbeToken = addonPresenceProbeToken + 1
    local token = addonPresenceProbeToken
    addonPresenceProbePendingUntil = GetTime() + 3.0

    C_Timer.After(0.35, function()
        if token ~= addonPresenceProbeToken then
            return
        end

        local selfName = SafeName("player")
        local refreshed = {}
        local units = GroupUnits()
        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                local memberName = SafeName(unit)
                if memberName ~= "Unknown" then
                    refreshed[memberName] = addonPresenceByName[memberName] == true
                end
            end
        end
        refreshed[selfName] = true
        addonPresenceByName = refreshed

        C_ChatInfo.SendAddonMessage(KeyParty.prefix, "PING_REQ", channel)

        if GetTime() >= lastVersionProbeTime + 10.0 then
            lastVersionProbeTime = GetTime()
            C_ChatInfo.SendAddonMessage(KeyParty.prefix, "VERSION_REQ", channel)
        end
    end)
end

local function RefreshUIIfVisible()
    if KL_UI and KL_UI.frame and KL_UI.frame:IsShown() then
        local best = nil
        if KeyParty.GetBestProgressionKey then
            best = KeyParty.GetBestProgressionKey()
        end
        KL_UI:Populate(KeyParty.members, best)
    end
end

Print = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff98Key Party|r: " .. tostring(msg))
end

local function DetectAnnouncementChatChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function PrintBestProgressionKeyAnnouncement(best, force, sendToGroupChat)
    if not best or not best.mapID or not best.level then
        if force then
            Print("no progression recommendation is currently available.")
        end
        return
    end

    if not force and AreAllGroupMembersUsingAddon() then
        return
    end

    local mapNameResolver = (KeyParty and KeyParty.GetMapName) or function(mapID)
        return "Map " .. tostring(mapID)
    end

    local message = string.format(
        "the next best progression key of this party is %s +%d",
        mapNameResolver(best.mapID),
        best.level
    )

    if sendToGroupChat then
        local channel = DetectAnnouncementChatChannel()
        if channel then
            message = "Key Party: " .. message
            ---@diagnostic disable-next-line: deprecated
            SendChatMessage(message, channel)
            return
        end
    end

    Print(message)
end

CanonicalName = function(name)
    local n = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if n == "" then
        return "Unknown"
    end
    return Ambiguate(n, "short")
end

SafeName = function(unit)
    local name, realm = UnitName(unit)
    if not name then
        return "Unknown"
    end
    local full = (realm and realm ~= "") and (name .. "-" .. realm) or name
    return CanonicalName(full)
end

local function FullName(unit)
    local name, realm = UnitName(unit)
    if not name then
        return nil
    end

    if not realm or realm == "" then
        realm = GetRealmName()
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

local function GetRealmAwareDisplayName(unit)
    local name, realm = UnitName(unit)
    if not name then
        return "Unknown", nil, true
    end

    local playerRealm = GetRealmName()
    if not realm or realm == "" then
        realm = playerRealm
    end

    if realm and realm ~= "" and playerRealm and playerRealm ~= "" and realm ~= playerRealm then
        return name .. "-" .. realm, realm, false
    end

    return name, realm, true
end

GroupUnits = function()
    local units = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        for i = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. i
        end
    else
        units[#units + 1] = "player"
    end

    return units
end

local function GetMapName(mapID)
    if not mapID then
        return "Unknown Dungeon"
    end

    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if name and name ~= "" then
        return name
    end

    return "Map " .. tostring(mapID)
end
-- Expose for KeyPartyUI.lua
KeyParty.GetMapName = GetMapName

local function IsSpellKnownByID(spellID)
    if not spellID then
        return false
    end
    ---@diagnostic disable-next-line: deprecated
    if IsSpellKnownOrOverridesKnown then
        ---@diagnostic disable-next-line: deprecated
        return IsSpellKnownOrOverridesKnown(spellID, false)
    end
    ---@diagnostic disable-next-line: deprecated
    return IsPlayerSpell(spellID)
end

local function GetTeleportSpellIDForMap(mapID)
    if not mapID then
        return nil
    end
    NormalizePortalSpellMap()
    local spellID = KeyPartyDB.portalSpellByMap[mapID]
    if not spellID then
        return nil
    end
    if IsSpellKnownByID(spellID) then
        return spellID
    end
    return nil
end

KeyParty.GetTeleportSpellIDForMap = GetTeleportSpellIDForMap

local function BuildMapNameIndex()
    local index = {}
    local mapTable = C_ChallengeMode.GetMapTable() or {}
    for _, mapID in ipairs(mapTable) do
        local mapName = GetMapName(mapID)
        if mapName and mapName ~= "" then
            local lower = strlower(mapName)
            index[lower] = mapID
            index[(lower:gsub("%s+", ""))] = mapID
        end
    end
    return index
end

local function ResolveMapID(input)
    if not input then
        return nil
    end

    local asNumber = tonumber(input)
    if asNumber and asNumber > 0 then
        return math.floor(asNumber)
    end

    local lower = strlower(tostring(input))
    lower = lower:gsub("^%s+", ""):gsub("%s+$", "")
    if lower == "" then
        return nil
    end

    local compact = lower:gsub("%s+", "")
    local index = BuildMapNameIndex()
    if index[lower] then
        return index[lower]
    end
    if index[compact] then
        return index[compact]
    end

    return nil
end

local DEFAULT_PORTAL_SPELLS_BY_DUNGEON = {
    ["Magister's Terrace"] = 1255433,
    ["Seat of the Triumvirate"] = 252631,
    ["Skyreach"] = 169765,
    ["Maisara Caverns"] = 1255247,
    ["Windrummer Spire"] = 1254840,
    ["Pit of Saron"] = 1255366,
    ["Algeth'ar Academy"] = 396126,
    ["Nexus Point Xenas"] = 1255391,
}

local function SeedDefaultPortalMappings()
    NormalizePortalSpellMap()
    for dungeonName, spellID in pairs(DEFAULT_PORTAL_SPELLS_BY_DUNGEON) do
        local mapID = ResolveMapID(dungeonName)
        if mapID and not KeyPartyDB.portalSpellByMap[mapID] then
            KeyPartyDB.portalSpellByMap[mapID] = spellID
        end
    end
end

local function SetManualMemberKey(ownerInput, mapInput, levelInput)
    local owner = tostring(ownerInput or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if owner == "" then
        return false, "Player name is required."
    end

    local mapID = ResolveMapID(mapInput)
    if not mapID or mapID <= 0 then
        return false, "Invalid map. Use a map ID or exact dungeon name."
    end

    local level = tonumber(levelInput)
    if not level or level <= 0 then
        return false, "Invalid key level."
    end
    level = math.floor(level)

    local ownerName = CanonicalName(owner)
    local member = EnsureMember(ownerName)
    member.key = {
        mapID = mapID,
        level = level,
    }

    return true, ownerName, mapID, level
end

local function NormalizeChatText(text)
    if not text then
        return ""
    end
    -- Strip color and hyperlink wrappers while keeping visible text.
    local out = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    out = out:gsub("|H.-|h(.-)|h", "%1")
    return out
end

local function FindMapIDInText(text)
    local index = BuildMapNameIndex()
    local haystack = strlower(text or "")
    local compact = haystack:gsub("%s+", "")
    local bestMapID = nil
    local bestLen = 0

    for name, mapID in pairs(index) do
        if #name > bestLen then
            if haystack:find(name, 1, true) or compact:find(name, 1, true) then
                bestMapID = mapID
                bestLen = #name
            end
        end
    end

    return bestMapID
end

local function GuessKeyLevelFromText(text)
    if not text then
        return nil
    end

    -- Common outputs: "+10", "(10)", "level 10"
    local level = tonumber(text:match("%+(%d%d?)"))
        or tonumber(text:match("%((%d%d?)%)"))
        or tonumber(text:match("[Ll]evel%s*(%d%d?)"))

    if level and level > 0 then
        return level
    end
    return nil
end

local function GuessRatingFromText(text)
    if not text then
        return nil
    end

    local function ParseToken(token)
        if not token then
            return nil
        end
        local digits = token:gsub("[^%d]", "")
        local n = tonumber(digits)
        if n and n >= 100 and n <= 9999 then
            return n
        end
        return nil
    end

    local n = ParseToken(text:match("[Rr][Ii][Oo]%s*[:=-]?%s*([%d%.,]+)"))
    if n then
        return n
    end

    n = ParseToken(text:match("[Ss]core%s*[:=-]?%s*([%d%.,]+)"))
    if n then
        return n
    end

    -- Fallback: rating-like number only when message looks M+ related.
    local lower = strlower(text)
    if lower:find("rio", 1, true) or lower:find("mythic", 1, true) or lower:find("keys", 1, true) then
        for token in text:gmatch("([%d%.,]+)") do
            n = ParseToken(token)
            if n and n >= 500 then
                return n
            end
        end
    end

    return nil
end

local function ParseKeystoneLink(text)
    if not text then
        return nil, nil
    end

    local payload = text:match("|Hkeystone:([^|]+)|h")
    if not payload then
        return nil, nil
    end

    local tokens = {}
    for part in payload:gmatch("[^:]+") do
        tokens[#tokens + 1] = tonumber(part)
    end

    local knownMap = {}
    for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
        knownMap[mapID] = true
    end

    local mapID = nil
    local mapIndex = nil
    for i, n in ipairs(tokens) do
        if n and knownMap[n] then
            mapID = n
            mapIndex = i
            break
        end
    end

    if not mapID then
        return nil, nil
    end

    local function IsLikelyKeyLevel(n)
        return n and n >= 2 and n <= 40
    end

    local level = nil
    if mapIndex and IsLikelyKeyLevel(tokens[mapIndex - 1]) then
        level = tokens[mapIndex - 1]
    elseif mapIndex and IsLikelyKeyLevel(tokens[mapIndex + 1]) then
        level = tokens[mapIndex + 1]
    else
        for _, n in ipairs(tokens) do
            if IsLikelyKeyLevel(n) then
                level = n
                break
            end
        end
    end

    if mapID and level then
        return mapID, level
    end

    return nil, nil
end

local function IsCurrentGroupMemberName(name)
    local want = CanonicalName(name)
    if want == "Unknown" then
        return false
    end

    local units = GroupUnits()
    for _, unit in ipairs(units) do
        if UnitExists(unit) and SafeName(unit) == want then
            return true
        end
    end

    return false
end

local function TryParseExternalKeyMessage(message, sender)
    local clean = NormalizeChatText(message)
    if clean == "" then
        return false
    end

    local owner = CanonicalName(sender or "Unknown")
    if not IsCurrentGroupMemberName(owner) then
        return false
    end

    local prefixName = clean:match("^([^:]+):")
    if prefixName and #prefixName <= 32 and not prefixName:find("%[") then
        local prefixOwner = CanonicalName(prefixName)
        if IsCurrentGroupMemberName(prefixOwner) then
            owner = prefixOwner
        end
    end

    local member = EnsureMember(owner)

    local rating = GuessRatingFromText(clean)
    if rating and rating > 0 then
        member.totalRating = rating
    end

    local mapID, level = ParseKeystoneLink(message)
    if not mapID or not level then
        mapID = FindMapIDInText(clean)
        level = GuessKeyLevelFromText(clean)
    end

    if mapID and level and level > 0 then
        member.key = {
            mapID = mapID,
            level = level,
        }
        return true
    end

    return rating ~= nil
end

local function RequestExternalKeys(channel)
    if channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT" then
        if not IsGroupCommunicationAllowed() then
            return
        end

        -- Skip visible !keys if everyone in group is known to run this addon.
        if AreAllGroupMembersUsingAddon() then
            return
        end

        -- During a recent probe window, wait for addon pings to settle first.
        if GetTime() < addonPresenceProbePendingUntil then
            return
        end

        -- Many key addons respond to !keys in group chat.
        ---@diagnostic disable-next-line: deprecated
        SendChatMessage("!keys", channel)
    end
end

local function GetAllKnownMapIDs()
    local known = {}

    local mapTable = C_ChallengeMode.GetMapTable()
    if mapTable then
        for _, mapID in ipairs(mapTable) do
            known[mapID] = true
        end
    end

    for _, data in pairs(KeyParty.members) do
        if data.dungeonScores then
            for mapID in pairs(data.dungeonScores) do
                known[mapID] = true
            end
        end
        if data.key and data.key.mapID then
            known[data.key.mapID] = true
        end
    end

    local out = {}
    for mapID in pairs(known) do
        out[#out + 1] = mapID
    end

    table.sort(out, function(a, b)
        return GetMapName(a) < GetMapName(b)
    end)

    return out
end

EnsureMember = function(name)
    if not KeyParty.members[name] then
        KeyParty.members[name] = {
            name = name,
            displayName = name,
            realm = nil,
            isSameRealm = true,
            classToken = nil,
            totalRating = 0,
            dungeonScores = {},
            dungeonLevels = {},
            key = nil,
        }
    end
    return KeyParty.members[name]
end

local function ParseRatingSummary(summary)
    local totalRating = 0
    local scores = {}
    local levels = {}

    if not summary then
        return totalRating, scores, levels
    end

    -- Confirmed field names from API dump (TWW / patch 11.x):
    --   summary.currentSeasonScore    -> total rating
    --   summary.runs[i].challengeModeID -> dungeon ID
    --   summary.runs[i].mapScore        -> dungeon score
    --   summary.runs[i].bestRunLevel    -> highest key level completed
    totalRating = tonumber(summary.currentSeasonScore) or 0

    if type(summary.runs) == "table" then
        for _, run in ipairs(summary.runs) do
            local mapID = tonumber(run.challengeModeID)
            local score = tonumber(run.mapScore)
            local level = tonumber(run.bestRunLevel) or 0
            if mapID and mapID > 0 then
                if score and score > 0 then
                    local prev = scores[mapID] or 0
                    if score > prev then
                        scores[mapID] = score
                    end
                end
                if level > 0 then
                    local prevLevel = levels[mapID] or 0
                    if level > prevLevel then
                        levels[mapID] = level
                    end
                end
            end
        end
    end

    return totalRating, scores, levels
end

local function ParseRaiderIOProfile(profile)
    if type(profile) ~= "table" then
        return 0, nil
    end

    local score = 0
    local key = nil

    local mkp = profile.mythicKeystoneProfile or profile.mythicPlusProfile or profile
    if type(mkp) == "table" then
        score = tonumber(mkp.currentScore or mkp.currentSeasonScore or mkp.score or mkp.mythicPlusScore) or 0
    end

    if score <= 0 then
        score = tonumber(profile.currentScore or profile.currentSeasonScore or profile.score or profile.mythicPlusScore) or 0
    end

    local keyObj = profile.currentKeystone
        or profile.keystone
        or (type(mkp) == "table" and (mkp.currentKeystone or mkp.keystone))

    if type(keyObj) == "table" then
        local mapID = tonumber(
            keyObj.mapChallengeModeID
            or keyObj.challengeModeID
            or keyObj.mapID
        )
        local level = tonumber(keyObj.level or keyObj.keystoneLevel)

        if mapID and level and mapID > 0 and level > 0 then
            key = {
                mapID = mapID,
                level = math.floor(level),
            }
        end
    end

    return score, key
end

local function TryReadRaiderIOByIdentity(unit, fullName, shortName)
    ---@diagnostic disable-next-line: undefined-field
    local rio = _G.RaiderIO
    if type(rio) ~= "table" then
        return 0, nil
    end

    local bestScore = 0
    local bestKey = nil

    local function MergeCandidate(score, key)
        local s = tonumber(score) or 0
        if s > bestScore then
            bestScore = s
        end
        if key and (not bestKey) then
            bestKey = key
        end
    end

    local function TryProfileCall(callable, a, b)
        if type(callable) ~= "function" then
            return
        end

        local ok, profile = pcall(callable, a, b)
        if ok then
            local s, k = ParseRaiderIOProfile(profile)
            MergeCandidate(s, k)
        end
    end

    -- Try common RaiderIO accessors with multiple identities.
    if type(rio.GetProfile) == "function" then
        TryProfileCall(rio.GetProfile, unit)
        TryProfileCall(rio.GetProfile, fullName)
        TryProfileCall(rio.GetProfile, shortName)
    end

    if bestScore <= 0 and type(rio.GetScore) == "function" then
        local function TryScore(arg)
            if not arg then
                return
            end
            local ok, score = pcall(rio.GetScore, arg)
            if ok then
                MergeCandidate(score, nil)
            end
        end

        TryScore(unit)
        TryScore(fullName)
        TryScore(shortName)
    end

    return bestScore, bestKey
end

local function TryReadRaiderIOForUnit(unit)
    local fullName = FullName(unit)
    local shortName = SafeName(unit)
    return TryReadRaiderIOByIdentity(unit, fullName, shortName)
end

local function TryReadRaiderIOByName(name)
    local shortName = CanonicalName(name)
    return TryReadRaiderIOByIdentity(nil, name, shortName)
end

local function ReadUnitRating(unit)
    if not UnitExists(unit) then
        return 0, {}
    end

    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    if not summary and unit == "player" then
        summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    end

    return ParseRatingSummary(summary)
end

local function EnqueueInspectForUnit(unit, name)
    if not unit or not UnitExists(unit) then
        return
    end
    if UnitIsUnit(unit, "player") then
        return
    end
    if not CanInspect(unit) then
        return
    end

    local guid = UnitGUID(unit)
    if not guid or inspectQueuedByGUID[guid] then
        return
    end

    inspectQueuedByGUID[guid] = true
    inspectMetaByGUID[guid] = {
        unit = unit,
        name = name,
    }
    inspectQueue[#inspectQueue + 1] = guid
end

local function ProcessInspectQueue()
    if inspectInFlightGUID or #inspectQueue == 0 then
        return
    end

    local guid = table.remove(inspectQueue, 1)
    local meta = inspectMetaByGUID[guid]
    if not meta or not meta.unit or not UnitExists(meta.unit) then
        inspectQueuedByGUID[guid] = nil
        inspectMetaByGUID[guid] = nil
        C_Timer.After(0.05, ProcessInspectQueue)
        return
    end

    inspectInFlightGUID = guid
    NotifyInspect(meta.unit)
end

local function HandleInspectReady(guid)
    if not guid then
        return
    end

    local meta = inspectMetaByGUID[guid]
    if not meta then
        if inspectInFlightGUID == guid then
            inspectInFlightGUID = nil
        end
        ClearInspectPlayer()
        C_Timer.After(0.05, ProcessInspectQueue)
        return
    end

    local totalRating = 0
    local dungeonScores = {}
    local dungeonLevels = {}

    if meta.unit and UnitExists(meta.unit) then
        totalRating, dungeonScores, dungeonLevels = ReadUnitRating(meta.unit)
    end

    if totalRating <= 0 then
        local summaryByName = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(meta.name)
        totalRating, dungeonScores, dungeonLevels = ParseRatingSummary(summaryByName)
    end

    if totalRating <= 0 then
        local rioRating = 0
        rioRating = select(1, TryReadRaiderIOByName(meta.name))
        if rioRating and rioRating > 0 then
            totalRating = rioRating
        end
    end

    local member = EnsureMember(CanonicalName(meta.name or "Unknown"))
    if totalRating > 0 then
        member.totalRating = totalRating
    end
    if next(dungeonScores) then
        member.dungeonScores = dungeonScores
    end
    if next(dungeonLevels) then
        member.dungeonLevels = dungeonLevels
    end

    inspectQueuedByGUID[guid] = nil
    inspectMetaByGUID[guid] = nil
    if inspectInFlightGUID == guid then
        inspectInFlightGUID = nil
    end

    ClearInspectPlayer()
    RefreshUIIfVisible()
    C_Timer.After(0.08, ProcessInspectQueue)
end

local function GetOwnedKeyInfo()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()

    if not level or not mapID or level <= 0 then
        return nil
    end

    return {
        mapID = mapID,
        level = level,
    }
end

local function SendOwnKeyInfo(channel, target)
    local key = GetOwnedKeyInfo()
    local totalRating = 0
    do
        local playerRating = ReadUnitRating("player")
        totalRating = tonumber(playerRating) or 0
    end

    local payload
    if key then
        payload = string.format("KEY|%d|%d|%d", key.mapID, key.level, math.floor(totalRating))
    else
        payload = string.format("KEY|0|0|%d", math.floor(totalRating))
    end

    C_ChatInfo.SendAddonMessage(KeyParty.prefix, payload, channel, target)
end

local function BestProgressionKey()
    local candidates = {}
    local memberList = {}

    for name, data in pairs(KeyParty.members) do
        memberList[#memberList + 1] = name
        if data.key and data.key.mapID and data.key.level and data.key.level > 0 then
            local id = data.key.mapID .. ":" .. data.key.level
            if not candidates[id] then
                candidates[id] = {
                    owner = name,
                    mapID = data.key.mapID,
                    level = data.key.level,
                }
            end
        end
    end

    local best = nil
    local bestValue = nil

    for _, candidate in pairs(candidates) do
        local missingCount = 0
        local scoreSum = 0
        local counted = 0

        for _, memberName in ipairs(memberList) do
            local data = KeyParty.members[memberName]
            local score = 0
            if data and data.dungeonScores then
                score = data.dungeonScores[candidate.mapID] or 0
            end

            if score <= 0 then
                missingCount = missingCount + 1
            end

            scoreSum = scoreSum + score
            counted = counted + 1
        end

        local avgScore = counted > 0 and (scoreSum / counted) or 0
        local value = (missingCount * 100000) + ((5000 - avgScore) * 10) + (candidate.level * 25)

        if (not bestValue) or (value > bestValue) then
            bestValue = value
            best = {
                owner = candidate.owner,
                mapID = candidate.mapID,
                level = candidate.level,
                missingCount = missingCount,
                memberCount = counted,
                avgScore = avgScore,
            }
        end
    end

    return best
end

KeyParty.GetBestProgressionKey = BestProgressionKey

local function PrintRatingsReport()
    local names = {}
    for name in pairs(KeyParty.members) do
        names[#names + 1] = name
    end
    table.sort(names)

    if #names == 0 then
        Print("No group members found.")
        return
    end

    Print("=== Mythic+ Group Report ===")

    Print("Total rating per group member:")
    for _, name in ipairs(names) do
        local m = KeyParty.members[name]
        Print(string.format("- %s: %.1f", name, m.totalRating or 0))
    end

    Print("Available keystones:")
    local anyKey = false
    for _, name in ipairs(names) do
        local m = KeyParty.members[name]
        if m.key and m.key.level and m.key.level > 0 then
            anyKey = true
            Print(string.format("- %s: %s +%d", name, GetMapName(m.key.mapID), m.key.level))
        else
            Print(string.format("- %s: no key shared", name))
        end
    end

    if not anyKey then
        Print("No group keystones received. Ask everyone to run the addon and use /kp refresh.")
    end

    local best = BestProgressionKey()
    if best then
        Print(string.format("Best progression key: %s +%d (owner: %s)", GetMapName(best.mapID), best.level, best.owner))
        Print(string.format("Reason: %d/%d players have no score on this dungeon, group average %.1f.", best.missingCount, best.memberCount, best.avgScore))
    else
        Print("No progression recommendation possible (no keys available).")
    end
end

local function SnapshotGroupRatings()
    local units = GroupUnits()
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name = SafeName(unit)
            local member = EnsureMember(name)
            local displayName, realm, isSameRealm = GetRealmAwareDisplayName(unit)
            member.displayName = displayName or name
            member.realm = realm
            member.isSameRealm = isSameRealm ~= false
            local _, classToken = UnitClass(unit)
            if classToken and classToken ~= "" then
                member.classToken = classToken
            end
            local totalRating, dungeonScores, dungeonLevels = ReadUnitRating(unit)
            member.totalRating = totalRating
            member.dungeonScores = dungeonScores or {}
            member.dungeonLevels = dungeonLevels or {}

            if totalRating <= 0 then
                local rioRating, rioKey = TryReadRaiderIOForUnit(unit)
                if rioRating and rioRating > 0 then
                    member.totalRating = rioRating
                end
                if (not member.key) and rioKey then
                    member.key = rioKey
                end
            end

            if (not UnitIsUnit(unit, "player")) and (totalRating <= 0) then
                EnqueueInspectForUnit(unit, name)
            end
        end
    end

    ProcessInspectQueue()
end

IsGroupCommunicationAllowed = function()
    if not IsInGroup() and not IsInRaid() and not IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return false
    end

    local groupSize = GetNumGroupMembers()
    if (not groupSize or groupSize <= 0) and IsInGroup() then
        groupSize = GetNumSubgroupMembers() + 1
    end

    return (groupSize or 0) > 0 and groupSize <= 5
end

DetectAddonChannel = function()
    if not IsGroupCommunicationAllowed() then
        return "WHISPER"
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return "WHISPER"
end

local function SnapshotLocalState()
    KeyParty.members = {}
    SnapshotGroupRatings()

    local playerMember = EnsureMember(SafeName("player"))
    playerMember.key = GetOwnedKeyInfo()
end

local function RefreshAndReport(options)
    local passive = (type(options) == "table" and options.passive) and true or false
    local propagateGroupRefresh = true
    local announceBestProgressionKey = false
    local forceBestProgressionKeyAnnouncement = false
    local announceBestProgressionKeyInGroupChat = false
    if type(options) == "table" and options.propagateGroupRefresh == false then
        propagateGroupRefresh = false
    end
    if type(options) == "table" and options.announceBestProgressionKey == true then
        announceBestProgressionKey = true
    end
    if type(options) == "table" and options.forceBestProgressionKeyAnnouncement == true then
        forceBestProgressionKeyAnnouncement = true
    end
    if type(options) == "table" and options.announceBestProgressionKeyInGroupChat == true then
        announceBestProgressionKeyInGroupChat = true
    end

    initialFrameRefreshPending = false

    SnapshotLocalState()

    local channel = DetectAddonChannel()

    if channel == "WHISPER" then
        local playerName = UnitName("player")
        local msg = "KEY_REQ"
        C_ChatInfo.SendAddonMessage(KeyParty.prefix, msg, channel, playerName)
        SendOwnKeyInfo(channel, playerName)
    else
        if propagateGroupRefresh then
            C_ChatInfo.SendAddonMessage(KeyParty.prefix, "REFRESH_REQ", channel)
        end
        C_ChatInfo.SendAddonMessage(KeyParty.prefix, "KEY_REQ", channel)
        SendOwnKeyInfo(channel)
        RequestExternalKeys(channel)
    end

    C_Timer.After(2.0, function()
        local best = BestProgressionKey()
        if KL_UI then
            local shouldPopulate = (not passive)
                or (KL_UI.frame and KL_UI.frame:IsShown())

            if shouldPopulate then
                local ok, err = pcall(function()
                    KL_UI:Populate(KeyParty.members, best)
                end)
                if not ok then
                    Print("UI update failed, falling back to chat report.")
                    Print(tostring(err))
                    if not passive then
                        PrintRatingsReport()
                    end
                end
            end

        elseif not passive then
            PrintRatingsReport()
        end
        if announceBestProgressionKey or forceBestProgressionKeyAnnouncement then
            PrintBestProgressionKeyAnnouncement(
                best,
                forceBestProgressionKeyAnnouncement,
                announceBestProgressionKeyInGroupChat
            )
        end
        KeyParty.lastReportTime = GetServerTime()
    end)
end

local function HandleRemoteRefreshRequest(channel, sender)
    SnapshotLocalState()

    if channel == "WHISPER" and sender and sender ~= "" then
        SendOwnKeyInfo("WHISPER", sender)
    else
        SendOwnKeyInfo(channel)
    end

    if KL_UI and KL_UI.frame and KL_UI.frame:IsShown() then
        local best = BestProgressionKey()
        KL_UI:Populate(KeyParty.members, best)
    end
end

local function SchedulePostDungeonAutoRefresh()
    postDungeonRefreshSerial = postDungeonRefreshSerial + 1
    local serial = postDungeonRefreshSerial
    local shouldAutoOpen = IsAutoOpenAtDungeonEndEnabled()
    local refreshOptions = {
        passive = not shouldAutoOpen,
    }

    -- Run twice to catch delayed API updates right after end-of-run screens.
    C_Timer.After(4.0, function()
        if serial == postDungeonRefreshSerial then
            RefreshAndReport(refreshOptions)
        end
    end)

    C_Timer.After(14.0, function()
        if serial == postDungeonRefreshSerial then
            local finalOptions = {
                passive = refreshOptions.passive,
                announceBestProgressionKey = true,
                announceBestProgressionKeyInGroupChat = IsPartyChatAnnouncementAtDungeonEndEnabled(),
            }
            RefreshAndReport(finalOptions)
        end
    end)
end

local function TestDungeonEndBehavior()
    local shouldAutoOpen = IsAutoOpenAtDungeonEndEnabled()
    Print(string.format(
        "Testing end-of-dungeon behavior: auto-open is %s",
        shouldAutoOpen and "ON" or "OFF"
    ))
    RefreshAndReport({ passive = not shouldAutoOpen })
end

local function TestBestProgressionKeyAnnouncementSolo()
    Print("Testing best progression key announcement.")
    RefreshAndReport({
        passive = true,
        forceBestProgressionKeyAnnouncement = true,
        propagateGroupRefresh = false,
    })
end

local function CountEntries(tbl)
    local n = 0
    if type(tbl) ~= "table" then
        return n
    end
    for _ in pairs(tbl) do
        n = n + 1
    end
    return n
end

local function SerializeTable(tbl, indent, depth, visited)
    if type(tbl) ~= "table" or depth > 6 then
        return tostring(tbl)
    end
    visited = visited or {}
    if visited[tbl] then
        return "<cycle>"
    end
    visited[tbl] = true
    indent = indent or ""
    local childIndent = indent .. "  "
    local lines = { "{" }
    for k, v in pairs(tbl) do
        local key = "[" .. tostring(k) .. "]"
        if type(v) == "table" then
            lines[#lines + 1] = childIndent .. key .. " = " .. SerializeTable(v, childIndent, depth + 1, visited) .. ","
        else
            lines[#lines + 1] = childIndent .. key .. " = " .. tostring(v) .. ","
        end
    end
    lines[#lines + 1] = indent .. "}"
    return table.concat(lines, "\n")
end

local function PrintApiDump()
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    if not summary then
        Print("Summary returned nil. Open the Mythic+ tab in-game first, then retry.")
        return
    end

    local serialized = SerializeTable(summary, "", 0, {})
    KeyPartyDB.apiDump = serialized
    KeyPartyDB.apiDumpTime = date("%Y-%m-%d %H:%M:%S")

    Print("API dump saved to SavedVariables. Do /reload now, then open:")
    Print("  WTF/Account/<name>/SavedVariables/KeyParty.lua")
    Print("Look for the apiDump field.")
end

local function PrintDebugReport()
    KeyParty.members = {}
    SnapshotGroupRatings()

    local names = {}
    for name in pairs(KeyParty.members) do
        names[#names + 1] = name
    end
    table.sort(names)

    Print("=== Debug: Mythic+ Parse Report ===")
    Print(string.format("Members found: %d", #names))

    if #names == 0 then
        Print("No members found for debug output.")
        return
    end

    for _, name in ipairs(names) do
        local member = KeyParty.members[name]
        local scoreCount = CountEntries(member.dungeonScores)
        Print(string.format("- %s: total=%.1f, dungeonScores=%d", name, member.totalRating or 0, scoreCount))

        local printed = 0
        for mapID, score in pairs(member.dungeonScores or {}) do
            Print(string.format("  %s (%d): %.1f", GetMapName(mapID), mapID, score))
            printed = printed + 1
            if printed >= 5 then
                break
            end
        end
    end
end

local function PrintAddonPresenceDebug()
    TriggerAddonPresenceProbe()

    C_Timer.After(0.8, function()
        local names = {}
        local seen = {}
        for _, unit in ipairs(GroupUnits()) do
            if UnitExists(unit) then
                local name = SafeName(unit)
                if name ~= "Unknown" and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
        end

        table.sort(names)

        if #names == 0 then
            Print("Addon presence: no group members found.")
            return
        end

        Print("=== Debug: Addon Presence ===")
        for _, name in ipairs(names) do
            local hasAddon = addonPresenceByName[name] == true
            Print(string.format("- %s: %s", name, hasAddon and "yes" or "no"))
        end
        Print(string.format(
            "All detected in group: %s",
            AreAllGroupMembersUsingAddon() and "yes" or "no"
        ))
    end)
end

local function HandleAddonMessage(prefix, message, channel, sender)
    if not (prefix == KeyParty.prefix or prefix == KeyParty.legacyPrefix) or not message then
        return
    end

    if channel ~= "WHISPER" and not IsGroupCommunicationAllowed() then
        return
    end

    local senderName = CanonicalName(sender or "Unknown")
    MarkAddonPresence(senderName)
    local selfName = SafeName("player")

    if message == "PING_REQ" then
        if sender and sender ~= "" and senderName ~= selfName then
            C_ChatInfo.SendAddonMessage(KeyParty.prefix, "PING_ACK", "WHISPER", sender)
        end
        return
    end

    if message == "PING_ACK" then
        return
    end

    if message == "REFRESH_REQ" then
        if senderName ~= selfName then
            HandleRemoteRefreshRequest(channel, sender)
        end
        return
    end

    if message == "VERSION_REQ" then
        local replyTarget = nil
        local replyChannel = channel
        if sender and sender ~= "" then
            replyChannel = "WHISPER"
            replyTarget = sender
        end
        SendAddonVersion(replyChannel, replyTarget)
        return
    end

    local member = EnsureMember(senderName)

    if message == "KEY_REQ" then
        local replyTarget = nil
        if channel == "WHISPER" then
            replyTarget = sender
        end

        SendOwnKeyInfo(channel, replyTarget)
        return
    end

    local tag, mapID, level, rating = strsplit("|", message)
    if tag == "VERSION_ACK" then
        local remoteVersion = tostring(mapID or "0.0.0")
        MaybeNotifyOutdatedAddonVersion(remoteVersion, senderName)
        return
    end

    if tag == "KEY" then
        local mapIDNum = tonumber(mapID) or 0
        local levelNum = tonumber(level) or 0
        local ratingNum = tonumber(rating) or 0
        if ratingNum > 0 then
            member.totalRating = ratingNum
        end
        if levelNum > 0 and mapIDNum > 0 then
            member.key = {
                mapID = mapIDNum,
                level = levelNum,
            }
        else
            member.key = nil
        end

        RefreshUIIfVisible()
    end
end

local function HandleSlash(msg)
    local cmd = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if cmd == "" then
        -- Toggle frame; if no data yet, also refresh
        if KL_UI then
            if not KL_UI.frame:IsShown() and next(KeyParty.members) == nil then
                RefreshAndReport()
            else
                KL_UI:Toggle()
            end
        else
            RefreshAndReport()
        end
        return
    end

    if cmd == "refresh" then
        RefreshAndReport()
        return
    end

    if cmd == "report" then
        PrintRatingsReport()
        return
    end

    if cmd == "debug" then
        PrintDebugReport()
        return
    end

    if cmd == "debugaddon" then
        PrintAddonPresenceDebug()
        return
    end

    if cmd == "testdungeonend" then
        TestDungeonEndBehavior()
        return
    end

    if cmd == "testbestkeyannouncement" then
        TestBestProgressionKeyAnnouncementSolo()
        return
    end

    if cmd == "debugcolors" then
        if not (KL_UI and KL_UI.GetInstanceScoreColorDebugLines) then
            Print("UI not available for color debug.")
            return
        end

        local delay = 0.2
        if not (KL_UI.frame and KL_UI.frame:IsShown()) then
            RefreshAndReport()
            delay = 2.4
        end

        C_Timer.After(delay, function()
            local lines = KL_UI:GetInstanceScoreColorDebugLines()
            if #lines == 0 then
                Print("No instance score color data available.")
                return
            end

            Print("=== Debug: Instance Score Colors ===")
            for _, line in ipairs(lines) do
                Print(line)
            end
        end)
        return
    end

    if cmd == "debugcooldown" then
        if KL_UI and KL_UI.SetDebugCooldown then
            KL_UI:SetDebugCooldown(45)
            Print("Debug cooldown enabled for 45s.")
        else
            Print("UI not available for debug cooldown.")
        end
        return
    end

    if cmd:match("^debugcooldown%s+") then
        local arg = cmd:match("^debugcooldown%s+(.+)$")
        arg = tostring(arg or ""):gsub("^%s+", ""):gsub("%s+$", "")

        if arg == "off" or arg == "0" then
            if KL_UI and KL_UI.SetDebugCooldown then
                KL_UI:SetDebugCooldown(nil)
                Print("Debug cooldown disabled.")
            else
                Print("UI not available for debug cooldown.")
            end
            return
        end

        local seconds = tonumber(arg)
        if not seconds or seconds <= 0 then
            Print("Usage: /kp debugcooldown [seconds|off]")
            return
        end

        if KL_UI and KL_UI.SetDebugCooldown then
            KL_UI:SetDebugCooldown(seconds)
            Print(string.format("Debug cooldown enabled for %ds.", math.floor(seconds)))
        else
            Print("UI not available for debug cooldown.")
        end
        return
    end

    if cmd == "dumpapi" then
        PrintApiDump()
        return
    end

    if cmd:match("^setportal%s+") then
        local mapID, spellID = cmd:match("^setportal%s+(%d+)%s+(%d+)$")
        mapID = tonumber(mapID)
        spellID = tonumber(spellID)
        if not mapID or not spellID then
            Print("Usage: /kp setportal <mapID> <spellID>")
            return
        end

        NormalizePortalSpellMap()
        KeyPartyDB.portalSpellByMap[mapID] = spellID
        local known = IsSpellKnownByID(spellID)
        Print(string.format(
            "Portal mapping saved: %s (%d) -> spell %d%s",
            GetMapName(mapID), mapID, spellID, known and "" or " (spell not known on this character)"
        ))
        return
    end

    Print("Usage: /kp [refresh|report]")
end

SLASH_KEYPARTY1 = "/keyparty"
SLASH_KEYPARTY2 = "/kp"
SlashCmdList.KEYPARTY = HandleSlash

KeyParty:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon ~= ADDON_NAME then
            return
        end

        NormalizePortalSpellMap()
        SeedDefaultPortalMappings()
        MarkAddonPresence(SafeName("player"))
        if KeyPartyDB.autoOpenAtDungeonEnd == nil then
            KeyPartyDB.autoOpenAtDungeonEnd = false
        end
        if KeyPartyDB.partyChatAnnouncementAtDungeonEnd == nil then
            KeyPartyDB.partyChatAnnouncementAtDungeonEnd = false
        end

        C_ChatInfo.RegisterAddonMessagePrefix(KeyParty.prefix)
        C_ChatInfo.RegisterAddonMessagePrefix(KeyParty.legacyPrefix)
        if KL_UI then
            KL_UI.OnRefresh = RefreshAndReport
            KL_UI.ShouldRefreshOnShow = function()
                return initialFrameRefreshPending
            end
            KL_UI.OnRefreshOnShow = function()
                RefreshAndReport({ passive = true })
            end
            KL_UI.OnToggleAutoOpenAtDungeonEnd = function(enabled)
                SetAutoOpenAtDungeonEndEnabled(enabled)
            end
            KL_UI.OnTogglePartyChatAnnouncementAtDungeonEnd = function(enabled)
                SetPartyChatAnnouncementAtDungeonEndEnabled(enabled)
            end
            if KL_UI.SetAutoOpenAtDungeonEndChecked then
                KL_UI:SetAutoOpenAtDungeonEndChecked(IsAutoOpenAtDungeonEndEnabled())
            end
            if KL_UI.SetPartyChatAnnouncementAtDungeonEndChecked then
                KL_UI:SetPartyChatAnnouncementAtDungeonEndChecked(IsPartyChatAnnouncementAtDungeonEndEnabled())
            end
        end
        Print("loaded. Use /kp to open the panel.")
        return
    end

    if event == "CHAT_MSG_ADDON" then
        HandleAddonMessage(...)
        return
    end

    if event == "INSPECT_READY" then
        local guid = ...
        HandleInspectReady(guid)
        return
    end

    if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_INSTANCE_CHAT" then
        local message, sender = ...
        if TryParseExternalKeyMessage(message, sender) and KL_UI and KL_UI.frame:IsShown() then
            local best = BestProgressionKey()
            KL_UI:Populate(KeyParty.members, best)
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        TriggerAddonPresenceProbe()
        return
    end

    if event == "CHALLENGE_MODE_COMPLETED" then
        SchedulePostDungeonAutoRefresh()
        return
    end
end)

KeyParty:RegisterEvent("ADDON_LOADED")
KeyParty:RegisterEvent("CHAT_MSG_ADDON")
KeyParty:RegisterEvent("INSPECT_READY")
KeyParty:RegisterEvent("CHAT_MSG_PARTY")
KeyParty:RegisterEvent("CHAT_MSG_RAID")
KeyParty:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
KeyParty:RegisterEvent("GROUP_ROSTER_UPDATE")
KeyParty:RegisterEvent("CHALLENGE_MODE_COMPLETED")
