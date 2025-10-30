-- StarterPlayer/StarterPlayerScripts/UIToggleManager.client.lua
-- UI一括表示/非表示管理（Q キーで切り替え）

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[UIToggleManager] 初期化開始")

-- 非表示対象の UI リスト
local UIElements = {
	-- FastTravelUI のワープボタン
	{
		name = "FastTravelButton",
		find = function()
			local ui = playerGui:FindFirstChild("FastTravelUI")
			return ui and ui:FindFirstChild("WarpButton")
		end,
	},
	-- ミニマップ
	{
		name = "Minimap",
		find = function()
			local ui = playerGui:FindFirstChild("MinimapUI")
			return ui
		end,
	},
	-- デバッグボタン（宝箱リセット）
	{
		name = "DebugButtons",
		find = function()
			local ui = playerGui:FindFirstChild("DebugButtonsUI")
			return ui
		end,
	},
	-- メニューボタン（ステータス、アイテム、スキル、戦歴、設定、システム）
	{
		name = "MenuUI",
		find = function()
			local ui = playerGui:FindFirstChild("MenuUI")
			return ui
		end,
	},
	-- ステータスUI（HP、レベル、EXP、ゴールド）
	{
		name = "StatusUI",
		find = function()
			local ui = playerGui:FindFirstChild("StatusUI")
			return ui
		end,
	},
	-- Roblox システムUI（Music ボタンなど）
	{
		name = "RobloxTopbar",
		find = function()
			return "RobloxTopbar" -- ダミー値、toggle時に処理
		end,
		isSystemUI = true,
	},
}

-- UI表示状態
local uiVisible = true

-- UI の表示/非表示を切り替え
local function toggleAllUI()
	uiVisible = not uiVisible
	print(("[UIToggleManager] UI 切り替え: %s"):format(uiVisible and "表示" or "非表示"))

	for _, uiData in ipairs(UIElements) do
		-- システムUI の場合
		if uiData.isSystemUI then
			local starterGui = game:GetService("StarterGui")
			-- Roblox トップバー（Music ボタンなど）を切り替え
			pcall(function()
				starterGui:SetCore("TopbarEnabled", uiVisible)
			end)
			print(("[UIToggleManager] %s: %s"):format(uiData.name, uiVisible and "表示" or "非表示"))
		else
			-- 通常の UI
			local element = uiData.find()
			if element then
				-- ScreenGui と TextButton 両方に対応
				if element:IsA("ScreenGui") then
					element.Enabled = uiVisible
				else
					-- TextButton や Frame の場合は Visible を使用
					element.Visible = uiVisible
				end
				print(("[UIToggleManager] %s: %s"):format(uiData.name, uiVisible and "表示" or "非表示"))
			else
				print(("[UIToggleManager] ⚠️  %s が見つかりません"):format(uiData.name))
			end
		end
	end
end

-- Q キー入力を監視
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	-- Q キーで UI 切り替え
	if input.KeyCode == Enum.KeyCode.Q then
		toggleAllUI()
	end
end)

print("[UIToggleManager] 初期化完了")
print("[UIToggleManager] Q キーで UI の表示/非表示を切り替えられます")
