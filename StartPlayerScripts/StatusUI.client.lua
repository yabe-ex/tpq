-- StarterPlayer/StarterPlayerScripts/StatusUI.client.lua
-- 画面左下に常時表示するプレイヤーステータス

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[StatusUI] 初期化中...")

-- 現在のステータス
local currentHP = 100
local currentMaxHP = 100
local currentLevel = 1
local currentExp = 0
local currentExpToNext = 100
local currentGold = 0

-- UI要素
local statusGui = nil
local hpBarBackground = nil
local hpBarFill = nil
local hpLabel = nil
local levelLabel = nil
local expLabel = nil
local goldLabel = nil

-- HPの色を取得
local function getHPColor(hpPercent)
	if hpPercent > 0.6 then
		return Color3.fromRGB(46, 204, 113)  -- 緑
	elseif hpPercent > 0.3 then
		return Color3.fromRGB(241, 196, 15)  -- 黄色
	else
		return Color3.fromRGB(231, 76, 60)  -- 赤
	end
end

-- 表示を更新
local function updateDisplay()
	if hpBarFill and hpLabel then
		local hpPercent = currentHP / currentMaxHP

		-- バーの長さをアニメーション
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(hpBarFill, tweenInfo, {
			Size = UDim2.new(hpPercent, 0, 1, 0)
		})
		tween:Play()

		-- 色を変更
		hpBarFill.BackgroundColor3 = getHPColor(hpPercent)

		-- テキスト更新
		hpLabel.Text = string.format("%d / %d", currentHP, currentMaxHP)
	end

	if levelLabel then
		levelLabel.Text = string.format("Lv.%d", currentLevel)
	end

	if expLabel then
		expLabel.Text = string.format("EXP: %d / %d", currentExp, currentExpToNext)
	end

	if goldLabel then
		goldLabel.Text = string.format("💰 %d G", currentGold)
	end
end

-- UI作成
local function createStatusUI()
	statusGui = Instance.new("ScreenGui")
	statusGui.Name = "StatusUI"
	statusGui.ResetOnSpawn = false
	statusGui.Parent = playerGui

	-- 背景フレーム
	local backgroundFrame = Instance.new("Frame")
	backgroundFrame.Name = "StatusBackground"
	backgroundFrame.Size = UDim2.new(0, 250, 0, 120)
	backgroundFrame.Position = UDim2.new(1, -270, 1, -140)
	backgroundFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	backgroundFrame.BackgroundTransparency = 0.3
	backgroundFrame.BorderSizePixel = 0
	backgroundFrame.Parent = statusGui

	-- 角を丸くする
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = backgroundFrame

	-- レベル表示
	levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0, 80, 0, 25)
	levelLabel.Position = UDim2.new(0, 10, 0, 10)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	levelLabel.TextStrokeTransparency = 0.5
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextSize = 20
	levelLabel.Text = "Lv.1"
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = backgroundFrame

	-- HPバー背景
	hpBarBackground = Instance.new("Frame")
	hpBarBackground.Name = "HPBarBackground"
	hpBarBackground.Size = UDim2.new(1, -20, 0, 20)
	hpBarBackground.Position = UDim2.new(0, 10, 0, 40)
	hpBarBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	hpBarBackground.BorderSizePixel = 0
	hpBarBackground.Parent = backgroundFrame

	-- HPバー背景の角を丸くする
	local hpBarCorner = Instance.new("UICorner")
	hpBarCorner.CornerRadius = UDim.new(0, 5)
	hpBarCorner.Parent = hpBarBackground

	-- HPバー（塗りつぶし）
	hpBarFill = Instance.new("Frame")
	hpBarFill.Name = "HPBarFill"
	hpBarFill.Size = UDim2.new(1, 0, 1, 0)
	hpBarFill.Position = UDim2.new(0, 0, 0, 0)
	hpBarFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	hpBarFill.BorderSizePixel = 0
	hpBarFill.Parent = hpBarBackground

	-- HPバーの角を丸くする
	local hpFillCorner = Instance.new("UICorner")
	hpFillCorner.CornerRadius = UDim.new(0, 5)
	hpFillCorner.Parent = hpBarFill

	-- HPテキスト
	hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HPLabel"
	hpLabel.Size = UDim2.new(1, 0, 1, 0)
	hpLabel.Position = UDim2.new(0, 0, 0, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextStrokeTransparency = 0.5
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextSize = 14
	hpLabel.Text = "100 / 100"
	hpLabel.Parent = hpBarBackground

	-- 経験値表示
	expLabel = Instance.new("TextLabel")
	expLabel.Name = "ExpLabel"
	expLabel.Size = UDim2.new(1, -20, 0, 18)
	expLabel.Position = UDim2.new(0, 10, 0, 65)
	expLabel.BackgroundTransparency = 1
	expLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	expLabel.TextStrokeTransparency = 0.7
	expLabel.Font = Enum.Font.Gotham
	expLabel.TextSize = 14
	expLabel.Text = "EXP: 0 / 100"
	expLabel.TextXAlignment = Enum.TextXAlignment.Left
	expLabel.Parent = backgroundFrame

	-- ゴールド表示
	goldLabel = Instance.new("TextLabel")
	goldLabel.Name = "GoldLabel"
	goldLabel.Size = UDim2.new(1, -20, 0, 18)
	goldLabel.Position = UDim2.new(0, 10, 0, 88)
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	goldLabel.TextStrokeTransparency = 0.7
	goldLabel.Font = Enum.Font.GothamBold
	goldLabel.TextSize = 14
	goldLabel.Text = "💰 0 G"
	goldLabel.TextXAlignment = Enum.TextXAlignment.Left
	goldLabel.Parent = backgroundFrame

	print("[StatusUI] UI作成完了")
end

-- ステータス更新イベント
local function onStatusUpdate(hp, maxHP, level, exp, expToNext, gold)
	print(("[StatusUI] ステータス更新受信: HP=%d/%d, Lv=%d, EXP=%d/%d, Gold=%d"):format(
		hp or 0, maxHP or 0, level or 0, exp or 0, expToNext or 0, gold or 0
		))

	currentHP = hp or currentHP
	currentMaxHP = maxHP or currentMaxHP
	currentLevel = level or currentLevel
	currentExp = exp or currentExp
	currentExpToNext = expToNext or currentExpToNext
	currentGold = gold or currentGold

	updateDisplay()
end

-- 初期化
createStatusUI()

print("[StatusUI] RemoteEventを待機中...")

-- RemoteEventを待機（最大30秒）
task.spawn(function()
	local StatusUpdateEvent = ReplicatedStorage:WaitForChild("StatusUpdate", 10)
	if StatusUpdateEvent then
		StatusUpdateEvent.OnClientEvent:Connect(onStatusUpdate)
		print("[StatusUI] StatusUpdateイベント接続完了")

		-- 初回のステータス要求
		task.wait(1)  -- 1秒待ってから要求
		local RequestStatusEvent = ReplicatedStorage:FindFirstChild("RequestStatus")
		if RequestStatusEvent then
			print("[StatusUI] 初回ステータスを要求")
			RequestStatusEvent:FireServer()
		else
			warn("[StatusUI] RequestStatusイベントが見つかりません")
		end
	else
		warn("[StatusUI] StatusUpdateイベントの待機がタイムアウトしました")
	end
end)

print("[StatusUI] 初期化完了")