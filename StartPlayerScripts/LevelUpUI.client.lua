-- LevelUpUI.client.lua
-- 右上下部に表示されるレベルアップ演出（濃いグレー背景＋整列テキスト＋レベル表示中央寄せ）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local levelUpGui

print("[LevelUpUI] 初期化中...")

-- local function showLevelUp(level, maxHP, speed, attack, defense)
-- 	if levelUpGui then
-- 		levelUpGui:Destroy()
-- 	end

-- 	levelUpGui = Instance.new("ScreenGui")
-- 	levelUpGui.Name = "LevelUpUI"
-- 	levelUpGui.ResetOnSpawn = false
-- 	levelUpGui.IgnoreGuiInset = true
-- 	levelUpGui.DisplayOrder = 20
-- 	levelUpGui.Parent = playerGui

-- 	-- === メインボックス ===
-- 	local frame = Instance.new("Frame")
-- 	frame.Size = UDim2.new(0, 600, 0, 210)
-- 	-- frame.Position = UDim2.new(1, -270, 0, 180) -- 📍【位置調整ポイント①】右上からの位置を変えたい場合ここ
-- 	frame.Position = UDim2.new(0.5, 0, 0.3, 0)
-- 	frame.AnchorPoint = Vector2.new(0.5, 0.5)
-- 	frame.BackgroundColor3 = Color3.fromRGB(45, 45, 55) -- 📍【色調整】背景の濃さを変える場合ここ
-- 	frame.BorderSizePixel = 0
-- 	frame.BackgroundTransparency = 1
-- 	frame.ZIndex = 100
-- 	frame.Parent = levelUpGui

-- 	local corner = Instance.new("UICorner")
-- 	corner.CornerRadius = UDim.new(0, 10)
-- 	corner.Parent = frame

-- 	local stroke = Instance.new("UIStroke")
-- 	stroke.Thickness = 4
-- 	stroke.Color = Color3.fromRGB(255, 215, 0)
-- 	stroke.Transparency = 1
-- 	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
-- 	stroke.Parent = frame

-- 	-- === タイトル ===
-- 	local title = Instance.new("TextLabel")
-- 	title.BackgroundTransparency = 1
-- 	title.Size = UDim2.new(1, -20, 0, 40)
-- 	title.Position = UDim2.new(0, 10, 0, 10)
-- 	title.Font = Enum.Font.GothamBlack
-- 	title.Text = "LEVEL UP!"
-- 	title.TextColor3 = Color3.fromRGB(255, 230, 100)
-- 	title.TextStrokeTransparency = 0.4
-- 	title.TextScaled = true
-- 	title.ZIndex = 101
-- 	title.Parent = frame
-- 	title.TextTransparency = 1

-- 	-- === レベル番号 ===
-- 	local levelText = Instance.new("TextLabel")
-- 	levelText.BackgroundTransparency = 1
-- 	levelText.Size = UDim2.new(1, -20, 0, 25)
-- 	levelText.Position = UDim2.new(0, 15, 0, 50)
-- 	levelText.Font = Enum.Font.GothamBold
-- 	levelText.Text = ("Level %d"):format(level)
-- 	levelText.TextColor3 = Color3.fromRGB(255, 240, 200)
-- 	levelText.TextStrokeTransparency = 0.5
-- 	levelText.TextScaled = false
-- 	levelText.TextSize = 26
-- 	levelText.ZIndex = 101
-- 	levelText.Parent = frame
-- 	levelText.TextTransparency = 1
-- 	levelText.TextXAlignment = Enum.TextXAlignment.Center -- ✅ 中央寄せに変更

-- 	-- === ステータス詳細 ===
-- 	local info = Instance.new("TextLabel")
-- 	info.BackgroundTransparency = 1
-- 	info.Size = UDim2.new(1, -40, 0, 130)
-- 	info.Position = UDim2.new(0, 60, 0, 100) -- 📍【位置調整ポイント②】ステータス群の上下位置・左余白を調整したい場合ここ
-- 	info.Font = Enum.Font.Code
-- 	info.TextSize = 22
-- 	info.TextColor3 = Color3.fromRGB(255, 255, 255)
-- 	info.TextStrokeTransparency = 0.7
-- 	info.TextYAlignment = Enum.TextYAlignment.Top
-- 	info.TextXAlignment = Enum.TextXAlignment.Left
-- 	info.ZIndex = 101

-- 	info.Text = string.format(
-- 		"%-8s %6d\n%-8s %6d\n%-8s %6d\n%-8s %6d",
-- 		"体力",
-- 		maxHP,
-- 		"攻撃力",
-- 		attack,
-- 		"守備力",
-- 		defense,
-- 		"素早さ",
-- 		speed
-- 	)
-- 	info.Parent = frame
-- 	info.TextTransparency = 1

-- 	-- === グロー光 ===
-- 	local glow = Instance.new("ImageLabel")
-- 	glow.BackgroundTransparency = 1
-- 	glow.Image = "rbxassetid://10957087634"
-- 	glow.ImageColor3 = Color3.fromRGB(255, 255, 200)
-- 	glow.Size = UDim2.new(1.2, 0, 1.2, 0)
-- 	glow.Position = UDim2.new(-0.1, 0, -0.1, 0)
-- 	glow.ZIndex = 99
-- 	glow.Parent = frame
-- 	glow.ImageTransparency = 1

-- 	-- === フェードイン ===
-- 	local tweenIn = TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 0 })
-- 	local tweenStroke = TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 0 })
-- 	local tweenTitle = TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 0 })
-- 	local tweenLevel = TweenService:Create(levelText, TweenInfo.new(0.4), { TextTransparency = 0 })
-- 	local tweenInfo = TweenService:Create(info, TweenInfo.new(0.8), { TextTransparency = 0 })
-- 	local tweenGlow = TweenService:Create(glow, TweenInfo.new(1.0), { ImageTransparency = 0.4 })

-- 	tweenIn:Play()
-- 	tweenStroke:Play()
-- 	tweenTitle:Play()
-- 	tweenLevel:Play()
-- 	tweenInfo:Play()
-- 	tweenGlow:Play()

-- 	task.wait(3.5)

-- 	-- === フェードアウト ===
-- 	local tweenOut = TweenService:Create(frame, TweenInfo.new(0.8), { BackgroundTransparency = 1 })
-- 	local tweenOutStroke = TweenService:Create(stroke, TweenInfo.new(0.8), { Transparency = 1 })
-- 	local tweenOutTitle = TweenService:Create(title, TweenInfo.new(0.8), { TextTransparency = 1 })
-- 	local tweenOutLevel = TweenService:Create(levelText, TweenInfo.new(0.8), { TextTransparency = 1 })
-- 	local tweenOutInfo = TweenService:Create(info, TweenInfo.new(0.8), { TextTransparency = 1 })
-- 	local tweenOutGlow = TweenService:Create(glow, TweenInfo.new(0.8), { ImageTransparency = 1 })

-- 	tweenOut:Play()
-- 	tweenOutStroke:Play()
-- 	tweenOutTitle:Play()
-- 	tweenOutLevel:Play()
-- 	tweenOutInfo:Play()
-- 	tweenOutGlow:Play()

-- 	task.wait(1)
-- 	levelUpGui:Destroy()
-- end

local function num(v)
	if typeof(v) == "table" then
		return v.Value or 0
	elseif typeof(v) == "number" then
		return v
	else
		return 0
	end
end

local function showLevelUp(level, maxHP, speed, attack, defense, oldHP, oldSpeed, oldAttack, oldDefense)
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
	frame.Size = UDim2.new(0, 540, 0, 300)
	frame.Position = UDim2.new(0.5, 0, 0.4, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	frame.ZIndex = 100
	frame.Parent = levelUpGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Transparency = 1
	stroke.Parent = frame

	-- === タイトル ===
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.Font = Enum.Font.GothamBlack
	title.Text = "LEVEL UP!"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextStrokeTransparency = 0.4
	title.TextScaled = true
	title.ZIndex = 101
	title.TextTransparency = 1
	title.Parent = frame

	-- === レベル番号 ===
	local levelText = Instance.new("TextLabel")
	levelText.BackgroundTransparency = 1
	levelText.Size = UDim2.new(1, 0, 0, 25)
	levelText.Position = UDim2.new(0, 0, 0, 60)
	levelText.Font = Enum.Font.GothamBold
	levelText.Text = ("Level %d"):format(level)
	levelText.TextColor3 = Color3.fromRGB(255, 240, 200)
	levelText.TextStrokeTransparency = 0.5
	levelText.TextSize = 26
	levelText.ZIndex = 101
	levelText.TextTransparency = 1
	levelText.TextXAlignment = Enum.TextXAlignment.Center
	levelText.Parent = frame

	-- === ステータス群 ===
	local stats = {
		{ "体力", num(oldHP), num(maxHP) - num(oldHP), num(maxHP) },
		{ "攻撃力", num(oldAttack), num(attack) - num(oldAttack), num(attack) },
		{ "守備力", num(oldDefense), num(defense) - num(oldDefense), num(defense) },
		{ "素早さ", num(oldSpeed), num(speed) - num(oldSpeed), num(speed) },
	}

	for i, row in ipairs(stats) do
		local baseY = 110 + (i - 1) * 38
		for j = 1, 4 do
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamMedium
			label.TextScaled = true
			label.ZIndex = 101
			label.Size = UDim2.new(0, 100, 0, 32)
			label.Position = UDim2.new(0, 40 + (j - 1) * 110, 0, baseY)
			label.TextTransparency = 1

			if j == 1 then
				label.Text = row[1]
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.TextXAlignment = Enum.TextXAlignment.Right
			elseif j == 2 then
				label.Text = tostring(row[2])
				label.TextColor3 = Color3.fromRGB(200, 200, 200)
				label.TextXAlignment = Enum.TextXAlignment.Center
			elseif j == 3 then
				label.Text = string.format("%+d", row[3])
				label.TextColor3 = Color3.fromRGB(255, 215, 0)
				label.TextXAlignment = Enum.TextXAlignment.Center
			else
				label.Text = tostring(row[4])
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.TextXAlignment = Enum.TextXAlignment.Center
			end

			label.Parent = frame
			TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
		end
	end

	-- === グロー光 ===
	local glow = Instance.new("ImageLabel")
	glow.BackgroundTransparency = 1
	glow.Image = "rbxassetid://10957087634"
	glow.ImageColor3 = Color3.fromRGB(255, 255, 200)
	glow.Size = UDim2.new(1.3, 0, 1.3, 0)
	glow.Position = UDim2.new(-0.15, 0, -0.15, 0)
	glow.ZIndex = 99
	glow.ImageTransparency = 1
	glow.Parent = frame

	-- === フェードイン ===
	local fadeIn = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(frame, fadeIn, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(stroke, fadeIn, { Transparency = 0 }):Play()
	TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	TweenService:Create(levelText, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	TweenService:Create(glow, TweenInfo.new(1.0), { ImageTransparency = 0.4 }):Play()

	task.wait(2)

	-- === フェードアウト ===
	local fadeTextInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- 文字を先に
	local fadeBGInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- 背景は少し遅く

	-- 🔸 全ての文字（LEVEL UP!, レベル, ステータス）をフェードアウト
	for _, descendant in ipairs(frame:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			TweenService:Create(descendant, fadeTextInfo, { TextTransparency = 1 }):Play()
		end
	end

	-- 🔸 背景・枠・Glowは少し遅れて消す
	TweenService:Create(frame, fadeBGInfo, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(stroke, fadeBGInfo, { Transparency = 1 }):Play()
	TweenService:Create(glow, fadeBGInfo, { ImageTransparency = 1 }):Play()

	task.wait(0.9)
	levelUpGui:Destroy()
end

-- イベント接続
local LevelUpEvent = ReplicatedStorage:WaitForChild("LevelUp", 10)
if LevelUpEvent then
	-- LevelUpEvent.OnClientEvent:Connect(showLevelUp)
	LevelUpEvent.OnClientEvent:Connect(function(level, maxHP, speed, attack, defense, oldStats)
		showLevelUp(
			level,
			maxHP,
			speed,
			attack,
			defense,
			oldStats.MaxHP,
			oldStats.Speed,
			oldStats.Attack,
			oldStats.Defense
		)
	end)

	print("[LevelUpUI] LevelUpイベント接続完了")
else
	warn("[LevelUpUI] LevelUpイベントが見つかりません")
end

print("[LevelUpUI] 初期化完了")
