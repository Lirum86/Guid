-- ConfigSystem.lua (OOP Version - Completely Redesigned)
-- Based on the advanced RadiantHub approach with ModernUI integration
-- Features: Rich notifications, metadata tracking, import/export, retry logic

local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Services
local Players = game:GetService('Players')
local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')

local player = Players.LocalPlayer

-- Enhanced Executor Detection
local function detectExecutorInfo()
    local info = {
        name = "Unknown",
        hasFileSystem = false,
        hasHttp = false,
        functions = {},
        capabilities = {}
    }
    
    -- File system functions check
    local fileFunctions = {"writefile", "readfile", "isfolder", "makefolder", "delfile", "listfiles", "isfile"}
    local hasAllFiles = true
    
    for _, func in ipairs(fileFunctions) do
        if _G[func] then
            info.functions[func] = true
        else
            hasAllFiles = false
            info.functions[func] = false
        end
    end
    
    info.hasFileSystem = hasAllFiles
    
    -- Executor detection
    if syn then
        info.name = "Synapse X"
        info.hasHttp = syn.request ~= nil
        info.capabilities = {"file_system", "http_requests", "websockets"}
    elseif KRNL_LOADED then
        info.name = "KRNL"
        info.hasHttp = request ~= nil
        info.capabilities = {"file_system", "http_requests"}
    elseif getgenv().FLUXUS_LOADED then
        info.name = "Fluxus"
        info.hasHttp = request ~= nil
        info.capabilities = {"file_system", "http_requests"}
    elseif getgenv().EXPLOIT then
        info.name = "JJSploit"
        info.hasHttp = false
        info.capabilities = {"basic"}
    else
        info.name = "Generic Executor"
        info.hasHttp = request ~= nil or game.HttpGet ~= nil
        info.capabilities = {"unknown"}
    end
    
    return info
end

-- Create new ConfigManager instance
function ConfigManager.new(uiInstance)
    local self = setmetatable({}, ConfigManager)
    
    -- Core properties
    self.uiInstance = uiInstance
    self.configFolder = 'ModernUI_Configs'
    self.httpService = HttpService
    self.currentConfig = 'Default'
    self.autoLoadConfig = nil
    self.isInitialized = false
    
    -- Executor info
    self.executorInfo = detectExecutorInfo()
    
    -- Notification system references
    self.notificationSystem = nil
    self.configDropdown = nil
    
    -- Initialize with retry logic
    task.spawn(function()
        self:initializeWithRetry()
    end)
    
    return self
end

-- ENHANCED safeNotify with multiple fallback methods
function ConfigManager:safeNotify(notifType, title, message, duration)
    duration = duration or 4
    
    -- Try multiple notification methods in order of preference
    local notificationMethods = {
        -- Method 1: UI Instance notification system
        function()
            if self.uiInstance and self.uiInstance.notifications then
                local notifSystem = self.uiInstance.notifications
                if type(notifSystem) == "table" then
                    local method = notifSystem[notifType]
                    if method and type(method) == "function" then
                        method(notifSystem, title, message, duration)
                        return true
                    end
                end
            end
            return false
        end,
        
        -- Method 2: Global notification system
        function()
            if getgenv().ModernUINotifications then
                local notifFunc = getgenv().ModernUINotifications[notifType]
                if notifFunc and type(notifFunc) == "function" then
                    notifFunc(title, message, duration)
                    return true
                end
            end
            return false
        end,
        
        -- Method 3: StarterGui notifications
        function()
            if game:GetService("StarterGui") then
                local success = pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = title,
                        Text = message,
                        Duration = duration
                    })
                end)
                return success
            end
            return false
        end,
        
        -- Method 4: Console output with formatting
        function()
            local typeColors = {
                success = "✅",
                error = "❌", 
                warning = "⚠️",
                info = "ℹ️"
            }
            local icon = typeColors[notifType] or "📋"
            print(string.format("[%s] %s: %s", icon, title, message))
            return true
        end
    }
    
    -- Try each method until one succeeds
    for i, method in ipairs(notificationMethods) do
        local success = pcall(method)
        if success then
            return true
        end
    end
    
    -- Ultimate fallback
    print("[CONFIG] " .. title .. ": " .. message)
    return false
end

-- Initialize with retry logic
function ConfigManager:initializeWithRetry()
    local maxAttempts = 10
    local attempt = 0
    
    while attempt < maxAttempts and not self.isInitialized do
        attempt = attempt + 1
        
        -- Wait for UI to be ready
        if self.uiInstance then
            local success = self:initializeConfigSystem()
            if success then
                self.isInitialized = true
                break
            end
        end
        
        task.wait(0.5)
    end
    
    if not self.isInitialized then
        self:safeNotify('warning', 'Config System', 'Initialization failed after ' .. maxAttempts .. ' attempts', 5)
    end
end

-- Initialize the config system
function ConfigManager:initializeConfigSystem()
    self:safeNotify('info', 'Config System', 'Initializing for ' .. self.executorInfo.name, 3)
    
    if not self.executorInfo.hasFileSystem then
        self:safeNotify('error', 'File System Error', 'File system functions not available in ' .. self.executorInfo.name, 6)
        return false
    end
    
    -- Create config folder
    local success = pcall(function()
        if not isfolder(self.configFolder) then
            makefolder(self.configFolder)
            self:safeNotify('info', 'Folder Created', 'Config folder: ' .. self.configFolder, 2)
        end
    end)
    
    if not success then
        self:safeNotify('error', 'Folder Error', 'Failed to create config folder', 4)
        return false
    end
    
    -- Create default config if it doesn't exist
    if not isfile(self.configFolder .. '/Default.json') then
        self:createDefaultConfig()
    end
    
    -- Load auto-load setting
    task.spawn(function()
        task.wait(1)
        self:checkAutoLoad()
    end)
    
    self:safeNotify('success', 'Config System', 'Successfully initialized!', 3)
    return true
end

-- Enhanced serialization with support for Roblox types
function ConfigManager:serializeValue(value)
    local valueType = typeof(value)
    
    if valueType == "Color3" then
        return {
            _type = "Color3",
            r = math.floor(value.R * 255 + 0.5),
            g = math.floor(value.G * 255 + 0.5),
            b = math.floor(value.B * 255 + 0.5)
        }
    elseif valueType == "Vector3" then
        return {
            _type = "Vector3",
            x = value.X, y = value.Y, z = value.Z
        }
    elseif valueType == "Vector2" then
        return {
            _type = "Vector2",
            x = value.X, y = value.Y
        }
    elseif valueType == "UDim2" then
        return {
            _type = "UDim2",
            x_scale = value.X.Scale, x_offset = value.X.Offset,
            y_scale = value.Y.Scale, y_offset = value.Y.Offset
        }
    elseif valueType == "EnumItem" then
        return {
            _type = "EnumItem",
            enum_type = tostring(value.EnumType),
            name = value.Name
        }
    elseif valueType == "table" then
        local serialized = {}
        for k, v in pairs(value) do
            if type(v) ~= "function" and type(v) ~= "userdata" then
                serialized[k] = self:serializeValue(v)
            end
        end
        return serialized
    else
        return value
    end
end

-- Enhanced deserialization
function ConfigManager:deserializeValue(value)
    if type(value) == "table" and value._type then
        if value._type == "Color3" then
            return Color3.fromRGB(
                math.clamp(tonumber(value.r) or 110, 0, 255),
                math.clamp(tonumber(value.g) or 117, 0, 255),
                math.clamp(tonumber(value.b) or 243, 0, 255)
            )
        elseif value._type == "Vector3" then
            return Vector3.new(
                tonumber(value.x) or 0,
                tonumber(value.y) or 0,
                tonumber(value.z) or 0
            )
        elseif value._type == "Vector2" then
            return Vector2.new(
                tonumber(value.x) or 0,
                tonumber(value.y) or 0
            )
        elseif value._type == "UDim2" then
            return UDim2.new(
                tonumber(value.x_scale) or 0, tonumber(value.x_offset) or 0,
                tonumber(value.y_scale) or 0, tonumber(value.y_offset) or 0
            )
        elseif value._type == "EnumItem" then
            local success, enum = pcall(function()
                local enumType = value.enum_type:gsub("^Enum%.", "")
                if Enum[enumType] and Enum[enumType][value.name] then
                    return Enum[enumType][value.name]
                end
                return nil
            end)
            return success and enum or nil
        end
        return value
    elseif type(value) == "table" then
        local deserialized = {}
        for k, v in pairs(value) do
            deserialized[k] = self:deserializeValue(v)
        end
        return deserialized
    else
        return value
    end
end

-- Enhanced config name validation
function ConfigManager:validateConfigName(name)
    if not name or type(name) ~= "string" then
        return false, 'Config name must be a string'
    end
    
    if name == '' or name:match('^%s*$') then
        return false, 'Config name cannot be empty'
    end
    
    if #name > 50 then
        return false, 'Config name too long (max 50 characters)'
    end
    
    if name:match('[<>:"/\\|?*]') then
        return false, 'Config name contains invalid characters'
    end
    
    local reserved = {'con', 'prn', 'aux', 'nul', 'com1', 'com2', 'com3', 'com4', 'com5', 'lpt1', 'lpt2', 'lpt3'}
    for _, word in ipairs(reserved) do
        if name:lower() == word then
            return false, 'Config name is a reserved system name'
        end
    end
    
    return true, 'Valid config name'
end

-- Create default configuration
function ConfigManager:createDefaultConfig()
    local defaultSettings = {
        metadata = {
            version = "3.0",
            created = os.time(),
            description = "Default ModernUI configuration",
            creator = player.Name,
            executor = self.executorInfo.name,
            game = game.PlaceId or 0
        },
        settings = {
            theme = {
                primary = {r = 110, g = 117, b = 243}
            },
            ui = {
                watermarkVisible = true,
                toggleKey = "RightShift"
            }
        }
    }
    
    local success, error = pcall(function()
        local jsonString = self.httpService:JSONEncode(defaultSettings)
        writefile(self.configFolder .. '/Default.json', jsonString)
    end)
    
    if success then
        self:safeNotify('success', 'Default Config', 'Default configuration created successfully!', 3)
    else
        self:safeNotify('error', 'Default Config Error', 'Failed to create default config: ' .. tostring(error), 5)
    end
end

-- Gather all settings from UI
function ConfigManager:gatherAllSettings()
    if not self.uiInstance then
        self:safeNotify('error', 'UI Error', 'UI instance not available', 3)
        return nil
    end
    
    local settings = {}
    
    -- Gather theme settings
    if self.uiInstance.options and self.uiInstance.options.theme then
        settings.theme = self:serializeValue(self.uiInstance.options.theme)
    end
    
    -- Gather UI settings
    settings.ui = {
        watermarkVisible = self.uiInstance._watermarkVisible ~= false,
        toggleKey = (self.uiInstance:GetToggleKey() and self.uiInstance:GetToggleKey().Name) or "RightShift"
    }
    
    -- Additional settings can be gathered here
    -- settings.tabs = self:gatherTabSettings()
    
    return settings
end

-- Apply settings to UI
function ConfigManager:applySettings(settings)
    if not self.uiInstance or not settings then
        return false
    end
    
    local appliedCount = 0
    local totalSettings = 0
    
    -- Apply theme settings
    if settings.theme then
        totalSettings = totalSettings + 1
        local success = pcall(function()
            local theme = self:deserializeValue(settings.theme)
            self.uiInstance:SetTheme(theme)
            appliedCount = appliedCount + 1
        end)
        if not success then
            self:safeNotify('warning', 'Theme Error', 'Failed to apply theme settings', 3)
        end
    end
    
    -- Apply UI settings
    if settings.ui then
        if settings.ui.watermarkVisible ~= nil then
            totalSettings = totalSettings + 1
            local success = pcall(function()
                self.uiInstance:SetWatermarkVisible(settings.ui.watermarkVisible)
                appliedCount = appliedCount + 1
            end)
            if not success then
                self:safeNotify('warning', 'Watermark Error', 'Failed to apply watermark setting', 3)
            end
        end
        
        if settings.ui.toggleKey then
            totalSettings = totalSettings + 1
            local success = pcall(function()
                self.uiInstance:SetToggleKey(settings.ui.toggleKey)
                appliedCount = appliedCount + 1
            end)
            if not success then
                self:safeNotify('warning', 'Keybind Error', 'Failed to apply toggle key', 3)
            end
        end
    end
    
    return appliedCount > 0
end

-- Create new configuration
function ConfigManager:createNewConfig(configName)
    local isValid, errorMsg = self:validateConfigName(configName)
    
    if not isValid then
        self:safeNotify('error', 'Invalid Name', errorMsg, 4)
        return false
    end
    
    local filePath = self.configFolder .. '/' .. configName .. '.json'
    if isfile(filePath) then
        self:safeNotify('warning', 'Config Exists', 'Configuration "' .. configName .. '" already exists!', 4)
        return false
    end
    
    -- Create with current settings
    local success = self:saveConfig(configName)
    
    if success then
        task.wait(0.2) -- File system delay
        self:updateConfigList()
        self:safeNotify('success', 'Config Created', 'Configuration "' .. configName .. '" created successfully!', 4)
    end
    
    return success
end

-- Save configuration
function ConfigManager:saveConfig(configName)
    if not configName or configName == '' then
        self:safeNotify('error', 'Invalid Name', 'Config name cannot be empty!', 3)
        return false
    end
    
    local success, result = pcall(function()
        local settings = self:gatherAllSettings()
        if not settings then
            error('Failed to gather settings from UI')
        end
        
        local configData = {
            name = configName,
            settings = settings,
            metadata = {
                version = "3.0",
                created = isfile(self.configFolder .. '/' .. configName .. '.json') and 
                         (self:getConfigMetadata(configName) and self:getConfigMetadata(configName).created) or os.time(),
                lastModified = os.time(),
                creator = player.Name,
                executor = self.executorInfo.name,
                game = game.PlaceId or 0,
                description = "ModernUI configuration: " .. configName
            }
        }
        
        local jsonString = self.httpService:JSONEncode(configData)
        local filePath = self.configFolder .. '/' .. configName .. '.json'
        writefile(filePath, jsonString)
        
        return true
    end)
    
    if success then
        self.currentConfig = configName
        self:updateConfigList()
        self:safeNotify('success', 'Config Saved', 'Configuration "' .. configName .. '" saved successfully!', 3)
        return true
    else
        self:safeNotify('error', 'Save Failed', 'Failed to save config: ' .. tostring(result), 4)
        return false
    end
end

-- Load configuration
function ConfigManager:loadConfig(configName)
    if not configName or configName == '' then
        self:safeNotify('error', 'Invalid Config', 'No config name provided!', 3)
        return false
    end
    
    local filePath = self.configFolder .. '/' .. configName .. '.json'
    
    if not isfile(filePath) then
        self:safeNotify('error', 'Config Not Found', 'Configuration "' .. configName .. '" does not exist!', 4)
        return false
    end
    
    local success, result = pcall(function()
        local fileContent = readfile(filePath)
        local configData = self.httpService:JSONDecode(fileContent)
        
        if not configData.settings then
            error('Invalid config format: missing settings')
        end
        
        return configData
    end)
    
    if success and result then
        local applySuccess = self:applySettings(result.settings)
        
        if applySuccess then
            self.currentConfig = configName
            
            -- Update dropdown if available
            self:updateSelectedConfig(configName)
            
            self:safeNotify('success', 'Config Loaded', 'Configuration "' .. configName .. '" loaded successfully!', 4)
            return true
        else
            self:safeNotify('error', 'Apply Failed', 'Failed to apply settings from "' .. configName .. '"!', 4)
            return false
        end
    else
        self:safeNotify('error', 'Load Failed', 'Failed to load config: ' .. tostring(result), 4)
        return false
    end
end

-- Delete configuration
function ConfigManager:deleteConfig(configName)
    if configName == 'Default' then
        self:safeNotify('error', 'Cannot Delete', 'The Default config cannot be deleted!', 3)
        return false
    end
    
    if not configName or configName == '' then
        self:safeNotify('error', 'Invalid Config', 'No config name provided!', 3)
        return false
    end
    
    local filePath = self.configFolder .. '/' .. configName .. '.json'
    
    if not isfile(filePath) then
        self:safeNotify('error', 'Config Not Found', 'Config "' .. configName .. '" does not exist!', 3)
        return false
    end
    
    local success, error = pcall(function()
        delfile(filePath)
    end)
    
    if success then
        -- Reset auto-load if this config was auto-loading
        if self.autoLoadConfig == configName then
            self:setAutoLoad(nil)
        end
        
        -- Switch to Default if this was current config
        if self.currentConfig == configName then
            self.currentConfig = 'Default'
            self:loadConfig('Default')
        end
        
        self:updateConfigList()
        self:safeNotify('success', 'Config Deleted', 'Configuration "' .. configName .. '" deleted successfully!', 3)
        return true
    else
        self:safeNotify('error', 'Delete Failed', 'Failed to delete config: ' .. tostring(error), 4)
        return false
    end
end

-- Get list of all configurations
function ConfigManager:getConfigList()
    local configs = {}
    
    if not isfolder(self.configFolder) then
        return {'Default'}
    end
    
    local success, files = pcall(function()
        return listfiles(self.configFolder)
    end)
    
    if success and files then
        for _, filePath in ipairs(files) do
            local fileName = filePath:match('([^/\\]+)%.json$')
            if fileName and fileName ~= 'autoload' then
                table.insert(configs, fileName)
            end
        end
    end
    
    -- Ensure Default is first
    local hasDefault = false
    for i, config in ipairs(configs) do
        if config == 'Default' then
            table.remove(configs, i)
            hasDefault = true
            break
        end
    end
    
    table.sort(configs)
    table.insert(configs, 1, 'Default')
    
    return configs
end

-- Update configuration list in dropdown
function ConfigManager:updateConfigList()
    if not self.configDropdown then
        self:findConfigDropdown()
    end
    
    if self.configDropdown then
        local success, configs = pcall(function()
            return self:getConfigList()
        end)
        
        if success and configs then
            pcall(function()
                if self.configDropdown.SetOptions and type(self.configDropdown.SetOptions) == "function" then
                    self.configDropdown:SetOptions(configs)
                    
                    -- Update selection
                    if table.find(configs, self.currentConfig) then
                        self:updateSelectedConfig(self.currentConfig)
                    end
                end
            end)
        end
    end
end

-- Find and store reference to config dropdown
function ConfigManager:findConfigDropdown()
    -- This should be called when the dropdown is created
    -- For now, it's a placeholder that would be filled by the Settings Tab
end

-- Set dropdown reference
function ConfigManager:setDropdownReference(dropdown)
    self.configDropdown = dropdown
end

-- Update selected config in dropdown
function ConfigManager:updateSelectedConfig(configName)
    if self.configDropdown then
        pcall(function()
            if self.configDropdown.SetValue and type(self.configDropdown.SetValue) == "function" then
                self.configDropdown:SetValue(configName)
            end
        end)
    end
end

-- Set auto-load configuration
function ConfigManager:setAutoLoad(configName)
    local autoLoadFile = self.configFolder .. '/autoload.txt'
    
    if configName and configName ~= '' then
        local configFile = self.configFolder .. '/' .. configName .. '.json'
        if not isfile(configFile) then
            self:safeNotify('error', 'Config Not Found', 'Cannot set autoload: Config "' .. configName .. '" does not exist!', 4)
            return false
        end
        
        local success = pcall(function()
            writefile(autoLoadFile, configName)
        end)
        
        if success then
            self.autoLoadConfig = configName
            self:safeNotify('success', 'AutoLoad Set', 'Config "' .. configName .. '" will auto-load on startup', 4)
            return true
        else
            self:safeNotify('error', 'AutoLoad Failed', 'Failed to set autoload', 4)
            return false
        end
    else
        local success = pcall(function()
            if isfile(autoLoadFile) then
                delfile(autoLoadFile)
            end
        end)
        
        if success then
            self.autoLoadConfig = nil
            self:safeNotify('info', 'AutoLoad Disabled', 'Automatic config loading disabled', 3)
            return true
        else
            self:safeNotify('error', 'AutoLoad Failed', 'Failed to disable autoload', 4)
            return false
        end
    end
end

-- Check and execute auto-load
function ConfigManager:checkAutoLoad()
    local autoLoadFile = self.configFolder .. '/autoload.txt'
    
    if not isfile(autoLoadFile) then
        return false
    end
    
    local success, configName = pcall(function()
        return readfile(autoLoadFile)
    end)
    
    if success and configName and configName ~= '' then
        local configFile = self.configFolder .. '/' .. configName .. '.json'
        if not isfile(configFile) then
            self:safeNotify('warning', 'AutoLoad Error', 'AutoLoad config "' .. configName .. '" not found. Disabled autoload.', 4)
            self:setAutoLoad(nil)
            return false
        end
        
        self:safeNotify('info', 'AutoLoad Active', 'Loading config "' .. configName .. '"...', 3)
        
        task.wait(0.5)
        return self:loadConfig(configName)
    end
    
    return false
end

-- Get configuration metadata
function ConfigManager:getConfigMetadata(configName)
    local filePath = self.configFolder .. '/' .. configName .. '.json'
    
    if not isfile(filePath) then
        return nil
    end
    
    local success, result = pcall(function()
        local fileContent = readfile(filePath)
        local configData = self.httpService:JSONDecode(fileContent)
        return configData.metadata
    end)
    
    return success and result or nil
end

-- Export configuration
function ConfigManager:exportConfig(configName)
    local filePath = self.configFolder .. '/' .. configName .. '.json'
    
    if not isfile(filePath) then
        self:safeNotify('error', 'Export Failed', 'Config "' .. configName .. '" does not exist!', 3)
        return nil
    end
    
    local success, content = pcall(function()
        return readfile(filePath)
    end)
    
    if success then
        self:safeNotify('success', 'Export Success', 'Config "' .. configName .. '" exported to clipboard!', 4)
        return content
    else
        self:safeNotify('error', 'Export Failed', 'Failed to export config', 4)
        return nil
    end
end

-- Import configuration
function ConfigManager:importConfig(importData, newConfigName)
    if not importData or importData == '' then
        self:safeNotify('error', 'Import Failed', 'No import data provided!', 3)
        return false
    end
    
    local isValid, errorMsg = self:validateConfigName(newConfigName)
    if not isValid then
        self:safeNotify('error', 'Invalid Name', errorMsg, 4)
        return false
    end
    
    local success = pcall(function()
        local configData = self.httpService:JSONDecode(importData)
        
        if not configData.settings then
            error('Invalid config format: missing settings')
        end
        
        configData.name = newConfigName
        configData.metadata = configData.metadata or {}
        configData.metadata.imported = os.time()
        configData.metadata.originalName = configData.name
        configData.metadata.importer = player.Name
        
        local jsonString = self.httpService:JSONEncode(configData)
        writefile(self.configFolder .. '/' .. newConfigName .. '.json', jsonString)
        
        return true
    end)
    
    if success then
        self:updateConfigList()
        self:safeNotify('success', 'Import Success', 'Config "' .. newConfigName .. '" imported successfully!', 4)
        return true
    else
        self:safeNotify('error', 'Import Failed', 'Failed to import config - check the data format', 4)
        return false
    end
end

-- Get executor information
function ConfigManager:getExecutorInfo()
    return self.executorInfo
end

-- Get current configuration name
function ConfigManager:getCurrentConfig()
    return self.currentConfig
end

-- Get auto-load configuration
function ConfigManager:getAutoLoadConfig()
    return self.autoLoadConfig
end

-- Cleanup
function ConfigManager:destroy()
    self.uiInstance = nil
    self.configDropdown = nil
    self.notificationSystem = nil
    self.isInitialized = false
end

return ConfigManager
