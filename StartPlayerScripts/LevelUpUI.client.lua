-- StarterPlayer/StarterPlayerScripts/LevelUpUI.client.lua
-- レベルアップ演出

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[LevelUpUI] 初期化中...")

-- UI要素
local levelUpGui = nil

-- レベルアップ演出を表示
local function showLevelUp(level, maxHP, speed, attack, defense)
	print(("[LevelUpUI] ========================================"):format())
	print(("[LevelUpUI] レベルアップ演出開始！"):format())
	print(("[LevelUpUI] Lv.%d, HP:%d, 素早さ:%d, 攻撃:%d, 守備:%d"):format(
		level, maxHP, speed, attack, defense
		))
	print(("[LevelUpUI] ========================================"):format())

	-- 既存のGUIを削除
	if levelUpGui then
		levelUpGui:Destroy()
	end

	-- 新しいGUIを作成
	levelUpGui = Instance.new("ScreenGui")
	levelUpGui.Name = "LevelUpUI"
	levelUpGui.ResetOnSpawn = false
	levelUpGui.Parent = playerGui

	-- 背景（暗い）
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.Position = UDim2.fromScale(0, 0)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.ZIndex = 100
	background.Parent = levelUpGui

	-- 背景を暗くする
	local bgTween = TweenService:Create(background, TweenInfo.new(0.3), {
		BackgroundTransparency = 0.5
	})
	bgTween:Play()

	-- レベルアップテキスト
	local levelUpText = Instance.new("TextLabel")
	levelUpText.Size = UDim2.new(0, 600, 0, 100)
	levelUpText.Position = UDim2.new(0.5, -300, 0.35, -50)
	levelUpText.BackgroundTransparency = 1
	levelUpText.TextColor3 = Color3.fromRGB(255, 215, 0)
	levelUpText.TextStrokeTransparency = 0
	levelUpText.TextStrokeColor3 = Color3.new(0, 0, 0)
	levelUpText.Font = Enum.Font.GothamBold
	levelUpText.TextSize = 60
	levelUpText.Text = "LEVEL UP!"
	levelUpText.TextTransparency = 1
	levelUpText.ZIndex = 101
	levelUpText.Parent = levelUpGui

	-- テキストをフェードイン
	local textTween = TweenService:Create(levelUpText, TweenInfo.new(0.5), {
		TextTransparency = 0,
		TextStrokeTransparency = 0
	})
	textTween:Play()

	-- レベル表示
	local levelText = Instance.new("TextLabel")
	levelText.Size = UDim2.new(0, 600, 0, 60)
	levelText.Position = UDim2.new(0.5, -300, 0.45, 0)
	levelText.BackgroundTransparency = 1
	levelText.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelText.TextStrokeTransparency = 0
	levelText.Font = Enum.Font.GothamBold
	levelText.TextSize = 40
	levelText.Text = string.format("Level %d", level)
	levelText.TextTransparency = 1
	levelText.ZIndex = 101
	levelText.Parent = levelUpGui

	-- レベルテキストをフェードイン
	local levelTextTween = TweenService:Create(levelText, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.2), {
		TextTransparency = 0,
		TextStrokeTransparency = 0.5
	})
	levelTextTween:Play()

	-- ステータス表示フレーム
	local statsFrame = Instance.new("Frame")
	statsFrame.Size = UDim2.new(0, 400, 0, 150)
	statsFrame.Position = UDim2.new(0.5, -200, 0.55, 0)
	statsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	statsFrame.BackgroundTransparency = 1
	statsFrame.BorderSizePixel = 0
	statsFrame.ZIndex = 101
	statsFrame.Parent = levelUpGui

	-- 角を丸くする
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = statsFrame

	-- フレームをフェードイン
	local frameTween = TweenService:Create(statsFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.3), {
		BackgroundTransparency = 0.2
	})
	frameTween:Play()

	-- ステータステキスト
	local statsText = Instance.new("TextLabel")
	statsText.Size = UDim2.new(1, -40, 1, -40)
	statsText.Position = UDim2.new(0, 20, 0, 20)
	statsText.BackgroundTransparency = 1
	statsText.TextColor3 = Color3.fromRGB(200, 255, 200)
	statsText.TextStrokeTransparency = 0.5
	statsText.Font = Enum.Font.Gotham
	statsText.TextSize = 20

	local hpPlus   = (deltas and deltas.hp) or 10
    local spdPlus  = (deltas and deltas.speed) or 2
    local atkPlus  = (deltas and deltas.attack) or 2
    local defPlus  = (deltas and deltas.defense) or 2

    statsText.Text = string.format(
        "HP: %d (+%d)\n素早さ: %d (+%d)\n攻撃力: %d (+%d)\n守備力: %d (+%d)",
        maxHP, hpPlus,
        speed, spdPlus,
        attack, atkPlus,
        defense, defPlus
    )

	statsText.TextTransparency = 1
	statsText.TextYAlignment = Enum.TextYAlignment.Top
	statsText.ZIndex = 102
	statsText.Parent = statsFrame

	-- ステータステキストをフェードイン
	local statsTween = TweenService:Create(statsText, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.4), {
		TextTransparency = 0,
		TextStrokeTransparency = 0.5
	})
	statsTween:Play()

	-- 2.5秒後にフェードアウト
	task.delay(2.5, function()
		local fadeOutTween = TweenService:Create(background, TweenInfo.new(0.5), {
			BackgroundTransparency = 1
		})
		fadeOutTween:Play()

		TweenService:Create(levelUpText, TweenInfo.new(0.5), {
			TextTransparency = 1,
			TextStrokeTransparency = 1
		}):Play()

		TweenService:Create(levelText, TweenInfo.new(0.5), {
			TextTransparency = 1,
			TextStrokeTransparency = 1
		}):Play()

		TweenService:Create(statsFrame, TweenInfo.new(0.5), {
			BackgroundTransparency = 1
		}):Play()

		TweenService:Create(statsText, TweenInfo.new(0.5), {
			TextTransparency = 1,
			TextStrokeTransparency = 1
		}):Play()

		-- 3秒後に削除
		task.wait(0.5)
		if levelUpGui then
			levelUpGui:Destroy()
			levelUpGui = nil
		end
	end)
end

-- RemoteEventを待機
local LevelUpEvent = ReplicatedStorage:WaitForChild("LevelUp", 10)
if LevelUpEvent then
	LevelUpEvent.OnClientEvent:Connect(showLevelUp)
	print("[LevelUpUI] LevelUpイベント接続完了")
else
	warn("[LevelUpUI] LevelUpイベントが見つかりません")
end

print("[LevelUpUI] 初期化完了")