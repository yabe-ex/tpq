-- ReplicatedStorage/Islands/Town.lua (4つの島で構成されるTownエリア - 重複版)

return {
	-- 1. StartTown (North-West, メインスポーン地点)
	{
		name = "StartTown",
		centerX = 10050, -- ★修正: -100から-50へ (X:-150〜150)
		centerZ = 50, -- ★修正: 100から50へ (Z:-150〜150)
		sizeXZ = 200,
		baseY = 50,
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
		name = "Town_NE",
		centerX = 11100, -- ★修正: 100から50へ
		centerZ = 50, -- ★修正: 100から50へ
		sizeXZ = 200,
		baseY = 50,
		thickness = 8,
		grid = 10,
		hillAmplitude = 3,
		hillScale = 80,
		seed = 77778,
		generateOcean = false,
		safeZone = true,
		baseMaterial = Enum.Material.Slate,
	},

	-- 3. Town_SW (South-West)
	{
		name = "Town_SW",
		centerX = 10050, -- ★修正: -100から-50へ
		centerZ = -50, -- ★修正: -100から-50へ
		sizeXZ = 200,
		baseY = 50,
		thickness = 8,
		grid = 10,
		hillAmplitude = 3,
		hillScale = 80,
		seed = 77779,
		generateOcean = false,
		safeZone = true,
		baseMaterial = Enum.Material.Slate,
	},

	-- 4. Town_SE (South-East)
	{
		name = "Town_SE",
		centerX = 10100, -- ★修正: 100から50へ
		centerZ = -50, -- ★修正: -100から-50へ
		sizeXZ = 200,
		baseY = 50,
		thickness = 8,
		grid = 10,
		hillAmplitude = 3,
		hillScale = 80,
		seed = 77780,
		generateOcean = false,
		safeZone = true,
		baseMaterial = Enum.Material.Slate,
	},
}
