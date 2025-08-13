
-- SettingsTab.lua (Ultimate Fixed Version)
-- Completely rewritten Config system integration
-- Exports: function Build(ui, afterTab) -> returns the created tab

local SettingsTab = {}

local function createTabAfter(ui, title, icon, afterTab)
    local tab = ui:CreateTab(title, icon)
    return tab
end

function SettingsTab.Build(ui, afterTab, deps)
    local ConfigSystem = deps and deps.ConfigSystem or nil
    local tab = createTabAfter(ui, "Settings", "⚙️", afterTab)

    -- Window 1: UI Settings
    local winKeys = tab:CreateWindow("UI Settings")
    
    winKeys:CreateKeybind("UI Toggle", "RightShift", function(key)
        print("UI Toggle Key: " .. key)
        ui:SetToggleKey(key)
    end)
    
    winKeys:CreateCheckbox("Watermark", true, function(val)
        print("Watermark: " .. tostring(val))
        ui:SetWatermarkVisible(val)
    end)
    
    winKeys:CreateColorPicker("Theme Color", (ui.options and ui.options.theme and ui.options.theme.primary) or Color3.fromRGB(110,117,243), function(color, alpha)
        print("Theme Color: " .. tostring(color))
        ui:SetTheme({ primary = color })
    end)

    -- Early return if no ConfigSystem
    if not ConfigSystem then
        print("⚠️ ConfigSystem not available")
        return tab
    end

    -- Window 2: Config System (completely rewritten)
    local winCfg = tab:CreateWindow("Config")

    -- State Management
    local configState = {
        selectedConfig = "Default",
        cfgName = "",
        isInitialized = false
    }

    -- Helper Functions
    local function colorToTbl(c)
        if typeof(c) ~= 'Color3' then return {r=110,g=117,b=243} end
        return { r = math.floor(c.R*255+0.5), g = math.floor(c.G*255+0.5), b = math.floor(c.B*255+0.5) }
    end
    
    local function tblToColor(t)
        if type(t) ~= 'table' then return Color3.fromRGB(110,117,243) end
        return Color3.fromRGB(tonumber(t.r) or 110, tonumber(t.g) or 117, tonumber(t.b) or 243)
    end

    -- Config Name Input
    local configNameBox = winCfg:CreateTextBox("Config Name", "Enter name...", function(name)
        configState.cfgName = name or ""
        print("✏️ Config Name: " .. configState.cfgName)
    end)

    -- Configs Dropdown - Store reference properly
    local configsDropdown = nil
    
    -- Safe Config List Getter
    local function getConfigList()
        local success, list = pcall(function()
            return ConfigSystem and ConfigSystem.List() or {}
        end)
        
        if not success or not list or #list == 0 then
            return {"Default"}
        end
        
        return list
    end

    -- CRITICAL FIX: Dropdown Refresh Function
    local function refreshDropdown(selectName)
        if not configsDropdown then 
            warn("❌ Dropdown not ready")
            return 
        end
        
        print("🔄 Refreshing configs...")
        
        -- Get fresh config list
        local configList = getConfigList()
        print("📋 Available configs: " .. table.concat(configList, ", "))
        
        -- Update dropdown options with error handling
        local updateSuccess = pcall(function()
            if configsDropdown and configsDropdown.SetOptions then
                configsDropdown.SetOptions(configList)
                print("✅ Dropdown options updated")
            end
        end)
        
        if not updateSuccess then
            warn("❌ Failed to update dropdown options")
            return
        end
        
        -- Set selected value
        local targetConfig = selectName or configList[1] or "Default"
        configState.selectedConfig = targetConfig
        
        -- CRITICAL: Wait for dropdown to be ready
        task.wait(0.05)
        
        local setSuccess = pcall(function()
            if configsDropdown and configsDropdown.SetValue then
                configsDropdown.SetValue(targetConfig)
                print("✅ Selected config: " .. targetConfig)
            end
        end)
        
        if not setSuccess then
            warn("❌ Failed to set dropdown value")
        end
    end

    -- Create Dropdown with proper callback
    local initialConfigs = getConfigList()
    configsDropdown = winCfg:CreateDropdown("Select Config", initialConfigs, "Default", function(selected)
        if selected and selected ~= "" then
            configState.selectedConfig = selected
            print("📂 Config selected: " .. selected)
        end
    end)

    -- BUTTONS WITH PROPER ERROR HANDLING

    -- Create Config Button
    winCfg:CreateButton("Create Config", function()
        print("🔄 Creating config...")
        
        if not ConfigSystem then
            warn("❌ ConfigSystem unavailable")
            return
        end
        
        local name = configState.cfgName
        if not name or name == "" then
            warn("❌ Please enter a config name!")
            return
        end
        
        -- Check if config already exists
        local exists = false
        local success = pcall(function()
            exists = ConfigSystem.Exists(name)
        end)
        
        if exists then
            warn("❌ Config '" .. name .. "' already exists!")
            return
        end
        
        -- Create config
        local createSuccess = pcall(function()
            return ConfigSystem.Create(name)
        end)
        
        if createSuccess then
            print("✅ Config '" .. name .. "' created successfully")
            
            -- Refresh after creation with proper delay
            task.spawn(function()
                task.wait(0.2)  -- Longer delay to ensure creation is complete
                refreshDropdown(name)
            end)
        else
            warn("❌ Failed to create config '" .. name .. "'")
        end
    end)

    -- Save Config Button
    winCfg:CreateButton("Save Config", function()
        print("💾 Saving config...")
        
        if not ConfigSystem or not configState.selectedConfig then
            warn("❌ ConfigSystem or selectedConfig unavailable")
            return
        end
        
        -- Gather current settings
        local theme = ui.options and ui.options.theme or { primary = Color3.fromRGB(110,117,243) }
        local saveData = {
            primary = colorToTbl(theme.primary),
            watermark = (ui._watermarkVisible ~= false),
            toggleKey = (ui:GetToggleKey() and ui:GetToggleKey().Name) or "RightShift",
            savedAt = os.time()
        }
        
        print("💾 Saving data: " .. game:GetService("HttpService"):JSONEncode(saveData))
        
        -- Save config
        local saveSuccess = pcall(function()
            return ConfigSystem.Save(configState.selectedConfig, saveData)
        end)
        
        if saveSuccess then
            print("✅ Config '" .. configState.selectedConfig .. "' saved successfully")
        else
            warn("❌ Failed to save config '" .. configState.selectedConfig .. "'")
        end
    end)

    -- Load Config Button
    winCfg:CreateButton("Load Config", function()
        print("📂 Loading config...")
        
        if not ConfigSystem or not configState.selectedConfig then
            warn("❌ ConfigSystem or selectedConfig unavailable")
            return
        end
        
        -- Load config data
        local success, data = pcall(function()
            return ConfigSystem.Load(configState.selectedConfig)
        end)
        
        if not success or type(data) ~= 'table' then
            warn("❌ Failed to load config '" .. configState.selectedConfig .. "'")
            return
        end
        
        print("📊 Loaded data: " .. game:GetService("HttpService"):JSONEncode(data))
        
        -- Apply settings with error handling
        if data.primary then 
            local colorSuccess = pcall(function()
                local color = tblToColor(data.primary)
                ui:SetTheme({ primary = color })
                print("✅ Theme applied: " .. tostring(color))
            end)
            if not colorSuccess then
                warn("❌ Failed to apply theme")
            end
        end
        
        if data.watermark ~= nil then 
            local wmSuccess = pcall(function()
                ui:SetWatermarkVisible(data.watermark and true or false)
                print("✅ Watermark: " .. tostring(data.watermark))
            end)
            if not wmSuccess then
                warn("❌ Failed to set watermark")
            end
        end
        
        if data.toggleKey then 
            local keySuccess = pcall(function()
                ui:SetToggleKey(data.toggleKey)
                print("✅ Toggle key: " .. data.toggleKey)
            end)
            if not keySuccess then
                warn("❌ Failed to set toggle key")
            end
        end
        
        print("✅ Config '" .. configState.selectedConfig .. "' loaded successfully")
    end)

    -- Delete Config Button
    winCfg:CreateButton("Delete Config", function()
        print("🗑️ Deleting config...")
        
        if not ConfigSystem or not configState.selectedConfig then
            warn("❌ ConfigSystem or selectedConfig unavailable")
            return
        end
        
        if configState.selectedConfig == "Default" then
            warn("❌ Cannot delete Default config!")
            return
        end
        
        -- Delete config
        local deleteSuccess = pcall(function()
            return ConfigSystem.Delete(configState.selectedConfig)
        end)
        
        if deleteSuccess then
            print("✅ Config '" .. configState.selectedConfig .. "' deleted")
            
            -- Refresh and select Default
            task.spawn(function()
                task.wait(0.2)
                refreshDropdown("Default")
            end)
        else
            warn("❌ Failed to delete config '" .. configState.selectedConfig .. "'")
        end
    end)

    -- Auto Load Checkbox
    winCfg:CreateCheckbox("Auto Load Config", false, function(enabled)
        print("🔄 Auto Load: " .. tostring(enabled))
        
        if not ConfigSystem then return end
        
        local autoSuccess = pcall(function()
            local targetConfig = enabled and configState.selectedConfig or nil
            ConfigSystem.SetAutoLoad(targetConfig)
            print("✅ Auto load set to: " .. tostring(targetConfig))
        end)
        
        if not autoSuccess then
            warn("❌ Failed to set auto load")
        end
    end)

    -- INITIALIZATION SEQUENCE
    local function initializeConfigSystem()
        if not ConfigSystem or configState.isInitialized then return end
        
        print("🔄 Initializing config system...")
        
        local initSuccess = pcall(function()
            -- Ensure Default config exists
            if not ConfigSystem.Exists('Default') then 
                ConfigSystem.Create('Default')
                print("✅ Default config created")
            end
            
            -- Check for auto load
            local autoConfig = ConfigSystem.GetAutoLoad()
            if autoConfig and autoConfig ~= "" and ConfigSystem.Exists(autoConfig) then
                print("🔄 Auto load found: " .. autoConfig)
                configState.selectedConfig = autoConfig
            end
            
            configState.isInitialized = true
        end)
        
        if initSuccess then
            print("✅ Config system initialized")
            
            -- Initial dropdown refresh
            task.spawn(function()
                task.wait(0.3)  -- Wait for everything to be ready
                refreshDropdown(configState.selectedConfig)
            end)
        else
            warn("❌ Config system initialization failed")
        end
    end

    -- Start initialization
    task.spawn(function()
        task.wait(0.5)  -- Wait for UI to be fully ready
        initializeConfigSystem()
    end)

    return tab
end

return SettingsTab
