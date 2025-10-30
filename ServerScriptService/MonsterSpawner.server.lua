-- ServerScriptService/MonsterSpawner.server.lua
-- ゾーン対応版モンスター配置システム（バトル高速化版、徘徊AI修正版）
local showLabels = true

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FieldGen = require(ReplicatedStorage:WaitForChild("FieldGen"))
local ZoneManager = require(script.Parent.ZoneManager)

local SharedState = require(ReplicatedStorage:WaitForChild("SharedState"))
local GameEvents = require(ReplicatedStorage:WaitForChild("GameEvents"))
local ContinentsRegistry = require(ReplicatedStorage.Continents.Registry)

-- BattleSystem読込（オプショナル）
local BattleSystem = nil
local battleSystemScript = script.Parent:FindFirstChild("BattleSystem")
if battleSystemScript then
	local success, result = pcall(function()
		return require(battleSystemScript)
	end)
	if success then
		BattleSystem = result
		print("[MonsterSpawner] BattleSystem読み込み成功")
	else
		warn("[MonsterSpawner] BattleSystem読み込み失敗:", result)
	end
else
	warn("[MonsterSpawner] BattleSystemが見つかりません - バトル機能は無効です")
end

-- Registry読込
local MonstersFolder = ReplicatedStorage:WaitForChild("Monsters")
local Registry = require(MonstersFolder:WaitForChild("Registry"))

-- 島の設定を読み込み
local IslandsRegistry = require(ReplicatedStorage.Islands.Registry)
local Islands = {}
for _, island in ipairs(IslandsRegistry) do
	Islands[island.name] = island
end

-- グローバル変数
local ActiveMonsters = {}
local UpdateInterval = 0.05
local MonsterCounts = {}
local TemplateCache = {}
local RespawnQueue = {}

-- 安全地帯チェック
local function isSafeZone(zoneName)
	local island = Islands[zoneName]
	if island and island.safeZone then
		return true
	end
	return false
end

-- ユーティリティ関数
local function resolveTemplate(pathArray: { string }): Model?
	local node: Instance = game
	for _, seg in ipairs(pathArray) do
		node = node:FindFirstChild(seg)
		if not node then
			return nil
		end
	end
	return (node and node:IsA("Model")) and node or nil
end

local function ensureHRP(model: Model): BasePart?
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		if not model.PrimaryPart then
			model.PrimaryPart = hrp
		end
		return hrp
	end
	return nil
end

-- 島から大陸名を逆引きするマップを作成
local IslandToContinentMap = {}
do
	for _, continent in ipairs(ContinentsRegistry) do
		if continent and continent.islands then
			for _, islandName in ipairs(continent.islands) do
				IslandToContinentMap[islandName] = continent.name
				print(("[MonsterSpawner] マップ: %s -> %s"):format(islandName, continent.name))
			end
		end
	end
	local mapCount = 0
	for _ in pairs(IslandToContinentMap) do
		mapCount = mapCount + 1
	end

	print("[MonsterSpawner] IslandToContinentMap 初期化完了 (" .. mapCount .. " 個)")
end

-- 島名から大陸名を取得
local function getContinentNameFromIsland(islandName)
	local result = IslandToContinentMap[islandName]
	if not result then
		warn(
			("[MonsterSpawner] 警告: 島 '%s' が IslandToContinentMap に見つかりません。島名をそのまま使用します"):format(
				islandName
			)
		)
		return islandName
	end
	return result
end
-- 島名から大陸名を取得
local function getContinentNameFromIsland(islandName)
	return IslandToContinentMap[islandName] or islandName
end

local function placeOnGround(model: Model, x: number, z: number)
	local hrp = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn("[MonsterSpawner] HumanoidRootPart が見つかりません: " .. model.Name)
		return
	end

	local groundY = FieldGen.raycastGroundY(x, z, 100)
		or FieldGen.raycastGroundY(x, z, 200)
		or FieldGen.raycastGroundY(x, z, 50)
		or 10

	local _, yaw = hrp.CFrame:ToOrientation()
	model:PivotTo(CFrame.new(x, groundY + 20, z) * CFrame.Angles(0, yaw, 0))

	local bboxCFrame, bboxSize = model:GetBoundingBox()
	local bottomY = bboxCFrame.Position.Y - (bboxSize.Y * 0.5)
	local offset = hrp.Position.Y - bottomY

	model:PivotTo(CFrame.new(x, groundY + offset, z) * CFrame.Angles(0, yaw, 0))
end

local function nearestPlayer(position: Vector3)
	local best, bestDist = nil, math.huge
	for _, pl in ipairs(Players:GetPlayers()) do
		local ch = pl.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if hrp then
			local d = (position - hrp.Position).Magnitude
			if d < bestDist then
				best, bestDist = pl, d
			end
		end
	end
	return best, bestDist
end

-- AI状態管理（高速化版）
local AIState = {}
AIState.__index = AIState

function AIState.new(monster, def)
	local self = setmetatable({}, AIState)
	self.monster = monster
	self.def = def
	self.humanoid = monster:FindFirstChildOfClass("Humanoid")
	self.root = monster.PrimaryPart

	-- ★ 【修正】Brave スコアを計算（個体差付き）
	local braveBase = def.Brave or 5
	local variationRange = def.VariationRange or 1
	local variation = (math.random() * 2 - 1) * variationRange
	self.braveScore = math.clamp(braveBase + variation, 0, 9)

	-- 従来互換性のため courage も計算
	self.courage = self.braveScore / 9
	self.brave = (self.courage > 0.5)

	self.wanderGoal = nil
	self.nextWanderAt = 0
	self.lastUpdateTime = 0
	self.lastDistanceLog = 0
	self.updateRate = def.AiTickRate or 0.3

	-- ★ 【修正】UpdateNearby / UpdateFar パラメータから参照
	self.nearUpdateRate = def.UpdateNearby or 0.2
	self.farUpdateRate = def.UpdateFar or 1.0
	self.nearbyThreshold = def.UpdateNearbyThreshold or 150

	self.originalSpeed = self.humanoid.WalkSpeed
	self.wasInBattle = false

	-- 【修正点1】徘徊ステート管理を整理
	self.isMoving = false -- 移動状態か
	self.isWaiting = false -- 待機状態か (停止状態)
	self.waitEndTime = 0 -- 待機終了時刻
	-- 【修正点1 終わり】

	-- デバッグ出力
	print(
		("[AIState] %s - Brave: %.2f (base: %d, range: %.1f)"):format(
			monster.Name,
			self.braveScore,
			braveBase,
			variationRange
		)
	)

	return self
end

-- ============================================================
-- 修正版 attachLabel() 関数
-- 余白を完全に削除
-- ============================================================

local function attachLabel(model: Model, maxDist: number)
	local hrp = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local _, bboxSize = model:GetBoundingBox()
	local labelOffset = math.min(bboxSize.Y * 0.5 + 2, 15)

	local gui = Instance.new("BillboardGui")
	gui.Name = "DebugInfo"
	gui.Adornee = hrp
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 180, 0, 70) -- ★ 高さを削減（85 → 70）
	gui.StudsOffset = Vector3.new(0, labelOffset + 5, 0)
	gui.MaxDistance = maxDist
	gui.Parent = hrp

	-- 背景パネル
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 0.2
	background.BorderSizePixel = 1
	background.BorderColor3 = Color3.new(1, 1, 1)
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = gui

	-- テキストラベル
	local lb = Instance.new("TextLabel")
	lb.Name = "InfoText"
	lb.BackgroundTransparency = 1
	lb.TextScaled = false
	lb.TextSize = 20 -- ★ サイズ微調整（21 → 20）
	lb.Font = Enum.Font.GothamBold
	lb.TextColor3 = Color3.new(1, 1, 1)
	lb.TextStrokeTransparency = 0.5
	lb.TextStrokeColor3 = Color3.new(0, 0, 0)
	lb.Size = UDim2.fromScale(1, 1)
	lb.Text = "Ready"
	lb.TextXAlignment = Enum.TextXAlignment.Center
	lb.TextYAlignment = Enum.TextYAlignment.Top
	lb.LineHeight = 0.85 -- ★ 行高をもっと詰める（1.0 → 0.85）
	lb.Parent = background

	print(("[attachLabel] %s: ラベル作成完了"):format(model.Name))
end

function AIState:shouldUpdate(currentTime)
	local _, dist = nearestPlayer(self.root.Position)
	-- ★ 【修正】nearbyThreshold を参照（150スタッド固定から変更可能に）
	local rate = dist < self.nearbyThreshold and self.nearUpdateRate or self.farUpdateRate
	return (currentTime - self.lastUpdateTime) >= rate
end

-- ============================================================
-- 修正版 updateLabel() 関数
-- "B:" を "Brave:" に変更
-- ============================================================

local function updateLabel(monster: Model, braveScore: number, distToPlayer: number, mode: string)
	if not monster or not monster.Parent then
		return
	end

	local hrp = monster:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local gui = hrp:FindFirstChild("DebugInfo")
	if not gui then
		return
	end

	-- ★ background から探す
	local background = gui:FindFirstChild("Background")
	if not background then
		print(("[updateLabel] %s: Background が見つかりません"):format(monster.Name))
		return
	end

	local infoText = background:FindFirstChild("InfoText")
	if not infoText then
		print(("[updateLabel] %s: InfoText が見つかりません"):format(monster.Name))
		return
	end

	-- distToPlayer が nil の場合はデフォルト値を使用
	if not distToPlayer or distToPlayer == math.huge then
		distToPlayer = 999
	end

	local monsterName = monster.Name

	-- Mode の決定
	local modeText = ""
	if braveScore >= 7 then
		modeText = "CHASE"
	elseif braveScore >= 5 then
		modeText = "NORMAL"
	elseif braveScore >= 3 then
		modeText = "TIMID"
	else
		modeText = "FLEE"
	end

	-- 距離の表示
	local distText = ""
	if distToPlayer and distToPlayer < 1000 then
		distText = string.format("%.1fm", distToPlayer)
	else
		distText = "----"
	end

	-- Brave の表示（★ "B:" を "Brave:" に）
	local braveText = string.format("Brave:%.1f", braveScore)

	-- テキスト形式を改善
	infoText.Text = string.format("%s\n%s %s\n%s", monsterName, modeText, distText, braveText)

	-- Mode に応じた色付け
	if braveScore >= 7 then
		infoText.TextColor3 = Color3.new(1, 0.3, 0.3) -- 赤
	elseif braveScore >= 5 then
		infoText.TextColor3 = Color3.new(1, 1, 0.3) -- 黄
	elseif braveScore >= 3 then
		infoText.TextColor3 = Color3.new(0.3, 0.8, 1) -- 青
	else
		infoText.TextColor3 = Color3.new(0.8, 0.3, 1) -- 紫
	end
end

function AIState:update()
	if not self.monster.Parent or not self.humanoid or not self.root then
		return false
	end

	if self.monster:GetAttribute("Defeated") then
		if not self.loggedDefeated then
			-- print(("[AI DEBUG] %s - Defeated状態のためスキップ"):format(self.monster.Name))
			self.loggedDefeated = true
		end
		return false
	end

	-- ★ 【新規追加】海に落ちたかチェック
	local isInWater = self.root.Position.Y < 0 or self.humanoid:GetState() == Enum.HumanoidStateType.Swimming
	if isInWater and self.root.Position.Y < -50 then
		print(
			("[MonsterSpawner] %s が海に落ちました。削除してリスポーン予約"):format(
				self.monster.Name
			)
		)

		local monsterName = self.def.Name or "Unknown"
		local islandName = self.monster:GetAttribute("SpawnIsland") or "Unknown"

		-- MonsterCounts を更新
		if MonsterCounts[islandName] and MonsterCounts[islandName][monsterName] then
			MonsterCounts[islandName][monsterName] = MonsterCounts[islandName][monsterName] - 1
		end

		-- ★ 修正：pcall でエラーハンドリング
		local success = pcall(function()
			scheduleRespawn(monsterName, self.def, islandName)
		end)

		if not success then
			warn(("[MonsterSpawner] リスポーン予約に失敗: %s"):format(monsterName))
		end

		-- モンスターを削除
		self.monster:Destroy()
		return false
	end

	-- バトル状態を確認
	local isGlobalBattle = BattleSystem and BattleSystem.isAnyBattleActive and BattleSystem.isAnyBattleActive()
	local isThisMonsterInBattle = self.monster:GetAttribute("InBattle")
	local isAnyBattle = isGlobalBattle or isThisMonsterInBattle

	-- いずれかのバトルが進行中なら停止
	if isAnyBattle then
		self.humanoid.WalkSpeed = 0
		self.humanoid:MoveTo(self.root.Position)
		self.wasInBattle = true
		return true
	end

	-- バトルが終了したら速度を復元
	if self.wasInBattle and not isAnyBattle then
		-- print(("[AI DEBUG] %s - バトル終了、速度復元: %.1f"):format(self.monster.Name, self.originalSpeed))
		self.humanoid.WalkSpeed = self.originalSpeed
		self.wasInBattle = false
		self.loggedDefeated = false
	end

	local p, dist = nearestPlayer(self.root.Position)
	local chaseRange = self.def.ChaseDistance or 60
	local now = os.clock()

	-- ★ 【修正】BattleStartDistance を参照
	local battleStartDistance = self.def.BattleStartDistance or 7

	-- バトル判定（高速化・距離拡大）
	if BattleSystem and p and dist <= battleStartDistance then
		-- print(("[AI DEBUG] %s - 接触検出！距離=%.1f"):format(self.monster.Name, dist))

		if BattleSystem.isInBattle(p) then
			self.humanoid:MoveTo(self.root.Position)
			return true
		end

		if BattleSystem.isAnyBattleActive and BattleSystem.isAnyBattleActive() then
			self.humanoid:MoveTo(self.root.Position)
			return true
		end

		if self.monster:GetAttribute("InBattle") then
			return true
		end

		local character = p.Character
		if character then
			-- 【重要】即座にプレイヤーを停止（バトル開始前）
			local playerHumanoid = character:FindFirstChildOfClass("Humanoid")
			local playerHrp = character:FindFirstChild("HumanoidRootPart")

			if playerHumanoid and playerHrp then
				-- プレイヤーを即座に停止
				playerHumanoid.WalkSpeed = 0
				playerHumanoid.JumpPower = 0
				playerHrp.Anchored = true
			end

			self.monster:SetAttribute("InBattle", true)
			self.humanoid.WalkSpeed = 0
			self.humanoid:MoveTo(self.root.Position)

			local battleStarted = BattleSystem.startBattle(p, self.monster)
			-- print(("[AI DEBUG] バトル開始結果: %s"):format(tostring(battleStarted)))

			if not battleStarted then
				-- バトル開始失敗時はプレイヤーも解放
				self.monster:SetAttribute("InBattle", false)
				self.humanoid.WalkSpeed = self.originalSpeed

				if playerHumanoid and playerHrp then
					playerHumanoid.WalkSpeed = 16
					playerHumanoid.JumpPower = 50
					playerHrp.Anchored = false
				end
			end

			return true
		else
			self.monster:SetAttribute("InBattle", false)
		end
	end

	-- ★ 【修正】移動してから海チェック
	local isInWater = self.root.Position.Y < 0 or self.humanoid:GetState() == Enum.HumanoidStateType.Swimming

	-- ラベル更新
	-- local label = self.root:FindFirstChild("DebugInfo") and self.root.DebugInfo:FindFirstChild("InfoText")
	-- if label then
	-- 	-- ★ 【修正】Brave レベルに応じた行動表示
	-- 	local behaviorName = ""
	-- 	if self.braveScore >= 7 then
	-- 		behaviorName = "CHASE"
	-- 	elseif self.braveScore >= 5 then
	-- 		behaviorName = "NORMAL"
	-- 	elseif self.braveScore >= 3 then
	-- 		behaviorName = "TIMID"
	-- 	else
	-- 		behaviorName = "FLEE"
	-- 	end
	-- 	label.Text =
	-- 		string.format("%s\nBrave:%.1f %s | %.1fm", self.monster.Name, self.braveScore, behaviorName, dist or 999)
	-- end

	-- ラベル更新関数を呼び出し
	if showLabels then
		if dist then
			updateLabel(self.monster, self.braveScore, dist, "Free")
		else
			updateLabel(self.monster, self.braveScore, 999, "Free")
		end
	end
	updateLabel(self.monster, self.braveScore, dist, "Free")
	local gui = self.root:FindFirstChild("DebugInfo")
	if gui then
		gui.Enabled = not isInWater
	end

	-- 【修正点2】徘徊ロジックを再構築
	local function wanderLogic()
		local w = self.def.Wander or {}
		local minWait = w.MinWait or 2
		local maxWait = w.MaxWait or 5
		local minRadius = w.MinRadius or 20
		local maxRadius = w.MaxRadius or 60
		local stopDistance = 5 -- 目標到達と見なす距離

		local isGoalReached = self.wanderGoal and (self.root.Position - self.wanderGoal).Magnitude < stopDistance
		local isWaitFinished = self.isWaiting and now >= self.waitEndTime

		if self.isWaiting then
			-- ステート: 待機中（停止）
			self.humanoid:MoveTo(self.root.Position) -- 停止を維持
			self.isMoving = false

			if isWaitFinished then
				-- 待機終了。次の目標設定へ
				self.isWaiting = false
				self.wanderGoal = nil
			end
		elseif isGoalReached or not self.wanderGoal then
			-- ステート: 目標到達 or 目標なし -> 新目標設定 & 移動開始

			-- 目標に到達したら待機モードに移行
			if isGoalReached then
				self.isWaiting = true
				self.waitEndTime = now + math.random(minWait * 10, maxWait * 10) / 10
				self.humanoid:MoveTo(self.root.Position) -- 停止
				return
			end

			-- 新しい目標を設定
			local ang = math.random() * math.pi * 2
			local rad = math.random(minRadius, maxRadius)
			local gx = self.root.Position.X + math.cos(ang) * rad
			local gz = self.root.Position.Z + math.sin(ang) * rad

			local gy = FieldGen.raycastGroundY(gx, gz, 100) or self.root.Position.Y + 5 -- 見つからなければ現在のY+5

			self.wanderGoal = Vector3.new(gx, gy, gz)
			self.isMoving = true

			self.humanoid:MoveTo(self.wanderGoal)
		else
			-- ステート: 移動中（継続）
			self.isMoving = true
			self.humanoid:MoveTo(self.wanderGoal)
		end
	end
	-- 【修正点2 終わり】

	-- ★ 【修正】Brave スコアに基づいた行動決定
	if not p then
		-- プレイヤーがいない：徘徊のみ
		wanderLogic()
	elseif self.braveScore >= 7 then
		-- ★ 勇敢（Brave 7,8,9）：常に追跡
		self.wanderGoal = nil
		self.isMoving = false
		self.isWaiting = false
		self.humanoid:MoveTo(p.Character.HumanoidRootPart.Position)
	elseif self.braveScore >= 5 then
		-- ★ 中程度（Brave 5,6）：距離に応じて判定
		if dist < chaseRange then
			self.wanderGoal = nil
			self.isMoving = false
			self.isWaiting = false
			self.humanoid:MoveTo(p.Character.HumanoidRootPart.Position)
		else
			wanderLogic()
		end
	elseif self.braveScore >= 3 then
		-- ★ 臆病（Brave 3,4）：距離に応じて逃げ、範囲は中程度
		if dist < chaseRange then
			self.wanderGoal = nil
			self.isMoving = false
			self.isWaiting = false
			local away = (self.root.Position - p.Character.HumanoidRootPart.Position).Unit
			self.humanoid:MoveTo(self.root.Position + away * 100)
		else
			wanderLogic()
		end
	else
		-- ★ 極度に臆病（Brave 0,1,2）：常に逃げ、最大範囲
		self.wanderGoal = nil
		self.isMoving = false
		self.isWaiting = false
		local away = (self.root.Position - p.Character.HumanoidRootPart.Position).Unit
		self.humanoid:MoveTo(self.root.Position + away * 150)
	end

	self.lastUpdateTime = now
	return true
end

-- スポーン処理（島指定版）
local function spawnMonster(template: Model, index: number, def, islandName)
	local m = template:Clone()
	m.Name = (def.Name or template.Name) .. "_" .. index

	-- === 両目の生成（SurfaceGui方式・縦横比維持・貼り付き調整付き） ===
	-- === カラー設定＋両目生成 ===
	if def.ColorProfile then
		-- まず Body/Core の色とマテリアルを設定
		for _, part in ipairs(m:GetDescendants()) do
			if part:IsA("MeshPart") then
				-- SurfaceAppearance があると色が反映されないため削除
				for _, child in ipairs(part:GetChildren()) do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end

				if part:IsA("MeshPart") and (part.Name == "Body" or part.Name == "Core") then
					-- ★ 全て同じ物理プロパティに統一
					part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.01, 0.01)
				end

				-- Body（外側）
				if part.Name == "Body" then
					if def.ColorProfile.Body then
						part.Color = def.ColorProfile.Body
					end

					-- ★ 設定ファイルから Material を読み込む
					if def.ColorProfile.BodyMaterial then
						part.Material = Enum.Material[def.ColorProfile.BodyMaterial]
					else
						part.Material = Enum.Material.Neon -- デフォルト
					end

					-- ★ 設定ファイルから Transparency を読み込む
					if def.ColorProfile.BodyTransparency then
						part.Transparency = def.ColorProfile.BodyTransparency
					else
						part.Transparency = 0.2 -- デフォルト
					end
				-- Core（内側）
				elseif part.Name == "Core" then
					if def.ColorProfile.Core then
						part.Color = def.ColorProfile.Core
					end

					-- ★ 設定ファイルから Material を読み込む
					if def.ColorProfile.CoreMaterial then
						part.Material = Enum.Material[def.ColorProfile.CoreMaterial]
					else
						part.Material = Enum.Material.Granite -- デフォルト
					end

					-- ★ 設定ファイルから Transparency を読み込む
					if def.ColorProfile.CoreTransparency then
						part.Transparency = def.ColorProfile.CoreTransparency
					else
						part.Transparency = 0.1 -- デフォルト
					end
				end
			end
		end

		-- === 両目の生成 （オリジナル）===
		-- if def.ColorProfile.EyeTexture then
		-- 	-- 目を貼る対象（Bodyに貼るのが自然）
		-- 	local targetPart = m:FindFirstChild("Body") or m.PrimaryPart
		-- 	if targetPart then
		-- 		-- ▼ 調整用パラメータ（ColorProfileで上書き可能）
		-- 		local useDecal = def.ColorProfile.UseDecal == true
		-- 		local eyeSize = def.ColorProfile.EyeSize or 0.18
		-- 		local eyeY = def.ColorProfile.EyeY or 0.48 -- 少し高めに配置
		-- 		local eyeSeparation = def.ColorProfile.EyeSeparation or 0.18
		-- 		local zOffset = def.ColorProfile.EyeZOffset or 1
		-- 		local alwaysOnTop = def.ColorProfile.EyeAlwaysOnTop == true
		-- 		local sizingMode = def.ColorProfile.EyeSizingMode or "Scale"
		-- 		local pps = def.ColorProfile.PixelsPerStud or 60
		-- 		local eyePixelSize = def.ColorProfile.EyePixelSize or 120

		-- 		if useDecal then
		-- 			-- ★ Decal方式（両目を1枚にした画像向け）
		-- 			local decal = Instance.new("Decal")
		-- 			decal.Texture = def.ColorProfile.EyeTexture
		-- 			decal.Face = Enum.NormalId.Front
		-- 			decal.Transparency = 0
		-- 			decal.Parent = targetPart
		-- 		else
		-- 			-- ★ SurfaceGui + ImageLabel方式（個別に左右配置）
		-- 			for _, sign in ipairs({ -1, 1 }) do
		-- 				local eyeGui = Instance.new("SurfaceGui")
		-- 				eyeGui.Name = (sign == -1) and "EyeGuiL" or "EyeGuiR"
		-- 				eyeGui.Adornee = targetPart
		-- 				eyeGui.Face = Enum.NormalId.Front
		-- 				eyeGui.AlwaysOnTop = alwaysOnTop
		-- 				eyeGui.LightInfluence = 1
		-- 				eyeGui.ZOffset = zOffset
		-- 				eyeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		-- 				if sizingMode == "Pixels" then
		-- 					eyeGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		-- 					eyeGui.PixelsPerStud = pps
		-- 				end

		-- 				eyeGui.Parent = targetPart

		-- 				local img = Instance.new("ImageLabel")
		-- 				img.Name = "Eye"
		-- 				img.BackgroundTransparency = 1
		-- 				img.Image = def.ColorProfile.EyeTexture
		-- 				img.AnchorPoint = Vector2.new(0.5, 0.5)

		-- 				if sizingMode == "Pixels" then
		-- 					img.Size = UDim2.new(0, eyePixelSize, 0, eyePixelSize)
		-- 					img.Position = UDim2.new(0.5 + (sign * eyeSeparation), 0, eyeY, 0)
		-- 				else
		-- 					img.Size = UDim2.new(eyeSize, 0, eyeSize, 0)
		-- 					img.Position = UDim2.new(0.5 + (sign * eyeSeparation), 0, eyeY, 0)
		-- 				end

		-- 				local aspect = Instance.new("UIAspectRatioConstraint")
		-- 				aspect.AspectRatio = 1
		-- 				aspect.DominantAxis = Enum.DominantAxis.Height
		-- 				aspect.Parent = img

		-- 				pcall(function()
		-- 					img.ScaleType = Enum.ScaleType.Fit
		-- 				end)

		-- 				img.ImageTransparency = 0
		-- 				img.Parent = eyeGui
		-- 			end
		-- 		end
		-- 	end
		-- end

		if def.ColorProfile.EyeTexture then
			local targetPart = m:FindFirstChild("Body") or m.PrimaryPart
			if targetPart then
				-- 左目
				local leftEye = Instance.new("Part")
				leftEye.Name = "LeftEye"
				leftEye.Shape = Enum.PartType.Ball
				-- leftEye.Size = Vector3.new(0.15, 0.15, 0.05)
				leftEye.Size = Vector3.new(0.3, 0.3, 0.05)
				leftEye.Material = Enum.Material.SmoothPlastic
				leftEye.CanCollide = false
				leftEye.TopSurface = Enum.SurfaceType.Smooth
				leftEye.BottomSurface = Enum.SurfaceType.Smooth
				leftEye.Parent = m

				local leftDecal = Instance.new("Decal")
				leftDecal.Texture = def.ColorProfile.EyeTexture
				leftDecal.Face = Enum.NormalId.Front
				leftDecal.Parent = leftEye

				-- Weld で Body に固定
				local leftWeld = Instance.new("WeldConstraint")
				leftWeld.Part0 = targetPart
				leftWeld.Part1 = leftEye
				leftWeld.Parent = leftEye

				-- CFrame で位置調整
				leftEye.Position = targetPart.Position + Vector3.new(-0.35, 0.40, -0.82)

				-- 右目（同じ処理を繰り返す）
				local rightEye = Instance.new("Part")
				rightEye.Name = "RightEye"
				rightEye.Shape = Enum.PartType.Ball
				rightEye.Size = Vector3.new(0.28, 0.28, 0.05)
				rightEye.Material = Enum.Material.SmoothPlastic
				rightEye.CanCollide = false
				rightEye.TopSurface = Enum.SurfaceType.Smooth
				rightEye.BottomSurface = Enum.SurfaceType.Smooth
				rightEye.Parent = m

				local rightDecal = Instance.new("Decal")
				rightDecal.Texture = def.ColorProfile.EyeTexture
				rightDecal.Face = Enum.NormalId.Front
				rightDecal.Parent = rightEye

				local rightWeld = Instance.new("WeldConstraint")
				rightWeld.Part0 = targetPart
				rightWeld.Part1 = rightEye
				rightWeld.Parent = rightEye

				rightEye.Position = targetPart.Position + Vector3.new(0.35, 0.40, -0.82)
			end
		end
	end
	-- === カラー設定＋両目生成 ここまで ===

	-- === 両目の生成 ここまで ===

	-- === カラー＆外見設定ここまで ===

	local hum = m:FindFirstChildOfClass("Humanoid")
	local hrp = ensureHRP(m)

	if not hum or not hrp then
		warn("[MonsterSpawner] Humanoid または HRP がありません: " .. m.Name)
		m:Destroy()
		return
	end

	m:SetAttribute("IsEnemy", true)
	m:SetAttribute("MonsterKind", def.Name or "Monster")
	m:SetAttribute("ChaseDistance", def.ChaseDistance or 60)

	-- ★修正点★: SpawnZone に大陸名を設定
	local continentName = getContinentNameFromIsland(islandName)
	m:SetAttribute("SpawnZone", continentName)
	m:SetAttribute("SpawnIsland", islandName)

	local speedMin = def.SpeedMin or 0.7
	local speedMax = def.SpeedMax or 1.3
	local speedMult = speedMin + math.random() * (speedMax - speedMin)
	hum.WalkSpeed = (def.WalkSpeed or 14) * speedMult
	hum.HipHeight = 0

	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.Transparency = 1

	for _, descendant in ipairs(m:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= hrp then
			descendant.CanCollide = true
			descendant.Anchored = false

			for _, child in ipairs(descendant:GetChildren()) do
				if child:IsA("WeldConstraint") or child:IsA("Weld") then
					child:Destroy()
				end
			end

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hrp
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end

	m.Parent = Workspace

	local island = Islands[islandName]
	if not island then
		warn(("[MonsterSpawner] 島 '%s' が見つかりません"):format(islandName))
		m:Destroy()
		return
	end

	local spawnRadius
	if def.radiusPercent then
		spawnRadius = (island.sizeXZ / 2) * (def.radiusPercent / 100)
	else
		spawnRadius = def.spawnRadius or 50
	end

	local rx = island.centerX + math.random(-spawnRadius, spawnRadius)
	local rz = island.centerZ + math.random(-spawnRadius, spawnRadius)

	placeOnGround(m, rx, rz)

	task.wait(0.05)
	hrp.Anchored = false

	-- attachLabel(m, 500)

	local aiState = AIState.new(m, def)
	table.insert(ActiveMonsters, aiState)

	local monsterName = def.Name or "Monster"
	if not MonsterCounts[islandName] then
		MonsterCounts[islandName] = {}
	end
	MonsterCounts[islandName][monsterName] = (MonsterCounts[islandName][monsterName] or 0) + 1

	print(
		("[MonsterSpawner] %s を %s (%s) にスポーン (大陸: %s)"):format(
			m.Name,
			islandName,
			def.Name,
			continentName
		)
	)
end

-- ゾーン内のモンスターカウントを取得
local function getZoneMonsterCounts(zoneName)
	local counts = {}

	-- 大陸名から島のリストを取得
	local islandNames = {}

	-- ContinentsRegistryをロード（まだロードされていない場合）
	if not ContinentsRegistry then
		local ContinentsFolder = ReplicatedStorage:FindFirstChild("Continents")
		if ContinentsFolder then
			local RegistryModule = ContinentsFolder:FindFirstChild("Registry")
			if RegistryModule then
				ContinentsRegistry = require(RegistryModule)
				print("[MonsterSpawner] ContinentsRegistryをロードしました")
			end
		end
	end

	-- 大陸の場合は、含まれる島をすべて取得
	local continent = nil
	if ContinentsRegistry then
		for _, cont in ipairs(ContinentsRegistry) do
			if cont.name == zoneName then
				continent = cont
				break
			end
		end
	end

	if continent and continent.islands then
		-- 大陸内の全島を対象にする
		for _, islandName in ipairs(continent.islands) do
			table.insert(islandNames, islandName)
		end
		print(("[MonsterSpawner] 大陸 %s の島リスト: %s"):format(zoneName, table.concat(islandNames, ", ")))
	else
		-- 大陸でない場合は、ゾーン名自体を島名とする
		table.insert(islandNames, zoneName)
		print(("[MonsterSpawner] %s は島として扱います"):format(zoneName))
	end

	-- 各島のモンスターカウントを集計
	for _, islandName in ipairs(islandNames) do
		if MonsterCounts[islandName] then
			for monsterName, count in pairs(MonsterCounts[islandName]) do
				counts[monsterName] = (counts[monsterName] or 0) + count
			end
		end
	end

	print(
		("[MonsterSpawner] ゾーン %s のモンスターカウント: %s"):format(
			zoneName,
			game:GetService("HttpService"):JSONEncode(counts)
		)
	)

	return counts
end

-- 全ゾーンのモンスター数をSharedStateに保存
local function updateAllMonsterCounts()
	print("[MonsterSpawner] 全ゾーンのモンスターカウントを更新中...")

	-- 一旦クリア
	SharedState.MonsterCounts = {}

	-- アクティブなゾーンごとにカウント
	local ZoneManager = require(script.Parent.ZoneManager)
	for zoneName, _ in pairs(ZoneManager.ActiveZones) do
		SharedState.MonsterCounts[zoneName] = getZoneMonsterCounts(zoneName)
	end

	print("[MonsterSpawner] モンスターカウント更新完了")
end

-- カスタムカウントでモンスターをスポーン（ロード時用）
local function spawnMonstersWithCounts(zoneName, customCounts)
	if isSafeZone(zoneName) then
		print(
			("[MonsterSpawner] %s は安全地帯です。モンスターをスポーンしません"):format(zoneName)
		)
		return
	end

	if not customCounts or type(customCounts) ~= "table" then
		print(
			("[MonsterSpawner] カスタムカウントが無効です。通常スポーンを実行: %s"):format(
				zoneName
			)
		)
		spawnMonstersForZone(zoneName)
		return
	end

	print(("[MonsterSpawner] カスタムカウントでモンスターをスポーン: %s"):format(zoneName))
	print(("[MonsterSpawner] カウント: %s"):format(game:GetService("HttpService"):JSONEncode(customCounts)))

	-- カスタムカウントに基づいてスポーン
	for monsterName, count in pairs(customCounts) do
		local template = TemplateCache[monsterName]
		local def = nil

		-- 定義を取得
		for _, regDef in ipairs(Registry) do
			if regDef.Name == monsterName then
				def = regDef
				break
			end
		end

		if template and def and count > 0 then
			print(("[MonsterSpawner] %s を %d 体スポーン"):format(monsterName, count))

			-- 各モンスターの配置先を決定
			if def.SpawnLocations then
				-- ★ 修正：島情報と count、radiusPercent を一緒に保持
				local locationsInZone = {}
				for _, location in ipairs(def.SpawnLocations) do
					-- このゾーンに含まれる島かチェック
					local isInZone = false

					-- 大陸の場合
					local Continents = {}
					for _, continent in ipairs(ContinentsRegistry) do
						Continents[continent.name] = continent
					end

					if Continents[zoneName] then
						for _, islandName in ipairs(Continents[zoneName].islands) do
							if islandName == location.islandName then
								isInZone = true
								break
							end
						end
					elseif zoneName == location.islandName then
						isInZone = true
					end

					if isInZone then
						-- ★ 修正：location 全体を保存（islandName、radiusPercent を含む）
						table.insert(locationsInZone, {
							islandName = location.islandName,
							radiusPercent = location.radiusPercent, -- radiusPercent を保存
						})
					end
				end

				-- 各ロケーションに配分
				if #locationsInZone > 0 then
					-- ★ 修正：customCounts の count を使用（SpawnLocations の count は使わない）
					local countPerLocation = math.ceil(count / #locationsInZone)

					for _, locationInfo in ipairs(locationsInZone) do
						local islandName = locationInfo.islandName

						print(
							("[MonsterSpawner] %s -> %s: %d 体 (radiusPercent: %s)"):format(
								monsterName,
								islandName,
								countPerLocation,
								tostring(locationInfo.radiusPercent or "デフォルト")
							)
						)

						-- 指定数分スポーン
						for i = 1, math.min(countPerLocation, count) do
							local spawnDef = {}
							for k, v in pairs(def) do
								spawnDef[k] = v
							end
							-- ★ 重要：location 固有の radiusPercent で上書き
							if locationInfo.radiusPercent then
								spawnDef.radiusPercent = locationInfo.radiusPercent
							end

							spawnMonster(template, i, spawnDef, islandName)
							count = count - 1

							if count <= 0 then
								break
							end
							if i % 5 == 0 then
								task.wait()
							end
						end

						if count <= 0 then
							break
						end
					end
				end
			end
		else
			if not template then
				warn(("[MonsterSpawner] テンプレート未発見: %s"):format(monsterName))
			end
			if not def then
				warn(("[MonsterSpawner] 定義未発見: %s"):format(monsterName))
			end
		end
	end
end

-- ゾーンにモンスターをスポーンする（大陸対応版）
function spawnMonstersForZone(zoneName)
	if isSafeZone(zoneName) then
		print(
			("[MonsterSpawner] %s は安全地帯です。モンスターをスポーンしません"):format(zoneName)
		)
		return
	end

	print(("[MonsterSpawner] %s にモンスターを配置中..."):format(zoneName))

	local islandsInZone = {}

	local ContinentsRegistry = require(ReplicatedStorage.Continents.Registry)
	local Continents = {}
	for _, continent in ipairs(ContinentsRegistry) do
		Continents[continent.name] = continent
	end

	if Continents[zoneName] then
		local continent = Continents[zoneName]
		for _, islandName in ipairs(continent.islands) do
			islandsInZone[islandName] = true
		end
		print(("[MonsterSpawner] 大陸 %s の島: %s"):format(zoneName, table.concat(continent.islands, ", ")))
	else
		islandsInZone[zoneName] = true
	end

	for _, def in ipairs(Registry) do
		local monsterName = def.Name or "Monster"
		local template = TemplateCache[monsterName]

		if template then
			if def.SpawnLocations then
				for _, location in ipairs(def.SpawnLocations) do
					local islandName = location.islandName

					if islandsInZone[islandName] then
						local radiusText = location.radiusPercent or 100
						print(
							("[MonsterSpawner] %s を %s に配置中 (数: %d, 範囲: %d%%)"):format(
								monsterName,
								islandName,
								location.count,
								radiusText
							)
						)

						if not MonsterCounts[islandName] then
							MonsterCounts[islandName] = {}
						end
						MonsterCounts[islandName][monsterName] = 0

						for i = 1, (location.count or 0) do
							local spawnDef = {}
							for k, v in pairs(def) do
								spawnDef[k] = v
							end
							spawnDef.radiusPercent = location.radiusPercent
							spawnDef.spawnRadius = location.spawnRadius

							spawnMonster(template, i, spawnDef, islandName)
							if i % 5 == 0 then
								task.wait()
							end
						end
					end
				end
			else
				warn(
					("[MonsterSpawner] %s は旧形式です。SpawnLocations形式に移行してください"):format(
						monsterName
					)
				)
			end
		end
	end
end

-- リスポーン処理（島対応版）
local function scheduleRespawn(monsterName, def, islandName)
	if not def or not def.RespawnTime then
		print(("[MonsterSpawner] %s のRespawnTime が定義されていません"):format(monsterName))
		return
	end

	local respawnData = {
		monsterName = monsterName,
		def = def,
		islandName = islandName,
		respawnAt = os.clock() + def.RespawnTime,
	}

	table.insert(RespawnQueue, respawnData)
	print(
		("[MonsterSpawner] %s がリスポーンキューに追加されました（%d秒後）"):format(
			monsterName,
			def.RespawnTime
		)
	)
end

-- ★ 【新規追加】リスポーンキューを処理する関数
local function processRespawnQueue()
	print("[MonsterSpawner] リスポーンキュー処理開始")

	task.spawn(function()
		while true do
			if #RespawnQueue > 0 then
				local now = os.clock()

				for i = #RespawnQueue, 1, -1 do
					local data = RespawnQueue[i]

					if now >= data.respawnAt then
						-- リスポーン時間に達した
						local template = TemplateCache[data.monsterName]

						if template then
							-- ★ 修正：島名から大陸名に変換
							local zoneName = getContinentNameFromIsland(data.islandName)

							print(
								("[MonsterSpawner] %s が %s にリスポーン（大陸: %s）"):format(
									data.monsterName,
									data.islandName,
									zoneName
								)
							)

							-- ★ 修正：count = 1 に固定（リスポーンは常に1匹）
							local counts = {}
							counts[data.monsterName] = 1 -- ★ 常に1匹だけ

							-- spawnMonstersWithCounts を呼び出し
							spawnMonstersWithCounts(zoneName, counts)
						else
							warn(
								("[MonsterSpawner] テンプレート '%s' が見つかりません"):format(
									data.monsterName
								)
							)
						end

						table.remove(RespawnQueue, i)
					end
				end
			end

			task.wait(1)
		end
	end)
end

print("[MonsterSpawner] scheduleRespawn と processRespawnQueue を登録しました")

-- AI更新ループ（高速化）
local function startGlobalAILoop()
	print("[MonsterSpawner] AI更新ループ開始（高速化版）")

	task.spawn(function()
		while true do
			if #ActiveMonsters > 0 then
				local currentTime = os.clock()

				for i = #ActiveMonsters, 1, -1 do
					local state = ActiveMonsters[i]

					if state:shouldUpdate(currentTime) then
						local success, result = pcall(function()
							return state:update()
						end)

						if not success then
							warn(
								("[MonsterSpawner ERROR] AI更新エラー: %s - %s"):format(
									state.monster.Name,
									tostring(result)
								)
							)
						elseif not result then
							local monsterDef = state.def
							local monsterName = monsterDef.Name or "Unknown"
							local zoneName = state.monster:GetAttribute("SpawnZone") or "Unknown"

							if MonsterCounts[zoneName] and MonsterCounts[zoneName][monsterName] then
								MonsterCounts[zoneName][monsterName] = MonsterCounts[zoneName][monsterName] - 1
							end

							table.remove(ActiveMonsters, i)
							scheduleRespawn(monsterName, monsterDef, zoneName)
						end
					end
				end
			end

			task.wait(UpdateInterval)
		end
	end)
end

-- ゾーンのモンスターを削除する
function despawnMonstersForZone(zoneName)
	print(("[MonsterSpawner] %s のモンスターを削除中..."):format(zoneName))

	local removedCount = 0

	-- ★修正点★: SpawnZone は大陸名で比較
	for i = #ActiveMonsters, 1, -1 do
		local state = ActiveMonsters[i]
		local monsterZone = state.monster:GetAttribute("SpawnZone")

		if monsterZone == zoneName then
			state.monster:Destroy()
			table.remove(ActiveMonsters, i)
			removedCount = removedCount + 1
		end
	end

	-- RespawnQueue からも削除
	for i = #RespawnQueue, 1, -1 do
		if RespawnQueue[i].zoneName == zoneName then
			table.remove(RespawnQueue, i)
		end
	end

	print(("[MonsterSpawner] %s のモンスターを %d体 削除しました"):format(zoneName, removedCount))
end

-- ===== MemoryMonitor 用のモンスター詳細表示（更新版）=====
local function getZoneMonsterDetails(zoneName)
	local details = {}

	for _, state in ipairs(ActiveMonsters) do
		local spawnZone = state.monster:GetAttribute("SpawnZone")
		local spawnIsland = state.monster:GetAttribute("SpawnIsland")

		-- 大陸で比較
		if spawnZone == zoneName then
			if not details[spawnIsland] then
				details[spawnIsland] = 0
			end
			details[spawnIsland] = details[spawnIsland] + 1
		end
	end

	return details
end

-- 初期化
print("[MonsterSpawner] === スクリプト開始（バトル高速化版）===")

if BattleSystem then
	BattleSystem.init()
	print("[MonsterSpawner] BattleSystem初期化完了")
else
	print("[MonsterSpawner] BattleSystemなしで起動")
end

-- モンスターカウントリクエストに応答
GameEvents.MonsterCountRequest.Event:Connect(function(zoneName)
	print(("[MonsterSpawner] モンスターカウントリクエスト受信: %s"):format(zoneName or "全ゾーン"))

	if zoneName then
		-- 特定ゾーンのみ
		SharedState.MonsterCounts[zoneName] = getZoneMonsterCounts(zoneName)
	else
		-- 全ゾーン
		updateAllMonsterCounts()
	end

	-- 完了通知
	GameEvents.MonsterCountResponse:Fire()
end)

print("[MonsterSpawner] GameEventsへの応答登録完了")

Workspace:WaitForChild("World", 10)
print("[MonsterSpawner] World フォルダ検出")

task.wait(1)

print("[MonsterSpawner] モンスターテンプレートをキャッシュ中...")
for _, def in ipairs(Registry) do
	local template = resolveTemplate(def.TemplatePath)
	if template then
		local monsterName = def.Name or "Monster"
		TemplateCache[monsterName] = template
		print(("[MonsterSpawner] テンプレートキャッシュ: %s"):format(monsterName))
	else
		warn(("[MonsterSpawner] テンプレート未発見: %s"):format(def.Name or "?"))
	end
end

startGlobalAILoop()
processRespawnQueue()

print("[MonsterSpawner] === 初期化完了（バトル即座開始対応）===")

_G.SpawnMonstersForZone = spawnMonstersForZone
_G.DespawnMonstersForZone = despawnMonstersForZone
_G.SpawnMonstersWithCounts = spawnMonstersWithCounts
_G.GetZoneMonsterCounts = getZoneMonsterCounts
_G.UpdateAllMonsterCounts = updateAllMonsterCounts

print("[MonsterSpawner] グローバル関数登録完了（カウント機能付き）")

-- ============================================================
-- テクスチャー変更関数（正しいプロパティ版）
-- TopSurfaceTexture などを使用
-- ============================================================

_G.ChangeAllMonsterTexture = function(textureName)
	local textureMap = {
		["brick"] = "rbxasset://textures/Bricks_Layered.png",
		["wood"] = "rbxasset://textures/Wood.png",
		["grass"] = "rbxasset://textures/Grass.png",
		["diamond"] = "rbxasset://textures/Diamondplate.png",
		["marble"] = "rbxasset://textures/Marble.png",
		["slate"] = "rbxasset://textures/Slate.png",
		["concrete"] = "rbxasset://textures/Concrete.png",
		["rock"] = "rbxasset://textures/Rock.png",
	}

	local assetId = textureMap[textureName:lower()]
	if not assetId then
		print(("[ChangeAllMonsterTexture] テクスチャー '%s' が見つかりません"):format(textureName))
		return
	end

	local function applyTexture(part)
		local surfaces = {
			"Top",
			"Bottom",
			"Front",
			"Back",
			"Left",
			"Right",
		}

		for _, surfaceName in ipairs(surfaces) do
			part[surfaceName .. "Surface"] = Enum.SurfaceType.Texture
			part[surfaceName .. "SurfaceTexture"] = assetId
		end
	end

	for _, state in ipairs(ActiveMonsters) do
		local monster = state.monster

		local body = monster:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			applyTexture(body)
		end

		local core = monster:FindFirstChild("Core")
		if core and core:IsA("BasePart") then
			applyTexture(core)
		end
	end

	print(
		("[ChangeAllMonsterTexture] すべてのモンスターのテクスチャーを '%s' に変更"):format(
			textureName
		)
	)
end

_G.ChangeMonsterTexture = function(monsterName, textureName)
	local textureMap = {
		["brick"] = "rbxasset://textures/Bricks_Layered.png",
		["wood"] = "rbxasset://textures/Wood.png",
		["grass"] = "rbxasset://textures/Grass.png",
		["diamond"] = "rbxasset://textures/Diamondplate.png",
		["marble"] = "rbxasset://textures/Marble.png",
		["slate"] = "rbxasset://textures/Slate.png",
		["concrete"] = "rbxasset://textures/Concrete.png",
		["rock"] = "rbxasset://textures/Rock.png",
	}

	local assetId = textureMap[textureName:lower()]
	if not assetId then
		print(("[ChangeMonsterTexture] テクスチャー '%s' が見つかりません"):format(textureName))
		return
	end

	local function applyTexture(part)
		local surfaces = {
			"Top",
			"Bottom",
			"Front",
			"Back",
			"Left",
			"Right",
		}

		for _, surfaceName in ipairs(surfaces) do
			part[surfaceName .. "Surface"] = Enum.SurfaceType.Texture
			part[surfaceName .. "SurfaceTexture"] = assetId
		end
	end

	for _, state in ipairs(ActiveMonsters) do
		if state.monster.Name == monsterName then
			local monster = state.monster

			local body = monster:FindFirstChild("Body")
			if body and body:IsA("BasePart") then
				applyTexture(body)
			end

			local core = monster:FindFirstChild("Core")
			if core and core:IsA("BasePart") then
				applyTexture(core)
			end

			print(
				("[ChangeMonsterTexture] %s のテクスチャーを '%s' に変更"):format(monsterName, textureName)
			)
			return
		end
	end
	print(("[ChangeMonsterTexture] %s が見つかりません"):format(monsterName))
end

print("[MonsterSpawner] テクスチャー変更関数を登録しました（正しい方法）")

-- -- ★ スクリプト内で直接実行（テスト用）
-- task.wait(3)
-- _G.ChangeAllMonsterTexture("brick")

-- local Lighting = game:GetService("Lighting")

-- -- 時刻
-- Lighting.ClockTime = 18

-- -- 暗さ
-- Lighting.Brightness = 0.8

-- -- 環境光（夕方色）
-- Lighting.Ambient = Color3.fromRGB(150, 100, 80)
-- Lighting.OutdoorAmbient = Color3.fromRGB(150, 100, 80)

-- -- 太陽の色
-- local sun = Lighting:FindFirstChild("Sun")
-- if sun then
-- 	sun.Color = Color3.fromRGB(255, 140, 60)
-- end
