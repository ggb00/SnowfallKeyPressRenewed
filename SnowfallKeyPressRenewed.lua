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

local function updateBindings()
  if InCombatLockdown() then
    pendingUpdate = true
    overrideFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  hook = false
  ClearOverrideBindings(overrideFrame)
  hook = true

  local numBindings = GetNumBindings()
  for i = 1, numBindings do
    local _, _, key1, key2 = GetBinding(i)
    if key1 and not stringfind(key1, "MOUSEWHEEL") and key1 ~= "BUTTON1" and key1 ~= "BUTTON2" then
      boundKeys[key1] = true
    end
    if key2 and not stringfind(key2, "MOUSEWHEEL") and key2 ~= "BUTTON1" and key2 ~= "BUTTON2" then
      boundKeys[key2] = true
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
  else
    boundKeys[overrideKey] = nil
  end
end

hooksecurefunc("SetOverrideBinding", setOverrideBindingHook)
hooksecurefunc("SetOverrideBindingSpell", setOverrideBindingHook)
hooksecurefunc("SetOverrideBindingClick", setOverrideBindingHook)
hooksecurefunc("SetOverrideBindingItem", setOverrideBindingHook)
hooksecurefunc("SetOverrideBindingMacro", setOverrideBindingHook)

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
    overrideFrame:SetScript("OnUpdate", function(self)
      self:SetScript("OnUpdate", nil)
      if pendingUpdate then
        pendingUpdate = false
        updateBindings()
      end
    end)
  end
end
hooksecurefunc("ClearOverrideBindings", clearOverrideBindingsHook)

local function onEvent(self, event)
  if event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pendingUpdate then
      pendingUpdate = false
      updateBindings()
    end
  else
    updateBindings()
  end
end

overrideFrame:SetScript("OnEvent", onEvent)
overrideFrame:RegisterEvent("PLAYER_LOGIN")
overrideFrame:RegisterEvent("UPDATE_BINDINGS")