-------------------------------------------------------------------------------
-- Project: AscensionTooltip
-- Author: Aka-DoctorCode 
-- File: Core.lua
-- Version: 12.0.0
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME = "AscensionTooltip"
local AscensionTooltip = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

AscensionTooltip.masterWhitelist = {}
AscensionTooltip.talentsMissingName = {}
AscensionTooltip.replacedSpells = {}

local talentCache = {}
AscensionTooltip.recentSpells = {}
local MAX_RECENT = 10

local IsSpellKnown = (C_Spell and C_Spell.IsSpellKnown) or (C_SpellBook and C_SpellBook.IsSpellKnown) or _G.IsSpellKnown

-- =========================================================================
-- LOGIC
-- =========================================================================
function AscensionTooltip:AddToRecent(spellID)
    local spellInfo = self:SafeGetSpellInfo(spellID)
    if not spellInfo then return end

    table.insert(self.recentSpells, 1, {
        spellID = spellID,
        time = GetTime(),
        name = spellInfo.name or "Unknown"
    })

    if #self.recentSpells > MAX_RECENT then
        table.remove(self.recentSpells, MAX_RECENT + 1)
    end
end

function AscensionTooltip:UpdateTalentCache()
    table.wipe(talentCache)
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return end
    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo then return end

    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodes = C_Traits.GetTreeNodes(treeID)
        for _, nodeID in ipairs(nodes) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            if nodeInfo and nodeInfo.activeEntry and nodeInfo.currentRank and nodeInfo.currentRank > 0 then
                local entryID = nodeInfo.activeEntry.entryID
                local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                if entryInfo and entryInfo.definitionID then
                    local def = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if def.spellID then
                        local talent = Spell:CreateFromSpellID(def.spellID)
                        if talent then
                            talent:ContinueOnSpellLoad(function()
                                talentCache[def.spellID] = {
                                    name = talent:GetSpellName(),
                                    desc = talent:GetSpellDescription()
                                }
                            end)
                        end
                    end
                end
            end
        end
    end
end

function AscensionTooltip:ApplyTooltipStyling(tooltip)
    if not tooltip or tooltip:IsForbidden() or not self.db or not self.db.profile then return end
    local db = self.db.profile

    if db.ClampToScreen then 
        tooltip:SetClampedToScreen(true) 
    end

    -- Apply anchoring if not default
    if db.AnchorPoint and db.AnchorPoint ~= "ANCHOR_CURSOR" then
        tooltip:SetOwner(UIParent, db.AnchorPoint, db.AnchorOffsetX, db.AnchorOffsetY)
    end

    local alpha = (db.TooltipOpacity or 90) / 100
    if not tooltip.SolidBg then
        tooltip.SolidBg = tooltip:CreateTexture(nil, "BACKGROUND")
        tooltip.SolidBg:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 4, -4)
        tooltip.SolidBg:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -4, 4)
    end
    tooltip.SolidBg:SetColorTexture(db.BackgroundColor.r, db.BackgroundColor.g, db.BackgroundColor.b, alpha)
    tooltip.SolidBg:Show()

    if tooltip.NineSlice then
        tooltip.NineSlice:SetCenterColor(0, 0, 0, 0)
        tooltip.NineSlice:SetBorderColor(db.BorderColor.r, db.BorderColor.g, db.BorderColor.b, db.BorderColor.a or 1)
    end

    -- FIX: Added safety check for GameTooltipTextLeft1
    local fontName, fontHeight, fontFlags
    if GameTooltipTextLeft1 then
        fontName, fontHeight, fontFlags = GameTooltipTextLeft1:GetFont()
    else
        -- Fallback if font object is not ready
        fontName = "Fonts\\FRIZQT__.TTF"
        fontFlags = "OUTLINE"
    end

    local targetWidth = db.TooltipWidth or 350
    local maxHeight = db.MaxHeight or 500

    tooltip:SetMinimumWidth(targetWidth)

    local function ApplyTextStyles(width)
        for i = 1, tooltip:NumLines() do
            local left = _G[tooltip:GetName() .. "TextLeft" .. i]
            if left then
                left:SetWidth(width - 20)
                left:SetWordWrap(true)
                if fontName then
                    left:SetFont(fontName, db.FontSize, fontFlags)
                end
            end
        end
    end

    ApplyTextStyles(targetWidth)
    tooltip:Show()

    local currentHeight = tooltip:GetHeight()
    if currentHeight > maxHeight and currentHeight > 0 then
        local ratio = currentHeight / maxHeight
        if ratio > 1.02 then
            local maxWidthAllowed = UIParent:GetWidth() * 0.75
            local newWidth = math.min(maxWidthAllowed, targetWidth * ratio * 1.05)
            tooltip:SetMinimumWidth(newWidth)
            ApplyTextStyles(newWidth)
            tooltip:Show()
        end
    end
end

function AscensionTooltip:SearchTreeCached(spellID, tooltip)
    if not tooltip.AscensionHooked then
        tooltip:HookScript("OnTooltipCleared", function(self)
            self.AscensionLastSpell = nil
            if self.SolidBg then self.SolidBg:Hide() end
        end)
        tooltip.AscensionHooked = true
    end

    if not tooltip or tooltip:IsForbidden() or not self.db or not self.db.profile then return end
    local db = self.db.profile

    self:ApplyTooltipStyling(tooltip)

    if InCombatLockdown() then 
        return 
    end

    if tooltip.AscensionLastSpell == spellID then return end

    if not tooltip.AscensionHooked then
        tooltip:HookScript("OnTooltipCleared", function(self)
            self.AscensionLastSpell = nil
            if self.SolidBg then self.SolidBg:Hide() end
        end)
        tooltip.AscensionHooked = true
    end

    if db.DisableExtraInfo then
        self:ApplyTooltipStyling(tooltip)
        return
    end

    if db.ShowOnModifier ~= "None" then
        local modifierMap = { Shift = IsShiftKeyDown, Alt = IsAltKeyDown, Ctrl = IsControlKeyDown, Cmd = IsMetaKeyDown }
        if not (modifierMap[db.ShowOnModifier] and modifierMap[db.ShowOnModifier]()) then
            self:ApplyTooltipStyling(tooltip)
            return
        end
    end

    local spellInfo = self:SafeGetSpellInfo(spellID)
    if not spellInfo then return end

    self:AddToRecent(spellID)

    if db.UserBlacklist[tostring(spellID)] or db.UserBlacklist[spellInfo.name] then
        self:ApplyTooltipStyling(tooltip)
        return
    end

    local nameHex, descHex = self:RGBToHex(db.TalentNameColor.r, db.TalentNameColor.g, db.TalentNameColor.b),
        self:RGBToHex(db.TalentDescColor.r, db.TalentDescColor.g, db.TalentDescColor.b)
    local processedRun = {}

    for talentID, talent in pairs(talentCache) do
        if not (db.UserBlacklist[tostring(talentID)] or db.UserBlacklist[talent.name]) then
            local isWhitelisted = self.masterWhitelist[spellID] and self.masterWhitelist[spellID][talentID]
            local isMissingName = self.talentsMissingName[spellID] and self.talentsMissingName[spellID][talentID]
            local isUserWhitelisted = db.UserWhitelist[tostring(spellID)] or db.UserWhitelist[spellInfo.name]
            local descMatch = talent.desc and (self:EnhancedDescMatch(talent.desc, spellInfo.name) or
                (self.replacedSpells[spellID] and self:EnhancedDescMatch(talent.desc,
                    self:SafeGetSpellInfo(self.replacedSpells[spellID]) and self:SafeGetSpellInfo(self.replacedSpells[spellID]).name or "")))

            if (isWhitelisted or isMissingName or isUserWhitelisted or descMatch) then
                if not processedRun[talentID] and not self:IsLineInTooltip(tooltip, talent.name) then

                    if db.ShowTalentIcons then
                        local talentSpellInfo = self:SafeGetSpellInfo(talentID)
                        local icon = talentSpellInfo and talentSpellInfo.iconID
                        
                        if icon then
                            -- Case 1: Icon found, name and description on the same line using dynamic IconSize
                            local iconSize = db.IconSize or 30
                            local safeDesc = string.gsub(talent.desc, "|r", "|r" .. descHex)
                            tooltip:AddLine(string.format("|T%d:%d:%d:0:0|t %s %s", icon, iconSize, iconSize, nameHex .. talent.name .. ":|r", descHex .. safeDesc .. "|r"), 1, 1, 1, true)
                        else
                            -- Case 2: Icon option ON, but icon not found (Fallback to text only)
                            local safeDesc = string.gsub(talent.desc, "|r", "|r" .. descHex)
                            tooltip:AddLine(nameHex .. talent.name .. ":|r " .. descHex .. safeDesc .. "|r", 1, 1, 1, true)
                        end
                    else
                        -- Case 3: Icon option OFF (Text only)
                        local safeDesc = string.gsub(talent.desc, "|r", "|r" .. descHex)
                        tooltip:AddLine(nameHex .. talent.name .. ":|r " .. descHex .. safeDesc .. "|r", 1, 1, 1, true)
                    end

                    processedRun[talentID] = true
                end
            end
        end
    end

    tooltip.AscensionLastSpell = spellID
    self:ApplyTooltipStyling(tooltip)
end

function AscensionTooltip:MODIFIER_STATE_CHANGED()
    if not self.db or self.db.profile.ShowOnModifier == "None" or not GameTooltip:IsShown() then 
        return 
    end

    local data = GameTooltip:GetTooltipData()
    if data and data.type == Enum.TooltipDataType.Spell and data.id then
        GameTooltip:SetSpellByID(data.id)
    end
end

function AscensionTooltip:OnInitialize()
    if not self:CheckDependencies() then return end

    self.db = LibStub("AceDB-3.0"):New("AscensionTooltipDB", self.defaults, true)

    LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, self:GetOptions())

    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, "Ascension Tooltip")

    self:RegisterChatCommand("at", function()
        LibStub("AceConfigDialog-3.0"):Open(ADDON_NAME)
    end)
    self:RegisterChatCommand("atrecent", function()
        self:Print("Recent spells:")
        for i, entry in ipairs(self.recentSpells or {}) do
            self:Print(string.format("%d. %s (ID: %d)", i, entry.name, entry.spellID))
        end
    end)

    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "UpdateTalentCache")
    self:RegisterEvent("PLAYER_LOGIN", "UpdateTalentCache")
    self:RegisterEvent("MODIFIER_STATE_CHANGED") 
end

-- =========================================================================
-- TOOLTIP HOOKS
-- =========================================================================

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if not tooltip or tooltip:IsForbidden() then return end

        if InCombatLockdown() then
            AscensionTooltip:ApplyTooltipStyling(tooltip)
            return
        end

        if not data or not data.type then return end
        
        local dataType = data.type
        if dataType == Enum.TooltipDataType.Spell and data.id then
            AscensionTooltip:SearchTreeCached(data.id, tooltip)
        elseif dataType == Enum.TooltipDataType.Macro then
            if data.lines and data.lines[1] and data.lines[1].tooltipID then
                local spellID = data.lines[1].tooltipID
                if spellID then
                    AscensionTooltip:SearchTreeCached(spellID, tooltip)
                end
            end
        end
    end)
end
