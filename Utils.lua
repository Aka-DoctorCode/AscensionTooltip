local ADDON_NAME = "AscensionTooltip"
local AscensionTooltip = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

-- =========================================================================
-- UTILITY FUNCTIONS
-- =========================================================================

function AscensionTooltip:RGBToHex(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255), math.floor((g or 1) * 255),
        math.floor((b or 1) * 255))
end

function AscensionTooltip:URLEncode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

function AscensionTooltip:IsLineInTooltip(tooltip, textPart)
    if not textPart or textPart == "" then return false end
    local tooltipName = tooltip:GetName()
    if not tooltipName then return false end
    for i = 1, tooltip:NumLines() do
        local line = _G[tooltipName .. "TextLeft" .. i]
        local text = line and line:GetText()
        if text and string.find(text, textPart, 1, true) then return true end
    end
    return false
end

-- Safe wrapper for API calls
function AscensionTooltip:SafeGetSpellInfo(spellID)
    local success, info = pcall(C_Spell.GetSpellInfo, spellID)
    return success and info or nil
end

-- Enhanced spell matching with patterns
function AscensionTooltip:EnhancedDescMatch(talentDesc, spellName)
    if not talentDesc or not spellName then return false end

    -- Case-insensitive matching
    local lowerDesc = string.lower(talentDesc)
    local lowerSpell = string.lower(spellName)

    -- Check for exact name match
    if string.find(lowerDesc, lowerSpell, 1, true) then
        return true
    end

    -- Check for spell name with punctuation variations
    local spellPattern = string.gsub(lowerSpell, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
    if string.find(lowerDesc, spellPattern) then
        return true
    end

    return false
end

-- Dependency check
function AscensionTooltip:CheckDependencies()
    if not LibStub then
        print("|cffff0000AscensionTooltip requires Ace3 libraries|r")
        return false
    end
    return true
end
