-- ReplicatedStorage/SharedState.lua
-- 共有状態管理（循環依存を防ぐための中央データストア）

local SharedState = {}

-- モンスター関連
SharedState.MonsterCounts = {}
-- 形式: {[zoneName] = {[monsterName] = count}}
-- 例: {["ContinentA"] = {["Slime"] = 5, ["Mage"] = 3}}

SharedState.SpawnQueue = {}
-- リスポーン待ちのモンスター情報

-- バトル関連
SharedState.ActiveBattles = {}
-- 形式: {[player] = battleData}

-- ゾーン関連
SharedState.PlayerZones = {}
-- 形式: {[player] = zoneName}

-- ロック管理（非同期処理の排他制御用）
SharedState.Locks = {}
-- 形式: {[lockName] = boolean}

-- デバッグ用
function SharedState.printState()
	print("[SharedState] === Current State ===")
	print("MonsterCounts:", game:GetService("HttpService"):JSONEncode(SharedState.MonsterCounts))
	print("ActiveBattles:", #SharedState.ActiveBattles)
	print("PlayerZones:", game:GetService("HttpService"):JSONEncode(SharedState.PlayerZones))
	print("Locks:", game:GetService("HttpService"):JSONEncode(SharedState.Locks))
end

print("[SharedState] Module initialized")

return SharedState