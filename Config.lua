-- ConfigSystem.lua (Executor Version)
-- Config-System für Roblox Executors (kein Studio)
-- Verwendet writefile/readfile statt ReplicatedStorage

local ConfigSystem = {}

-- Services
local Players = game:GetService('Players')
local HttpService = game:GetService('HttpService')

local player = Players.LocalPlayer

-- Executor File System Check
local hasFileSystem = (writefile and readfile and isfolder and makefolder and delfile and listfiles)

-- Interner State
local configs = {}
local autoLoadConfig = nil
local configFolder = "ModernUI_Configs"

-- Initialisierung
local function init()
    if not hasFileSystem then
        warn("❌ CRITICAL: Executor doesn't support file system! Config system disabled.")
        return false
    end
    
    -- Config Folder erstellen falls nicht existent
    if not isfolder(configFolder) then
        makefolder(configFolder)
        print("📁 Created config folder: " .. configFolder)
    end
    
    -- Lade existierende Configs
    ConfigSystem._loadConfigs()
    
    -- Auto-Load Einstellung laden
    ConfigSystem._loadAutoLoad()
    
    return true
end

-- Private Hilfsfunktionen
function ConfigSystem._serializeValue(value)
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
            x = value.X,
            y = value.Y,
            z = value.Z
        }
    elseif valueType == "Vector2" then
        return {
            _type = "Vector2",
            x = value.X,
            y = value.Y
        }
    elseif valueType == "UDim2" then
        return {
            _type = "UDim2",
            x_scale = value.X.Scale,
            x_offset = value.X.Offset,
            y_scale = value.Y.Scale,
            y_offset = value.Y.Offset
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
            serialized[k] = ConfigSystem._serializeValue(v)
        end
        return serialized
    else
        -- Primitive Typen (string, number, boolean, nil)
        return value
    end
end

function ConfigSystem._deserializeValue(value)
    if type(value) == "table" and value._type then
        if value._type == "Color3" then
            return Color3.fromRGB(
                tonumber(value.r) or 110,
                tonumber(value.g) or 117,
                tonumber(value.b) or 243
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
                tonumber(value.x_scale) or 0,
                tonumber(value.x_offset) or 0,
                tonumber(value.y_scale) or 0,
                tonumber(value.y_offset) or 0
            )
        elseif value._type == "EnumItem" then
            local success, enum = pcall(function()
                local enumType = value.enum_type
                if enumType and value.name then
                    -- Entferne "Enum." Prefix falls vorhanden
                    enumType = enumType:gsub("^Enum%.", "")
                    if Enum[enumType] and Enum[enumType][value.name] then
                        return Enum[enumType][value.name]
                    end
                end
                return nil
            end)
            return success and enum or nil
        end
        return value
    elseif type(value) == "table" then
        local deserialized = {}
        for k, v in pairs(value) do
            deserialized[k] = ConfigSystem._deserializeValue(v)
        end
        return deserialized
    else
        return value
    end
end

function ConfigSystem._getConfigPath(name)
    return configFolder .. "/" .. name .. ".json"
end

function ConfigSystem._loadConfigs()
    if not hasFileSystem then return end
    
    configs = {}
    
    local success, files = pcall(function()
        return listfiles(configFolder)
    end)
    
    if not success then
        warn("ConfigSystem: Fehler beim Laden der Config-Liste")
        return
    end
    
    for _, filePath in ipairs(files) do
        if filePath:match("%.json$") then
            local fileName = filePath:match("([^/\\]+)%.json$")
            if fileName then
                local readSuccess, content = pcall(function()
                    return readfile(filePath)
                end)
                
                if readSuccess and content then
                    local parseSuccess, data = pcall(function()
                        return HttpService:JSONDecode(content)
                    end)
                    
                    if parseSuccess and type(data) == "table" then
                        configs[fileName] = data
                        print("📂 Loaded config: " .. fileName)
                    else
                        warn("ConfigSystem: Fehler beim Parsen von " .. fileName)
                    end
                end
            end
        end
    end
end

function ConfigSystem._saveConfig(name, data)
    if not hasFileSystem then return false end
    
    local filePath = ConfigSystem._getConfigPath(name)
    
    local success, serialized = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    
    if not success then
        warn("ConfigSystem: Fehler beim Serialisieren von " .. name)
        return false
    end
    
    local writeSuccess = pcall(function()
        writefile(filePath, serialized)
    end)
    
    if writeSuccess then
        print("💾 Config gespeichert: " .. filePath)
        return true
    else
        warn("ConfigSystem: Fehler beim Schreiben von " .. name)
        return false
    end
end

function ConfigSystem._loadAutoLoad()
    if not hasFileSystem then return end
    
    local autoLoadPath = configFolder .. "/autoload.txt"
    
    local success, content = pcall(function()
        return readfile(autoLoadPath)
    end)
    
    if success and content and content ~= "" then
        autoLoadConfig = content:gsub("%s+", "") -- Remove whitespace
        print("🔄 Auto-load config: " .. autoLoadConfig)
    end
end

function ConfigSystem._saveAutoLoad()
    if not hasFileSystem then return end
    
    local autoLoadPath = configFolder .. "/autoload.txt"
    
    local success = pcall(function()
        writefile(autoLoadPath, autoLoadConfig or "")
    end)
    
    if success then
        print("💾 Auto-load setting saved")
    else
        warn("ConfigSystem: Fehler beim Speichern der Auto-Load Einstellung")
    end
end

function ConfigSystem._validateConfigName(name)
    if type(name) ~= "string" then
        return false, "Config-Name muss ein String sein"
    end
    
    if name == "" then
        return false, "Config-Name darf nicht leer sein"
    end
    
    if name:match("[^%w%s%-_]") then
        return false, "Config-Name enthält ungültige Zeichen"
    end
    
    if #name > 50 then
        return false, "Config-Name ist zu lang (max. 50 Zeichen)"
    end
    
    return true
end

-- Öffentliche API
function ConfigSystem.Create(name)
    if not init() then return false end
    
    local valid, error = ConfigSystem._validateConfigName(name)
    if not valid then
        warn("ConfigSystem.Create: " .. error)
        return false
    end
    
    local configData = {
        _metadata = {
            created = os.time(),
            version = "1.0",
            executor = true
        }
    }
    
    configs[name] = configData
    
    return ConfigSystem._saveConfig(name, configData)
end

function ConfigSystem.Delete(name)
    if not init() then return false end
    
    if not configs[name] then
        warn("ConfigSystem.Delete: Config '" .. name .. "' existiert nicht")
        return false
    end
    
    configs[name] = nil
    
    -- Lösche Datei
    local filePath = ConfigSystem._getConfigPath(name)
    local success = pcall(function()
        delfile(filePath)
    end)
    
    if success then
        print("🗑️ Config gelöscht: " .. name)
    else
        warn("ConfigSystem.Delete: Fehler beim Löschen der Datei")
    end
    
    -- Auto-Load zurücksetzen falls gelöscht
    if autoLoadConfig == name then
        autoLoadConfig = nil
        ConfigSystem._saveAutoLoad()
    end
    
    return success
end

function ConfigSystem.Save(name, data)
    if not init() then return false end
    
    local valid, error = ConfigSystem._validateConfigName(name)
    if not valid then
        warn("ConfigSystem.Save: " .. error)
        return false
    end
    
    if type(data) ~= "table" then
        warn("ConfigSystem.Save: Data muss eine Tabelle sein")
        return false
    end
    
    -- Erstelle Config falls nicht existent
    if not configs[name] then
        ConfigSystem.Create(name)
    end
    
    -- Serialisiere und speichere
    local serializedData = ConfigSystem._serializeValue(data)
    
    local configData = {
        _metadata = {
            created = configs[name]._metadata and configs[name]._metadata.created or os.time(),
            modified = os.time(),
            version = "1.0",
            executor = true
        }
    }
    
    -- Merge Daten
    for k, v in pairs(serializedData) do
        configData[k] = v
    end
    
    configs[name] = configData
    
    return ConfigSystem._saveConfig(name, configData)
end

function ConfigSystem.Load(name)
    if not init() then return nil end
    
    if not configs[name] then
        warn("ConfigSystem.Load: Config '" .. name .. "' existiert nicht")
        return nil
    end
    
    local configData = {}
    for k, v in pairs(configs[name]) do
        if k ~= "_metadata" then
            configData[k] = ConfigSystem._deserializeValue(v)
        end
    end
    
    return configData
end

function ConfigSystem.List()
    if not init() then return {"Default"} end
    
    local list = {}
    for name, _ in pairs(configs) do
        table.insert(list, name)
    end
    
    table.sort(list)
    
    -- Stelle sicher dass Default immer existiert
    if #list == 0 or not ConfigSystem.Exists("Default") then
        ConfigSystem.Create("Default")
        if not table.find(list, "Default") then
            table.insert(list, "Default")
        end
    end
    
    return list
end

function ConfigSystem.Exists(name)
    if not init() then return false end
    return configs[name] ~= nil
end

function ConfigSystem.GetInfo(name)
    if not init() then return nil end
    
    if not configs[name] then
        return nil
    end
    
    return configs[name]._metadata
end

function ConfigSystem.SetAutoLoad(configName)
    if not init() then return false end
    
    if configName ~= nil and not configs[configName] then
        warn("ConfigSystem.SetAutoLoad: Config '" .. configName .. "' existiert nicht")
        return false
    end
    
    autoLoadConfig = configName
    ConfigSystem._saveAutoLoad()
    return true
end

function ConfigSystem.GetAutoLoad()
    if not init() then return nil end
    return autoLoadConfig
end

function ConfigSystem.Export(name)
    if not init() then return nil end
    
    local configData = ConfigSystem.Load(name)
    if not configData then
        return nil
    end
    
    local exportData = {
        name = name,
        exported = os.time(),
        version = "1.0",
        executor = true,
        data = configData
    }
    
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(exportData)
    end)
    
    return success and encoded or nil
end

function ConfigSystem.Import(encodedData, targetName)
    if not init() then return false end
    
    local success, importData = pcall(function()
        return HttpService:JSONDecode(encodedData)
    end)
    
    if not success or type(importData) ~= "table" then
        warn("ConfigSystem.Import: Ungültige Import-Daten")
        return false
    end
    
    if not importData.data then
        warn("ConfigSystem.Import: Keine Config-Daten gefunden")
        return false
    end
    
    local name = targetName or importData.name
    if not name then
        warn("ConfigSystem.Import: Kein Config-Name angegeben")
        return false
    end
    
    return ConfigSystem.Save(name, importData.data)
end

-- Auto-Load beim Laden des Scripts
function ConfigSystem.AutoLoad()
    if not init() then return nil end
    
    if autoLoadConfig and configs[autoLoadConfig] then
        print("🔄 Auto-loading config: " .. autoLoadConfig)
        return ConfigSystem.Load(autoLoadConfig)
    end
    
    return nil
end

-- Cleanup Funktion
function ConfigSystem.Cleanup()
    configs = {}
    autoLoadConfig = nil
end

-- Erstelle Default Config beim ersten Laden
if hasFileSystem then
    task.spawn(function()
        task.wait(1) -- Warte bis alles geladen ist
        init()
        if not ConfigSystem.Exists("Default") then
            ConfigSystem.Create("Default")
            print("✅ Default config created for executor")
        end
    end)
end

return ConfigSystem
