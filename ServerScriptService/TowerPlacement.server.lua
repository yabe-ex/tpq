-- ServerScriptService/TowerPlacement.server.lua
-- StartTownにタワーを配置

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
print("[TowerPlacement] タワー配置をスキップ")
-- print("[TowerPlacement] タワー配置開始")

-- -- StartTownの設定を取得
-- local IslandsRegistry = require(ReplicatedStorage.Islands.Registry)
-- local townConfig = nil
-- for _, island in ipairs(IslandsRegistry) do
-- 	if island.name == "StartTown" then
-- 		townConfig = island
-- 		break
-- 	end
-- end

-- if not townConfig then
-- 	warn("[TowerPlacement] StartTownの設定が見つかりません")
-- 	return
-- end

-- -- 配置位置（StartTownの中心から東に50スタッド）
-- local TOWER_OFFSET_X = 400  -- ★修正: 400に変更 (-100 + 400 = 300)
-- local TOWER_OFFSET_Z = -100 -- ★修正: -100に変更 (100 + (-100) = 0)

-- -- 地形生成を待つ
-- task.wait(1)

-- -- ServerStorage/Buildingsからタワーのテンプレートを取得
-- local buildingsFolder = ServerStorage:FindFirstChild("Buildings")
-- if not buildingsFolder then
-- 	warn("[TowerPlacement] ServerStorage に 'Buildings' フォルダが見つかりません")
-- 	return
-- end

-- local towerTemplate = buildingsFolder:FindFirstChild("Tower")
-- if not towerTemplate then
-- 	warn("[TowerPlacement] ServerStorage/Buildings に 'Tower' が見つかりません")
-- 	warn("[TowerPlacement] Toolboxから Asset ID 12127172596 を ServerStorage/Buildings に配置してください")
-- 	return
-- end

-- -- タワーを複製
-- local tower = towerTemplate:Clone()
-- tower.Parent = workspace

-- print("[TowerPlacement] タワーを読み込みました:", tower.Name)

-- -- 配置位置を計算
-- local towerX = townConfig.centerX + TOWER_OFFSET_X
-- local towerZ = townConfig.centerZ + TOWER_OFFSET_Z

-- -- 地面の高さを取得
-- local FieldGen = require(ReplicatedStorage:WaitForChild("FieldGen"))
-- local groundY = FieldGen.raycastGroundY(towerX, towerZ, townConfig.baseY + 100)

-- if not groundY then
-- 	-- レイキャストが失敗した場合は推定高度を使用
-- 	groundY = townConfig.baseY + 5
-- 	warn("[TowerPlacement] 地面検出失敗、推定高度を使用:", groundY)
-- end

-- -- タワーの底面を地面に合わせる
-- if tower:IsA("Model") then
-- 	-- Modelの場合：最下点を地面に合わせる
-- 	local primaryPart = tower.PrimaryPart
-- 	if not primaryPart then
-- 		for _, part in ipairs(tower:GetDescendants()) do
-- 			if part:IsA("BasePart") then
-- 				tower.PrimaryPart = part
-- 				primaryPart = part
-- 				print("[TowerPlacement] PrimaryPartを自動設定:", part.Name)
-- 				break
-- 			end
-- 		end
-- 	end

-- 	if primaryPart then
-- 		-- まず目標位置に配置
-- 		tower:SetPrimaryPartCFrame(CFrame.new(towerX, groundY, towerZ))

-- 		-- 最下点を探す
-- 		local lowestY = math.huge
-- 		local lowestPartName = ""
-- 		for _, part in ipairs(tower:GetDescendants()) do
-- 			if part:IsA("BasePart") then
-- 				local partBottom = part.Position.Y - (part.Size.Y / 2)
-- 				if partBottom < lowestY then
-- 					lowestY = partBottom
-- 					lowestPartName = part.Name
-- 				end
-- 			end
-- 		end

-- 		print(("[TowerPlacement] デバッグ情報:"):format())
-- 		print(("  地面の高さ (groundY): %.1f"):format(groundY))
-- 		print(("  最下点パーツ: %s"):format(lowestPartName))
-- 		print(("  最下点の高さ (配置前): %.1f"):format(lowestY))

-- 		-- 最下点が地面になるよう調整
-- 		local adjustment = groundY - lowestY
-- 		local currentCFrame = tower:GetPrimaryPartCFrame()
-- 		tower:SetPrimaryPartCFrame(currentCFrame + Vector3.new(0, adjustment, 0))

-- 		-- 調整後の最下点を確認
-- 		local newLowestY = math.huge
-- 		for _, part in ipairs(tower:GetDescendants()) do
-- 			if part:IsA("BasePart") then
-- 				local partBottom = part.Position.Y - (part.Size.Y / 2)
-- 				if partBottom < newLowestY then
-- 					newLowestY = partBottom
-- 				end
-- 			end
-- 		end

-- 		local _, size = tower:GetBoundingBox()
-- 		print("[TowerPlacement] タワーを配置しました (Model):")
-- 		print(("  位置: X=%.1f, Y=%.1f, Z=%.1f"):format(towerX, groundY, towerZ))
-- 		print(("  サイズ: %.1f x %.1f x %.1f"):format(size.X, size.Y, size.Z))
-- 		print(("  調整: %.1f スタッド上に移動"):format(adjustment))
-- 		print(("  調整後の最下点: %.1f (目標: %.1f)"):format(newLowestY, groundY))
-- 	else
-- 		local cf, size = tower:GetBoundingBox()
-- 		local lowestY = cf.Position.Y - (size.Y / 2)
-- 		local adjustment = groundY - lowestY
-- 		tower:PivotTo(CFrame.new(towerX, groundY + adjustment, towerZ))
-- 		print("[TowerPlacement] PivotToで配置しました:")
-- 		print(("  位置: X=%.1f, Y=%.1f, Z=%.1f"):format(towerX, groundY, towerZ))
-- 	end
-- elseif tower:IsA("BasePart") then
-- 	-- MeshPartなど単一パーツの場合
-- 	local size = tower.Size
-- 	local offsetY = size.Y / 2
-- 	tower.CFrame = CFrame.new(towerX, groundY + offsetY, towerZ)
-- 	print("[TowerPlacement] タワーを配置しました (BasePart):")
-- 	print(("  位置: X=%.1f, Y=%.1f, Z=%.1f"):format(towerX, groundY + offsetY, towerZ))
-- 	print(("  サイズ: %.1f x %.1f x %.1f"):format(size.X, size.Y, size.Z))
-- else
-- 	warn("[TowerPlacement] 未対応の型:", tower.ClassName)
-- 	return
-- end

-- -- タワーを固定
-- for _, part in ipairs(tower:GetDescendants()) do
-- 	if part:IsA("BasePart") then
-- 		part.Anchored = true
-- 	end
-- end

-- print("[TowerPlacement] 配置完了")