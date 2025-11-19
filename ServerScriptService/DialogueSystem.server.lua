-- ServerScriptService/DialogueSystem.server.lua
-- NPC会話システム（Town限定版・自動NPCID割り当て版）
-- 機能：Townに配置済みのNPCを検出し、自動的に NPCID を割り当てる

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DialogueSystem = {}
local NPCData = nil
local dialogueCache = {}
local playerDialogueState = {}

print("[DialogueSystem] 初期化開始")

-- ============================================================================
-- RemoteEvent の作成
-- ============================================================================
local function ensureRemoteEvent(name, parent)
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
		print(("[DialogueSystem] ✓ RemoteEvent作成: %s"):format(name))
	end
	return remote
end

local StartDialogueRemote = ensureRemoteEvent("StartDialogue", ReplicatedStorage)
local ChoiceSelectedRemote = ensureRemoteEvent("ChoiceSelected", ReplicatedStorage)
local DialogueEndRemote = ensureRemoteEvent("DialogueEnd", ReplicatedStorage)

-- ============================================================================
-- NPCData のロード
-- ============================================================================
local function loadNPCData()
	local npcDataModule = ReplicatedStorage:FindFirstChild("NPCs")
	if not npcDataModule then
		npcDataModule = Instance.new("Folder")
		npcDataModule.Name = "NPCs"
		npcDataModule.Parent = ReplicatedStorage
		print("[DialogueSystem] NPCsフォルダを作成しました")
	end

	local npcDataPath = npcDataModule:FindFirstChild("NPCData")
	if npcDataPath and npcDataPath:IsA("ModuleScript") then
		local success, data = pcall(require, npcDataPath)
		if success and type(data) == "table" then
			NPCData = data
			print("[DialogueSystem] NPCData ロード成功")
			return true
		else
			warn("[DialogueSystem] NPCData のロード失敗: ", data)
			return false
		end
	else
		warn("[DialogueSystem] NPCData モジュールが見つかりません")
		return false
	end
end

-- ============================================================================
-- NPCID を自動生成する関数
-- ============================================================================
local function generateNPCId(modelName)
	-- 「NPC_」プレフィックスを削除
	local withoutPrefix = modelName:gsub("^NPC_", "")

	-- キャメルケースをスネークケースに変換
	-- 例: VillageElder → village_elder
	local converted = withoutPrefix:gsub("([a-z])([A-Z])", "%1_%2"):lower()

	return converted
end

-- ============================================================================
-- 会話ツリーのロード（キャッシング機能付き）
-- ============================================================================
function DialogueSystem.LoadDialogueTree(treeName)
	if not treeName then
		warn("[DialogueSystem] treeName が nil です")
		return nil
	end

	if dialogueCache[treeName] then
		return dialogueCache[treeName]
	end

	local dialoguesFolder = ReplicatedStorage:FindFirstChild("Dialogues")
	if not dialoguesFolder then
		warn("[DialogueSystem] Dialogues フォルダが見つかりません")
		return nil
	end

	local dialogueModule = dialoguesFolder:FindFirstChild(treeName)
	if not dialogueModule or not dialogueModule:IsA("ModuleScript") then
		warn(("[DialogueSystem] 会話ツリー '%s' が見つかりません"):format(treeName))
		return nil
	end

	local success, data = pcall(require, dialogueModule)
	if success and type(data) == "table" then
		dialogueCache[treeName] = data
		print(("[DialogueSystem] 会話ツリー '%s' をキャッシュしました"):format(treeName))
		return data
	else
		warn(("[DialogueSystem] 会話ツリー '%s' のロード失敗: %s"):format(treeName, data))
		return nil
	end
end

-- ============================================================================
-- NPCの初期化（自動NPCID割り当て版）
-- ============================================================================
function DialogueSystem.Initialize()
	local town = workspace:FindFirstChild("Town")
	if not town then
		warn("[DialogueSystem] Town が Workspace に見つかりません")
		return false
	end

	local npcInitCount = 0
	local errorCount = 0
	local detectedNPCs = {}

	print("[DialogueSystem] ========================================")
	print("[DialogueSystem] Town内のNPCを初期化中...")
	print("[DialogueSystem] ========================================")

	-- Town内のすべてのモデルを探索
	for _, model in ipairs(town:GetDescendants()) do
		if not model:IsA("Model") then
			continue
		end

		-- HumanoidRootPart と Humanoid を持つ確認（NPC判定）
		if not model:FindFirstChild("HumanoidRootPart") or not model:FindFirstChild("Humanoid") then
			continue
		end

		-- ProximityPrompt を検索
		local prompt = model:FindFirstChildOfClass("ProximityPrompt", true)
		if not prompt then
			continue
		end

		-- NPCID を取得（なければ自動生成）
		local npcId = model:GetAttribute("NPCID")
		if not npcId then
			-- 自動生成
			npcId = generateNPCId(model.Name)
			model:SetAttribute("NPCID", npcId)
			print(("[DialogueSystem] [AUTO] %s に NPCID '%s' を自動設定"):format(model.Name, npcId))
		end

		-- NPCData から情報を取得
		if not NPCData or not NPCData[npcId] then
			print(
				("[DialogueSystem] [WARN] '%s' (NPCID: %s) のデータが NPCData にありません"):format(
					model.Name,
					npcId
				)
			)
			errorCount = errorCount + 1
			continue
		end

		local npcInfo = NPCData[npcId]

		-- 二重登録を防止
		if prompt:GetAttribute("DialogueConnected") then
			continue
		end

		-- ProximityPrompt の設定
		prompt.ActionText = prompt.ActionText or "話しかける"
		prompt.ObjectText = npcInfo.name or npcId
		prompt.MaxActivationDistance = prompt.MaxActivationDistance or 15

		-- イベント接続【★ NPCモデルを渡す】
		prompt.Triggered:Connect(function(player)
			DialogueSystem.StartDialogue(player, npcId, model)
		end)

		prompt:SetAttribute("DialogueConnected", true)

		npcInitCount = npcInitCount + 1
		table.insert(detectedNPCs, {
			modelName = model.Name,
			npcId = npcId,
			npcName = npcInfo.name,
		})
		print(("[DialogueSystem] ✓ '%s' → '%s' (%s)"):format(model.Name, npcId, npcInfo.name))
	end

	print("[DialogueSystem] ========================================")

	if npcInitCount == 0 then
		warn("[DialogueSystem] ❌ 初期化可能なNPCが見つかりません")
		warn("[DialogueSystem] 確認事項:")
		warn("[DialogueSystem] 1. Town内にモデルが存在するか")
		warn("[DialogueSystem] 2. モデルに HumanoidRootPart と Humanoid があるか")
		warn("[DialogueSystem] 3. モデルに ProximityPrompt があるか")
		warn("[DialogueSystem] 4. NPCData.lua に対応する定義があるか")
		return false
	end

	print(
		("[DialogueSystem] ✅ NPC初期化完了: %d個のNPC初期化成功、%d個エラー"):format(
			npcInitCount,
			errorCount
		)
	)
	print("[DialogueSystem] ========================================")
	return true
end

-- ============================================================================
-- 会話開始【★ npcModelパラメータ追加】
-- ============================================================================
function DialogueSystem.StartDialogue(player, npcId, npcModel)
	if not player or not player:IsDescendantOf(game.Players) then
		return
	end

	if not NPCData or not NPCData[npcId] then
		warn(("[DialogueSystem] 無効なNPC ID: %s"):format(tostring(npcId)))
		return
	end

	local npcInfo = NPCData[npcId]
	local dialogueTree = DialogueSystem.LoadDialogueTree(npcInfo.dialogueTree)

	if not dialogueTree then
		warn(("[DialogueSystem] 会話ツリー '%s' をロードできません"):format(npcInfo.dialogueTree))
		return
	end

	playerDialogueState[player] = {
		npcId = npcId,
		currentNode = "greeting",
		dialogueTree = dialogueTree,
		npcInfo = npcInfo,
	}

	StartDialogueRemote:FireClient(player, {
		npcId = npcId,
		npcName = npcInfo.name,
		npcDescription = npcInfo.description,
		dialogueTree = dialogueTree,
		npcModel = npcModel, -- ★ NPCモデルをクライアントに送信
	})

	print(("[DialogueSystem] '%s' との会話を開始: %s"):format(player.Name, npcId))
end

-- ============================================================================
-- 選択肢処理（クライアント→サーバ）
-- ============================================================================
ChoiceSelectedRemote.OnServerEvent:Connect(function(player, npcId, nodeName, choiceIndex)
	if not player or not player:IsDescendantOf(game.Players) then
		return
	end

	local state = playerDialogueState[player]
	if not state or state.npcId ~= npcId then
		warn(("[DialogueSystem] '%s' の会話状態が無効です"):format(player.Name))
		return
	end

	local node = state.dialogueTree[nodeName]
	if not node or not node.choices or not node.choices[choiceIndex] then
		warn(("[DialogueSystem] 無効な選択肢: %s -> %d"):format(nodeName, choiceIndex))
		return
	end

	local choice = node.choices[choiceIndex]

	if choice.action then
		DialogueSystem.HandleAction(player, state.npcId, state.npcInfo, choice.action, choice)
	end

	if choice.nextNode then
		playerDialogueState[player].currentNode = choice.nextNode

		local nextNode = state.dialogueTree[choice.nextNode]
		if nextNode then
			StartDialogueRemote:FireClient(player, {
				npcId = npcId,
				npcName = state.npcInfo.name,
				currentNode = choice.nextNode,
				node = nextNode,
			})
		else
			warn(("[DialogueSystem] 次のノード '%s' が見つかりません"):format(choice.nextNode))
			DialogueSystem.EndDialogue(player)
		end
	else
		DialogueSystem.EndDialogue(player)
	end
end)

-- ============================================================================
-- アクション処理
-- ============================================================================
function DialogueSystem.HandleAction(player, npcId, npcInfo, action, choice)
	print(("[DialogueSystem] アクション実行: %s (NPC: %s, Action: %s)"):format(player.Name, npcId, action))

	if action == "acceptQuest" then
		DialogueSystem.AcceptQuest(player, npcId, choice.questId)
	elseif action == "completeQuest" then
		DialogueSystem.CompleteQuest(player, npcId, choice.questId)
	elseif action == "showShop" then
		print("[DialogueSystem] ショップUI表示（未実装）")
	else
		print(("[DialogueSystem] 未知のアクション: %s"):format(action))
	end
end

-- ============================================================================
-- クエスト関連処理
-- ============================================================================
function DialogueSystem.AcceptQuest(player, npcId, questId)
	if not questId then
		return
	end

	local PlayerStatsModule = require(ServerScriptService:WaitForChild("PlayerStats"))
	local stats = PlayerStatsModule.getStats(player)

	if not stats then
		warn(("[DialogueSystem] '%s' のステータスが見つかりません"):format(player.Name))
		return
	end

	if stats.Quests and stats.Quests[questId] then
		print(("[DialogueSystem] '%s' は既に '%s' を受注しています"):format(player.Name, questId))
		return
	end

	if not stats.Quests then
		stats.Quests = {}
	end

	stats.Quests[questId] = {
		status = "accepted",
		acceptedAt = os.time(),
		progress = 0,
	}

	print(("[DialogueSystem] '%s' がクエスト '%s' を受注しました"):format(player.Name, questId))

	if _G.AutoSavePlayer then
		_G.AutoSavePlayer(player, "クエスト受注")
	end
end

function DialogueSystem.CompleteQuest(player, npcId, questId)
	if not questId then
		return
	end

	local PlayerStatsModule = require(ServerScriptService:WaitForChild("PlayerStats"))
	local stats = PlayerStatsModule.getStats(player)

	if not stats or not stats.Quests or not stats.Quests[questId] then
		warn(("[DialogueSystem] '%s' がクエスト '%s' を受注していません"):format(player.Name, questId))
		return
	end

	stats.Quests[questId].status = "completed"
	stats.Quests[questId].completedAt = os.time()

	print(("[DialogueSystem] '%s' がクエスト '%s' を完了しました"):format(player.Name, questId))

	if _G.AutoSavePlayer then
		_G.AutoSavePlayer(player, "クエスト完了")
	end
end

-- ============================================================================
-- 会話終了
-- ============================================================================
function DialogueSystem.EndDialogue(player)
	if not player or not player:IsDescendantOf(game.Players) then
		return
	end

	DialogueEndRemote:FireClient(player)
	playerDialogueState[player] = nil

	print(("[DialogueSystem] '%s' との会話を終了"):format(player.Name))
end

-- ============================================================================
-- クリーンアップ
-- ============================================================================
game:GetService("Players").PlayerRemoving:Connect(function(player)
	playerDialogueState[player] = nil
end)

-- ============================================================================
-- 初期化実行
-- ============================================================================
local function initializeDialogueSystem()
	if not loadNPCData() then
		warn("[DialogueSystem] NPCData のロードに失敗しました")
		return
	end

	if not DialogueSystem.Initialize() then
		warn("[DialogueSystem] NPC初期化に失敗しました")
		return
	end

	print("[DialogueSystem] === 初期化完了 ===")
end

task.spawn(initializeDialogueSystem)

return DialogueSystem
