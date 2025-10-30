-- ServerScriptService/ResetSave.server.lua
-- 「初期化する」ボタンからのリクエストを処理して、セーブを消去＆Lv1初期化

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- RemoteEvents（無ければ作る）
local function getOrCreateEvent(name)
	local ev = ReplicatedStorage:FindFirstChild(name)
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = ReplicatedStorage
	end
	return ev
end

local ResetSaveRequest = getOrCreateEvent("ResetSaveRequest")
local ResetSaveResult  = getOrCreateEvent("ResetSaveResult")

-- 依存モジュール
local okPS, PlayerStats = pcall(function()
	return require(ServerScriptService:WaitForChild("PlayerStats"))
end)
local okDM, DataStoreManager = pcall(function()
	return require(ServerScriptService:WaitForChild("DataStoreManager"))
end)
local okDC, DataCollectors = pcall(function()
	return require(ServerScriptService:WaitForChild("DataCollectors"))
end)

-- 初期値を上書きセーブするヘルパ
local function saveDefaults(player)
	if not okPS then return false, "PlayerStats not found" end

	local defaults = {
		Level = 1,
		Experience = 0,
		MaxHP = 100,
		CurrentHP = 100,
		Attack = 10,
		Defense = 10,
		Speed = 10,
		Gold = 0,
		MonstersDefeated = 0,
	}

	-- 手元の PlayerStats に setter が無ければ stats テーブルを直書き（存在するならそちらを優先）
	local stats = PlayerStats.getStats and PlayerStats.getStats(player)
	if stats then
		for k,v in pairs(defaults) do
			stats[k] = v
		end
	else
		-- 何も無ければ諦める
		return false, "Player stats not available"
	end

	-- DataCollectors + DataStoreManager でセーブ（存在すれば）
	if okDM and okDC and DataCollectors.createSaveData and DataStoreManager.SaveData then
		local saveData = DataCollectors.createSaveData(player, stats)
		local ok = DataStoreManager.SaveData(player, saveData)
		if not ok then
			return false, "Save failed"
		end
	end

	return true
end

-- セーブの消去（モジュールが持っていれば使う／無ければ上書き保存で実質初期化）
local function wipeSave(player)
	-- DataStoreManager に Delete/Wipe 系があれば使う
	for _, fn in ipairs({"DeleteData", "WipeData", "RemoveData", "ResetData"}) do
		if okDM and type(DataStoreManager[fn]) == "function" then
			local ok, err = pcall(function()
				return DataStoreManager[fn](player)
			end)
			if ok then return true end
			warn("[ResetSave] DataStoreManager."..fn.." failed:", err)
		end
	end
	-- 無ければ「初期値で上書き保存」をフォールバックとして採用
	local ok, msg = saveDefaults(player)
	return ok, msg
end

ResetSaveRequest.OnServerEvent:Connect(function(player)
	-- 1) セーブ消去
	local ok, msg = wipeSave(player)
	if not ok then
		ResetSaveResult:FireClient(player, false, msg or "wipe failed")
		return
	end

	-- 2) そのまま初期値を反映（メモリ上の値もLv1に）
	local ok2, msg2 = saveDefaults(player)
	if not ok2 then
		ResetSaveResult:FireClient(player, false, msg2 or "apply defaults failed")
		return
	end

	-- 3) 念のためHP全回復＆ステ更新を飛ばす（存在すれば）
	if okPS then
		if type(PlayerStats.fullHeal) == "function" then
			PlayerStats.fullHeal(player)
		end
		if type(PlayerStats.sendStatusUpdate) == "function" then
			PlayerStats.sendStatusUpdate(player)
		end
	end

	-- 完了
	ResetSaveResult:FireClient(player, true)
end)
