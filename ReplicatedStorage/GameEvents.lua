-- ReplicatedStorage/GameEvents.lua
-- イベント駆動通信システム（循環依存を防ぐための通信レイヤー）

local GameEvents = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- イベント格納用フォルダを作成
local eventFolder = ReplicatedStorage:FindFirstChild("GameEventBindables")
if not eventFolder then
	eventFolder = Instance.new("Folder")
	eventFolder.Name = "GameEventBindables"
	eventFolder.Parent = ReplicatedStorage
end

-- イベントを取得または作成
local function getOrCreateEvent(name)
	local event = eventFolder:FindFirstChild(name)
	if not event then
		event = Instance.new("BindableEvent")
		event.Name = name
		event.Parent = eventFolder
		print(("[GameEvents] Created event: %s"):format(name))
	end
	return event
end

-- モンスター関連イベント
GameEvents.MonsterCountRequest = getOrCreateEvent("MonsterCountRequest")
GameEvents.MonsterCountResponse = getOrCreateEvent("MonsterCountResponse")
GameEvents.MonsterSpawned = getOrCreateEvent("MonsterSpawned")
GameEvents.MonsterDespawned = getOrCreateEvent("MonsterDespawned")

-- セーブ/ロード関連イベント
GameEvents.SaveRequest = getOrCreateEvent("SaveRequest")
GameEvents.SaveComplete = getOrCreateEvent("SaveComplete")
GameEvents.LoadComplete = getOrCreateEvent("LoadComplete")

-- ゾーン関連イベント
GameEvents.ZoneChanged = getOrCreateEvent("ZoneChanged")
GameEvents.ZoneLoadStart = getOrCreateEvent("ZoneLoadStart")
GameEvents.ZoneLoadComplete = getOrCreateEvent("ZoneLoadComplete")

-- バトル関連イベント
GameEvents.BattleStateChanged = getOrCreateEvent("BattleStateChanged")

-- ヘルパー関数：イベント発火（デバッグログ付き）
function GameEvents.Fire(eventName, ...)
	local event = GameEvents[eventName]
	if event then
		print(("[GameEvents] Firing: %s"):format(eventName))
		event:Fire(...)
	else
		warn(("[GameEvents] Event not found: %s"):format(eventName))
	end
end

-- ヘルパー関数：イベント待機（タイムアウト付き）
function GameEvents.Wait(eventName, timeout)
	local event = GameEvents[eventName]
	if not event then
		warn(("[GameEvents] Event not found: %s"):format(eventName))
		return nil
	end

	timeout = timeout or 5
	local startTime = tick()
	local result = nil

	local connection
	connection = event.Event:Connect(function(...)
		result = {...}
	end)

	-- タイムアウト待機
	while not result and (tick() - startTime) < timeout do
		task.wait(0.1)
	end

	connection:Disconnect()

	if not result then
		warn(("[GameEvents] Timeout waiting for: %s"):format(eventName))
	end

	return result and unpack(result) or nil
end

print("[GameEvents] Module initialized")

return GameEvents