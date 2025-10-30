-- StarterPlayer/StarterPlayerScripts/StatBuffManager.client.lua
-- ステータスバフシステム＋JumpPowerに応じた多段ジャンプ

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
print("[StatBuffManager] 初期化開始")

-- バフレベル管理
local buffState = {
	WalkSpeed = 1.0,
	JumpPower = 1.0,
}

-- デフォルト値
local defaultStats = {
	WalkSpeed = 16,
	JumpPower = 50,
	JumpHeight = 7.2,
}

-- ★ 多段ジャンプ管理（JumpPowerレベルに応じて制御）
local multiJumpState = {
	jumpsRemaining = 0,
	lastJumpTime = 0,
	jumpCooldown = 0.1, -- ジャンプ間のクールタイム（秒）
}

-- ★ 汎用バフ適用関数
local function applyStatBuff(statName, multiplier)
	local character = player.Character
	if not character then
		warn("[StatBuffManager] キャラクターが見つかりません")
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[StatBuffManager] Humanoid が見つかりません")
		return false
	end

	multiplier = math.clamp(tonumber(multiplier) or 1, 0.5, 10)

	if statName == "WalkSpeed" then
		local newSpeed = defaultStats.WalkSpeed * multiplier
		humanoid.WalkSpeed = newSpeed
		print(
			("[StatBuffManager] WalkSpeed: %.1f → %.1f (倍率: %.1f倍)"):format(
				defaultStats.WalkSpeed,
				newSpeed,
				multiplier
			)
		)
		return true
	elseif statName == "JumpPower" then
		local newPower = defaultStats.JumpPower * multiplier
		humanoid.JumpPower = newPower
		humanoid.JumpHeight = defaultStats.JumpHeight * multiplier
		print(
			("[StatBuffManager] JumpPower: %.1f → %.1f (倍率: %.1f倍)"):format(
				defaultStats.JumpPower,
				newPower,
				multiplier
			)
		)
		return true
	else
		warn(("[StatBuffManager] 未知のステータス: %s"):format(statName))
		return false
	end
end

-- ★ バフレベルをサイクル
local buffMultipliers = { 1.0, 2.0, 3.0, 4.0, 8.0, 16.0 }

local function cycleBuffLevel(statName)
	local currentLevel = buffState[statName] or 1.0
	local currentIndex = 1

	for i, mult in ipairs(buffMultipliers) do
		if math.abs(mult - currentLevel) < 0.01 then
			currentIndex = i
			break
		end
	end

	local nextIndex = (currentIndex % #buffMultipliers) + 1
	local nextLevel = buffMultipliers[nextIndex]

	buffState[statName] = nextLevel
	applyStatBuff(statName, nextLevel)

	print(("[StatBuffManager] %s レベル: %d/6 (倍率: %.1f倍)"):format(statName, nextIndex, nextLevel))

	return nextLevel
end

-- キャラクター生成時にバフ状態をリセット
player.CharacterAdded:Connect(function(character)
	print("[StatBuffManager] 新しいキャラクターが生成されました")

	buffState.WalkSpeed = 1.0
	buffState.JumpPower = 1.0

	-- ★ 多段ジャンプをリセット
	multiJumpState.jumpsRemaining = 0
	multiJumpState.lastJumpTime = 0

	task.wait(0.1)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = defaultStats.WalkSpeed
		humanoid.JumpPower = defaultStats.JumpPower
		humanoid.JumpHeight = defaultStats.JumpHeight
		print("[StatBuffManager] デフォルト値をリセット完了")
	end
end)

-- ★ 多段ジャンプの状態管理（地面着地判定）
local lastYPosition = 0
RunService.Heartbeat:Connect(function()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		return
	end

	local jumpPowerLevel = tonumber(buffState.JumpPower) or 1.0
	local maxJumps = math.floor(jumpPowerLevel)

	-- ★ Raycast で地面判定
	local rayOrigin = hrp.Position
	local rayDirection = Vector3.new(0, -5, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local rayResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)

	-- 地面から 5 Stud以内なら着地判定
	if rayResult and rayResult.Distance < 5 then
		multiJumpState.jumpsRemaining = maxJumps
	end

	lastYPosition = hrp.Position.Y
end)

-- ★ スペースキーで多段ジャンプ
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Space then
		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local jumpPowerLevel = tonumber(buffState.JumpPower) or 1.0

		-- JumpPowerレベルが2以上で、かつジャンプが残っている場合
		if jumpPowerLevel >= 2.0 and multiJumpState.jumpsRemaining > 0 then
			-- クールタイム確認
			local currentTime = tick()
			if currentTime - multiJumpState.lastJumpTime >= multiJumpState.jumpCooldown then
				-- ジャンプを実行
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				multiJumpState.jumpsRemaining -= 1
				multiJumpState.lastJumpTime = currentTime

				print(("[StatBuffManager] 追加ジャンプ！ 残り: %d回"):format(multiJumpState.jumpsRemaining))
			end
		end
	end
end)

-- WalkSpeedバフ（0 キー）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Zero then
		cycleBuffLevel("WalkSpeed")
	end
end)

-- JumpPowerバフ（- キー）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Minus then
		print("[StatBuffManager] - キーが押されました")
		cycleBuffLevel("JumpPower")
	end
end)

-- ★ 外部から呼び出せるAPI
_G.StatBuffManager = {
	applyStatBuff = applyStatBuff,
	getBuffLevel = function(statName)
		return buffState[statName] or 1.0
	end,
	resetBuffs = function()
		buffState.WalkSpeed = 1.0
		buffState.JumpPower = 1.0
		multiJumpState.jumpsRemaining = 0
		applyStatBuff("WalkSpeed", 1.0)
		applyStatBuff("JumpPower", 1.0)
		print("[StatBuffManager] すべてのバフをリセット")
	end,
}

print("[StatBuffManager] 初期化完了")
print("[StatBuffManager] 0 キー: WalkSpeed バフ (1.0x → 2.0x → 3.0x → 4.0x → 8.0x → 16.0x)")
print("[StatBuffManager] - キー: JumpPower バフ (1.0x → 2.0x → 3.0x → 4.0x → 8.0x → 16.0x)")
print("[StatBuffManager] ★ JumpPower が 2.0x 以上の場合、スペース連打で多段ジャンプ可能")
