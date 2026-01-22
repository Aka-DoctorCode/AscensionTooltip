local ADDON_NAME = "AscensionTooltip"
local AscensionTooltip = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local talentCache = {}
AscensionTooltip.recentSpells = {}
local MAX_RECENT = 10

local IsSpellKnown = (C_Spell and C_Spell.IsSpellKnown) or (C_SpellBook and C_SpellBook.IsSpellKnown) or _G.IsSpellKnown

-- =========================================================================
-- LOGIC
-- =========================================================================

-- Recent spells tracking
function AscensionTooltip:AddToRecent(spellID)
    local spellInfo = self:SafeGetSpellInfo(spellID)
    if not spellInfo then return end

    table.insert(self.recentSpells, 1, {
        spellID = spellID,
        time = GetTime(),
        name = spellInfo.name or "Unknown"
    })

    -- Keep only recent entries
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
            -- FIX: Check activeEntry to detect selected talents (Passive or Active) correctly
            if nodeInfo.activeEntry then
                local entryID = nodeInfo.activeEntry.entryID
                local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                if entryInfo and entryInfo.definitionID then
                    local def = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if def.spellID then
                        local talent = Spell:CreateFromSpellID(def.spellID)
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

function AscensionTooltip:ApplyTooltipStyling(tooltip)
    local db = self.db.profile
    -- FIX: Explicit nil check for both arguments
    if not tooltip or not db then return end

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
    local db = self.db.profile
    if not db or tooltip.AscensionLastSpell == spellID then return end

    if not tooltip.AscensionHooked then
        tooltip:HookScript("OnTooltipCleared", function(self)
            self.AscensionLastSpell = nil
            if self.SolidBg then self.SolidBg:Hide() end
        end)
        tooltip.AscensionHooked = true
    end

    -- Enhanced combat handling with delay
    if db.HideInCombat and InCombatLockdown() then
        if db.CombatDelay > 0 then
            C_Timer.After(db.CombatDelay, function()
                if not InCombatLockdown() then
                    self:SearchTreeCached(spellID, tooltip)
                end
            end)
        end
        self:ApplyTooltipStyling(tooltip)
        return
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

    -- Add to recent spells
    self:AddToRecent(spellID)

    -- Check if the main spell being hovered is blacklisted
    if db.UserBlacklist[tostring(spellID)] or db.UserBlacklist[spellInfo.name] then
        self:ApplyTooltipStyling(tooltip)
        return
    end

    local nameHex, descHex = self:RGBToHex(db.TalentNameColor.r, db.TalentNameColor.g, db.TalentNameColor.b),
        self:RGBToHex(db.TalentDescColor.r, db.TalentDescColor.g, db.TalentDescColor.b)
    local processedRun = {}

    for talentID, talent in pairs(talentCache) do
        -- Skip if this specific talent is blacklisted
        if not (db.UserBlacklist[tostring(talentID)] or db.UserBlacklist[talent.name]) then
            local isWhitelisted = self.masterWhitelist[spellID] and self.masterWhitelist[spellID][talentID]
            local isMissingName = self.talentsMissingName[spellID] and self.talentsMissingName[spellID][talentID]
            local isUserWhitelisted = db.UserWhitelist[tostring(spellID)] or db.UserWhitelist[spellInfo.name]

            -- Use enhanced description matching
            local descMatch = talent.desc and (self:EnhancedDescMatch(talent.desc, spellInfo.name) or
                (self.replacedSpells[spellID] and self:EnhancedDescMatch(talent.desc,
                    self:SafeGetSpellInfo(self.replacedSpells[spellID]) and self:SafeGetSpellInfo(self.replacedSpells[spellID]).name or "")))

            if (isWhitelisted or isMissingName or isUserWhitelisted or descMatch) then
                if not processedRun[talentID] and not self:IsLineInTooltip(tooltip, talent.name) then
                    tooltip:AddLine(" ")

                    if db.ShowTalentIcons then
                        local spellInfo = self:SafeGetSpellInfo(talentID)
                        local icon = spellInfo and spellInfo.iconID
                        if icon then
                            tooltip:AddLine(string.format("|T%d:18:18:0:0|t %s", icon, nameHex .. talent.name .. ":|r"))
                            local safeDesc = string.gsub(talent.desc, "|r", "|r" .. descHex)
                            tooltip:AddLine(descHex .. safeDesc .. "|r", 1, 1, 1, true)
                        else
                            local safeDesc = string.gsub(talent.desc, "|r", "|r" .. descHex)
                            tooltip:AddLine(nameHex .. talent.name .. ":|r " .. descHex .. safeDesc .. "|r", 1, 1, 1,
                                true)
                        end
                    else
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

function AscensionTooltip:OnInitialize()
    if not self:CheckDependencies() then return end

    self.db = LibStub("AceDB-3.0"):New("AscensionTooltipDB", self.defaults, true)

    -- Register Options Table
    LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, self:GetOptions())

    -- Add to Blizzard Interface Options (Traditional Menu)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, "Ascension Tooltip")

    -- Slash Command
    self:RegisterChatCommand("at", function()
        LibStub("AceConfigDialog-3.0"):Open(ADDON_NAME)
    end)

    -- Add command to show recent spells
    self:RegisterChatCommand("atrecent", function()
        self:Print("Recent spells:")
        for i, entry in ipairs(self.recentSpells or {}) do
            self:Print(string.format("%d. %s (ID: %d)", i, entry.name, entry.spellID))
        end
    end)

    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "UpdateTalentCache")
    self:RegisterEvent("PLAYER_LOGIN", "UpdateTalentCache")
end

-- =========================================================================
-- TOOLTIP HOOKS
-- =========================================================================

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if not data or not data.type then return end

        if data.type == Enum.TooltipDataType.Spell and data.id then
            AscensionTooltip:SearchTreeCached(data.id, tooltip)
        elseif data.type == Enum.TooltipDataType.Macro then
            if data.lines and data.lines[1] and data.lines[1].tooltipID then
                local spellID = data.lines[1].tooltipID
                AscensionTooltip:SearchTreeCached(spellID, tooltip)
            end
        end
    end)
end