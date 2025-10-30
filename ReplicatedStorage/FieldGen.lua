-- ReplicatedStorage/FieldGen

local FieldGen = {}

-- ノイズ関数（変更なし）
local function noise2D(x, z, scale)
	local s = (x / scale + z / scale * 57)
	return (math.sin(s * 12.9898) * 43758.5453) % 1
end

local function smoothNoise(x, z, scale)
	local intX, intZ = math.floor(x / scale), math.floor(z / scale)
	local fracX, fracZ = (x / scale) - intX, (z / scale) - intZ

	local v1 = noise2D(intX, intZ, 1)
	local v2 = noise2D(intX + 1, intZ, 1)
	local v3 = noise2D(intX, intZ + 1, 1)
	local v4 = noise2D(intX + 1, intZ + 1, 1)

	local i1 = v1 * (1 - fracX) + v2 * fracX
	local i2 = v3 * (1 - fracX) + v4 * fracX

	return i1 * (1 - fracZ) + i2 * fracZ
end

-- 【最適化1】バッチ生成システム
local function fillTerrainBatch(terrain, blocks)
	local batchSize = 200 -- 一度に処理する数
	local totalBlocks = #blocks
	-- print("[FieldGen] バッチ生成スタート")
	for i = 1, totalBlocks, batchSize do
		local endIdx = math.min(i + batchSize - 1, totalBlocks)

		for j = i, endIdx do
			local block = blocks[j]
			terrain:FillBlock(block.cframe, block.size, block.material)
		end

		-- サーバーの負荷分散
		if i % 2000 == 0 then
			task.wait()
			print(("[FieldGen] 進行状況: %d/%d (%.1f%%)"):format(i, totalBlocks, i / totalBlocks * 100))
		end
	end
	-- print("[FieldGen] バッチ生成終了")
end

-- ReplicatedStorage/FieldGen.lua
-- 【修正】generateIsland 関数全体
function FieldGen.generateIsland(config)
	-- 島ピン（地面からの発光ポール＋先端ラベル）生成
	local function createIslandLabel(cfg)
		if not (cfg and cfg.showIslandLabel) then
			return
		end

		-- ---------------------------
		-- 1) World フォルダと既存掃除
		-- ---------------------------
		local worldFolder = workspace:FindFirstChild("World")
		if not worldFolder then
			worldFolder = Instance.new("Folder")
			worldFolder.Name = "World"
			worldFolder.Parent = workspace
		end

		-- 名前ベース
		local baseName = tostring(cfg.name or "Island")
		-- 残っている古いアンカー類を掃除
		for _, child in ipairs(worldFolder:GetChildren()) do
			if child:IsA("BasePart") then
				if
					child.Name == (baseName .. "_LabelAnchor")
					or child.Name == (baseName .. "_Pin")
					or child.Name == (baseName .. "_NameAnchor")
				then
					child:Destroy()
				end
			end
		end

		-- ---------------------------
		-- 2) 地面Yを測ってピンの寸法を決める
		-- ---------------------------
		local x, z = cfg.centerX, cfg.centerZ
		local startY = (cfg.baseY or 0) + (cfg.thickness or 0) + 200 -- 充分上から落とす
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = { workspace.Terrain }
		rayParams.IgnoreWater = false

		local res = workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -5000, 0), rayParams)
		local groundY = res and res.Position.Y or ((cfg.baseY or 0) + 1)

		-- ピンの高さ：島表面（だいたい baseY+thickness）まで伸ばし、少し頭出し
		local islandTopY = (cfg.baseY or 0) + (cfg.thickness or 0)
		local poleHeight = math.max(12, (islandTopY - groundY) + (cfg.labelOffsetY or 6))

		-- 3) 既存掃除（重複防止）※ _PinBase/_PinBeam/_PinCyl も消す
		for _, child in ipairs(worldFolder:GetChildren()) do
			if child:IsA("BasePart") then
				if
					child.Name == (baseName .. "_LabelAnchor")
					or child.Name == (baseName .. "_Pin")
					or child.Name == (baseName .. "_PinBase")
					or child.Name == (baseName .. "_NameAnchor")
					or child.Name == (baseName .. "_PinCyl")
				then
					child:Destroy()
				end
			elseif child:IsA("Beam") and child.Name == (baseName .. "_PinBeam") then
				child:Destroy()
			end
		end

		-- 3-a) 透明の基部/先端アンカー（Attachment用）
		local base = Instance.new("Part")
		base.Name = baseName .. "_PinBase"
		base.Anchored = true
		base.CanCollide = false
		base.CanQuery = false
		base.CastShadow = false
		base.Transparency = 1
		base.Size = Vector3.new(0.2, 0.2, 0.2)
		base.CFrame = CFrame.new(x, groundY + 0.1, z)
		base.Parent = worldFolder

		local tip = Instance.new("Part")
		tip.Name = baseName .. "_NameAnchor"
		tip.Anchored = true
		tip.CanCollide = false
		tip.CanQuery = false
		tip.CastShadow = false
		tip.Transparency = 1
		tip.Size = Vector3.new(0.2, 0.2, 0.2)
		tip.CFrame = CFrame.new(x, groundY + poleHeight, z)
		tip.Parent = worldFolder

		local a0 = Instance.new("Attachment")
		a0.Name = "PinA0"
		a0.Parent = base
		local a1 = Instance.new("Attachment")
		a1.Name = "PinA1"
		a1.Parent = tip

		-- 3-b) Beam（地面→先端の光る線）
		local beam = Instance.new("Beam")
		beam.Name = baseName .. "_PinBeam"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = false
		beam.Width0 = 1.2
		beam.Width1 = 1.2
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new(0)
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 223, 79))
		beam.Segments = 12
		beam.Parent = worldFolder -- ← 安定のため World 直下

		-- 3-c) 視認性のための“縦の棒”ブロック（Neon）
		local solid = Instance.new("Part")
		solid.Name = baseName .. "_PinSolid"
		solid.Anchored = true
		solid.CanCollide = false
		solid.CanQuery = false
		solid.CastShadow = false
		solid.Material = Enum.Material.Neon
		solid.Color = Color3.fromRGB(255, 223, 79)
		-- 縦方向(Y)に長い棒：幅0.6 × 高さ poleHeight × 奥行0.6
		solid.Size = Vector3.new(0.6, poleHeight, 0.6)
		solid.CFrame = CFrame.new(x, groundY + poleHeight * 0.5, z)
		solid.Parent = worldFolder

		-- （任意）Cylinder を併走させたい場合は縦向きに90度回して配置
		-- ※ RobloxのCylinderは“長手がX軸”なので、Z軸へ90度回して“縦(Y)”にします
		--[[
local cyl = Instance.new("Part")
cyl.Name = baseName .. "_PinCyl"
cyl.Anchored = true
cyl.CanCollide = false
cyl.CanQuery = false
cyl.CastShadow = false
cyl.Material = Enum.Material.Neon
cyl.Color = Color3.fromRGB(255, 223, 79)
local radius = 0.5
cyl.Shape = Enum.PartType.Cylinder
cyl.Size = Vector3.new(poleHeight, radius * 2, radius * 2) -- 長手をX軸に持つため、X=高さ
cyl.CFrame = CFrame.new(x, groundY + poleHeight * 0.5, z) * CFrame.Angles(0, 0, math.rad(90))
cyl.Parent = worldFolder
]]

		-- 3-d) 先端グロー（控えめに）
		local glow = Instance.new("PointLight")
		glow.Brightness = 1.5
		glow.Range = math.clamp(poleHeight * 0.6, 8, 40)
		glow.Color = Color3.fromRGB(255, 223, 79)
		glow.Parent = tip

		-- ---------------------------
		-- 4) 先端アンカー（小さな透明パーツ）
		-- ---------------------------
		local tip = Instance.new("Part")
		tip.Name = baseName .. "_NameAnchor"
		tip.Anchored = true
		tip.CanCollide = false
		tip.CanQuery = false
		tip.CastShadow = false
		tip.Transparency = 1
		tip.Size = Vector3.new(0.2, 0.2, 0.2)
		tip.CFrame = CFrame.new(x, groundY + poleHeight, z)
		tip.Parent = worldFolder

		-- ---------------------------
		-- 5) 島名だけの BillboardGui（座標は出さない）
		-- ---------------------------
		local bb = Instance.new("BillboardGui")
		bb.Name = "Nameplate"
		bb.AlwaysOnTop = true
		bb.MaxDistance = cfg.labelMaxDistance or 5000
		bb.Size = UDim2.fromOffset(140, 40) -- 小さめ
		bb.Parent = tip

		local bg = Instance.new("Frame")
		bg.BackgroundTransparency = 0.25
		bg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
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
		label.Text = tostring(cfg.name or "Island") -- 島名だけ
		label.Parent = bg
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
		pad.Parent = bg

		-- ---------------------------
		-- 6) ログ出力（島名と(X,Z)のペア）
		-- ---------------------------
		-- print(("[IslandPin] %s\t(%.1f, %.1f)"):format(baseName, cfg.centerX, cfg.centerZ))
		local cx = tonumber(cfg.centerX) or 0
		local cz = tonumber(cfg.centerZ) or 0
		print(string.format("[IslandPin] %s\t(%.1f, %.1f)", baseName, cx, cz))
	end

	local terrain = workspace.Terrain

	local cfg = {
		name = config.name or "Island",
		centerX = config.centerX or 0,
		centerZ = config.centerZ or 0,
		sizeXZ = config.sizeXZ or config.sizeXY or 500,
		baseY = config.baseY or 0,
		thickness = config.thickness or 10,
		hillAmplitude = config.hillAmplitude or 20,
		hillScale = config.hillScale or 150,
		seed = config.seed or 12345,
		generateOcean = config.generateOcean ~= false,
		oceanRadius = config.oceanRadius or 1500,
		grid = config.grid or 12,
		showIslandLabel = config.showIslandLabel,
		labelOffsetY = config.labelOffsetY,
		labelMaxDistance = config.labelMaxDistance,
		_labelFont = config._labelFont,
		_labelTextSize = config._labelTextSize,
		_labelBgTrans = config._labelBgTrans,

		-- 【修正点 A】新しいプロパティを取得。デフォルトは Grass に設定
		baseMaterial = config.baseMaterial or Enum.Material.Grass,
	}

	-- print(("[FieldGen] 生成開始: %s at (%.0f, %.0f, Material: %s)"):format(cfg.name, cfg.centerX, cfg.centerZ, tostring(cfg.baseMaterial)))

	math.randomseed(cfg.seed)

	local halfSize = cfg.sizeXZ / 2
	local oceanY = cfg.baseY - 10
	local cliffHeight = oceanY + 8

	-- 【重要】ブロックを配列に溜めてからバッチ処理
	local terrainBlocks = {}
	local waterBlocks = {}

	-- 地形ブロックを準備
	for x = -halfSize, halfSize, cfg.grid do
		for z = -halfSize, halfSize, cfg.grid do
			local worldX = cfg.centerX + x
			local worldZ = cfg.centerZ + z

			local distFromCenter = math.sqrt(x * x + z * z)
			local normalizedDist = distFromCenter / halfSize
			local edgeFade = math.max(0, 1 - normalizedDist * 1.2)

			if edgeFade > 0 then
				local height = smoothNoise(worldX + cfg.seed, worldZ + cfg.seed, cfg.hillScale)
				local hillY = cfg.baseY + (height * cfg.hillAmplitude * edgeFade)
				local targetY = math.max(hillY, cliffHeight)

				table.insert(terrainBlocks, {
					cframe = CFrame.new(worldX, targetY - cfg.thickness / 2, worldZ),
					size = Vector3.new(cfg.grid, cfg.thickness, cfg.grid),

					-- 【修正点 B】ハードコードされた Material を設定値に置き換え
					material = cfg.baseMaterial,
				})
			end
		end
	end

	-- print(("[FieldGen] 地形ブロック数: %d"):format(#terrainBlocks))
	fillTerrainBatch(terrain, terrainBlocks)
	createIslandLabel(cfg)

	-- 海の生成
	if cfg.generateOcean then
		local oceanGrid = 20
		local oceanHalfSize = cfg.oceanRadius / 2
		local maxDistWithTerrain = halfSize * 0.8

		for x = -oceanHalfSize, oceanHalfSize, oceanGrid do
			for z = -oceanHalfSize, oceanHalfSize, oceanGrid do
				local dist = math.sqrt(x * x + z * z)
				if dist > maxDistWithTerrain then
					table.insert(waterBlocks, {
						cframe = CFrame.new(cfg.centerX + x, oceanY, cfg.centerZ + z),
						size = Vector3.new(oceanGrid, 20, oceanGrid),
						material = Enum.Material.Water,
					})
				end
			end
		end

		print(("[FieldGen] 海ブロック数: %d"):format(#waterBlocks))
		fillTerrainBatch(terrain, waterBlocks)
	end

	-- マーカー作成
	local worldFolder = workspace:FindFirstChild("World")
	if not worldFolder then
		worldFolder = Instance.new("Folder")
		worldFolder.Name = "World"
		worldFolder.Parent = workspace
	end

	-- 🌳【追加】FieldObjects（木や岩など）を配置する
	if config.fieldObjects then
		print("[FieldGen]config.fieldObjetsに入りました")
		local templateFolder = game:GetService("ServerStorage"):FindFirstChild("FieldObjectTemplates")
		if not templateFolder then
			warn("[FieldGen] FieldObjectTemplates フォルダが ServerStorage に存在しません")
			return
		end

		local fieldFolder = workspace:FindFirstChild("FieldObjects")
		if not fieldFolder then
			fieldFolder = Instance.new("Folder")
			fieldFolder.Name = "FieldObjects"
			fieldFolder.Parent = workspace
		end

		for _, obj in ipairs(config.fieldObjects) do
			local template = templateFolder:FindFirstChild(obj.model)
			if template then
				local instance = template:Clone()
				instance.Anchored = true
				instance.Position = Vector3.new(unpack(obj.position))

				if obj.size then
					instance.Size = instance.Size * obj.size
				end

				if obj.rotationY then
					instance.Orientation = Vector3.new(0, obj.rotationY, 0)
				end

				instance.Parent = fieldFolder
			else
				warn(("[FieldGen] モデルが見つかりません: %s"):format(obj.model))
			end
		end
	end

	-- print(("[FieldGen] 完了: %s"):format(cfg.name))
end

-- レイキャスト（変更なし）
function FieldGen.raycastGroundY(x, z, startY)
	startY = startY or 500

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false

	local origin = Vector3.new(x, startY, z)
	local direction = Vector3.new(0, -startY - 500, 0)

	local result = workspace:Raycast(origin, direction, params)
	return result and result.Position.Y or nil
end

-- 橋の生成（バッチ処理版）
function FieldGen.generateBridge(fromIsland, toIsland, config)
	local terrain = workspace.Terrain

	local cfg = {
		name = config.name or "Bridge",
		width = config.width or 20,
		height = config.height or 5,
		thickness = config.thickness or 5,
	}

	print(("[FieldGen] 橋を生成中: %s"):format(cfg.name))

	local x1, z1 = fromIsland.centerX, fromIsland.centerZ
	local x2, z2 = toIsland.centerX, toIsland.centerZ

	local dx = x2 - x1
	local dz = z2 - z1
	local distance = math.sqrt(dx * dx + dz * dz)

	local bridgeY = ((fromIsland.baseY or 0) + (toIsland.baseY or 0)) / 2 + cfg.height
	local segments = math.ceil(distance / 10)

	local bridgeBlocks = {}

	for i = 0, segments do
		local t = i / segments
		local x = x1 + dx * t
		local z = z1 + dz * t

		local perpX = -dz / distance
		local perpZ = dx / distance

		for w = -cfg.width / 2, cfg.width / 2, 8 do
			local worldX = x + perpX * w
			local worldZ = z + perpZ * w

			table.insert(bridgeBlocks, {
				cframe = CFrame.new(worldX, bridgeY, worldZ),
				size = Vector3.new(8, cfg.thickness, 8),
				material = Enum.Material.Slate,
			})
		end
	end

	fillTerrainBatch(terrain, bridgeBlocks)
	createIslandLabel(cfg)
	print(("[FieldGen] 橋生成完了: %s (距離: %.1f)"):format(cfg.name, distance))
end

-- ===== Field Objects Placement =====
local ServerStorage = game:GetService("ServerStorage")

local function ensureFolder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function setAnchoredAll(inst: Instance, anchored: boolean)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = anchored
		end
	end
end

local function ensurePrimaryPart(model: Model)
	if model.PrimaryPart then
		return
	end
	local pp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	if pp then
		model.PrimaryPart = pp
	end
end

local function pivotModel(model: Model, cf: CFrame)
	ensurePrimaryPart(model)
	if model.PrimaryPart then
		model:PivotTo(cf)
	else
		-- どうしてもPrimaryPartが無い場合のフォールバック
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CFrame = cf
			end
		end
	end
end

-- FieldGen.lua の placeFieldObjects 関数を以下のコードで置き換えてください
-- 既存の placeFieldObjects 関数全体を、下記のコードで置き換えます

-- FieldGen.lua の placeFieldObjects 関数を以下のコードで置き換えてください
-- 既存の placeFieldObjects 関数全体を、下記のコードで置き換えます

-- FieldGen.lua の placeFieldObjects 関数を以下のコードで置き換えてください
-- 既存の placeFieldObjects 関数全体を、下記のコードで置き換えます

function FieldGen.placeFieldObjects(continentName: string?, objects: { any }, player: Player?)
	if not objects or #objects == 0 then
		warn("[FieldGen.placeFieldObjects] オブジェクト配列が空です")
		return
	end

	-- print("[FieldGen.placeFieldObjects] ===== オブジェクト配置開始 =====")
	-- print(("[FieldGen.placeFieldObjects] continentName: %s"):format(tostring(continentName)))
	-- print(("[FieldGen.placeFieldObjects] objects 数: %d"):format(#objects))

	task.wait(1)

	local allCollectedItems = {}
	local Players = game:GetService("Players")
	local ServerScriptService = game:GetService("ServerScriptService")

	local success, PlayerStatsModule = pcall(function()
		return require(ServerScriptService:WaitForChild("PlayerStats"))
	end)

	if success then
		for _, plr in ipairs(Players:GetPlayers()) do
			local stats = PlayerStatsModule.getStats(plr)
			if stats and stats.CollectedItems then
				for chestId, _ in pairs(stats.CollectedItems) do
					allCollectedItems[chestId] = true
				end
				-- print(("[FieldGen] %s の取得済みアイテムを読み込み"):format(plr.Name))
			end
		end

		local count = 0
		for _ in pairs(allCollectedItems) do
			count = count + 1
		end
		print(("[FieldGen] 全プレイヤーの取得済みアイテム総数: %d"):format(count))
	else
		warn("[FieldGen] PlayerStatsModuleの読み込みに失敗")
	end

	local ServerStorage = game:GetService("ServerStorage")
	local templatesRoot = ServerStorage:FindFirstChild("FieldObjects")
	if not templatesRoot then
		warn("[FieldGen] ServerStorage/FieldObjects が見つかりません。配置スキップ")
		print("[FieldGen] ※ ServerStorageの中に『FieldObjects』フォルダを作成してください")
		return
	end

	-- print("[FieldGen] ✓ ServerStorage/FieldObjects が見つかりました")

	local function ensureFolder(parent: Instance, name: string): Instance
		local f = parent:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		return f
	end

	local function setAnchoredAll(inst: Instance, anchored: boolean)
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = anchored
			end
		end
	end

	local function ensurePrimaryPart(model: Model)
		if model.PrimaryPart then
			return
		end
		local pp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
		if pp then
			model.PrimaryPart = pp
		end
	end

	local function pivotModel(model: Model, cf: CFrame)
		ensurePrimaryPart(model)
		if model.PrimaryPart then
			model:PivotTo(cf)
		else
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CFrame = cf
				end
			end
		end
	end

	local root = ensureFolder(workspace, "FieldObjects")
	local parentFolder = continentName and ensureFolder(root, continentName) or root

	-- print(("[FieldGen] 配置先フォルダ: workspace/FieldObjects/%s"):format(continentName or "root"))

	local objectsProcessed = 0
	local objectsPlaced = 0

	for objIdx, obj in ipairs(objects) do
		-- print(("[FieldGen] [%d/%d] ◆◆◆ オブジェクト処理開始 ◆◆◆"):format(objIdx, #objects))

		if not obj then
			warn(("[FieldGen] [%d] オブジェクトがnilです"):format(objIdx))
			continue
		end

		-- print(("[FieldGen] [%d] assetId: %s"):format(objIdx, tostring(obj.assetId or "なし")))
		-- print(("[FieldGen] [%d] model: %s"):format(objIdx, tostring(obj.model or "なし")))
		-- print(("[FieldGen] [%d] position: %s"):format(objIdx, tostring(obj.position or "なし")))
		-- print(("[FieldGen] [%d] randomSpread: %s"):format(objIdx, obj.randomSpread and "あり" or "なし"))

		objectsProcessed = objectsProcessed + 1

		local objectsToPlace = {}

		if obj.randomSpread then
			local spread = obj.randomSpread
			local centerX = obj.position[1] or 0
			local centerZ = obj.position[3] or 0
			local radius = spread.radius or 50
			local density = spread.density or 0.5
			local maxCount = spread.count or 20
			local rotRandom = spread.rotationRandomness or false
			local scaleVar = spread.scaleVariance or 0
			local offsetVar = spread.groundOffsetVariance or 0

			-- print(
			-- 	("[FieldGen] [%d] ★ランダム配置 中心(%.1f,%.1f) 半径%.1f 密度%.2f 最大%d"):format(
			-- 		objIdx,
			-- 		centerX,
			-- 		centerZ,
			-- 		radius,
			-- 		density,
			-- 		maxCount
			-- 	)
			-- )

			local placed = 0
			local attempts = 0
			local maxAttempts = math.floor(maxCount / math.max(0.01, density)) + 100

			while placed < maxCount and attempts < maxAttempts do
				attempts = attempts + 1

				local angle = math.random() * math.pi * 2
				local dist = math.sqrt(math.random()) * radius
				local px = centerX + math.cos(angle) * dist
				local pz = centerZ + math.sin(angle) * dist

				if math.random() < density then
					table.insert(objectsToPlace, {
						baseObj = obj,
						position = { px, obj.position[2] or 0, pz },
						rotation = rotRandom and { 0, math.random() * 360, 0 } or (obj.rotation or { 0, 0, 0 }),
						size = obj.size * (1 + (math.random() - 0.5) * scaleVar * 2),
						groundOffset = (obj.groundOffset or 0) + (math.random() - 0.5) * offsetVar * 2,
					})
					placed = placed + 1
				end
			end

			-- print(
			-- 	("[FieldGen] [%d] ランダム配置結果: %d個配置（試行: %d回）"):format(
			-- 		objIdx,
			-- 		placed,
			-- 		attempts
			-- 	)
			-- )
		else
			-- print(("[FieldGen] [%d] ★単一配置"):format(objIdx))
			table.insert(objectsToPlace, {
				baseObj = obj,
				position = obj.position,
				rotation = obj.rotation or { 0, 0, 0 },
				size = obj.size or 1,
				groundOffset = obj.groundOffset or 0,
			})
		end

		-- print(("[FieldGen] [%d] 配置対象: %d個"):format(objIdx, #objectsToPlace))

		for placeIdx, placeInfo in ipairs(objectsToPlace) do
			-- print(("[FieldGen] [%d-%d] ━━━ 配置処理開始 ━━━"):format(objIdx, placeIdx))

			local obj_config = placeInfo.baseObj
			local p = placeInfo.position
			local x, y, z = p[1] or 0, p[2] or 0, p[3] or 0

			-- print(("[FieldGen] [%d-%d] 座標: (%.1f, %.1f, %.1f)"):format(objIdx, placeIdx, x, y, z))

			local clone

			-- Asset方式 or テンプレート方式の判定
			if obj_config.assetId then
				-- print(("[FieldGen] [%d-%d] ■ Asset方式を試みます"):format(objIdx, placeIdx))
				-- print(("[FieldGen] [%d-%d] AssetID: %s"):format(objIdx, placeIdx, obj_config.assetId))

				local ok, result = pcall(function()
					-- print(("[FieldGen] [%d-%d]   └→ game:GetObjects() 実行中..."):format(objIdx, placeIdx))
					local objs = game:GetObjects(obj_config.assetId)
					-- print(
					-- 	("[FieldGen] [%d-%d]   └→ game:GetObjects() 完了。戻り値数: %d"):format(
					-- 		objIdx,
					-- 		placeIdx,
					-- 		#objs
					-- 	)
					-- )
					return objs
				end)

				if ok then
					-- print(("[FieldGen] [%d-%d] ✓ pcall成功"):format(objIdx, placeIdx))
					if result and #result > 0 then
						clone = result[1]
						-- print(("[FieldGen] [%d-%d] ✓✓ Asset読み込み成功！"):format(objIdx, placeIdx))
					else
						-- warn(
						-- 	("[FieldGen] [%d-%d] ✗ Assetのロード失敗: 戻り値が空"):format(objIdx, placeIdx)
						-- )
						-- print(
						-- 	("[FieldGen] [%d-%d] → AssetIDが正しいか確認してください"):format(
						-- 		objIdx,
						-- 		placeIdx
						-- 	)
						-- )
						-- print(
						-- 	("[FieldGen] [%d-%d] → Studio内で右クリック > Copy Asset IDしましたか？"):format(
						-- 		objIdx,
						-- 		placeIdx
						-- 	)
						-- )
						continue
					end
				else
					warn(("[FieldGen] [%d-%d] ✗ pcall失敗: %s"):format(objIdx, placeIdx, tostring(result)))
					continue
				end
			elseif obj_config.model then
				-- print(("[FieldGen] [%d-%d] ■ テンプレート方式を試みます"):format(objIdx, placeIdx))
				-- print(("[FieldGen] [%d-%d] モデル名: %s"):format(objIdx, placeIdx, obj_config.model))

				-- print(
				-- 	("[FieldGen] [%d-%d]   └→ ServerStorage/FieldObjects を検索中..."):format(objIdx, placeIdx)
				-- )
				local template = templatesRoot:FindFirstChild(tostring(obj_config.model))
				if not template then
					warn(("[FieldGen] [%d-%d] ✗ テンプレートが見つかりません"):format(objIdx, placeIdx))
					-- print(
					-- 	("[FieldGen] [%d-%d] → ServerStorage/FieldObjects フォルダを確認してください"):format(
					-- 		objIdx,
					-- 		placeIdx
					-- 	)
					-- )
					-- print(
					-- 	("[FieldGen] [%d-%d] → 指定した名前: '%s'"):format(objIdx, placeIdx, obj_config.model)
					-- )

					-- FieldObjects内のモデル一覧を表示
					-- print(("[FieldGen] [%d-%d] → FieldObjects 内のモデル一覧:"):format(objIdx, placeIdx))
					-- for _, child in ipairs(templatesRoot:GetChildren()) do
					-- 	print(("[FieldGen] [%d-%d]    - %s"):format(objIdx, placeIdx, child.Name))
					-- end

					continue
				end

				-- print(("[FieldGen] [%d-%d] ✓ テンプレート見つかった"):format(objIdx, placeIdx))
				-- print(("[FieldGen] [%d-%d]   └→ クローン中..."):format(objIdx, placeIdx))
				clone = template:Clone()
				-- print(("[FieldGen] [%d-%d] ✓✓ クローン完了"):format(objIdx, placeIdx))
			else
				warn(
					("[FieldGen] [%d-%d] ✗ modelまたはassetIdが指定されていません"):format(
						objIdx,
						placeIdx
					)
				)
				continue
			end

			if not clone then
				warn(("[FieldGen] [%d-%d] ✗ cloneがnilです（原因不明）"):format(objIdx, placeIdx))
				continue
			end

			-- print(("[FieldGen] [%d-%d] ✓ cloneオブジェクト取得成功"):format(objIdx, placeIdx))

			setAnchoredAll(clone, true)

			local scale = tonumber(placeInfo.size) or 1
			if clone:IsA("Model") then
				if scale ~= 1 then
					pcall(function()
						clone:ScaleTo(scale)
					end)
				end
			elseif clone:IsA("BasePart") then
				if scale ~= 1 then
					clone.Size = clone.Size * scale
				end
			end

			local upAxis = tostring(obj_config.upAxis or "Y")
			local baseRot = CFrame.new()
			if upAxis == "Z" then
				baseRot = CFrame.Angles(math.rad(-90), 0, 0)
			elseif upAxis == "X" then
				baseRot = CFrame.Angles(0, 0, math.rad(90))
			end

			local rot = placeInfo.rotation or {}
			local rx = math.rad(rot[1] or obj_config.rotationX or 0)
			local ry = math.rad(rot[2] or obj_config.rotationY or 0)
			local rz = math.rad(rot[3] or obj_config.rotationZ or 0)
			local userRot = CFrame.Angles(rx, ry, rz)

			local mode = obj_config.mode or "ground"
			local offset = tonumber(placeInfo.groundOffset) or 0
			local align = (obj_config.alignToSlope == true)

			-- print(("[FieldGen] [%d-%d] 配置モード: %s, offset: %.2f"):format(objIdx, placeIdx, mode, offset))

			if mode == "fixed" then
				-- print(("[FieldGen] [%d-%d] → 固定配置を実行"):format(objIdx, placeIdx))

				local finalCF = CFrame.new(x, y, z) * baseRot * userRot

				if clone:IsA("Model") then
					pivotModel(clone, finalCF)
				elseif clone:IsA("BasePart") then
					clone.CFrame = finalCF
				end

				-- print(
				-- 	("[FieldGen] [%d-%d] ✓ 固定配置完了 (%.1f, %.1f, %.1f)"):format(objIdx, placeIdx, x, y, z)
				-- )
			else
				-- print(("[FieldGen] [%d-%d] → 地面接地モードを実行"):format(objIdx, placeIdx))

				local startY = 3000
				local hit = nil

				-- print(
				-- 	("[FieldGen] [%d-%d]   └→ レイキャスト実行中: (%.1f, ?, %.1f)"):format(
				-- 		objIdx,
				-- 		placeIdx,
				-- 		x,
				-- 		z
				-- 	)
				-- )

				do
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Include
					params.FilterDescendantsInstances = { workspace.Terrain }
					params.IgnoreWater = false
					hit = workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -6000, 0), params)
				end

				if hit then
					local groundY = hit.Position.Y
					local up = align and hit.Normal or Vector3.yAxis

					-- print(
					-- 	("[FieldGen] [%d-%d] ✓ レイキャスト成功: 地面Y=%.1f"):format(
					-- 		objIdx,
					-- 		placeIdx,
					-- 		groundY
					-- 	)
					-- )

					if clone:IsA("Model") then
						local tempCF = CFrame.new(x, groundY + 100, z) * baseRot * userRot
						pivotModel(clone, tempCF)

						local bbCFrame, bbSize = clone:GetBoundingBox()
						local bottomY = bbCFrame.Position.Y - (bbSize.Y * 0.5)

						local deltaY = (groundY + offset) - bottomY

						if align then
							local look = clone:GetPivot().LookVector
							local tangent = (look - look:Dot(up) * up).Unit
							local right = tangent:Cross(up).Unit
							local pos = bbCFrame.Position + Vector3.new(0, deltaY, 0)
							local newCF = CFrame.fromMatrix(pos, right, up)
							pivotModel(clone, newCF)
						else
							pivotModel(clone, clone:GetPivot() + Vector3.new(0, deltaY, 0))
						end
					elseif clone:IsA("BasePart") then
						local height = clone.Size.Y * 0.5

						if align then
							local right = clone.CFrame.RightVector
							local forward = right:Cross(up).Unit
							right = up:Cross(forward).Unit
							clone.CFrame = CFrame.fromMatrix(Vector3.new(x, groundY + height + offset, z), right, up)
						else
							clone.CFrame = CFrame.new(x, groundY + height + offset, z) * (baseRot * userRot)
						end
					end

					-- print(
					-- 	("[FieldGen] [%d-%d] ✓ 配置完了 (%.1f, %.1f, %.1f)"):format(
					-- 		objIdx,
					-- 		placeIdx,
					-- 		x,
					-- 		groundY + offset,
					-- 		z
					-- 	)
					-- )
				else
					warn(
						("[FieldGen] [%d-%d] ✗ レイキャスト失敗: 地面が見つかりません"):format(
							objIdx,
							placeIdx
						)
					)
					-- print(
					-- 	("[FieldGen] [%d-%d] → テラインが生成されているか確認してください"):format(
					-- 		objIdx,
					-- 		placeIdx
					-- 	)
					-- )
					-- print(
					-- 	("[FieldGen] [%d-%d] → 座標 (%.1f, %.1f) に地形がありますか？"):format(
					-- 		objIdx,
					-- 		placeIdx,
					-- 		x,
					-- 		z
					-- 	)
					-- )
				end
			end

			if obj_config.interaction then
				-- print(("[FieldGen] [%d-%d] インタラクション設定中..."):format(objIdx, placeIdx))

				local interaction = obj_config.interaction

				clone:SetAttribute("HasInteraction", true)
				clone:SetAttribute("InteractionType", interaction.type or "unknown")
				clone:SetAttribute("InteractionAction", interaction.action or "調べる")
				clone:SetAttribute("InteractionKey", interaction.key or "E")
				clone:SetAttribute("InteractionRange", interaction.range or 8)

				if interaction.type == "chest" then
					clone:SetAttribute("ChestId", interaction.chestId)
					clone:SetAttribute("OpenedModel", interaction.openedModel)
					clone:SetAttribute("DisplayDuration", interaction.displayDuration or 5)

					local HttpService = game:GetService("HttpService")
					local rewardsJson = HttpService:JSONEncode(interaction.rewards or {})
					clone:SetAttribute("RewardsData", rewardsJson)

					-- print(
					-- 	("[FieldGen] [%d-%d] ✓ インタラクション設定完了: ChestId=%s"):format(
					-- 		objIdx,
					-- 		placeIdx,
					-- 		interaction.chestId
					-- 	)
					-- )
				end
			end

			clone.Parent = parentFolder
			objectsPlaced = objectsPlaced + 1
			-- print(("[FieldGen] [%d-%d] ✓✓✓ オブジェクト配置完了 ✓✓✓"):format(objIdx, placeIdx))
		end

		-- print(("[FieldGen] [%d] ◆◆◆ オブジェクト処理完了 ◆◆◆"):format(objIdx))
	end

	-- print(("[FieldGen.placeFieldObjects] ===== 全処理完了 ====="):format())
	-- print(
	-- 	("[FieldGen.placeFieldObjects] 処理対象: %d個, 配置済み: %d個"):format(
	-- 		objectsProcessed,
	-- 		objectsPlaced
	-- 	)
	-- )
end

--=====================================================
-- Paths (MVP): Catmull-Rom spline -> Terrain FillBlock
--=====================================================

-- {x,y,z} -> Vector3
local function v3(arr)
	return Vector3.new(arr[1] or 0, arr[2] or 0, arr[3] or 0)
end

-- Catmull-Rom 補間（MVP: 標準係数0.5）
local function catmullRom(p0, p1, p2, p3, t: number)
	local t2, t3 = t * t, t * t * t
	-- 0.5 * (2P1 + (-P0+P2)t + (2P0-5P1+4P2-P3)t^2 + (-P0+3P1-3P2+P3)t^3)
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

-- 区間長に応じてサンプル数を決める（等間隔っぽく）
local function sampleSegment(p1, p2, stepStuds)
	local dist = (p2 - p1).Magnitude
	local n = math.max(2, math.floor(dist / math.max(0.1, stepStuds)))
	return n
end

-- points端のガード（p[-1]=p[0], p[n+1]=p[n]）
local function getPoint(points, i)
	if i < 1 then
		return points[1]
	elseif i > #points then
		return points[#points]
	else
		return points[i]
	end
end

-- ===== Road/Path Slice Fill =====
local function fillRoadSlice(
	terrain,
	centerPos: Vector3,
	forward: Vector3,
	up: Vector3,
	width: number,
	length: number,
	thickness: number,
	material
)
	local fwd = forward.Magnitude > 0 and forward.Unit or Vector3.zAxis
	local upv = up.Magnitude > 0 and up.Unit or Vector3.yAxis

	local dot = math.abs(fwd:Dot(upv))
	if dot > 0.99 then
		upv = Vector3.yAxis
	end

	local right = fwd:Cross(upv)
	if right.Magnitude < 0.01 then
		right = if fwd:Dot(Vector3.yAxis) > 0.9 then Vector3.xAxis else Vector3.yAxis
	end
	right = right.Unit
	upv = right:Cross(fwd).Unit

	local cf = CFrame.fromMatrix(centerPos, right, upv)
	local size = Vector3.new(length, thickness, width)

	terrain:FillBlock(cf, size, material)
end

-- ★ 湖生成関数（塗りつぶし型）
function FieldGen.generateLake(config)
	if not config then
		warn("[FieldGen.generateLake] config が指定されていません")
		return
	end

	local terrain = workspace.Terrain
	local centerX = config.centerX or 0
	local centerZ = config.centerZ or 0
	local radius = config.radius or 50
	local depth = config.depth or 10
	local step = config.step or 8
	local material = config.material or Enum.Material.Water

	-- ★【修正】baseY を自動判定（指定がなければレイキャストで検出）
	local baseY = config.baseY
	if not baseY then
		local startY = 3000
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		params.IgnoreWater = false

		local hit = workspace:Raycast(Vector3.new(centerX, startY, centerZ), Vector3.new(0, -startY - 1000, 0), params)

		if hit then
			baseY = hit.Position.Y
			-- print(
			-- 	("[FieldGen] 湖 '%s': 地面高さを自動検出 Y=%.1f"):format(config.name or "UnnamedLake", baseY)
			-- )
		else
			baseY = 30 -- フォールバック
			-- warn(
			-- 	("[FieldGen] 湖 '%s': 地面検出失敗、デフォルト Y=%.1f を使用"):format(
			-- 		config.name or "UnnamedLake",
			-- 		baseY
			-- 	)
			-- )
		end
	end

	-- print(
	-- 	("[FieldGen] 湖生成開始: %s (中心: %.1f, %.1f, 半径: %.1f, 深さ: %.1f, step: %d)"):format(
	-- 		config.name or "UnnamedLake",
	-- 		centerX,
	-- 		centerZ,
	-- 		radius,
	-- 		depth,
	-- 		step
	-- 	)
	-- )

	local blockCount = 0

	-- ★【修正】ステップ1: 湖の場所の地形を削除（Airで上書き）
	for x = centerX - radius, centerX + radius, step do
		for z = centerZ - radius, centerZ + radius, step do
			local dist = math.sqrt((x - centerX) ^ 2 + (z - centerZ) ^ 2)
			if dist <= radius then
				-- 地形を削除して窪みを作る
				terrain:FillBlock(
					CFrame.new(x, baseY - depth / 2, z),
					Vector3.new(step, depth + 5, step),
					Enum.Material.Air
				)
			end
		end
	end

	-- ★【修正】ステップ2: 窪みの底に水を流す
	local waterY = baseY - depth + 2
	for x = centerX - radius, centerX + radius, step do
		for z = centerZ - radius, centerZ + radius, step do
			local dist = math.sqrt((x - centerX) ^ 2 + (z - centerZ) ^ 2)
			if dist <= radius then
				terrain:FillBlock(CFrame.new(x, waterY, z), Vector3.new(step, 3, step), material)
				blockCount = blockCount + 1
			end
		end
	end

	-- print(
	-- 	("[FieldGen] 湖生成完了: %s (%d ブロック、深さ: %.1f)"):format(
	-- 		config.name or "UnnamedLake",
	-- 		blockCount,
	-- 		depth
	-- 	)
	-- )
end

-- ★ 川生成関数（ウェイポイント + Catmull-Rom補間版）
function FieldGen.generateRiver(config)
	if not config then
		warn("[FieldGen.generateRiver] config が指定されていません")
		return
	end

	local terrain = workspace.Terrain
	local width = config.width or 15
	local depth = config.depth or 8
	local step = config.step or 4
	local material = config.material or Enum.Material.Water

	-- ウェイポイント取得
	local points = config.points or {}
	if #points < 2 then
		warn("[FieldGen.generateRiver] ウェイポイントが不足しています（最低2点必要）")
		return
	end

	-- baseY を自動判定（指定がなければレイキャストで検出）
	local baseY = config.baseY
	if not baseY then
		local startY = 3000
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		params.IgnoreWater = false

		-- 最初のポイントで地面検出
		local firstPoint = points[1]
		local hit = workspace:Raycast(
			Vector3.new(firstPoint[1], startY, firstPoint[2]),
			Vector3.new(0, -startY - 1000, 0),
			params
		)

		if hit then
			baseY = hit.Position.Y
			-- print(
			-- 	("[FieldGen] 川 '%s': 地面高さを自動検出 Y=%.1f"):format(config.name or "UnnamedRiver", baseY)
			-- )
		else
			baseY = 30 -- フォールバック
			-- warn(
			-- 	("[FieldGen] 川 '%s': 地面検出失敗、デフォルト Y=%.1f を使用"):format(
			-- 		config.name or "UnnamedRiver",
			-- 		baseY
			-- 	)
			-- )
		end
	end

	print(
		-- ("[FieldGen] 川生成開始: %s (ウェイポイント: %d個, 幅: %.1f, 深さ: %.1f)"):format(
		-- 	config.name or "UnnamedRiver",
		-- 	#points,
		-- 	width,
		-- 	depth
		-- )
	)

	-- ウェイポイントをVector3に変換
	local P = {}
	for i = 1, #points do
		local pt = points[i]
		P[i] = Vector3.new(pt[1] or 0, pt[2] or baseY, pt[3] or 0)
	end

	local totalDeleteBlocks = 0
	local totalWaterBlocks = 0

	-- Catmull-Rom補間で川を生成
	for seg = 1, #P - 1 do
		local p0 = getPoint(P, seg - 1)
		local p1 = getPoint(P, seg)
		local p2 = getPoint(P, seg + 1)
		local p3 = getPoint(P, seg + 2)

		local n = sampleSegment(p1, p2, step)
		for j = 0, n - 1 do
			local t0 = j / n
			local t1 = (j + 1) / n

			local a = catmullRom(p0, p1, p2, p3, t0)
			local b = catmullRom(p0, p1, p2, p3, t1)
			local mid = (a + b) * 0.5
			local dir = (b - a)

			if dir.Magnitude < 1e-6 then
				dir = Vector3.zAxis
			end

			-- ★ ステップ1: 川の轍を削除（Airで上書き）
			-- 川の幅方向に削除
			local rightVec = Vector3.yAxis:Cross(dir.Unit)
			if rightVec.Magnitude < 0.01 then
				rightVec = Vector3.xAxis
			end
			rightVec = rightVec.Unit

			-- 川の中心から左右に削除
			for w = -width / 2, width / 2, step do
				local deleteX = mid.X + rightVec.X * w
				local deleteZ = mid.Z + rightVec.Z * w

				terrain:FillBlock(
					CFrame.new(deleteX, baseY - depth / 2, deleteZ),
					Vector3.new(step, depth + 5, step),
					Enum.Material.Air
				)
				totalDeleteBlocks = totalDeleteBlocks + 1
			end

			-- ★ ステップ2: 川の底に水を配置
			local waterY = baseY - depth + 2
			for w = -width / 2, width / 2, step do
				local waterX = mid.X + rightVec.X * w
				local waterZ = mid.Z + rightVec.Z * w

				terrain:FillBlock(CFrame.new(waterX, waterY, waterZ), Vector3.new(step, 3, step), material)
				totalWaterBlocks = totalWaterBlocks + 1
			end
		end
	end

	-- print(
	-- 	("[FieldGen] 川生成完了: %s (削除ブロック: %d, 水ブロック: %d)"):format(
	-- 		config.name or "UnnamedRiver",
	-- 		totalDeleteBlocks,
	-- 		totalWaterBlocks
	-- 	)
	-- )
end

-- ★ 実験用：くり抜かない湖生成（直接Waterで塗りつぶし）
function FieldGen.generateLake_Simple(config)
	if not config then
		warn("[FieldGen.generateLake_Simple] config が指定されていません")
		return
	end

	local terrain = workspace.Terrain
	local centerX = config.centerX or 0
	local centerZ = config.centerZ or 0
	local radius = config.radius or 50
	local depth = config.depth or 10
	local step = config.step or 8
	local material = config.material or Enum.Material.Water

	-- baseY を自動判定（指定がなければレイキャストで検出）
	local baseY = config.baseY
	if not baseY then
		local startY = 3000
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		params.IgnoreWater = false

		local hit = workspace:Raycast(Vector3.new(centerX, startY, centerZ), Vector3.new(0, -startY - 1000, 0), params)

		if hit then
			baseY = hit.Position.Y
			-- print(
			-- 	("[FieldGen] 湖_シンプル '%s': 地面高さを自動検出 Y=%.1f"):format(
			-- 		config.name or "UnnamedLake",
			-- 		baseY
			-- 	)
			-- )
		else
			baseY = 30 -- フォールバック
			-- warn(
			-- 	("[FieldGen] 湖_シンプル '%s': 地面検出失敗、デフォルト Y=%.1f を使用"):format(
			-- 		config.name or "UnnamedLake",
			-- 		baseY
			-- 	)
			-- )
		end
	end

	-- print(
	-- 	("[FieldGen] 湖_シンプル 生成開始: %s (中心: %.1f, %.1f, 半径: %.1f, 深さ: %.1f, step: %d)"):format(
	-- 		config.name or "UnnamedLake",
	-- 		centerX,
	-- 		centerZ,
	-- 		radius,
	-- 		depth,
	-- 		step
	-- 	)
	-- )

	local blockCount = 0

	-- ★【シンプル】地面の高さから深さ分下に、直接Waterを配置（削除なし）
	local waterTopY = baseY -- 地面と同じ高さから開始
	local waterBottomY = baseY - depth -- depth分下まで

	for x = centerX - radius, centerX + radius, step do
		for z = centerZ - radius, centerZ + radius, step do
			local dist = math.sqrt((x - centerX) ^ 2 + (z - centerZ) ^ 2)
			if dist <= radius then
				-- 地面レベルから深さ分をWaterで塗りつぶし
				-- Y中心を (waterTopY + waterBottomY) / 2 に設定
				local centerY = (waterTopY + waterBottomY) / 2
				local fillHeight = waterTopY - waterBottomY

				terrain:FillBlock(CFrame.new(x, centerY, z), Vector3.new(step, fillHeight, step), material)
				blockCount = blockCount + 1
			end
		end
	end

	-- print(
	-- 	("[FieldGen] 湖_シンプル 生成完了: %s (%d ブロック、深さ: %.1f)"):format(
	-- 		config.name or "UnnamedLake",
	-- 		blockCount,
	-- 		depth
	-- 	)
	-- )
end

function FieldGen.buildPaths(continentName: string?, paths: { any })
	print("[FieldGen/Paths] ===== パス生成開始 =====")
	print("[FieldGen/Paths] paths型: " .. type(paths))
	print("[FieldGen/Paths] paths要素数: " .. tostring(#paths))

	if not paths then
		print("[FieldGen/Paths] paths が nil です")
		return
	end

	local terrain = workspace.Terrain
	local logPrefix = ("[FieldGen/Paths]%s "):format(continentName and ("[" .. continentName .. "]") or "")

	for pathIdx, path in ipairs(paths) do
		local pts = path.points or {}

		-- print("[FieldGen/Paths] ===== パス生成中 =====")
		-- print(string.format("[FieldGen/Paths] パス #%d 名: %s", pathIdx, tostring(path.name or "Unnamed")))

		if #pts < 2 then
			warn(logPrefix .. "points が不足（最低2点）: " .. tostring(path.name))
			continue
		end

		-- for i, pt in ipairs(pts) do
		-- 	print(
		-- 		string.format("[FieldGen/Paths] 入力ポイント %d: X=%.1f, Y=%.1f, Z=%.1f", i, pt[1], pt[2], pt[3])
		-- 	)
		-- end

		local width = tonumber(path.width) or 12
		local step = tonumber(path.step) or 3
		local mat = path.material or Enum.Material.Ground
		local yOffset = tonumber(path.groundOffset) or 0.05
		local thick = tonumber(path.thickness) or 2
		local pathType = tostring(path.type or "road"):lower()

		local function getGroundHeightAtXZ(x, z, hintY)
			local startY = math.max(hintY + 600, 3000)

			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { workspace.Terrain }
			params.IgnoreWater = false

			local hit = workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -(startY + 2000), 0), params)

			if hit then
				return hit.Position.Y, hit.Normal
			else
				return hintY, Vector3.yAxis
			end
		end

		local P = table.create(#pts)
		for i = 1, #pts do
			local pt = pts[i]
			local x = pt[1] or 0
			local y = pt[2] or 0
			local z = pt[3] or 0

			local groundY, normal = getGroundHeightAtXZ(x, z, y)
			P[i] = Vector3.new(x, groundY + yOffset, z)

			-- print(
			-- 	string.format(
			-- 		"[FieldGen/Paths] ポイント %d: (%.1f, %.1f, %.1f) → 地面Y: %.1f (オフセット後: %.1f)",
			-- 		i,
			-- 		x,
			-- 		y,
			-- 		z,
			-- 		groundY,
			-- 		groundY + yOffset
			-- 	)
			-- )
		end

		local slices = 0
		for seg = 1, #P - 1 do
			local p0 = getPoint(P, seg - 1)
			local p1 = getPoint(P, seg)
			local p2 = getPoint(P, seg + 1)
			local p3 = getPoint(P, seg + 2)

			local n = sampleSegment(p1, p2, step)
			for j = 0, n - 1 do
				local t0 = j / n
				local t1 = (j + 1) / n

				local a = catmullRom(p0, p1, p2, p3, t0)
				local b = catmullRom(p0, p1, p2, p3, t1)
				local mid = (a + b) * 0.5
				local dir = (b - a)

				if dir.Magnitude < 1e-6 then
					dir = Vector3.zAxis
				end

				local midGroundY = getGroundHeightAtXZ(mid.X, mid.Z, mid.Y)
				local useY = midGroundY + yOffset
				local up = Vector3.yAxis

				local centerY = useY - (thick / 2)

				fillRoadSlice(
					terrain,
					Vector3.new(mid.X, centerY, mid.Z),
					dir.Unit,
					up,
					width,
					(b - a).Magnitude,
					thick,
					mat
				)

				slices += 1
			end
		end

		-- print(
		-- 	("%s[%s] パス '%s': points=%d, slices=%d, width=%.1f, type=%s"):format(
		-- 		logPrefix,
		-- 		pathIdx,
		-- 		tostring(path.name or "?"),
		-- 		#P,
		-- 		slices,
		-- 		width,
		-- 		pathType
		-- 	)
		-- )
	end
end

return FieldGen
