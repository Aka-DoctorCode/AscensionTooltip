--[[ 
    AscensionTooltip
    Version: 3.4.1
    Description:
    An enhanced tooltip addon for Project Ascension, providing detailed talent 
    information and interactive spell-talent relationship insights.
    
    Features: 
    - Full Visual Customization: Adjust colors, opacity, and borders for a premium look.
    - Smart Scaling: Pixel-based MaxHeight with automatic width adjustment to prevent overlap.
    - User Whitelist: Manually add spells/talents to your local database and contribute to the community.
    - User Blacklist: Exclude specific entries to keep your tooltips clean and relevant.
    - Data Resolving: Real-time resolution of Spell Names, IDs, and Icons in the settings menu.
    - Multi-Platform Reporting: Easily share your whitelist with the developer via GitHub, CurseForge, or Raw Data.
    - Profile Management: Save and reset configurations per character profile.
]]

local ADDON_NAME = "AscensionTooltip"
AscensionTooltip = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")

-- =========================================================================
-- STATIC POPUP CONFIGURATION
-- =========================================================================
StaticPopupDialogs["ASCENSION_TOOLTIP_REPORT"] = {
    text = "%s",
    button1 = "Close",
    hasEditBox = 1,
    editBoxWidth = 350,
    OnShow = function(self, data)
        if self.EditBox then
            self.EditBox:SetText(data or "")
            self.EditBox:SetFocus()
            self.EditBox:HighlightText()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- =========================================================================
-- DEFAULT SETTINGS (AceDB)
-- =========================================================================
local defaults = {
    profile = {
        TooltipWidth = 350,
        FontSize = 12,
        ClampToScreen = true,
        HideInCombat = false,
        MaxHeight = 500,
        TooltipOpacity = 90,
        ShowOnModifier = "None",
        DisableExtraInfo = false,
        TalentNameColor = {r=0.2, g=1.0, b=1.0, a=1.0},
        TalentDescColor = {r=1.0, g=0.82, b=0.0, a=1.0},
        BackgroundColor = {r=0.05, g=0.05, b=0.05}, 
        BorderColor = {r=0.8, g=0.8, b=0.8, a=1.0},
        UserWhitelist = {},
        UserBlacklist = {},
        -- Developer Metadata
        GithubUser = "aka-doctorcode", 
        GithubRepo = "ascensiontooltip",
        CurseForgeURL = "https://www.curseforge.com/wow/addons/ascensiontooltip/comments"
    }
}

-- =========================================================================
-- MASTER DATA
-- =========================================================================
local talentsMissingName = { [370960] = { [377082] = true } }

local replacedSpells = { 
    [431443] = 361469, [467307] = 107428, [157153] = 5394, 
    [443454] = 378081, [200758] = 53, [388667] = 686 
}

local masterWhitelist = {
    [124682] = { [116680] = true, [388491] = true }, 
    [115151] = { [116680] = true, [388491] = true },
    [116670] = { [116680] = true, [388491] = true }, 
    [107428] = { [116680] = true, [388491] = true },
    [191837] = { [116680] = true, [388491] = true }, 
    [322101] = { [116680] = true, [388491] = true },
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

local talentCache = {}

-- =========================================================================
-- UTILITY FUNCTIONS
-- =========================================================================

local function RGBToHex(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor((r or 1)*255), math.floor((g or 1)*255), math.floor((b or 1)*255))
end

local function URLEncode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
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
-- VISUALIZATION & SCALING LOGIC
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
    end

    local fontName, _, fontFlags = GameTooltipTextLeft1:GetFont()
    local targetWidth = db.TooltipWidth or 350
    local maxHeight = db.MaxHeight or 500

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
        if ratio > 1.02 then
            local maxWidthAllowed = UIParent:GetWidth() * 0.75
            local newWidth = math.min(maxWidthAllowed, targetWidth * ratio * 1.05)
            tooltip:SetMinimumWidth(newWidth)
            ApplyTextStyles(newWidth)
            tooltip:Show()
        end
    end
end

-- =========================================================================
-- OPTIONS MENU (AceConfig)
-- =========================================================================

function AscensionTooltip:GetOptions()
    return {
        name = "Ascension Tooltip",
        handler = AscensionTooltip,
        type = "group",
        desc = "Detailed talent information and interactive spell-talent relationship insights for Project Ascension.",
        args = {
            general = {
                name = "General Settings",
                type = "group",
                inline = true,
                order = 1,
                args = {
                    width = {
                        name = "Base Width",
                        type = "range", min = 200, max = 800, step = 1,
                        get = function() return self.db.profile.TooltipWidth end,
                        set = function(_, v) self.db.profile.TooltipWidth = v end,
                        order = 1,
                    },
                    maxHeight = {
                        name = "Max Height (Pixels)",
                        desc = "The tooltip will grow wider if it exceeds this height.",
                        type = "range", min = 100, max = 1500, step = 10,
                        get = function() return self.db.profile.MaxHeight end,
                        set = function(_, v) self.db.profile.MaxHeight = v end,
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
                        name = "Background Opacity %",
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
                }
            },
            colors = {
                name = "Color Customization",
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
                }
            },
            whitelist = {
                name = "Whitelist & Contribution",
                type = "group",
                inline = true,
                order = 3,
                args = {
                    addSpell = {
                        name = "Add Spell/Talent to Whitelist",
                        type = "input",
                        get = function() return "" end,
                        set = function(_, v) 
                            if v and v ~= "" then 
                                self.db.profile.UserWhitelist[v] = true 
                                self:Print("Added to local whitelist: " .. v)
                            end 
                        end,
                        order = 1,
                    },
                    listHeader = {
                        name = "Currently in your Whitelist:",
                        type = "header",
                        order = 2,
                    },
                    listContent = {
                        type = "description",
                        name = function()
                            local list = ""
                            local count = 0
                            for k, _ in pairs(self.db.profile.UserWhitelist) do
                                local spellID = tonumber(k)
                                local spellInfo = spellID and C_Spell.GetSpellInfo(spellID) or C_Spell.GetSpellInfo(k)
                                if spellInfo then
                                    local icon = spellInfo.iconID or 134400
                                    list = list .. string.format("|T%d:18:18:0:0|t %s (|cff00ffff%d|r)\n", icon, spellInfo.name, spellInfo.spellID)
                                else
                                    list = list .. "|cffff0000[?]|r " .. tostring(k) .. "\n"
                                end
                                count = count + 1
                            end
                            if count == 0 then return "\n|cff888888Empty|r" end
                            return "\n" .. list
                        end,
                        width = "full",
                        order = 3,
                    },
                    reportGroup = {
                        name = "Reporting Methods",
                        type = "group",
                        inline = true,
                        order = 4,
                        args = {
                            helpText = {
                                name = "\nYour contributions help keep the Master Whitelist accurate and updated for everyone. Thank you for your support!\n",
                                type = "description",
                                fontSize = "large",
                                order = 0,
                            },
                            github = {
                                name = "GitHub Issue",
                                desc = "Creates a pre-filled issue (requires account).",
                                type = "execute",
                                func = function()
                                    local spells = ""
                                    for k, _ in pairs(self.db.profile.UserWhitelist) do spells = spells .. "- " .. k .. "\n" end
                                    if spells == "" then return end
                                    local url = string.format("https://github.com/%s/%s/issues/new?title=%s&body=%s", 
                                        self.db.profile.GithubUser, self.db.profile.GithubRepo, URLEncode("Whitelist Report"), URLEncode(spells))
                                    StaticPopup_Show("ASCENSION_TOOLTIP_REPORT", "Copy and paste into your browser:", nil, url)
                                end,
                                order = 1,
                            },
                            curse = {
                                name = "CurseForge Comment",
                                desc = "Direct link to CurseForge comments page.",
                                type = "execute",
                                func = function()
                                    local url = self.db.profile.CurseForgeURL or ""
                                    StaticPopup_Show("ASCENSION_TOOLTIP_REPORT", "Go here and paste your Raw Data:", nil, url)
                                end,
                                order = 2,
                            },
                            raw = {
                                name = "Raw Data",
                                desc = "Copy a simple string for Discord or Forums.",
                                type = "execute",
                                func = function()
                                    local data = "AT_DATA:"
                                    for k, _ in pairs(self.db.profile.UserWhitelist) do data = data .. k .. "," end
                                    StaticPopup_Show("ASCENSION_TOOLTIP_REPORT", "Paste this in Discord or CurseForge:", nil, data)
                                end,
                                order = 3,
                            },
                        }
                    },
                    clear = {
                        name = "Clear My Whitelist",
                        type = "execute",
                        func = function() self.db.profile.UserWhitelist = {} end,
                        order = 5,
                    },
                }
            },
            blacklist = {
                name = "Blacklist Management",
                type = "group",
                inline = true,
                order = 4,
                args = {
                    addSpell = {
                        name = "Add Spell/Talent to Blacklist",
                        desc = "Hides information for this spell or talent even if it matches a description.",
                        type = "input",
                        get = function() return "" end,
                        set = function(_, v) 
                            if v and v ~= "" then 
                                self.db.profile.UserBlacklist[v] = true 
                                self:Print("Added to local blacklist: " .. v)
                            end 
                        end,
                        order = 1,
                    },
                    listHeader = {
                        name = "Currently in your Blacklist:",
                        type = "header",
                        order = 2,
                    },
                    listContent = {
                        type = "description",
                        name = function()
                            local list = ""
                            local count = 0
                            for k, _ in pairs(self.db.profile.UserBlacklist) do
                                local spellID = tonumber(k)
                                local spellInfo = spellID and C_Spell.GetSpellInfo(spellID) or C_Spell.GetSpellInfo(k)
                                if spellInfo then
                                    local icon = spellInfo.iconID or 134400
                                    list = list .. string.format("|T%d:18:18:0:0|t %s (|cffff6666%d|r)\n", icon, spellInfo.name, spellInfo.spellID)
                                else
                                    list = list .. "|cffff0000[?]|r " .. tostring(k) .. "\n"
                                end
                                count = count + 1
                            end
                            if count == 0 then return "\n|cff888888No blacklisted spells.|r" end
                            return "\n" .. list
                        end,
                        width = "full",
                        order = 3,
                    },
                    clear = {
                        name = "Clear My Blacklist",
                        type = "execute",
                        func = function() self.db.profile.UserBlacklist = {} end,
                        order = 4,
                    },
                }
            },
            reset = {
                name = "Reset Profile",
                type = "execute",
                confirm = true,
                desc = "Reset all settings for this profile to default.",
                func = function() self.db:ResetProfile() ReloadUI() end,
                order = 5,
            },
        }
    }
end

-- =========================================================================
-- EVENTS & CORE LOGIC
-- =========================================================================

function AscensionTooltip:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("AscensionTooltipDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, self:GetOptions())
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, "Ascension Tooltip")

    self:RegisterChatCommand("at", function() Settings.OpenToCategory(self.optionsFrame.name) end)
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
        AscensionTooltip:ApplyTooltipStyling(tooltip)
        return
    end

    if db.ShowOnModifier ~= "None" then
        local modifierMap = { Shift = IsShiftKeyDown, Alt = IsAltKeyDown, Ctrl = IsControlKeyDown, Cmd = IsMetaKeyDown }
        if not (modifierMap[db.ShowOnModifier] and modifierMap[db.ShowOnModifier]()) then
            AscensionTooltip:ApplyTooltipStyling(tooltip)
            return
        end
    end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then return end
    
    -- Check if the main spell being hovered is blacklisted
    if db.UserBlacklist[tostring(spellID)] or db.UserBlacklist[spellInfo.name] then
        AscensionTooltip:ApplyTooltipStyling(tooltip)
        return
    end

    local nameHex, descHex = RGBToHex(db.TalentNameColor.r, db.TalentNameColor.g, db.TalentNameColor.b), RGBToHex(db.TalentDescColor.r, db.TalentDescColor.g, db.TalentDescColor.b)
    local processedRun = {}

    for talentID, talent in pairs(talentCache) do
        -- Skip if this specific talent is blacklisted
        if not (db.UserBlacklist[tostring(talentID)] or db.UserBlacklist[talent.name]) then
            local isWhitelisted = masterWhitelist[spellID] and masterWhitelist[spellID][talentID]
            local isUserWhitelisted = db.UserWhitelist[tostring(spellID)] or db.UserWhitelist[spellInfo.name]
            
            local descMatch = talent.desc and (string.find(talent.desc, spellInfo.name, 1, true) or (replacedSpells[spellID] and string.find(talent.desc, C_Spell.GetSpellInfo(replacedSpells[spellID]).name, 1, true)))

            if (isWhitelisted or isUserWhitelisted or descMatch) then
                if not processedRun[talent.name] and not IsLineInTooltip(tooltip, talent.name) then
                    tooltip:AddLine(" ")
                    local safeDesc = string.gsub(talent.desc, "|r", "|r" .. descHex)
                    tooltip:AddLine(nameHex .. talent.name .. ":|r " .. descHex .. safeDesc .. "|r", 1, 1, 1, true)
                    processedRun[talent.name] = true
                end
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
        elseif data.type == Enum.TooltipDataType.Macro and data.lines[1].tooltipID then
            SearchTreeCached(data.lines[1].tooltipID, tooltip)
        end
    end)
end