return {
	name = "ContinentArena",
	displayName = "Arena",

	islands = {
		"Arena_01",
		"Arena_02",
	},

	bridges = {},

	paths = {},

	-- ★修正: 北海道、四国、九州へのポータルを追加
	fieldObjects = {
		{
			model = "PortalBack",
			position = { 10008.8, 156.0, 1.1 },
			mode = "ground",
			size = 1,
			rotation = { 0, 0, 0 },
			stickToGround = false,
		},
	},

	fieldObjects = {},

	BGM = "rbxassetid://139951867631287", -- 後でアセットIDに変更
	BGMVolume = 0.2,
}
