-- StartPlayerScripts/DialogueUI.client.lua
-- NPC会話UI（クライアント側）【グリッドレイアウト + 数字入力 + NPC停止版】
-- 機能：選択肢を2列グリッドで表示、数字キー入力、対話中NPCの停止

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local DialogueUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StartDialogueRemote = ReplicatedStorage:WaitForChild("StartDialogue")
local ChoiceSelectedRemote = ReplicatedStorage:WaitForChild("ChoiceSelected")
local DialogueEndRemote = ReplicatedStorage:WaitForChild("DialogueEnd")

-- UI状態管理
local currentDialogueState = {
	isOpen = false,
	npcId = nil,
	npcName = nil,
	npcModel = nil, -- ★ 対話中のNPCモデル
	dialogueTree = nil,
	currentNode = "greeting",
	selectedChoiceIndex = 1,
}

-- プレイヤーフリーズ用
local playerCharacter = nil
local playerHumanoid = nil
local playerHRP = nil
local originalWalkSpeed = 0
local originalJumpPower = 0

-- ============================================================================
-- プレイヤーをフリーズさせる関数
-- ============================================================================
local function freezePlayer()
	playerCharacter = player.Character
	if not playerCharacter then
		return
	end

	playerHumanoid = playerCharacter:FindFirstChild("Humanoid")
	playerHRP = playerCharacter:FindFirstChild("HumanoidRootPart")

	if playerHumanoid and playerHRP then
		originalWalkSpeed = playerHumanoid.WalkSpeed
		originalJumpPower = playerHumanoid.JumpPower

		print(
			("[DialogueUI] [DEBUG] フリーズ前: WalkSpeed=%d, JumpPower=%d"):format(
				originalWalkSpeed,
				originalJumpPower
			)
		)

		playerHumanoid.WalkSpeed = 0
		playerHumanoid.JumpPower = 0

		-- ★ ContextActionService で Space キーをバインド（ジャンプをブロック）
		local ContextActionService = game:GetService("ContextActionService")
		local function blockJump(actionName, inputState, inputObject)
			if inputState == Enum.UserInputState.Begin then
				print("[DialogueUI] ★ Space キーをブロック中（ContextActionService）")
				return Enum.ContextActionResult.Sink -- Space キー入力を消費
			end
			return Enum.ContextActionResult.Pass
		end
		ContextActionService:BindAction("BlockJumpAction", blockJump, false, Enum.KeyCode.Space)
		currentDialogueState.blockJumpAction = "BlockJumpAction"

		print(
			("[DialogueUI] [DEBUG] フリーズ後: WalkSpeed=%d, JumpPower=%d"):format(
				playerHumanoid.WalkSpeed,
				playerHumanoid.JumpPower
			)
		)
		print(
			"[DialogueUI] ✓ プレイヤーをフリーズしました（ContextActionService で Space ブロック）"
		)
	end
end

-- ============================================================================
-- プレイヤーのフリーズを解除する関数
-- ============================================================================
local function unfreezePlayer()
	if playerHumanoid then
		print(
			("[DialogueUI] [DEBUG] フリーズ解除前: WalkSpeed=%d, JumpPower=%d"):format(
				playerHumanoid.WalkSpeed,
				playerHumanoid.JumpPower
			)
		)

		-- ★ ContextActionService のバインドを解除
		if currentDialogueState.blockJumpAction then
			local ContextActionService = game:GetService("ContextActionService")
			ContextActionService:UnbindAction(currentDialogueState.blockJumpAction)
			print("[DialogueUI] ★ ContextActionService のバインドを解除")
			currentDialogueState.blockJumpAction = nil
		end

		playerHumanoid.WalkSpeed = originalWalkSpeed
		playerHumanoid.JumpPower = originalJumpPower

		print(
			("[DialogueUI] [DEBUG] フリーズ解除後: WalkSpeed=%d, JumpPower=%d"):format(
				playerHumanoid.WalkSpeed,
				playerHumanoid.JumpPower
			)
		)
		print("[DialogueUI] ✓ プレイヤーのフリーズを解除しました")
	end
end

-- ============================================================================
-- 指定したNPCモデルをフリーズさせる関数
-- ============================================================================
local function freezeNPC(npcModel)
	if not npcModel then
		return
	end

	currentDialogueState.npcModel = npcModel

	local humanoid = npcModel:FindFirstChild("Humanoid")
	if humanoid then
		npcModel:SetAttribute("FrozenByDialogue", true)
		npcModel:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
		humanoid.WalkSpeed = 0
		print(("[DialogueUI] ✓ NPC '%s' をフリーズしました"):format(npcModel.Name))
	end
end

-- ============================================================================
-- NPCのフリーズを解除する関数
-- ============================================================================
local function unfreezeNPC()
	local npcModel = currentDialogueState.npcModel
	if not npcModel then
		return
	end

	local humanoid = npcModel:FindFirstChild("Humanoid")
	if humanoid and npcModel:GetAttribute("FrozenByDialogue") then
		local originalSpeed = npcModel:GetAttribute("OriginalWalkSpeed") or 16
		humanoid.WalkSpeed = originalSpeed
		npcModel:SetAttribute("FrozenByDialogue", false)
		print(("[DialogueUI] ✓ NPC '%s' のフリーズを解除しました"):format(npcModel.Name))
	end

	currentDialogueState.npcModel = nil
end

-- ============================================================================
-- UI要素の作成【グリッドレイアウト対応版】
-- ============================================================================
local function createDialogueUI()
	-- 既存のUIを削除
	local existingUI = playerGui:FindFirstChild("DialogueUI")
	if existingUI then
		existingUI:Destroy()
	end

	-- メインコンテナ
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DialogueUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui

	-- 背景（ダーク）
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.Position = UDim2.new(0, 0, 0, 0)
	background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	background.BackgroundTransparency = 0.3
	background.BorderSizePixel = 0
	background.Parent = screenGui

	-- 会話ウィンドウ（下部中央）
	local dialogueWindow = Instance.new("Frame")
	dialogueWindow.Name = "DialogueWindow"
	dialogueWindow.Size = UDim2.new(0.8, 0, 0.40, 0) -- ★ 0.35 → 0.40 に変更
	dialogueWindow.Position = UDim2.new(0.1, 0, 0.55, 0)
	dialogueWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	dialogueWindow.BorderColor3 = Color3.fromRGB(100, 150, 255)
	dialogueWindow.BorderSizePixel = 2
	dialogueWindow.Parent = screenGui

	-- コーナー丸め
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = dialogueWindow

	-- NPC名表示
	local npcNameLabel = Instance.new("TextLabel")
	npcNameLabel.Name = "NPCNameLabel"
	npcNameLabel.Size = UDim2.new(1, -20, 0, 40)
	npcNameLabel.Position = UDim2.new(0, 10, 0, 10)
	npcNameLabel.BackgroundTransparency = 1
	npcNameLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	npcNameLabel.TextScaled = false
	npcNameLabel.TextSize = 26
	npcNameLabel.Font = Enum.Font.GothamBold
	npcNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	npcNameLabel.Parent = dialogueWindow

	-- 会話テキスト
	local dialogueText = Instance.new("TextLabel")
	dialogueText.Name = "DialogueText"
	dialogueText.Size = UDim2.new(1, -20, 0, 100)
	dialogueText.Position = UDim2.new(0, 10, 0, 55)
	dialogueText.BackgroundTransparency = 1
	dialogueText.TextColor3 = Color3.fromRGB(255, 255, 255)
	dialogueText.TextScaled = false
	dialogueText.TextSize = 24
	dialogueText.Font = Enum.Font.Gotham
	dialogueText.TextWrapped = true
	dialogueText.TextXAlignment = Enum.TextXAlignment.Left
	dialogueText.TextYAlignment = Enum.TextYAlignment.Top
	dialogueText.Parent = dialogueWindow

	-- ★ 選択肢コンテナ【グリッドレイアウト対応】
	local choicesContainer = Instance.new("Frame")
	choicesContainer.Name = "ChoicesContainer"
	choicesContainer.Size = UDim2.new(1, -20, 0, 120) -- 高さ増加（2行対応）
	choicesContainer.Position = UDim2.new(0, 10, 0, 160)
	choicesContainer.BackgroundTransparency = 1
	choicesContainer.Parent = dialogueWindow

	-- ★ UIGridLayout【2列グリッド】
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8) -- セル間のパディング
	gridLayout.CellSize = UDim2.new(0.5, -4, 0, 45) -- 1行の高さ45px、1行に2つ
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.Parent = choicesContainer

	choicesContainer.ClipsDescendants = true

	return {
		screenGui = screenGui,
		background = background,
		dialogueWindow = dialogueWindow,
		npcNameLabel = npcNameLabel,
		dialogueText = dialogueText,
		choicesContainer = choicesContainer,
		gridLayout = gridLayout,
	}
end

-- ============================================================================
-- 選択肢ボタンの作成【2列対応】
-- ============================================================================
local function createChoiceButton(choiceText, choiceIndex, npcId, nodeName, isSelected)
	local button = Instance.new("TextButton")
	button.Name = ("Choice_%d"):format(choiceIndex)

	-- グリッドレイアウトがサイズを管理するため、サイズ指定不要
	button.AutomaticSize = Enum.AutomaticSize.None

	-- ★ ハイライトカラーを青とグレーに変更
	if isSelected then
		-- 選択中: 青色
		button.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
	else
		-- 未選択: グレー
		button.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	end

	button.BorderColor3 = Color3.fromRGB(80, 150, 220)
	button.BorderSizePixel = 1
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = false
	button.TextSize = 24
	button.Font = Enum.Font.Gotham
	button.Text = choiceText

	-- ホバー効果
	button.MouseEnter:Connect(function()
		-- ホバー時は青色
		button.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
		currentDialogueState.selectedChoiceIndex = choiceIndex
		updateChoiceHighlight()
	end)

	button.MouseLeave:Connect(function()
		if currentDialogueState.selectedChoiceIndex == choiceIndex then
			button.BackgroundColor3 = Color3.fromRGB(0, 100, 200) -- 選択中は青
		else
			button.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- 未選択はグレー
		end
	end)

	button.MouseButton1Click:Connect(function()
		selectChoice(choiceIndex, npcId, nodeName)
	end)

	return button
end

-- ============================================================================
-- 選択肢のハイライト更新
-- ============================================================================
function updateChoiceHighlight()
	if not currentDialogueState.ui then
		return
	end

	local choicesContainer = currentDialogueState.ui.choicesContainer
	local choiceButtons = {}

	for _, child in ipairs(choicesContainer:GetChildren()) do
		if child:IsA("TextButton") then
			table.insert(choiceButtons, child)
		end
	end

	for i, button in ipairs(choiceButtons) do
		if i == currentDialogueState.selectedChoiceIndex then
			-- ★ 選択中: 青色
			button.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
		else
			-- 未選択: グレー
			button.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		end
	end
end

-- ============================================================================
-- 選択肢を選択
-- ============================================================================
function selectChoice(choiceIndex, npcId, nodeName)
	if not currentDialogueState.dialogueTree then
		return
	end

	local node = currentDialogueState.dialogueTree[nodeName]
	if not node or not node.choices or not node.choices[choiceIndex] then
		return
	end

	local choice = node.choices[choiceIndex]
	ChoiceSelectedRemote:FireServer(npcId, nodeName, choiceIndex)
end

-- ============================================================================
-- 会話内容を表示
-- ============================================================================
local function displayNode(ui, npcName, nodeName, node)
	if not node then
		return
	end

	ui.npcNameLabel.Text = npcName

	local dialogueText = node.text
	if type(dialogueText) == "table" then
		dialogueText = dialogueText.ja or dialogueText.en or "[テキストなし]"
	end

	ui.dialogueText.Text = tostring(dialogueText)

	-- 古い選択肢を削除
	for _, child in ipairs(ui.choicesContainer:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	currentDialogueState.selectedChoiceIndex = 1

	if node.choices and #node.choices > 0 then
		for choiceIndex, choice in ipairs(node.choices) do
			local choiceText = choice.text
			if type(choiceText) == "table" then
				choiceText = choiceText.ja or choiceText.en or "[選択肢なし]"
			end

			local isSelected = (choiceIndex == currentDialogueState.selectedChoiceIndex)
			local button = createChoiceButton(choiceText, choiceIndex, currentDialogueState.npcId, nodeName, isSelected)
			button.Parent = ui.choicesContainer
		end
	else
		-- 選択肢がない場合は自動閉鎖
		task.wait(0.3) -- ★ 1.5秒 → 0.3秒に短縮
		DialogueUI.CloseDialogue()
	end
end

-- ============================================================================
-- 会話UI開く
-- ============================================================================
function DialogueUI.ShowDialogue(dialogueData)
	if currentDialogueState.isOpen then
		return
	end

	-- UI作成
	local ui = createDialogueUI()

	-- 状態を保存
	currentDialogueState.isOpen = true
	currentDialogueState.npcId = dialogueData.npcId
	currentDialogueState.npcName = dialogueData.npcName
	currentDialogueState.dialogueTree = dialogueData.dialogueTree or dialogueData.node
	currentDialogueState.currentNode = dialogueData.currentNode or "greeting"
	currentDialogueState.ui = ui

	-- ★ プレイヤーをフリーズ
	freezePlayer()

	-- ★ 対話中のNPCモデルを取得してフリーズ
	if dialogueData.npcModel then
		freezeNPC(dialogueData.npcModel)
	end

	-- ノード表示
	local startNode = dialogueData.node or dialogueData.dialogueTree[currentDialogueState.currentNode]
	if startNode then
		displayNode(ui, dialogueData.npcName, currentDialogueState.currentNode, startNode)
	end

	print(("[DialogueUI] 会話開始: %s（プレイヤー＆NPC フリーズ中）"):format(dialogueData.npcId))
end

-- ============================================================================
-- 会話更新（選択肢選択後）
-- ============================================================================
function DialogueUI.UpdateDialogue(dialogueData)
	if not currentDialogueState.isOpen or not currentDialogueState.ui then
		return
	end

	local ui = currentDialogueState.ui
	local npcName = dialogueData.npcName or currentDialogueState.npcName
	local nodeName = dialogueData.currentNode or currentDialogueState.currentNode
	local node = dialogueData.node
		or (currentDialogueState.dialogueTree and currentDialogueState.dialogueTree[nodeName])

	if node then
		displayNode(ui, npcName, nodeName, node)
		currentDialogueState.currentNode = nodeName
	end
end

-- ============================================================================
-- 会話UI閉じる
-- ============================================================================
function DialogueUI.CloseDialogue()
	if not currentDialogueState.isOpen or not currentDialogueState.ui then
		return
	end

	currentDialogueState.ui.screenGui:Destroy()

	-- フリーズを解除
	unfreezePlayer()
	unfreezeNPC()

	currentDialogueState.isOpen = false
	currentDialogueState.npcId = nil
	currentDialogueState.npcName = nil
	currentDialogueState.npcModel = nil
	currentDialogueState.dialogueTree = nil
	currentDialogueState.currentNode = "greeting"
	currentDialogueState.ui = nil
	currentDialogueState.selectedChoiceIndex = 1

	print("[DialogueUI] 会話を閉じました（フリーズ解除）")
end

-- ============================================================================
-- キーボード入力処理【矢印キーは選択のみ、Enter/Spaceで決定】
-- ============================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- ★ 【最優先処理】会話中の Space キーを Enter キーにマッピング
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
		if currentDialogueState.isOpen then
			print("[DialogueUI] [DEBUG] Space キーが Enter として機能（会話中）")

			local choicesContainer = currentDialogueState.ui.choicesContainer
			local choiceCount = 0

			for _, child in ipairs(choicesContainer:GetChildren()) do
				if child:IsA("TextButton") then
					choiceCount = choiceCount + 1
				end
			end

			if choiceCount > 0 and currentDialogueState.selectedChoiceIndex > 0 then
				print("[DialogueUI] [DEBUG] 選択肢を実行")
				selectChoice(
					currentDialogueState.selectedChoiceIndex,
					currentDialogueState.npcId,
					currentDialogueState.currentNode
				)
			end
			return -- ★ Space キーの入力を消費（ジャンプをブロック）
		end
	end

	if gameProcessed then
		return
	end

	if not currentDialogueState.isOpen then
		return
	end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		local keyCode = input.KeyCode

		-- Esc キーで会話終了
		if keyCode == Enum.KeyCode.Escape then
			print("[DialogueUI] [DEBUG] Esc キーで会話終了")
			DialogueUI.CloseDialogue()
			return
		end

		-- 矢印キー（↓）または S キー：次の選択肢（選択のみ）
		if keyCode == Enum.KeyCode.Down or keyCode == Enum.KeyCode.S then
			print("[DialogueUI] [DEBUG] ↓キーまたはSキー")
			if not currentDialogueState.ui then
				return
			end
			local choicesContainer = currentDialogueState.ui.choicesContainer
			local choiceCount = 0

			for _, child in ipairs(choicesContainer:GetChildren()) do
				if child:IsA("TextButton") then
					choiceCount = choiceCount + 1
				end
			end

			if choiceCount > 0 then
				currentDialogueState.selectedChoiceIndex =
					math.min(currentDialogueState.selectedChoiceIndex + 2, choiceCount)
				updateChoiceHighlight()
			end
			return
		end

		-- 矢印キー（↑）または W キー：前の選択肢（選択のみ）
		if keyCode == Enum.KeyCode.Up or keyCode == Enum.KeyCode.W then
			print("[DialogueUI] [DEBUG] ↑キーまたはWキー")
			if not currentDialogueState.ui then
				return
			end
			local choicesContainer = currentDialogueState.ui.choicesContainer
			local choiceCount = 0

			for _, child in ipairs(choicesContainer:GetChildren()) do
				if child:IsA("TextButton") then
					choiceCount = choiceCount + 1
				end
			end

			if choiceCount > 0 then
				currentDialogueState.selectedChoiceIndex = math.max(currentDialogueState.selectedChoiceIndex - 2, 1)
				updateChoiceHighlight()
			end
			return
		end

		-- 矢印キー（→）または D キー：右の選択肢（選択のみ）
		if keyCode == Enum.KeyCode.Right or keyCode == Enum.KeyCode.D then
			print("[DialogueUI] [DEBUG] →キーまたはDキー")
			if not currentDialogueState.ui then
				return
			end
			local choicesContainer = currentDialogueState.ui.choicesContainer
			local choiceCount = 0

			for _, child in ipairs(choicesContainer:GetChildren()) do
				if child:IsA("TextButton") then
					choiceCount = choiceCount + 1
				end
			end

			if choiceCount > 0 then
				local nextIndex = currentDialogueState.selectedChoiceIndex + 1
				if nextIndex % 2 == 0 and nextIndex <= choiceCount then
					currentDialogueState.selectedChoiceIndex = nextIndex
					updateChoiceHighlight()
				end
			end
			return
		end

		-- 矢印キー（←）または A キー：左の選択肢（選択のみ）
		if keyCode == Enum.KeyCode.Left or keyCode == Enum.KeyCode.A then
			print("[DialogueUI] [DEBUG] ←キーまたはAキー")
			if not currentDialogueState.ui then
				return
			end
			local choicesContainer = currentDialogueState.ui.choicesContainer
			local choiceCount = 0

			for _, child in ipairs(choicesContainer:GetChildren()) do
				if child:IsA("TextButton") then
					choiceCount = choiceCount + 1
				end
			end

			if choiceCount > 0 then
				local nextIndex = currentDialogueState.selectedChoiceIndex - 1
				if nextIndex % 2 == 1 and nextIndex >= 1 then
					currentDialogueState.selectedChoiceIndex = nextIndex
					updateChoiceHighlight()
				end
			end
			return
		end

		-- ★ Enter/Return キーで決定【重要】
		if keyCode == Enum.KeyCode.Return then
			print("[DialogueUI] [DEBUG] Enter キー入力")

			local choicesContainer = currentDialogueState.ui.choicesContainer
			local choiceCount = 0

			for _, child in ipairs(choicesContainer:GetChildren()) do
				if child:IsA("TextButton") then
					choiceCount = choiceCount + 1
				end
			end

			print(
				("[DialogueUI] [DEBUG] Enter: 選択肢数=%d, インデックス=%d"):format(
					choiceCount,
					currentDialogueState.selectedChoiceIndex
				)
			)

			if choiceCount > 0 and currentDialogueState.selectedChoiceIndex > 0 then
				print("[DialogueUI] [DEBUG] 選択肢を実行")
				-- ★ selectChoice 関数を直接呼び出す
				selectChoice(
					currentDialogueState.selectedChoiceIndex,
					currentDialogueState.npcId,
					currentDialogueState.currentNode
				)
			else
				print("[DialogueUI] [DEBUG] 選択肢が見つかりません")
			end
			return
		end

		-- ★ 数値キー（1-9）で選択肢を選択のみ
		local numberKeys = {
			Enum.KeyCode.One,
			Enum.KeyCode.Two,
			Enum.KeyCode.Three,
			Enum.KeyCode.Four,
			Enum.KeyCode.Five,
			Enum.KeyCode.Six,
			Enum.KeyCode.Seven,
			Enum.KeyCode.Eight,
			Enum.KeyCode.Nine,
		}

		for i, numberKey in ipairs(numberKeys) do
			if keyCode == numberKey then
				print(("[DialogueUI] [DEBUG] 数字キー %d"):format(i))
				if not currentDialogueState.ui then
					return
				end
				local choicesContainer = currentDialogueState.ui.choicesContainer
				local choiceButtons = {}

				for _, child in ipairs(choicesContainer:GetChildren()) do
					if child:IsA("TextButton") then
						table.insert(choiceButtons, child)
					end
				end

				if choiceButtons[i] then
					currentDialogueState.selectedChoiceIndex = i
					updateChoiceHighlight()
					print(("[DialogueUI] [DEBUG] 選択肢 %d を選択状態に"):format(i))
				end
				return
			end
		end
	end
end)

-- ============================================================================
-- RemoteEvent リスナー
-- ============================================================================
StartDialogueRemote.OnClientEvent:Connect(function(dialogueData)
	if dialogueData.node then
		DialogueUI.UpdateDialogue(dialogueData)
	else
		DialogueUI.ShowDialogue(dialogueData)
	end
end)

DialogueEndRemote.OnClientEvent:Connect(function()
	DialogueUI.CloseDialogue()
end)

print("[DialogueUI] === 初期化完了（グリッド + 数字入力 + NPC停止版）===")

return DialogueUI
