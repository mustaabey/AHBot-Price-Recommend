-- =========================================================================
-- mod-ah-bot.conf settings according to your configuration:
-- AuctionHouseBot.UseBuyPriceForBuyer = 1 -> USE_BUY_PRICE = true
-- AuctionHouseBot.UseBuyPriceForBuyer = 0 -> USE_BUY_PRICE = false
-- =========================================================================
local USE_BUY_PRICE = true

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

    -- Calculate safe bid prices (95% of max bid)
    local safeBidSingle = math.floor(singleMaxBid * 0.95)
    local safeBidStack = math.floor(singleMaxBid * count * 0.95)

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("|cff00ff00AHPriceRec Buyout:|r", FormatMoney(safeBidSingle))
    if count > 1 then
        tooltip:AddDoubleLine(string.format("|cff00ff00AHPriceRec Stack (%dx):|r", count), FormatMoney(safeBidStack))
    end
    tooltip:Show()
end

GameTooltip:HookScript("OnTooltipSetItem", AttachAHBotPriceRecommend)
ItemRefTooltip:HookScript("OnTooltipSetItem", AttachAHBotPriceRecommend)