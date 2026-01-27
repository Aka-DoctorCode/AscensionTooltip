-------------------------------------------------------------------------------
-- Project: AscensionTooltip
-- Author: Aka-DoctorCode 
-- File: Config.lua
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

-- Constants for Reporting
local GITHUB_USER = "AkaDoctorCode"
local GITHUB_REPO = "AscensionTooltip"
local CURSEFORGE_URL = "https://www.curseforge.com/wow/addons/ascension-tooltip"

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
            self.EditBox:SetFocus()
            self.EditBox:SetText(data or "")
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
AscensionTooltip.defaults = {
    profile = {
        TooltipWidth = 350,
        FontSize = 12,
        ClampToScreen = true,
        HideInCombat = false,
        MaxHeight = 500,
        TooltipOpacity = 90,
        ShowOnModifier = "None",
        DisableExtraInfo = false,
        TalentNameColor = { r = 0.2, g = 1.0, b = 1.0, a = 1.0 },    -- Cyan
        TalentDescColor = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }, -- Yellow
        BackgroundColor = { r = 0.00, g = 0.00, b = 0.00 }, -- Black
        BorderColor = { r = 0.8, g = 0.8, b = 0.8, a = 0.0 }, -- Grey
        UserWhitelist = {},
        UserBlacklist = {},
        AnchorPoint = "ANCHOR_CURSOR",
        AnchorOffsetX = 0,
        AnchorOffsetY = 0,
        ShowTalentIcons = true,
        IconSize = 30,
    }
}

-- =========================================================================
-- OPTIONS MENU (AceConfig)
-- =========================================================================

function AscensionTooltip:GetOptions()
    local options = {
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
                        type = "range",
                        min = 200,
                        max = 1000,
                        step = 10,
                        get = function() return self.db.profile.TooltipWidth end,
                        set = function(_, v) self.db.profile.TooltipWidth = v end,
                        order = 1,
                    },
                    maxHeight = {
                        name = "Height",
                        desc = "The tooltip will grow wider if it exceeds this height.",
                        type = "range",
                        min = 100,
                        max = 1500,
                        step = 10,
                        get = function() return self.db.profile.MaxHeight end,
                        set = function(_, v) self.db.profile.MaxHeight = v end,
                        order = 2,
                    },
                    fontSize = {
                        name = "Font Size",
                        type = "range",
                        min = 8,
                        max = 24,
                        step = 1,
                        get = function() return self.db.profile.FontSize end,
                        set = function(_, v) self.db.profile.FontSize = v end,
                        order = 3,
                    },
                    opacity = {
                        name = "Background Opacity %",
                        type = "range",
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function() return self.db.profile.TooltipOpacity end,
                        set = function(_, v) self.db.profile.TooltipOpacity = v end,
                        order = 4,
                    },
                    modifier = {
                        name = "Modifier Key",
                        type = "select",
                        values = { ["None"] = "None", ["Shift"] = "Shift", ["Alt"] = "Alt", ["Ctrl"] = "Ctrl", ["Cmd"] = "Cmd" },
                        get = function() return self.db.profile.ShowOnModifier end,
                        set = function(_, v) self.db.profile.ShowOnModifier = v end,
                        order = 5,
                    },
                    clampToScreen = {
                        name = "Clamp to Screen",
                        type = "toggle",
                        get = function() return self.db.profile.ClampToScreen end,
                        set = function(_, v) self.db.profile.ClampToScreen = v end,
                        order = 6,
                    },
                    anchorPoint = {
                        name = "Tooltip Anchor",
                        type = "select",
                        values = {
                            ["ANCHOR_CURSOR"] = "Cursor",
                            ["ANCHOR_TOP"] = "Top",
                            ["ANCHOR_BOTTOM"] = "Bottom",
                            ["ANCHOR_LEFT"] = "Left",
                            ["ANCHOR_RIGHT"] = "Right",
                            ["ANCHOR_TOPLEFT"] = "Top Left",
                            ["ANCHOR_TOPRIGHT"] = "Top Right",
                            ["ANCHOR_BOTTOMLEFT"] = "Bottom Left",
                            ["ANCHOR_BOTTOMRIGHT"] = "Bottom Right"
                        },
                        get = function() return self.db.profile.AnchorPoint end,
                        set = function(_, v) self.db.profile.AnchorPoint = v end,
                        order = 7,
                    },
                    showIcons = {
                        name = "Show Talent Icons",
                        type = "toggle",
                        get = function() return self.db.profile.ShowTalentIcons end,
                        set = function(_, v) self.db.profile.ShowTalentIcons = v end,
                        order = 9,
                    },
                    iconSize = {
                        name = "Icon Size",
                        type = "range",
                        min = 16,
                        max = 64,
                        step = 1,
                        get = function() return self.db.profile.IconSize end,
                        set = function(_, v) self.db.profile.IconSize = v end,
                        disabled = function() return not self.db.profile.ShowTalentIcons end,
                        order = 10,
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
                        type = "color",
                        hasAlpha = true,
                        get = function()
                            local c = self.db.profile.TalentNameColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a) self.db.profile.TalentNameColor = { r = r, g = g, b = b, a = a } end,
                        order = 1,
                    },
                    descColor = {
                        name = "Talent Description Color",
                        type = "color",
                        hasAlpha = true,
                        get = function()
                            local c = self.db.profile.TalentDescColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a) self.db.profile.TalentDescColor = { r = r, g = g, b = b, a = a } end,
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
                            -- FIX: Added explicit check if UserWhitelist is nil (though defaults should handle it)
                            if self.db.profile.UserWhitelist then
                                for k, _ in pairs(self.db.profile.UserWhitelist) do
                                    local spellID = tonumber(k)
                                    -- Check if SafeGetSpellInfo exists before calling
                                    local spellInfo = (self.SafeGetSpellInfo and (self:SafeGetSpellInfo(spellID) or self:SafeGetSpellInfo(k)))
                                    if spellInfo then
                                        local icon = spellInfo.iconID or 134400
                                        list = list ..
                                            string.format("|T%d:18:18:0:0|t %s (|cff00ffff%d|r)\n", icon, spellInfo.name,
                                                spellInfo.spellID)
                                    else
                                        list = list .. "|cffff0000[?]|r " .. tostring(k) .. "\n"
                                    end
                                    count = count + 1
                                end
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
                                name =
                                "\nYour contributions help keep the Master Whitelist accurate and updated for everyone. Thank you for your support!\n",
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
                                    if self.db.profile.UserWhitelist then
                                        for k, _ in pairs(self.db.profile.UserWhitelist) do
                                            spells = spells .. "- " .. k .. "\n"
                                        end
                                    end
                                    if spells == "" then return end
                                    
                                    -- FIX: Use constants instead of missing db profile keys
                                    local url = string.format("https://github.com/%s/%s/issues/new?title=%s&body=%s",
                                        GITHUB_USER, GITHUB_REPO,
                                        self:URLEncode("Whitelist Report"), self:URLEncode(spells))
                                    StaticPopup_Show("ASCENSION_TOOLTIP_REPORT", "Copy and paste into your browser:", nil,
                                        url)
                                end,
                                order = 1,
                            },
                            curse = {
                                name = "CurseForge Comment",
                                desc = "Direct link to CurseForge comments page.",
                                type = "execute",
                                func = function()
                                    -- FIX: Use constant
                                    local url = CURSEFORGE_URL
                                    StaticPopup_Show("ASCENSION_TOOLTIP_REPORT", "Go here and paste your Raw Data:", nil,
                                        url)
                                end,
                                order = 2,
                            },
                            raw = {
                                name = "Raw Data",
                                desc = "Copy a simple string for Discord or Forums.",
                                type = "execute",
                                func = function()
                                    local data = "AT_DATA:"
                                    if self.db.profile.UserWhitelist then
                                        for k, _ in pairs(self.db.profile.UserWhitelist) do data = data .. k .. "," end
                                    end
                                    StaticPopup_Show("ASCENSION_TOOLTIP_REPORT", "Paste this in Discord or CurseForge:",
                                        nil, data)
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
                            if self.db.profile.UserBlacklist then
                                for k, _ in pairs(self.db.profile.UserBlacklist) do
                                    local spellID = tonumber(k)
                                    local spellInfo = nil
                                    if AscensionTooltip.SafeGetSpellInfo then
                                        spellInfo = AscensionTooltip:SafeGetSpellInfo(spellID) or AscensionTooltip:SafeGetSpellInfo(k)
                                    end
                                    if spellInfo then
                                        local icon = spellInfo.iconID or 134400
                                        list = list ..
                                            string.format("|T%d:18:18:0:0|t %s (|cffff6666%d|r)\n", icon, spellInfo.name,
                                                spellInfo.spellID)
                                    else
                                        list = list .. "|cffff0000[?]|r " .. tostring(k) .. "\n"
                                    end
                                    count = count + 1
                                end
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
            recentSpells = {
                name = "Recent Spells",
                type = "group",
                inline = true,
                order = 5,
                args = {
                    showRecent = {
                        name = "Show Recent Spells",
                        type = "execute",
                        func = function()
                            self:Print("Recent spells:")
                            for i, entry in ipairs(self.recentSpells or {}) do
                                self:Print(string.format("%d. %s (ID: %d)", i, entry.name, entry.spellID))
                            end
                        end,
                        order = 1,
                    },
                    clearRecent = {
                        name = "Clear Recent Spells",
                        type = "execute",
                        func = function()
                            if self.recentSpells then
                                table.wipe(self.recentSpells)
                            end
                            self:Print("Recent spells cleared")
                        end,
                        order = 2,
                    },
                }
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
            reset = {
                name = "Reset Profile Settings",
                type = "execute",
                confirm = true,
                desc = "Reset all visual and data settings for this profile to default.",
                func = function()
                    self.db:ResetProfile()
                    ReloadUI()
                end,
                order = 7,
            },
        }
    }
    -- Ensure profiles group is consistent with the UI
    options.args.profiles.order = 6
    options.args.profiles.inline = true
    return options
end
