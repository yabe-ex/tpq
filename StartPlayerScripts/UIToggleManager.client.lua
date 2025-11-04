-- StarterPlayer/StarterPlayerScripts/UIToggleManager.client.lua
-- UI一括表示/非表示管理（Q キーで切り替え）
-- ★ 4段階トグル（全表示 -> 非表示 -> ステータスのみ -> ステータス+ミニマップ）に修正

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[UIToggleManager] 初期化開始 (4段階トグル版)")

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

-- ★ UI表示状態 (1: 全表示, 2: 全非表示, 3: ステータスのみ, 4: ステータス+ミニマップ)
local uiState = 1

-- UI の表示/非表示を更新する関数
local function updateUIVisibility()
	local stateName = "不明"
	if uiState == 1 then
		stateName = "すべて表示"
	elseif uiState == 2 then
		stateName = "すべて非表示"
	elseif uiState == 3 then
		stateName = "ステータスのみ表示"
	elseif uiState == 4 then
		stateName = "ステータスとミニマップのみ表示"
	end
	print(("[UIToggleManager] UI 切り替え: %s (状態 %d)"):format(stateName, uiState))

	for _, uiData in ipairs(UIElements) do
		-- このUIを現在の状態で表示すべきか判定
		local isVisible = false
		if uiState == 1 then
			-- 状態1: すべて表示
			isVisible = true
		elseif uiState == 2 then
			-- 状態2: すべて非表示
			isVisible = false
		elseif uiState == 3 then
			-- ★ 状態3: ステータスのみ表示
			if uiData.name == "StatusUI" then
				isVisible = true
			else
				isVisible = false
			end
		elseif uiState == 4 then
			-- ★ 状態4: ステータスとミニマップのみ表示
			if uiData.name == "StatusUI" or uiData.name == "Minimap" then
				isVisible = true
			else
				isVisible = false
			end
		end

		-- システムUI の場合
		if uiData.isSystemUI then
			pcall(function()
				StarterGui:SetCore("TopbarEnabled", isVisible)
			end)
			print(("[UIToggleManager]  > %s: %s"):format(uiData.name, isVisible and "表示" or "非表示"))
		else
			-- 通常の UI
			local element = uiData.find()
			if element then
				if element:IsA("ScreenGui") then
					element.Enabled = isVisible
				else
					element.Visible = isVisible
				end
				print(("[UIToggleManager]  > %s: %s"):format(uiData.name, isVisible and "表示" or "非表示"))
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
		-- ★ 状態を切り替える (1 -> 2 -> 3 -> 4 -> 1)
		uiState = uiState + 1
		if uiState > 4 then
			uiState = 1 -- 4の次は1に戻る
		end

		-- 新しい関数を呼び出す
		updateUIVisibility()
	end
end)

print("[UIToggleManager] 初期化完了")
print("[UIToggleManager] Q キーで UI の表示/非表示を切り替えられます (4段階)")
