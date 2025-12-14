--[[ 
    AscensionTooltip
    Based on HarreksAdvancedTooltips
]]

local ADDON_NAME = "AscensionTooltip"

-- 1. CONFIGURATION
local DEFAULTS = {
    TooltipWidth = 350,
    FontSize = 12,
    ClampToScreen = true,
    HideInCombat = false,
    MaxHeightPercent = 70,
    TooltipOpacity = 90,
    -- Text Colors
    TalentNameColor = {r=0.2, g=1.0, b=1.0, a=1.0},
    TalentDescColor = {r=1.0, g=0.82, b=0.0, a=1.0},
    -- Background/Border Colors
    BackgroundColor = {r=0.05, g=0.05, b=0.05}, 
    BorderColor = {r=0.8, g=0.8, b=0.8, a=1.0}
}

local db

-- =========================================================================
-- DATA (Talents and Spells)
-- =========================================================================

local talentsMissingName = {
    [370960] = { [377082] = true },
}

local replacedSpells = {
    [431443] = 361469,
    [467307] = 107428,
    [157153] = 5394,
    [443454] = 378081,
    [200758] = 53,
    [388667] = 686,
}

local blacklistedTalents = {
    [124682] = { [116680] = true, [388491] = true },
    [115151] = { [116680] = true, [388491] = true },
    [116670] = { [116680] = true, [388491] = true },
    [107428] = { [116680] = true, [388491] = true },
    [191837] = { [116680] = true, [388491] = true },
    [322101] = { [116680] = true, [388491] = true },
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

local talentCache = {}

-- =========================================================================
-- MAIN LOGIC
-- =========================================================================

local function UpdateTalentCache()
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
                    local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if definitionInfo.spellID and IsPlayerSpell(definitionInfo.spellID) then
                        local talentSpellID = definitionInfo.spellID
                        if talentSpellID then
                            local talent = Spell:CreateFromSpellID(talentSpellID)
                            talent:ContinueOnSpellLoad(function()
                                talentCache[talentSpellID] = {
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

local function RGBToHex(r, g, b)
    r = r or 1.0
    g = g or 1.0
    b = b or 1.0
    return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
end

-- Apply Tooltip Styling
local function ApplyTooltipStyling(tooltip)
    if not tooltip or not db then return end

    -- 1. Clamp to Screen
    if db.ClampToScreen then
        tooltip:SetClampedToScreen(true)
    end

    -- 2. SOLID BACKGROUND LOGIC (To achieve 100% opacity)
    local bg = db.BackgroundColor
    local bd = db.BorderColor
    local alpha = (db.TooltipOpacity or 90) / 100

    -- Create our own solid texture if it doesn't exist
    if not tooltip.SolidBg then
        tooltip.SolidBg = tooltip:CreateTexture(nil, "BACKGROUND")
        -- Inset slightly to not cover the borders (adjust -4/4 if needed)
        tooltip.SolidBg:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 4, -4)
        tooltip.SolidBg:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -4, 4)
    end

    -- Apply color to our solid texture
    if bg then
        tooltip.SolidBg:SetColorTexture(bg.r, bg.g, bg.b, alpha)
        tooltip.SolidBg:Show()
    else
        tooltip.SolidBg:Hide()
    end

    -- Handle Default WoW Textures (NineSlice)
    if tooltip.NineSlice then
        -- Hide the default center texture (make it invisible) so it doesn't interfere
        tooltip.NineSlice:SetCenterColor(0, 0, 0, 0)
        
        -- Apply Border Color
        if bd then
            tooltip.NineSlice:SetBorderColor(bd.r, bd.g, bd.b, bd.a or 1.0)
        end
    else
        -- Fallback for legacy frames: Try to hide backdrop bg or tint it
        if bg and tooltip.SetBackdropColor then
            -- Make legacy background invisible too, relying on SolidBg
            tooltip:SetBackdropColor(0, 0, 0, 0)
        end
        if bd and tooltip.SetBackdropBorderColor then
            tooltip:SetBackdropBorderColor(bd.r, bd.g, bd.b, bd.a or 1.0)
        end
    end

    -- Get font to re-apply
    local fontName, fontHeight, fontFlags
    if GameTooltipTextLeft1 then
        fontName, fontHeight, fontFlags = GameTooltipTextLeft1:GetFont()
    end

    -- MAX HEIGHT LOGIC
    local maxPercent = db.MaxHeightPercent or 70
    local screenHeight = UIParent:GetHeight()
    local maxHeight = screenHeight * (maxPercent / 100)

    -- Helper to force layout updates
    local function ForceLayout(width)
        tooltip:SetMinimumWidth(width)
        for i = 1, tooltip:NumLines() do
            local left = _G[tooltip:GetName().."TextLeft"..i]
            local right = _G[tooltip:GetName().."TextRight"..i]
            
            if left then
                left:SetWidth(width - 25) -- Safe margin
                left:SetWordWrap(true)
                if db.FontSize and fontName then
                    left:SetFont(fontName, db.FontSize, fontFlags)
                end
            end
            if right and db.FontSize and fontName then
                right:SetFont(fontName, db.FontSize, fontFlags)
            end
        end
        tooltip:Show() -- Force recalculation
    end

    -- 3. Step 1: Apply user configured width
    local currentWidth = db.TooltipWidth or 350
    ForceLayout(currentWidth)

    -- 4. Step 2: Check max height overflow
    local currentHeight = tooltip:GetHeight()
    
    if currentHeight > maxHeight and currentHeight > 0 then
        local targetRatio = currentHeight / maxHeight
        local newWidth = currentWidth * targetRatio * 1.1
        
        local maxScreenWidth = UIParent:GetWidth() * 0.90
        if newWidth > maxScreenWidth then newWidth = maxScreenWidth end

        if newWidth > currentWidth then
            ForceLayout(newWidth)
        end
    end
end

local function SearchTreeCached(spellID, tooltip)
    if not db then return end
    
    if db.HideInCombat and InCombatLockdown() then
        ApplyTooltipStyling(tooltip)
        return
    end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then return end
    
    local spellName = spellInfo.name
    local extraSpellName = nil
    if replacedSpells[spellID] then
        local extraSpellInfo = C_Spell.GetSpellInfo(replacedSpells[spellID])
        if extraSpellInfo then
            extraSpellName = extraSpellInfo.name
        end
    end

    local nameHex = RGBToHex(db.TalentNameColor.r, db.TalentNameColor.g, db.TalentNameColor.b)

    for talentSpellID, talentInfo in pairs(talentCache) do
        local isNotBlacklisted = not (blacklistedTalents[spellID] and blacklistedTalents[spellID][talentSpellID])
        local isMissingName = talentsMissingName[spellID] and talentsMissingName[spellID][talentSpellID]
        
        local nameMatch = (talentInfo.name ~= spellName)
        local descMatch = false
        
        if talentInfo.desc then
            local foundInDesc = string.find(talentInfo.desc, spellName, 1, true)
            local foundExtra = extraSpellName and string.find(talentInfo.desc, extraSpellName, 1, true)
            descMatch = foundInDesc or foundExtra
        end

        if (isMissingName or (isNotBlacklisted and nameMatch and descMatch)) then
            local tooltipText = "\n" .. nameHex .. talentInfo.name .. ":|r " .. talentInfo.desc .. "\n"
            tooltip:AddLine(tooltipText, db.TalentDescColor.r, db.TalentDescColor.g, db.TalentDescColor.b, true)
        end
    end
    
    ApplyTooltipStyling(tooltip)
end

-- =========================================================================
-- OPTIONS MENU
-- =========================================================================

local OptionsPanel = CreateFrame("Frame", "AscensionTooltipOptions", UIParent)
OptionsPanel.name = "Ascension Tooltip"

local function CreateCheckbox(name, parent, labelText, dbKey)
    local check = CreateFrame("CheckButton", name, parent, "ChatConfigCheckButtonTemplate")
    _G[name .. "Text"]:SetText(labelText)
    check:SetScript("OnClick", function(self)
        db[dbKey] = self:GetChecked()
    end)
    check:HookScript("OnShow", function(self)
        if db then self:SetChecked(db[dbKey]) end
    end)
    return check
end

-- Slider with +/- Buttons
local function CreateSlider(name, parent, min, max, step, labelText, dbKey)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(180) 
    
    _G[name .. "Low"]:SetText(min)
    _G[name .. "High"]:SetText(max)
    _G[name .. "Text"]:SetText(labelText)
    
    local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -5)
    
    slider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value / step + 0.5) * step 
        valueText:SetText(string.format("%.0f", val))
        db[dbKey] = val
    end)
    slider:HookScript("OnShow", function(self)
        if db then
            self:SetValue(db[dbKey])
            valueText:SetText(string.format("%.0f", db[dbKey]))
        end
    end)

    -- Minus Button [-]
    local btnMinus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btnMinus:SetSize(20, 20)
    btnMinus:SetText("-")
    btnMinus:SetPoint("RIGHT", slider, "LEFT", -5, 0)
    btnMinus:SetScript("OnClick", function()
        local current = slider:GetValue()
        local newVal = current - step
        if newVal < min then newVal = min end
        slider:SetValue(newVal)
    end)

    -- Plus Button [+]
    local btnPlus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btnPlus:SetSize(20, 20)
    btnPlus:SetText("+")
    btnPlus:SetPoint("LEFT", slider, "RIGHT", 5, 0)
    btnPlus:SetScript("OnClick", function()
        local current = slider:GetValue()
        local newVal = current + step
        if newVal > max then newVal = max end
        slider:SetValue(newVal)
    end)

    return slider
end

local function CreateColorPicker(name, parent, labelText, dbKey, useOpacity)
    local frame = CreateFrame("Button", name, parent)
    frame:SetSize(20, 20)
    local swatch = frame:CreateTexture(nil, "OVERLAY")
    swatch:SetAllPoints()
    swatch:SetColorTexture(1, 1, 1)
    frame.swatch = swatch
    
    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", frame, "RIGHT", 10, 0)
    label:SetText(labelText)
    
    frame:SetScript("OnClick", function()
        local colorData = db[dbKey]
        local r, g, b, a = colorData.r, colorData.g, colorData.b, colorData.a
        
        local info = {
            r = r, g = g, b = b, opacity = a,
            hasOpacity = useOpacity,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = 1.0
                if useOpacity then
                    na = ColorPickerFrame:GetColorAlpha() or 1.0
                else
                    na = a
                end
                
                db[dbKey].r, db[dbKey].g, db[dbKey].b, db[dbKey].a = nr, ng, nb, na
                swatch:SetColorTexture(nr, ng, nb, na)
            end,
            opacityFunc = function()
                 if not useOpacity then return end
                 local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                 local na = ColorPickerFrame:GetColorAlpha() or 1.0
                 db[dbKey].r, db[dbKey].g, db[dbKey].b, db[dbKey].a = nr, ng, nb, na
                 swatch:SetColorTexture(nr, ng, nb, na)
            end,
            cancelFunc = function()
                db[dbKey].r, db[dbKey].g, db[dbKey].b, db[dbKey].a = r, g, b, a
                swatch:SetColorTexture(r, g, b, a)
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    frame:HookScript("OnShow", function()
        if db then
            local t = db[dbKey]
            swatch:SetColorTexture(t.r, t.g, t.b, t.a or 1.0)
        end
    end)
    return frame
end

local function InitOptionsPanel()
    local title = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ascension Tooltip")

    local subText = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subText:SetText("Customize tooltip size and appearance.")

    -- 1. Tooltip Width
    local sliderWidth = CreateSlider("AT_SliderWidth", OptionsPanel, 200, 600, 10, "Tooltip Width", "TooltipWidth")
    sliderWidth:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 25, -30)

    -- 2. Max Height Percent
    local sliderHeight = CreateSlider("AT_SliderHeight", OptionsPanel, 30, 95, 5, "Max Screen Height %", "MaxHeightPercent")
    sliderHeight:SetPoint("TOPLEFT", sliderWidth, "BOTTOMLEFT", 0, -40)

    -- 3. Font Size
    local sliderFont = CreateSlider("AT_SliderFont", OptionsPanel, 8, 24, 1, "Font Size", "FontSize")
    sliderFont:SetPoint("TOPLEFT", sliderHeight, "BOTTOMLEFT", 0, -40)

    -- 4. Background Opacity
    local sliderOpacity = CreateSlider("AT_SliderOpacity", OptionsPanel, 0, 100, 5, "Background Opacity %", "TooltipOpacity")
    sliderOpacity:SetPoint("TOPLEFT", sliderFont, "BOTTOMLEFT", 0, -40)

    local chkCombat = CreateCheckbox("AT_ChkCombat", OptionsPanel, "Hide Extra Info in Combat", "HideInCombat")
    chkClamp:SetPoint("TOPLEFT", sliderOpacity, "BOTTOMLEFT", -25, -20)
    
    -- TEXT COLORS
    local cpNameColor = CreateColorPicker("AT_ColorName", OptionsPanel, "Talent Name Color", "TalentNameColor", true)
    cpNameColor:SetPoint("TOPLEFT", chkCombat, "BOTTOMLEFT", 0, -30)

    local cpDescColor = CreateColorPicker("AT_ColorDesc", OptionsPanel, "Talent Description Color", "TalentDescColor", true)
    cpDescColor:SetPoint("TOPLEFT", cpNameColor, "BOTTOMLEFT", 0, -15)
    
    -- BACKGROUND COLORS
    local cpBgColor = CreateColorPicker("AT_ColorBg", OptionsPanel, "Tooltip Background Color", "BackgroundColor", false)
    cpBgColor:SetPoint("TOPLEFT", cpDescColor, "BOTTOMLEFT", 0, -30)

    local cpBdColor = CreateColorPicker("AT_ColorBd", OptionsPanel, "Tooltip Border Color", "BorderColor", true)
    cpBdColor:SetPoint("TOPLEFT", cpBgColor, "BOTTOMLEFT", 0, -15)

    local btnReset = CreateFrame("Button", "AT_BtnReset", OptionsPanel, "UIPanelButtonTemplate")
    btnReset:SetSize(120, 22)
    btnReset:SetText("Reset Defaults")
    btnReset:SetPoint("TOPLEFT", cpBdColor, "BOTTOMLEFT", 0, -40)
    btnReset:SetScript("OnClick", function()
        AscensionTooltipDB = CopyTable(DEFAULTS)
        db = AscensionTooltipDB
        ReloadUI()
    end)
end

-- Registration Logic: Priorities Settings (Modern) > Legacy to avoid duplicates
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(OptionsPanel, "Ascension Tooltip")
    Settings.RegisterAddOnCategory(category)
else
    InterfaceOptions_AddOnCategory(OptionsPanel)
end

InitOptionsPanel()

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if not AscensionTooltipDB then 
            AscensionTooltipDB = CopyTable(DEFAULTS) 
        end
        db = AscensionTooltipDB
        
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then 
                if type(v) == "table" then 
                    db[k] = CopyTable(v) 
                else 
                    db[k] = v 
                end
            end
        end
        
        C_Timer.After(1, UpdateTalentCache)
        
    elseif event == "TRAIT_CONFIG_UPDATED" then
        C_Timer.After(1, UpdateTalentCache)
    end
end)

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if not data or not data.type then return end
        
        if data.type == Enum.TooltipDataType.Spell and IsSpellKnownOrOverridesKnown(data.id) then
            SearchTreeCached(data.id, tooltip)
        elseif data.type == Enum.TooltipDataType.Macro and data.lines[1].tooltipID and IsSpellKnownOrOverridesKnown(data.lines[1].tooltipID) then
            SearchTreeCached(data.lines[1].tooltipID, tooltip)
        else
            ApplyTooltipStyling(tooltip) 
        end
    end)
end