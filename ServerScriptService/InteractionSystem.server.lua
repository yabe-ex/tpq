-- ServerScriptService/InteractionSystem.server.lua
-- インタラクションシステム（宝箱、NPC等）

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

print("[InteractionSystem] 初期化開始")

-- 依存モジュール
local PlayerStatsModule = require(ServerScriptService:WaitForChild("PlayerStats"))

-- RemoteEvent作成
local InteractEvent = ReplicatedStorage:FindFirstChild("InteractEvent")
if not InteractEvent then
	InteractEvent = Instance.new("RemoteEvent")
	InteractEvent.Name = "InteractEvent"
	InteractEvent.Parent = ReplicatedStorage
end

local InteractionResponseEvent = ReplicatedStorage:FindFirstChild("InteractionResponse")
if not InteractionResponseEvent then
	InteractionResponseEvent = Instance.new("RemoteEvent")
	InteractionResponseEvent.Name = "InteractionResponse"
	InteractionResponseEvent.Parent = ReplicatedStorage
end

-- 宝箱を開ける処理
local function handleChestInteraction(player, chestObject)
	print("[InteractionSystem DEBUG] ステップ1: 開始")

	local chestId = chestObject:GetAttribute("ChestId")
	if not chestId then
		warn("[InteractionSystem] ChestIdが設定されていません")
		return false
	end

	print("[InteractionSystem DEBUG] ステップ2: ChestId取得 =", chestId)

	-- プレイヤーのステータスを取得
	local stats = PlayerStatsModule.getStats(player)
	if not stats then
		warn(("[InteractionSystem] %s のステータスが見つかりません"):format(player.Name))
		return false
	end

	print("[InteractionSystem DEBUG] ステップ3: ステータス取得完了")

	-- 既に取得済みかチェック
	if stats.CollectedItems[chestId] then
		print(("[InteractionSystem] %s は既に %s を取得済み"):format(player.Name, chestId))
		return false
	end

	print("[InteractionSystem DEBUG] ステップ4: 未取得確認完了")

	-- 距離チェック（不正防止）
	local character = player.Character
	if not character then
		warn("[InteractionSystem DEBUG] キャラクターなし")
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn("[InteractionSystem DEBUG] HRPなし")
		return false
	end

	print("[InteractionSystem DEBUG] ステップ5: キャラクター確認完了")

	local distance = (hrp.Position - chestObject.Position).Magnitude
	local range = chestObject:GetAttribute("InteractionRange") or 8

	if distance > range + 5 then
		warn(("[InteractionSystem] %s が遠すぎます: %.1f > %d"):format(player.Name, distance, range))
		return false
	end

	print("[InteractionSystem DEBUG] ステップ6: 距離チェック完了")
	print(("[InteractionSystem] %s が %s を開けます"):format(player.Name, chestId))

	-- 報酬データを取得
	local rewardsJson = chestObject:GetAttribute("RewardsData")
	print("[InteractionSystem DEBUG] ステップ7: RewardsData =", rewardsJson)

	local rewards = {}
	if rewardsJson then
		local success, decoded = pcall(function()
			return HttpService:JSONDecode(rewardsJson)
		end)
		if success then
			rewards = decoded
			print("[InteractionSystem DEBUG] ステップ8: 報酬デコード成功")
		else
			warn("[InteractionSystem DEBUG] ステップ8: 報酬デコード失敗")
		end
	end

	-- 報酬を付与
	for _, reward in ipairs(rewards) do
		if reward.item == "ゴールド" then
			stats.Gold = stats.Gold + reward.count
			print(("[InteractionSystem] %s にゴールド %d を付与"):format(player.Name, reward.count))
		else
			-- 将来的にアイテムシステムと連携
			print(("[InteractionSystem] %s に %s x%d を付与（未実装）"):format(
				player.Name, reward.item, reward.count
			))
		end
	end

	print("[InteractionSystem DEBUG] ステップ9: 報酬付与完了")

	-- 取得済みに設定
	stats.CollectedItems[chestId] = true

	-- セーブ（即座に保存）
	if _G.AutoSavePlayer then
		_G.AutoSavePlayer(player, "宝箱取得")
	end

	print("[InteractionSystem DEBUG] ステップ10: セーブ完了")

	-- モデルを開いた状態に切り替え
	local openedModelName = chestObject:GetAttribute("OpenedModel")
	if openedModelName then
		print("[InteractionSystem DEBUG] ステップ11: モデル切り替え開始")
		task.spawn(function()
			local ServerStorage = game:GetService("ServerStorage")
			local fieldObjectsFolder = ServerStorage:FindFirstChild("FieldObjects")
			if fieldObjectsFolder then
				local openedTemplate = fieldObjectsFolder:FindFirstChild(openedModelName)
				if openedTemplate then
					-- 閉じた宝箱を非表示
					chestObject.Transparency = 1
					for _, child in ipairs(chestObject:GetDescendants()) do
						if child:IsA("BasePart") then
							child.Transparency = 1
						end
					end

					-- 開いた宝箱を配置
					local openedChest = openedTemplate:Clone()
					openedChest.CFrame = chestObject.CFrame
					openedChest.Anchored = true
					openedChest.CanCollide = false
					openedChest.Parent = chestObject.Parent

					print("[InteractionSystem DEBUG] 開いた宝箱を配置")

					-- 表示時間後に削除
					local duration = chestObject:GetAttribute("DisplayDuration") or 3
					task.wait(duration)

					openedChest:Destroy()
					chestObject:Destroy()

					print(("[InteractionSystem] %s を削除しました"):format(chestId))
				else
					warn("[InteractionSystem DEBUG] 開いたモデルが見つかりません:", openedModelName)
				end
			else
				warn("[InteractionSystem DEBUG] FieldObjectsフォルダが見つかりません")
			end
		end)
	end

	print("[InteractionSystem DEBUG] ステップ12: クライアント送信準備")

	-- クライアントに報酬情報を送信
	local responseData = {
		success = true,
		type = "chest",
		rewards = rewards,
		displayDuration = chestObject:GetAttribute("DisplayDuration") or 3,
	}

	print(("[InteractionSystem DEBUG] 送信データ: %s"):format(HttpService:JSONEncode(responseData)))

	InteractionResponseEvent:FireClient(player, responseData)

	print("[InteractionSystem DEBUG] ステップ13: 送信完了")

	return true
end

-- インタラクション処理のルーティング
local function handleInteraction(player, object)
	print("[InteractionSystem DEBUG] handleInteraction呼び出し")

	if not object or not object:IsA("BasePart") then
		warn("[InteractionSystem DEBUG] オブジェクトが無効")
		return
	end

	print("[InteractionSystem DEBUG] オブジェクト:", object.Name)

	local interactionType = object:GetAttribute("InteractionType")
	print("[InteractionSystem DEBUG] InteractionType:", interactionType)

	if interactionType == "chest" then
		handleChestInteraction(player, object)
	elseif interactionType == "npc" then
		-- 将来的にNPC処理
		print("[InteractionSystem] NPC処理は未実装")
	else
		warn(("[InteractionSystem] 未知のインタラクションタイプ: %s"):format(tostring(interactionType)))
	end
end

-- イベント接続
InteractEvent.OnServerEvent:Connect(function(player, object)
	print("[InteractionSystem DEBUG] InteractEvent受信")
	handleInteraction(player, object)
end)

-- 取得済みアイテムリストを返すRemoteFunction
local GetCollectedItemsFunc = ReplicatedStorage:FindFirstChild("GetCollectedItems")
if not GetCollectedItemsFunc then
	GetCollectedItemsFunc = Instance.new("RemoteFunction")
	GetCollectedItemsFunc.Name = "GetCollectedItems"
	GetCollectedItemsFunc.Parent = ReplicatedStorage
end

GetCollectedItemsFunc.OnServerInvoke = function(player)
	local stats = PlayerStatsModule.getStats(player)
	if stats and stats.CollectedItems then
		print(("[InteractionSystem] %s の取得済みリストを送信: %d個"):format(
			player.Name,
			next(stats.CollectedItems) and #stats.CollectedItems or 0
		))
		return stats.CollectedItems
	end
	return {}
end

print("[InteractionSystem] 初期化完了")