-- StartPlayerScripts/LoadingUI.client.lua
-- ローディング画面の表示・非表示制御

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[LoadingUI] 初期化開始")

-- ローディング画像の Asset ID リスト
local LoadingImages = {
	-- "rbxassetid://74049529220513",
	-- "rbxassetid://139010932520933",
	-- "rbxassetid://140175964173817",
	-- "rbxassetid://117367461463003",
	-- "rbxassetid://109768764700057",
}

-- LoadingHints を読み込み
local LoadingHints = require(ReplicatedStorage:WaitForChild("LoadingHints"))

-- ローディング UI を作成
local function createLoadingScreen()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LoadingScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 500 -- 通常のUI背後に配置
	screenGui.Parent = playerGui

	-- 背景（全画面黒）
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	background.BackgroundTransparency = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Position = UDim2.fromScale(0, 0)
	background.ZIndex = 1
	background.Parent = screenGui

	-- 画像表示エリア
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "LoadingImage"
	imageLabel.BackgroundTransparency = 1
	imageLabel.Size = UDim2.fromOffset(600, 450)
	imageLabel.Position = UDim2.fromScale(0.5, 0.35)
	imageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	imageLabel.ScaleType = Enum.ScaleType.Fit
	imageLabel.ZIndex = 2
	imageLabel.Parent = background

	-- "Now Loading..." テキスト
	local loadingText = Instance.new("TextLabel")
	loadingText.Name = "LoadingText"
	loadingText.Text = "Now Loading..."
	loadingText.Font = Enum.Font.GothamBold
	loadingText.TextSize = 56
	loadingText.TextColor3 = Color3.fromRGB(255, 255, 255)
	loadingText.BackgroundTransparency = 1
	loadingText.Size = UDim2.fromOffset(500, 70)
	loadingText.Position = UDim2.fromScale(0.5, 0.75)
	loadingText.AnchorPoint = Vector2.new(0.5, 0.5)
	loadingText.ZIndex = 2
	loadingText.Parent = background

	-- ヒントテキスト（シンプル版：背景なし）
	local hintText = Instance.new("TextLabel")
	hintText.Name = "HintText"
	hintText.Text = ""
	hintText.Font = Enum.Font.Gotham
	hintText.TextSize = 24
	hintText.TextColor3 = Color3.fromRGB(255, 255, 100)
	hintText.BackgroundTransparency = 1
	hintText.TextWrapped = true
	hintText.TextScaled = true
	hintText.Size = UDim2.fromOffset(800, 100)
	hintText.Position = UDim2.fromScale(0.5, 0.88)
	hintText.AnchorPoint = Vector2.new(0.5, 0.5)
	hintText.ZIndex = 2
	hintText.Parent = background

	-- ストローク（縁取り）を追加
	hintText.TextStrokeTransparency = 0.5
	hintText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

	-- 初期状態は非表示
	screenGui.Enabled = false

	print("[LoadingUI] ローディング画面を作成しました")

	local loadingScreenObj = {}
	loadingScreenObj.screenGui = screenGui
	loadingScreenObj.imageLabel = imageLabel
	loadingScreenObj.background = background
	loadingScreenObj.loadingText = loadingText
	loadingScreenObj.hintText = hintText

	function loadingScreenObj:show(playerLevel)
		print("[LoadingUI] show() 呼び出し開始")

		playerLevel = playerLevel or 1
		print("[LoadingUI] playerLevel: " .. tostring(playerLevel))

		-- ランダムに画像を選択してセット
		if #LoadingImages > 0 then
			local randomImage = LoadingImages[math.random(#LoadingImages)]
			self.imageLabel.Image = randomImage
			print("[LoadingUI] 画像をセット: " .. randomImage)
		else
			print("[LoadingUI] 警告: LoadingImages が空です")
		end

		-- ヒント取得
		print("[LoadingUI] ヒント取得中...")
		local hint = LoadingHints.getHintByLevel(playerLevel)
		print("[LoadingUI] ヒント取得完了: " .. tostring(hint))

		-- ヒントテキストをセット
		-- self.hintText.Text = "💡 " .. hint
		self.hintText.Text = hint
		print("[LoadingUI] hintText をセット完了: " .. self.hintText.Text)

		-- リセット（透明度を0に）
		self.background.BackgroundTransparency = 0
		self.loadingText.TextTransparency = 0
		self.imageLabel.ImageTransparency = 0
		self.hintText.TextTransparency = 0

		-- 表示
		self.screenGui.Enabled = true
		print("[LoadingUI] screenGui を表示")
	end

	function loadingScreenObj:fadeOut()
		print("[LoadingUI] フェードアウト開始")

		local fadeOut = TweenService:Create(self.background, TweenInfo.new(1, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		})

		local labelFadeOut = TweenService:Create(self.loadingText, TweenInfo.new(1, Enum.EasingStyle.Quad), {
			TextTransparency = 1,
		})

		local imageFadeOut = TweenService:Create(self.imageLabel, TweenInfo.new(1, Enum.EasingStyle.Quad), {
			ImageTransparency = 1,
		})

		local hintFadeOut = TweenService:Create(self.hintText, TweenInfo.new(1, Enum.EasingStyle.Quad), {
			TextTransparency = 1,
		})

		fadeOut:Play()
		labelFadeOut:Play()
		imageFadeOut:Play()
		hintFadeOut:Play()

		fadeOut.Completed:Connect(function()
			self.screenGui.Enabled = false
			print("[LoadingUI] フェードアウト完了")
		end)
	end

	function loadingScreenObj:hide()
		self.screenGui.Enabled = false
		self.imageLabel.Image = ""
		self.hintText.Text = ""
		print("[LoadingUI] ローディング画面を非表示")
	end

	return loadingScreenObj
end

local loadingScreen = createLoadingScreen()

print("[LoadingUI] loadingScreen の型: " .. type(loadingScreen))
print("[LoadingUI] loadingScreen.show の型: " .. type(loadingScreen.show))

-- ★【追加】ゲーム初期化時の SpawnReady イベント対応
local spawnReadyEvent = ReplicatedStorage:FindFirstChild("SpawnReady")
if spawnReadyEvent then
	print("[LoadingUI] SpawnReadyEvent に接続しました")
	spawnReadyEvent.OnClientEvent:Connect(function()
		print("[LoadingUI] SpawnReady イベント受信 → ローディング画面をフェードアウト")
		loadingScreen:fadeOut()
	end)
else
	print("[LoadingUI] SpawnReadyEvent が見つかりません（後から作成される可能性あり）")
	-- 後から作成される場合に備えて監視
	local childConn
	childConn = ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "SpawnReady" and child:IsA("RemoteEvent") then
			print("[LoadingUI] SpawnReadyEvent が新規作成されました → 接続")
			childConn:Disconnect()
			child.OnClientEvent:Connect(function()
				print("[LoadingUI] SpawnReady イベント受信 → ローディング画面をフェードアウト")
				loadingScreen:fadeOut()
			end)
		end
	end)
end

-- ワープイベント（WarpPortal 経由）
local warpEvent = ReplicatedStorage:WaitForChild("WarpEvent")
warpEvent.OnClientEvent:Connect(function(action, zoneName, playerLevel)
	print(
		"[LoadingUI] warpEvent 受信: action="
			.. tostring(action)
			.. ", zoneName="
			.. tostring(zoneName)
			.. ", playerLevel="
			.. tostring(playerLevel)
	)

	if action == "StartLoading" then
		print(("[LoadingUI] ワープ開始: %s (レベル: %d)"):format(zoneName or "Unknown", playerLevel or 1))
		loadingScreen:show(playerLevel or 1)
	elseif action == "EndLoading" then
		print(("[LoadingUI] ワープ完了: %s"):format(zoneName or "Unknown"))
		task.wait(0.5)
		loadingScreen:fadeOut()
	end
end)

-- ファストトラベルイベント（FastTravelSystem 経由）
local fastTravelEvent = ReplicatedStorage:WaitForChild("FastTravelEvent")
fastTravelEvent.OnClientEvent:Connect(function(action, zoneName, playerLevel)
	print(
		"[LoadingUI] fastTravelEvent 受信: action="
			.. tostring(action)
			.. ", zoneName="
			.. tostring(zoneName)
			.. ", playerLevel="
			.. tostring(playerLevel)
	)

	if action == "StartLoading" then
		print(
			("[LoadingUI] ファストトラベル開始: %s (レベル: %d)"):format(
				zoneName or "Unknown",
				playerLevel or 1
			)
		)
		loadingScreen:show(playerLevel or 1)
	elseif action == "EndLoading" then
		print(("[LoadingUI] ファストトラベル完了: %s"):format(zoneName or "Unknown"))
		task.wait(0.5)
		loadingScreen:fadeOut()
	end
end)

print("[LoadingUI] 初期化完了")
