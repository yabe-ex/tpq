-- ===== ./ReplicatedStorage/Islands/Registry.lua =====
-- ReplicatedStorage/Islands/Registry.lua (全コード)
local RS = game:GetService("ReplicatedStorage")
local IslandsFolder = RS:WaitForChild("Islands")

local allIslands = {}

-- 島定義のリスト
local islandModules = {
	IslandsFolder:WaitForChild("Town"), -- 【修正】Town.lua を参照
	IslandsFolder:WaitForChild("HokkaidoIslands"),
	IslandsFolder:WaitForChild("ShikokuIslands"),
	IslandsFolder:WaitForChild("KyushuIslands"),
	IslandsFolder:WaitForChild("Snowland"),
	IslandsFolder:WaitForChild("BananaLand"),
	IslandsFolder:WaitForChild("Vendant"),
	IslandsFolder:WaitForChild("Vendant2"),
	IslandsFolder:WaitForChild("Vendant3"),
	IslandsFolder:WaitForChild("Hokkaido"),
}

-- 各モジュールを読み込み
for _, module in ipairs(islandModules) do
	local result = require(module)

	-- Town (単一テーブル) と Hokkaido (配列) の両方を処理
	if result and result.name then
		-- 単一の島定義 (Town)
		table.insert(allIslands, result)
	elseif type(result) == "table" and #result > 0 then
		-- 複数の島定義（配列, Hokkaido）
		for _, island in ipairs(result) do
			if island and island.name then
				table.insert(allIslands, island)
			else
				warn(
					("[Islands/Registry] '%s' から取得したリストに無効な要素があります"):format(
						module.Name
					)
				)
			end
		end
	else
		warn(("[Islands/Registry] 不正な島定義: '%s'"):format(module.Name))
	end
end

print(("[Islands/Registry] 合計 %d 個の島を読み込みました"):format(#allIslands))

return allIslands
