-- ServerScriptService/PlayerStats.lua
-- プレイヤーのステータスを管理するModuleScript
-- ステップ2: SharedState/GameEvents統合版

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 【ステップ2】SharedStateとGameEventsをロード
local SharedState = require(ReplicatedStorage:WaitForChild("SharedState"))
local GameEvents = require(ReplicatedStorage:WaitForChild("GameEvents"))

local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))

local PlayerStats = {}
local LoadedDataCache = {}

-- RemoteEventを取得する関数
local function getRemoteEvent(name)
	return ReplicatedStorage:WaitForChild(name, 10)
end

-- デフォルトステータス
local DEFAULT_STATS = {
	Level = 1,
	Experience = 0,
	Gold = 100, -- 初期ゴールド100G

	MaxHP = 100,
	CurrentHP = 100,

	Speed = 6, -- 素早さ
	Attack = 10, -- 攻撃力
	Defense = 12, -- 守備力
	MonstersDefeated = 0,

	MonsterCounts = {}, -- モンスターカウント追加
	CollectedItems = {}, -- 取得済みアイテム
}

-- レベルアップに必要な経験値（緩やか逓増: 50 * level^1.7）
local function getRequiredExp(level)
	return math.floor(50 * (level ^ 1.7) + 0.5)
end

-- 各プレイヤーのステータスを保存
local PlayerData = {}

-- プレイヤー参加時に装備を適用するスクリプト

game.Players.PlayerAdded:Connect(function(player)
	-- print(
	-- 	"[AccessoryScript DEBUG] 装備イベントリスナーが "
	-- 		.. player.Name
	-- 		.. " のために登録されます。"
	-- )

	local ServerStorage = game:GetService("ServerStorage")
	local AccessoriesFolder = ServerStorage:WaitForChild("Accessories") -- フォルダを先に取得

	-- キャラクターが生成されたとき（リスポーン時も含む）
	player.CharacterAdded:Connect(function(character)
		-- まず Humanoid を取得 (アクセサリと服の両方で必要)
		local humanoid = character:WaitForChild("Humanoid")
		if not humanoid then
			warn("[AccessoryScript] " .. character.Name .. " から Humanoid が見つかりません。")
			return
		end
		-- print("[AccessoryScript DEBUG] CharacterAdded が発火、Humanoid を発見しました for " .. player.Name)

		-- --- 1. ヘルメットの装着 (既存のロジック) ---
		local helmetSuccess, helmetError = pcall(function()
			local helmetTemplate = AccessoriesFolder:WaitForChild("HelmetAccessory")
			local helmet = helmetTemplate:Clone()

			local existing = character:FindFirstChild(helmet.Name)
			if existing then
				existing:Destroy()
			end

			humanoid:AddAccessory(helmet)
			-- print("[AccessoryScript DEBUG] " .. player.Name .. " に HelmetAccessory を装備しました。")
		end)

		if not helmetSuccess then
			-- warn("[AccessoryScript ERROR] ヘルメット装着失敗:", helmetError)
		end

		-- --- 2. 服（展開図）の装着 (既存のロジック) ---
		local clothingSuccess, clothingError = pcall(function()
			local clothingAssetID = "rbxassetid://118184810445004"

			local shirt = character:FindFirstChildOfClass("Shirt")
			if not shirt then
				shirt = Instance.new("Shirt")
				shirt.Name = "Shirt"
				shirt.Parent = character
			end

			local pants = character:FindFirstChildOfClass("Pants")
			if not pants then
				pants = Instance.new("Pants")
				pants.Name = "Pants"
				pants.Parent = character
			end

			shirt.ShirtTemplate = clothingAssetID
			pants.PantsTemplate = clothingAssetID

			print(
				"[AccessoryScript DEBUG] "
					.. player.Name
					.. " に Clothing (ID: "
					.. clothingAssetID
					.. ") を装備しました。"
			)
		end)
	end)
end)

-- プレイヤーのステータスを初期化
function PlayerStats.initPlayer(player: Player)
	if PlayerData[player] then
		warn(("[PlayerStats] %s は既に初期化済みです"):format(player.Name))
		-- 既に初期化済みの場合はLocationを返却
		return PlayerData[player].Location
			or {
				ZoneName = "ContinentTown",
				X = DEFAULT_STATS.MaxHP,
				Y = DEFAULT_STATS.MaxHP,
				Z = DEFAULT_STATS.MaxHP,
			}
	end

	-- デフォルト値でステータスを作成
	local stats = {}
	for key, value in pairs(DEFAULT_STATS) do
		stats[key] = value
	end

	-- ★DataStoreからデータをロード（ブロッキング）
	local loadedData = DataStoreManager.LoadData(player)
	LoadedDataCache[player] = loadedData

	local loadedLocation = nil

	if loadedData and loadedData.PlayerState then
		local playerState = loadedData.PlayerState

		-- ステータスを適用
		for key, value in pairs(playerState.Stats) do
			if stats[key] ~= nil then
				stats[key] = value
			end
		end

		-- Locationを適用
		if playerState.Location then
			loadedLocation = playerState.Location
			print(
				("[PlayerStats] %s のセーブデータを適用しました: %s (%.0f, %.0f, %.0f)"):format(
					player.Name,
					loadedLocation.ZoneName,
					loadedLocation.X,
					loadedLocation.Y,
					loadedLocation.Z
				)
			)
		end

		stats.CollectedItems = loadedData.CollectedItems or {}

		print(
			("[PlayerStats] %s の取得済みアイテム数: %d"):format(
				player.Name,
				next(stats.CollectedItems) and #stats.CollectedItems or 0
			)
		)
	else
		print(
			("[PlayerStats] %s の新規データ、またはロード失敗（デフォルト値使用）"):format(
				player.Name
			)
		)
	end

	PlayerData[player] = stats
	print(("[PlayerStats] %s のステータスを初期化しました（DataStore適用後）"):format(player.Name))

	-- 【ステップ2】SharedStateにプレイヤーゾーンを初期化
	SharedState.PlayerZones[player] = nil

	-- setupAccessoryEvents(player)

	-- ★ロードされたLocation情報を返す
	return loadedLocation
end

function PlayerStats.getLastLoadedData(player: Player)
	return LoadedDataCache[player]
end

-- プレイヤーのステータスを取得
function PlayerStats.getStats(player: Player)
	return PlayerData[player]
end

-- 特定のステータスを取得
function PlayerStats.getStat(player: Player, statName: string)
	local stats = PlayerData[player]
	if not stats then
		warn(("[PlayerStats] %s のステータスが見つかりません"):format(player.Name))
		return nil
	end
	return stats[statName]
end

-- 特定のステータスを設定
function PlayerStats.setStat(player: Player, statName: string, value)
	local stats = PlayerData[player]
	if not stats then
		warn(("[PlayerStats] %s のステータスが見つかりません"):format(player.Name))
		return
	end

	stats[statName] = value
	print(("[PlayerStats] %s の %s を %s に設定"):format(player.Name, statName, tostring(value)))
end

-- HPを回復
function PlayerStats.healHP(player: Player, amount: number)
	local stats = PlayerData[player]
	if not stats then
		return
	end

	stats.CurrentHP = math.min(stats.CurrentHP + amount, stats.MaxHP)
	print(
		("[PlayerStats] %s のHPを %d 回復（現在: %d/%d)"):format(
			player.Name,
			amount,
			stats.CurrentHP,
			stats.MaxHP
		)
	)
end

-- HPを全回復
function PlayerStats.fullHeal(player: Player)
	local stats = PlayerData[player]
	if not stats then
		return
	end

	stats.CurrentHP = stats.MaxHP
	print(("[PlayerStats] %s のHPを全回復"):format(player.Name))
end

-- ダメージを受ける
function PlayerStats.takeDamage(player: Player, damage: number): boolean
	local stats = PlayerData[player]
	if not stats then
		return false
	end

	stats.CurrentHP = math.max(0, stats.CurrentHP - damage)
	print(
		("[PlayerStats] %s が %d ダメージを受けた（残りHP: %d/%d)"):format(
			player.Name,
			damage,
			stats.CurrentHP,
			stats.MaxHP
		)
	)

	-- ステータス更新を送信
	local StatusUpdateEvent = getRemoteEvent("StatusUpdate")
	if StatusUpdateEvent then
		local expToNext = getRequiredExp(stats.Level)
		StatusUpdateEvent:FireClient(
			player,
			stats.CurrentHP,
			stats.MaxHP,
			stats.Level,
			stats.Experience,
			expToNext,
			stats.Gold
		)
	end

	-- 死亡判定
	if stats.CurrentHP <= 0 then
		print(("[PlayerStats] %s は倒れた！"):format(player.Name))
		return true -- 死亡
	end

	return false -- 生存
end

-- 経験値を追加
function PlayerStats.addExperience(player, amount)
	local stats = PlayerStats.getStats(player)
	if not stats then
		return
	end

	stats.Experience = (stats.Experience or 0) + (amount or 0)

	local leveledUp = false
	local lastDeltas = nil

	while true do
		local need = PlayerStats.getExpToNext(stats.Level)
		if (stats.Experience or 0) < need then
			break
		end

		-- ★旧ステータスを記録
		local oldStats = {
			MaxHP = stats.MaxHP,
			Speed = stats.Speed,
			Attack = stats.Attack,
			Defense = stats.Defense,
		}

		stats.Experience = stats.Experience - need
		stats.Level = stats.Level + 1
		leveledUp = true

		local deltas = PlayerStats.calcLevelUpDeltas(stats.Level)
		lastDeltas = deltas

		-- 新ステータス反映
		stats.MaxHP += deltas.hp
		stats.Speed += deltas.speed
		stats.Attack += deltas.attack
		stats.Defense += deltas.defense
		stats.CurrentHP = stats.MaxHP

		-- クライアント通知（新仕様対応）
		local LevelUpEvent = game.ReplicatedStorage:FindFirstChild("LevelUp")
		if LevelUpEvent then
			LevelUpEvent:FireClient(
				player,
				stats.Level,
				stats.MaxHP,
				stats.Speed,
				stats.Attack,
				stats.Defense,
				oldStats -- ✅ ← 新しく追加（旧値を渡す）
			)
		end
	end
end

-- ゴールドを追加
function PlayerStats.addGold(player: Player, gold: number)
	local stats = PlayerData[player]
	if not stats then
		return
	end

	stats.Gold = stats.Gold + gold
	print(("[PlayerStats] %s がゴールド %d を獲得（合計: %d)"):format(player.Name, gold, stats.Gold))

	-- ステータス更新を送信
	local StatusUpdateEvent = getRemoteEvent("StatusUpdate")
	if StatusUpdateEvent then
		local expToNext = getRequiredExp(stats.Level)
		StatusUpdateEvent:FireClient(
			player,
			stats.CurrentHP,
			stats.MaxHP,
			stats.Level,
			stats.Experience,
			expToNext,
			stats.Gold
		)
	end
end

-- ゴールドを減らす
function PlayerStats.removeGold(player: Player, gold: number): boolean
	local stats = PlayerData[player]
	if not stats then
		return false
	end

	if stats.Gold < gold then
		print(("[PlayerStats] %s のゴールドが不足しています"):format(player.Name))
		return false
	end

	stats.Gold = stats.Gold - gold
	print(("[PlayerStats] %s がゴールド %d を失った（残り: %d)"):format(player.Name, gold, stats.Gold))
	return true
end

-- 倒したモンスター数を追加
function PlayerStats.addMonstersDefeated(player: Player, count: number)
	print(("[PlayerStats] ========================================"):format())
	print(("[PlayerStats] addMonstersDefeated 呼び出し"):format())
	print(("  プレイヤー: %s"):format(player.Name))
	print(("  追加数: %d"):format(count or 1))

	local stats = PlayerData[player]
	if not stats then
		warn(
			("[PlayerStats] ❌ %s のステータスが見つかりません（モンスターカウント失敗)"):format(
				player.Name
			)
		)
		print(("[PlayerStats] ========================================"):format())
		return
	end

	local oldCount = stats.MonstersDefeated
	count = count or 1
	stats.MonstersDefeated = stats.MonstersDefeated + count

	print(("  変更前: %d"):format(oldCount))
	print(("  変更後: %d"):format(stats.MonstersDefeated))
	print(("[PlayerStats] ✅ モンスター撃破数更新成功"):format())
	print(("[PlayerStats] ========================================"):format())
end

-- レベルアップ
function PlayerStats.levelUp(player: Player)
	local stats = PlayerData[player]
	if not stats then
		return
	end

	-- ★旧ステータスを記録
	local oldStats = {
		MaxHP = stats.MaxHP,
		Speed = stats.Speed,
		Attack = stats.Attack,
		Defense = stats.Defense,
	}

	local oldLevel = stats.Level
	stats.Level += 1
	stats.MaxHP += 10
	stats.Speed += 2
	stats.Attack += 2
	stats.Defense += 2
	stats.CurrentHP = stats.MaxHP

	print(("[PlayerStats] 🎉 %s がレベルアップ！ %d → %d"):format(player.Name, oldLevel, stats.Level))

	local LevelUpEvent = getRemoteEvent("LevelUp")
	if LevelUpEvent then
		LevelUpEvent:FireClient(
			player,
			stats.Level,
			stats.MaxHP,
			stats.Speed,
			stats.Attack,
			stats.Defense,
			oldStats -- ✅ ← 新しく追加
		)
	end
end

-- 【ステップ2】モンスターカウントを更新
function PlayerStats.updateMonsterCounts(player: Player, zoneName: string)
	local stats = PlayerData[player]
	if not stats then
		return
	end

	-- SharedStateから最新のカウントを取得
	if SharedState.MonsterCounts[zoneName] then
		stats.MonsterCounts[zoneName] = SharedState.MonsterCounts[zoneName]
		print(
			("[PlayerStats] %s のゾーン %s のモンスターカウントを更新"):format(player.Name, zoneName)
		)
	end
end

-- プレイヤーが退出したらデータをクリア
function PlayerStats.removePlayer(player: Player)
	PlayerData[player] = nil
	LoadedDataCache[player] = nil -- 【追加】
	SharedState.PlayerZones[player] = nil
	print(("[PlayerStats] %s のデータを削除しました"):format(player.Name))
end

-- 初期化
function PlayerStats.init()
	print("[PlayerStats DEBUG] PlayerStats.init() が実行されました。") -- ★デバッグ追加

	print("[PlayerStats DEBUG] 新規PlayerAddedリスナーを登録します。")
	Players.PlayerAdded:Connect(function(player)
		print("[PlayerStats DEBUG] 新規プレイヤー: " .. player.Name .. " が参加しました。")
		PlayerStats.initPlayer(player)
		-- (setupAccessoryEvents は initPlayer の中で呼び出される)
	end)

	-- 既存のプレイヤーを初期化
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerStats.initPlayer(player)
	end

	-- 退出時にデータをクリア
	Players.PlayerRemoving:Connect(function(player)
		PlayerStats.removePlayer(player)
	end)

	-- 詳細ステータスリクエスト用RemoteEvent
	local RequestStatsDetailEvent = ReplicatedStorage:FindFirstChild("RequestStatsDetail")
	if not RequestStatsDetailEvent then
		RequestStatsDetailEvent = Instance.new("RemoteEvent")
		RequestStatsDetailEvent.Name = "RequestStatsDetail"
		RequestStatsDetailEvent.Parent = ReplicatedStorage
	end

	RequestStatsDetailEvent.OnServerEvent:Connect(function(player)
		local stats = PlayerStats.getStats(player)
		if stats then
			-- StatsDetailEventを取得または作成
			local StatsDetailEvent = ReplicatedStorage:FindFirstChild("StatsDetail")
			if not StatsDetailEvent then
				StatsDetailEvent = Instance.new("RemoteEvent")
				StatsDetailEvent.Name = "StatsDetail"
				StatsDetailEvent.Parent = ReplicatedStorage
				print("[PlayerStats] StatsDetailイベントを作成しました")
			end

			print(
				("[PlayerStats] 詳細ステータスを送信: MonstersDefeated=%d"):format(
					stats.MonstersDefeated or 0
				)
			)
			StatsDetailEvent:FireClient(player, stats)
		end
	end)

	print("[PlayerStats] 初期化完了（ステップ2: SharedState統合版）")
end

-- 例）PlayerStats.lua のトップレベル（return の前、ユーティリティの辺り）に追記
local function pow(base, exp)
	return base ^ exp
end

function PlayerStats.getExpToNext(level: number): number
	-- 50 * level^1.7 を四捨五入
	return math.floor(50 * pow(level, 1.7) + 0.5)
end

-- レベルアップ時の増分を計算
-- 仕様：
--  - 通常：HP +10、他 +2
--  - レベルが5の倍数：1.5倍（HP+15、他+3）
--  - さらにHPはレベル帯で上昇幅を増やす（例：Lv10~19:+15、Lv20~29:+20、…）
function PlayerStats.calcLevelUpDeltas(newLevel: number)
	-- 基本値
	local hpInc = 10
	local otherInc = 2

	-- レベル帯でHP増加幅を加算（例示）
	if newLevel >= 20 then
		hpInc = 20
	elseif newLevel >= 10 then
		hpInc = 15
	end
	-- 必要ならさらに帯を増やせます
	-- if newLevel >= 30 then hpInc = 25 end ... 等

	-- 5の倍数は1.5倍
	if newLevel % 5 == 0 then
		hpInc = math.floor(hpInc * 1.5 + 0.5) -- 10→15, 15→22, 20→30 など
		otherInc = math.floor(otherInc * 1.5 + 0.5) -- 2→3
	end

	return {
		hp = hpInc,
		speed = otherInc,
		attack = otherInc,
		defense = otherInc,
	}
end

return PlayerStats
