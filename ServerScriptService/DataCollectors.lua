-- ServerScriptService/DataCollectors.lua
-- セーブ/ロードに必要なデータを収集・適用するモジュール

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local DataCollectors = {}

-- プレイヤーの状態を収集
function DataCollectors.collectPlayerState(player: Player, playerStats)
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart", 5)

    local zoneManager = require(script.Parent.ZoneManager)
    local currentZone = zoneManager.GetPlayerZone(player)

    local playerState = {
        -- ステータス (PlayerStatsから取得)
        Stats = {
            Level = playerStats.Level,
            Experience = playerStats.Experience,
            Gold = playerStats.Gold,
            CurrentHP = playerStats.CurrentHP,
            MonstersDefeated = playerStats.MonstersDefeated,
        },
        -- 位置情報
        Location = {
            ZoneName = currentZone or "ContinentTown", -- デフォルトはタウン
            X = hrp and hrp.Position.X or 0,
            Y = hrp and hrp.Position.Y or 50, -- Yは地形から少し上の位置
            Z = hrp and hrp.Position.Z or 0,
        },
    }

    return playerState
end

-- 【修正】ワールドの状態（モンスターカウントのみ）を収集
function DataCollectors.collectFieldState(zoneName)
    local fieldState = {
        MonsterCounts = {}
    }

    -- MonsterSpawnerのグローバル関数を使ってカウント取得
    if _G.GetZoneMonsterCounts then
        local counts = _G.GetZoneMonsterCounts(zoneName)
        if counts then
            fieldState.MonsterCounts = counts
            print(("[DataCollectors] %s のモンスターカウント収集: %s"):format(
                zoneName,
                HttpService:JSONEncode(counts)
            ))
        else
            print(("[DataCollectors] %s にモンスターカウントがありません"):format(zoneName))
        end
    else
        warn("[DataCollectors] _G.GetZoneMonsterCounts が利用できません")
    end

    return fieldState
end

-- 【修正】ワールドの状態を復元 (ロード時に使用)
function DataCollectors.restoreFieldState(zoneName, fieldState)
    if not fieldState then
        warn("[DataCollectors] 復元するフィールド状態がありません")
        return false
    end

    if not fieldState.MonsterCounts or next(fieldState.MonsterCounts) == nil then
        print(("[DataCollectors] %s に復元するモンスターがありません"):format(zoneName))
        return false
    end

    print(("[DataCollectors] %s のモンスターを復元中: %s"):format(
        zoneName,
        HttpService:JSONEncode(fieldState.MonsterCounts)
    ))

    -- MonsterSpawnerのグローバル関数を使ってスポーン
    if _G.SpawnMonstersWithCounts then
        _G.SpawnMonstersWithCounts(zoneName, fieldState.MonsterCounts)
        print(("[DataCollectors] %s のモンスター復元完了"):format(zoneName))
        return true
    else
        warn("[DataCollectors] _G.SpawnMonstersWithCounts が利用できません")
        return false
    end
end

-- 総合セーブデータを作成
function DataCollectors.createSaveData(player: Player, playerStats)
    local currentZone = (require(script.Parent.ZoneManager)).GetPlayerZone(player)

    local saveData = {
        PlayerState = DataCollectors.collectPlayerState(player, playerStats),
        CurrentZone = currentZone,
        FieldState = (currentZone ~= "ContinentTown") and DataCollectors.collectFieldState(currentZone) or nil,
        CollectedItems = playerStats.CollectedItems or {},
        SaveTime = os.time(),
    }

    return saveData
end

return DataCollectors