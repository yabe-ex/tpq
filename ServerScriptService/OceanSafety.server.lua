-- ServerScriptService/OceanSafety.server.lua
-- 改善版：各ゾーンのリスポーン位置を動的に取得

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[OceanSafety] 初期化開始")

-- 設定
local WATER_LEVEL = -25 -- この高さより下に落ちたら処理
local CHECK_INTERVAL = 0.5 -- チェック間隔（秒）

local ZoneManager = require(game:GetService("ServerScriptService").ZoneManager)
local Islands = require(ReplicatedStorage.Islands.Registry)
local Continents = require(ReplicatedStorage.Continents.Registry)

-- 島をマップ化
local IslandsMap = {}
for _, island in ipairs(Islands) do
	IslandsMap[island.name] = island
end

-- 大陸をマップ化
local ContinentsMap = {}
for _, continent in ipairs(Continents) do
	if continent and continent.name then
		ContinentsMap[continent.name] = continent
	end
end

-- 指定ゾーンのリスポーン位置を取得
local function getZoneSpawnPosition(zoneName)
	local continent = ContinentsMap[zoneName]

	-- TerrainBaseの場合、spawnPositionを直接使用
	if continent and continent.spawnPosition then
		return Vector3.new(continent.spawnPosition[1], continent.spawnPosition[2], continent.spawnPosition[3])
	end

	if not continent or not continent.islands or #continent.islands == 0 then
		warn(("[OceanSafety] ゾーン '%s' が見つかりません"):format(zoneName))
		-- フォールバック: TerrainBase の座標を使用
		local terrainContinent = ContinentsMap["TerrainBase"]
		if terrainContinent and terrainContinent.spawnPosition then
			return Vector3.new(
				terrainContinent.spawnPosition[1],
				terrainContinent.spawnPosition[2],
				terrainContinent.spawnPosition[3]
			)
		else
			return Vector3.new(377.3, 5131.0, 112.4) -- 最後の手段：TerrainBaseのデフォルト座標
		end
	end

	-- 最初の島を取得
	local firstIslandName = continent.islands[1]
	local firstIsland = IslandsMap[firstIslandName]

	if not firstIsland then
		warn(
			("[OceanSafety] 大陸 '%s' の最初の島 '%s' が見つかりません"):format(
				zoneName,
				firstIslandName
			)
		)
		return Vector3.new(0, 20, 0)
	end

	local spawnX = firstIsland.centerX
	local spawnZ = firstIsland.centerZ
	local spawnY = firstIsland.baseY + 25

	return Vector3.new(spawnX, spawnY, spawnZ)
end

print("[OceanSafety] 初期化完了")

-- プレイヤーの監視
local monitorPlayer = function(player)
	player.CharacterAdded:Connect(function(character)
		local hrp = character:WaitForChild("HumanoidRootPart")
		local humanoid = character:WaitForChild("Humanoid")

		local lastCheck = 0
		local spawnTime = os.clock() -- ★ スポーン時刻記録
		local SPAWN_GRACE_PERIOD = 2 -- ★ 2秒間は海判定を無視

		RunService.Heartbeat:Connect(function()
			if not character.Parent or not hrp.Parent then
				return
			end

			local now = os.clock()

			-- ★ スポーン直後は処理をスキップ
			if now - spawnTime < SPAWN_GRACE_PERIOD then
				return
			end

			if now - lastCheck < CHECK_INTERVAL then
				return
			end
			lastCheck = now

			-- 水面より下に落ちたかチェック
			if hrp.Position.Y < WATER_LEVEL then
				print(("[OceanSafety] %s が海に落ちました。リスポーン中..."):format(player.Name))

				-- 現在のゾーンを取得
				local currentZone = ZoneManager.GetPlayerZone(player)
				local spawnPos = getZoneSpawnPosition(currentZone or "TerrainBase")

				-- 速度をゼロに
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero

				-- ゾーンの中心に戻す
				hrp.CFrame = CFrame.new(spawnPos)

				-- 体力を少し減らす（ペナルティ）
				-- if humanoid.Health > 10 then
				-- 	humanoid.Health = humanoid.Health - 10
				-- end

				print(
					("[OceanSafety] %s をリスポーン完了: (%.1f, %.1f, %.1f)"):format(
						player.Name,
						spawnPos.X,
						spawnPos.Y,
						spawnPos.Z
					)
				)
			end
		end)
	end)
end

-- 既存プレイヤーと新規プレイヤーに適用
for _, player in ipairs(Players:GetPlayers()) do
	monitorPlayer(player)
end
Players.PlayerAdded:Connect(monitorPlayer)

-- モンスターの監視
RunService.Heartbeat:Connect(function()
	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("IsEnemy") then
			local hrp = model:FindFirstChild("HumanoidRootPart")

			if hrp and hrp.Position.Y < WATER_LEVEL then
				model:Destroy()
			end
		end
	end
end)
