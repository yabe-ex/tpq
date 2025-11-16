-- ===== ./StartPlayerScripts/WarpUI.client.lua =====
-- StarterPlayer/StarterPlayerScripts/WarpUI.client.lua
-- ワープ時のロード画面

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- RemoteEventを取得 - タイムアウトを短く設定
local warpEvent = ReplicatedStorage:WaitForChild("WarpEvent", 5) -- ★修正: タイムアウトを5秒に設定

if not warpEvent then
	warn("[WarpUI] WarpEventが見つかりません。ワープUIは機能しません。")
	return
end

print("[WarpUI] 初期化完了")

-- ロード画面のUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WarpLoadingUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "LoadingFrame"
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.BackgroundTransparency = 1
frame.Visible = false
frame.Parent = screenGui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0.6, 0, 0.2, 0)
label.Position = UDim2.new(0.2, 0, 0.4, 0)
label.BackgroundTransparency = 1
label.Text = "Loading..."
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.SourceSansBold
label.Parent = frame

-- RemoteEventを受信
warpEvent.OnClientEvent:Connect(function(action, zoneName)
	if action == "StartLoading" then
		print("[WarpUI] ロード画面表示:", zoneName)
		label.Text = "Warping to " .. (zoneName or "???") .. "..."
		frame.BackgroundTransparency = 0.3
		frame.Visible = true

		-- フェードイン
		for i = 0.3, 0.7, 0.1 do
			frame.BackgroundTransparency = 1 - i
			task.wait(0.05)
		end
	elseif action == "EndLoading" then
		print("[WarpUI] ロード画面非表示")

		-- フェードアウト
		for i = 0.7, 0, -0.1 do
			frame.BackgroundTransparency = 1 - i
			task.wait(0.05)
		end

		frame.Visible = false
	end
end)
