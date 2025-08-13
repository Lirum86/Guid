-- SettingsTab.lua
-- Builds the Settings tab content for ModernUI
-- Exports: function Build(ui, afterTab) -> returns the created tab

local SettingsTab = {}

local function createTabAfter(ui, title, icon, afterTab)
    -- Currently the library appends; place after is not supported directly, so create normally
    local tab = ui:CreateTab(title, icon)
    return tab
end

function SettingsTab.Build(ui, afterTab, deps)
    local ConfigSystem = deps and deps.ConfigSystem or nil
    local tab = createTabAfter(ui, "Settings", "⚙️", afterTab)

    -- Window 1: Keybind + Watermark toggle
    local winKeys = tab:CreateWindow("UI Settings")
    winKeys:CreateKeybind("UI Toggle", "RightShift", function(key)
        ui:SetToggleKey(key)
    end)
    winKeys:CreateCheckbox("Watermark", true, function(val)
        ui:SetWatermarkVisible(val)
    end)
    winKeys:CreateColorPicker("Theme Color", (ui.options and ui.options.theme and ui.options.theme.primary) or Color3.fromRGB(110,117,243), function(color, alpha)
        ui:SetTheme({ primary = color })
    end)

    -- Window 2: Config system (placeholders; logic wired in Example)
    local winCfg = tab:CreateWindow("Config")

    local cfgName = ""
    local configNameBox = winCfg:CreateTextBox("Config Name", "MyConfig", function(name)
        cfgName = name
    end)

    local configsDropdown = nil
    local function refreshDropdown(selectName)
        if not configsDropdown then return end
        local list = (ConfigSystem and ConfigSystem.List()) or {"Default"}
        if configsDropdown.SetOptions then pcall(function() configsDropdown.SetOptions(list) end) end
        local choose = selectName or list[1]
        if choose and configsDropdown.SetValue then pcall(function() configsDropdown.SetValue(choose) end) end
    end

    local createBtn = winCfg:CreateButton("Create Config", function()
        if ConfigSystem then
            if cfgName == nil or cfgName == '' then return end
            ConfigSystem.Create(cfgName)
            task.defer(function() refreshDropdown(cfgName) end)
        end
    end)

    local selectedConfig = nil
    configsDropdown = winCfg:CreateDropdown("Configs", (ConfigSystem and ConfigSystem.List()) or {"Default"}, "Default", function(val)
        selectedConfig = val
    end)

    local function colorToTbl(c)
        if typeof(c) ~= 'Color3' then return {r=110,g=117,b=243} end
        return { r = math.floor(c.R*255+0.5), g = math.floor(c.G*255+0.5), b = math.floor(c.B*255+0.5) }
    end
    local function tblToColor(t)
        if type(t) ~= 'table' then return Color3.fromRGB(110,117,243) end
        return Color3.fromRGB(tonumber(t.r) or 110, tonumber(t.g) or 117, tonumber(t.b) or 243)
    end

    local loadBtn = winCfg:CreateButton("Load", function()
        if not (ConfigSystem and selectedConfig) then return end
        local data = ConfigSystem.Load(selectedConfig)
        if type(data) ~= 'table' then return end
        if data.primary then ui:SetTheme({ primary = tblToColor(data.primary) }) end
        if data.watermark ~= nil then ui:SetWatermarkVisible(data.watermark and true or false) end
        if data.toggleKey then ui:SetToggleKey(data.toggleKey) end
    end)
    local saveBtn = winCfg:CreateButton("Save", function()
        if not (ConfigSystem and selectedConfig) then return end
        local theme = ui.options and ui.options.theme or { primary = Color3.fromRGB(110,117,243) }
        local data = {
            primary = colorToTbl(theme.primary),
            watermark = (ui._watermarkVisible ~= false),
            toggleKey = (ui:GetToggleKey() and ui:GetToggleKey().Name) or "RightShift",
        }
        ConfigSystem.Save(selectedConfig, data)
        -- nach Speichern Dropdown-Liste aktualisieren, Auswahl beibehalten
        task.defer(function() pcall(function() if configsDropdown then configsDropdown.SetOptions(ConfigSystem.List()) configsDropdown.SetValue(selectedConfig) end end) end)
    end)

    winCfg:CreateCheckbox("Auto Load Config", false, function(val)
        if ConfigSystem then
            ConfigSystem.SetAutoLoad(val and selectedConfig or nil)
        end
    end)

    -- Ensure default exists and auto refresh list on build
    if ConfigSystem then
        if not ConfigSystem.Exists('Default') then ConfigSystem.Create('Default') end
        task.defer(function() refreshDropdown('Default') end)
        local auto = ConfigSystem.GetAutoLoad()
        if auto then
            pcall(function() if configsDropdown and configsDropdown.SetValue then configsDropdown.SetValue(auto) end end)
            selectedConfig = auto
        end
    end

    return tab
end

return SettingsTab


