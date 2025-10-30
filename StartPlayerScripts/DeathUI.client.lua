-- StarterPlayer/StarterPlayerScripts/DeathUI.client.lua
-- 死亡時の選択UI（街に戻る / ゴールドロストで復活）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[DeathUI] 初期化中...")

-- UI要素
local deathGui = nil

-- 死亡UIを表示
local function showDeathUI(currentGold, reviveCost)
	print(("[DeathUI] ========================================"):format())
	print(("[DeathUI] 死亡UI表示"):format())
	print(("[DeathUI] 所持金: %d G, 復活コスト: %d G"):format(currentGold, reviveCost))
	print(("[DeathUI] ========================================"):format())

	-- 既存のGUIを削除
	if deathGui then
		deathGui:Destroy()
	end

	-- 新しいGUIを作成
	deathGui = Instance.new("ScreenGui")
	deathGui.Name = "DeathUI"
	deathGui.ResetOnSpawn = false
	deathGui.Parent = playerGui

	-- 背景（暗い）
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.Position = UDim2.fromScale(0, 0)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 0.3
	background.BorderSizePixel = 0
	background.ZIndex = 200
	background.Parent = deathGui

	-- タイトル
	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(0, 600, 0, 80)
	titleText.Position = UDim2.new(0.5, -300, 0.3, 0)
	titleText.BackgroundTransparency = 1
	titleText.TextColor3 = Color3.fromRGB(255, 100, 100)
	titleText.TextStrokeTransparency = 0
	titleText.Font = Enum.Font.GothamBold
	titleText.TextSize = 50
	titleText.Text = "YOU DIED"
	titleText.ZIndex = 201
	titleText.Parent = deathGui

	-- 選択フレーム
	local choiceFrame = Instance.new("Frame")
	choiceFrame.Size = UDim2.new(0, 600, 0, 200)
	choiceFrame.Position = UDim2.new(0.5, -300, 0.45, 0)
	choiceFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	choiceFrame.BackgroundTransparency = 0.2
	choiceFrame.BorderSizePixel = 0
	choiceFrame.ZIndex = 201
	choiceFrame.Parent = deathGui

	-- 角を丸くする
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = choiceFrame

	-- 説明テキスト
	local descText = Instance.new("TextLabel")
	descText.Size = UDim2.new(1, -40, 0, 60)
	descText.Position = UDim2.new(0, 20, 0, 20)
	descText.BackgroundTransparency = 1
	descText.TextColor3 = Color3.fromRGB(255, 255, 255)
	descText.TextStrokeTransparency = 0.5
	descText.Font = Enum.Font.Gotham
	descText.TextSize = 18
	descText.Text = "敗北しました。どうしますか？"
	descText.TextWrapped = true
	descText.ZIndex = 202
	descText.Parent = choiceFrame

	-- 「街に戻る」ボタン
	local returnButton = Instance.new("TextButton")
	returnButton.Size = UDim2.new(0, 250, 0, 50)
	returnButton.Position = UDim2.new(0.5, -260, 0, 100)
	returnButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
	returnButton.BorderSizePixel = 0
	returnButton.Font = Enum.Font.GothamBold
	returnButton.TextSize = 20
	returnButton.Text = "🏠 街に戻る"
	returnButton.TextColor3 = Color3.new(1, 1, 1)
	returnButton.ZIndex = 202
	returnButton.Parent = choiceFrame

	-- ボタンの角を丸くする
	local returnCorner = Instance.new("UICorner")
	returnCorner.CornerRadius = UDim.new(0, 8)
	returnCorner.Parent = returnButton

	-- 「ゴールドで復活」ボタン
	local reviveButton = Instance.new("TextButton")
	reviveButton.Size = UDim2.new(0, 250, 0, 50)
	reviveButton.Position = UDim2.new(0.5, 10, 0, 100)
	reviveButton.BorderSizePixel = 0
	reviveButton.Font = Enum.Font.GothamBold
	reviveButton.TextSize = 20
	reviveButton.TextColor3 = Color3.new(1, 1, 1)
	reviveButton.ZIndex = 202
	reviveButton.Parent = choiceFrame

	-- ボタンの角を丸くする
	local reviveCorner = Instance.new("UICorner")
	reviveCorner.CornerRadius = UDim.new(0, 8)
	reviveCorner.Parent = reviveButton

	-- ゴールドが足りるかチェック
	if currentGold >= reviveCost then
		reviveButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
		reviveButton.Text = string.format("💰 復活 (%d G)", reviveCost)
	else
		reviveButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		reviveButton.Text = string.format("💰 復活 (%d G) - 不足", reviveCost)
		reviveButton.Active = false
	end

	-- ボタンのホバーエフェクト
	returnButton.MouseEnter:Connect(function()
		returnButton.BackgroundColor3 = Color3.fromRGB(62, 172, 239)
	end)
	returnButton.MouseLeave:Connect(function()
		returnButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
	end)

	if currentGold >= reviveCost then
		reviveButton.MouseEnter:Connect(function()
			reviveButton.BackgroundColor3 = Color3.fromRGB(56, 224, 133)
		end)
		reviveButton.MouseLeave:Connect(function()
			reviveButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
		end)
	end

	-- 「街に戻る」ボタンクリック
	returnButton.MouseButton1Click:Connect(function()
		print("[DeathUI] 街に戻るを選択")

		-- サーバーに通知
		local DeathChoiceEvent = ReplicatedStorage:FindFirstChild("DeathChoice")
		if DeathChoiceEvent then
			DeathChoiceEvent:FireServer("return")
		end

		-- バトルUIを閉じる
		local battleUI = playerGui:FindFirstChild("BattleUI")
		if battleUI then
			battleUI.Enabled = false
		end

		-- システムキーのブロックを解除
		local ContextActionService = game:GetService("ContextActionService")
		ContextActionService:UnbindAction("BlockSystemKeys")

		-- Roblox UIを再有効化
		local StarterGui = game:GetService("StarterGui")
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
		end)

		-- UIを閉じる
		if deathGui then
			deathGui:Destroy()
			deathGui = nil
		end
	end)

	-- 「ゴールドで復活」ボタンクリック
	reviveButton.MouseButton1Click:Connect(function()
		if currentGold < reviveCost then
			print("[DeathUI] ゴールド不足")
			return
		end

		print("[DeathUI] ゴールドで復活を選択")

		-- サーバーに通知
		local DeathChoiceEvent = ReplicatedStorage:FindFirstChild("DeathChoice")
		if DeathChoiceEvent then
			DeathChoiceEvent:FireServer("revive")
		end

		-- バトルUIを閉じる
		local battleUI = playerGui:FindFirstChild("BattleUI")
		if battleUI then
			battleUI.Enabled = false
		end

		-- システムキーのブロックを解除
		local ContextActionService = game:GetService("ContextActionService")
		ContextActionService:UnbindAction("BlockSystemKeys")

		-- Roblox UIを再有効化
		local StarterGui = game:GetService("StarterGui")
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
		end)

		-- UIを閉じる
		if deathGui then
			deathGui:Destroy()
			deathGui = nil
		end
	end)
end

-- RemoteEventを待機
local ShowDeathUIEvent = ReplicatedStorage:WaitForChild("ShowDeathUI", 10)
if ShowDeathUIEvent then
	ShowDeathUIEvent.OnClientEvent:Connect(showDeathUI)
	print("[DeathUI] ShowDeathUIイベント接続完了")
else
	warn("[DeathUI] ShowDeathUIイベントが見つかりません")
end

print("[DeathUI] 初期化完了")