-- ConfigSystem.lua (executor-ready)
-- Robust, file-backed with in-memory fallback; provides change notifications

local HttpService = game:GetService("HttpService")

local ConfigSystem = {}

-- FS detection (executors)
local function hasFs()
    return typeof(isfile) == "function"
        and typeof(writefile) == "function"
        and typeof(readfile) == "function"
        and typeof(makefolder) == "function"
        and typeof(isfolder) == "function"
end

local function canListFs()
    return typeof(listfiles) == "function"
end

local BASE_DIR = "workspace/LynixConfigs"
-- Allow overriding base directory for executors with restricted paths
if typeof(getgenv) == "function" then
    local g = getgenv()
    if type(g) == "table" and type(g.LynixConfigBase) == "string" and #g.LynixConfigBase > 0 then
        BASE_DIR = g.LynixConfigBase
    end
end
local INDEX_FILE = BASE_DIR .. "/_index.json"
local META_FILE = BASE_DIR .. "/_meta.json"

local function ensureDir()
    if not hasFs() then return end
    pcall(function()
        -- ensure parent workspace exists first (executor compatibility)
        if not isfolder("workspace") then
            makefolder("workspace")
        end
        if not isfolder(BASE_DIR) then
            makefolder(BASE_DIR)
        end
    end)
end

local function jsonEncode(t)
    local ok, s = pcall(function() return HttpService:JSONEncode(t or {}) end)
    return ok and s or "{}"
end
local function jsonDecode(s)
    local ok, res = pcall(function() return HttpService:JSONDecode(s) end)
    return ok and res or nil
end

-- In-memory fallback store
local memoryStore = { list = {}, data = {}, auto = nil }

-- Index handling (to avoid relying solely on listfiles)
local function readIndex()
    if not hasFs() then return memoryStore.list end
    ensureDir()
    if isfile(INDEX_FILE) then
        local t = jsonDecode(readfile(INDEX_FILE))
        if type(t) == "table" then return t end
    end
    -- Build from directory if index missing
    local names = {}
    local ok, files = pcall(function() return listfiles(BASE_DIR) end)
    if canListFs() and ok and type(files) == "table" then
        for _, path in ipairs(files) do
            -- support both forward and backslashes
            local name = path:match("[/\\]([^/\\]+)%.json$")
            if name and name ~= "_index" and name ~= "_meta" then table.insert(names, name) end
        end
    end
    table.sort(names)
    writefile(INDEX_FILE, jsonEncode(names))
    return names
end

local function writeIndex(list)
    if hasFs() then
        ensureDir()
        writefile(INDEX_FILE, jsonEncode(list or {}))
    else
        memoryStore.list = list
    end
end

local function sanitize(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("[^%w%-%._]", "_")
    if name == "" then return nil end
    return name
end

local listeners = {}
function ConfigSystem.OnChanged(cb)
    if type(cb) == "function" then table.insert(listeners, cb) end
end
local function notify()
    for _, cb in ipairs(listeners) do
        pcall(cb)
    end
end

function ConfigSystem.List()
    local list = hasFs() and readIndex() or memoryStore.list
    return table.clone(list)
end

function ConfigSystem.Exists(name)
    name = sanitize(name)
    if not name then return false end
    if hasFs() then
        return isfile(BASE_DIR .. "/" .. name .. ".json")
    else
        return memoryStore.data[name] ~= nil
    end
end

function ConfigSystem.Create(name)
    name = sanitize(name)
    if not name then return false, "invalid name" end
    ensureDir()
    local list = ConfigSystem.List()
    if not table.find(list, name) then
        table.insert(list, name)
        table.sort(list)
        writeIndex(list)
    end
    if hasFs() then
        local path = BASE_DIR .. "/" .. name .. ".json"
        if not isfile(path) then writefile(path, jsonEncode({})) end
    else
        memoryStore.data[name] = memoryStore.data[name] or {}
    end
    notify()
    return true
end

function ConfigSystem.Save(name, data)
    name = sanitize(name)
    if not name then return false, "invalid name" end
    ensureDir()
    data = data or {}
    if hasFs() then
        local path = BASE_DIR .. "/" .. name .. ".json"
        local payload = jsonEncode(data) or "{}"
        -- some executors return nil from immediate readfile on a freshly written temp file
        -- keep it simple and write directly
        writefile(path, payload)
    else
        memoryStore.data[name] = data
    end
    -- ensure exists in index
    ConfigSystem.Create(name)
    return true
end

function ConfigSystem.Load(name)
    name = sanitize(name)
    if not name then return nil end
    if hasFs() then
        local path = BASE_DIR .. "/" .. name .. ".json"
        if not isfile(path) then return {} end
        local raw = readfile(path)
        local t = jsonDecode(raw)
        return (type(t) == "table") and t or {}
    else
        return memoryStore.data[name] or {}
    end
end

-- Auto-load flag stored in meta
local function readMeta()
    if hasFs() and isfile(META_FILE) then
        return jsonDecode(readfile(META_FILE)) or {}
    end
    return { autoLoad = memoryStore.auto }
end
local function writeMeta(t)
    if hasFs() then
        ensureDir()
        writefile(META_FILE, jsonEncode(t or {}))
    else
        memoryStore.auto = t and t.autoLoad or nil
    end
end

function ConfigSystem.SetAutoLoad(name)
    name = sanitize(name)
    local meta = readMeta()
    meta.autoLoad = name
    writeMeta(meta)
    notify()
end
function ConfigSystem.GetAutoLoad()
    local meta = readMeta()
    return meta.autoLoad
end

return ConfigSystem


