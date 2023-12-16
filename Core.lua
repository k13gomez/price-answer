assert(Auctionator, "Auctionator is missing, please enable", 2)
local addon_folder = ... -- pt is not used

-- upvalue globals
local LibStub = LibStub
local Auctionator = Auctionator
local pairs = pairs

-- addon creation
local PriceAnswer = LibStub("AceAddon-3.0"):NewAddon(addon_folder, "AceConsole-3.0", "AceEvent-3.0", "LibAboutPanel-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_folder)
local Dialog = LibStub("AceConfigDialog-3.0")

-- defaults for options
local defaults = {
    profile = {
        enableAddOn = true,
        disableInCombat = true,
        formatLargeNumbers = true,
        issueInstructions = true,
        trigger = "price",
        replyChannel = {
            ["*"] = "WHISPER"
        },
        tsmSources = {
            ["*"] = true
        },
        watchedChatChannels = {
            ["*"] = true
        }
    }
}

-- handle user options
local db -- used for shorthand and for resetting the options to defaults

-- local variables
local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC -- not Wrath or retail
local isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE -- not any "classic" version of the game
local events = {
    ["CHAT_MSG_CHANNEL"]                = GLOBAL_CHANNELS,
    ["CHAT_MSG_SAY"]                    = CHAT_MSG_SAY,
    ["CHAT_MSG_YELL"]                   = CHAT_MSG_YELL,
    ["CHAT_MSG_GUILD"]                  = CHAT_MSG_GUILD,
    ["CHAT_MSG_OFFICER"]                = CHAT_MSG_OFFICER,
    ["CHAT_MSG_PARTY"]                  = CHAT_MSG_PARTY,
    ["CHAT_MSG_RAID"]                   = CHAT_MSG_RAID,
    ["CHAT_MSG_WHISPER"]                = CHAT_MSG_WHISPER,
    ["CHAT_MSG_BN_WHISPER"]             = CHAT_MSG_BN_WHISPER,
    ["CHAT_MSG_RAID_WARNING"]           = CHAT_MSG_RAID_WARNING,
}
if isMainline then
    events["CHAT_MSG_COMMUNITIES_CHANNEL"]    = CLUB_FINDER_COMMUNITIES
    events["CHAT_MSG_INSTANCE_CHAT"]          = CHAT_MSG_INSTANCE_CHAT
end

-- main Ace3 Functions
function PriceAnswer:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("PriceAnswerDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    db = self.db.profile

    -- set enabled/disabled state as per user prefs
    self:SetEnabledState(db.enableAddOn)

    local options = self:GetOptions()

    -- create Profiles within the options
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    options.args.profiles.order = 0

    -- LibAboutPanel-2.0 support
    options.args.aboutTable = self:AboutOptionsTable(addon_folder)
    options.args.aboutTable.order = -1

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addon_folder, options)

    -- register options with WoW's Interface\AddOns\ UI
    Dialog:AddToBlizOptions(addon_folder, L["Price Answer"])

    -- standalone GUI widget is too short, resize (default width: 700, height: 500)
    -- Dialog:SetDefaultSize(addon_folder, 700, 650)

    -- create and register slash command
    self:RegisterChatCommand("priceanswer", "ChatCommand")
    self:RegisterChatCommand("prans", "ChatCommand")
end

function PriceAnswer:OnEnable()
    for event in pairs(events) do
        if db.watchedChatChannels[event] then
            self:RegisterEvent(event)
        else
            self:UnregisterEvent(event)
        end
    end
end

function PriceAnswer:OnDisable()
    for event in pairs(events) do
        self:UnregisterEvent(event)
    end
end

-- reset the SV database
function PriceAnswer:RefreshConfig()
    db = self.db.profile
end

-- handle slash commands
function PriceAnswer:ChatCommand(input)
    if Dialog.OpenFrames[addon_folder] then
        Dialog:Close(addon_folder)
    else
        Dialog:Open(addon_folder)
    end
end

-- secure hook CHAT_MSG_WHISPER for testing purposes when the user sends themself a message
local PriceAnswerSentMessages = {}
hooksecurefunc("SendChatMessage", function(message, _, _, _, _, _, _, mine)
    if mine then
        PriceAnswerSentMessages[message] = 1
    end
end)

-- chat messages event handlers
function PriceAnswer:CHAT_MSG_CHANNEL(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, "WHISPER", nil, senderName)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageOne, "WHISPER", nil, senderName)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_SAY(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.sayChannel, nil, db.replyChannel.sayChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.sayChannel, nil, db.replyChannel.sayChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_YELL(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.yellChannel, nil, db.replyChannel.yellChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.yellChannel, nil, db.replyChannel.yellChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_GUILD(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.guildChannel, nil, db.replyChannel.guildChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.guildChannel, nil, db.replyChannel.guildChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_OFFICER(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.officerChannel, nil, db.replyChannel.officerChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.officerChannel, nil, db.replyChannel.officerChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_PARTY(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.partyChannel, nil, db.replyChannel.partyChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.partyChannel, nil, db.replyChannel.partyChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_INSTANCE_CHAT(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.instanceChannel, nil, db.replyChannel.instanceChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.instanceChannel, nil, db.replyChannel.instanceChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_COMMUNITIES_CHANNEL(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, "WHISPER", nil, senderName)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, "WHISPER", nil, senderName)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_RAID(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.raidChannel, nil, db.replyChannel.raidChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.raidChannel, nil, db.replyChannel.raidChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_RAID_WARNING(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.raidWarningChannel, nil, db.replyChannel.raidWarningChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.raidWarningChannel, nil, db.replyChannel.raidWarningChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_WHISPER(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage, senderName = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    -- prevent the user from infinitely whispering him/herself when testing
    if PriceAnswerSentMessages[incomingMessage] then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, "WHISPER", nil, senderName, nil, nil, nil, true)
    end
    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, "WHISPER", nil, senderName, nil, nil, nil, true)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_BN_WHISPER(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end

    local incomingMessage = ...
    -- this escapes the ? character but ther other magic characters could also be escaped
    if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

    local bnSenderID = select(13, ...)

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        BNSendWhisper(bnSenderID, outgoingMessageOne)
    end

    if outgoingMessageTwo ~= "" then
        BNSendWhisper(bnSenderID, outgoingMessageTwo)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

-- no need to duplicate code for every event
function PriceAnswer:GetOutgoingMessage(incomingMessage)
    -- pattern for "trigger N item" incoming chat messages
    -- item can be an itemLink EX: ["|cff0070dd|Hitem:63470::::::::53:257::2:1:4198:2:28:1199:9:35:::::|h[Missing Diplomat's Pauldrons]|h|r"]
    -- or item can be an itemID EX: 63470
    -- or item can be an item name EX: Missing Diplomat's Pauldrons
    -- the quantity N is optional and defaults to 1 if not provided or is less than 1
    local pattern = "^(%d*)%s*(.*)$"
    local incomingMessageTrim = strtrim(strsub(incomingMessage, strlen(L[db.trigger])+1)," \r\n")
    local itemCount, tail = strmatch(incomingMessageTrim, pattern)

    itemCount = itemCount and itemCount:trim()
    tail = tail and tail:trim()

    -- get the itemID
    local itemID, retOK, ret1 -- use pcall() to validate GetItemInfoInstant()
    if not itemID then
        retOK, ret1 = pcall(GetItemInfoInstant, tail)
        if retOK then
            itemID = ret1
        else
            retOK, ret1 = pcall(GetItemInfoInstant, tonumber(tail))
            if retOK then
                itemID = ret1
            end
        end
    end

    -- the above did not get an itemID
    if not itemID then
        retOK, ret1 = pcall(GetItemInfoInstant, itemCount)
        if retOK then
            itemID = ret1
        else
            retOK, ret1 = pcall(GetItemInfoInstant, tonumber(itemCount))
            if retOK then
                itemID = ret1
            end
        end
    end -- at this point it does not matter if there is no itemID

    itemCount = tonumber(itemCount) or 1
    if not itemCount or itemCount < 1 then
        itemCount = 1
    end

    -- get values in copper coins
    local _, itemLink, _, _, _, _, _, _, _, _, vendorCopper = GetItemInfo(itemID)
    local auctionCopper = Auctionator.API.v1.GetAuctionPriceByItemID("PriceAnswer", itemID)
    if auctionCopper then
        auctionCopper = itemCount * auctionCopper
    end

    -- convert copper coins into human-readable strings "14g55s96c" or nil. must be >= 1c if it isn't nil
    -- local vendorString = self:ConvertToHumanReadable(vendorCopper)
    local auctionString = self:ConvertToHumanReadable(auctionCopper)

    -- build the outgoing message
    local outgoingMessageOne, outgoingMessageTwo = "", "Auction Price for " .. tostring(itemCount) .. " x " .. itemLink .. " = " .. auctionString

    -- trim dead spaces
    outgoingMessageOne = outgoingMessageOne:trim()
    outgoingMessageTwo = outgoingMessageTwo:trim()

    -- if the incoming syntax is wrong or the item has no price data, then reply with those instead of price information
    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        if db.issueInstructions then
            outgoingMessageOne = format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger])
            outgoingMessageTwo = L["Alternatively, the item has no price data"]
        end
    end

    return outgoingMessageOne, outgoingMessageTwo
end

function PriceAnswer:ConvertToHumanReadable(num_copper)
    local gold_string, silver_string, copper_string = "", "", ""
    local gold, silver, copper

    if num_copper and num_copper >= 1 then
        gold = floor(num_copper / 10000)
        silver = (num_copper / 100) % 100
        copper = num_copper % 100

        if gold >= 1 then
            if db.formatLargeNumbers then
                gold = FormatLargeNumber(gold)
                gold_string = format("%s" .. GOLD_AMOUNT_SYMBOL, gold)
            else
                gold_string = format("%d" .. GOLD_AMOUNT_SYMBOL, gold)
            end
        end
        if silver >= 1 then
            silver_string = format("%d" .. SILVER_AMOUNT_SYMBOL, silver)
        end
        if copper >= 1 then
            copper_string = format("%d" .. COPPER_AMOUNT_SYMBOL, copper)
        end

        return gold_string .. silver_string .. copper_string
    end
    return "-"
end
