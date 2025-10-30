return {
	{
		name = "Arena_01",
		centerX = 10000, -- ★修正: -100から-50へ (X:-150〜150)
		centerZ = 50, -- ★修正: 100から50へ (Z:-150〜150)
		sizeXZ = 200,
		baseY = 150,
		thickness = 8,
		grid = 10,
		hillAmplitude = 3,
		hillScale = 80,
		seed = 77777,
		generateOcean = true,
		safeZone = true,
		baseMaterial = Enum.Material.Slate,
	},

	-- 2. Town_NE (North-East)
	{
		name = "Arena_02",
		centerX = 10050, -- ★修正: 100から50へ
		centerZ = 50, -- ★修正: 100から50へ
		sizeXZ = 200,
		baseY = 150,
		thickness = 8,
		grid = 10,
		hillAmplitude = 3,
		hillScale = 80,
		seed = 77778,
		generateOcean = false,
		safeZone = true,
		baseMaterial = Enum.Material.Slate,
	},
}
