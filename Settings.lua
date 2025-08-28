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
    print("[SettingsTab] Building Settings Tab...")
    print("[SettingsTab] UI instance type: " .. type(ui))
    print("[SettingsTab] UI._configManagerForSettings: " .. tostring(ui._configManagerForSettings))
    print("[SettingsTab] UI.configManager: " .. tostring(ui.configManager))
    
    -- Verwende neues ConfigManager System falls verfügbar, sonst Fallback
    local ConfigSystem = nil
    
    -- Warte kurz, da ConfigManager möglicherweise noch nicht bereit ist
    local attempts = 0
    while attempts < 5 do  -- Reduced from 10
        if ui._configManagerForSettings then
            print("[SettingsTab] Found ConfigManager from Library integration")
            ConfigSystem = ui._configManagerForSettings
            break
        elseif ui.configManager then
            print("[SettingsTab] Found ConfigManager directly on UI")
            ConfigSystem = ui.configManager
            break
        elseif deps and deps.ConfigSystem then
            print("[SettingsTab] Using ConfigSystem from deps")
            ConfigSystem = deps.ConfigSystem
            break
        else
            attempts = attempts + 1
            if attempts < 5 then  -- Reduced from 10
                print("[SettingsTab] ConfigManager not ready, waiting... (attempt " .. attempts .. "/5)")
                task.wait(0.01)
            end
        end
    end
    
    if not ConfigSystem then
        print("[SettingsTab] No ConfigSystem available after " .. attempts .. " attempts!")
        print("[SettingsTab] Attempting to load ConfigSystem manually...")
        
        -- Versuche ConfigSystem direkt zu laden
        local success = pcall(function()
            -- Lokales ConfigSystem probieren
            local ok, module = pcall(function()
                return require(script.Parent:WaitForChild("ConfigSystem"))
            end)
            
            if ok and module then
                print("[SettingsTab] Local ConfigSystem loaded successfully")
                ConfigSystem = module.new(ui)
            else
                print("[SettingsTab] Local ConfigSystem failed, trying GitHub...")
                -- GitHub Fallback
                local ConfigManagerClass = loadstring(game:HttpGet("https://raw.githubusercontent.com/Lirum86/Guid/refs/heads/main/Config.lua"))()
                if ConfigManagerClass then
                    print("[SettingsTab] GitHub ConfigSystem loaded, creating instance...")
                    ConfigSystem = ConfigManagerClass.new(ui)
                end
            end
        end)
        
        if not success then
            print("[SettingsTab] Manual ConfigSystem loading failed")
        end
    end
    
    if ConfigSystem then
        print("[SettingsTab] ConfigSystem type: " .. type(ConfigSystem))
        if type(ConfigSystem) == "table" then
            local methods = {}
            for k, v in pairs(ConfigSystem) do
                if type(v) == "function" then
                    table.insert(methods, k)
                end
            end
            print("[SettingsTab] Available methods: " .. table.concat(methods, ", "))
        end
    end
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
        local list = {"Default"}
        
        if ConfigSystem then
            if ConfigSystem.getConfigList then
                -- Neues ConfigManager System
                list = ConfigSystem:getConfigList()
            elseif ConfigSystem.List then
                -- Altes ConfigSystem
                list = ConfigSystem.List()
            end
        end
        
        if configsDropdown.SetOptions then pcall(function() configsDropdown.SetOptions(list) end) end
        local choose = selectName or list[1]
        if choose and configsDropdown.SetValue then pcall(function() configsDropdown.SetValue(choose) end) end
    end

    local createBtn = winCfg:CreateButton("Create Config", function()
        if not ConfigSystem then 
            print("[SettingsTab] No ConfigSystem available")
            return 
        end
        
        if cfgName == nil or cfgName == '' then 
            print("[SettingsTab] Config name is empty")
            return 
        end
        
        print("[SettingsTab] Creating config: " .. cfgName)
        
        local success = false
        if ConfigSystem.createConfig then
            -- Neues ConfigManager System
            success = ConfigSystem:createConfig(cfgName)
        elseif ConfigSystem.Create then
            -- Altes ConfigSystem
            success = ConfigSystem.Create(cfgName)
        end
        
        if success then
            task.defer(function() 
                refreshDropdown(cfgName) 
                -- Config Name Input leeren
                configNameBox.SetValue("")
                cfgName = ""
            end)
        end
    end)

    local selectedConfig = "Default" -- Initialer Wert setzen
    local initialList = {"Default"}
    
    if ConfigSystem then
        if ConfigSystem.getConfigList then
            initialList = ConfigSystem:getConfigList()
        elseif ConfigSystem.List then
            initialList = ConfigSystem.List()
        end
    end
    
    -- Wenn Default nicht in der Liste ist, nehme das erste Element
    if #initialList > 0 and not table.find(initialList, "Default") then
        selectedConfig = initialList[1]
    end
    
    configsDropdown = winCfg:CreateDropdown("Configs", initialList, selectedConfig, function(val)
        selectedConfig = val
        print("[SettingsTab] Config selected: " .. tostring(val))
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
        if not ConfigSystem then 
            print("[SettingsTab] No ConfigSystem available")
            return 
        end
        
        if not selectedConfig then 
            print("[SettingsTab] No config selected")
            return 
        end
        
        print("[SettingsTab] Loading config: " .. selectedConfig)
        
        local success = false
        if ConfigSystem.loadConfig then
            -- Neues ConfigManager System
            success = ConfigSystem:loadConfig(selectedConfig)
        elseif ConfigSystem.Load then
            -- Altes ConfigSystem - Legacy-Verhalten
            local data = ConfigSystem.Load(selectedConfig)
            if type(data) == 'table' then
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
                success = true
            end
        end
        
        if not success then
            print("[SettingsTab] Failed to load config: " .. selectedConfig)
        end
    end)
    local saveBtn = winCfg:CreateButton("Save", function()
        if not ConfigSystem then 
            print("[SettingsTab] No ConfigSystem available")
            return 
        end
        
        if not selectedConfig then 
            print("[SettingsTab] No config selected")
            return 
        end
        
        print("[SettingsTab] Saving config: " .. selectedConfig)
        
        local success = false
        if ConfigSystem.saveConfig then
            -- Neues ConfigManager System - automatische Datensammlung
            success = ConfigSystem:saveConfig(selectedConfig)
        elseif ConfigSystem.Save then
            -- Altes ConfigSystem - manuelle Datensammlung
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
            success = ok
            if not ok then 
                print("[SettingsTab] Config save failed: " .. tostring(err))
            end
        end
        
        if success then
            -- nach Speichern Dropdown-Liste aktualisieren, Auswahl beibehalten
            task.defer(function() refreshDropdown(selectedConfig) end)
        end
    end)

    local deleteBtn = winCfg:CreateButton("Delete", function()
        if not ConfigSystem then 
            print("[SettingsTab] No ConfigSystem available")
            return 
        end
        
        if not selectedConfig then 
            print("[SettingsTab] No config selected")
            return 
        end
        
        if selectedConfig == "default" or selectedConfig == "Default" then
            print("[SettingsTab] Cannot delete default config")
            return
        end
        
        print("[SettingsTab] Deleting config: " .. selectedConfig)
        
        local success = false
        if ConfigSystem.deleteConfig then
            -- Neues ConfigManager System
            success = ConfigSystem:deleteConfig(selectedConfig)
        elseif ConfigSystem.Delete then
            -- Altes ConfigSystem
            success = ConfigSystem.Delete(selectedConfig)
        end
        
        if success then
            local deletedConfig = selectedConfig
            selectedConfig = nil
            
            task.defer(function()
                -- Config-Liste aktualisieren
                local list = {"Default"}
                if ConfigSystem.getConfigList then
                    list = ConfigSystem:getConfigList()
                elseif ConfigSystem.List then
                    list = ConfigSystem.List()
                end
                
                if configsDropdown then
                    configsDropdown.SetOptions(list)
                    configsDropdown.SetValue(list[1])
                    selectedConfig = list[1]
                end
                
                -- AutoLoad-Status wird nicht automatisch geändert (nur manuelle Kontrolle)
                print("[SettingsTab] AutoLoad checkbox state unchanged (manual control only)")
                
                print("[SettingsTab] Config '" .. deletedConfig .. "' successfully deleted and UI updated")
            end)
        else
            print("[SettingsTab] Failed to delete config: " .. selectedConfig)
        end
    end)

    -- AutoLoad Checkbox mit korrektem State
    local autoLoadCheckbox = winCfg:CreateCheckbox("Auto Load Config", false, function(val)
        if ConfigSystem then
            if ConfigSystem.setAutoLoad then
                -- Neues ConfigManager System
                ConfigSystem:setAutoLoad(val and selectedConfig or nil)
                print("[SettingsTab] AutoLoad set to: " .. tostring(val and selectedConfig or "None"))
            elseif ConfigSystem.SetAutoLoad then
                -- Altes ConfigSystem
                ConfigSystem.SetAutoLoad(val and selectedConfig or nil)
            end
        end
    end)



    -- Ensure default exists and auto refresh list on build
    if ConfigSystem then
        -- Default Config sicherstellen
        local defaultExists = false
        if ConfigSystem.configExists then
            defaultExists = ConfigSystem:configExists('Default')
        elseif ConfigSystem.Exists then
            defaultExists = ConfigSystem.Exists('Default')
        end
        
        if not defaultExists then
            if ConfigSystem.createConfig then
                ConfigSystem:createConfig('Default')
            elseif ConfigSystem.Create then
                ConfigSystem.Create('Default')
            end
        end
        
        task.defer(function() refreshDropdown('Default') end)
        
        -- AutoLoad Status beim Start anzeigen (aber nur visuell, nicht automatisch ändern)
        task.spawn(function()
            task.wait(0.01)
            
            local auto = nil
            if ConfigSystem.getAutoLoad then
                auto = ConfigSystem:getAutoLoad()
            elseif ConfigSystem.GetAutoLoad then
                auto = ConfigSystem.GetAutoLoad()
            end
            
            print("[SettingsTab] Current AutoLoad config: " .. tostring(auto))
            
            if auto and auto ~= "" then
                -- Config im Dropdown setzen
                pcall(function() 
                    if configsDropdown and configsDropdown.SetValue then 
                        configsDropdown.SetValue(auto) 
                    end 
                end)
                selectedConfig = auto
                
                -- Checkbox visuell auf den korrekten Status setzen (nur beim Start)
                pcall(function()
                    if autoLoadCheckbox and autoLoadCheckbox.SetValue then
                        autoLoadCheckbox.SetValue(true)
                        print("[SettingsTab] AutoLoad checkbox visually set to true (startup only)")
                    end
                end)
            else
                -- Checkbox visuell auf false setzen (nur beim Start)
                pcall(function()
                    if autoLoadCheckbox and autoLoadCheckbox.SetValue then
                        autoLoadCheckbox.SetValue(false)
                        print("[SettingsTab] AutoLoad checkbox visually set to false (startup only)")
                    end
                end)
            end
        end)
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


