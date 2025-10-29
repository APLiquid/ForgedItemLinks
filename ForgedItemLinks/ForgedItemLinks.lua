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
	DIVINE       = "|cfffdd016",
    TITANFORGED  = "|cff8080FF",
    WARFORGED    = "|cffFF9670",
    LIGHTFORGED  = "|cffFFFFA6",
    ATTUNED      = "|cff33FF33",
    ATTUNABLE    = "|cffFF69B4",
}
local DEFAULT_TAGS = {
    mythicText = "M",
    divineText = "D",
    titanforgedText = "TF",
    warforgedText = "WF",
    lightforgedText = "LF",
    attunedText = "Attuned",
    attunableText = "Attunable",
}
local positionOptions = {"After", "Before", "Prefix", "Sufix", "Disable"}
local ITEM_SAMPLE_MAP = {
	M   = "|Hitem:61340:0:0:0:0:0:0:0:80|h[Embroidered Cape of Mysteries]|h",
	D   = "|Hitem:22418:0:0:0:0:0:0:0:80|h[Dreadnaught Helmet]|h",
	LF  = "|Hitem:9149:0:0:0:0:0:0:12288:80|h[Philosopher's Stone]|h",
	MTF = "|Hitem:61395:0:0:0:0:0:0:4096:80|h[Greathelm of the Unbreakable]|h",
	W   = "|Hitem:15428:0:0:0:0:0:787:8192:80|h[Peerless Belt of the Owl]|h",
	R   = "|Hitem:44188:0:0:0:0:0:0:0:80|h[Cloak of Peaceful Resolutions]|h",
}

-- Helper function to get tag text with fallback to default
local function GetTagText(key)
    local value = FILDB[key]
    if value == nil or value == "" then
        return DEFAULT_TAGS[key] or ""
    end
    return value
end

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
		if FILDB["divineText"] == nil then FILDB["divineText"] = "D" end
        if FILDB["divinePos"] == nil then FILDB["divinePos"] = "After" end
        if FILDB["forgePos"] == nil then FILDB["forgePos"] = "After" end
        if FILDB["titanforgedText"] == nil then FILDB["titanforgedText"] = "TF" end
        if FILDB["warforgedText"] == nil then FILDB["warforgedText"] = "WF" end
        if FILDB["lightforgedText"] == nil then FILDB["lightforgedText"] = "LF" end
        if FILDB["attunedText"] == nil then FILDB["attunedText"] = "Attuned" end
        if FILDB["attunableText"] == nil then FILDB["attunableText"] = "Attunable" end
        if FILDB["attunedPos"] == nil then FILDB["attunedPos"] = "After" end
        if FILDB["attunablePos"] == nil then FILDB["attunablePos"] = "After" end
        
        CreateSettingsPanel()
		
		print("|cff33ff99[Forged Item Links]|r: Loaded.")
    end
end)

-- Safe wrapper for GetItemLinkTitanforge
function GetForgeLevelFromLink(itemLink)
    if not itemLink then return FORGE_LEVEL_MAP.BASE end
    
    -- Check if the function exists before calling it
    if not GetItemLinkTitanforge then
        return FORGE_LEVEL_MAP.BASE
    end
    
    -- Safely call the function with pcall to prevent errors
    local success, forgeValue = pcall(GetItemLinkTitanforge, itemLink)
    
    if not success then
        return FORGE_LEVEL_MAP.BASE
    end
    
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
  local itemID = tonumber(link:match("|Hitem:(%d+):"))
  local color = GetItemColorFromLink(link)
  local newlink = link
  if not foundColoredLinks then newlink = color .. newlink end
  FILDB["LastLink"] = newlink
  
  -- Attunement Check
  if _G.CanAttuneItemHelper and _G.GetItemLinkAttuneProgress then
      if CanAttuneItemHelper(itemID) == 1 then
          local progress = GetItemLinkAttuneProgress(link)
          if progress == 100 then
              newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.ATTUNED, GetTagText("attunedText"), FILDB["attunedPos"])
          elseif progress >= 0 and progress < 100 then
              newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.ATTUNABLE, GetTagText("attunableText"), FILDB["attunablePos"])
          end
      end
  end
  
  -- Check if mythic - with safe checking for GetItemTagsCustom
  local isMythic = false
  local isDivine = false
  if GetItemTagsCustom then
    local success, itemTags1, itemTags2 = pcall(GetItemTagsCustom, itemID)
    if success and itemTags1 then
      isDivine = (itemTags1 == 130)
      isMythic = bit.band(itemTags1, 0x80) ~= 0 and not isDivine
    end
  end
  
  local forgeLevel = GetForgeLevelFromLink(link) or 0
  
  if isDivine then
    newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.DIVINE, GetTagText("divineText"), FILDB["divinePos"])
  elseif isMythic then
    newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.MYTHIC, GetTagText("mythicText"), FILDB["mythicPos"])
  end
  
  -- Check Forge info
  if forgeLevel == (FORGE_LEVEL_MAP and FORGE_LEVEL_MAP.TITANFORGED or 1) then
	newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.TITANFORGED, GetTagText("titanforgedText"), FILDB["forgePos"])
  elseif forgeLevel == (FORGE_LEVEL_MAP and FORGE_LEVEL_MAP.WARFORGED or 2) then
    newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.WARFORGED, GetTagText("warforgedText"), FILDB["forgePos"])
  elseif forgeLevel == (FORGE_LEVEL_MAP and FORGE_LEVEL_MAP.LIGHTFORGED or 3) then
    newlink = BuildNewLink(newlink, color, TEXT_COLOR_MAP.LIGHTFORGED, GetTagText("lightforgedText"), FILDB["forgePos"])
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
  "CHAT_MSG_RAID",
  "CHAT_MSG_RAID_LEADER",
  "CHAT_MSG_WHISPER",
  "CHAT_MSG_WHISPER_INFORM",
  "CHAT_MSG_CHANNEL",
  "CHAT_MSG_OFFICER",
}) do
  ChatFrame_AddMessageEventFilter(event, ChatFilter)
end

-- Settings Panel Creation
function CreateSettingsPanel()
    local settingsPanel = CreateFrame("Frame", "ForgedItemLinksSettingsPanel", UIParent)
    settingsPanel.name = "Forged Item Links"
	
	local hasChanges = false
	local firstOpen = true
    
	local function MarkChanged()
		if not firstOpen then
			hasChanges = true
		end
	end
	
	--Title
	local title = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText("Forged Item Links Settings")
	
    -- Text Tags header
    local textTagsLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    textTagsLabel:SetPoint("TOPLEFT", 20, -40)
    textTagsLabel:SetText("Text Tags")
    
    -- Mythic Text
    local mythicLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    mythicLabel:SetPoint("TOPLEFT", 20, -65)
    mythicLabel:SetText("Mythic Tag:")
    
    local mythicEditBox = CreateFrame("EditBox", "FIL_MythicEditBox", settingsPanel, "InputBoxTemplate")
    mythicEditBox:SetSize(80, 20)
    mythicEditBox:SetPoint("TOPLEFT", 140, -60)
    mythicEditBox:SetText(FILDB["mythicText"] or "M")
    mythicEditBox:SetAutoFocus(false)
	mythicEditBox:SetScript("OnTextChanged", MarkChanged)
    
    -- Titanforged Text
    local titanforgedLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titanforgedLabel:SetPoint("TOPLEFT", 20, -85)
    titanforgedLabel:SetText("Titanforged Tag:")
    
    local titanforgedEditBox = CreateFrame("EditBox", "FIL_TitanforgedEditBox", settingsPanel, "InputBoxTemplate")
    titanforgedEditBox:SetSize(80, 20)
    titanforgedEditBox:SetPoint("TOPLEFT", 140, -80)
    titanforgedEditBox:SetText(FILDB["titanforgedText"] or "TF")
    titanforgedEditBox:SetAutoFocus(false)
	titanforgedEditBox:SetScript("OnTextChanged", MarkChanged)
    
    -- Warforged Text
    local warforgedLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    warforgedLabel:SetPoint("TOPLEFT", 20, -105)
    warforgedLabel:SetText("Warforged Tag:")
    
    local warforgedEditBox = CreateFrame("EditBox", "FIL_WarforgedEditBox", settingsPanel, "InputBoxTemplate")
    warforgedEditBox:SetSize(80, 20)
    warforgedEditBox:SetPoint("TOPLEFT", 140, -100)
    warforgedEditBox:SetText(FILDB["warforgedText"] or "WF")
    warforgedEditBox:SetAutoFocus(false)
	warforgedEditBox:SetScript("OnTextChanged", MarkChanged)
    
    -- Lightforged Text
    local lightforgedLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lightforgedLabel:SetPoint("TOPLEFT", 20, -125)
    lightforgedLabel:SetText("Lightforged Tag:")
    
    local lightforgedEditBox = CreateFrame("EditBox", "FIL_LightforgedEditBox", settingsPanel, "InputBoxTemplate")
    lightforgedEditBox:SetSize(80, 20)
    lightforgedEditBox:SetPoint("TOPLEFT", 140, -120)
    lightforgedEditBox:SetText(FILDB["lightforgedText"] or "LF")
	lightforgedEditBox:SetAutoFocus(false)
	lightforgedEditBox:SetScript("OnTextChanged", MarkChanged)
	
	-- Divine Text
    local divineLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    divineLabel:SetPoint("TOPLEFT", 20, -145)
    divineLabel:SetText("Divine Tag:")
    
    local divineEditBox = CreateFrame("EditBox", "FIL_DivineEditBox", settingsPanel, "InputBoxTemplate")
    divineEditBox:SetSize(80, 20)
    divineEditBox:SetPoint("TOPLEFT", 140, -140)
    divineEditBox:SetText(FILDB["divineText"] or "D")
	divineEditBox:SetAutoFocus(false)
	divineEditBox:SetScript("OnTextChanged", MarkChanged)
	
	-- Attuned Text
    local attunedLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    attunedLabel:SetPoint("TOPLEFT", 20, -165)
    attunedLabel:SetText("Attuned Tag:")
    
    local attunedEditBox = CreateFrame("EditBox", "FIL_AttunedEditBox", settingsPanel, "InputBoxTemplate")
    attunedEditBox:SetSize(80, 20)
    attunedEditBox:SetPoint("TOPLEFT", 140, -160)
    attunedEditBox:SetText(FILDB["attunedText"] or "Attuned")
    attunedEditBox:SetAutoFocus(false)
	attunedEditBox:SetScript("OnTextChanged", MarkChanged)
    
    -- Attunable Text
    local attunableLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    attunableLabel:SetPoint("TOPLEFT", 20, -185)
    attunableLabel:SetText("Attunable Tag:")
    
    local attunableEditBox = CreateFrame("EditBox", "FIL_AttunableEditBox", settingsPanel, "InputBoxTemplate")
    attunableEditBox:SetSize(80, 20)
    attunableEditBox:SetPoint("TOPLEFT", 140, -180)
    attunableEditBox:SetText(FILDB["attunableText"] or "Attunable")
    attunableEditBox:SetAutoFocus(false)
	attunableEditBox:SetScript("OnTextChanged", MarkChanged)
	
	--Position Settings
    local textFieldsLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    textFieldsLabel:SetPoint("TOPLEFT", 20, -205)
    textFieldsLabel:SetText("Tag Position")
	
    -- Mythic Position Dropdown
    local mythicPosLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    mythicPosLabel:SetPoint("TOPLEFT", 20, -230)
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
    forgePosLabel:SetPoint("TOPLEFT", 200, -230)
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
    
	-- Divine Position Dropdown
    local divinePosLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    divinePosLabel:SetPoint("TOPLEFT", 20, -290)
    divinePosLabel:SetText("Divine Position:")
    
    local divinePosDropdown = CreateFrame("Frame", "FIL_DivinePosDropdown", settingsPanel, "UIDropDownMenuTemplate")
    divinePosDropdown:SetPoint("TOPLEFT", divinePosLabel, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(divinePosDropdown, 120)
    UIDropDownMenu_SetText(divinePosDropdown, FILDB["divinePos"] or "After")
    
    local function InitializeDivinePosDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        local options = positionOptions
        for _, option in ipairs(options) do
            info.text = option
            info.value = option
            info.func = function()
                FILDB["divinePos"] = option
                UIDropDownMenu_SetText(divinePosDropdown, option)
				hasChanges = true
            end
            info.checked = (FILDB["divinePos"] == option)
            UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(divinePosDropdown, InitializeDivinePosDropdown)

    -- Attuned Position Dropdown
    local attunedPosLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    attunedPosLabel:SetPoint("TOPLEFT", 200, -290)
    attunedPosLabel:SetText("Attuned Position:")
    
    local attunedPosDropdown = CreateFrame("Frame", "FIL_AttunedPosDropdown", settingsPanel, "UIDropDownMenuTemplate")
    attunedPosDropdown:SetPoint("TOPLEFT", attunedPosLabel, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(attunedPosDropdown, 120)
    UIDropDownMenu_SetText(attunedPosDropdown, FILDB["attunedPos"] or "After")
    
    local function InitializeAttunedPosDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, option in ipairs(positionOptions) do
            info.text = option
            info.value = option
            info.func = function()
                FILDB["attunedPos"] = option
                UIDropDownMenu_SetText(attunedPosDropdown, option)
				hasChanges = true
            end
            info.checked = (FILDB["attunedPos"] == option)
            UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(attunedPosDropdown, InitializeAttunedPosDropdown)

    -- Attunable Position Dropdown
    local attunablePosLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    attunablePosLabel:SetPoint("TOPLEFT", 20, -350)
    attunablePosLabel:SetText("Attunable Position:")
    
    local attunablePosDropdown = CreateFrame("Frame", "FIL_AttunablePosDropdown", settingsPanel, "UIDropDownMenuTemplate")
    attunablePosDropdown:SetPoint("TOPLEFT", attunablePosLabel, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(attunablePosDropdown, 120)
    UIDropDownMenu_SetText(attunablePosDropdown, FILDB["attunablePos"] or "After")
    
    local function InitializeAttunablePosDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, option in ipairs(positionOptions) do
            info.text = option
            info.value = option
            info.func = function()
                FILDB["attunablePos"] = option
                UIDropDownMenu_SetText(attunablePosDropdown, option)
				hasChanges = true
            end
            info.checked = (FILDB["attunablePos"] == option)
            UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(attunablePosDropdown, InitializeAttunablePosDropdown)
	
    -- Reset Button
    local resetButton = CreateFrame("Button", "FIL_ResetButton", settingsPanel, "GameMenuButtonTemplate")
    resetButton:SetSize(120, 30)
    resetButton:SetPoint("TOPLEFT", 250, -135)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        FILDB["mythicPos"] = "After"
		FILDB["divinePos"] = "After"
        FILDB["forgePos"] = "After"
		FILDB["mythicText"] = "M"
		FILDB["divineText"] = "D"
        FILDB["titanforgedText"] = "TF"
        FILDB["warforgedText"] = "WF"
        FILDB["lightforgedText"] = "LF"
        FILDB["attunedText"] = "Attuned"
        FILDB["attunableText"] = "Attunable"
        FILDB["attunedPos"] = "After"
        FILDB["attunablePos"] = "After"
        
        -- Update UI elements
        UIDropDownMenu_SetText(mythicPosDropdown, "After")
		UIDropDownMenu_SetText(divinePosDropdown, "After")
        UIDropDownMenu_SetText(forgePosDropdown, "After")
        UIDropDownMenu_SetText(attunedPosDropdown, "After")
        UIDropDownMenu_SetText(attunablePosDropdown, "After")
		mythicEditBox:SetText("M")
		divineEditBox:SetText("D")
        titanforgedEditBox:SetText("TF")
        warforgedEditBox:SetText("WF")
        lightforgedEditBox:SetText("LF")
        attunedEditBox:SetText("Attuned")
        attunableEditBox:SetText("Attunable")
        hasChanges = true
        print("|cff33ff99[Forged Item Links]|r: Settings reset to defaults!")
    end)
	
	-- Auto-save when panel is hidden/closed
    settingsPanel:SetScript("OnHide", function()
		firstOpen = false
        if hasChanges and hasChanges == true then
            -- Save all text field values
            FILDB["mythicText"] = mythicEditBox:GetText()
			FILDB["divineText"] = divineEditBox:GetText()
            FILDB["titanforgedText"] = titanforgedEditBox:GetText()
            FILDB["warforgedText"] = warforgedEditBox:GetText()
            FILDB["lightforgedText"] = lightforgedEditBox:GetText()
            FILDB["attunedText"] = attunedEditBox:GetText()
            FILDB["attunableText"] = attunableEditBox:GetText()
            hasChanges = false  -- Reset change flag
            print("|cff33ff99[Forged Item Links]|r: Settings saved, printing samples:")
			print("Myhtic: " .. AddTags(ITEM_SAMPLE_MAP.M))
			print("Divine: " .. AddTags(ITEM_SAMPLE_MAP.D))
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