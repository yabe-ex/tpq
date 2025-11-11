-- StarterPlayer/StarterPlayerScripts/StatusUI.client.lua
-- ★ バトル連動版 v4 (通常時ZIndex修正、バトル時フォントサイズ縮小)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[StatusUI] 初期化中... (バトル連動版 v4)")

-- 現在のステータス
local currentHP = 100
local currentMaxHP = 100
local currentLevel = 1
local currentExp = 0
local currentExpToNext = 100
local currentGold = 0
local isInBattle = false -- ★ バトル状態を管理

-- UI要素
local statusGui = nil
local backgroundFrame = nil -- ★ 全体の背景
local hpBarBackground = nil
local hpBarFill = nil
local hpLabel = nil
local levelLabel = nil
local expLabel = nil
local goldLabel = nil

-- HPの色を取得
local function getHPColor(hpPercent)
	if hpPercent > 0.6 then
		return Color3.fromRGB(46, 204, 113) -- 緑
	elseif hpPercent > 0.3 then
		return Color3.fromRGB(241, 196, 15) -- 黄色
	else
		return Color3.fromRGB(231, 76, 60) -- 赤
	end
end

local function updateDisplay()
	if hpBarFill and hpLabel then
		local hpPercent = currentHP / currentMaxHP
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(hpBarFill, tweenInfo, {
			Size = UDim2.new(hpPercent, 0, 1, 0),
		})
		tween:Play()

		local colorTween = TweenService:Create(
			hpBarFill,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundColor3 = getHPColor(hpPercent) }
		)
		colorTween:Play()

		hpLabel.Text = string.format("%d / %d", currentHP, currentMaxHP)
	end

	-- ★ ここを追加：レベル更新
	if levelLabel then
		local level = currentLevel or 1
		levelLabel.Text = string.format("Lv.%d", level)
	end

	if expLabel then
		-- EXPの表示形式「現在 / 必要EXP EXP」
		local exp = currentExp or 0
		local toNext = currentExpToNext or 0
		expLabel.Text = string.format("%d / %d EXP", exp, toNext)
	end

	if goldLabel then
		-- ゴールドのフォーマット（3桁区切り対応）
		local formattedGold = tostring(currentGold or 0):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		goldLabel.Text = string.format("%s G", formattedGold)
	end
end

-- ★ UI作成 (Lv左上・Gold右上・EXP右下・HPバー下段)
local function createStatusUI()
	statusGui = Instance.new("ScreenGui")
	statusGui.Name = "StatusUI"
	statusGui.ResetOnSpawn = false
	statusGui.Parent = playerGui
	statusGui.DisplayOrder = 10

	-- 背景フレーム
	backgroundFrame = Instance.new("Frame")
	backgroundFrame.Name = "StatusBackground"
	backgroundFrame.Size = UDim2.new(0, 300, 0, 90)
	backgroundFrame.Position = UDim2.new(1, -320, 1, -95)
	backgroundFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	backgroundFrame.BorderSizePixel = 0
	backgroundFrame.ZIndex = 11
	backgroundFrame.Parent = statusGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = backgroundFrame

	-- === 左上：レベルボックス ===
	local levelBox = Instance.new("Frame")
	levelBox.Name = "LevelBox"
	levelBox.Size = UDim2.new(0, 65, 0, 45)
	levelBox.Position = UDim2.new(0, 10, 0, 8)
	levelBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	levelBox.BorderSizePixel = 0
	levelBox.ZIndex = 12
	levelBox.Parent = backgroundFrame

	local levelCorner = Instance.new("UICorner")
	levelCorner.CornerRadius = UDim.new(0, 8)
	levelCorner.Parent = levelBox

	levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, 0, 1, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.TextStrokeTransparency = 0.5
	levelLabel.Font = Enum.Font.GothamBold
	-- levelLabel.TextScaled = true
	levelLabel.Text = "Lv.10"
	levelLabel.ZIndex = 13
	levelLabel.Parent = levelBox
	levelLabel.TextSize = 24 -- ★ 少し小さめ

	-- === 右上：ゴールド ===
	goldLabel = Instance.new("TextLabel")
	goldLabel.Name = "GoldLabel"
	goldLabel.Size = UDim2.new(0, 180, 0, 25)
	goldLabel.Position = UDim2.new(1, -190, 0, 6) -- ★ 少し上げる (10→6)
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	goldLabel.TextStrokeTransparency = 0.5
	goldLabel.Font = Enum.Font.GothamBold
	goldLabel.TextSize = 20
	goldLabel.Text = "1,234,567 G"
	goldLabel.TextXAlignment = Enum.TextXAlignment.Right
	goldLabel.ZIndex = 12
	goldLabel.Parent = backgroundFrame

	-- === 右下：経験値 ===
	expLabel = Instance.new("TextLabel")
	expLabel.Name = "ExpLabel"
	expLabel.Size = UDim2.new(0, 200, 0, 25)
	expLabel.Position = UDim2.new(1, -210, 0, 33) -- ★ さらに少し上げる (38→33)
	expLabel.BackgroundTransparency = 1
	expLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	expLabel.TextStrokeTransparency = 0.5
	expLabel.Font = Enum.Font.GothamBold -- ★ 統一
	expLabel.TextSize = 19
	expLabel.Text = "10 / 100 EXP" -- ★ 表示形式変更
	expLabel.TextXAlignment = Enum.TextXAlignment.Right
	expLabel.ZIndex = 12
	expLabel.Parent = backgroundFrame

	-- === 下段：HPバー ===
	hpBarBackground = Instance.new("Frame")
	hpBarBackground.Name = "HPBarBackground"
	hpBarBackground.Size = UDim2.new(1, -20, 0, 18)
	hpBarBackground.Position = UDim2.new(0, 10, 1, -25)
	hpBarBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	hpBarBackground.BorderSizePixel = 0
	hpBarBackground.ZIndex = 12
	hpBarBackground.Parent = backgroundFrame

	local hpBarCorner = Instance.new("UICorner")
	hpBarCorner.CornerRadius = UDim.new(0, 4)
	hpBarCorner.Parent = hpBarBackground

	hpBarFill = Instance.new("Frame")
	hpBarFill.Name = "HPBarFill"
	hpBarFill.Size = UDim2.new(1, 0, 1, 0)
	hpBarFill.BackgroundColor3 = Color3.fromRGB(30, 220, 30)
	hpBarFill.BorderSizePixel = 0
	hpBarFill.ZIndex = 13
	hpBarFill.Parent = hpBarBackground

	local hpFillCorner = Instance.new("UICorner")
	hpFillCorner.CornerRadius = UDim.new(0, 4)
	hpFillCorner.Parent = hpBarFill

	hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HPLabel"
	hpLabel.Size = UDim2.new(1, 0, 1, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextStrokeTransparency = 0.5
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextSize = 14
	hpLabel.Text = "100 / 100"
	hpLabel.ZIndex = 14
	hpLabel.Parent = hpBarBackground

	print("[StatusUI] UI作成完了 (EXP書式変更＋位置微調整)")
end

-- ステータス更新イベント
local function onStatusUpdate(hp, maxHP, level, exp, expToNext, gold)
	currentHP = hp or currentHP
	currentMaxHP = maxHP or currentMaxHP
	currentLevel = level or currentLevel
	currentExp = exp or currentExp
	currentExpToNext = expToNext or currentExpToNext
	currentGold = gold or currentGold
	updateDisplay()
end

-- バトル表示に切り替え（中央に大きなHPバーを表示）
local function switchToBattleView()
	if not backgroundFrame then
		return
	end
	print("[StatusUI] バトル表示に切り替え (中央HPバー)")

	-- === 背景フレームを「画面中央より少し下」に移動＆拡大 ===
	backgroundFrame:TweenSizeAndPosition(
		UDim2.new(0, 700, 0, 90),
		UDim2.new(0.5, -350, 0.7, -45),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		0.4,
		true
	)
	backgroundFrame.BackgroundTransparency = 1

	-- 子要素を取得
	local hpBarBackground = backgroundFrame:FindFirstChild("HPBarBackground")
	local hpBarFill = hpBarBackground and hpBarBackground:FindFirstChild("HPBarFill")
	local hpLabel = hpBarBackground and hpBarBackground:FindFirstChild("HPLabel")
	local levelBox = backgroundFrame:FindFirstChild("LevelBox")
	local levelLabel = levelBox and levelBox:FindFirstChild("LevelLabel")
	local goldLabel = backgroundFrame:FindFirstChild("GoldLabel")
	local expLabel = backgroundFrame:FindFirstChild("ExpLabel")

	-- === HPバー（太く・中央寄せ） ===
	if hpBarBackground then
		hpBarBackground:TweenSizeAndPosition(
			UDim2.new(1, -40, 0, 40), -- 高さを約2倍に
			UDim2.new(0, 20, 0.5, -20), -- フレーム内で中央配置
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quad,
			0.3,
			true
		)
		hpBarBackground.Visible = true
	end

	if hpLabel then
		hpLabel.Visible = true
		hpLabel.TextSize = 20
		hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		hpLabel.TextStrokeTransparency = 0.4
	end

	if hpBarFill then
		hpBarFill.Visible = true
	end

	-- === 他のUI要素は非表示 ===
	if levelBox then
		levelBox.Visible = false
	end
	if goldLabel then
		goldLabel.Visible = false
	end
	if expLabel then
		expLabel.Visible = false
	end
end

-- 通常表示に切り替え（バトル終了後に呼ばれる）
local function switchToDefaultView()
	if not backgroundFrame then
		return
	end
	print("[StatusUI] 通常表示に切り替え (右下レイアウト)")
	backgroundFrame.BackgroundTransparency = 0.3

	-- 背景フレームを右下に戻す
	backgroundFrame:TweenSizeAndPosition(
		UDim2.new(0, 300, 0, 90),
		UDim2.new(1, -320, 1, -95),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		0.4,
		true
	)
	backgroundFrame.BackgroundTransparency = 0.3
	backgroundFrame.Visible = true

	-- === 子要素取得 ===
	local levelBox = backgroundFrame:FindFirstChild("LevelBox")
	local levelLabel = levelBox and levelBox:FindFirstChild("LevelLabel")
	local goldLabel = backgroundFrame:FindFirstChild("GoldLabel")
	local expLabel = backgroundFrame:FindFirstChild("ExpLabel")
	local hpBarBackground = backgroundFrame:FindFirstChild("HPBarBackground")
	local hpBarFill = hpBarBackground and hpBarBackground:FindFirstChild("HPBarFill")
	local hpLabel = hpBarBackground and hpBarBackground:FindFirstChild("HPLabel")

	-- === レベルボックス ===
	if levelBox then
		levelBox.Visible = true
		levelBox.Position = UDim2.new(0, 10, 0, 8)
		levelBox.Size = UDim2.new(0, 65, 0, 45)
		levelBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	end

	if levelLabel then
		levelLabel.Visible = true
		levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		levelLabel.TextStrokeTransparency = 0.5
		levelLabel.Font = Enum.Font.GothamBold
		levelLabel.TextSize = 18
	end

	-- === ゴールド（右上） ===
	if goldLabel then
		goldLabel.Visible = true
		goldLabel.Position = UDim2.new(1, -190, 0, 6)
		goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		goldLabel.Font = Enum.Font.GothamBold
		goldLabel.TextSize = 20
		goldLabel.TextStrokeTransparency = 0.5
		goldLabel.TextXAlignment = Enum.TextXAlignment.Right
	end

	-- === 経験値（右下） ===
	if expLabel then
		expLabel.Visible = true
		expLabel.Position = UDim2.new(1, -210, 0, 33)
		expLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		expLabel.Font = Enum.Font.GothamBold
		expLabel.TextSize = 19
		expLabel.TextStrokeTransparency = 0.5
		expLabel.TextXAlignment = Enum.TextXAlignment.Right
	end

	-- === HPバー（下段） ===
	if hpBarBackground then
		hpBarBackground.Visible = true
		hpBarBackground.Position = UDim2.new(0, 10, 1, -25)
		hpBarBackground.Size = UDim2.new(1, -20, 0, 18)
		hpBarBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		hpBarBackground.BorderSizePixel = 0
	end

	if hpBarFill then
		hpBarFill.Visible = true
		hpBarFill.BackgroundColor3 = Color3.fromRGB(30, 220, 30)
	end

	if hpLabel then
		hpLabel.Visible = true
		hpLabel.TextColor3 = Color3.new(1, 1, 1)
		hpLabel.TextStrokeTransparency = 0.5
		hpLabel.Font = Enum.Font.GothamBold
		hpLabel.TextSize = 14
	end
end

-- 初期化
createStatusUI()
updateDisplay() -- 初回更新

print("[StatusUI] RemoteEventを待機中...")

-- バトルイベントリスナー
task.spawn(function()
	local BattleStartEvent = ReplicatedStorage:WaitForChild("BattleStart", 10)
	local BattleEndEvent = ReplicatedStorage:WaitForChild("BattleEnd", 10)

	if BattleStartEvent then
		BattleStartEvent.OnClientEvent:Connect(switchToBattleView)
		print("[StatusUI] BattleStartイベント接続完了")
	else
		warn("[StatusUI] BattleStartイベントが見つかりません")
	end

	if BattleEndEvent then
		BattleEndEvent.OnClientEvent:Connect(switchToDefaultView)
		print("[StatusUI] BattleEndEvent イベント接続完了")
	else
		warn("[StatusUI] BattleEndEvent イベントが見つかりません")
	end
end)

-- ステータス更新イベント（既存）
task.spawn(function()
	local StatusUpdateEvent = ReplicatedStorage:WaitForChild("StatusUpdate", 10)
	if StatusUpdateEvent then
		StatusUpdateEvent.OnClientEvent:Connect(onStatusUpdate)
		print("[StatusUI] StatusUpdateイベント接続完了")

		task.wait(1)
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
