return {
	name = "VerdantContinent",
	displayName = "Verdant Continent",
	islands = {
		"Town_00",
		"Town_01",
		"Town_02",
		"Town_03",
		"Town_04",
		"Town_05",
	},
	paths = {
		-- {
		-- 	name = "MainTrail01",
		-- 	points = {
		-- 		{ 435.8, 31.0, 767.3 },
		-- 		{ 395.0, 40.7, 615.0 },
		-- 		{ 338.2, 74.7, 527.3 },
		-- 		{ 280.7, 45.3, 457.7 },
		-- 		{ 193.0, 40.5, 393.2 },
		-- 		{ 209.9, 38.9, 289.0 },
		-- 		{ 298.9, 34.0, 185.8 },
		-- 		{ 435.2, 31.0, 86.8 },
		-- 	},
		-- 	width = 18,
		-- 	method = "terrain",
		-- 	material = Enum.Material.Ground,
		-- 	step = 3,
		-- 	alignToSlope = false,
		-- 	-- groundOffset = 0.05,
		-- },
		{
			name = "SideRoad",
			type = "road",
			points = {
				{ 435.8, 31.0, 767.3 },
				{ 395.0, 40.7, 615.0 },
				{ 338.2, 74.7, 527.3 },
				{ 280.7, 45.3, 457.7 },
				{ 193.0, 40.5, 393.2 },
				{ 209.9, 38.9, 289.0 },
				{ 298.9, 34.0, 185.8 },
				{ 435.2, 31.0, 86.8 },
			},
			width = 18,
			material = Enum.Material.Concrete,
			step = 3,
			groundOffset = 0.05,
		},

		-- パス3：川（例）
		{
			name = "MountainStream",
			type = "water", -- ← 水流表現
			points = {
				{ 356.8, 35.9, 763.1 },
				{ 348.3, 35.9, 727.6 },
				{ 361.6, 35.9, 683.9 },
				{ 348.2, 39.6, 628.2 },
				{ 331.8, 68.5, 560.2 },
			},
			width = 90, -- 川は幅広く
			material = Enum.Material.Water,
			step = 2, -- より滑らかに
			groundOffset = 0.8, -- 地面より少し下に
			thickness = 3, -- 川の深さ
			-- embankmentWidth = 6, -- ← 4 や 6 ではなく 2 にしてみる
			-- embankmentHeight = 2,
			-- embankmentMaterial = Enum.Material.Grass,
		},
		{
			name = "RiverEmbankmentLeft",
			type = "road",
			points = {
				{ 353.8, 35.9, 763.1 },
				{ 345.3, 35.9, 727.6 },
				{ 358.6, 35.9, 683.9 },
				{ 345.2, 39.6, 628.2 },
				{ 328.8, 68.5, 560.2 },
			},
			width = 4,
			material = Enum.Material.Grass,
			step = 3,
			groundOffset = 0.5,
		},
		{
			name = "RiverEmbankmentRight",
			type = "road",
			points = {
				{ 359.8, 35.9, 763.1 },
				{ 351.3, 35.9, 727.6 },
				{ 364.6, 35.9, 683.9 },
				{ 351.2, 39.6, 628.2 },
				{ 336.8, 68.5, 560.2 },
			},
			width = 4,
			material = Enum.Material.Grass,
			step = 3,
			groundOffset = 0.5,
		},
	},
	fieldObjects = {},
	BGM = "",
	BGMVolume = 0.2,
}
