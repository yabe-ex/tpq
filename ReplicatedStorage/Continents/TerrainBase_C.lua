-- ReplicatedStorage/Continents/TerrainBase_C.lua

local continent = {
	name = "TerrainBase",
	displayName = "ベースキャンプ",
	spawnPosition = { 377.3, 5131.0, 112.4 }, -- プレイヤーの初期スポーン位置
	portals = {
		{
			isFastTravelTarget = true,
			name = "北海道へ",
			toZone = "Hokkaido_C",
			position = { 377.3, 5131.0, 112.4 }, -- Terrain上の設置座標 (Y座標を元に戻す)
			spawnPosition = { 128.3, 31.1, 782.6 }, -- Hokkaido_C のワープ先座標
			targetPosition = { 128.3, 31.1, 782.6 }, -- Hokkaido_C のワープ先座標
			model = "Door",
			label = "→ 北海道へ",
			snapToGround = true,
			heightOffset = 0,
			rotate = true,
			rotation = { 0, 90, 0 },
			isTerrain = true,
		},
		{
			isFastTravelTarget = true,
			name = "九州へ",
			toZone = "Kyusyu_C",
			position = { 377.3, 5131.0, -112.4 }, -- Terrain上の設置座標 (Y座標を元に戻す)
			spawnPosition = { 447.2, 31.3, 685.2 }, -- Kyusyu_C のワープ先座標
			targetPosition = { 447.2, 31.3, 685.2 }, -- Kyusyu_C のワープ先座標
			model = "Door",
			label = "→ 九州へ",
			snapToGround = true,
			heightOffset = 0,
			rotate = true,
			rotation = { 0, 90, 0 },
			isTerrain = true,
		},
	},
}

return continent
