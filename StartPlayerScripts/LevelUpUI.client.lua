-- LevelUpUI.client.lua
-- 右上下部に表示されるレベルアップ演出（濃いグレー背景＋整列テキスト＋レベル表示中央寄せ）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local levelUpGui

print("[LevelUpUI] 初期化中...")

local function showLevelUp(level, maxHP, speed, attack, defense)
	if levelUpGui then
		levelUpGui:Destroy()
	end

	levelUpGui = Instance.new("ScreenGui")
	levelUpGui.Name = "LevelUpUI"
	levelUpGui.ResetOnSpawn = false
	levelUpGui.IgnoreGuiInset = true
	levelUpGui.DisplayOrder = 20
	levelUpGui.Parent = playerGui

	-- === メインボックス ===
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 250, 0, 210)
	frame.Position = UDim2.new(1, -270, 0, 180) -- 📍【位置調整ポイント①】右上からの位置を変えたい場合ここ
	frame.BackgroundColor3 = Color3.fromRGB(45, 45, 55) -- 📍【色調整】背景の濃さを変える場合ここ
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	frame.ZIndex = 100
	frame.Parent = levelUpGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Transparency = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	-- === タイトル ===
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.Font = Enum.Font.GothamBlack
	title.Text = "LEVEL UP!"
	title.TextColor3 = Color3.fromRGB(255, 230, 100)
	title.TextStrokeTransparency = 0.4
	title.TextScaled = true
	title.ZIndex = 101
	title.Parent = frame
	title.TextTransparency = 1

	-- === レベル番号 ===
	local levelText = Instance.new("TextLabel")
	levelText.BackgroundTransparency = 1
	levelText.Size = UDim2.new(1, -20, 0, 25)
	levelText.Position = UDim2.new(0, 15, 0, 50)
	levelText.Font = Enum.Font.GothamBold
	levelText.Text = ("Level %d"):format(level)
	levelText.TextColor3 = Color3.fromRGB(255, 240, 200)
	levelText.TextStrokeTransparency = 0.5
	levelText.TextScaled = false
	levelText.TextSize = 26
	levelText.ZIndex = 101
	levelText.Parent = frame
	levelText.TextTransparency = 1
	levelText.TextXAlignment = Enum.TextXAlignment.Center -- ✅ 中央寄せに変更

	-- === ステータス詳細 ===
	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.Size = UDim2.new(1, -40, 0, 130)
	info.Position = UDim2.new(0, 60, 0, 100) -- 📍【位置調整ポイント②】ステータス群の上下位置・左余白を調整したい場合ここ
	info.Font = Enum.Font.Code
	info.TextSize = 22
	info.TextColor3 = Color3.fromRGB(255, 255, 255)
	info.TextStrokeTransparency = 0.7
	info.TextYAlignment = Enum.TextYAlignment.Top
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.ZIndex = 101

	info.Text = string.format(
		"%-8s %6d\n%-8s %6d\n%-8s %6d\n%-8s %6d",
		"体力",
		maxHP,
		"攻撃力",
		attack,
		"守備力",
		defense,
		"素早さ",
		speed
	)
	info.Parent = frame
	info.TextTransparency = 1

	-- === グロー光 ===
	local glow = Instance.new("ImageLabel")
	glow.BackgroundTransparency = 1
	glow.Image = "rbxassetid://10957087634"
	glow.ImageColor3 = Color3.fromRGB(255, 255, 200)
	glow.Size = UDim2.new(1.2, 0, 1.2, 0)
	glow.Position = UDim2.new(-0.1, 0, -0.1, 0)
	glow.ZIndex = 99
	glow.Parent = frame
	glow.ImageTransparency = 1

	-- === フェードイン ===
	local tweenIn = TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 0 })
	local tweenStroke = TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 0 })
	local tweenTitle = TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 0 })
	local tweenLevel = TweenService:Create(levelText, TweenInfo.new(0.4), { TextTransparency = 0 })
	local tweenInfo = TweenService:Create(info, TweenInfo.new(0.8), { TextTransparency = 0 })
	local tweenGlow = TweenService:Create(glow, TweenInfo.new(1.0), { ImageTransparency = 0.4 })

	tweenIn:Play()
	tweenStroke:Play()
	tweenTitle:Play()
	tweenLevel:Play()
	tweenInfo:Play()
	tweenGlow:Play()

	task.wait(3.5)

	-- === フェードアウト ===
	local tweenOut = TweenService:Create(frame, TweenInfo.new(0.8), { BackgroundTransparency = 1 })
	local tweenOutStroke = TweenService:Create(stroke, TweenInfo.new(0.8), { Transparency = 1 })
	local tweenOutTitle = TweenService:Create(title, TweenInfo.new(0.8), { TextTransparency = 1 })
	local tweenOutLevel = TweenService:Create(levelText, TweenInfo.new(0.8), { TextTransparency = 1 })
	local tweenOutInfo = TweenService:Create(info, TweenInfo.new(0.8), { TextTransparency = 1 })
	local tweenOutGlow = TweenService:Create(glow, TweenInfo.new(0.8), { ImageTransparency = 1 })

	tweenOut:Play()
	tweenOutStroke:Play()
	tweenOutTitle:Play()
	tweenOutLevel:Play()
	tweenOutInfo:Play()
	tweenOutGlow:Play()

	task.wait(1)
	levelUpGui:Destroy()
end

-- イベント接続
local LevelUpEvent = ReplicatedStorage:WaitForChild("LevelUp", 10)
if LevelUpEvent then
	LevelUpEvent.OnClientEvent:Connect(showLevelUp)
	print("[LevelUpUI] LevelUpイベント接続完了")
else
	warn("[LevelUpUI] LevelUpイベントが見つかりません")
end

print("[LevelUpUI] 初期化完了")
