-- ===== ./ReplicatedStorage/Continents/ContinentTown.lua =====
return {
	name = "ContinentTown",
	displayName = "Start Town",

	islands = {
		"StartTown",
		"Town_NE",
		"Town_SW",
		"Town_SE",
	},

	bridges = {},

	-- ★修正: 北海道、四国、九州へのポータルを追加
	portals = {
		-- {
		-- 	name = "Town_to_Hokkaido",
		-- 	toZone = "ContinentHokkaido",
		-- 	islandName = "StartTown",
		-- 	offsetX = 0,
		-- 	offsetZ = -50,
		-- 	size = Vector3.new(8, 12, 8),
		-- 	color = Color3.fromRGB(200, 200, 255),
		-- 	label = "→ Hokkaido",
		-- },
		-- {
		-- 	name = "Town_to_Kyushu", -- ★新規ポータル
		-- 	toZone = "ContinentKyushu",
		-- 	islandName = "Town_SE",
		-- 	offsetX = 0,
		-- 	offsetZ = 0,
		-- 	size = Vector3.new(8, 12, 8),
		-- 	color = Color3.fromRGB(255, 100, 100),
		-- 	label = "→ Kyushu",
		-- },

		-- {
		-- 	name = "Hokkaido_20", -- ★新規ポータル
		-- 	toZone = "Hokkaido_C",
		-- 	islandName = "Town_SW",
		-- 	offsetX = 0,
		-- 	offsetZ = 0,
		-- 	size = Vector3.new(8, 12, 8),
		-- 	color = Color3.fromRGB(255, 100, 100),
		-- 	label = "→ 北海道へ",
		-- },
		-- {
		-- 	name = "Portal_02",
		-- 	zone = "Hokkaido_C",
		-- 	position = { 10083.2, 57.2, 50.4 }, -- ★絶対座標
		-- 	toZone = "Kyusyu_C",
		-- 	model = "crystal1",
		-- 	size = 1.5,
		-- 	label = "→ 九州へ",
		-- 	rotate = true,
		-- },
		{
			name = "Portal_02",
			islandName = "Kyusyu_01",
			toZone = "Kyusyu_C",
			position = { 10029.4, 57.5, 57.5 }, -- ★絶対座標
			model = "crystal1",
			size = 1.5,
			label = "→ 九州へ",
			snapToGround = true,
			rotate = true,
		},
		{
			name = "Portal_Terrain",
			isTerrain = true, -- Terrainモード
			position = { 10028.4, 59.5, 52.5 }, -- 現在ポータルの設置位置
			targetPosition = { 574.1, 5381.9, -770.1 }, -- ワープ先のTerrain座標（★新フィールド）
			model = "crystal1",
			size = 1.5,
			label = "→ 大地へ",
			rotate = true,
			snapToGround = true,
		},
	},

	fieldObjects = {
		{
			model = "Chest",
			position = { 55, 78, -5.8 },
			mode = "ground",
			size = 1.5,
			rotation = { 0, 0, 0 },
			groundOffset = 0, -- 芝生で少し浮かせたい時
			alignToSlope = true, -- 斜面に木を傾けたくないならfalse
		},
		{
			model = "koki3D",
			position = { 58.7, 78, -5.8 },
			mode = "ground",
			size = 1,
			rotation = { 0, 0, 0 },
			stickToGround = false, -- 省略可（trueが既定）
			groundOffset = 0, -- 芝生で少し浮かせたい時
			alignToSlope = true, -- 斜面に木を傾けたくないならfalse
		},

		{
			model = "koki3D",
			position = { 26.1, 57.6, -9.5 },
			mode = "ground",
			size = 0.2,
			rotation = { 0, 0, 0 },
			stickToGround = false, -- 省略可（trueが既定）
			groundOffset = 0, -- 芝生で少し浮かせたい時
			alignToSlope = true, -- 斜面に木を傾けたくないならfalse
		},

		{
			model = "muichiro",
			position = { 23.2, 57.5, -15.2 },
			mode = "fixed",
			size = 0.2,
			rotation = { 0, 0, 0 },
			stickToGround = false, -- 省略可（trueが既定）
			groundOffset = 10, -- 芝生で少し浮かせたい時
			alignToSlope = true, -- 斜面に木を傾けたくないならfalse
			-- upAxis = "",
		}, --

		{
			model = "box_closed",
			position = { 42.4, 56.5, 10.9 },
			mode = "ground",
			size = 1,
			rotation = { 0, 0, 0 },
			stickToGround = false, -- 省略可（trueが既定）
			groundOffset = 0, -- 芝生で少し浮かせたい時
			alignToSlope = false, -- 斜面に木を傾けたくないならfalse

			interaction = {
				type = "chest", -- インタラクションタイプ
				action = "開ける", -- ボタンに表示されるテキスト
				key = "E", -- キーバインド
				range = 8, -- インタラクション可能距離（スタッド）

				-- 宝箱固有の情報
				chestId = "town_chest_01", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ポーション", count = 3 },
					{ item = "ゴールド", count = 50 },
				},
				displayDuration = 3, -- 報酬表示時間（秒）
			},
		},

		{
			model = "box_closed",
			position = { 42.4, 56.5, 20.9 },
			mode = "ground",
			size = 1,
			rotation = { 0, 0, 0 },
			stickToGround = false, -- 省略可（trueが既定）
			groundOffset = 0, -- 芝生で少し浮かせたい時
			alignToSlope = false, -- 斜面に木を傾けたくないならfalse

			interaction = {
				type = "chest", -- インタラクションタイプ
				action = "開ける", -- ボタンに表示されるテキスト
				key = "E", -- キーバインド
				range = 8, -- インタラクション可能距離（スタッド）

				-- 宝箱固有の情報
				chestId = "town_chest_02", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ポーション", count = 1 },
					{ item = "ゴールド", count = 25 },
				},
				displayDuration = 3, -- 報酬表示時間（秒）
			},
		},

		{
			model = "PortalToArena",
			position = { 92.4, 56.5, 30.9 },
			mode = "ground",
			size = 1,
			rotation = { 0, -45, 45 },
			stickToGround = false, -- 省略可（trueが既定）
			groundOffset = 0, -- 芝生で少し浮かせたい時
			alignToSlope = false, -- 斜面に木を傾けたくないならfalse
		},

		{
			model = "golem",
			position = { 31.9, 56.5, 10.9 },
			mode = "ground",
			size = 0.1,
			rotation = { 0, 0, 0 },
			stickToGround = false, -- 省略可（trueが既定）
			alignToSlope = false, -- 斜面に木を傾けたくないならfalse
		},
	},

	BGM = "rbxassetid://139951867631287", -- 後でアセットIDに変更
	BGMVolume = 0.2,
}
