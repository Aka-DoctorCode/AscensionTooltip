--[[ 
    AscensionTooltip v3.0.0
    Migración completa a Ace3 Framework
]]

local ADDON_NAME = "AscensionTooltip"
AscensionTooltip = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")

-- =========================================================================
-- CONFIGURACIÓN POR DEFECTO (AceDB)
-- =========================================================================
local defaults = {
    profile = {
        TooltipWidth = 350,
        FontSize = 12,
        ClampToScreen = true,
        HideInCombat = false,
        MaxHeightPercent = 70,
        TooltipOpacity = 90,
        ShowOnModifier = "None",    -- None, Shift, Alt, Ctrl, Cmd
        DisableExtraInfo = false,
        -- Text Colors
        TalentNameColor = {r=0.2, g=1.0, b=1.0, a=1.0},
        TalentDescColor = {r=1.0, g=0.82, b=0.0, a=1.0},
        -- Background/Border Colors
        BackgroundColor = {r=0.05, g=0.05, b=0.05}, 
        BorderColor = {r=0.8, g=0.8, b=0.8, a=1.0}
    }
}

-- =========================================================================
-- DATOS ESTÁTICOS
-- =========================================================================
local talentsMissingName = { [370960] = { [377082] = true } }
local replacedSpells = { [431443] = 361469, [467307] = 107428, [157153] = 5394, [443454] = 378081, [200758] = 53, [388667] = 686 }
local blacklistedTalents = {
    [124682] = { [116680] = true, [388491] = true }, [115151] = { [116680] = true, [388491] = true },
    [116670] = { [116680] = true, [388491] = true }, [107428] = { [116680] = true, [388491] = true },
    [191837] = { [116680] = true, [388491] = true }, [322101] = { [116680] = true, [388491] = true },
    [774] = { [33891] = true }, [48438] = { [33891] = true }, [8936] = { [33891] = true },
    [5176] = { [33891] = true }, [339] = { [33891] = true }, [102693] = { [393371] = true },
    [188389] = { [262303] = true, [378270] = true, [114050] = true }, [188443] = { [262303] = true },
    [188196] = { [262303] = true }, [196840] = { [262303] = true }, [51505] = { [262303] = true },
}

local talentCache = {}

-- =========================================================================
-- FUNCIONES AUXILIARES
-- =========================================================================

local function RGBToHex(r, g, b)
    return string.format("|cff%02x%02x%02x", (r or 1)*255, (g or 1)*255, (b or 1)*255)
end

local function IsLineInTooltip(tooltip, textPart)
    if not textPart or textPart == "" then return false end
    local tooltipName = tooltip:GetName()
    if not tooltipName then return false end
    for i = 1, tooltip:NumLines() do
        local line = _G[tooltipName.."TextLeft"..i]
        local text = line and line:GetText()
        if text and string.find(text, textPart, 1, true) then return true end
    end
    return false
end

-- =========================================================================
-- LÓGICA DE VISUALIZACIÓN
-- =========================================================================

function AscensionTooltip:ApplyTooltipStyling(tooltip)
    local db = self.db.profile
    if not tooltip or not db then return end

    if db.ClampToScreen then tooltip:SetClampedToScreen(true) end

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
    elseif tooltip.SetBackdropColor then
        tooltip:SetBackdropColor(0, 0, 0, 0)
        tooltip:SetBackdropBorderColor(db.BorderColor.r, db.BorderColor.g, db.BorderColor.b, db.BorderColor.a or 1)
    end

    local fontName, _, fontFlags = GameTooltipTextLeft1:GetFont()
    local targetWidth = db.TooltipWidth or 350
    local screenHeight = UIParent:GetHeight()
    local maxHeight = screenHeight * (db.MaxHeightPercent / 100)

    tooltip:SetMinimumWidth(targetWidth)

    local function ApplyTextStyles(width)
        for i = 1, tooltip:NumLines() do
            local left = _G[tooltip:GetName().."TextLeft"..i]
            if left then
                left:SetWidth(width - 20)
                left:SetWordWrap(true)
                left:SetFont(fontName, db.FontSize, fontFlags)
            end
        end
    end

    ApplyTextStyles(targetWidth)
    tooltip:Show()

    local currentHeight = tooltip:GetHeight()
    if currentHeight > maxHeight and currentHeight > 0 then
        local ratio = currentHeight / maxHeight
        if ratio > 1.05 then
            local newWidth = math.min(UIParent:GetWidth() * 0.6, targetWidth * ratio * 1.05)
            tooltip:SetMinimumWidth(newWidth)
            ApplyTextStyles(newWidth)
            tooltip:Show()
        end
    end
end

-- =========================================================================
-- MENÚ DE OPCIONES (AceConfig)
-- =========================================================================

function AscensionTooltip:GetOptions()
    return {
        name = "Ascension Tooltip",
        handler = AscensionTooltip,
        type = "group",
        args = {
            general = {
                name = "General Settings",
                type = "group",
                inline = true,
                order = 1,
                args = {
                    width = {
                        name = "Tooltip Width",
                        type = "range", min = 200, max = 600, step = 1,
                        get = function() return self.db.profile.TooltipWidth end,
                        set = function(_, v) self.db.profile.TooltipWidth = v end,
                        order = 1,
                    },
                    maxHeight = {
                        name = "Max Height %",
                        type = "range", min = 30, max = 95, step = 1,
                        get = function() return self.db.profile.MaxHeightPercent end,
                        set = function(_, v) self.db.profile.MaxHeightPercent = v end,
                        order = 2,
                    },
                    fontSize = {
                        name = "Font Size",
                        type = "range", min = 8, max = 24, step = 1,
                        get = function() return self.db.profile.FontSize end,
                        set = function(_, v) self.db.profile.FontSize = v end,
                        order = 3,
                    },
                    opacity = {
                        name = "Opacity %",
                        type = "range", min = 0, max = 100, step = 1,
                        get = function() return self.db.profile.TooltipOpacity end,
                        set = function(_, v) self.db.profile.TooltipOpacity = v end,
                        order = 4,
                    },
                    modifier = {
                        name = "Modifier Key",
                        type = "select",
                        values = { ["None"]="None", ["Shift"]="Shift", ["Alt"]="Alt", ["Ctrl"]="Ctrl", ["Cmd"]="Cmd" },
                        get = function() return self.db.profile.ShowOnModifier end,
                        set = function(_, v) self.db.profile.ShowOnModifier = v end,
                        order = 5,
                    },
                    clamp = {
                        name = "Clamp to Screen",
                        type = "toggle",
                        get = function() return self.db.profile.ClampToScreen end,
                        set = function(_, v) self.db.profile.ClampToScreen = v end,
                        order = 6,
                    },
                    combat = {
                        name = "Hide in Combat",
                        type = "toggle",
                        get = function() return self.db.profile.HideInCombat end,
                        set = function(_, v) self.db.profile.HideInCombat = v end,
                        order = 7,
                    },
                    disable = {
                        name = "Disable Info",
                        type = "toggle",
                        get = function() return self.db.profile.DisableExtraInfo end,
                        set = function(_, v) self.db.profile.DisableExtraInfo = v end,
                        order = 8,
                    },
                }
            },
            colors = {
                name = "Colors",
                type = "group",
                inline = true,
                order = 2,
                args = {
                    nameColor = {
                        name = "Talent Name Color",
                        type = "color", hasAlpha = true,
                        get = function() local c = self.db.profile.TalentNameColor return c.r, c.g, c.b, c.a end,
                        set = function(_, r, g, b, a) self.db.profile.TalentNameColor = {r=r, g=g, b=b, a=a} end,
                        order = 1,
                    },
                    descColor = {
                        name = "Talent Description Color",
                        type = "color", hasAlpha = true,
                        get = function() local c = self.db.profile.TalentDescColor return c.r, c.g, c.b, c.a end,
                        set = function(_, r, g, b, a) self.db.profile.TalentDescColor = {r=r, g=g, b=b, a=a} end,
                        order = 2,
                    },
                    bgColor = {
                        name = "Background Color",
                        type = "color",
                        get = function() local c = self.db.profile.BackgroundColor return c.r, c.g, c.b end,
                        set = function(_, r, g, b) self.db.profile.BackgroundColor = {r=r, g=g, b=b} end,
                        order = 3,
                    },
                    borderColor = {
                        name = "Border Color",
                        type = "color", hasAlpha = true,
                        get = function() local c = self.db.profile.BorderColor return c.r, c.g, c.b, c.a end,
                        set = function(_, r, g, b, a) self.db.profile.BorderColor = {r=r, g=g, b=b, a=a} end,
                        order = 4,
                    },
                }
            },
            reset = {
                name = "Reset Settings",
                type = "execute",
                func = function() self.db:ResetProfile() ReloadUI() end,
                order = 3,
            }
        }
    }
end

-- =========================================================================
-- EVENTOS Y CORE
-- =========================================================================

function AscensionTooltip:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("AscensionTooltipDB", defaults, true)
    
    LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, self:GetOptions())
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, "Ascension Tooltip")

    local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME .. " Profiles", profiles)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME .. " Profiles", "Profiles", "Ascension Tooltip")

    self:RegisterChatCommand("at", function() InterfaceOptionsFrame_OpenToCategory(self.optionsFrame) end)
    
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "UpdateTalentCache")
    self:RegisterEvent("PLAYER_LOGIN", "UpdateTalentCache")
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
            for _, entryID in ipairs(nodeInfo.entryIDs) do
                local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                if entryInfo and entryInfo.definitionID then
                    local def = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if def.spellID and IsPlayerSpell(def.spellID) then
                        local talent = Spell:CreateFromSpellID(def.spellID)
                        talent:ContinueOnSpellLoad(function()
                            talentCache[def.spellID] = { name = talent:GetSpellName(), desc = talent:GetSpellDescription() }
                        end)
                    end
                end
            end
        end
    end
end

-- =========================================================================
-- TOOLTIP LOGIC
-- =========================================================================

local function SearchTreeCached(spellID, tooltip)
    local db = AscensionTooltip.db.profile
    if not db or tooltip.AscensionLastSpell == spellID then return end

    if not tooltip.AscensionHooked then
        tooltip:HookScript("OnTooltipCleared", function(self)
            self.AscensionLastSpell = nil
            if self.SolidBg then self.SolidBg:Hide() end
        end)
        tooltip.AscensionHooked = true
    end

    if (db.HideInCombat and InCombatLockdown()) or db.DisableExtraInfo then
        tooltip.AscensionLastSpell = spellID
        AscensionTooltip:ApplyTooltipStyling(tooltip)
        return
    end

    if db.ShowOnModifier ~= "None" then
        local modifierMap = { Shift = IsShiftKeyDown, Alt = IsAltKeyDown, Ctrl = IsControlKeyDown, Cmd = IsMetaKeyDown }
        if not (modifierMap[db.ShowOnModifier] and modifierMap[db.ShowOnModifier]()) then
            tooltip.AscensionLastSpell = spellID
            AscensionTooltip:ApplyTooltipStyling(tooltip)
            return
        end
    end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then return end
    
    local extraName = replacedSpells[spellID] and C_Spell.GetSpellInfo(replacedSpells[spellID]).name
    local nameHex, descHex = RGBToHex(db.TalentNameColor.r, db.TalentNameColor.g, db.TalentNameColor.b), RGBToHex(db.TalentDescColor.r, db.TalentDescColor.g, db.TalentDescColor.b)
    local processedRun = {}

    for talentID, talent in pairs(talentCache) do
        local isBlacklisted = blacklistedTalents[spellID] and blacklistedTalents[spellID][talentID]
        local isMissing = talentsMissingName[spellID] and talentsMissingName[spellID][talentID]
        local nameMatch = talent.name ~= spellInfo.name
        local descMatch = talent.desc and (string.find(talent.desc, spellInfo.name, 1, true) or (extraName and string.find(talent.desc, extraName, 1, true)))

        if (isMissing or (not isBlacklisted and nameMatch and descMatch)) then
            if not processedRun[talent.name] and not IsLineInTooltip(tooltip, talent.name) then
                tooltip:AddLine(" ")
                local safeDesc = string.gsub(talent.desc, "|r", "|r" .. descHex)
                tooltip:AddLine(nameHex .. talent.name .. ":|r " .. descHex .. safeDesc .. "|r", 1, 1, 1, true)
                processedRun[talent.name] = true
            end
        end
    end
    
    tooltip.AscensionLastSpell = spellID
    AscensionTooltip:ApplyTooltipStyling(tooltip)
end

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if not data or not data.type then return end
        if data.type == Enum.TooltipDataType.Spell and IsSpellKnownOrOverridesKnown(data.id) then
            SearchTreeCached(data.id, tooltip)
        elseif data.type == Enum.TooltipDataType.Macro and data.lines[1].tooltipID and IsSpellKnownOrOverridesKnown(data.lines[1].tooltipID) then
            SearchTreeCached(data.lines[1].tooltipID, tooltip)
        elseif tooltip.AscensionLastSpell then
            AscensionTooltip:ApplyTooltipStyling(tooltip)
        end
    end)
end