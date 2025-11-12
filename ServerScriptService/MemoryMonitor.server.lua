-- ServerScriptService/MemoryMonitor.server.lua
print("[MemoryMonitor] 起動")

local ZoneManager = require(game:GetService("ServerScriptService"):WaitForChild("ZoneManager"))

task.spawn(function()
	while true do
		task.wait(10) -- 10秒ごと

		print("\n========== メモリ監視 ==========")

		-- ActiveZones を表示
		local activeZones = {}
		for zoneName, _ in pairs(ZoneManager.ActiveZones) do
			table.insert(activeZones, zoneName)
		end
		-- print("ロード済み大陸:", table.concat(activeZones, ", ") or "なし")
		-- print("大陸数:", #activeZones)

		-- モンスター数
		local monsterCount = 0
		for _, model in ipairs(workspace:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("IsEnemy") then
				monsterCount = monsterCount + 1
			end
		end
		print("モンスター数:", monsterCount)

		local monstersByZone = {}
		for _, model in ipairs(workspace:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("IsEnemy") then
				local spawnZone = model:GetAttribute("SpawnZone")
				monstersByZone[spawnZone] = (monstersByZone[spawnZone] or 0) + 1
			end
		end
		print("モンスター詳細:", monstersByZone)

		-- workspace の子要素数
		print("Workspace 子要素数:", #workspace:GetChildren())

		-- ポータル数
		local portalCount = 0
		local worldFolder = workspace:FindFirstChild("World")
		if worldFolder then
			for _, child in ipairs(worldFolder:GetChildren()) do
				if child:IsA("Part") and child:GetAttribute("FromZone") then
					portalCount = portalCount + 1
				end
			end
		end
		print("ポータル数:", portalCount)

		print("================================\n")
	end
end)

print("[MemoryMonitor] モニター開始（10秒ごと）")
