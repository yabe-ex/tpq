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

-- ファストトラベル可能なポータル一覧を取得
local function getFastTravelTargetsList()
	local targets = {}

	for _, continent in ipairs(ContinentsRegistry) do
		-- 大陸に portals 定義があるか確認
		if continent.portals then
			for _, portal in ipairs(continent.portals) do
				-- isFastTravelTarget が true で、かつ Terrainワープではないポータルのみを対象とする
				if portal.isFastTravelTarget and not portal.isTerrain then
					table.insert(targets, {
						continentName = continent.name, -- 移動先の大陸名
						portalName = portal.name, -- ポータルの名前（UI表示用）
						displayName = portal.name, -- UI表示名としてポータル名を使用
					})
				end
			end
		end
	end

	return targets
end

-- ワープ処理（改善版：プレイヤーレベルをローディング画面に送信）
local function handleFastTravel(player, continentName, portalName)
	print(
		("[FastTravel] [DEBUG] ワープ要求受信: Player=%s, Continent=%s, Portal=%s"):format(
			player.Name,
			continentName,
			portalName or "（大陸デフォルト）"
		)
	)

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

	local targetPortal = nil
	local spawnPosition = nil

	if portalName then
		-- ポータル名が指定されている場合、ポータル定義から spawnPosition を取得
		if continent.portals then
			for _, portal in ipairs(continent.portals) do
				if portal.name == portalName and portal.isFastTravelTarget and not portal.isTerrain then
					targetPortal = portal
					local basePosition = portal.position
					spawnPosition = {
						basePosition[1] - 4, -- X座標から4を引く
						basePosition[2], -- Y座標はそのまま
						basePosition[3] - 4, -- Z座標から4を引く
					}
					break
				end
			end
		end

		if not targetPortal or not spawnPosition then
			warn(
				("[FastTravel] [DEBUG] ポータル検索失敗: 大陸 '%s' にファストトラベル対象のポータル '%s' が見つかりません"):format(
					continentName,
					portalName
				)
			)
			return false
		end
	end

	-- プレイヤーレベルを取得
	local stats = PlayerStatsModule.getStats(player)
	local playerLevel = stats and stats.Level or 1
	print(("[FastTravel] プレイヤー %s のレベル: %d"):format(player.Name, playerLevel))

	-- クライアントにローディング開始を通知（レベル付き）
	FastTravelEvent:FireClient(player, "StartLoading", continentName, playerLevel)
	task.wait(0.2)

	local success
	if spawnPosition then
		-- 座標指定ワープ
		print(
			("[FastTravel] [DEBUG] ZoneManager.WarpPlayerToZoneWithPosition 呼び出し: Zone=%s, Pos=%s"):format(
				continentName,
				tostring(spawnPosition)
			)
		)
		success = ZoneManager.WarpPlayerToZoneWithPosition(player, continentName, spawnPosition)
	else
		-- 大陸デフォルトワープ（ファストトラベルの旧仕様）
		print(("[FastTravel] [DEBUG] ZoneManager.WarpPlayerToZone 呼び出し: Zone=%s"):format(continentName))
		success = ZoneManager.WarpPlayerToZone(player, continentName)
	end

	if success then
		print(("[FastTravel] %s を %s にワープしました"):format(player.Name, continentName))

		-- モンスターとポータルを生成（非同期）
		task.spawn(function()
			task.wait(1)

			-- ★ 【重要】モンスター生成時に、既存のモンスターをカウント
			-- 既にモンスターがいる場合はスキップ（セーブ復元済みの可能性）
			local totalMonsters = 0
			if _G.GetZoneMonsterCounts then
				local currentCounts = _G.GetZoneMonsterCounts(continentName)

				if currentCounts then
					for monsterName, count in pairs(currentCounts) do
						totalMonsters = totalMonsters + count
					end
				end

				print(("[FastTravel] %s の現在のモンスター数: %d"):format(continentName, totalMonsters))
			end

			-- ★ 【判定】モンスターがいない場合のみ生成
			if totalMonsters == 0 then
				-- モンスター生成
				if _G.SpawnMonstersForZone then
					_G.SpawnMonstersForZone(continentName)
					print(("[FastTravel] %s のモンスターを生成しました"):format(continentName))
				else
					warn("[FastTravel] SpawnMonstersForZone が見つかりません")
				end
			else
				print(
					("[FastTravel] %s にはすでに %d体のモンスターがいます。新規生成をスキップ"):format(
						continentName,
						totalMonsters
					)
				)
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
	return getFastTravelTargetsList()
end

FastTravelEvent.OnServerEvent:Connect(function(player, continentName, portalName)
	handleFastTravel(player, continentName, portalName)
end)

print("[FastTravel] 初期化完了")
