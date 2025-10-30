-- StarterPlayer/StarterPlayerScripts/DebugButtons.client.lua
-- デバッグ用ボタン（開発時のみ使用）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[DebugButtons] 初期化開始")

-- デバッグモード（本番環境ではfalseに）
local DEBUG_MODE = true

if not DEBUG_MODE then
	print("[DebugButtons] デバッグモードOFF")
	return
end

-- RemoteEvent取得（サーバーが作成するまで待機）
local DebugCommandEvent = ReplicatedStorage:WaitForChild("DebugCommand", 10)
if not DebugCommandEvent then
	warn("[DebugButtons] DebugCommandEventが見つかりません")
	return
end

print("[DebugButtons] RemoteEventを取得しました")

-- ScreenGui作成
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DebugButtonsUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 300
screenGui.Parent = playerGui

-- ボタンコンテナ（右上から左に並ぶ）
local container = Instance.new("Frame")
container.Name = "ButtonContainer"
container.Size = UDim2.new(0, 600, 0, 50)
container.Position = UDim2.new(1, -620, 0, 20) -- 右上
container.BackgroundTransparency = 1
container.Parent = screenGui

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = container

-- デバッグボタン作成関数
local function createDebugButton(text, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 180, 0, 40)
	button.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	button.BackgroundTransparency = 0.2
	button.BorderSizePixel = 2
	button.BorderColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 16
	button.Font = Enum.Font.SourceSansBold
	button.AutoButtonColor = true
	button.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	-- ホバーエフェクト
	button.MouseEnter:Connect(function()
		button.BackgroundTransparency = 0
	end)

	button.MouseLeave:Connect(function()
		button.BackgroundTransparency = 0.2
	end)

	-- クリックイベント
	button.MouseButton1Click:Connect(callback)

	return button
end

-- 【ボタン1】宝箱リセット
createDebugButton("🔄 宝箱リセット", function()
	print("[DebugButtons] 宝箱リセットボタンをクリック")
	DebugCommandEvent:FireServer("reset_chests")
	print("[DebugButtons] サーバーにリセット要求を送信しました")
end)

-- 【将来追加予定のボタン例】
-- createDebugButton("💰 ゴールド+1000", function()
-- 	DebugCommandEvent:FireServer("add_gold", 1000)
-- end)

-- createDebugButton("⬆️ レベルアップ", function()
-- 	DebugCommandEvent:FireServer("level_up")
-- end)

print("[DebugButtons] 初期化完了")