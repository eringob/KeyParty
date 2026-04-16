-- KeyPartySeasonData.lua
-- Season-specific dungeon data: update this file when a new M+ season starts.
--
-- Each entry requires:
--   mapID   - C_ChallengeMode map ID (look up with /kp debugportal or Wowhead)
--   spellID - portal/teleport spell ID (cast the spell, then check /kp debugportal)
--   name    - display name, used as fallback when mapID is 0
--
-- Set a manual override in-game with: /kp setportal <mapID> <spellID>

-- Season 1 - Midnight (patch 12.x)
KeyParty_SeasonDungeons = {
    { mapID = 557, spellID = 1254400, name = "Windrunner Spire" },
    { mapID = 560, spellID = 1254559, name = "Maisara Caverns" },
    { mapID = 559, spellID = 1254563, name = "Nexus-Point Xenas" },
    { mapID = 558, spellID = 1254572, name = "Magisters' Terrace" },
    { mapID = 556, spellID = 1254555, name = "Pit of Saron" },
    { mapID = 239, spellID = 1254551, name = "Seat of the Triumvirate" },
    { mapID = 161, spellID = 159898,  name = "Skyreach" },
    { mapID = 402, spellID = 393273,  name = "Algeth'ar Academy" },
}
