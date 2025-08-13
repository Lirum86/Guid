-- SettingsTab.lua (Updated for ConfigManager v3.0)
-- Settings Tab für Roblox Executors mit erweiterten Config-Features
-- Exports: function Build(ui, afterTab, configManager) -> returns the created tab

local SettingsTab = {}

local function createTabAfter(ui, title, icon, afterTab)
    local tab = ui:CreateTab(title, icon)
    return tab
end

function SettingsTab.Build(ui, afterTab, configManager)
    local tab = createTabAfter(ui, "Settings", "⚙️", afterTab)

    print("🔧 Building Settings Tab for ConfigManager v3.0...")

    -- Check if ConfigManager is available
    if not configManager then
        print("❌ ConfigManager not provided - creating basic settings only")
        
        -- Basic settings without config system
        local basicWindow = tab:CreateWindow("Basic UI Settings")
        
        basicWindow:CreateKeybind("UI Toggle Key", "RightShift", function(key)
            ui:SetToggleKey(key)
        end)
        
        basicWindow:CreateCheckbox("Show Watermark", true, function(val)
            ui:SetWatermarkVisible(val)
        end)
        
        basicWindow:CreateColorPicker("Theme Color", Color3.fromRGB(110,117,243), function(color)
            ui:SetTheme({ primary = color })
        end)
        
        return tab
    end
    
    -- Wait for ConfigManager initialization
    if not configManager.isInitialized then
        print("⏳ Waiting for ConfigManager initialization...")
        local attempts = 0
        while not configManager.isInitialized and attempts < 20 do
            task.wait(0.5)
            attempts = attempts + 1
        end
        
        if not configManager.isInitialized then
            print("⚠️ ConfigManager initialization timeout - proceeding anyway")
        end
    end

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

    -- Window 2: Executor Info
    local infoWindow = tab:CreateWindow("Executor Info")
    
    -- Get executor info from ConfigManager (safe check)
    local executorInfo = nil
    local hasExecutorInfo = false
    
    if configManager and configManager.getExecutorInfo then
        local success, info = pcall(function()
            return configManager:getExecutorInfo()
        end)
        
        if success and info then
            executorInfo = info
            hasExecutorInfo = true
        end
    end
    
    if hasExecutorInfo then
        infoWindow:CreateButton("Executor: " .. executorInfo.name, function()
            print("🖥️ Executor:", executorInfo.name)
            print("📁 File System:", executorInfo.hasFileSystem)
            print("🌐 HTTP Support:", executorInfo.hasHttp)
            print("🔧 Capabilities:", table.concat(executorInfo.capabilities, ", "))
        end)
        
        infoWindow:CreateButton("File System: " .. (executorInfo.hasFileSystem and "✅ Supported" or "❌ Not Supported"), function()
            print("📁 File System Functions:")
            for funcName, supported in pairs(executorInfo.functions) do
                print("  " .. funcName .. ": " .. (supported and "✅" or "❌"))
            end
        end)
        
        infoWindow:CreateButton("HTTP Requests: " .. (executorInfo.hasHttp and "✅ Supported" or "❌ Not Supported"), function()
            print("🌐 HTTP Support:", executorInfo.hasHttp)
        end)
        
        -- Early return if no file system support
        if not executorInfo.hasFileSystem then
            print("❌ Executor doesn't support file system - Config features disabled")
            local warningWindow = tab:CreateWindow("⚠️ Warning")
            warningWindow:CreateButton("File System Required", function()
                if configManager and configManager.safeNotify then
                    configManager:safeNotify('error', 'File System Error', 
                        'Your executor doesn\'t support file operations. Config features are disabled.', 5)
                else
                    print("❌ Your executor doesn't support file operations. Config features are disabled.")
                end
            end)
            return tab
        end
    else
        -- Fallback executor detection
        local hasFileSystem = (writefile and readfile and isfolder and makefolder and delfile and listfiles)
        local hasHttp = (syn and syn.request) or (http and http.request) or request
        
        infoWindow:CreateButton("File System: " .. (hasFileSystem and "✅ Supported" or "❌ Not Supported"), function()
            print("📁 File System Check:", hasFileSystem)
        end)
        
        infoWindow:CreateButton("HTTP Requests: " .. (hasHttp and "✅ Supported" or "❌ Not Supported"), function()
            print("🌐 HTTP Check:", hasHttp)
        end)
        
        if not hasFileSystem then
            print("❌ Executor doesn't support file system - Config features disabled")
            local warningWindow = tab:CreateWindow("⚠️ Warning")
            warningWindow:CreateButton("File System Required", function()
                print("❌ Your executor doesn't support file operations (writefile/readfile)")
                print("Config saving/loading will not work!")
            end)
            return tab
        end
    end

    print("✅ ConfigManager available with file system support")

    -- Window 3: Config Management
    local winCfg = tab:CreateWindow("Config Management")

    -- State Management
    local configState = {
        selectedConfig = configManager:getCurrentConfig() or "Default",
        newConfigName = "",
        isLoading = false
    }

    -- Config Name Input
    local configNameBox = winCfg:CreateTextBox("New Config Name", "Enter config name...", function(name)
        configState.newConfigName = name or ""
        print("✏️ Config Name Set: " .. configState.newConfigName)
    end)

    -- Config Dropdown with proper initialization
    local configsDropdown = nil
    
    -- Get initial config list
    local function getConfigList()
        if not configManager then return {"Default"} end
        
        local success, list = pcall(function()
            return configManager:getConfigList()
        end)
        
        if success and list and #list > 0 then
            return list
        end
        
        return {"Default"}
    end

    -- Update dropdown with current configs
    local function updateConfigDropdown()
        if not configsDropdown or not configManager then return end
        
        local success, configList = pcall(function()
            return getConfigList()
        end)
        
        if not success then
            print("❌ Failed to get config list")
            return
        end
        
        print("🔄 Updating dropdown with configs: " .. table.concat(configList, ", "))
        
        local updateSuccess = pcall(function()
            if configsDropdown.SetOptions then
                configsDropdown:SetOptions(configList)
            end
            
            -- Update selected value
            local currentConfig = configManager:getCurrentConfig()
            if currentConfig and table.find(configList, currentConfig) then
                configState.selectedConfig = currentConfig
                if configsDropdown.SetValue then
                    configsDropdown:SetValue(currentConfig)
                end
            end
        end)
        
        if not updateSuccess then
            print("❌ Failed to update dropdown")
        end
    end

    -- Create Dropdown
    local initialConfigs = getConfigList()
    configsDropdown = winCfg:CreateDropdown("Current Config", initialConfigs, configState.selectedConfig, function(selected)
        if selected and selected ~= "" and not configState.isLoading then
            configState.selectedConfig = selected
            print("📂 Config Selected: " .. selected)
        end
    end)

    -- Set dropdown reference in ConfigManager
    if configManager and configManager.setDropdownReference then
        pcall(function()
            configManager:setDropdownReference(configsDropdown)
        end)
    end

    -- CONFIG OPERATION BUTTONS

    -- Create Config Button
    winCfg:CreateButton("Create New Config", function()
        print("🔄 Creating new config...")
        
        if not configManager then
            print("❌ ConfigManager not available")
            return
        end
        
        local name = configState.newConfigName
        if not name or name == "" then
            if configManager.safeNotify then
                configManager:safeNotify('error', 'Invalid Name', 'Please enter a config name!', 3)
            else
                print("❌ Please enter a config name!")
            end
            return
        end
        
        -- Create using ConfigManager
        local success = pcall(function()
            return configManager:createNewConfig(name)
        end)
        
        if success then
            if configNameBox.SetValue then
                configNameBox:SetValue("")
            end
            configState.newConfigName = ""
            configState.selectedConfig = name
            
            -- Update dropdown
            task.spawn(function()
                task.wait(0.3)
                updateConfigDropdown()
            end)
        else
            print("❌ Failed to create config")
        end
    end)

    -- Save Config Button  
    winCfg:CreateButton("Save Current Settings", function()
        print("💾 Saving current settings...")
        
        if not configManager then
            print("❌ ConfigManager not available")
            return
        end
        
        local success = pcall(function()
            return configManager:saveConfig(configState.selectedConfig)
        end)
        
        if not success then
            print("❌ Failed to save config")
        end
    end)

    -- Load Config Button
    winCfg:CreateButton("Load Selected Config", function()
        print("📂 Loading selected config...")
        
        if not configManager then
            print("❌ ConfigManager not available")
            return
        end
        
        configState.isLoading = true
        
        local success = pcall(function()
            return configManager:loadConfig(configState.selectedConfig)
        end)
        
        if success then
            -- Update UI elements to reflect loaded settings
            task.spawn(function()
                task.wait(0.1)
                
                -- Update toggle key display
                if ui and ui.GetToggleKey and toggleKeybind and toggleKeybind.SetValue then
                    local currentKey = ui:GetToggleKey()
                    if currentKey then
                        pcall(function()
                            toggleKeybind:SetValue(currentKey.Name)
                        end)
                    end
                end
                
                -- Update watermark checkbox
                if ui and watermarkToggle and watermarkToggle.SetValue then
                    pcall(function()
                        watermarkToggle:SetValue(ui._watermarkVisible ~= false)
                    end)
                end
                
                -- Update theme color picker
                if ui and ui.options and ui.options.theme and ui.options.theme.primary and themePicker and themePicker.SetValue then
                    pcall(function()
                        themePicker:SetValue(ui.options.theme.primary)
                    end)
                end
            end)
        else
            print("❌ Failed to load config")
        end
        
        configState.isLoading = false
    end)

    -- Delete Config Button
    winCfg:CreateButton("Delete Selected Config", function()
        print("🗑️ Deleting selected config...")
        
        if not configManager then
            print("❌ ConfigManager not available")
            return
        end
        
        local success = pcall(function()
            return configManager:deleteConfig(configState.selectedConfig)
        end)
        
        if success then
            configState.selectedConfig = "Default"
            task.spawn(function()
                task.wait(0.3)
                updateConfigDropdown()
            end)
        else
            print("❌ Failed to delete config")
        end
    end)

    -- Window 4: Advanced Config Features
    local advancedWindow = tab:CreateWindow("Advanced Config")
    
    -- Auto Load Section
    local autoLoadEnabled = false
    local autoLoadCheckbox = advancedWindow:CreateCheckbox("Auto Load on Startup", false, function(enabled)
        autoLoadEnabled = enabled
        print("🔄 Auto Load: " .. tostring(enabled))
        
        if not configManager then return end
        
        local success = pcall(function()
            local targetConfig = enabled and configState.selectedConfig or nil
            return configManager:setAutoLoad(targetConfig)
        end)
        
        if not success then
            print("❌ Failed to set auto load")
        end
    end)

    -- Config Info Button
    advancedWindow:CreateButton("Show Config Info", function()
        if not configManager then 
            print("❌ ConfigManager not available")
            return 
        end
        
        local success, metadata = pcall(function()
            return configManager:getConfigMetadata(configState.selectedConfig)
        end)
        
        if success and metadata then
            print("📋 Config Info for '" .. configState.selectedConfig .. "':")
            print("Version: " .. (metadata.version or "Unknown"))
            print("Created: " .. (metadata.created and os.date("%Y-%m-%d %H:%M:%S", metadata.created) or "Unknown"))
            print("Modified: " .. (metadata.lastModified and os.date("%Y-%m-%d %H:%M:%S", metadata.lastModified) or "Never"))
            print("Creator: " .. (metadata.creator or "Unknown"))
            print("Executor: " .. (metadata.executor or "Unknown"))
            print("Game ID: " .. (metadata.game or "Unknown"))
            print("Description: " .. (metadata.description or "No description"))
            
            if configManager.safeNotify then
                configManager:safeNotify('info', 'Config Info', 
                    'Check console for detailed information about "' .. configState.selectedConfig .. '"', 4)
            end
        else
            if configManager.safeNotify then
                configManager:safeNotify('error', 'No Info', 
                    'No metadata available for "' .. configState.selectedConfig .. '"', 3)
            else
                print("❌ No metadata available for config '" .. configState.selectedConfig .. "'")
            end
        end
    end)

    -- Window 5: Import/Export
    local importExportWindow = tab:CreateWindow("Import/Export")
    
    -- Export Config Button
    importExportWindow:CreateButton("Export to Clipboard", function()
        if not configManager then
            print("❌ ConfigManager not available")
            return
        end
        
        local success, exportData = pcall(function()
            return configManager:exportConfig(configState.selectedConfig)
        end)
        
        if success and exportData then
            if setclipboard then
                local clipSuccess = pcall(function()
                    setclipboard(exportData)
                end)
                if clipSuccess then
                    if configManager.safeNotify then
                        configManager:safeNotify('success', 'Export Success', 
                            'Config "' .. configState.selectedConfig .. '" copied to clipboard!', 4)
                    end
                else
                    print("📋 Export Data for '" .. configState.selectedConfig .. "':")
                    print(exportData)
                    if configManager.safeNotify then
                        configManager:safeNotify('info', 'Export Data', 
                            'Config data printed to console (clipboard failed)', 4)
                    end
                end
            else
                print("📋 Export Data for '" .. configState.selectedConfig .. "':")
                print(exportData)
                if configManager.safeNotify then
                    configManager:safeNotify('info', 'Export Data', 
                        'Config data printed to console (clipboard not supported)', 4)
                end
            end
        else
            print("❌ Failed to export config")
        end
    end)

    -- Import Config Input and Button
    local importDataBox = importExportWindow:CreateTextBox("Import Data", "Paste config data here...", function() end)
    local importNameBox = importExportWindow:CreateTextBox("Import Name", "New config name...", function() end)
    
    importExportWindow:CreateButton("Import Config", function()
        if not configManager then
            print("❌ ConfigManager not available")
            return
        end
        
        local importData = ""
        local importName = ""
        
        if importDataBox.GetValue then
            importData = importDataBox:GetValue() or ""
        end
        
        if importNameBox.GetValue then
            importName = importNameBox:GetValue() or ""
        end
        
        if importData == "" then
            if configManager.safeNotify then
                configManager:safeNotify('error', 'Import Error', 'Please paste config data first!', 3)
            else
                print("❌ Please paste config data first!")
            end
            return
        end
        
        if importName == "" then
            if configManager.safeNotify then
                configManager:safeNotify('error', 'Import Error', 'Please enter a name for the imported config!', 3)
            else
                print("❌ Please enter a name for the imported config!")
            end
            return
        end
        
        local success = pcall(function()
            return configManager:importConfig(importData, importName)
        end)
        
        if success then
            if importDataBox.SetValue then
                importDataBox:SetValue("")
            end
            if importNameBox.SetValue then
                importNameBox:SetValue("")
            end
            configState.selectedConfig = importName
            
            task.spawn(function()
                task.wait(0.3)
                updateConfigDropdown()
            end)
        else
            print("❌ Failed to import config")
        end
    end)

    -- INITIALIZATION
    local function initializeSettingsTab()
        print("🔄 Initializing Settings Tab...")
        
        if not configManager then
            print("⚠️ ConfigManager not available - skipping initialization")
            return
        end
        
        -- Wait for ConfigManager to be ready
        local attempts = 0
        local maxAttempts = 20
        
        while attempts < maxAttempts do
            if configManager.isInitialized then
                break
            end
            attempts = attempts + 1
            task.wait(0.5)
        end
        
        if not configManager.isInitialized then
            if configManager.safeNotify then
                configManager:safeNotify('warning', 'Initialization Timeout', 
                    'ConfigManager initialization took longer than expected', 4)
            else
                print("⚠️ ConfigManager initialization took longer than expected")
            end
        end
        
        -- Update initial state
        local success, currentConfig = pcall(function()
            return configManager:getCurrentConfig()
        end)
        if success and currentConfig then
            configState.selectedConfig = currentConfig
        end
        
        -- Check for auto load setting
        local autoSuccess, autoLoadConfig = pcall(function()
            return configManager:getAutoLoadConfig()
        end)
        if autoSuccess and autoLoadConfig and autoLoadConfig ~= "" then
            autoLoadEnabled = true
            if autoLoadCheckbox and autoLoadCheckbox.SetValue then
                pcall(function()
                    autoLoadCheckbox:SetValue(true)
                end)
            end
        end
        
        -- Initial dropdown update
        task.spawn(function()
            task.wait(0.5)
            updateConfigDropdown()
        end)
        
        print("✅ Settings Tab initialized successfully")
    end     -- Start initialization
    task.spawn(function()
        task.wait(1)  -- Wait for UI to be fully ready
        initializeSettingsTab()
    end)

    print("✅ Settings Tab built successfully with ConfigManager v3.0")
    return tab
end

return SettingsTab
