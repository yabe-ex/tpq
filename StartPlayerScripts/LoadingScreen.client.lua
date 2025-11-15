-- StarterPlayer/StarterPlayerScripts/LoadingScreen.client.lua
-- 初回ロード時のローディング画面（ワープ用と統一）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[LoadingScreen] 初期化中...")

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

-- ローディング画面のUI（ワープ用と同じ構成）
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InitialLoadingUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1000 -- 最前面に表示
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

-- 画像表示エリア（中央に大きく）
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
hintText.TextColor3 = Color3.fromRGB(255, 255, 100) -- 黄色でハイライト
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

print("[LoadingScreen] ローディング画面を作成しました")

-- 初期表示：ランダム画像とヒント
local function showInitialLoading()
	-- ランダムに画像を選択してセット
	if #LoadingImages > 0 then
		local randomImage = LoadingImages[math.random(#LoadingImages)]
		imageLabel.Image = randomImage
		print("[LoadingScreen] 画像をセット: " .. randomImage)
	else
		print("[LoadingScreen] 警告: LoadingImages が空です")
	end

	-- ヒント取得（デフォルトレベル 1）
	local hint = LoadingHints.getHintByLevel(1)
	hintText.Text = hint
	-- hintText.Text = "💡 " .. hint
	-- print("[LoadingScreen] ヒント表示: " .. hint)
end

-- ★【修正】イベント処理フラグ
local alreadyFaded = false

local function fadeOutAndDestroy()
	if alreadyFaded then
		print("[LoadingScreen] 既にフェードアウト済みです（二重実行防止）")
		return
	end
	alreadyFaded = true

	print("[LoadingScreen] スポーン準備完了、フェードアウト開始")

	-- フェードアウトアニメーション
	local fadeOut = TweenService:Create(background, TweenInfo.new(1, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1,
	})

	local labelFadeOut = TweenService:Create(loadingText, TweenInfo.new(1, Enum.EasingStyle.Quad), {
		TextTransparency = 1,
	})

	local imageFadeOut = TweenService:Create(imageLabel, TweenInfo.new(1, Enum.EasingStyle.Quad), {
		ImageTransparency = 1,
	})

	local hintFadeOut = TweenService:Create(hintText, TweenInfo.new(1, Enum.EasingStyle.Quad), {
		TextTransparency = 1,
	})

	fadeOut:Play()
	labelFadeOut:Play()
	imageFadeOut:Play()
	hintFadeOut:Play()

	fadeOut.Completed:Connect(function()
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
			print("[LoadingScreen] ローディング画面を削除")
		end
	end)
end

-- 初期ローディング表示
showInitialLoading()
print("[LoadingScreen] 初期表示完了（ローディング画面を表示中）")

-- ★【修正】RemoteEvent取得：WaitForChild ではなく FindFirstChild を使用
-- そして後から来るイベントも拾うように接続
local spawnReadyEvent = ReplicatedStorage:FindFirstChild("SpawnReady")

if spawnReadyEvent then
	print("[LoadingScreen] SpawnReadyEvent が既に存在します")
	spawnReadyEvent.OnClientEvent:Connect(function()
		print("[LoadingScreen] OnClientEvent に接続しました")
		fadeOutAndDestroy()
	end)
else
	print("[LoadingScreen] SpawnReadyEvent が見つかりません、監視中...")
	-- ★【修正】ChildAdded で後から作成されるイベントを監視
	local childConn
	childConn = ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "SpawnReady" and child:IsA("RemoteEvent") then
			print("[LoadingScreen] SpawnReadyEvent が新規作成されました")
			childConn:Disconnect()

			-- イベントに接続
			child.OnClientEvent:Connect(function()
				print("[LoadingScreen] OnClientEvent に接続しました")
				fadeOutAndDestroy()
			end)
		end
	end)

	-- ★【修正】タイムアウト対策：15秒待ってもイベントが来なければ自動消去
	task.wait(15)
	if screenGui and screenGui.Parent and not alreadyFaded then
		print(
			"[LoadingScreen] タイムアウト：ローディング画面を自動削除（イベントが来ませんでした）"
		)
		childConn:Disconnect()
		fadeOutAndDestroy()
	end
end

print("[LoadingScreen] 初期化完了")
