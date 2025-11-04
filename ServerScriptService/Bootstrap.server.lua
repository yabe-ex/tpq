-- ServerScriptService/Bootstrap.server.lua
-- ゲーム初期化スクリプト（スポーン完了シグナル安定化版）

-- ★ 【一時的】セーブデータをクリア
local DataStoreService = game:GetService("DataStoreService")
local PLAYER_DATA_STORE = DataStoreService:GetDataStore("TypingQuestPlayerSaveData_V1")

-- ゲーム開始時に1回だけ実行
local CLEAR_SAVE = true -- クリアする場合は true、しない場合は false

if CLEAR_SAVE then
	print("[TEMP] すべてのセーブデータをクリア中...")
	local success, err = pcall(function()
		-- 注意：全プレイヤーのセーブを削除するため、テスト用途のみ
		PLAYER_DATA_STORE:RemoveAsync("6023547159") -- あなたのユーザーID
	end)

	if success then
		print("[TEMP] セーブクリア完了")
	else
		warn("[TEMP] セーブクリア失敗:", err)
	end
end

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("[Bootstrap] === ゲーム初期化開始 ===")

-- プレイヤーがゲームに参加したとき
-- game.Players.PlayerAdded:Connect(function(player)
-- 	-- キャラクターが生成されたとき
-- 	player.CharacterAdded:Connect(function(character)
-- 		-- ServerStorage からアクセサリーを取得
-- 		local accessoryFolder = game.ServerStorage:WaitForChild("Accessories")
-- 		local helmet = accessoryFolder:WaitForChild("HelmetAccessory"):Clone()

-- 		-- キャラクターに装着
-- 		character:AddAccessory(helmet)
-- 	end)
-- end)

-- ★ RemoteEventの先行作成（重要：後から作らない）
local SpawnReadyEvent = ReplicatedStorage:FindFirstChild("SpawnReady")
if not SpawnReadyEvent then
	SpawnReadyEvent = Instance.new("RemoteEvent")
	SpawnReadyEvent.Name = "SpawnReady"
	SpawnReadyEvent.Parent = ReplicatedStorage
	print("[Bootstrap] ✓ SpawnReadyEvent作成")
end

local SaveGameEvent = ReplicatedStorage:FindFirstChild("SaveGame")
if not SaveGameEvent then
	SaveGameEvent = Instance.new("RemoteEvent")
	SaveGameEvent.Name = "SaveGame"
	SaveGameEvent.Parent = ReplicatedStorage
	print("[Bootstrap] ✓ SaveGameEvent作成")
end

local SaveSuccessEvent = ReplicatedStorage:FindFirstChild("SaveSuccess")
if not SaveSuccessEvent then
	SaveSuccessEvent = Instance.new("RemoteEvent")
	SaveSuccessEvent.Name = "SaveSuccess"
	SaveSuccessEvent.Parent = ReplicatedStorage
	print("[Bootstrap] ✓ SaveSuccessEvent作成")
end

-- ★ 効果音の初期化（早期）
do
	local function findSoundRegistry()
		local m = ServerScriptService:FindFirstChild("SoundRegistry")
		if not m then
			local modules = ServerScriptService:FindFirstChild("Modules")
			if modules then
				m = modules:FindFirstChild("SoundRegistry")
			end
		end
		if not m then
			m = ReplicatedStorage:FindFirstChild("SoundRegistry")
		end
		return m
	end

	local m = findSoundRegistry()
	if m and m:IsA("ModuleScript") then
		local okReq, modOrErr = pcall(require, m)
		if okReq and type(modOrErr) == "table" and type(modOrErr.init) == "function" then
			local okInit, errInit = pcall(modOrErr.init)
			if okInit then
				print("[Bootstrap] Sounds初期化完了（SoundRegistry）")
			else
				warn("[Bootstrap] SoundRegistry.init エラー: ", errInit)
			end
		else
			warn("[Bootstrap] SoundRegistry 戻り値が不正: ", modOrErr)
		end
	else
		local folder = ReplicatedStorage:FindFirstChild("Sounds")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Sounds"
			folder.Parent = ReplicatedStorage
		end
		local function ensure(name, id, vol)
			local s = folder:FindFirstChild(name)
			if not s then
				s = Instance.new("Sound")
				s.Name = name
				s.SoundId = id
				s.Volume = vol
				s.Parent = folder
			end
		end
		ensure("TypingCorrect", "rbxassetid://159534615", 0.4)
		ensure("TypingError", "rbxassetid://113721818600044", 0.5)
		ensure("EnemyHit", "rbxassetid://155288625", 0.6)
		warn("[Bootstrap] SoundRegistry が見つかないため、暫定 Sounds を用意")
	end
end

-- ZoneManager等のロード
local ZoneManager = require(script.Parent:WaitForChild("ZoneManager"))
local PlayerStatsModule = require(script.Parent:WaitForChild("PlayerStats"))
local DataStoreManager = require(ServerScriptService:WaitForChild("DataStoreManager"))
local DataCollectors = require(ServerScriptService:WaitForChild("DataCollectors"))

local START_ZONE_NAME = "ContinentTown"
local LastLoadedData = {}

-- PlayerStatsの初期化
PlayerStatsModule.init()

print("[Bootstrap DEBUG] PlayerStatsModule.init() を呼び出しました。") -- ★デバッグ追加

print("[Bootstrap] 街を生成中（非同期）...")
task.spawn(function()
	ZoneManager.LoadZone(START_ZONE_NAME)
	print("[Bootstrap] 地形生成完了")
end)

-- 街の設定を取得
local IslandsRegistry = require(ReplicatedStorage.Islands.Registry)
local townConfig = nil
for _, island in ipairs(IslandsRegistry) do
	if island.name == "StartTown" then
		townConfig = island
		break
	end
end

if not townConfig then
	warn("[Bootstrap] StartTown の設定が見つかりません！")
	return
end

-- セーブイベントハンドラ
SaveGameEvent.OnServerEvent:Connect(function(player)
	print(("[Bootstrap] 💾 %s からセーブリクエスト受信"):format(player.Name))

	local stats = PlayerStatsModule.getStats(player)
	if not stats then
		warn(("[Bootstrap] ❌ %s のステータスが見つかりません"):format(player.Name))
		SaveSuccessEvent:FireClient(player, false)
		return
	end

	local saveData = DataCollectors.createSaveData(player, stats)
	local success = DataStoreManager.SaveData(player, saveData)

	if success then
		print(("[Bootstrap] ✅ %s のセーブ成功"):format(player.Name))
	else
		warn(("[Bootstrap] ❌ %s のセーブ失敗"):format(player.Name))
	end
end)

-- ★ プレイヤースポーン処理
local function setupPlayerSpawn(player)
	task.spawn(function()
		local totalStartTime = os.clock()

		-- DataStoreロード
		print(("[Bootstrap] %s のDataStoreロード開始"):format(player.Name))
		local loadedLocation = PlayerStatsModule.initPlayer(player)
		local fullLoadedData = PlayerStatsModule.getLastLoadedData(player)

		if not loadedLocation then
			warn(("[Bootstrap] %s のロードデータがnil、デフォルト使用"):format(player.Name))
			loadedLocation = {
				ZoneName = "ContinentTown",
				X = townConfig.centerX,
				Y = townConfig.baseY + 25,
				Z = townConfig.centerZ,
			}
		end

		LastLoadedData[player] = {
			Location = loadedLocation,
			FieldState = fullLoadedData and fullLoadedData.FieldState or nil,
			CurrentZone = fullLoadedData and fullLoadedData.CurrentZone or nil,
		}

		local targetZone = loadedLocation.ZoneName
		print(
			("[Bootstrap] ⏱️ DataStoreロード完了: %s (%.0f, %.0f, %.0f)"):format(
				targetZone,
				loadedLocation.X,
				loadedLocation.Y,
				loadedLocation.Z
			)
		)

		player:SetAttribute("ContinentName", targetZone)

		-- ゾーンロード（必要に応じて）
		if targetZone ~= START_ZONE_NAME then
			print(("[Bootstrap] キャラ生成前: %s のゾーンをロード"):format(targetZone))
			ZoneManager.LoadZone(targetZone)
			task.wait(2)
		end

		-- キャラクター生成と同時にワープ
		print(("[Bootstrap] %s のキャラクター生成を開始"):format(player.Name))

		local connection
		connection = player.CharacterAdded:Connect(function(character)
			connection:Disconnect()
			print(("[Bootstrap] ✓ キャラクター生成完了"):format())

			-- HRPを取得してワープ
			task.spawn(function()
				local hrp = character:WaitForChild("HumanoidRootPart", 5)
				if not hrp then
					warn(("[Bootstrap] %s のHRPが見つかりません"):format(player.Name))
					-- フォールバック：でもイベントは発火
					SpawnReadyEvent:FireClient(player)
					return
				end

				-- ★ 修正：ロード時のワープ先座標を LastLoadedData から取得
				local warpLocation = LastLoadedData[player] and LastLoadedData[player].Location
				if not warpLocation then
					warn(("[Bootstrap] %s のロードデータがnil、デフォルト使用"):format(player.Name))
					warpLocation = {
						ZoneName = "ContinentTown",
						X = townConfig.centerX,
						Y = townConfig.baseY + 25,
						Z = townConfig.centerZ,
					}
				end

				local targetZone = warpLocation.ZoneName

				-- ワープ実行 (WarpPlayerToZone はモンスターをスポーン *しない* ことに注意)
				ZoneManager.WarpPlayerToZone(player, targetZone)

				-- ★ 修正：ロードした正確な座標に移動
				hrp.CFrame = CFrame.new(warpLocation.X, warpLocation.Y, warpLocation.Z)

				print(
					("[Bootstrap] ✓ %s をワープ完了 (%.0f, %.0f, %.0f)"):format(
						player.Name,
						warpLocation.X,
						warpLocation.Y,
						warpLocation.Z
					)
				)

				-- 【重要】ワープ完了 → 即座にローディング画面を解除
				print(("[Bootstrap] [SpawnReady] %s に通知を送信"):format(player.Name))
				SpawnReadyEvent:FireClient(player)

				-- ▼▼▼【ここからが修正箇所】▼▼▼
				-- 以下、並行処理で復元・初期化を実行
				task.spawn(function()
					task.wait(1)

					if LastLoadedData[player] and LastLoadedData[player].FieldState then
						-- 【A: セーブデータがある場合】
						local zoneName = LastLoadedData[player].CurrentZone
						print(("[Bootstrap] %s のフィールド状態を復元: %s"):format(player.Name, zoneName))

						-- 1. モンスターを復元
						DataCollectors.restoreFieldState(zoneName, LastLoadedData[player].FieldState)

						-- 2. ポータルを生成
						if _G.CreatePortalsForZone then
							_G.CreatePortalsForZone(zoneName)
						end
					else
						-- 【B: セーブデータがない場合 (新規 or セーブせず終了)】
						print(
							("[Bootstrap] %s は初回プレイ、または復元データなし"):format(player.Name)
						)

						-- ★ 修正：FastTravelSystem任せにせず、ここで通常スポーンを実行する
						if _G.SpawnMonstersForZone then
							print(
								("[Bootstrap] %s のために %s の通常モンスターをスポーン"):format(
									player.Name,
									targetZone
								)
							)
							_G.SpawnMonstersForZone(targetZone)
						else
							warn("[Bootstrap] _G.SpawnMonstersForZone が見つかりません")
						end

						-- 2. ポータルを生成
						if _G.CreatePortalsForZone then
							_G.CreatePortalsForZone(targetZone)
						end
					end

					LastLoadedData[player] = nil
				end)

				-- ステータス更新
				task.spawn(function()
					local stats = PlayerStatsModule.getStats(player)
					if stats then
						local expToNext = stats.Level * 100
						local StatusUpdateEvent = ReplicatedStorage:FindFirstChild("StatusUpdate")
						if StatusUpdateEvent then
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
				end)

				print(("[Bootstrap] ⏱️ 合計時間: %.2f秒"):format(os.clock() - totalStartTime))
			end)
		end)

		player:LoadCharacter()
	end)
end

-- 既存プレイヤー対応
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerSpawn(player)
end

-- 新規プレイヤー対応
Players.PlayerAdded:Connect(setupPlayerSpawn)

-- クリーンアップ
Players.PlayerRemoving:Connect(function(player)
	LastLoadedData[player] = nil
end)

print("[Bootstrap] === ゲーム初期化完了 ===")

-- ★【新規追加】MenuUIの「ロード」ボタン（Studio用）の処理
local RequestLoadRespawnEvent = ReplicatedStorage:FindFirstChild("RequestLoadRespawn")
if RequestLoadRespawnEvent then
	RequestLoadRespawnEvent.OnServerEvent:Connect(function(player)
		print(("[Bootstrap] %s からロード（リスポーン）要求を受信"):format(player.Name))

		-- 既存の setupPlayerSpawn 関数を再利用して、ロード処理を強制実行
		setupPlayerSpawn(player)
	end)
else
	warn("[Bootstrap] RequestLoadRespawnEvent が見つかりません")
end

print(("[Bootstrap] プレイヤーは街（%s）からスタートします"):format(START_ZONE_NAME))
