-- ConfigSystem.lua
-- Erweiterte Konfigurationsverwaltung für ModernUI
-- Unterstützt: Speichern/Laden, Auto-Load, JSON-ähnliche Serialisierung, Fehlerbehandlung

local ConfigSystem = {}

-- Services
local Players = game:GetService('Players')
local HttpService = game:GetService('HttpService')

local player = Players.LocalPlayer

-- Interner State
local configs = {}
local autoLoadConfig = nil
local dataFolder = nil

-- Initialisierung
local function init()
    if dataFolder then return end
    
    -- DataStore Folder erstellen
    dataFolder = Instance.new('Folder')
    dataFolder.Name = 'ModernUI_Configs'
    dataFolder.Parent = player
    
    -- Lade existierende Configs
    ConfigSystem._loadFromDataStore()
    
    -- Auto-Load Einstellung laden
    local autoLoadValue = dataFolder:FindFirstChild('AutoLoad')
    if autoLoadValue and autoLoadValue:IsA('StringValue') then
        autoLoadConfig = autoLoadValue.Value
        if autoLoadConfig == '' then autoLoadConfig = nil end
    end
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

function ConfigSystem._saveToDataStore()
    -- Speichere alle Configs als StringValues in DataStore Folder
    for name, data in pairs(configs) do
        local stringValue = dataFolder:FindFirstChild(name)
        if not stringValue then
            stringValue = Instance.new('StringValue')
            stringValue.Name = name
            stringValue.Parent = dataFolder
        end
        
        local success, serialized = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        
        if success then
            stringValue.Value = serialized
        else
            warn("ConfigSystem: Fehler beim Serialisieren von Config '" .. name .. "': " .. tostring(serialized))
        end
    end
    
    -- Auto-Load Einstellung speichern
    local autoLoadValue = dataFolder:FindFirstChild('AutoLoad')
    if not autoLoadValue then
        autoLoadValue = Instance.new('StringValue')
        autoLoadValue.Name = 'AutoLoad'
        autoLoadValue.Parent = dataFolder
    end
    autoLoadValue.Value = autoLoadConfig or ''
end

function ConfigSystem._loadFromDataStore()
    if not dataFolder then return end
    
    configs = {}
    
    for _, child in ipairs(dataFolder:GetChildren()) do
        if child:IsA('StringValue') and child.Name ~= 'AutoLoad' then
            local success, data = pcall(function()
                return HttpService:JSONDecode(child.Value)
            end)
            
            if success and type(data) == "table" then
                configs[child.Name] = data
            else
                warn("ConfigSystem: Fehler beim Laden von Config '" .. child.Name .. "'")
            end
        end
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
    init()
    
    local valid, error = ConfigSystem._validateConfigName(name)
    if not valid then
        warn("ConfigSystem.Create: " .. error)
        return false
    end
    
    configs[name] = {
        _metadata = {
            created = os.time(),
            version = "1.0"
        }
    }
    
    ConfigSystem._saveToDataStore()
    return true
end

function ConfigSystem.Delete(name)
    init()
    
    if not configs[name] then
        warn("ConfigSystem.Delete: Config '" .. name .. "' existiert nicht")
        return false
    end
    
    configs[name] = nil
    
    -- Entferne aus DataStore
    local stringValue = dataFolder:FindFirstChild(name)
    if stringValue then
        stringValue:Destroy()
    end
    
    -- Auto-Load zurücksetzen falls gelöscht
    if autoLoadConfig == name then
        autoLoadConfig = nil
        ConfigSystem._saveToDataStore()
    end
    
    return true
end

function ConfigSystem.Save(name, data)
    init()
    
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
    
    configs[name] = {
        _metadata = {
            created = configs[name]._metadata and configs[name]._metadata.created or os.time(),
            modified = os.time(),
            version = "1.0"
        }
    }
    
    -- Merge Daten
    for k, v in pairs(serializedData) do
        configs[name][k] = v
    end
    
    ConfigSystem._saveToDataStore()
    return true
end

function ConfigSystem.Load(name)
    init()
    
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
    init()
    
    local list = {}
    for name, _ in pairs(configs) do
        table.insert(list, name)
    end
    
    table.sort(list)
    return list
end

function ConfigSystem.Exists(name)
    init()
    return configs[name] ~= nil
end

function ConfigSystem.GetInfo(name)
    init()
    
    if not configs[name] then
        return nil
    end
    
    return configs[name]._metadata
end

function ConfigSystem.Rename(oldName, newName)
    init()
    
    if not configs[oldName] then
        warn("ConfigSystem.Rename: Config '" .. oldName .. "' existiert nicht")
        return false
    end
    
    local valid, error = ConfigSystem._validateConfigName(newName)
    if not valid then
        warn("ConfigSystem.Rename: " .. error)
        return false
    end
    
    if configs[newName] then
        warn("ConfigSystem.Rename: Config '" .. newName .. "' existiert bereits")
        return false
    end
    
    -- Kopiere Daten
    configs[newName] = configs[oldName]
    configs[oldName] = nil
    
    -- Update Auto-Load falls betroffen
    if autoLoadConfig == oldName then
        autoLoadConfig = newName
    end
    
    -- Update DataStore
    local oldStringValue = dataFolder:FindFirstChild(oldName)
    if oldStringValue then
        oldStringValue:Destroy()
    end
    
    ConfigSystem._saveToDataStore()
    return true
end

function ConfigSystem.Copy(sourceName, targetName)
    init()
    
    if not configs[sourceName] then
        warn("ConfigSystem.Copy: Quell-Config '" .. sourceName .. "' existiert nicht")
        return false
    end
    
    local valid, error = ConfigSystem._validateConfigName(targetName)
    if not valid then
        warn("ConfigSystem.Copy: " .. error)
        return false
    end
    
    if configs[targetName] then
        warn("ConfigSystem.Copy: Ziel-Config '" .. targetName .. "' existiert bereits")
        return false
    end
    
    -- Deep Copy der Config-Daten
    local function deepCopy(original)
        local copy = {}
        for k, v in pairs(original) do
            if type(v) == "table" then
                copy[k] = deepCopy(v)
            else
                copy[k] = v
            end
        end
        return copy
    end
    
    configs[targetName] = deepCopy(configs[sourceName])
    
    -- Update Metadaten
    configs[targetName]._metadata = {
        created = os.time(),
        version = "1.0",
        copiedFrom = sourceName
    }
    
    ConfigSystem._saveToDataStore()
    return true
end

function ConfigSystem.SetAutoLoad(configName)
    init()
    
    if configName ~= nil and not configs[configName] then
        warn("ConfigSystem.SetAutoLoad: Config '" .. configName .. "' existiert nicht")
        return false
    end
    
    autoLoadConfig = configName
    ConfigSystem._saveToDataStore()
    return true
end

function ConfigSystem.GetAutoLoad()
    init()
    return autoLoadConfig
end

function ConfigSystem.Export(name)
    init()
    
    local configData = ConfigSystem.Load(name)
    if not configData then
        return nil
    end
    
    local exportData = {
        name = name,
        exported = os.time(),
        version = "1.0",
        data = configData
    }
    
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(exportData)
    end)
    
    return success and encoded or nil
end

function ConfigSystem.Import(encodedData, targetName)
    init()
    
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
    init()
    
    if autoLoadConfig and configs[autoLoadConfig] then
        return ConfigSystem.Load(autoLoadConfig)
    end
    
    return nil
end

-- Cleanup Funktion
function ConfigSystem.Cleanup()
    configs = {}
    autoLoadConfig = nil
    if dataFolder then
        dataFolder:Destroy()
        dataFolder = nil
    end
end

-- Initialisiere beim ersten Aufruf
init()

return ConfigSystem
