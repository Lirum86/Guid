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
    
    -- Get executor info from ConfigManager
    local executorInfo = configManager:getExecutorInfo()
    
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
            configManager:safeNotify('error', 'File System Error', 
                'Your executor doesn\'t support file operations. Config features are disabled.', 5)
        end)
        return tab
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
        if not configsDropdown then return end
        
        local configList = getConfigList()
        print("🔄 Updating dropdown with configs: " .. table.concat(configList, ", "))
        
        pcall(function()
            if configsDropdown.SetOptions then
                configsDropdown.SetOptions(configsDropdown, configList)
            end
            
            -- Update selected value
            local currentConfig = configManager:getCurrentConfig()
            if currentConfig and table.find(configList, currentConfig) then
                configState.selectedConfig = currentConfig
                if configsDropdown.SetValue then
                    configsDropdown.SetValue(configsDropdown, currentConfig)
                end
            end
        end)
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
    configManager:setDropdownReference(configsDropdown)

    -- CONFIG OPERATION BUTTONS

    -- Create Config Button
    winCfg:CreateButton("Create New Config", function()
        print("🔄 Creating new config...")
        
        local name = configState.newConfigName
        if not name or name == "" then
            configManager:safeNotify('error', 'Invalid Name', 'Please enter a config name!', 3)
            return
        end
        
        -- Create using ConfigManager
        local success = configManager:createNewConfig(name)
        if success then
            configNameBox.SetValue(configNameBox, "")
            configState.newConfigName = ""
            configState.selectedConfig = name
            
            -- Update dropdown
            task.spawn(function()
                task.wait(0.3)
                updateConfigDropdown()
            end)
        end
    end)

    -- Save Config Button  
    winCfg:CreateButton("Save Current Settings", function()
        print("💾 Saving current settings...")
        configManager:saveConfig(configState.selectedConfig)
    end)

    -- Load Config Button
    winCfg:CreateButton("Load Selected Config", function()
        print("📂 Loading selected config...")
        configState.isLoading = true
        
        local success = configManager:loadConfig(configState.selectedConfig)
        if success then
            -- Update UI elements to reflect loaded settings
            task.spawn(function()
                task.wait(0.1)
                
                -- Update toggle key display
                local currentKey = ui:GetToggleKey()
                if currentKey and toggleKeybind.SetValue then
                    toggleKeybind.SetValue(toggleKeybind, currentKey.Name)
                end
                
                -- Update watermark checkbox
                if watermarkToggle.SetValue then
                    watermarkToggle.SetValue(watermarkToggle, ui._watermarkVisible ~= false)
                end
                
                -- Update theme color picker
                if ui.options and ui.options.theme and ui.options.theme.primary and themePicker.SetValue then
                    themePicker.SetValue(themePicker, ui.options.theme.primary)
                end
            end)
        end
        
        configState.isLoading = false
    end)

    -- Delete Config Button
    winCfg:CreateButton("Delete Selected Config", function()
        print("🗑️ Deleting selected config...")
        
        local success = configManager:deleteConfig(configState.selectedConfig)
        if success then
            configState.selectedConfig = "Default"
            task.spawn(function()
                task.wait(0.3)
                updateConfigDropdown()
            end)
        end
    end)

    -- Window 4: Advanced Config Features
    local advancedWindow = tab:CreateWindow("Advanced Config")
    
    -- Auto Load Section
    local autoLoadEnabled = false
    local autoLoadCheckbox = advancedWindow:CreateCheckbox("Auto Load on Startup", false, function(enabled)
        autoLoadEnabled = enabled
        print("🔄 Auto Load: " .. tostring(enabled))
        
        local targetConfig = enabled and configState.selectedConfig or nil
        configManager:setAutoLoad(targetConfig)
    end)

    -- Config Info Button
    advancedWindow:CreateButton("Show Config Info", function()
        local metadata = configManager:getConfigMetadata(configState.selectedConfig)
        if metadata then
            print("📋 Config Info for '" .. configState.selectedConfig .. "':")
            print("Version: " .. (metadata.version or "Unknown"))
            print("Created: " .. (metadata.created and os.date("%Y-%m-%d %H:%M:%S", metadata.created) or "Unknown"))
            print("Modified: " .. (metadata.lastModified and os.date("%Y-%m-%d %H:%M:%S", metadata.lastModified) or "Never"))
            print("Creator: " .. (metadata.creator or "Unknown"))
            print("Executor: " .. (metadata.executor or "Unknown"))
            print("Game ID: " .. (metadata.game or "Unknown"))
            print("Description: " .. (metadata.description or "No description"))
            
            configManager:safeNotify('info', 'Config Info', 
                'Check console for detailed information about "' .. configState.selectedConfig .. '"', 4)
        else
            configManager:safeNotify('error', 'No Info', 
                'No metadata available for "' .. configState.selectedConfig .. '"', 3)
        end
    end)

    -- Window 5: Import/Export
    local importExportWindow = tab:CreateWindow("Import/Export")
    
    -- Export Config Button
    importExportWindow:CreateButton("Export to Clipboard", function()
        local exportData = configManager:exportConfig(configState.selectedConfig)
        if exportData then
            if setclipboard then
                setclipboard(exportData)
                configManager:safeNotify('success', 'Export Success', 
                    'Config "' .. configState.selectedConfig .. '" copied to clipboard!', 4)
            else
                print("📋 Export Data for '" .. configState.selectedConfig .. "':")
                print(exportData)
                configManager:safeNotify('info', 'Export Data', 
                    'Config data printed to console (clipboard not supported)', 4)
            end
        end
    end)

    -- Import Config Input and Button
    local importDataBox = importExportWindow:CreateTextBox("Import Data", "Paste config data here...", function() end)
    local importNameBox = importExportWindow:CreateTextBox("Import Name", "New config name...", function() end)
    
    importExportWindow:CreateButton("Import Config", function()
        local importData = importDataBox.GetValue and importDataBox:GetValue() or ""
        local importName = importNameBox.GetValue and importNameBox:GetValue() or ""
        
        if importData == "" then
            configManager:safeNotify('error', 'Import Error', 'Please paste config data first!', 3)
            return
        end
        
        if importName == "" then
            configManager:safeNotify('error', 'Import Error', 'Please enter a name for the imported config!', 3)
            return
        end
        
        local success = configManager:importConfig(importData, importName)
        if success then
            importDataBox.SetValue(importDataBox, "")
            importNameBox.SetValue(importNameBox, "")
            configState.selectedConfig = importName
            
            task.spawn(function()
                task.wait(0.3)
                updateConfigDropdown()
            end)
        end
    end)

    -- INITIALIZATION
    local function initializeSettingsTab()
        print("🔄 Initializing Settings Tab...")
        
        -- Wait for ConfigManager to be ready
        local attempts = 0
        local maxAttempts = 20
        
        while attempts < maxAttempts and not configManager.isInitialized do
            attempts = attempts + 1
            task.wait(0.5)
        end
        
        if not configManager.isInitialized then
            configManager:safeNotify('warning', 'Initialization Timeout', 
                'ConfigManager initialization took longer than expected', 4)
        end
        
        -- Update initial state
        configState.selectedConfig = configManager:getCurrentConfig() or "Default"
        
        -- Check for auto load setting
        local autoLoadConfig = configManager:getAutoLoadConfig()
        if autoLoadConfig and autoLoadConfig ~= "" then
            autoLoadEnabled = true
            if autoLoadCheckbox.SetValue then
                autoLoadCheckbox.SetValue(autoLoadCheckbox, true)
            end
        end
        
        -- Initial dropdown update
        task.spawn(function()
            task.wait(0.5)
            updateConfigDropdown()
        end)
        
        print("✅ Settings Tab initialized successfully")
    end

    -- Start initialization
    task.spawn(function()
        task.wait(1)  -- Wait for UI to be fully ready
        initializeSettingsTab()
    end)

    print("✅ Settings Tab built successfully with ConfigManager v3.0")
    return tab
end

return SettingsTab
