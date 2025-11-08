-- ServerScriptService/WarpPortal.server.lua
-- 改善版：ポータルワープにプレイヤーレベルを送信

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("[WarpPortal] 初期化開始")

local warpEvent = ReplicatedStorage:FindFirstChild("WarpEvent")
if not warpEvent then
	warpEvent = Instance.new("RemoteEvent")
	warpEvent.Name = "WarpEvent"
	warpEvent.Parent = ReplicatedStorage
end

local ZoneManager = require(script.Parent.ZoneManager)
local BattleSystem = require(script.Parent.BattleSystem)
local PlayerStatsModule = require(script.Parent.PlayerStats)

local warpingPlayers = {}
local activePortals = {}

local IslandsRegistry = require(ReplicatedStorage.Islands.Registry)
local ContinentsRegistry = require(ReplicatedStorage.Continents.Registry)

local Islands = {}
for _, island in ipairs(IslandsRegistry) do
	Islands[island.name] = island
end

local Continents = {}
for _, continent in ipairs(ContinentsRegistry) do
	if continent and continent.name then
		Continents[continent.name] = continent
	else
		warn("[WarpPortal] 名前が設定されていない大陸定義をスキップしました")
	end
end

local function ensureHRP(model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		if not model.PrimaryPart then
			model.PrimaryPart = hrp
		end
		return hrp
	end
	return nil
end

local function attachLabel(model, maxDist)
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
	gui.Size = UDim2.new(0, 150, 0, 50)
	gui.StudsOffset = Vector3.new(0, labelOffset, 0)
	gui.MaxDistance = maxDist
	gui.Parent = hrp

	local lb = Instance.new("TextLabel")
	lb.Name = "InfoText"
	lb.BackgroundTransparency = 1
	lb.TextScaled = true
	lb.Font = Enum.Font.GothamBold
	lb.TextColor3 = Color3.new(1, 1, 1)
	lb.TextStrokeTransparency = 0.5
	lb.Size = UDim2.fromScale(1, 1)
	lb.Text = "Ready"
	lb.Parent = gui
end

-- ==========================================================
-- createPortal()
-- 大陸定義ファイル内のポータル定義から、ワープポータルを生成（確実に反応するTouchHitbox付き）
-- ==========================================================
local function createPortal(config, fromZone)
	local islandName = config.islandName or fromZone
	local zoneConfig = Islands[islandName]

	if not zoneConfig then
		warn(("[WarpPortal] ゾーン '%s' の島設定が見つかりません"):format(islandName))
		return nil
	end

	-- === 1) 座標計算（position優先。指定が無ければ offsetX/Z 互換） ===
	local portalX, portalY, portalZ
	local portalHeight = 10
	local FieldGen = require(ReplicatedStorage:WaitForChild("FieldGen"))

	if config.position then
		portalX = config.position[1]
		portalY = config.position[2]
		portalZ = config.position[3]
		if not portalY then
			local rayStartY = (zoneConfig.baseY or 30) + (zoneConfig.hillAmplitude or 20) + 100
			local groundY = FieldGen.raycastGroundY(portalX, portalZ, rayStartY)
			portalY = (groundY and (groundY + portalHeight / 2)) or ((zoneConfig.baseY or 30) + portalHeight / 2)
		end
	else
		portalX = (zoneConfig.centerX or 0) + (config.offsetX or 0)
		portalZ = (zoneConfig.centerZ or 0) + (config.offsetZ or 0)
		local rayStartY = (zoneConfig.baseY or 30) + (zoneConfig.hillAmplitude or 20) + 100
		local groundY = FieldGen.raycastGroundY(portalX, portalZ, rayStartY)
		portalY = (groundY and (groundY + portalHeight / 2)) or ((zoneConfig.baseY or 30) + portalHeight / 2)
	end
	local portalPosition = Vector3.new(portalX, portalY, portalZ)

	-- === 2) 見た目のポータル（モデル or デフォルトPart） ===
	local portal
	if config.model then
		local ServerStorage = game:GetService("ServerStorage")
		local templatesRoot = ServerStorage:FindFirstChild("FieldObjects")
		if not templatesRoot then
			warn("[WarpPortal] ServerStorage/FieldObjects が見つかりません")
			return nil
		end
		local template = templatesRoot:FindFirstChild(config.model)
		if not template then
			warn(("[WarpPortal] モデル '%s' が FieldObjects に見つかりません"):format(config.model))
			return nil
		end

		portal = template:Clone()
		portal.Name = config.name or ("Portal_" .. tostring(math.random(10000)))

		for _, part in ipairs(portal:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				-- 見た目側は触れなくてもOK（反応は専用Hitboxで取る）
				part.CanTouch = false
			end
		end

		if portal:IsA("Model") and not portal.PrimaryPart then
			local base = portal:FindFirstChildWhichIsA("BasePart")
			if base then
				portal.PrimaryPart = base
			end
		end

		local scale = config.size or 1
		if portal:IsA("Model") and scale ~= 1 then
			pcall(function()
				portal:ScaleTo(scale)
			end)
		end

		local rotation = config.rotation or { 0, 0, 0 }
		local rotCFrame =
			CFrame.Angles(math.rad(rotation[1] or 0), math.rad(rotation[2] or 0), math.rad(rotation[3] or 0))

		if portal:IsA("Model") then
			portal:PivotTo(CFrame.new(portalPosition) * rotCFrame)
		elseif portal:IsA("BasePart") then
			portal.CFrame = CFrame.new(portalPosition) * rotCFrame
		end
	else
		local p = Instance.new("Part")
		p.Name = config.name or "Portal_Default"
		p.Size = config.size or Vector3.new(8, 12, 8)
		p.Position = portalPosition
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.Transparency = 0.3
		p.Color = config.color or Color3.fromRGB(255, 255, 255)
		p.Material = Enum.Material.Neon
		portal = p
	end

	portal:SetAttribute("FromZone", fromZone)
	portal:SetAttribute("ToZone", config.toZone)

	-- === 3) Workspaceに配置 ===
	local worldFolder = workspace:FindFirstChild("World") or Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = workspace
	portal.Parent = worldFolder

	-- === 4) ラベル（任意） ===
	local labelParent = portal:IsA("Model") and portal.PrimaryPart or portal
	if labelParent then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PortalLabel"
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 7, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = labelParent

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = config.label or ("→ " .. (config.toZone or "?"))
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.TextStrokeTransparency = 0.5
		label.Parent = billboard
	end

	-- === 5) 専用ヒットボックス（確実にTouchedを取る） ===
	local hitbox = Instance.new("Part")
	hitbox.Name = (portal.Name .. "_TouchHitbox")
	hitbox.Size = config.hitboxSize or Vector3.new(10, 12, 10) -- 反応しやすいデフォルト
	hitbox.CFrame = CFrame.new(portalPosition + (config.hitboxOffset or Vector3.new(0, 0, 0)))
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.CanTouch = true
	hitbox.Parent = worldFolder

	-- === 6️⃣ ProximityPrompt（E長押しでワープ） ===
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "ワープする"
	prompt.ObjectText = config.label or ("→ " .. (config.toZone or "?"))
	prompt.HoldDuration = 1.0 -- 長押し時間(秒)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = hitbox -- ヒットボックスに付与

	prompt.Triggered:Connect(function(player)
		if not player or warpingPlayers[player.UserId] then
			return
		end
		if BattleSystem and BattleSystem.isInBattle and BattleSystem.isInBattle(player) then
			return
		end

		local character = player.Character
		if not character then
			return
		end

		print("[DEBUG Prompt] Warp triggered by:", player.Name, "→", config.toZone)

		local currentZone = ZoneManager.GetPlayerZone(player)
		if not currentZone then
			ZoneManager.PlayerZones[player] = fromZone
		end

		local stats = PlayerStatsModule.getStats(player)
		local level = stats and stats.Level or 1
		warpEvent:FireClient(player, "StartLoading", config.toZone, level)

		task.wait(0.3)
		BattleSystem.resetAllBattles()

		local success = ZoneManager.WarpPlayerToZone(player, config.toZone)
		print("[DEBUG Prompt] Warp success:", success)

		if success then
			createPortalsForZone(config.toZone)
			if _G.SpawnMonstersForZone then
				_G.SpawnMonstersForZone(config.toZone)
			end
			task.wait(0.3)
			warpEvent:FireClient(player, "EndLoading", config.toZone, level)
		else
			warn(("[WarpPortal] %s のワープに失敗"):format(player.Name))
			warpEvent:FireClient(player, "EndLoading", config.toZone, level)
		end

		task.delay(0.75, function()
			warpingPlayers[player.UserId] = nil
			if character then
				character:SetAttribute("IsWarping", false)
			end
		end)
	end)

	-- === 7) オプション：見た目の回転エフェクト（任意）
	if config.rotate then
		local target = (portal:IsA("Model") and portal.PrimaryPart) or (portal:IsA("BasePart") and portal) or nil
		if target then
			local bav = Instance.new("BodyAngularVelocity")
			bav.AngularVelocity = Vector3.new(0, config.rotateSpeed or 2, 0)
			bav.MaxTorque = Vector3.new(0, math.huge, 0)
			bav.P = 1000
			bav.Parent = target
		end
	end

	-- デバッグ：生成確認
	-- print(("[WarpPortal] Portal ready: %s → %s @ (%.1f, %.1f, %.1f)")
	--   :format(fromZone, config.toZone, portalPosition.X, portalPosition.Y, portalPosition.Z))

	return portal
end

function createPortalsForZone(zoneName)
	print("[WarpPortal DEBUG] createPortalsForZone 呼び出し:", zoneName)

	if activePortals[zoneName] then
		print(("[WarpPortal] %s のポータルは既に存在します"):format(zoneName))
		return
	end

	activePortals[zoneName] = {}

	local continent = Continents[zoneName]
	if continent and continent.portals then
		print(("[WarpPortal] %s のポータルを並列生成中..."):format(zoneName))

		for _, portalConfig in ipairs(continent.portals) do
			task.spawn(function()
				local islandName = portalConfig.islandName
				if not Islands[islandName] then
					warn(("[WarpPortal] 島 %s が見つかりません"):format(islandName))
				else
					local portal = createPortal(portalConfig, zoneName)
					if portal then
						portal:SetAttribute("FromZone", zoneName)
						table.insert(activePortals[zoneName], portal)
						print(
							("[WarpPortal] ポータル作成: %s (配置: %s)"):format(portalConfig.name, islandName)
						)
					end
				end
			end)
		end
	else
		print(("[WarpPortal] %s のポータル設定が見つかりません"):format(zoneName))
	end
end

function destroyPortalsForZone(zoneName)
	local actualZoneName = zoneName
	if actualZoneName == "StartTown" then
		actualZoneName = "ContinentTown"
	end

	if not activePortals[actualZoneName] then
		print(
			("[WarpPortal] %s のポータルはありません（既に削除済みか未作成）"):format(
				actualZoneName
			)
		)
		return
	end

	print(("[WarpPortal] %s のポータルを削除中..."):format(actualZoneName))

	for _, portal in ipairs(activePortals[actualZoneName] or {}) do
		if portal and portal.Parent then
			portal:Destroy()
		end
	end

	activePortals[actualZoneName] = nil
	print(("[WarpPortal] %s のポータルを削除完了"):format(actualZoneName))
end

task.spawn(function()
	local maxWait = 10
	local waited = 0

	while not _G.SpawnMonstersForZone and waited < maxWait do
		task.wait(0.5)
		waited = waited + 0.5
	end

	if _G.SpawnMonstersForZone then
		print("[WarpPortal] MonsterSpawner関数検出成功")
	else
		warn("[WarpPortal] MonsterSpawner関数が見つかりません")
	end
end)

task.wait(0.3)
createPortalsForZone("ContinentTown")

Players.PlayerRemoving:Connect(function(player)
	warpingPlayers[player.UserId] = nil
	ZoneManager.PlayerZones[player] = nil
end)

_G.CreatePortalsForZone = createPortalsForZone
_G.DestroyPortalsForZone = destroyPortalsForZone

print("[WarpPortal] 初期化完了")
