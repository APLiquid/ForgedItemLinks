local colorItemLinkPattern = "|c%x%x%x%x%x%x%x%x|Hitem:%d+:[^|]+|h%[[^%]]+%]|h"
local itemLinkPattern = "|Hitem:%d+:[^|]+|h%[[^%]]+%]|h"
local FORGE_LEVEL_MAP = {
    BASE         = 0,
    TITANFORGED  = 1,
    WARFORGED    = 2,
    LIGHTFORGED  = 3,
}
local TEXT_COLOR_MAP = {
    MYTHIC       = "|cfff59fd6",
    TITANFORGED  = "|cff8080FF",
    WARFORGED    = "|cffFF9670",
    LIGHTFORGED  = "|cffFFFFA6",
}
local positionOptions = {"After", "Before", "Prefix", "Sufix", "Disable"}
local ITEM_SAMPLE_MAP = {
	M   = "|Hitem:61340:0:0:0:0:0:0:0:80|h[Embroidered Cape of Mysteries]|h",
	LF  = "|Hitem:9149:0:0:0:0:0:0:12288:80|h[Philosopher's Stone]|h",
	MTF = "|Hitem:61395:0:0:0:0:0:0:4096:80|h[Greathelm of the Unbreakable]|h",
	W   = "|Hitem:15428:0:0:0:0:0:787:8192:80|h[Peerless Belt of the Owl]|h",
	R   = "|Hitem:44188:0:0:0:0:0:0:0:80|h[Cloak of Peaceful Resolutions]|h",
}

-- Saved variables setup in ADDON_LOADED
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "ForgedItemLinks" then
        -- Initialize saved variables - preserve existing values
        FILDB = FILDB or {}
        
        -- Only set defaults if the key doesn't exist or is nil
        if FILDB["mythicText"] == nil then FILDB["mythicText"] = "M" end
        if FILDB["mythicPos"] == nil then FILDB["mythicPos"] = "After" end
        if FILDB["forgePos"] == nil then FILDB["forgePos"] = "After" end
        if FILDB["titanforgedText"] == nil then FILDB["titanforgedText"] = "TF" end
        if FILDB["warforgedText"] == nil then FILDB["warforgedText"] = "WF" end
        if FILDB["lightforgedText"] == nil then FILDB["lightforgedText"] = "LF" end
        
        CreateSettingsPanel()
		
		print("|cff33ff99[Forged Item Links]|r: Loaded.")
    end
end)



function GetForgeLevelFromLink(itemLink)
    if not itemLink then return FORGE_LEVEL_MAP.BASE end
    local forgeValue = GetItemLinkTitanforge(itemLink)
        -- Validate against known values
    for _, v in pairs(FORGE_LEVEL_MAP) do
        if forgeValue == v then return forgeValue end
    end
    return FORGE_LEVEL_MAP.BASE
end

local function GetItemColorFromLink(itemLink)
    -- Try to extract color from existing colored link first
    local colorCode = itemLink:match("^(|c%x%x%x%x%x%x%x%x)")
    if colorCode then
		--print("color found in link")
        return colorCode
    end
    
    -- If no color found, extract item ID and get it from GetItemInfo
    local itemID = tonumber(itemLink:match("|Hitem:(%d+):"))
    if itemID then
        local itemName, fullItemLink, itemRarity = GetItemInfo(itemID)
        if fullItemLink then
            -- Extract color from the full colored link
            colorCode = fullItemLink:match("^(|c%x%x%x%x%x%x%x%x)")
            if colorCode then
			    --print("color found in secondary link")
                return colorCode
            end
        end
        
        -- Fallback: use rarity to determine color
        if itemRarity then
            local rarityColors = {
                [0] = "|cff9d9d9d", -- Poor (Gray)
                [1] = "|cffffffff", -- Common (White)
                [2] = "|cff1eff00", -- Uncommon (Green)
                [3] = "|cff0070dd", -- Rare (Blue)
                [4] = "|cffa335ee", -- Epic (Purple)
                [5] = "|cffff8000", -- Legendary (Orange)
                [6] = "|cffe6cc80", -- Artifact (Light Orange)
                [7] = "|cff00ccff", -- Heirloom (Light Blue)
            }
			--print("color asigned by rarity")
            return rarityColors[itemRarity] or "|cffffffff"
        end
    end
    
    -- Ultimate fallback - white
	--print("color not found")
    return "|cffffffff"
end

local function BuildNewLink(link, itemColor, tagColor, tag, position)
	local pre, core, sufx = link:match("^(.-)%[([^%]]+)%](.*)$")
    local actions = {
        After   = pre .. "[" .. core .. "]" .. sufx .. tagColor .. "[" .. tag .. "]|r",
        Before  = tagColor .. "[" .. tag .. "]" .. itemColor .. pre .. "[" .. core .. "]" .. sufx,
        Prefix  = pre .. "[" .. tagColor .. tag .. " " .. itemColor .. core .. "]" .. sufx,
        Sufix   = pre .. "[" .. core .. " " .. tagColor .. tag .. itemColor .. "]" .. sufx,
        Disable = link
    }
    return actions[position] or actions.After
end

local function ProcessItemLink(link, foundColoredLinks)
  --local itemID = CustomExtractItemId(link)
  local itemID = tonumber(link:match("|Hitem:(%d+):"))
  local color = GetItemColorFromLink(link)
  local newlink = link
  if not foundColoredLinks then newlink = color .. newlink end
  FILDB["LastLink"] = newlink
  
  -- Check if mythic
  local itemTags1, itemTags2 = GetItemTagsCustom(itemID)
  local isMythic = bit.band(itemTags1 or 0, 0x80) ~= 0
  local forgeLevel = GetForgeLevelFromLink and GetForgeLevelFromLink(link) or 0
  
  if isMythic then
	newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.MYTHIC, FILDB.mythicText, FILDB["mythicPos"])
  end
  
  -- Check Forge info
  if forgeLevel == (FORGE_LEVEL_MAP and FORGE_LEVEL_MAP.TITANFORGED or 1) then
	newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.TITANFORGED, FILDB.titanforgedText, FILDB["forgePos"])
  elseif forgeLevel == (FORGE_LEVEL_MAP and FORGE_LEVEL_MAP.WARFORGED or 2) then
    newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.WARFORGED, FILDB.warforgedText, FILDB["forgePos"])
  elseif forgeLevel == (FORGE_LEVEL_MAP and FORGE_LEVEL_MAP.LIGHTFORGED or 3) then
    newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.LIGHTFORGED, FILDB.lightforgedText, FILDB["forgePos"])
  end
  
  return newlink
end

local function AddTags(msg)
  -- First try to match colored item links
  local foundColoredLinks = false
  local newMsg = msg:gsub(colorItemLinkPattern, function(link)
    foundColoredLinks = true
    return ProcessItemLink(link, true)  -- Pass true for foundColoredLinks
  end)
  
  -- If no colored links were found, try the regular itemLinkPattern
  if not foundColoredLinks then
    newMsg = newMsg:gsub(itemLinkPattern, function(link)
      return ProcessItemLink(link, false)  -- Pass false for foundColoredLinks
    end)
  end
  
  return newMsg
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

-- Settings Panel Creation
local settingsPanel

function CreateSettingsPanel()
    -- Create main panel
    settingsPanel = CreateFrame("Frame", "ForgedItemLinksSettingsPanel", UIParent)
    settingsPanel.name = "ForgedItemLinks"
    settingsPanel:Hide()
	
	-- Change tracking variables
    local hasChanges = false
    local firstOpen = true
    -- Function to mark that changes have been made
    local function MarkChanged()
        if not firstOpen then hasChanges = true end
    end
    
    -- Panel background
    settingsPanel:SetSize(600, 400)
    settingsPanel:SetPoint("CENTER")
    
    -- Title
    local title = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Forged Item Links Settings")
	
	-- Info note
    local infoNote = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    infoNote:SetPoint("TOPLEFT", 16, -35)
    infoNote:SetText("|cffFFFF00Note: Using /reload will revert these settings to what they were on login!|r")
    
    -- Text Fields Section
    local textFieldsLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    textFieldsLabel:SetPoint("TOPLEFT", 20, -60)
    textFieldsLabel:SetText("Text Settings")
	
	-- Mythic Text
    local mythicLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    mythicLabel:SetPoint("TOPLEFT", 20, -85)
    mythicLabel:SetText("Mythic Tag:")
    
    local mythicEditBox = CreateFrame("EditBox", "FIL_MythicEditBox", settingsPanel, "InputBoxTemplate")
    mythicEditBox:SetSize(80, 20)
    mythicEditBox:SetPoint("TOPLEFT", 140, -80)
    mythicEditBox:SetText(FILDB["mythicText"] or "M")
    mythicEditBox:SetAutoFocus(false)
	mythicEditBox:SetScript("OnTextChanged", MarkChanged)
    
    -- Titanforged Text
    local titanforgedLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titanforgedLabel:SetPoint("TOPLEFT", 20, -105)
    titanforgedLabel:SetText("Titanforged Tag:")
    
    local titanforgedEditBox = CreateFrame("EditBox", "FIL_TitanforgedEditBox", settingsPanel, "InputBoxTemplate")
    titanforgedEditBox:SetSize(80, 20)
    titanforgedEditBox:SetPoint("TOPLEFT", 140, -100)
    titanforgedEditBox:SetText(FILDB["titanforgedText"] or "TF")
    titanforgedEditBox:SetAutoFocus(false)
	titanforgedEditBox:SetScript("OnTextChanged", MarkChanged)
    
    -- Warforged Text
    local warforgedLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    warforgedLabel:SetPoint("TOPLEFT", 20, -125)
    warforgedLabel:SetText("Warforged Tag:")
    
    local warforgedEditBox = CreateFrame("EditBox", "FIL_WarforgedEditBox", settingsPanel, "InputBoxTemplate")
    warforgedEditBox:SetSize(80, 20)
    warforgedEditBox:SetPoint("TOPLEFT", 140, -120)
    warforgedEditBox:SetText(FILDB["warforgedText"] or "WF")
    warforgedEditBox:SetAutoFocus(false)
	warforgedEditBox:SetScript("OnTextChanged", MarkChanged)
    
    -- Lightforged Text
    local lightforgedLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lightforgedLabel:SetPoint("TOPLEFT", 20, -145)
    lightforgedLabel:SetText("Lightforged Tag:")
    
    local lightforgedEditBox = CreateFrame("EditBox", "FIL_LightforgedEditBox", settingsPanel, "InputBoxTemplate")
    lightforgedEditBox:SetSize(80, 20)
    lightforgedEditBox:SetPoint("TOPLEFT", 140, -140)
    lightforgedEditBox:SetText(FILDB["lightforgedText"] or "LF")
	lightforgedEditBox:SetAutoFocus(false)
	lightforgedEditBox:SetScript("OnTextChanged", MarkChanged)
	
	--Position Settings
	local textFieldsLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    textFieldsLabel:SetPoint("TOPLEFT", 20, -185)
    textFieldsLabel:SetText("Tag Position")
	
    -- Mythic Position Dropdown
    local mythicPosLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    mythicPosLabel:SetPoint("TOPLEFT", 20, -210)
    mythicPosLabel:SetText("Mythic Position:")
    
    local mythicPosDropdown = CreateFrame("Frame", "FIL_MythicPosDropdown", settingsPanel, "UIDropDownMenuTemplate")
    mythicPosDropdown:SetPoint("TOPLEFT", mythicPosLabel, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(mythicPosDropdown, 120)
    UIDropDownMenu_SetText(mythicPosDropdown, FILDB["mythicPos"] or "After")
    
    local function InitializeMythicPosDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        local options = positionOptions
        for _, option in ipairs(options) do
            info.text = option
            info.value = option
            info.func = function()
                FILDB["mythicPos"] = option
                UIDropDownMenu_SetText(mythicPosDropdown, option)
				hasChanges = true
            end
            info.checked = (FILDB["mythicPos"] == option)
            UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(mythicPosDropdown, InitializeMythicPosDropdown)
    
    -- Forge Position Dropdown
    local forgePosLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    forgePosLabel:SetPoint("TOPLEFT", 200, -210)
    forgePosLabel:SetText("Forge Position:")
    
    local forgePosDropdown = CreateFrame("Frame", "FIL_ForgePosDropdown", settingsPanel, "UIDropDownMenuTemplate")
    forgePosDropdown:SetPoint("TOPLEFT", forgePosLabel, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(forgePosDropdown, 120)
    UIDropDownMenu_SetText(forgePosDropdown, FILDB["forgePos"] or "After")
    
    local function InitializeForgePosDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        local options = positionOptions
        for _, option in ipairs(options) do
            info.text = option
            info.value = option
            info.func = function()
                FILDB["forgePos"] = option
                UIDropDownMenu_SetText(forgePosDropdown, option)
				hasChanges = true
            end
            info.checked = (FILDB["forgePos"] == option)
            UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(forgePosDropdown, InitializeForgePosDropdown)
    
    -- Reset Button
    local resetButton = CreateFrame("Button", "FIL_ResetButton", settingsPanel, "GameMenuButtonTemplate")
    resetButton:SetSize(120, 30)
    resetButton:SetPoint("TOPLEFT", 250, -135)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        FILDB["mythicPos"] = "After"
        FILDB["forgePos"] = "After"
		FILDB["mythicText"] = "M"
        FILDB["titanforgedText"] = "TF"
        FILDB["warforgedText"] = "WF"
        FILDB["lightforgedText"] = "LF"
        
        -- Update UI elements
        UIDropDownMenu_SetText(mythicPosDropdown, "After")
        UIDropDownMenu_SetText(forgePosDropdown, "After")
		mythicEditBox:SetText("M")
        titanforgedEditBox:SetText("TF")
        warforgedEditBox:SetText("WF")
        lightforgedEditBox:SetText("LF")
        hasChanges = true
        print("|cff33ff99[Forged Item Links]|r: Settings reset to defaults!")
    end)
	
	-- Auto-save when panel is hidden/closed
    settingsPanel:SetScript("OnHide", function()
		firstOpen = false
        if hasChanges and hasChanges == true then
            -- Save all text field values
            FILDB["mythicText"] = mythicEditBox:GetText()
            FILDB["titanforgedText"] = titanforgedEditBox:GetText()
            FILDB["warforgedText"] = warforgedEditBox:GetText()
            FILDB["lightforgedText"] = lightforgedEditBox:GetText()
            hasChanges = false  -- Reset change flag
            print("|cff33ff99[Forged Item Links]|r: Settings saved, printing samples:")
			print("Myhtic: " .. AddTags(ITEM_SAMPLE_MAP.M))
			print("Lightforged: ".. AddTags(ITEM_SAMPLE_MAP.LF))
			print("Mythic TitanForged: ".. AddTags(ITEM_SAMPLE_MAP.MTF))
			print("Warforged: ".. AddTags(ITEM_SAMPLE_MAP.W))
			print("Regular: ".. AddTags(ITEM_SAMPLE_MAP.R))
        end
    end)
	
	-- Reset change flag when panel is shown (in case user opens/closes without changes)
    settingsPanel:SetScript("OnShow", function()
        hasChanges = false
    end)
	
    -- Add to Blizzard Interface Options (WotLK method)
    InterfaceOptions_AddCategory(settingsPanel)
	
end

-- Slash command to open settings
SLASH_FORGEDITEMLINKS1 = "/fil"
SLASH_FORGEDITEMLINKS2 = "/forgeditemlinks"
SlashCmdList["FORGEDITEMLINKS"] = function(msg)
    if settingsPanel then
        InterfaceOptionsFrame_OpenToCategory(settingsPanel)
    else
        print("Forged Item Links: Settings panel not yet loaded.")
    end
end


