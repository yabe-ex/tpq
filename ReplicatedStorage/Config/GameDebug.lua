-- ReplicatedStorage/Config/GameDebug.lua
local GameDebug = {
    BattleLogs = false,         -- サーバ/クライアントの詳細ログ
    BattleTelemetry = true,     -- テレメトリ送信有効
    TelemetrySampleCycles = 3,  -- 1バトルで最初のnサイクルだけ収集
    DriftWarnMs = 120,          -- ドリフト閾値(ms) 超過時のみ警告ログ
}
return GameDebug
