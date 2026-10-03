-- SnowfallKeyPressRenewed.lua
local _G = _G
local type = type
local ipairs = ipairs
local pairs = pairs
local stringmatch = string.match
local stringgsub = string.gsub
local stringfind = string.find
local InCombatLockdown = InCombatLockdown
local GetNumBindings = GetNumBindings
local GetBinding = GetBinding
local GetBindingAction = GetBindingAction
local GetBindingKey = GetBindingKey
local SetOverrideBinding = SetOverrideBinding
local SetOverrideBindingClick = SetOverrideBindingClick
local ClearOverrideBindings = ClearOverrideBindings
local SecureButton_GetModifiedAttribute = SecureButton_GetModifiedAttribute
local SecureHandlerWrapScript = SecureHandlerWrapScript
local SecureHandlerUnwrapScript = SecureHandlerUnwrapScript
local SecureHandlerExecute = SecureHandlerExecute
local SecureHandlerSetFrameRef = SecureHandlerSetFrameRef
local issecurevariable = issecurevariable

local templates = {
  {command = "^ACTIONBUTTON(%d+)$",          attributes = {{"type", "macro"}, {"actionbutton", "%1"                         }}},
  {command = "^MULTIACTIONBAR1BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton",  "MultiBarBottomLeftButton%1" }}},
  {command = "^MULTIACTIONBAR2BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton",  "MultiBarBottomRightButton%1"}}},
  {command = "^MULTIACTIONBAR3BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton",  "MultiBarRightButton%1"      }}},
  {command = "^MULTIACTIONBAR4BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton",  "MultiBarLeftButton%1"       }}},
  {command = "^SHAPESHIFTBUTTON(%d+)$",      attributes = {{"type", "click"}, {"clickbutton",  "ShapeshiftButton%1"         }}},
  {command = "^BONUSACTIONBUTTON(%d+)$",     attributes = {{"type", "click"}, {"clickbutton",  "PetActionButton%1"          }}},
  {command = "^MULTICASTSUMMONBUTTON(%d+)$", attributes = {{"type", "click"}, {"multicastsummon", "%1"                      }}},
  {command = "^MULTICASTRECALLBUTTON1$",     attributes = {{"type", "click"}, {"clickbutton",  "MultiCastRecallSpellButton" }}},
  {command = "^CLICK (.+):([^:]+)$",         attributes = {{"type", "click"}, {"clickbutton",  "%1"                         }}},
  {command = "^MACRO (.+)$",                 attributes = {{"type", "macro"}, {"macro",        "%1"                         }}},
  {command = "^SPELL (.+)$",                 attributes = {{"type", "spell"}, {"spell",        "%1"                         }}},
  {command = "^ITEM (.+)$",                  attributes = {{"type", "item" }, {"item",         "%1"                         }}},
}

local allowedTypeAttributes = {
  ["actionbar"]  = true,
  ["action"]     = true,
  ["pet"]        = true,
  ["multispell"] = true,
  ["spell"]      = true,
  ["item"]       = true,
  ["macro"]      = true,
  ["cancelaura"] = true,
  ["stop"]       = true,
  ["target"]     = true,
  ["focus"]      = true,
  ["assist"]     = true,
  ["maintank"]   = true,
  ["mainassist"] = true,
}

local modifierCombos = {
  "",
  "ALT-",
  "CTRL-",
  "SHIFT-",
  "ALT-CTRL-",
  "ALT-SHIFT-",
  "CTRL-SHIFT-",
  "ALT-CTRL-SHIFT-",
}

local universalBaseKeys = {
  "SPACE", "ENTER", "ESCAPE", "TAB", "BACKSPACE", "DELETE", "INSERT",
  "HOME", "END", "PAGEUP", "PAGEDOWN", "UP", "DOWN", "LEFT", "RIGHT",
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
  "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
  "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
  "`", "-", "=", "[", "]", "\\", ";", "'", ".", ",", "/",
  "NUMPAD0", "NUMPAD1", "NUMPAD2", "NUMPAD3", "NUMPAD4",
  "NUMPAD5", "NUMPAD6", "NUMPAD7", "NUMPAD8", "NUMPAD9",
  "NUMPADDECIMAL", "NUMPADDIVIDE", "NUMPADMINUS", "NUMPADMULTIPLY", "NUMPADPLUS",
  "BUTTON3", "BUTTON4", "BUTTON5", "BUTTON6", "BUTTON7", "BUTTON8", "BUTTON9",
  "BUTTON10", "BUTTON11", "BUTTON12", "BUTTON13", "BUTTON14", "BUTTON15", "BUTTON16",
  "BUTTON17", "BUTTON18", "BUTTON19", "BUTTON20", "BUTTON21", "BUTTON22", "BUTTON23",
  "BUTTON24", "BUTTON25", "BUTTON26", "BUTTON27", "BUTTON28", "BUTTON29", "BUTTON30", "BUTTON31",
}

local addonButtonPrefixes = {
  {"BT4Button", 120},
  {"BT4PetButton", 10},
  {"BT4StanceButton", 10},
  {"DominosActionButton", 60},
  {"DominosPetActionButton", 10},
  {"DominosClassActionButton", 10},
  {"BindPadMacro", 100},
  {"BindPadKey", 100},
  {"MacaroonButton", 120},
}

local hook = true
local overrideFrame = CreateFrame("Frame")
local boundKeys = {}
local pendingUpdate = false

hooksecurefunc("ShowUIPanel", function()
  if KeyBindingFrame then
    KeyBindingFrame.mode = nil
  end
end)

local function isSecureButton(x)
  return type(x) == "table"
    and type(x.IsObjectType) == "function"
    and issecurevariable(x, "IsObjectType")
    and x:IsObjectType("Button")
    and not not x:IsProtected()
end

local function accelerateKey(key, command)
  if key == "BUTTON1" or key == "BUTTON2" or stringfind(key, "MOUSEWHEEL") then
    return
  end

  local clickButtonName, mouseButton
  local clickButton, harmButton, helpButton
  local mouseType, harmType, helpType
  local bindButtonName, bindButton

  for _, template in ipairs(templates) do
    if stringmatch(command, template.command) then
      if template.attributes then
        clickButtonName, mouseButton = stringmatch(command, "^CLICK (.+):([^:]+)$")
        if clickButtonName then
          clickButton = _G[clickButtonName]
          if not isSecureButton(clickButton) or SecureButton_GetModifiedAttribute(clickButton, "downbutton", mouseButton) then
            return
          end
          harmButton = SecureButton_GetModifiedAttribute(clickButton, "harmbutton", mouseButton)
          helpButton = SecureButton_GetModifiedAttribute(clickButton, "helpbutton", mouseButton)
          mouseType = SecureButton_GetModifiedAttribute(clickButton, "type", mouseButton)
          harmType = harmButton and SecureButton_GetModifiedAttribute(clickButton, "type", harmButton)
          helpType = helpButton and SecureButton_GetModifiedAttribute(clickButton, "type", helpButton)
          if (mouseType and not allowedTypeAttributes[mouseType])
            or (harmType and not allowedTypeAttributes[harmType])
            or (helpType and not allowedTypeAttributes[helpType]) then
            return
          end
        else
          mouseButton = "LeftButton"
        end

        bindButtonName = "SnowfallKeyPress_Button_" .. key
        bindButton = _G[bindButtonName]
        if not bindButton then
          bindButton = CreateFrame("Button", bindButtonName, nil, "SecureActionButtonTemplate")
          bindButton:RegisterForClicks("AnyDown")
          SecureHandlerSetFrameRef(bindButton, "VehicleMenuBar", VehicleMenuBar)
          SecureHandlerSetFrameRef(bindButton, "BonusActionBarFrame", BonusActionBarFrame)
          if MultiCastSummonSpellButton then
            SecureHandlerSetFrameRef(bindButton, "MultiCastSummonSpellButton", MultiCastSummonSpellButton)
          end
          SecureHandlerExecute(
            bindButton,
            [[
              VehicleMenuBar = self:GetFrameRef("VehicleMenuBar");
              BonusActionBarFrame = self:GetFrameRef("BonusActionBarFrame");
              MultiCastSummonSpellButton = self:GetFrameRef("MultiCastSummonSpellButton");
            ]]
          )
        end

        if bindButton._snowfallCommand ~= command then
          bindButton._snowfallCommand = command

          SecureHandlerUnwrapScript(bindButton, "OnClick")
          bindButton:SetAttribute("type", nil)
          bindButton:SetAttribute("clickbutton", nil)
          bindButton:SetAttribute("macro", nil)
          bindButton:SetAttribute("macrotext", nil)
          bindButton:SetAttribute("spell", nil)
          bindButton:SetAttribute("item", nil)

          local maxVehicleButtons = VEHICLE_MAX_ACTIONBUTTONS or 6

          for _, attribute in ipairs(template.attributes) do
            local attributeName = attribute[1]
            local attributeValue = stringgsub(command, template.command, attribute[2], 1)

            if attributeName == "clickbutton" then
              bindButton:SetAttribute(attributeName, _G[attributeValue])
            elseif attributeName == "actionbutton" then
              SecureHandlerWrapScript(
                bindButton, "OnClick", bindButton,
                [[
                  local clickMacro = "/click ActionButton]] .. attributeValue .. [[";
                  if (VehicleMenuBar and VehicleMenuBar:IsProtected() and VehicleMenuBar:IsShown() and ]] .. tostring(tonumber(attributeValue) <= maxVehicleButtons) .. [[) then
                    clickMacro = "/click VehicleMenuBarActionButton]] .. attributeValue .. [[";
                  elseif (BonusActionBarFrame and BonusActionBarFrame:IsProtected() and BonusActionBarFrame:IsShown()) then
                    clickMacro = "/click BonusActionButton]] .. attributeValue .. [[";
                  end
                  self:SetAttribute("macrotext", clickMacro);
                ]]
              )
            elseif attributeName == "multicastsummon" then
              SecureHandlerWrapScript(
                bindButton, "OnClick", bindButton,
                [[
                  if MultiCastSummonSpellButton then
                    lastID = MultiCastSummonSpellButton:GetID();
                    MultiCastSummonSpellButton:SetID(]] .. attributeValue .. [[);
                  end
                ]],
                [[
                  if MultiCastSummonSpellButton then
                    MultiCastSummonSpellButton:SetID(lastID);
                  end
                ]]
              )
              bindButton:SetAttribute("clickbutton", MultiCastSummonSpellButton)
            else
              bindButton:SetAttribute(attributeName, attributeValue)
            end
          end
        end

        hook = false
        SetOverrideBindingClick(overrideFrame, true, key, bindButtonName, mouseButton)
        hook = true
      end
      return
    end
  end
end

local function scanAddonButtons()
  for _, def in ipairs(addonButtonPrefixes) do
    local prefix, maxCount = def[1], def[2]
    if _G[prefix .. "1"] then
      for i = 1, maxCount do
        local buttonName = prefix .. i
        if not _G[buttonName] then break end
        local key1, key2 = GetBindingKey("CLICK " .. buttonName .. ":LeftButton")
        if key1 and key1 ~= "BUTTON1" and key1 ~= "BUTTON2" and not stringfind(key1, "MOUSEWHEEL") then
          boundKeys[key1] = true
        end
        if key2 and key2 ~= "BUTTON1" and key2 ~= "BUTTON2" and not stringfind(key2, "MOUSEWHEEL") then
          boundKeys[key2] = true
        end
      end
    end
  end
end

local function updateBindings()
  if InCombatLockdown() then
    pendingUpdate = true
    overrideFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  pendingUpdate = false

  hook = false
  ClearOverrideBindings(overrideFrame)
  hook = true

  local numBindings = GetNumBindings()
  for i = 1, numBindings do
    local _, _, key1, key2 = GetBinding(i)
    if key1 and key1 ~= "BUTTON1" and key1 ~= "BUTTON2" and not stringfind(key1, "MOUSEWHEEL") then
      boundKeys[key1] = true
    end
    if key2 and key2 ~= "BUTTON1" and key2 ~= "BUTTON2" and not stringfind(key2, "MOUSEWHEEL") then
      boundKeys[key2] = true
    end
  end

  scanAddonButtons()

  for _, baseKey in ipairs(universalBaseKeys) do
    for _, mod in ipairs(modifierCombos) do
      local comboKey = mod .. baseKey
      local command = GetBindingAction(comboKey, true)
      if command and command ~= "" then
        accelerateKey(comboKey, command)
      end
    end
  end

  for key in pairs(boundKeys) do
    local command = GetBindingAction(key, true)
    if command and command ~= "" then
      accelerateKey(key, command)
    else
      boundKeys[key] = nil
    end
  end
end

local function setBindingHook(key)
  if key and key ~= "BUTTON1" and key ~= "BUTTON2" and not stringfind(key, "MOUSEWHEEL") then
    boundKeys[key] = true
  end
end
hooksecurefunc("SetBinding", setBindingHook)
hooksecurefunc("SetBindingClick", setBindingHook)
hooksecurefunc("SetBindingSpell", setBindingHook)
hooksecurefunc("SetBindingMacro", setBindingHook)
hooksecurefunc("SetBindingItem", setBindingHook)

local function setOverrideBindingHook(_, _, overrideKey)
  if not hook or not overrideKey
    or stringfind(overrideKey, "MOUSEWHEEL")
    or overrideKey == "BUTTON1" or overrideKey == "BUTTON2" then
    return
  end

  if InCombatLockdown() then
    pendingUpdate = true
    overrideFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  boundKeys[overrideKey] = true

  hook = false
  SetOverrideBinding(overrideFrame, false, overrideKey, nil)
  hook = true

  local command = GetBindingAction(overrideKey, true)
  if command and command ~= "" then
    accelerateKey(overrideKey, command)
  end
end

hooksecurefunc("SetOverrideBinding", setOverrideBindingHook)
hooksecurefunc("SetOverrideBindingSpell", setOverrideBindingHook)
hooksecurefunc("SetOverrideBindingClick", setOverrideBindingHook)
hooksecurefunc("SetOverrideBindingItem", setOverrideBindingHook)
hooksecurefunc("SetOverrideBindingMacro", setOverrideBindingHook)

local function onDebounceUpdate(self)
  self:SetScript("OnUpdate", nil)
  if pendingUpdate then
    updateBindings()
  end
end

local function clearOverrideBindingsHook(owner)
  if not hook or owner == overrideFrame then
    return
  end

  if InCombatLockdown() then
    pendingUpdate = true
    overrideFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  if not pendingUpdate then
    pendingUpdate = true
    overrideFrame:SetScript("OnUpdate", onDebounceUpdate)
  end
end
hooksecurefunc("ClearOverrideBindings", clearOverrideBindingsHook)

local function onEvent(self, event)
  if event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pendingUpdate then
      updateBindings()
    end
  else
    updateBindings()
  end
end

overrideFrame:SetScript("OnEvent", onEvent)
overrideFrame:RegisterEvent("PLAYER_LOGIN")
overrideFrame:RegisterEvent("UPDATE_BINDINGS")