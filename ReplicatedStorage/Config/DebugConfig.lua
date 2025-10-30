-- ReplicatedStorage/Config/DebugConfig.lua
return {
    -- 文字 or 数字どちらでもOK（TRACE=10, DEBUG=20, INFO=30, WARN=40, ERROR=50）
    level = "DEBUG",

    -- {"BattleUI","BattleSystem"} のようにタグで絞り込み（nil でオフ）
    onlyTags = nil,

    -- 先頭に tick() を出す
    showTime = false,

    -- WARN/ERROR は warn() に流す（それ以外は print）
    warnForHighLevels = true,
}
