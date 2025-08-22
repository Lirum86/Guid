-- ConfigManager.lua - Executor-Optimized Config System
-- Robust config system with full executor compatibility and automatic UI integration

local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- System Konstanten
local SYSTEM_VERSION = "2.1"
local CONFIG_FOLDER = "LynixHub_Configs"
local AUTOLOAD_FILE = "autoload.txt"
local DEFAULT_CONFIG = "default"

-- Executor File System Detection (umfassende Kompatibilit\u00e4t)
local function getFileSystemType()
    local fs = {
        hasListFiles = typeof(listfiles) == "function",
        hasIsFolder = typeof(isfolder) == "function",
        hasMakeFolder = typeof(makefolder) == "function",
        hasIsFile = typeof(isfile) == "function",
        hasWriteFile = typeof(writefile) == "function",
        hasReadFile = typeof(readfile) == "function",
        hasDelFile = typeof(delfile) == "function"
    }
    
    fs.hasBasicFS = fs.hasIsFile and fs.hasWriteFile and fs.hasReadFile
    fs.hasFullFS = fs.hasBasicFS and fs.hasMakeFolder and fs.hasIsFolder
    
    return fs
end

local fileSystem = getFileSystemType()

-- Sichere Directory Operations
local function safeCreateDirectory(path)
    if not fileSystem.hasFullFS then return false end
    
    local success = pcall(function()
        if not isfolder(path) then
            makefolder(path)
        end
    end)
    
    return success and isfolder(path)
end

-- Sichere File Operations mit Executor Fallbacks
local function safeWriteFile(path, content)
    if not fileSystem.hasWriteFile then return false end
    
    local success = pcall(function()
        writefile(path, content)
    end)
    
    return success
end

local function safeReadFile(path)
    if not fileSystem.hasReadFile or not fileSystem.hasIsFile then return nil end
    
    local success, content = pcall(function()
        if isfile(path) then
            return readfile(path)
        end
        return nil
    end)
    
    return success and content or nil
end

local function safeDeleteFile(path)
    if not fileSystem.hasIsFile then return false end
    
    local success = pcall(function()
        if isfile(path) then
            if fileSystem.hasDelFile then
                delfile(path)
            else
                -- Fallback: Datei leeren wenn delfile nicht verf\u00fcgbar
                writefile(path, "")
            end
        end
    end)
    
    return success
end

local function safeListFiles(directory)
    if not fileSystem.hasListFiles or not fileSystem.hasIsFolder then return {} end
    
    local success, files = pcall(function()
        if isfolder(directory) then
            return listfiles(directory) or {}
        end
        return {}
    end)
    
    return success and files or {}
end

-- ConfigManager Constructor
function ConfigManager.new(hubInstance)
    local self = setmetatable({}, ConfigManager)
    
    -- Core Properties
    self.hubInstance = hubInstance
    self.configFolder = CONFIG_FOLDER
    self.currentConfig = DEFAULT_CONFIG
    self.autoLoadConfig = nil
    self.httpService = HttpService
    self.isInitialized = false
    self.hasFileSystem = fileSystem.hasBasicFS
    
    -- Memory Store f\u00fcr Executors ohne File System
    self.memoryStore = {
        configs = {},
        autoLoad = nil
    }
    
    -- Debug Info
    print("[ConfigManager] File System Support:")
    print("  - Basic FS: " .. tostring(fileSystem.hasBasicFS))
    print("  - Full FS: " .. tostring(fileSystem.hasFullFS))
    print("  - listfiles: " .. tostring(fileSystem.hasListFiles))
    
    -- Verz\u00f6gerte Initialisierung
    self:delayedInitialize()
    
    return self
end

-- Verz\u00f6gerte Initialisierung
function ConfigManager:delayedInitialize()
    task.spawn(function()
        local attempts = 0
        local maxAttempts = 10
        
        while attempts < maxAttempts do
            attempts = attempts + 1
            
            -- Warte bis GUI vollst\u00e4ndig geladen ist
            if self.hubInstance and self.hubInstance.tabs and #self.hubInstance.tabs > 0 then
                local success = self:initializeConfigSystem()
                if success then
                    self.isInitialized = true
                    self:safeNotify('success', 'Config System', 'Ready! (FS: ' .. (self.hasFileSystem and 'Yes' or 'Memory') .. ')', 3)
                    
                    -- Debug: Alle registrierten Elemente anzeigen
                    self:printAllRegisteredElements()
                    
                    -- AutoLoad nach erfolgreicher Initialisierung
                    self:checkAutoLoad()
                    break
                end
            end
            
            task.wait(0.1)
        end
        
        if not self.isInitialized then
            self:safeNotify('error', 'Config System', 'Failed to initialize after ' .. maxAttempts .. ' attempts')
        end
    end)
end

-- Config System Initialisierung
function ConfigManager:initializeConfigSystem()
    local success = pcall(function()
        -- File System Setup wenn verf\u00fcgbar
        if self.hasFileSystem then
            self:setupFileSystem()
        else
            self:safeNotify('warning', 'File System', 'Using memory storage only - configs lost on restart', 4)
        end
        
        -- Default Config erstellen
        self:ensureDefaultConfig()
        
        print("[ConfigManager] Initialization complete")
        return true
    end)
    
    if not success then
        print("[ConfigManager] Initialization failed")
    end
    
    return success
end

-- File System Setup mit mehreren Fallbacks
function ConfigManager:setupFileSystem()
    if not fileSystem.hasFullFS then 
        print("[ConfigManager] Limited file system - trying memory + basic files")
        return 
    end
    
    -- Verschiedene Pfade probieren
    local paths = {
        self.configFolder,
        "workspace/" .. self.configFolder,
        "autoexec/" .. self.configFolder
    }
    
    for _, path in ipairs(paths) do
        if safeCreateDirectory(path) then
            self.configFolder = path
            print("[ConfigManager] Using config directory: " .. path)
            return
        end
    end
    
    print("[ConfigManager] Could not create config directory, using current: " .. self.configFolder)
end

-- Default Config sicherstellen
function ConfigManager:ensureDefaultConfig()
    if not self:configExists(DEFAULT_CONFIG) then
        self:createDefaultConfig()
    end
end

-- Default Config erstellen
function ConfigManager:createDefaultConfig()
    local defaultData = self:createDefaultConfigData()
    return self:saveConfigData(DEFAULT_CONFIG, defaultData)
end

-- Default Config Daten
function ConfigManager:createDefaultConfigData()
    return {
        name = DEFAULT_CONFIG,
        settings = {
            metadata = {
                version = SYSTEM_VERSION,
                timestamp = os.time(),
                playerName = Players.LocalPlayer.Name
            },
            globalSettings = {
                menuToggleKey = "RightShift",
                watermarkVisible = true,
                themeColor = {r = 110, g = 117, b = 243}
            },
            tabs = {}
        },
        metadata = {
            version = SYSTEM_VERSION,
            created = os.time(),
            lastModified = os.time(),
            creator = Players.LocalPlayer.Name,
            description = "Default LynixHub configuration"
        }
    }
end

-- Settings von der GUI sammeln (robust)
function ConfigManager:gatherAllSettings()
    if not self.hubInstance then
        return self:createDefaultConfigData().settings
    end
    
    local settings = {
        metadata = {
            version = SYSTEM_VERSION,
            timestamp = os.time(),
            playerName = Players.LocalPlayer.Name
        },
        globalSettings = {
            menuToggleKey = "RightShift",
            watermarkVisible = true,
            themeColor = {r = 110, g = 117, b = 243}
        },
        elements = {},
        tabs = {}
    }
    
    -- Sichere Sammlung der globalen Settings
    pcall(function()
        if self.hubInstance._toggleKeyCode then
            settings.globalSettings.menuToggleKey = self.hubInstance._toggleKeyCode.Name
        end
        
        if self.hubInstance._watermarkVisible ~= nil then
            settings.globalSettings.watermarkVisible = self.hubInstance._watermarkVisible
        end
        
        if self.hubInstance.options and self.hubInstance.options.theme and self.hubInstance.options.theme.primary then
            settings.globalSettings.themeColor = self:colorToRGB(self.hubInstance.options.theme.primary)
        end
    end)
    
    -- Tab-spezifische Settings sammeln (vereinfacht aber robuster)
    pcall(function()
        if self.hubInstance.tabs then
            for i, tab in ipairs(self.hubInstance.tabs) do
                if tab and tab.frame then
                    local tabName = tab.frame.Name:gsub("Content", "")
                    if tabName ~= "Settings" then
                        settings.tabs[tabName] = {
                            index = i,
                            hasContent = true
                            -- Detaillierte Element-Sammlung k\u00f6nnte hier erweitert werden
                        }
                    end
                end
            end
        end
    end)
    
    -- Alle registrierten UI-Elemente sammeln (neue Methode)
    self:gatherRegisteredElements(settings)
    
    return settings
end

-- Sammle alle registrierten UI-Elemente
function ConfigManager:gatherRegisteredElements(settings)
    if self.hubInstance._getAllRegisteredElements then
        local elements = self.hubInstance:_getAllRegisteredElements()
        local elementCount = 0
        for _ in pairs(elements or {}) do elementCount = elementCount + 1 end
        print("[ConfigManager] Found " .. elementCount .. " registered elements")
        
        for elementId, element in pairs(elements or {}) do
            -- Auto Load Checkbox NICHT in Configs speichern
            if element.path and element.path:find("Auto Load Config") then
                print("[ConfigManager] Skipping Auto Load Checkbox from config save: " .. element.path)
                goto continue
            end
            
            local success, value = pcall(function()
                if element.api and element.api.GetValue then
                    local rawValue = element.api.GetValue()
                    
                    -- Spezielle Behandlung für verschiedene Typen
                    if element.type == "colorpicker" and typeof(rawValue) == "Color3" then
                        return self:colorToRGB(rawValue)
                    elseif element.type == "keybind" then
                        return tostring(rawValue)
                    elseif element.type == "multidropdown" and type(rawValue) == "table" then
                        -- MultiDropdown als Array der ausgewählten Keys speichern
                        local selected = {}
                        for key, isSelected in pairs(rawValue) do
                            if isSelected then
                                table.insert(selected, key)
                            end
                        end
                        return selected
                    elseif element.type == "button" then
                        -- Buttons speichern ihren Text-Wert
                        return tostring(rawValue)
                    else
                        return rawValue
                    end
                end
                return nil
            end)
            
            if success and value ~= nil then
                settings.elements[elementId] = {
                    type = element.type,
                    tabName = element.tabName,
                    windowName = element.windowName,
                    elementName = element.elementName,
                    path = element.path,
                    value = value
                }
                print("[ConfigManager] Saved element: " .. element.path .. " = " .. tostring(value))
            end
            
            ::continue::
        end
    else
        print("[ConfigManager] No element registry found in hubInstance")
    end
end

-- Settings auf GUI anwenden (robust)
function ConfigManager:applySettings(settings)
    if not settings or not self.hubInstance then 
        self:safeNotify('error', 'Apply Settings', 'Invalid settings data or no UI instance')
        return false 
    end
    
    local success = pcall(function()
        -- Globale Settings anwenden
        if settings.globalSettings then
            if settings.globalSettings.menuToggleKey then
                self.hubInstance:SetToggleKey(settings.globalSettings.menuToggleKey)
            end
            
            if settings.globalSettings.watermarkVisible ~= nil then
                self.hubInstance:SetWatermarkVisible(settings.globalSettings.watermarkVisible)
            end
            
            if settings.globalSettings.themeColor then
                local color = self:rgbToColor(settings.globalSettings.themeColor)
                self.hubInstance:SetTheme({primary = color})
            end
        end
        
        -- Element Settings anwenden
        if settings.elements then
            self:applyElementSettings(settings.elements)
        end
        
        return true
    end)
    
    if not success then
        self:safeNotify('error', 'Apply Settings', 'Failed to apply configuration')
    end
    
    return success
end

-- Element Settings anwenden
function ConfigManager:applyElementSettings(elements)
    if not self.hubInstance._getAllRegisteredElements then
        print("[ConfigManager] No element registry found for applying settings")
        return
    end
    
    local registeredElements = self.hubInstance:_getAllRegisteredElements()
    local appliedCount = 0
    
    for elementId, savedElement in pairs(elements) do
        -- Auto Load Checkbox NICHT von Configs laden
        if savedElement.path and savedElement.path:find("Auto Load Config") then
            print("[ConfigManager] Skipping Auto Load Checkbox from config load: " .. savedElement.path)
            goto continue
        end
        
        local registeredElement = registeredElements[elementId]
        
        if registeredElement and registeredElement.api and registeredElement.api.SetValue then
            local success = pcall(function()
                local value = savedElement.value
                
                -- Spezielle Behandlung für verschiedene Typen
                if savedElement.type == "colorpicker" and type(value) == "table" then
                    value = self:rgbToColor(value)
                elseif savedElement.type == "keybind" and type(value) == "string" then
                    -- Keybind bleibt als String
                elseif savedElement.type == "multidropdown" and type(value) == "table" then
                    -- MultiDropdown: Array in Map konvertieren
                    local selectedMap = {}
                    for _, key in ipairs(value) do
                        selectedMap[key] = true
                    end
                    value = selectedMap
                elseif savedElement.type == "button" and type(value) == "string" then
                    -- Button Text setzen
                    value = tostring(value)
                end
                
                registeredElement.api.SetValue(value)
                appliedCount = appliedCount + 1
                print("[ConfigManager] Restored element: " .. savedElement.path .. " = " .. tostring(value))
            end)
            
            if not success then
                print("[ConfigManager] Failed to restore element: " .. savedElement.path)
            end
        else
            print("[ConfigManager] Element not found in registry: " .. savedElement.path)
        end
        
        ::continue::
    end
    
    print("[ConfigManager] Applied " .. appliedCount .. " element settings")
end

-- Config speichern (executor-optimiert)
function ConfigManager:saveConfig(configName)
    if not configName or configName == "" then
        self:safeNotify('error', 'Save Failed', 'Config name cannot be empty!')
        return false
    end
    
    -- Aktuelle Settings sammeln
    local settings = self:gatherAllSettings()
    
    -- Config Objekt erstellen
    local configData = {
        name = configName,
        settings = settings,
        metadata = {
            version = SYSTEM_VERSION,
            created = os.time(),
            lastModified = os.time(),
            creator = Players.LocalPlayer.Name,
            description = "LynixHub configuration: " .. configName
        }
    }
    
    -- Speichern
    local success = self:saveConfigData(configName, configData)
    
    if success then
        self.currentConfig = configName
        self:safeNotify('success', 'Config Saved', 'Configuration "' .. configName .. '" saved successfully!', 3)
        return true
    else
        self:safeNotify('error', 'Save Failed', 'Could not save configuration!')
        return false
    end
end

-- Config laden (executor-optimiert)
function ConfigManager:loadConfig(configName)
    if not configName or configName == "" then
        self:safeNotify('error', 'Load Failed', 'Config name cannot be empty!')
        return false
    end
    
    local configData = self:loadConfigData(configName)
    
    if not configData then
        self:safeNotify('error', 'Load Failed', 'Configuration "' .. configName .. '" not found!')
        return false
    end
    
    -- Settings anwenden
    local success = self:applySettings(configData.settings)
    
    if success then
        self.currentConfig = configName
        self:safeNotify('success', 'Config Loaded', 'Configuration "' .. configName .. '" loaded successfully!', 3)
        return true
    else
        self:safeNotify('error', 'Load Failed', 'Could not apply configuration!')
        return false
    end
end

-- Config erstellen
function ConfigManager:createConfig(configName)
    if not configName or configName == "" then
        self:safeNotify('error', 'Create Failed', 'Config name cannot be empty!')
        return false
    end
    
    -- Prüfen ob bereits existiert
    if self:configExists(configName) then
        self:safeNotify('warning', 'Config Exists', 'Configuration "' .. configName .. '" already exists!')
        return false
    end
    
    -- Aktuelle Settings als neue Config speichern
    local success = self:saveConfig(configName)
    
    if success then
        self:safeNotify('success', 'Config Created', 'Configuration "' .. configName .. '" created successfully!', 3)
    end
    
    return success
end

-- Config l\u00f6schen
function ConfigManager:deleteConfig(configName)
    if not configName or configName == "" or configName == DEFAULT_CONFIG then
        self:safeNotify('error', 'Delete Failed', 'Cannot delete default configuration!')
        return false
    end
    
    local success = false
    
    if self.hasFileSystem then
        local filePath = self.configFolder .. "/" .. configName .. ".json"
        success = safeDeleteFile(filePath)
    else
        if self.memoryStore.configs[configName] then
            self.memoryStore.configs[configName] = nil
            success = true
        end
    end
    
    if success then
        -- AutoLoad zur\u00fccksetzen falls gel\u00f6schte Config
        local currentAutoLoad = self:getAutoLoad()
        if currentAutoLoad == configName then
            print("[ConfigManager] Deleted config was AutoLoad config, clearing AutoLoad setting")
            self:setAutoLoad(nil)
            self.autoLoadConfig = nil
        end
        
        self:safeNotify('success', 'Config Deleted', 'Configuration "' .. configName .. '" deleted successfully!', 3)
        return true
    else
        self:safeNotify('error', 'Delete Failed', 'Could not delete configuration!')
        return false
    end
end

-- Config Daten speichern (Executor-sicher)
function ConfigManager:saveConfigData(configName, configData)
    if self.hasFileSystem then
        local filePath = self.configFolder .. "/" .. configName .. ".json"
        
        local success, jsonString = pcall(function()
            return self.httpService:JSONEncode(configData)
        end)
        
        if success and jsonString then
            return safeWriteFile(filePath, jsonString)
        else
            print("[ConfigManager] JSON encoding failed for config: " .. configName)
            return false
        end
    else
        -- Memory Storage
        self.memoryStore.configs[configName] = configData
        return true
    end
end

-- Config Daten laden (Executor-sicher)
function ConfigManager:loadConfigData(configName)
    if self.hasFileSystem then
        local filePath = self.configFolder .. "/" .. configName .. ".json"
        local fileContent = safeReadFile(filePath)
        
        if fileContent then
            local success, result = pcall(function()
                return self.httpService:JSONDecode(fileContent)
            end)
            
            if success and result then
                return result
            else
                print("[ConfigManager] JSON decoding failed for config: " .. configName)
            end
        end
    else
        return self.memoryStore.configs[configName]
    end
    
    return nil
end

-- Config existiert prüfen
function ConfigManager:configExists(configName)
    if self.hasFileSystem then
        local filePath = self.configFolder .. "/" .. configName .. ".json"
        return fileSystem.hasIsFile and isfile(filePath)
    else
        return self.memoryStore.configs[configName] ~= nil
    end
end

-- Config Liste abrufen (Executor-kompatibel)
function ConfigManager:getConfigList()
    local configs = {}
    
    if self.hasFileSystem then
        local files = safeListFiles(self.configFolder)
        
        for _, filePath in ipairs(files) do
            local fileName = filePath:match("[/\\\\]([^/\\\\]+)%.json$")
            if fileName then
                table.insert(configs, fileName)
            end
        end
        
        -- Fallback: Wenn listfiles nicht funktioniert, versuche bekannte Configs
        if #configs == 0 then
            local knownConfigs = {DEFAULT_CONFIG, "config1", "config2", "test"}
            for _, name in ipairs(knownConfigs) do
                if self:configExists(name) then
                    table.insert(configs, name)
                end
            end
        end
    else
        for configName, _ in pairs(self.memoryStore.configs) do
            table.insert(configs, configName)
        end
    end
    
    -- Default Config sicherstellen
    if not table.find(configs, DEFAULT_CONFIG) then
        table.insert(configs, 1, DEFAULT_CONFIG)
    end
    
    table.sort(configs)
    return configs
end

-- AutoLoad System (Executor-optimiert)
function ConfigManager:setAutoLoad(configName)
    if self.hasFileSystem then
        local autoLoadPath = self.configFolder .. "/" .. AUTOLOAD_FILE
        
        if configName and configName ~= "" then
            safeWriteFile(autoLoadPath, configName)
        else
            safeDeleteFile(autoLoadPath)
        end
    else
        self.memoryStore.autoLoad = configName
    end
    
    self.autoLoadConfig = configName
end

function ConfigManager:getAutoLoad()
    if self.hasFileSystem then
        local autoLoadPath = self.configFolder .. "/" .. AUTOLOAD_FILE
        return safeReadFile(autoLoadPath)
    else
        return self.memoryStore.autoLoad
    end
end

function ConfigManager:checkAutoLoad()
    local autoLoadConfig = self:getAutoLoad()
    
    if autoLoadConfig and autoLoadConfig ~= "" and self:configExists(autoLoadConfig) then
        print("[ConfigManager] AutoLoading config: " .. autoLoadConfig)
        return self:loadConfig(autoLoadConfig)
    end
    
    return false
end

-- Utility Functions
function ConfigManager:colorToRGB(color)
    if typeof(color) ~= "Color3" then 
        return {r = 110, g = 117, b = 243}
    end
    return {
        r = math.floor(color.R * 255 + 0.5),
        g = math.floor(color.G * 255 + 0.5),
        b = math.floor(color.B * 255 + 0.5)
    }
end

function ConfigManager:rgbToColor(rgb)
    if type(rgb) ~= "table" then 
        return Color3.fromRGB(110, 117, 243)
    end
    return Color3.fromRGB(
        tonumber(rgb.r) or 110,
        tonumber(rgb.g) or 117,
        tonumber(rgb.b) or 243
    )
end

-- Sichere Notification mit mehreren Fallbacks
function ConfigManager:safeNotify(notifType, title, message, duration)
    duration = duration or 3
    
    -- Versuche über hubInstance zu notifizieren
    local success = pcall(function()
        if self.hubInstance and self.hubInstance.notifications then
            local method = self.hubInstance.notifications[notifType]
            if method and type(method) == "function" then
                method(self.hubInstance.notifications, title, message, duration)
                return true
            end
        end
        return false
    end)
    
    -- Fallback zu print mit Formatierung
    if not success then
        local prefix = string.upper(notifType)
        local formattedMessage = string.format("[%s] %s: %s", prefix, title, message)
        print(formattedMessage)
        
        -- Zusätzlich warn() für Errors
        if notifType == "error" then
            warn(formattedMessage)
        end
    end
end

-- Debug Information
function ConfigManager:getDebugInfo()
    local elementCount = 0
    local elementTypes = {}
    local elementsByTab = {}
    
    if self.hubInstance and self.hubInstance._getAllRegisteredElements then
        local elements = self.hubInstance:_getAllRegisteredElements()
        for _, element in pairs(elements or {}) do
            elementCount = elementCount + 1
            elementTypes[element.type] = (elementTypes[element.type] or 0) + 1
            
            if not elementsByTab[element.tabName] then
                elementsByTab[element.tabName] = {}
            end
            if not elementsByTab[element.tabName][element.windowName] then
                elementsByTab[element.tabName][element.windowName] = 0
            end
            elementsByTab[element.tabName][element.windowName] = elementsByTab[element.tabName][element.windowName] + 1
        end
    end
    
    return {
        initialized = self.isInitialized,
        hasFileSystem = self.hasFileSystem,
        configFolder = self.configFolder,
        currentConfig = self.currentConfig,
        autoLoad = self.autoLoadConfig,
        memoryConfigs = self.hasFileSystem and 0 or table.getn(self.memoryStore.configs or {}),
        fileSystemDetails = fileSystem,
        registeredElements = {
            total = elementCount,
            byType = elementTypes,
            byTab = elementsByTab
        }
    }
end

-- Debug: Alle registrierten Elemente anzeigen
function ConfigManager:printAllRegisteredElements()
    if not self.hubInstance or not self.hubInstance._getAllRegisteredElements then
        print("[ConfigManager] No element registry available")
        return
    end
    
    local elements = self.hubInstance:_getAllRegisteredElements()
    print("[ConfigManager] ===== REGISTERED ELEMENTS =====")
    
    for elementId, element in pairs(elements or {}) do
        print(string.format("[ConfigManager] %s: %s (%s) - %s", 
            elementId, 
            element.path, 
            element.type, 
            element.elementName
        ))
    end
    
    print("[ConfigManager] ===== END REGISTERED ELEMENTS =====")
end

return ConfigManager
