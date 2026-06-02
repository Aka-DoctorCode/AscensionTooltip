-------------------------------------------------------------------------------
-- Project: AscensionTooltip
-- Author: Aka-DoctorCode
-- File: Core.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field

local addonName = ...

local AT = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
AT.masterWhitelist = {}
AT.talentsMissingName = {}
AT.replacedSpells = {}
AT.matchCache = {}
local talentCache = {}
AT.recentSpells = {}
local maxRecent = 10

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

function AT:triggerTalentUpdate()
    if self.updateTimer then
        self:CancelTimer(self.updateTimer)
        self.updateTimer = nil
    end
    -- Phase 1 Debouncing: Wait 0.5s before building cache to prevent lag spikes
    self.updateTimer = self:ScheduleTimer("updateTalentCache", 0.5)
end

function AT:addToRecent(spellID)
    local spellInfo = self:safeGetSpellInfo(spellID)
    if not spellInfo then return end
    table.insert(self.recentSpells, 1, {
        spellID = spellID,
        time = GetTime(),
        name = spellInfo.name or "Unknown"
    })
    if #self.recentSpells > maxRecent then
        table.remove(self.recentSpells, maxRecent + 1)
    end
end

function AT:updateTalentCache()
    table.wipe(talentCache)
    table.wipe(self.matchCache)

    -- 1. Standard Class/Spec Talents
    local configID = C_ClassTalents.GetActiveConfigID()
    if configID then
        local configInfo = C_Traits.GetConfigInfo(configID)
        if configInfo then
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
    end

    -- 2. Phase 2: PvP Honor Talents Scanning
    if C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs then
        local pvpTalentIDs = C_SpecializationInfo.GetAllSelectedPvpTalentIDs()
        for _, pvpTalentID in ipairs(pvpTalentIDs) do
            local pvpTalentInfo = C_SpecializationInfo.GetPvpTalentInfo(pvpTalentID)
            if pvpTalentInfo and pvpTalentInfo.spellID then
                local defSpellID = pvpTalentInfo.spellID
                local talent = Spell:CreateFromSpellID(defSpellID)
                if talent then
                    talent:ContinueOnSpellLoad(function()
                        talentCache[defSpellID] = {
                            name = talent:GetSpellName(),
                            desc = talent:GetSpellDescription()
                        }
                    end)
                end
            end
        end
    end
end

function AT:applyTooltipStyling(tooltip)
    if not tooltip or tooltip:IsForbidden() or not self.db then return end

    local db = self.db.profile
    if not db then return end

    if db.ClampToScreen then
        tooltip:SetClampedToScreen(true)
    end
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

    local fontName, fontHeight, fontFlags
    if GameTooltipTextLeft1 then
        fontName, fontHeight, fontFlags = GameTooltipTextLeft1:GetFont()
    else
        fontName = "Fonts\\FRIZQT__.TTF"
        fontFlags = "OUTLINE"
    end
    local targetWidth = db.TooltipWidth or 350
    local maxHeight = db.MaxHeight or 500
    tooltip:SetMinimumWidth(targetWidth)

    local function applyTextStyles(width)
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
    applyTextStyles(targetWidth)
    tooltip:Show()

    -- Height adjustment wrapped in pcall to avoid taint errors
    pcall(function()
        local currentHeight = tooltip:GetHeight()
        if currentHeight > maxHeight and currentHeight > 0 then
            local ratio = currentHeight / maxHeight
            if ratio > 1.02 then
                local maxWidthAllowed = UIParent:GetWidth() * 0.75
                local newWidth = math.min(maxWidthAllowed, targetWidth * ratio * 1.05)
                tooltip:SetMinimumWidth(newWidth)
                applyTextStyles(newWidth)
                tooltip:Show()
            end
        end
    end)
end

function AT:buildStaticMatchCache(spellID, spellInfo)
    local matches = {}
    local replacedID = self.replacedSpells[spellID]
    local replacedSpellInfo = replacedID and self:safeGetSpellInfo(replacedID)
    local replacedName = replacedSpellInfo and replacedSpellInfo.name or ""

    for talentID, talent in pairs(talentCache) do
        local isWhitelisted = self.masterWhitelist[spellID] and self.masterWhitelist[spellID][talentID]
        local isMissingName = self.talentsMissingName[spellID] and self.talentsMissingName[spellID][talentID]

        local descMatch = false
        if talent.desc then
            descMatch = self:enhancedDescMatch(talent.desc, spellInfo.name) or
                (replacedName ~= "" and self:enhancedDescMatch(talent.desc, replacedName))
        end

        if isWhitelisted or isMissingName or descMatch then
            matches[talentID] = true
        end
    end

    self.matchCache[spellID] = matches
    return matches
end

function AT:searchTreeCached(spellID, tooltip)
    if not tooltip.AscensionHooked then
        tooltip:HookScript("OnTooltipCleared", function(self)
            self.AscensionLastSpell = nil
            if self.SolidBg then self.SolidBg:Hide() end
        end)
        tooltip.AscensionHooked = true
    end

    if not tooltip or tooltip:IsForbidden() or not self.db then return end

    local db = self.db.profile
    if not db then return end

    self:applyTooltipStyling(tooltip)
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
        self:applyTooltipStyling(tooltip)
        return
    end
    if db.ShowOnModifier ~= "None" then
        local modifierMap = { Shift = IsShiftKeyDown, Alt = IsAltKeyDown, Ctrl = IsControlKeyDown, Cmd = IsMetaKeyDown }
        if not (modifierMap[db.ShowOnModifier] and modifierMap[db.ShowOnModifier]()) then
            self:applyTooltipStyling(tooltip)
            return
        end
    end
    local spellInfo = self:safeGetSpellInfo(spellID)
    if not spellInfo then return end
    self:addToRecent(spellID)
    if db.UserBlacklist[tostring(spellID)] or db.UserBlacklist[spellInfo.name] then
        self:applyTooltipStyling(tooltip)
        return
    end

    local nameHex, descHex = self:rgbToHex(db.TalentNameColor.r, db.TalentNameColor.g, db.TalentNameColor.b),
        self:rgbToHex(db.TalentDescColor.r, db.TalentDescColor.g, db.TalentDescColor.b)

    local processedRun = {}
    -- Phase 1 Caching: Get or build the heavy string-matching cache for this specific spell
    local staticMatches = self.matchCache[spellID] or self:buildStaticMatchCache(spellID, spellInfo)
    local isSpellUserWhitelisted = db.UserWhitelist[tostring(spellID)] or db.UserWhitelist[spellInfo.name]

    for talentID, talent in pairs(talentCache) do
        if not (db.UserBlacklist[tostring(talentID)] or db.UserBlacklist[talent.name]) then
            local isTalentUserWhitelisted = db.UserWhitelist[tostring(talentID)] or db.UserWhitelist[talent.name]

            if staticMatches[talentID] or isSpellUserWhitelisted or isTalentUserWhitelisted then
                if not processedRun[talentID] and not self:isLineInTooltip(tooltip, talent.name) then
                    if db.ShowTalentIcons then
                        local talentSpellInfo = self:safeGetSpellInfo(talentID)
                        local iconID = talentSpellInfo and talentSpellInfo.iconID
                        if iconID then
                            local iconSize = db.IconSize or 30
                            local safeDescription = string.gsub(talent.desc, "|r", "|r" .. descHex)
                            tooltip:AddLine(
                                string.format("|T%d:%d:%d:0:0|t %s %s", iconID, iconSize, iconSize,
                                    nameHex .. talent.name .. ":|r", descHex .. safeDescription .. "|r"), 1, 1, 1, true)
                        else
                            local safeDescription = string.gsub(talent.desc, "|r", "|r" .. descHex)
                            tooltip:AddLine(nameHex .. talent.name .. ":|r " .. descHex .. safeDescription .. "|r", 1, 1,
                                1, true)
                        end
                    else
                        local safeDescription = string.gsub(talent.desc, "|r", "|r" .. descHex)
                        tooltip:AddLine(nameHex .. talent.name .. ":|r " .. descHex .. safeDescription .. "|r", 1, 1, 1,
                            true)
                    end
                    processedRun[talentID] = true
                end
            end
        end
    end
    tooltip.AscensionLastSpell = spellID
    self:applyTooltipStyling(tooltip)
end

function AT:modifierStateChanged()
    if not self.db then return end

    local db = self.db.profile
    if not db or db.ShowOnModifier == "None" or not GameTooltip:IsShown() then
        return
    end

    -- Bypass strict linter 'undefined field' warnings for modern API
    local getTooltipData = GameTooltip["GetTooltipData"]
    if not getTooltipData then return end

    local data = getTooltipData(GameTooltip)
    if data and data.type == Enum.TooltipDataType.Spell and data.id then
        GameTooltip:SetSpellByID(data.id)
    end
end

function AT:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ATDB", self.defaults, true)

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self:getOptions())

    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "Ascension Tooltip")

    self:RegisterChatCommand("at", function()
        LibStub("AceConfigDialog-3.0"):Open(addonName)
    end)

    self:RegisterChatCommand("atrecent", function()
        self:Print("Recent spells:")
        for i, entry in ipairs(self.recentSpells or {}) do
            self:Print(string.format("%d. %s (ID: %d)", i, entry.name, entry.spellID))
        end
    end)

    -- Use the debounced trigger instead of direct update
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "triggerTalentUpdate")
    self:RegisterEvent("PLAYER_LOGIN", "triggerTalentUpdate")
    self:RegisterEvent("MODIFIER_STATE_CHANGED", "modifierStateChanged")
end

-------------------------------------------------------------------------------
-- TOOLTIP HOOKS
-------------------------------------------------------------------------------

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if not tooltip or tooltip:IsForbidden() then return end
        if InCombatLockdown() then
            AT:applyTooltipStyling(tooltip)
            return
        end
        if not data or not data.type then return end

        local dataType = data.type
        local targetSpellID = nil

        -- Phase 2: Expanded Coverage (Spells, Macros, Auras/Buffs, Pet Actions)
        if dataType == Enum.TooltipDataType.Spell and data.id then
            targetSpellID = data.id
        elseif dataType == Enum.TooltipDataType.Macro then
            if data.lines and data.lines[1] and data.lines[1].tooltipID then
                targetSpellID = data.lines[1].tooltipID
            end
        elseif dataType == Enum.TooltipDataType.UnitAura and data.id then
            -- Auras (Buffs/Debuffs) use data.id directly as the spell ID
            targetSpellID = data.id
        elseif dataType == Enum.TooltipDataType.PetAction and data.id then
            -- Pet actions give us the slot ID, we must convert it to a Spell ID
            local _, _, _, _, _, _, petSpellID = GetPetActionInfo(data.id)
            if petSpellID then
                targetSpellID = petSpellID
            end
        end

        if targetSpellID then
            AT:searchTreeCached(targetSpellID, tooltip)
        end
    end)
end
