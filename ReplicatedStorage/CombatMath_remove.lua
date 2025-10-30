-- ReplicatedStorage/CombatMath.lua
local CombatMath = {}

-- 小ユーティリティ
local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function num(v, fallback)
	if typeof(v) == "number" and v == v then
		return v
	end
	return fallback
end

-- プレイヤーSpeedのみ（後方互換）
-- baseInterval: モンスターの基準秒（nil→8）
-- playerSpeed:  プレイヤーのSpeed（nil→10）
function CombatMath.enemyAttackInterval(baseInterval, playerSpeed)
	local base = num(baseInterval, 8)
	local p    = num(playerSpeed, 10)
	-- “pが高いほど敵が遅くなる”調整（0.35 は体感係数）
	local interval = base - (p - 10) * 0.35
	return clamp(interval, 5, 11)
end

-- プレイヤー/モンスター両Speedを使う版（今回はこちらを使用）
-- baseInterval: nil→8, playerSpeed: nil→10, monsterSpeed: nil→10
-- 係数0.25は後で微調整可（0.25〜0.4）
function CombatMath.enemyAttackIntervalWithMSpeed(playerSpeed, monsterSpeed, baseInterval)
	local base = num(baseInterval, 8)
	local p    = num(playerSpeed, 10)
	local m    = num(monsterSpeed, 10)
	local interval = base - (p - m) * 0.25
	return clamp(interval, 5, 11)
end

return CombatMath
