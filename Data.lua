-------------------------------------------------------------------------------
-- Project: AscensionTooltip
-- Author: Aka-DoctorCode 
-- File: Data.lua
-- Version: 12.0.0
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME = "AscensionTooltip"
local AscensionTooltip = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

-- =========================================================================
-- MASTER DATA
-- =========================================================================
-- Updated: Added Lifeforce Mender logic
AscensionTooltip.talentsMissingName = {
    ----Preservation Evoker
    --Living Flame
    [361469] = {
        --Lifeforce Mender
        [376179] = true
    },
    --Chronoflame
    [431443] = {
        --Lifeforce Mender
        [376179] = true
    },
    --Fire Breath
    [357208] = {
        --Lifeforce Mender
        [376179] = true
    }
}

-- Updated: Removed Cloudburst Totem
AscensionTooltip.replacedSpells = {
    ----Preservation Evoker
    --Chronoflame replaces Living Flame
    [431443] = 361469,
    ----Mistweaver Monk
    --Rushing Wind Kick replaces Rising Sun Kick
    [467307] = 107428,
    -----Farseer Shaman
    --Ancestral Swiftness replaces Natures Swiftness
    [443454] = 378081,
    ----Subtlety Rogue
    --Gloomblade replaces Backstab
    [200758] = 53,
    ---Affliction Warlock
    --Drain Soul replaces Shadow Bolt
    [388667] = 686,
    -- Fire Breath
    [382266] = 357208, 
    -- Eternity Surge
    [382411] = 359073,
    -- Spiritbloom
    [382731] = 367226,
    -- Dream Breath
    [382614] = 355936,
    -- Upheaval
    [396266] = 408092,
}

AscensionTooltip.masterWhitelist = {
    [124682] = { [116680] = true, [388491] = true },
    [115151] = { [116680] = true, [388491] = true },
    [116670] = { [116680] = true, [388491] = true },
    [107428] = { [116680] = true, [388491] = true },
    [191837] = { [116680] = true, [388491] = true },
    [322101] = { [116680] = true, [388491] = true },
    -- Fire Breath
    [357208] = { [408083] = true },
    -- Eternity Surge
    [359073] = { [408083] = true },
    -- Spiritbloom
    [367226] = { [408083] = true },
    -- Dream Breath
    [355936] = { [408083] = true },
    -- Upheaval
    [408092] = { [408083] = true },
    [774] = { [33891] = true },
    [48438] = { [33891] = true },
    [8936] = { [33891] = true },
    [5176] = { [33891] = true },
    [339] = { [33891] = true },
    [102693] = { [393371] = true },
    [188389] = { [262303] = true, [378270] = true, [114050] = true },
    [188443] = { [262303] = true },
    [188196] = { [262303] = true },
    [196840] = { [262303] = true },
    [51505] = { [262303] = true },
}
