-- KeyPartySeasonData.lua
-- Season-specific dungeon data: update this file when a new M+ season starts.
--
-- Each entry requires:
--   mapID   - C_ChallengeMode map ID (look up with /kp debugportal or Wowhead)
--   spellID - portal/teleport spell ID (cast the spell, then check /kp debugportal)
--   name    - display name, used as fallback when mapID is 0
--
-- Set a manual override in-game with: /kp setportal <mapID> <spellID>

-- Season 2 - Midnight (patch 12.1 / The War Within)
KeyParty_SeasonDungeons = {
    { mapID = 2509, spellID = 1286812, name = "Altar of Fangs" },
    { mapID = 2393, spellID = 1286809, name = "Murder Row" },
    { mapID = 2437, spellID = 1286807, name = "Den of Nalorakk" },
    { mapID = 2413, spellID = 1286801, name = "The Blinding Vale" },
    { mapID = 2444, spellID = 1286804, name = "Voidscar Arena" },
    { mapID = 1763, spellID = 1286831, name = "Kings' Rest" },
    { mapID = 1038, spellID = 1286828, name = "Temple of Sethraliss" },
    { mapID = 430, spellID = 393256, name = "Ruby Life Pools" },
}
