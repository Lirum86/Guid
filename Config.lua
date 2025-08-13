-- ConfigManager.lua - RadiantHub Style Config System
-- Vollständige Integration mit automatischer Settings-Erfassung und persistenter Speicherung

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

-- File System Detection (Executor compatibility)
local function hasFileSystem()
    return typeof(isfolder) == "function" 
        and typeof(makefolder) == "function"
        and typeof(isfile) == "function" 
        and typeof(writefile) == "function"
        and typeof(readfile) == "function"
        and typeof(delfile) == "function"
end

-- ConfigManager Constructor
function ConfigManager.new(hubInstance)
    local self = setmetatable({}, ConfigManager)
    
    -- Core Properties
    self.hubInstance = hubInstance  -- Referenz zur Haupt-GUI
    self.configFolder = CONFIG_FOLDER
    self.currentConfig = DEFAULT_CONFIG
    self.autoLoadConfig = nil
    self.httpService = HttpService
    self.isInitialized = false
    
    -- Internal State
    self.memoryStore = {
        configs = {},
        currentData = {},
        autoLoad = nil
    }
    
    -- Verzögerte Initialisierung wenn GUI bereit ist
    self:delayedInitialize()
    
    return self
end

-- Verzögerte Initialisierung
function ConfigManager:delayedInitialize()
    task.spawn(function()
        local attempts = 0
        local maxAttempts = 20
        
        while attempts < maxAttempts do
            attempts = attempts + 1
            
            -- Warte bis GUI vollständig geladen ist
            if self.hubInstance and self.hubInstance.tabs then
                task.wait(0.5) -- Zusätzliche Wartezeit für vollständige UI-Initialisierung
                
                local success = self:initializeConfigSystem()
                if success then
                    self.isInitialized = true
                    self:safeNotify('info', 'Config System', 'Ready!', 2)
                    break
                end
            end
            
            task.wait(0.2)
        end
        
        if not self.isInitialized then
            self:safeNotify('error', 'Config System', 'Failed to initialize!')
        end
    end)
end

-- Config System Initialisierung
function ConfigManager:initializeConfigSystem()
    local success = pcall(function()
        -- File System Setup
        if hasFileSystem() then
            self:setupFileSystem()
        else
            self:safeNotify('warning', 'File System', 'Using memory storage only')
        end
        
        -- Default Config erstellen
        self:ensureDefaultConfig()
        
        -- AutoLoad prüfen
        self:checkAutoLoad()
        
        -- Settings Tab Integration
        self:integrateWithSettingsTab()
        
        return true
    end)
    
    return success
end

-- File System Setup
function ConfigManager:setupFileSystem()
    -- Hauptordner erstellen
    if not isfolder(self.configFolder) then
        makefolder(self.configFolder)
    end
    
    -- Workspace Ordner für Executor Compatibility
    if not isfolder("workspace") then
        makefolder("workspace")
    end
    
    -- Config Unterordner in workspace
    local workspaceConfigPath = "workspace/" .. self.configFolder
    if not isfolder(workspaceConfigPath) then
        makefolder(workspaceConfigPath)
    end
end

-- Default Config sicherstellen
function ConfigManager:ensureDefaultConfig()
    if hasFileSystem() then
        local defaultPath = self.configFolder .. "/" .. DEFAULT_CONFIG .. ".json"
        if not isfile(defaultPath) then
            self:createDefaultConfig()
        end
    else
        -- Memory Storage
        if not self.memoryStore.configs[DEFAULT_CONFIG] then
            self.memoryStore.configs[DEFAULT_CONFIG] = self:createDefaultConfigData()
        end
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

-- Settings von der GUI sammeln
function ConfigManager:gatherAllSettings()
    if not self.hubInstance then
        return {}
    end
    
    local settings = {
        metadata = {
            version = SYSTEM_VERSION,
            timestamp = os.time(),
            playerName = Players.LocalPlayer.Name
        },
        globalSettings = {
            menuToggleKey = (self.hubInstance._toggleKeyCode and self.hubInstance._toggleKeyCode.Name) or "RightShift",
            watermarkVisible = self.hubInstance._watermarkVisible ~= false,
            themeColor = self:colorToRGB(self.hubInstance.options.theme.primary)
        },
        tabs = {}
    }
    
    -- Alle Tabs durchlaufen
    for i, tab in ipairs(self.hubInstance.tabs) do
        if tab and tab.frame and tab.frame.Name and tab.frame.Name ~= "Settings" then
            local tabName = tab.frame.Name:gsub("Content", "")
            settings.tabs[tabName] = {
                windows = {}
            }
            
            -- Alle Windows in diesem Tab durchlaufen
            settings.tabs[tabName].windows = self:gatherWindowSettings(tab.frame)
        end
    end
    
    return settings
end

-- Window Settings sammeln
function ConfigManager:gatherWindowSettings(tabFrame)
    local windows = {}
    
    -- Column Container finden
    local columnsContainer = tabFrame:FindFirstChild("ColumnsContainer")
    if not columnsContainer then return windows end
    
    -- Beide Columns durchgehen
    for _, column in ipairs({columnsContainer:FindFirstChild("Column1"), columnsContainer:FindFirstChild("Column2")}) do
        if column then
            for _, window in ipairs(column:GetChildren()) do
                if window:IsA("Frame") and window.Name:match("Window$") then
                    local windowName = window.Name:gsub("Window", "")
                    windows[windowName] = {
                        elements = self:gatherElementSettings(window)
                    }
                end
            end
        end
    end
    
    return windows
end

-- Element Settings sammeln
function ConfigManager:gatherElementSettings(window)
    local elements = {}
    
    local contentArea = window:FindFirstChild("ContentArea")
    if not contentArea then return elements end
    
    -- Alle UI Elemente durchgehen
    for _, container in ipairs(contentArea:GetChildren()) do
        if container:IsA("Frame") then
            local elementData = self:extractElementValue(container)
            if elementData then
                elements[elementData.name] = {
                    type = elementData.type,
                    value = elementData.value
                }
            end
        end
    end
    
    return elements
end

-- Einzelne Element Werte extrahieren
function ConfigManager:extractElementValue(container)
    local containerName = container.Name
    
    -- Checkbox
    if containerName:match("CheckboxContainer") then
        local checkbox = container:FindFirstChild("Checkbox")
        local label = container:FindFirstChild("Label")
        if checkbox and label then
            local isEnabled = checkbox.BackgroundColor3 == self.hubInstance.options.theme.primary
            return {
                name = label.Text,
                type = "checkbox",
                value = isEnabled
            }
        end
    end
    
    -- Slider
    if containerName:match("SliderContainer") then
        local label = container:FindFirstChild("Label")
        local valueLabel = container:FindFirstChild("ValueLabel")
        if label and valueLabel then
            return {
                name = label.Text,
                type = "slider", 
                value = tonumber(valueLabel.Text) or 0
            }
        end
    end
    
    -- Dropdown
    if containerName:match("DropdownContainer") then
        local label = container:FindFirstChild("Label")
        local button = container:FindFirstChild("DropdownButton")
        if label and button then
            return {
                name = label.Text,
                type = "dropdown",
                value = button.Text
            }
        end
    end
    
    -- MultiDropdown
    if containerName:match("MultiDropdownContainer") then
        local label = container:FindFirstChild("Label")
        local button = container:FindFirstChild("MultiDropdownButton")
        if label and button then
            return {
                name = label.Text,
                type = "multidropdown",
                value = button.Text
            }
        end
    end
    
    -- ColorPicker
    if containerName:match("ColorPickerContainer") then
        local label = container:FindFirstChild("Label")
        local preview = container:FindFirstChild("ColorPreview")
        if label and preview then
            return {
                name = label.Text,
                type = "colorpicker",
                value = self:colorToRGB(preview.BackgroundColor3)
            }
        end
    end
    
    -- TextBox
    if containerName:match("TextBox") then
        local textBox = container:FindFirstChildWhichIsA("TextBox")
        if textBox then
            return {
                name = "TextInput",
                type = "textbox",
                value = textBox.Text
            }
        end
    end
    
    -- Keybind
    if containerName:match("KeybindContainer") then
        local label = container:FindFirstChild("Label")
        local button = container:FindFirstChild("KeybindButton")
        if label and button then
            local keyText = button.Text:gsub("Bind: ", "")
            return {
                name = label.Text,
                type = "keybind",
                value = keyText
            }
        end
    end
    
    return nil
end

-- Settings auf GUI anwenden
function ConfigManager:applySettings(settings)
    if not settings or not self.hubInstance then return false end
    
    local success = pcall(function()
        -- Globale Settings anwenden
        if settings.globalSettings then
            self:applyGlobalSettings(settings.globalSettings)
        end
        
        -- Tab Settings anwenden
        if settings.tabs then
            self:applyTabSettings(settings.tabs)
        end
    end)
    
    return success
end

-- Globale Settings anwenden
function ConfigManager:applyGlobalSettings(globalSettings)
    if globalSettings.menuToggleKey then
        self.hubInstance:SetToggleKey(globalSettings.menuToggleKey)
    end
    
    if globalSettings.watermarkVisible ~= nil then
        self.hubInstance:SetWatermarkVisible(globalSettings.watermarkVisible)
    end
    
    if globalSettings.themeColor then
        local color = self:rgbToColor(globalSettings.themeColor)
        self.hubInstance:SetTheme({primary = color})
    end
end

-- Tab Settings anwenden (vereinfacht - full implementation würde API references brauchen)
function ConfigManager:applyTabSettings(tabSettings)
    -- Hier würde die vollständige Anwendung der Element-Werte stehen
    -- Das erfordert jedoch API-Referenzen zu allen UI-Elementen
    -- Die können über das hubInstance.tabs System verwaltet werden
    
    for tabName, tabData in pairs(tabSettings) do
        if tabData.windows then
            for windowName, windowData in pairs(tabData.windows) do
                if windowData.elements then
                    for elementName, elementData in pairs(windowData.elements) do
                        -- Element finden und Wert setzen
                        -- self:setElementValue(tabName, windowName, elementName, elementData)
                    end
                end
            end
        end
    end
end

-- Config speichern
function ConfigManager:saveConfig(configName)
    if not configName or configName == "" then
        self:safeNotify('error', 'Invalid Name', 'Config name cannot be empty!')
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
        self:safeNotify('success', 'Config Saved', 'Configuration "' .. configName .. '" saved!', 3)
        self:updateConfigList()
        return true
    else
        self:safeNotify('error', 'Save Failed', 'Could not save configuration!')
        return false
    end
end

-- Config laden
function ConfigManager:loadConfig(configName)
    if not configName or configName == "" then
        self:safeNotify('error', 'Invalid Name', 'Config name cannot be empty!')
        return false
    end
    
    local configData = self:loadConfigData(configName)
    
    if not configData then
        self:safeNotify('error', 'Config Not Found', 'Configuration "' .. configName .. '" does not exist!')
        return false
    end
    
    -- Settings anwenden
    local success = self:applySettings(configData.settings)
    
    if success then
        self.currentConfig = configName
        self:safeNotify('success', 'Config Loaded', 'Configuration "' .. configName .. '" loaded!', 4)
        return true
    else
        self:safeNotify('error', 'Load Failed', 'Could not apply configuration!')
        return false
    end
end

-- Config erstellen
function ConfigManager:createConfig(configName)
    if not configName or configName == "" then
        self:safeNotify('error', 'Invalid Name', 'Config name cannot be empty!')
        return false
    end
    
    -- Prüfen ob bereits existiert
    if self:configExists(configName) then
        self:safeNotify('warning', 'Config Exists', 'Configuration "' .. configName .. '" already exists!')
        return false
    end
    
    -- Aktuelle Settings als neue Config speichern
    return self:saveConfig(configName)
end

-- Config löschen
function ConfigManager:deleteConfig(configName)
    if not configName or configName == "" or configName == DEFAULT_CONFIG then
        self:safeNotify('error', 'Cannot Delete', 'Cannot delete default configuration!')
        return false
    end
    
    local success = false
    
    if hasFileSystem() then
        local filePath = self.configFolder .. "/" .. configName .. ".json"
        if isfile(filePath) then
            pcall(function() delfile(filePath) end)
            success = not isfile(filePath)
        end
    else
        if self.memoryStore.configs[configName] then
            self.memoryStore.configs[configName] = nil
            success = true
        end
    end
    
    if success then
        -- AutoLoad zurücksetzen falls gelöschte Config
        if self.autoLoadConfig == configName then
            self:setAutoLoad(nil)
        end
        
        self:safeNotify('success', 'Config Deleted', 'Configuration "' .. configName .. '" deleted!', 3)
        self:updateConfigList()
        return true
    else
        self:safeNotify('error', 'Delete Failed', 'Could not delete configuration!')
        return false
    end
end

-- Config Daten speichern (File System / Memory)
function ConfigManager:saveConfigData(configName, configData)
    local success = false
    
    if hasFileSystem() then
        local filePath = self.configFolder .. "/" .. configName .. ".json"
        local jsonString = self.httpService:JSONEncode(configData)
        
        pcall(function()
            writefile(filePath, jsonString)
            success = isfile(filePath)
        end)
    else
        self.memoryStore.configs[configName] = configData
        success = true
    end
    
    return success
end

-- Config Daten laden (File System / Memory)
function ConfigManager:loadConfigData(configName)
    if hasFileSystem() then
        local filePath = self.configFolder .. "/" .. configName .. ".json"
        if isfile(filePath) then
            local success, result = pcall(function()
                local fileContent = readfile(filePath)
                return self.httpService:JSONDecode(fileContent)
            end)
            return success and result or nil
        end
    else
        return self.memoryStore.configs[configName]
    end
    
    return nil
end

-- Config existiert prüfen
function ConfigManager:configExists(configName)
    if hasFileSystem() then
        local filePath = self.configFolder .. "/" .. configName .. ".json"
        return isfile(filePath)
    else
        return self.memoryStore.configs[configName] ~= nil
    end
end

-- Config Liste abrufen
function ConfigManager:getConfigList()
    local configs = {}
    
    if hasFileSystem() then
        local success, files = pcall(function()
            return listfiles and listfiles(self.configFolder) or {}
        end)
        
        if success and files then
            for _, filePath in ipairs(files) do
                local fileName = filePath:match("[/\\]([^/\\]+)%.json$")
                if fileName then
                    table.insert(configs, fileName)
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

-- AutoLoad System
function ConfigManager:setAutoLoad(configName)
    if hasFileSystem() then
        local autoLoadPath = self.configFolder .. "/" .. AUTOLOAD_FILE
        
        if configName and configName ~= "" then
            pcall(function() writefile(autoLoadPath, configName) end)
        else
            pcall(function() delfile(autoLoadPath) end)
        end
    else
        self.memoryStore.autoLoad = configName
    end
    
    self.autoLoadConfig = configName
end

function ConfigManager:getAutoLoad()
    if hasFileSystem() then
        local autoLoadPath = self.configFolder .. "/" .. AUTOLOAD_FILE
        if isfile(autoLoadPath) then
            local success, result = pcall(function()
                return readfile(autoLoadPath)
            end)
            return success and result or nil
        end
    else
        return self.memoryStore.autoLoad
    end
    
    return nil
end

function ConfigManager:checkAutoLoad()
    local autoLoadConfig = self:getAutoLoad()
    
    if autoLoadConfig and autoLoadConfig ~= "" and self:configExists(autoLoadConfig) then
        task.wait(1) -- Kurz warten damit GUI vollständig initialisiert ist
        return self:loadConfig(autoLoadConfig)
    end
    
    return false
end

-- Settings Tab Integration
function ConfigManager:integrateWithSettingsTab()
    -- Diese Methode wird die Library erweitern um Config Management UI zu integrieren
    -- Das passiert automatisch ohne Benutzereingriff
    if self.hubInstance and self.hubInstance._addConfigManagement then
        self.hubInstance:_addConfigManagement(self)
    end
end

-- Config Liste aktualisieren (Callback für UI)
function ConfigManager:updateConfigList()
    if self.configDropdownApi then
        local configs = self:getConfigList()
        self.configDropdownApi.SetOptions(configs)
    end
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

-- Sichere Notification
function ConfigManager:safeNotify(notifType, title, message, duration)
    duration = duration or 3
    
    local success = pcall(function()
        -- Versuche über hubInstance zu notifizieren
        if self.hubInstance and self.hubInstance.notifications then
            local method = self.hubInstance.notifications[notifType]
            if method and type(method) == "function" then
                method(self.hubInstance.notifications, title, message, duration)
                return true
            end
        end
        return false
    end)
    
    -- Fallback zu print
    if not success then
        local prefix = string.upper(notifType)
        print('[' .. prefix .. '] ' .. title .. ': ' .. message)
    end
end

return ConfigManager
