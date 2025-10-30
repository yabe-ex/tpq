-- StarterPlayer/StarterPlayerScripts/RewardPopup.client.lua
-- 報酬取得時のポップアップ表示

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[RewardPopup] 初期化開始")

-- RemoteEvent取得
local InteractionResponseEvent = ReplicatedStorage:WaitForChild("InteractionResponse", 10)
if not InteractionResponseEvent then
	warn("[RewardPopup] InteractionResponseが見つかりません")
	return
end

-- ScreenGui作成
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RewardPopupUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 200
screenGui.Parent = playerGui

-- ポップアップを表示
local function showRewardPopup(rewards, duration)
	duration = duration or 3
	print(("[RewardPopup] 報酬を表示: %d個, 表示時間: %d秒"):format(#rewards, duration))

	-- メインフレーム
	local frame = Instance.new("Frame")
	frame.Name = "RewardFrame"
	frame.Size = UDim2.new(0, 400, 0, 0) -- 高さは動的に調整
	frame.Position = UDim2.new(0.5, -200, 0.3, 0)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	-- タイトル
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "✨ アイテムを手に入れた！"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextSize = 24
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	-- 報酬リストコンテナ
	local listContainer = Instance.new("Frame")
	listContainer.Size = UDim2.new(1, -20, 1, -60)
	listContainer.Position = UDim2.new(0, 10, 0, 50)
	listContainer.BackgroundTransparency = 1
	listContainer.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = listContainer

	-- 各報酬を表示
	for i, reward in ipairs(rewards) do
		local rewardFrame = Instance.new("Frame")
		rewardFrame.Size = UDim2.new(1, 0, 0, 35)
		rewardFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		rewardFrame.BackgroundTransparency = 0.5
		rewardFrame.BorderSizePixel = 0
		rewardFrame.LayoutOrder = i
		rewardFrame.Parent = listContainer

		local rewardCorner = Instance.new("UICorner")
		rewardCorner.CornerRadius = UDim.new(0, 8)
		rewardCorner.Parent = rewardFrame

		-- アイテム名
		local itemLabel = Instance.new("TextLabel")
		itemLabel.Size = UDim2.new(0.7, 0, 1, 0)
		itemLabel.Position = UDim2.new(0, 15, 0, 0)
		itemLabel.BackgroundTransparency = 1
		itemLabel.Text = reward.item
		itemLabel.TextColor3 = Color3.new(1, 1, 1)
		itemLabel.TextSize = 20
		itemLabel.Font = Enum.Font.SourceSansBold
		itemLabel.TextXAlignment = Enum.TextXAlignment.Left
		itemLabel.Parent = rewardFrame

		-- 個数
		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(0.3, -15, 1, 0)
		countLabel.Position = UDim2.new(0.7, 0, 0, 0)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = "x" .. tostring(reward.count)
		countLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		countLabel.TextSize = 20
		countLabel.Font = Enum.Font.SourceSansBold
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.Parent = rewardFrame
	end

	-- フレームの高さを調整
	local contentHeight = 60 + (#rewards * 35) + ((#rewards - 1) * 8)
	frame.Size = UDim2.new(0, 400, 0, contentHeight)

	-- フェードイン
	frame.BackgroundTransparency = 1
	title.TextTransparency = 1

	for _, child in ipairs(listContainer:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundTransparency = 1
			for _, label in ipairs(child:GetChildren()) do
				if label:IsA("TextLabel") then
					label.TextTransparency = 1
				end
			end
		end
	end

	-- アニメーション：フェードイン
	TweenService:Create(frame, TweenInfo.new(0.5), {
		BackgroundTransparency = 0.2
	}):Play()

	TweenService:Create(title, TweenInfo.new(0.5), {
		TextTransparency = 0
	}):Play()

	for _, child in ipairs(listContainer:GetChildren()) do
		if child:IsA("Frame") then
			TweenService:Create(child, TweenInfo.new(0.5), {
				BackgroundTransparency = 0.5
			}):Play()

			for _, label in ipairs(child:GetChildren()) do
				if label:IsA("TextLabel") then
					TweenService:Create(label, TweenInfo.new(0.5), {
						TextTransparency = 0
					}):Play()
				end
			end
		end
	end

	-- 5秒後にフェードアウト
	task.wait(5)

	-- アニメーション：フェードアウト
	local fadeOut = TweenService:Create(frame, TweenInfo.new(1), {
		BackgroundTransparency = 1
	})

	TweenService:Create(title, TweenInfo.new(1), {
		TextTransparency = 1
	}):Play()

	for _, child in ipairs(listContainer:GetChildren()) do
		if child:IsA("Frame") then
			TweenService:Create(child, TweenInfo.new(1), {
				BackgroundTransparency = 1
			}):Play()

			for _, label in ipairs(child:GetChildren()) do
				if label:IsA("TextLabel") then
					TweenService:Create(label, TweenInfo.new(1), {
						TextTransparency = 1
					}):Play()
				end
			end
		end
	end

	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		frame:Destroy()
		print("[RewardPopup] ポップアップを削除しました")
	end)
end

-- サーバーからの報酬情報を受信
InteractionResponseEvent.OnClientEvent:Connect(function(data)
	if data.success and data.type == "chest" and data.rewards then
		local duration = data.displayDuration or 3
		showRewardPopup(data.rewards, duration)
	end
end)

print("[RewardPopup] 初期化完了")