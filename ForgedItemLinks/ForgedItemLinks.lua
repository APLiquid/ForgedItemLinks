local itemLinkPattern = "|Hitem:%d+:[^|]+|h%[[^%]]+%]|h"
local FORGE_LEVEL_MAP = {
    BASE         = 0,
    TITANFORGED  = 1,
    WARFORGED    = 2,
    LIGHTFORGED  = 3,
}

function GetForgeLevelFromLink(itemLink)
    if not itemLink then return FORGE_LEVEL_MAP.BASE end
    local forgeValue = GetItemLinkTitanforge(itemLink)
        -- Validate against known values
    for _, v in pairs(FORGE_LEVEL_MAP) do
        if forgeValue == v then return forgeValue end
    end
    return FORGE_LEVEL_MAP.BASE
end

local function AddTags(msg)
  return msg:gsub(itemLinkPattern, function(link)
	local itemID = CustomExtractItemId(link)
	local newlink = link
    -- Check if mythic
	local itemTags1, itemTags2 = GetItemTagsCustom(itemID)
	local isMythic = bit.band(itemTags1 or 0, 0x80) ~= 0
	local forgeLevel = GetForgeLevelFromLink and GetForgeLevelFromLink(link) or 0
    if isMythic then
      newlink = newlink .. "|cfff59fd6[M]|r"
    end
	-- Check Forge info
    if forgeLevel == (FORGE_LEVEL_MAP and FORGE_LEVEL_MAP.WARFORGED or 2) then
	  newlink = newlink .. "|cffFF9670[WF]|r"
    elseif forgeLevel == (FORGE_LEVEL_MAP and FORGE_LEVEL_MAP.LIGHTFORGED or 3) then
      newlink = newlink .. "|cffFFFFA6[LF]|r"
    elseif forgeLevel == (FORGE_LEVEL_MAP and FORGE_LEVEL_MAP.TITANFORGED or 1) then
      newlink = newlink .. "|cff8080FF[TF]|r"
    end
    return newlink
  end)
end

-- This is where we modify the message before it's displayed
local function ChatFilter(self, event, msg, author, ...)
  local newMsg = AddTags(msg)
  return false, newMsg, author, ...
end

-- Add the filter to all common chat events
for _, event in pairs({
  "CHAT_MSG_SAY",
  "CHAT_MSG_YELL",
  "CHAT_MSG_GUILD",
  "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_RAID",
  "CHAT_MSG_RAID_LEADER",
  "CHAT_MSG_WHISPER",
  "CHAT_MSG_CHANNEL",
  "CHAT_MSG_BATTLEGROUND",
  "CHAT_MSG_BATTLEGROUND_LEADER",
}) do
  ChatFrame_AddMessageEventFilter(event, ChatFilter)
end




