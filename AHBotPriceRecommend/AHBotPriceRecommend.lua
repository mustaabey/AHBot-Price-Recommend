-- =========================================================================
-- mod-ah-bot.conf settings according to your configuration:
-- AuctionHouseBot.UseBuyPriceForBuyer = 1 -> USE_BUY_PRICE = true
-- AuctionHouseBot.UseBuyPriceForBuyer = 0 -> USE_BUY_PRICE = false
-- Configurable in-game: Interface > AddOns > AHBot Price Recommend
-- Saved in the AHBotPriceRecommendDB SavedVariable.
-- =========================================================================
local USE_BUY_PRICE = true
local SAFE_BID_PERCENT = 95

-- Settings panel (Interface Options > AddOns)
local panel = CreateFrame("Frame", "AHBotPriceRecommendOptionsPanel", UIParent)
panel.name = "AHBot Price Recommend"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("AHBot Price Recommend")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("Match these settings to your server's mod-ah-bot.conf.")

local useBuyPriceCheck = CreateFrame("CheckButton", "AHBotPriceRecommendUseBuyPriceCheck", panel, "InterfaceOptionsCheckButtonTemplate")
useBuyPriceCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -12)
_G[useBuyPriceCheck:GetName() .. "Text"]:SetText("Use vendor Buy Price (AuctionHouseBot.UseBuyPriceForBuyer = 1)")
useBuyPriceCheck.tooltipText = "Checked: base price is the item's vendor BuyPrice (SellPrice * 4 if unknown).\nUnchecked: base price is the item's vendor SellPrice."
useBuyPriceCheck:SetScript("OnClick", function(self)
    USE_BUY_PRICE = self:GetChecked() and true or false
    AHBotPriceRecommendDB.useBuyPrice = USE_BUY_PRICE
end)

local safeBidSlider = CreateFrame("Slider", "AHBotPriceRecommendSafeBidSlider", panel, "OptionsSliderTemplate")
safeBidSlider:SetPoint("TOPLEFT", useBuyPriceCheck, "BOTTOMLEFT", 4, -32)
safeBidSlider:SetMinMaxValues(1, 200)
safeBidSlider:SetValueStep(1)
if safeBidSlider.SetObeyStepOnDrag then safeBidSlider:SetObeyStepOnDrag(true) end
safeBidSlider:SetWidth(200)
_G[safeBidSlider:GetName() .. "Low"]:SetText("1%")
_G[safeBidSlider:GetName() .. "High"]:SetText("200%")
safeBidSlider.tooltipText = "Percentage of the calculated max bid to recommend as the safe bid/buyout price. Default 95%."

local function UpdateSafeBidSliderText()
    local color
    if SAFE_BID_PERCENT >= 100 then
        color = "|cffff2020"
    elseif SAFE_BID_PERCENT > 95 then
        color = "|cffffd700"
    else
        color = "|cff20ff20"
    end
    _G[safeBidSlider:GetName() .. "Text"]:SetText(color .. "Safe Bid Percent (" .. SAFE_BID_PERCENT .. "%)|r")
end
UpdateSafeBidSliderText()

safeBidSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    SAFE_BID_PERCENT = value
    AHBotPriceRecommendDB.safeBidPercent = SAFE_BID_PERCENT
    UpdateSafeBidSliderText()
end)

local resetDefaultsButton = CreateFrame("Button", "AHBotPriceRecommendResetDefaultsButton", panel, "UIPanelButtonTemplate")
resetDefaultsButton:SetPoint("TOPLEFT", safeBidSlider, "BOTTOMLEFT", -4, -24)
resetDefaultsButton:SetSize(140, 22)
resetDefaultsButton:SetText("Reset to Defaults")
resetDefaultsButton:SetScript("OnClick", function()
    USE_BUY_PRICE = true
    SAFE_BID_PERCENT = 95
    AHBotPriceRecommendDB.useBuyPrice = USE_BUY_PRICE
    AHBotPriceRecommendDB.safeBidPercent = SAFE_BID_PERCENT
    panel.refresh()
end)

panel.refresh = function()
    useBuyPriceCheck:SetChecked(USE_BUY_PRICE)
    safeBidSlider:SetValue(SAFE_BID_PERCENT)
    UpdateSafeBidSliderText()
end
panel:SetScript("OnShow", panel.refresh)

InterfaceOptions_AddCategory(panel)

-- Load saved settings
panel:RegisterEvent("ADDON_LOADED")
panel:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "AHBotPriceRecommend" then return end
    self:UnregisterEvent("ADDON_LOADED")

    AHBotPriceRecommendDB = AHBotPriceRecommendDB or {}
    if AHBotPriceRecommendDB.useBuyPrice == nil then
        AHBotPriceRecommendDB.useBuyPrice = true
    end
    USE_BUY_PRICE = AHBotPriceRecommendDB.useBuyPrice

    if AHBotPriceRecommendDB.safeBidPercent == nil then
        AHBotPriceRecommendDB.safeBidPercent = 95
    end
    SAFE_BID_PERCENT = AHBotPriceRecommendDB.safeBidPercent
end)

local function FormatMoney(copper)
    if not copper or copper <= 0 then return "0c" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100

    local str = ""
    if g > 0 then str = str .. string.format("|cffffd700%dg|r ", g) end
    if s > 0 or g > 0 then str = str .. string.format("|cffc7c7cf%ds|r ", s) end
    str = str .. string.format("|cffeda55f%dc|r", c)
    return str
end

local function AttachAHBotPriceRecommend(tooltip)
    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    local _, _, quality, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
    if not quality then return end

    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if not itemID then return end

    local basePrice = 0

    if USE_BUY_PRICE then
        -- 1: DB BuyPrice
        if AHBotPriceRecommend_BuyPrices and AHBotPriceRecommend_BuyPrices[itemID] then
            basePrice = AHBotPriceRecommend_BuyPrices[itemID]
        else
            basePrice = (itemSellPrice or 0) * 4
        end
    else
        basePrice = itemSellPrice or 0
    end

    if basePrice <= 0 then
        tooltip:AddLine("AHPriceRec: |cffff2020Unknown (Price 0)|r")
        tooltip:Show()
        return
    end

    -- mod-ah-bot C++ formula: price * (Quality + 2)
    local qualityMultiplier = quality + 2
    local singleMaxBid = basePrice * qualityMultiplier

    -- Stack size check in bag
    local count = 1
    local focus = GetMouseFocus()
    if focus and focus.count then
        count = focus.count
    end

    -- Calculate safe bid prices (SAFE_BID_PERCENT% of max bid)
    local safeBidRatio = SAFE_BID_PERCENT / 100
    local safeBidSingle = math.floor(singleMaxBid * safeBidRatio)
    local safeBidStack = math.floor(singleMaxBid * count * safeBidRatio)

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("|cff00ff00AHPriceRec Buyout:|r", FormatMoney(safeBidSingle))
    if count > 1 then
        tooltip:AddDoubleLine(string.format("|cff00ff00AHPriceRec Stack (%dx):|r", count), FormatMoney(safeBidStack))
    end
    tooltip:Show()
end

GameTooltip:HookScript("OnTooltipSetItem", AttachAHBotPriceRecommend)
ItemRefTooltip:HookScript("OnTooltipSetItem", AttachAHBotPriceRecommend)