--- StartPlayerScripts/FastTravelUI.client.lua ---
-- StarterPlayer/StarterPlayerScripts/FastTravelUI.client.lua
-- ファストトラベルUIシステム

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[FastTravelUI] 初期化開始")

-- RemoteEvent取得
local FastTravelEvent = ReplicatedStorage:WaitForChild("FastTravelEvent", 10)
local GetContinentsEvent = ReplicatedStorage:WaitForChild("GetContinentsEvent", 10)

if not FastTravelEvent or not GetContinentsEvent then
	warn("[FastTravelUI] RemoteEventが見つかりません")
	return
end

-- UIコンテナ
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FastTravelUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ★【修正】ワープボタン（黒系ベース、MenuUI と同じデザイン）
local warpButton = Instance.new("TextButton")
warpButton.Name = "WarpButton"
warpButton.Size = UDim2.new(0, 200, 0, 50)
warpButton.Position = UDim2.new(0, 20, 1, -280)
warpButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60) -- 黒系
warpButton.BackgroundTransparency = 0.2 -- MenuUI と同じ
warpButton.BorderSizePixel = 0 -- 枠なし
warpButton.Text = "ファストトラベル"
warpButton.TextColor3 = Color3.new(1, 1, 1)
warpButton.TextSize = 16
warpButton.Font = Enum.Font.GothamBold
warpButton.Parent = screenGui

local warpButtonCorner = Instance.new("UICorner")
warpButtonCorner.CornerRadius = UDim.new(0, 8)
warpButtonCorner.Parent = warpButton

-- ★【追加】ホバーエフェクト（MenuUI と同じ）
warpButton.MouseEnter:Connect(function()
	TweenService:Create(warpButton, TweenInfo.new(0.2), {
		BackgroundColor3 = Color3.fromRGB(70, 70, 80),
	}):Play()
end)

warpButton.MouseLeave:Connect(function()
	TweenService:Create(warpButton, TweenInfo.new(0.2), {
		BackgroundColor3 = Color3.fromRGB(50, 50, 60),
	}):Play()
end)

-- モーダル背景
local modalBackground = Instance.new("Frame")
modalBackground.Name = "ModalBackground"
modalBackground.Size = UDim2.fromScale(1, 1)
modalBackground.Position = UDim2.fromScale(0, 0)
modalBackground.BackgroundColor3 = Color3.new(0, 0, 0)
modalBackground.BackgroundTransparency = 1
modalBackground.Visible = false
modalBackground.ZIndex = 101
modalBackground.Parent = screenGui

-- モーダルウィンドウ
local modalWindow = Instance.new("Frame")
modalWindow.Name = "ModalWindow"
modalWindow.Size = UDim2.new(0, 400, 0, 500)
modalWindow.Position = UDim2.new(0.5, -200, 0.5, -250)
modalWindow.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
modalWindow.BackgroundTransparency = 0.1
modalWindow.BorderSizePixel = 3
modalWindow.BorderColor3 = Color3.fromRGB(100, 150, 255)
modalWindow.ZIndex = 102
modalWindow.Parent = modalBackground

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 12)
modalCorner.Parent = modalWindow

-- タイトル
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "ワープ先を選択"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 24
titleLabel.Font = Enum.Font.GothamBold
titleLabel.ZIndex = 103
titleLabel.Parent = modalWindow

-- 閉じるボタン
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -50, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.BackgroundTransparency = 0.3
closeButton.BorderSizePixel = 0
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextSize = 24
closeButton.Font = Enum.Font.SourceSansBold
closeButton.ZIndex = 103
closeButton.Parent = modalWindow

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0, 8)
closeButtonCorner.Parent = closeButton

-- スクロールフレーム（大陸一覧）
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ContinentsList"
scrollFrame.Size = UDim2.new(1, -40, 1, -100)
scrollFrame.Position = UDim2.new(0, 20, 0, 70)
scrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
scrollFrame.BackgroundTransparency = 0.5
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 8
scrollFrame.ZIndex = 102
scrollFrame.Parent = modalWindow

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 8)
scrollCorner.Parent = scrollFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 10)
listPadding.PaddingBottom = UDim.new(0, 10)
listPadding.PaddingLeft = UDim.new(0, 10)
listPadding.PaddingRight = UDim.new(0, 10)
listPadding.Parent = scrollFrame

-- モーダルを開く
local function openModal()
	print("[FastTravelUI] モーダルを開く")

	-- ファストトラベル可能なポータル一覧を取得
	local success, targets = pcall(function()
		return GetContinentsEvent:InvokeServer()
	end)

	if not success or not targets then
		warn("[FastTravelUI] ファストトラベル先リストの取得に失敗しました:", targets)
		return
	end

	-- 既存のボタンをクリア
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- ボタンを生成
	for i, target in ipairs(targets) do
		local button = Instance.new("TextButton")
		button.Name = target.portalName -- ポータル名をボタン名に使用
		button.Size = UDim2.new(1, -20, 0, 60)
		button.BackgroundColor3 = Color3.fromRGB(60, 100, 180)
		button.BackgroundTransparency = 0.2
		button.BorderSizePixel = 0
		button.Text = target.displayName -- ポータル名をUI表示に使用
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextSize = 20
		button.Font = Enum.Font.SourceSansBold
		button.LayoutOrder = i
		button.ZIndex = 103
		button.Parent = scrollFrame

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button

		-- ホバーエフェクト
		button.MouseEnter:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.2), {
				BackgroundTransparency = 0,
			}):Play()
		end)

		button.MouseLeave:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.2,
			}):Play()
		end)

		-- クリックイベント
		button.MouseButton1Click:Connect(function()
			print(
				("[FastTravelUI] %s のポータル '%s' へワープ要求"):format(
					target.continentName,
					target.portalName
				)
			)
			-- サーバーに大陸名とポータル名を送信
			FastTravelEvent:FireServer(target.continentName, target.portalName)
			closeModal()
		end)
	end

	-- スクロールフレームのサイズ調整
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)

	-- モーダル表示
	modalBackground.Visible = true
	modalBackground.BackgroundTransparency = 0.5

	-- フェードイン
	TweenService:Create(modalBackground, TweenInfo.new(0.3), {
		BackgroundTransparency = 0.3,
	}):Play()
end

-- モーダルを閉じる
function closeModal()
	print("[FastTravelUI] モーダルを閉じる")

	TweenService:Create(modalBackground, TweenInfo.new(0.3), {
		BackgroundTransparency = 1,
	}):Play()

	task.wait(0.3)
	modalBackground.Visible = false
end

-- イベント接続
warpButton.MouseButton1Click:Connect(openModal)
closeButton.MouseButton1Click:Connect(closeModal)

-- 背景クリックで閉じる
modalBackground.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- モーダルウィンドウ外をクリックした場合
		local mousePos = input.Position
		local windowPos = modalWindow.AbsolutePosition
		local windowSize = modalWindow.AbsoluteSize

		if
			mousePos.X < windowPos.X
			or mousePos.X > windowPos.X + windowSize.X
			or mousePos.Y < windowPos.Y
			or mousePos.Y > windowPos.Y + windowSize.Y
		then
			closeModal()
		end
	end
end)

print("[FastTravelUI] 初期化完了")
