-- SettingsTab.lua (Executor Version)
-- Settings Tab für Roblox Executors mit File System Support
-- Exports: function Build(ui, afterTab) -> returns the created tab

local SettingsTab = {}

local function createTabAfter(ui, title, icon, afterTab)
    local tab = ui:CreateTab(title, icon)
    return tab
end

function SettingsTab.Build(ui, afterTab, deps)
    local ConfigSystem = deps and deps.ConfigSystem or nil
    local tab = createTabAfter(ui, "Settings", "⚙️", afterTab)

    print("🔧 Building Settings Tab for Executor...")

    -- Window 1: UI Settings
    local winKeys = tab:CreateWindow("UI Settings")
    
    -- UI Toggle Keybind
    local toggleKeybind = winKeys:CreateKeybind("UI Toggle Key", "RightShift", function(key)
        print("🔑 UI Toggle Key: " .. key)
        ui:SetToggleKey(key)
    end)
    
    -- Watermark Toggle
    local watermarkToggle = winKeys:CreateCheckbox("Show Watermark", true, function(val)
        print("💧 Watermark: " .. tostring(val))
        ui:SetWatermarkVisible(val)
    end)
    
    -- Theme Color Picker
    local themePicker = winKeys:CreateColorPicker("Theme Color", 
        (ui.options and ui.options.theme and ui.options.theme.primary) or Color3.fromRGB(110,117,243), 
        function(color, alpha)
            print("🎨 Theme Color: " .. tostring(color))
            ui:SetTheme({ primary = color })
        end
    )

    -- Executor Info
    local infoWindow = tab:CreateWindow("Executor Info")
    
    -- Check Executor Capabilities
    local hasFileSystem = (writefile and readfile and isfolder and makefolder and delfile and listfiles)
    local hasHttp = (syn and syn.request) or (http and http.request) or request
    local hasWebSocket = syn and syn.websocket
    
    infoWindow:CreateButton("File System: " .. (hasFileSystem and "✅ Supported" or "❌ Not Supported"), function()
        print("📁 File System Check:", hasFileSystem)
    end)
    
    infoWindow:CreateButton("HTTP Requests: " .. (hasHttp and "✅ Supported" or "❌ Not Supported"), function()
        print("🌐 HTTP Check:", hasHttp)
    end)

    -- Early return if no ConfigSystem or no file system
    if not ConfigSystem then
        print("⚠️ ConfigSystem not available")
        return tab
    end
    
    if not hasFileSystem then
        print("❌ Executor doesn't support file system - Config features disabled")
        local warningWindow = tab:CreateWindow("⚠️ Warning")
        warningWindow:CreateButton("File System Required", function()
            print("❌ Your executor doesn't support file operations (writefile/readfile)")
            print("Config saving/loading will not work!")
        end)
        return tab
    end

    print("✅ Config System available with file system support")

    -- Window 2: Config Management
    local winCfg = tab:CreateWindow("Config Management")

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
    local configNameBox = winCfg:CreateTextBox("New Config Name", "Enter config name...", function(name)
        configState.cfgName = name or ""
        print("✏️ Config Name Set: " .. configState.cfgName)
    end)

    -- Config Dropdown
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

    -- Dropdown Refresh Function (Fixed for Executor)
    local function refreshDropdown(selectName)
        if not configsDropdown then 
            warn("❌ Dropdown not initialized")
            return 
        end
        
        print("🔄 Refreshing config list...")
        
        -- Get fresh config list
        local configList = getConfigList()
        print("📋 Found configs: " .. table.concat(configList, ", "))
        
        -- Update dropdown options
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
        
        -- Wait for dropdown to be ready
        task.wait(0.1)
        
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

    -- Create Dropdown
    local initialConfigs = getConfigList()
    configsDropdown = winCfg:CreateDropdown("Current Config", initialConfigs, "Default", function(selected)
        if selected and selected ~= "" then
            configState.selectedConfig = selected
            print("📂 Config Selected: " .. selected)
        end
    end)

    -- CONFIG BUTTONS

    -- Create Config Button
    winCfg:CreateButton("Create New Config", function()
        print("🔄 Creating new config...")
        
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
            configNameBox.SetValue("")
            configState.cfgName = ""
            
            -- Refresh dropdown after creation
            task.spawn(function()
                task.wait(0.2)
                refreshDropdown(name)
            end)
        else
            warn("❌ Failed to create config '" .. name .. "'")
        end
    end)

    -- Save Config Button  
    winCfg:CreateButton("Save Current Settings", function()
        print("💾 Saving current settings...")
        
        if not ConfigSystem or not configState.selectedConfig then
            warn("❌ ConfigSystem or selectedConfig unavailable")
            return
        end
        
        -- Gather current UI settings
        local theme = ui.options and ui.options.theme or { primary = Color3.fromRGB(110,117,243) }
        local saveData = {
            -- Theme settings
            primary = colorToTbl(theme.primary),
            
            -- UI settings
            watermark = (ui._watermarkVisible ~= false),
            toggleKey = (ui:GetToggleKey() and ui:GetToggleKey().Name) or "RightShift",
            
            -- Metadata
            savedAt = os.time(),
            executor = true,
            game = game.GameId or 0,
            place = game.PlaceId or 0
        }
        
        print("💾 Saving data for '" .. configState.selectedConfig .. "':")
        print(game:GetService("HttpService"):JSONEncode(saveData))
        
        -- Save config
        local saveSuccess = pcall(function()
            return ConfigSystem.Save(configState.selectedConfig, saveData)
        end)
        
        if saveSuccess then
            print("✅ Config '" .. configState.selectedConfig .. "' saved successfully to file")
        else
            warn("❌ Failed to save config '" .. configState.selectedConfig .. "'")
        end
    end)

    -- Load Config Button
    winCfg:CreateButton("Load Selected Config", function()
        print("📂 Loading selected config...")
        
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
            warn("Error: " .. tostring(data))
            return
        end
        
        print("📊 Loaded config data:")
        print(game:GetService("HttpService"):JSONEncode(data))
        
        -- Apply theme settings
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
        
        -- Apply watermark setting
        if data.watermark ~= nil then 
            local wmSuccess = pcall(function()
                ui:SetWatermarkVisible(data.watermark and true or false)
                print("✅ Watermark: " .. tostring(data.watermark))
            end)
            if not wmSuccess then
                warn("❌ Failed to set watermark")
            end
        end
        
        -- Apply toggle key
        if data.toggleKey then 
            local keySuccess = pcall(function()
                ui:SetToggleKey(data.toggleKey)
                print("✅ Toggle key: " .. data.toggleKey)
            end)
            if not keySuccess then
                warn("❌ Failed to set toggle key")
            end
        end
        
        print("✅ Config '" .. configState.selectedConfig .. "' loaded and applied successfully")
    end)

    -- Delete Config Button
    winCfg:CreateButton("Delete Selected Config", function()
        print("🗑️ Deleting selected config...")
        
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
            print("✅ Config '" .. configState.selectedConfig .. "' deleted from file system")
            
            -- Refresh and select Default
            task.spawn(function()
                task.wait(0.2)
                refreshDropdown("Default")
            end)
        else
            warn("❌ Failed to delete config '" .. configState.selectedConfig .. "'")
        end
    end)

    -- Auto Load Section
    local autoLoadWindow = tab:CreateWindow("Auto Load")
    
    -- Auto Load Checkbox
    local autoLoadEnabled = false
    local autoLoadCheckbox = autoLoadWindow:CreateCheckbox("Auto Load on Script Start", false, function(enabled)
        autoLoadEnabled = enabled
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

    -- Config Info Button
    autoLoadWindow:CreateButton("Show Config Info", function()
        if not ConfigSystem or not configState.selectedConfig then return end
        
        local info = ConfigSystem.GetInfo(configState.selectedConfig)
        if info then
            print("📋 Config Info for '" .. configState.selectedConfig .. "':")
            print("Created: " .. (info.created and os.date("%Y-%m-%d %H:%M:%S", info.created) or "Unknown"))
            print("Modified: " .. (info.modified and os.date("%Y-%m-%d %H:%M:%S", info.modified) or "Never"))
            print("Version: " .. (info.version or "Unknown"))
            print("Executor: " .. tostring(info.executor or false))
        else
            print("❌ No info available for config '" .. configState.selectedConfig .. "'")
        end
    end)

    -- INITIALIZATION
    local function initializeConfigSystem()
        if not ConfigSystem or configState.isInitialized then return end
        
        print("🔄 Initializing executor config system...")
        
        local initSuccess = pcall(function()
            -- Ensure Default config exists
            if not ConfigSystem.Exists('Default') then 
                ConfigSystem.Create('Default')
                print("✅ Default config created")
            end
            
            -- Check for auto load
            local autoConfig = ConfigSystem.GetAutoLoad()
            if autoConfig and autoConfig ~= "" and ConfigSystem.Exists(autoConfig) then
                print("🔄 Found auto load config: " .. autoConfig)
                configState.selectedConfig = autoConfig
                autoLoadCheckbox.SetValue(true)
                autoLoadEnabled = true
            end
            
            configState.isInitialized = true
        end)
        
        if initSuccess then
            print("✅ Executor config system initialized")
            
            -- Initial dropdown refresh
            task.spawn(function()
                task.wait(0.5)
                refreshDropdown(configState.selectedConfig)
            end)
        else
            warn("❌ Executor config system initialization failed")
        end
    end

    -- Start initialization
    task.spawn(function()
        task.wait(1)  -- Wait for UI to be fully ready
        initializeConfigSystem()
    end)

    print("✅ Settings Tab built successfully for executor")
    return tab
end

return SettingsTab
