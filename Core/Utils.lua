-------------------------------------------------------------------------------
-- Project: AscensionTooltip
-- Author: Aka-DoctorCode
-- File: Utils.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field

local addonName = ...

local AT = LibStub("AceAddon-3.0"):GetAddon(addonName) ---@type AT

-------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
-------------------------------------------------------------------------------

function AT:rgbToHex(r, g, b)
    -- Format: |cffRRGGBB
    return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255), math.floor((g or 1) * 255),
        math.floor((b or 1) * 255))
end

function AT:urlEncode(str)
    if not str then return nil end

    local encodedStr = string.gsub(str, "\n", "\r\n")
    encodedStr = string.gsub(encodedStr, "([^%w %-%_%.%~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
    encodedStr = string.gsub(encodedStr, " ", "+")

    return encodedStr
end

function AT:isLineInTooltip(tooltip, textPart)
    if InCombatLockdown() or not tooltip or not textPart or textPart == "" then return false end

    local regions = { tooltip:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region:IsObjectType("FontString") then
            local success, text = pcall(region.GetText, region)
            -- Only proceed if we got a regular string (not a tainted secret string)
            if success and text and type(text) == "string" then
                -- Guard against taint errors when searching the text
                local ok, pos = pcall(string.find, text, textPart, 1, true)
                if ok and pos then
                    return true
                end
            end
        end
    end

    return false
end

function AT:safeGetSpellInfo(spellID)
    if not spellID or not C_Spell then return nil end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if spellInfo then
        return spellInfo
    end

    return nil
end

--- Strips WoW UI color codes from a string to ensure accurate matching
function AT:stripColors(text)
    if not text then return nil end
    -- Removes |cffXXXXXX and |r tags
    local cleanText = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    cleanText = string.gsub(cleanText, "|r", "")
    return cleanText
end

function AT:enhancedDescMatch(talentDesc, spellName)
    if not talentDesc or not spellName then return false end

    -- Phase 3: Sanitize strings before matching (Cooltips implementation)
    local cleanDesc = self:stripColors(talentDesc) or talentDesc
    local cleanSpell = self:stripColors(spellName) or spellName

    local lowerDesc = string.lower(cleanDesc)
    local lowerSpell = string.lower(cleanSpell)

    if string.find(lowerDesc, lowerSpell, 1, true) then
        return true
    end

    local spellPattern = string.gsub(lowerSpell, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
    if string.find(lowerDesc, spellPattern) then
        return true
    end

    return false
end

function AT:getClassColor(className)
    if not className then return "ffffff" end -- #ffffff

    local color = RAID_CLASS_COLORS[className]
    if color then
        return color:GenerateHexColor()
    end

    return "ffffff" -- #ffffff
end

function AT:safeGetItemInfo(itemID)
    if not itemID then return nil end

    -- Using C_Item for modern API support
    local item = Item:CreateFromItemID(itemID)
    if not item:IsItemEmpty() then
        item:ContinueOnItemLoad(function()
            -- Callback logic for async data
        end)
    end

    return item
end
