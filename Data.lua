-------------------------------------------------------------------------------
-- Project: Ascension Tooltip
-- Author: Aka-DoctorCode
-- File: Data.lua
-- Version: @project-version@
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local addonName = ...
---@class AT : AceAddon
local AT = LibStub("AceAddon-3.0"):GetAddon(addonName) ---@type AT

-------------------------------------------------------------------------------
-- MASTER DATA
-------------------------------------------------------------------------------
AT.talentsMissingName = {
    -- Preservation Evoker
    -- Living Flame
    [361469] = {
        -- Lifeforce Mender
        [376179] = true
    },
    -- Chronoflame
    [431443] = {
        -- Lifeforce Mender
        [376179] = true
    },
    -- Fire Breath
    [357208] = {
        -- Lifeforce Mender
        [376179] = true
    }
}

AT.replacedSpells = {
    -- Shaman Spells
    [378081] = 443454, -- Ancestral Swiftness replaces Nature's Swiftness
    -- Preservation Evoker
    [431443] = 361469, -- Chronoflame replaces Living Flame
    -- Mistweaver Monk
    [467307] = 107428, -- Rushing Wind Kick replaces Rising Sun Kick
    -- Farseer Shaman
    [443454] = 378081, -- Ancestral Swiftness replaces Nature's Swiftness
    -- Subtlety Rogue
    [200758] = 53,     -- Gloomblade replaces Backstab
    -- Affliction Warlock
    [388667] = 686,    -- Drain Soul replaces Shadow Bolt
    -- Evoker
    [382266] = 357208, -- Fire Breath
    [382411] = 359073, -- Eternity Surge
    [382731] = 367226, -- Spiritbloom
    [382614] = 355936, -- Dream Breath
    [396266] = 408092, -- Upheaval
}

AT.masterWhitelist = {
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
    -- Druid / General
    [774]    = { [33891] = true },
    [48438]  = { [33891] = true },
    [8936]   = { [33891] = true },
    [5176]   = { [33891] = true },
    [339]    = { [33891] = true },
    [102693] = { [393371] = true },
    [188389] = { [262303] = true, [378270] = true, [114050] = true },
    [188443] = { [262303] = true },
    [188196] = { [262303] = true },
    [196840] = { [262303] = true },
    [51505]  = { [262303] = true },
}