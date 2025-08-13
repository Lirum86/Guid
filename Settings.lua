-- SettingsTab.lua
-- Builds the Settings tab content for ModernUI
-- Exports: function Build(ui, afterTab) -> returns the created tab

local SettingsTab = {}
local externalBindings = {}

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
        -- apply external control states
        if type(data.controls) == 'table' then
            for key, value in pairs(data.controls) do
                local control = externalBindings[key]
                if control and type(control) == 'table' and type(control.SetValue) == 'function' then
                    -- color tables back to Color3
                    if type(value) == 'table' and value.__type == 'color' then
                        value = Color3.fromRGB(tonumber(value.r) or 110, tonumber(value.g) or 117, tonumber(value.b) or 243)
                    end
                    pcall(function() control.SetValue(value) end)
                end
            end
        end
    end)
    local saveBtn = winCfg:CreateButton("Save", function()
        if not (ConfigSystem and selectedConfig) then return end
        local theme = ui.options and ui.options.theme or { primary = Color3.fromRGB(110,117,243) }
        local data = {
            primary = colorToTbl(theme.primary),
            watermark = (ui._watermarkVisible ~= false),
            toggleKey = (ui:GetToggleKey() and ui:GetToggleKey().Name) or "RightShift",
        }
        -- capture external control states
        local controls = {}
        for key, control in pairs(externalBindings) do
            if type(control) == 'table' and type(control.GetValue) == 'function' then
                local ok, val = pcall(function() return control.GetValue() end)
                if ok then
                    if typeof(val) == 'Color3' then
                        controls[key] = { __type = 'color', r = math.floor(val.R*255+0.5), g = math.floor(val.G*255+0.5), b = math.floor(val.B*255+0.5) }
                    else
                        controls[key] = val
                    end
                end
            end
        end
        data.controls = controls
        local ok, err = ConfigSystem.Save(selectedConfig, data)
        if not ok then warn("Config save failed: ", err) end
        -- nach Speichern Dropdown-Liste aktualisieren, Auswahl beibehalten
        task.defer(function() pcall(function() if configsDropdown then configsDropdown.SetOptions(ConfigSystem.List()) configsDropdown.SetValue(selectedConfig) end end) end)
    end)

    local deleteBtn = winCfg:CreateButton("Delete", function()
        if not (ConfigSystem and selectedConfig) then return end
        local ok = ConfigSystem.Delete(selectedConfig)
        if ok then
            selectedConfig = nil
            task.defer(function()
                pcall(function()
                    if configsDropdown then
                        local list = ConfigSystem.List()
                        configsDropdown.SetOptions(list)
                        configsDropdown.SetValue(list[1])
                        selectedConfig = list[1]
                    end
                end)
            end)
        end
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

-- Register external controls from Example.lua
function SettingsTab.RegisterBindings(map)
    if type(map) ~= 'table' then return end
    for k, v in pairs(map) do
        if type(k) == 'string' and type(v) == 'table' then
            externalBindings[k] = v
        end
    end
end

return SettingsTab


