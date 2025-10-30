-- ServerScriptService/FastTravelSystem.server.lua
-- 改善版：ローディング画面にプレイヤーレベルを送信

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

print("[FastTravel] 初期化開始")

local ContinentsRegistry = require(ReplicatedStorage:WaitForChild("Continents"):WaitForChild("Registry"))
local IslandsRegistry = require(ReplicatedStorage:WaitForChild("Islands"):WaitForChild("Registry"))
local ZoneManager = require(game:GetService("ServerScriptService"):WaitForChild("ZoneManager", 10))
local PlayerStatsModule = require(ServerScriptService:WaitForChild("PlayerStats"))

-- IslandsRegistry を辞書形式に変換
local Islands = {}
for _, island in ipairs(IslandsRegistry) do
	if island and island.name then
		Islands[island.name] = island
	end
end

-- RemoteEvent 作成
local FastTravelEvent = ReplicatedStorage:FindFirstChild("FastTravelEvent")
if not FastTravelEvent then
	FastTravelEvent = Instance.new("RemoteEvent")
	FastTravelEvent.Name = "FastTravelEvent"
	FastTravelEvent.Parent = ReplicatedStorage
	print("[FastTravel] FastTravelEvent を作成しました")
end

local GetContinentsEvent = ReplicatedStorage:FindFirstChild("GetContinentsEvent")
if not GetContinentsEvent then
	GetContinentsEvent = Instance.new("RemoteFunction")
	GetContinentsEvent.Name = "GetContinentsEvent"
	GetContinentsEvent.Parent = ReplicatedStorage
	print("[FastTravel] GetContinentsEvent を作成しました")
end

-- 大陸一覧を取得
local function getContinentsList()
	local continents = {}

	for _, continent in ipairs(ContinentsRegistry) do
		table.insert(continents, {
			name = continent.name,
			displayName = continent.displayName or continent.name,
		})
	end

	return continents
end

-- ワープ処理（改善版：プレイヤーレベルをローディング画面に送信）
local function handleFastTravel(player, continentName)
	print(("[FastTravel] %s が %s へのワープを要求"):format(player.Name, continentName))

	-- バリデーション
	local continent = nil
	for _, cont in ipairs(ContinentsRegistry) do
		if cont.name == continentName then
			continent = cont
			break
		end
	end

	if not continent then
		warn(("[FastTravel] 大陸 '%s' が見つかりません"):format(continentName))
		return false
	end

	-- プレイヤーレベルを取得
	local stats = PlayerStatsModule.getStats(player)
	local playerLevel = stats and stats.Level or 1
	print(("[FastTravel] プレイヤー %s のレベル: %d"):format(player.Name, playerLevel))

	-- クライアントにローディング開始を通知（レベル付き）
	FastTravelEvent:FireClient(player, "StartLoading", continentName, playerLevel)
	task.wait(0.2)

	-- ZoneManager.WarpPlayerToZone() を呼び出し
	local success = ZoneManager.WarpPlayerToZone(player, continentName)

	if success then
		print(("[FastTravel] %s を %s にワープしました"):format(player.Name, continentName))

		-- モンスターとポータルを生成（非同期）
		task.spawn(function()
			task.wait(1)

			-- モンスター生成
			if _G.SpawnMonstersForZone then
				_G.SpawnMonstersForZone(continentName)
				print(("[FastTravel] %s のモンスターを生成しました"):format(continentName))
			else
				warn("[FastTravel] SpawnMonstersForZone が見つかりません")
			end

			-- ポータル生成
			if _G.CreatePortalsForZone then
				_G.CreatePortalsForZone(continentName)
				print(("[FastTravel] %s のポータルを生成しました"):format(continentName))
			else
				warn("[FastTravel] CreatePortalsForZone が見つかりません")
			end

			-- 生成完了後、クライアントにローディング終了を通知
			FastTravelEvent:FireClient(player, "EndLoading", continentName, playerLevel)
		end)
	else
		warn(("[FastTravel] %s のワープに失敗しました"):format(player.Name))
		FastTravelEvent:FireClient(player, "EndLoading", continentName, playerLevel)
	end

	return success
end

-- イベント接続
GetContinentsEvent.OnServerInvoke = function(player)
	return getContinentsList()
end

FastTravelEvent.OnServerEvent:Connect(function(player, continentName)
	handleFastTravel(player, continentName)
end)

print("[FastTravel] 初期化完了")
