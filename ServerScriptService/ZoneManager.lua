-- ServerScriptService/ZoneManager.lua
-- 改善版：古い大陸を削除 + Town常駐 + ワープロジック統一

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local FieldGen = require(ReplicatedStorage:WaitForChild("FieldGen"))

local ZoneManager = {}

ZoneManager.ActiveZones = {}
ZoneManager.PlayerZones = {}

local IslandsRegistry = require(ReplicatedStorage.Islands.Registry)
local ContinentsRegistry = require(ReplicatedStorage.Continents.Registry)

-- 島の設定をマップ化
local Islands = {}
for _, island in ipairs(IslandsRegistry) do
	Islands[island.name] = island
end

-- 大陸の設定をマップ化
local Continents = {}
for _, continent in ipairs(ContinentsRegistry) do
	if continent and continent.name then
		Continents[continent.name] = continent
	else
		warn("[ZoneManager] 名前が設定されていない大陸定義をスキップしました")
	end
end

-- print("[ZoneManager] 初期化完了。島数:", #IslandsRegistry, "大陸数:", #ContinentsRegistry)

-- DisplayConfig（任意）
local DisplayConfig
do
	local ok, cfg = pcall(function()
		local cfgFolder = ReplicatedStorage:FindFirstChild("Config")
		if not cfgFolder then
			return nil
		end
		local m = cfgFolder:FindFirstChild("DisplayConfig")
		if not m then
			return nil
		end
		return require(m)
	end)
	if ok then
		DisplayConfig = cfg
	else
		DisplayConfig = nil
	end
end

-- ZoneChangeイベント（クライアント通知用）
local ZoneChangeEvent = ReplicatedStorage:FindFirstChild("ZoneChange")
if not ZoneChangeEvent then
	ZoneChangeEvent = Instance.new("RemoteEvent")
	ZoneChangeEvent.Name = "ZoneChange"
	ZoneChangeEvent.Parent = ReplicatedStorage
	print("[ZoneManager] ZoneChangeイベントを作成しました")
end

-- 定数
local TOWN_ZONE_NAME = "ContinentTown"
local PERMANENT_ZONES = { TOWN_ZONE_NAME }

-- ゾーンが大陸かチェック
local function isContinent(zoneName)
	return Continents[zoneName] ~= nil
end

-- プレイヤーのゾーンを更新
local function updatePlayerZone(player, newZone)
	local oldZone = ZoneManager.PlayerZones[player]

	if oldZone == newZone then
		return
	end

	if oldZone then
		print(("[ZoneManager] %s が %s から出ました"):format(player.Name, oldZone))
		ZoneChangeEvent:FireClient(player, oldZone, false)
	end

	if newZone then
		print(("[ZoneManager] %s が %s に入りました"):format(player.Name, newZone))
		ZoneManager.PlayerZones[player] = newZone
		ZoneChangeEvent:FireClient(player, newZone, true)
	else
		ZoneManager.PlayerZones[player] = nil
	end
end

-- 島ラベル（BillboardGui）生成
local function createIslandLabel(cfg)
	if not (cfg and cfg.showIslandLabel) then
		return
	end

	local worldFolder = workspace:FindFirstChild("World")
	if not worldFolder then
		worldFolder = Instance.new("Folder")
		worldFolder.Name = "World"
		worldFolder.Parent = workspace
	end

	local anchorName = (cfg.name or "Island") .. "_LabelAnchor"
	local old = worldFolder:FindFirstChild(anchorName)
	if old then
		old:Destroy()
	end

	local anchor = Instance.new("Part")
	anchor.Name = anchorName
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1

	local baseY = cfg.baseY or 0
	local thickness = cfg.thickness or 0
	local labelOffset = cfg.labelOffsetY or 6
	anchor.Position = Vector3.new(cfg.centerX, baseY + thickness + labelOffset, cfg.centerZ)
	anchor.Parent = worldFolder

	local bb = Instance.new("BillboardGui")
	bb.Name = "Nameplate"
	bb.AlwaysOnTop = true
	bb.MaxDistance = cfg.labelMaxDistance or 5000
	bb.Size = UDim2.fromOffset(260, 72)
	bb.Parent = anchor

	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	bg.BackgroundTransparency = (cfg._labelBgTrans ~= nil) and cfg._labelBgTrans or 0.35
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bg

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextWrapped = true
	label.RichText = false
	label.Font = cfg._labelFont or Enum.Font.GothamBold
	label.TextScaled = false
	label.TextSize = cfg._labelTextSize or 16
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.Text = string.format("%s\n(%.1f, %.1f)", tostring(cfg.name or "Island"), cfg.centerX, cfg.centerZ)
	label.Parent = bg

	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = bg
end

-- 大陸をロード
local function loadContinent(continentName)
	local continent = Continents[continentName]
	if not continent then
		warn(("[ZoneManager] 大陸 '%s' が見つかりません"):format(continentName))
		return false
	end

	print(("[ZoneManager] 大陸生成開始: %s"):format(continentName))

	local showForThisContinent = false
	local labelParams = nil
	if DisplayConfig and DisplayConfig.isEnabledFor and DisplayConfig.getParamsFor then
		showForThisContinent = DisplayConfig.isEnabledFor(continent.name)
		labelParams = DisplayConfig.getParamsFor(continent.name)
	end

	-- 含まれる全ての島を生成
	for _, islandName in ipairs(continent.islands) do
		local islandConfig = Islands[islandName]
		if islandConfig then
			if showForThisContinent and labelParams then
				islandConfig.showIslandLabel = (labelParams.showIslandLabel ~= false)
				islandConfig.labelOffsetY = labelParams.labelOffsetY
				islandConfig.labelMaxDistance = labelParams.labelMaxDistance
				islandConfig._labelFont = labelParams.font
				islandConfig._labelTextSize = labelParams.textSize
				islandConfig._labelBgTrans = labelParams.backgroundTransparency
			end

			-- print(("[ZoneManager]   - 島を生成: %s"):format(islandName))
			FieldGen.generateIsland(islandConfig)
		else
			warn(("[ZoneManager]   - 島が見つかりません: %s"):format(islandName))
		end
	end

	-- 湖を生成
	if continent.lakes then
		-- print(("[ZoneManager] 湖を生成: %d 個"):format(#continent.lakes))
		for _, lakeConfig in ipairs(continent.lakes) do
			FieldGen.generateLake(lakeConfig)
		end
	end

	-- 川を生成
	if continent.rivers then
		-- print(("[ZoneManager] 川を生成: %d 本"):format(#continent.rivers))
		for _, riverConfig in ipairs(continent.rivers) do
			FieldGen.generateRiver(riverConfig)
		end
	end

	-- 橋を生成
	if continent.bridges then
		for _, bridgeConfig in ipairs(continent.bridges) do
			local fromIsland = Islands[bridgeConfig.fromIsland]
			local toIsland = Islands[bridgeConfig.toIsland]

			if fromIsland and toIsland then
				-- print(("[ZoneManager]   - 橋を生成: %s"):format(bridgeConfig.name))
				FieldGen.generateBridge(fromIsland, toIsland, bridgeConfig)
			else
				warn(("[ZoneManager]   - 橋の生成失敗: %s"):format(bridgeConfig.name))
			end
		end
	end

	ZoneManager.ActiveZones[continentName] = {
		config = continent,
		loadedAt = os.time(),
	}

	-- 追加オブジェクト
	if continent.fieldObjects and #continent.fieldObjects > 0 then
		-- print(("[ZoneManager] 追加オブジェクトを配置: %d 個"):format(#continent.fieldObjects))
		FieldGen.placeFieldObjects(continent.name, continent.fieldObjects)
	end

	-- ▼ 【重要】ここで待機してから道を生成
	task.wait(0.5) -- ← Terrain生成完了を待つ
	-- print("[ZoneManager] Terrain生成完了、パス生成を開始")

	-- ▼ 道を生成
	if continent.paths then
		local arr = continent.paths
		if #arr == 0 and arr.points then
			arr = { continent.paths }
		end
		if #arr > 0 then
			-- print("[ZoneManager] 道を引きます: " .. tostring(#arr) .. " 個のパス")
			FieldGen.buildPaths(continent.name, arr)
		end
	end

	print(("[ZoneManager] 大陸生成完了: %s"):format(continentName))

	-- ZoneManager.lua の loadContinent 関数内の最後に追加

	-- ===== 【診断】buildPaths 前のレイキャストテスト =====
	-- print("[ZoneManager診断] Terrain レイキャストテスト開始...")

	-- local testX, testZ = 405.2, 719.5
	-- local testStartY = 3600
	-- local testParams = RaycastParams.new()
	-- testParams.FilterType = Enum.RaycastFilterType.Include
	-- testParams.FilterDescendantsInstances = { workspace.Terrain }
	-- testParams.IgnoreWater = false

	-- -- local testHit = workspace:Raycast(Vector3.new(testX, testStartY, testZ), Vector3.new(0, -5000, 0), testParams)

	-- -- if testHit then
	-- -- 	print(string.format("[ZoneManager診断] ✓ レイキャスト成功: Y=%.1f", testHit.Position.Y))
	-- -- else
	-- -- 	print(string.format("[ZoneManager診断] ✗ レイキャスト失敗: Terrain が見つかりません"))
	-- -- 	print(string.format("[ZoneManager診断] テスト座標: (%.1f, _, %.1f)", testX, testZ))

	-- -- 	-- Terrain の存在確認
	-- -- 	local terrain = workspace.Terrain
	-- -- 	-- print(string.format("[ZoneManager診断] Terrain 存在: %s", terrain ~= nil))
	-- -- 	print(string.format("[ZoneManager診断] Terrain の大きさ: %s", tostring(terrain.Size)))
	-- -- end

	-- print("[ZoneManager診断] Terrain レイキャストテスト終了")
	-- ===== 診断ここまで =====

	return true
end

-- ゾーンをロード
function ZoneManager.LoadZone(zoneName)
	if ZoneManager.ActiveZones[zoneName] then
		print(("[ZoneManager] %s は既に生成済みです"):format(zoneName))
		return true
	end

	if isContinent(zoneName) then
		return loadContinent(zoneName)
	else
		warn(("[ZoneManager] ゾーン '%s' は大陸ではありません"):format(zoneName))
		return false
	end
end

-- ゾーンをアンロード（完全削除）
function ZoneManager.UnloadZone(zoneName)
	if not ZoneManager.ActiveZones[zoneName] then
		return
	end

	print(("[ZoneManager] ゾーン削除開始: %s"):format(zoneName))

	if not isContinent(zoneName) then
		warn(("[ZoneManager] ゾーン '%s' は大陸ではありません"):format(zoneName))
		return
	end

	local continent = Continents[zoneName]
	local terrain = workspace.Terrain

	-- ステップ1: Terrain（地形）を削除
	local configsToUnload = {}
	for _, islandName in ipairs(continent.islands) do
		table.insert(configsToUnload, Islands[islandName])
	end

	for _, config in ipairs(configsToUnload) do
		if config then
			local halfSize = config.sizeXZ / 2 + 50
			-- 山の頂上まで削除するため、hillAmplitude を考慮
			local maxHeight = config.baseY + (config.hillAmplitude or 20) + 50
			local region = Region3.new(
				Vector3.new(config.centerX - halfSize, config.baseY - 50, config.centerZ - halfSize),
				Vector3.new(config.centerX + halfSize, maxHeight, config.centerZ + halfSize)
			)
			region = region:ExpandToGrid(4)
			terrain:FillRegion(region, 4, Enum.Material.Air)
		end
	end

	-- ステップ2: モンスター削除
	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("IsEnemy") then
			local spawnZone = model:GetAttribute("SpawnZone")
			if spawnZone == zoneName then
				model:Destroy()
			end
		end
	end

	-- ステップ3: ポータル削除
	if _G.DestroyPortalsForZone then
		_G.DestroyPortalsForZone(zoneName)
	end

	-- ステップ4: フィールドオブジェクト削除
	local fieldObjectsFolder = workspace:FindFirstChild("FieldObjects")
	if fieldObjectsFolder then
		local zoneFolder = fieldObjectsFolder:FindFirstChild(zoneName)
		if zoneFolder then
			zoneFolder:Destroy()
		end
	end

	ZoneManager.ActiveZones[zoneName] = nil
	print(("[ZoneManager] ゾーン削除完了: %s"):format(zoneName))
end

-- プレイヤーをワープ（改善版）
function ZoneManager.WarpPlayerToZone(player, zoneName)
	print(("[ZoneManager] %s を %s にワープ中..."):format(player.Name, zoneName))

	if not isContinent(zoneName) then
		warn(("[ZoneManager] ゾーン '%s' は大陸ではありません"):format(player.Name))
		return false
	end

	local character = player.Character
	if not character then
		warn(("[ZoneManager] %s のキャラクターが見つかりません"):format(player.Name))
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	-- ========== 改善: ワープフロー ==========

	-- フェーズ1: 現在のゾーンを取得
	local currentZone = ZoneManager.GetPlayerZone(player)
	print(("[ZoneManager] 現在のゾーン: %s"):format(currentZone or "nil"))

	-- フェーズ2: 古い大陸をアンロード（Town は除外）
	if currentZone and currentZone ~= zoneName and not table.find(PERMANENT_ZONES, currentZone) then
		print(("[ZoneManager] 古い大陸をアンロード: %s"):format(currentZone))
		ZoneManager.UnloadZone(currentZone)
	end

	-- フェーズ3: Town を常駐させる
	if zoneName ~= TOWN_ZONE_NAME and not ZoneManager.ActiveZones[TOWN_ZONE_NAME] then
		print(("[ZoneManager] Town をロード（常駐）"):format())
		ZoneManager.LoadZone(TOWN_ZONE_NAME)
	end

	-- フェーズ4: 目的地ゾーンをロード
	if not ZoneManager.ActiveZones[zoneName] then
		print(("[ZoneManager] 目的地ゾーンをロード: %s"):format(zoneName))
		ZoneManager.LoadZone(zoneName)
	end

	-- フェーズ5: ワープ先座標を決定
	local continent = Continents[zoneName]
	local firstIslandName = continent.islands[1]
	local firstIsland = Islands[firstIslandName]

	if not firstIsland then
		warn(
			("[ZoneManager] 大陸 '%s' の最初の島 '%s' が見つかりません"):format(
				zoneName,
				firstIslandName
			)
		)
		return false
	end

	local targetX = firstIsland.centerX
	local targetZ = firstIsland.centerZ
	local baseY = firstIsland.baseY
	local hillAmplitude = firstIsland.hillAmplitude or 20

	-- フェーズ6: 地面検出
	local rayStartY = baseY + hillAmplitude + 100
	local groundY = FieldGen.raycastGroundY(targetX, targetZ, rayStartY)

	local spawnY
	if groundY then
		spawnY = groundY + 5
		print(("[ZoneManager] 地面検出成功: Y=%.1f"):format(groundY))
	else
		spawnY = baseY + (hillAmplitude * 0.6) + 10
		warn(("[ZoneManager] 地面検出失敗、予想高度使用: Y=%.1f"):format(spawnY))
	end

	-- フェーズ7: プレイヤーをワープ
	hrp.CFrame = CFrame.new(targetX, spawnY, targetZ)
	updatePlayerZone(player, zoneName)

	print(
		("[ZoneManager] %s を %s にワープ完了 (%.1f, %.1f, %.1f)"):format(
			player.Name,
			zoneName,
			targetX,
			spawnY,
			targetZ
		)
	)

	return true
end

function ZoneManager.GetPlayerZone(player)
	return ZoneManager.PlayerZones[player]
end

-- プレイヤー退出時の処理
Players.PlayerRemoving:Connect(function(player)
	local oldZone = ZoneManager.PlayerZones[player]
	if oldZone then
		print(("[ZoneManager] %s が退出しました。ゾーン: %s"):format(player.Name, oldZone))
		ZoneManager.PlayerZones[player] = nil
	end
end)

return ZoneManager
