-- ===== ./ReplicatedStorage/Continents/ContinentShikoku.lua (新規) =====
return {
	name = "ContinentShikoku",
	displayName = "Shikoku Region",

	islands = {
		"Shikoku_N1", "Shikoku_C1", "Shikoku_S1",
		"Shikoku_E1", "Shikoku_W1",
	},

	bridges = {},

	portals = {
		{
			name = "Shikoku_to_Town",
			toZone = "ContinentTown",
			islandName = "Shikoku_C1", -- 中央の島からポータル
			offsetX = 0,
			offsetZ = 0,
			label = "→ Town",
			color = Color3.fromRGB(150, 255, 150), -- 緑色のポータル
		}
	},

	BGM = "rbxassetid://139951867631287", -- 後でアセットIDに変更
	BGMVolume = 0.3,
}