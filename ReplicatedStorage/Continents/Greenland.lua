return {
	name = "VerdantPlateau",
	displayName = "緑の大陸",
	islands = {
		"VerdantPlateau_C1",
		"VerdantPlateau_C2",
		"VerdantPlateau_C3",
		"VerdantPlateau_C4",
	},
	paths = {
		{
			name = "MainRoad01",
			points = {
				{ 2720, 10, -220 },
				{ 2850, 10, -120 },
				{ 3000, 10, 0 },
				{ 3150, 10, 40 },
				{ 3280, 10, 60 },
			},
			width = 20,
			method = "terrain",
			material = Enum.Material.Ground,
			step = 3,
			alignToSlope = false,
			groundOffset = 0.05,
		},
	},
	{
		model = "Tree1",
		position = { 2783.8, 25.5, -62.1 },
		size = 1.8,
		rotation = { 0, 180, 0 },
		stickToGround = true, -- 省略可（trueが既定）
		groundOffset = 0.15, -- 芝生で少し浮かせたい時
		alignToSlope = true, -- 斜面に木を傾けたくないならfalse
	},
	{
		model = "Chest",
		position = { 2799.3, 25.2, -99.8 },
		size = 1.8,
		rotation = { 0, 180, 0 },
		stickToGround = true, -- 省略可（trueが既定）
		groundOffset = 0.15, -- 芝生で少し浮かせたい時
		alignToSlope = true, -- 斜面に木を傾けたくないならfalse
	},

	fieldObjects = {},
	BGM = "",
	BGMVolume = 0.2,
}
