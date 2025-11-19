-- ServerScriptService/AutoSetNPCAttributes
-- 自動属性設定スクリプト
-- 機能：プログラムで自動的にすべてのNPCに NPCID 属性を設定
-- 実行すると、Town内のすべてのNPCモデルに NPCID を自動付与

print("[AutoSetNPCAttributes] ========================================")
print("[AutoSetNPCAttributes] NPC属性自動設定を開始します")
print("[AutoSetNPCAttributes] ========================================")

local town = workspace:FindFirstChild("Town")
if not town then
	warn("[AutoSetNPCAttributes] ❌ Town が見つかりません")
	return
end

-- NPCの名前から NPCID を自動生成するマッピング
-- モデル名 → NPCID（スネークケース）
local function generateNPCId(modelName)
	-- 「NPC_」プレフィックスを削除
	local withoutPrefix = modelName:gsub("^NPC_", "")

	-- キャメルケースをスネークケースに変換
	-- 例: VillageElder → village_elder
	local converted = withoutPrefix:gsub("([a-z])([A-Z])", "%1_%2"):lower()

	return converted
end

local successCount = 0
local skipCount = 0
local processedNPCs = {}

print("[AutoSetNPCAttributes] Town内のNPCをスキャン中...")
print("[AutoSetNPCAttributes] ----------------------------------------")

-- Town内のすべてのモデルをスキャン
for _, model in ipairs(town:GetDescendants()) do
	-- Model である確認
	if not model:IsA("Model") then
		continue
	end

	-- HumanoidRootPart を持つモデル = NPC と判定
	-- （人型キャラクターの特徴）
	if not model:FindFirstChild("HumanoidRootPart") then
		continue
	end

	-- Humanoid を持つ確認
	if not model:FindFirstChild("Humanoid") then
		continue
	end

	-- 既に NPCID が設定されている場合はスキップ
	if model:GetAttribute("NPCID") then
		print(
			("[AutoSetNPCAttributes] - %s → 既に NPCID が設定済み（%s）"):format(
				model.Name,
				model:GetAttribute("NPCID")
			)
		)
		skipCount = skipCount + 1
		continue
	end

	-- ProximityPrompt があるか確認
	local hasPrompt = model:FindFirstChildOfClass("ProximityPrompt", true) ~= nil
	if not hasPrompt then
		print(("[AutoSetNPCAttributes] - %s → ProximityPrompt がないためスキップ"):format(model.Name))
		continue
	end

	-- NPCID を自動生成して設定
	local npcId = generateNPCId(model.Name)
	model:SetAttribute("NPCID", npcId)

	print(("[AutoSetNPCAttributes] ✓ %s → NPCID: '%s'"):format(model.Name, npcId))

	table.insert(processedNPCs, {
		name = model.Name,
		npcId = npcId,
	})

	successCount = successCount + 1
end

print("[AutoSetNPCAttributes] ----------------------------------------")
print(("[AutoSetNPCAttributes] 処理完了: %d個設定、%d個スキップ"):format(successCount, skipCount))
print("[AutoSetNPCAttributes] ========================================")

-- NPCData.lua で使用するNPCID の一覧を表示（コピペ用）
if successCount > 0 then
	print("[AutoSetNPCAttributes] ")
	print("[AutoSetNPCAttributes] 📋 NPCData.lua で使用する NPCID 一覧:")
	print("[AutoSetNPCAttributes] ")

	for _, npcInfo in ipairs(processedNPCs) do
		print(("[AutoSetNPCAttributes]     %s = {"):format(npcInfo.npcId))
		print(('[AutoSetNPCAttributes]         name = "%s",'):format(npcInfo.name))
		print('[AutoSetNPCAttributes]         description = "説明を入力",')
		print(('[AutoSetNPCAttributes]         dialogueTree = "%s_main",'):format(npcInfo.npcId))
		print("[AutoSetNPCAttributes]         quests = {},")
		print("[AutoSetNPCAttributes]     },")
	end

	print("[AutoSetNPCAttributes] ")
	print("[AutoSetNPCAttributes] ✅ このテンプレートを NPCData.lua にコピーしてください")
end

print("[AutoSetNPCAttributes] ")
print("[AutoSetNPCAttributes] このスクリプトはもう不要なので、削除してください")
