-- ReplicatedStorage/Util/Logger.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== 設定読み込み（Config を優先、なければ Util、最後にデフォルト） ==========
local function loadConfig()
    local cfgMod = nil

    -- ① Config/DebugConfig.lua（今回の新パス）
    local configFolder = ReplicatedStorage:FindFirstChild("Config")
    if configFolder then
        cfgMod = configFolder:FindFirstChild("DebugConfig")
    end

    -- ② 互換: Util/DebugConfig.lua
    if not cfgMod then
        local utilFolder = ReplicatedStorage:FindFirstChild("Util")
        if utilFolder then
            cfgMod = utilFolder:FindFirstChild("DebugConfig")
        end
    end

    -- ③ 直下: DebugConfig.lua（最後の保険）
    if not cfgMod then
        cfgMod = ReplicatedStorage:FindFirstChild("DebugConfig")
    end

    if cfgMod then
        local ok, got = pcall(require, cfgMod)
        if ok and type(got) == "table" then
            return got
        else
            warn("[Logger] DebugConfig require failed; using defaults")
        end
    else
        warn("[Logger] DebugConfig not found; using defaults")
    end

    -- デフォルト
    return {
        level = "INFO",
        onlyTags = nil,
        showTime = true,
        warnForHighLevels = true,
    }
end

local rawCfg = loadConfig()

-- ========== レベル正規化 ==========
local LEVELS = { TRACE=10, DEBUG=20, INFO=30, WARN=40, ERROR=50 }
local NAMES  = {}; for k,v in pairs(LEVELS) do NAMES[v]=k end

local function normalizeLevel(lv)
    if type(lv)=="number" then
        if lv < 15 then return LEVELS.TRACE end
        if lv < 25 then return LEVELS.DEBUG end
        if lv < 35 then return LEVELS.INFO  end
        if lv < 45 then return LEVELS.WARN  end
        return LEVELS.ERROR
    elseif type(lv)=="string" then
        local up = string.upper(lv:match("^%s*(.-)%s*$"))
        return LEVELS[up] or LEVELS.INFO
    end
    return LEVELS.INFO
end

local function normalizeTags(tags)
    if not tags then return nil end
    if type(tags)=="table" then
        -- すでに set 形式ならそのまま
        local isSet = true
        for k,v in pairs(tags) do
            if type(k) ~= "string" or v ~= true then
                isSet = false; break
            end
        end
        if isSet then return tags end

        -- 配列 → set
        local set = {}
        for _,name in ipairs(tags) do
            if type(name)=="string" then set[name]=true end
        end
        return set
    end
    return nil
end

local CONFIG = {
    level = normalizeLevel(rawCfg.level),
    onlyTags = normalizeTags(rawCfg.onlyTags),
    showTime = (rawCfg.showTime ~= false),
    warnForHighLevels = (rawCfg.warnForHighLevels ~= false),
}

-- ========== 本体 ==========
local Logger = {}
Logger._config = CONFIG
Logger._cache  = {}

local function shouldEmit(tag, lvl)
    if CONFIG.onlyTags and not CONFIG.onlyTags[tag] then return false end
    return lvl >= CONFIG.level
end

local function emit(tag, lvl, msg)
    local prefix = string.format("[%s][%s]", NAMES[lvl] or "LOG", tag)
    if CONFIG.showTime then
        prefix = string.format("[%.3f]%s", tick(), prefix)
    end
    local line = prefix .. " " .. tostring(msg)
    if CONFIG.warnForHighLevels and lvl >= LEVELS.WARN then
        warn(line)
    else
        print(line)
    end
end

local function makeLogger(tag)
    tag = tostring(tag or "APP")

    local function logAt(lvl, ...)
        if not shouldEmit(tag, lvl) then return end
        if select("#", ...) == 1 then
            emit(tag, lvl, select(1, ...))
        else
            local parts = {}
            for i=1,select("#", ...) do parts[#parts+1]=tostring(select(i,...)) end
            emit(tag, lvl, table.concat(parts, " "))
        end
    end

    local function logFmt(lvl, fmt, ...)
        if not shouldEmit(tag, lvl) then return end
        emit(tag, lvl, string.format(fmt, ...))
    end

    return {
        trace  = function(...) logAt(LEVELS.TRACE, ...) end,
        debug  = function(...) logAt(LEVELS.DEBUG, ...) end,
        info   = function(...) logAt(LEVELS.INFO , ...) end,
        warn   = function(...) logAt(LEVELS.WARN , ...) end,
        error  = function(...) logAt(LEVELS.ERROR, ...) end,

        tracef = function(fmt, ...) logFmt(LEVELS.TRACE, fmt, ...) end,
        debugf = function(fmt, ...) logFmt(LEVELS.DEBUG, fmt, ...) end,
        infof  = function(fmt, ...) logFmt(LEVELS.INFO , fmt, ...) end,
        warnf  = function(fmt, ...) logFmt(LEVELS.WARN , fmt, ...) end,
        errorf = function(fmt, ...) logFmt(LEVELS.ERROR, fmt, ...) end,
    }
end

function Logger.get(tag)
    if not Logger._cache[tag] then
        Logger._cache[tag] = makeLogger(tag)
    end
    return Logger._cache[tag]
end

-- ランタイムで変更したいとき用
function Logger.setLevel(lv)     CONFIG.level = normalizeLevel(lv) end
function Logger.setOnlyTags(ts)  CONFIG.onlyTags = normalizeTags(ts) end

return Logger
