-- StarterPlayer/StarterPlayerScripts/InteractionUI.client.lua
-- インタラクション検出とUIボタン表示

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[InteractionUI] 初期化開始")

-- RemoteEvent取得
local InteractEvent = ReplicatedStorage:WaitForChild("InteractEvent", 10)
if not InteractEvent then
	warn("[InteractionUI] InteractEventが見つかりません")
	return
end

-- RemoteFunctionで取得済みリストを取得
local GetCollectedItemsFunc = ReplicatedStorage:FindFirstChild("GetCollectedItems")
if not GetCollectedItemsFunc then
	GetCollectedItemsFunc = Instance.new("RemoteFunction")
	GetCollectedItemsFunc.Name = "GetCollectedItems"
	GetCollectedItemsFunc.Parent = ReplicatedStorage
end

-- 現在のインタラクション対象
local currentTarget = nil
local currentButton = nil

-- インタラクション済みのオブジェクトを記録
local interactedObjects = {}

-- インタラクションボタンUI作成
local function createInteractionButton(targetObject, actionText, key)
	-- 既存のボタンを削除
	if currentButton then
		currentButton:Destroy()
		currentButton = nil
	end

	-- ScreenGuiに配置（画面中央下部）
	local screenGui = playerGui:FindFirstChild("InteractionButtonGui")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "InteractionButtonGui"
		screenGui.ResetOnSpawn = false
		screenGui.DisplayOrder = 150
		screenGui.Parent = playerGui
	end

	-- 背景フレーム
	local frame = Instance.new("Frame")
	frame.Name = "InteractionFrame"
	frame.Size = UDim2.new(0, 250, 0, 60)
	frame.Position = UDim2.new(0.5, -125, 0.85, 0) -- 画面下部中央
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	-- ボタン
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.9, 0, 0.7, 0)
	button.Position = UDim2.new(0.05, 0, 0.15, 0)
	button.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
	button.BackgroundTransparency = 0.2
	button.BorderSizePixel = 2
	button.BorderColor3 = Color3.new(1, 1, 1)
	button.Text = string.format("%s [%s]", actionText, key)
	button.TextColor3 = Color3.new(0, 0, 0)
	button.TextSize = 20
	button.Font = Enum.Font.SourceSansBold
	button.AutoButtonColor = true
	button.Parent = frame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = button

	-- ボタンクリック
	button.MouseButton1Click:Connect(function()
		print("[InteractionUI DEBUG] ===== ボタンクリックイベント発火 =====")
		print(("[InteractionUI] ボタンクリック: %s"):format(targetObject.Name))

		-- インタラクション済みに記録
		interactedObjects[targetObject] = true

		-- サーバーに送信
		InteractEvent:FireServer(targetObject)

		-- 即座にボタンを削除
		if currentButton then
			currentButton:Destroy()
			currentButton = nil
		end
		currentTarget = nil
	end)

	-- デバッグ：ホバー検出
	button.MouseEnter:Connect(function()
		print("[InteractionUI DEBUG] マウスがボタンに入った")
		button.BackgroundTransparency = 0 -- ハイライト
	end)

	button.MouseLeave:Connect(function()
		print("[InteractionUI DEBUG] マウスがボタンから出た")
		button.BackgroundTransparency = 0.2
	end)

	currentButton = frame
	return frame
end

-- インタラクション可能なオブジェクトを検出
local function findNearestInteractable()
	local character = player.Character
	if not character then return nil end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local nearestObject = nil
	local nearestDistance = math.huge

	-- workspace内の全オブジェクトをチェック
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("HasInteraction") then
			-- インタラクション済みならスキップ
			if interactedObjects[obj] then
				continue
			end

			local distance = (hrp.Position - obj.Position).Magnitude
			local range = obj:GetAttribute("InteractionRange") or 8

			if distance <= range and distance < nearestDistance then
				nearestObject = obj
				nearestDistance = distance
			end
		end
	end

	return nearestObject
end

-- メインループ
RunService.Heartbeat:Connect(function()
	local nearest = findNearestInteractable()

	-- 対象が変わった場合
	if nearest ~= currentTarget then
		-- 古いボタンを削除
		if currentButton then
			currentButton:Destroy()
			currentButton = nil
		end

		currentTarget = nearest

		-- 新しいボタンを作成
		if nearest then
			local action = nearest:GetAttribute("InteractionAction") or "調べる"
			local key = nearest:GetAttribute("InteractionKey") or "E"
			createInteractionButton(nearest, action, key)

			print(("[InteractionUI] インタラクション可能: %s"):format(action))
		end
	end
end)

-- キー入力
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if currentTarget and input.KeyCode == Enum.KeyCode.E then
		local action = currentTarget:GetAttribute("InteractionAction") or "調べる"
		print(("[InteractionUI] Eキー押下: %s"):format(action))

		-- インタラクション済みに記録
		interactedObjects[currentTarget] = true

		-- サーバーに送信
		InteractEvent:FireServer(currentTarget)

		-- 即座にボタンを削除
		if currentButton then
			currentButton:Destroy()
			currentButton = nil
		end
		currentTarget = nil
	end
end)

