-- ===== ./ReplicatedStorage/Islands/ShikokuIslands.lua (新規) =====
return {
	-- 北部
	{
        name = "Shikoku_N1", centerX = 550, centerZ = 50, sizeXZ = 150, baseY = 10, thickness = 10, grid = 10,
        hillAmplitude = 15, hillScale = 100, seed = 60001, generateOcean = false, baseMaterial = Enum.Material.Sand,
    },
    -- 中央
	{
        name = "Shikoku_C1", centerX = 600, centerZ = 0, sizeXZ = 180, baseY = 10, thickness = 10, grid = 10,
        hillAmplitude = 20, hillScale = 120, seed = 60002, generateOcean = false, baseMaterial = Enum.Material.Sand,
    },
    -- 南部
	{
        name = "Shikoku_S1", centerX = 650, centerZ = -50, sizeXZ = 150, baseY = 10, thickness = 10, grid = 10,
        hillAmplitude = 15, hillScale = 100, seed = 60003, generateOcean = false, baseMaterial = Enum.Material.Sand,
    },
    -- 東部
	{
        name = "Shikoku_E1", centerX = 650, centerZ = 50, sizeXZ = 100, baseY = 10, thickness = 10, grid = 10,
        hillAmplitude = 10, hillScale = 80, seed = 60004, generateOcean = false, baseMaterial = Enum.Material.Sand,
    },
    -- 西部
	{
        name = "Shikoku_W1", centerX = 550, centerZ = -50, sizeXZ = 100, baseY = 10, thickness = 10, grid = 10,
        hillAmplitude = 10, hillScale = 80, seed = 60005, generateOcean = true, oceanRadius = 1000, baseMaterial = Enum.Material.Sand,
    },
}