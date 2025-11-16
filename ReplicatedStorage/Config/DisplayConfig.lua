--!strict
-- ReplicatedStorage/Config/DisplayConfig.lua
-- 大陸名を配列で指定して、島ラベル（BillboardGui）表示の対象を切り替える設定モジュール。
-- どこから呼ばれても落ちないように、nilガードを徹底。

local M = {}

-- ▼ グローバルON/OFF
M.enabled = true

-- ▼ ラベルを出す大陸名（複数OK）
--   例: { "BananaLand", "Hokkaido", "Kyushu" }
M.continents = {
	-- "BananaLand",
	-- "ContinentHokkaido",
	-- "ContinentKyushu",
	-- "VerdantContinent",
	-- "Hokkaido_C",
	-- "Kyusyu_C",
}

-- ▼ 既定の表示パラメータ
M.defaults = {
	showIslandLabel = true, -- 基本ON
	labelOffsetY = 6, -- 表面から少し上
	labelMaxDistance = 2000, -- 表示距離
	font = Enum.Font.GothamBold,
	textSize = 16,
	backgroundTransparency = 0.35,
}

-- ▼ 大陸ごとの上書き
--   例: M.overrides["BananaLand"] = { labelOffsetY = 10 }
M.overrides = {}

----------------------------------------------------------------
-- 内部ユーティリティ（nilガード）
----------------------------------------------------------------
local function asArray(t)
	-- 配列でなければ空配列を返す
	if typeof(t) ~= "table" then
		return {}
	end
	return t
end

local function asTable(t)
	if typeof(t) ~= "table" then
		return {}
	end
	return t
end

local function cloneTable(src)
	local dst = {}
	for k, v in pairs(src) do
		dst[k] = v
	end
	return dst
end

----------------------------------------------------------------
-- 公開API
----------------------------------------------------------------

function M.isEnabledFor(continentName: string): boolean
	-- グローバルOFFなら即false
	if M.enabled ~= true then
		return false
	end

	-- continents が不正/未設定でも落ちない
	local list = asArray(M.continents)
	if #list == 0 then
		-- 何も指定されていない場合は「全てOFF」にする運用
		return false
	end

	for _, n in ipairs(list) do
		if n == continentName then
			return true
		end
	end
	return false
end

function M.getParamsFor(continentName: string)
	-- defaults をクローンしてから overrides をマージ
	local params = cloneTable(asTable(M.defaults))
	local ovAll = asTable(M.overrides)
	local ov = ovAll[continentName]
	if typeof(ov) == "table" then
		for k, v in pairs(ov) do
			params[k] = v
		end
	end
	return params
end

return M
