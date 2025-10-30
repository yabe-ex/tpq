return {
	name = "ContinentHokkaido",
	displayName = "Hokkaido Continent",

	islands = {
		"Hokkaido_W0",
		"Hokkaido_W1",
		"Hokkaido_C1",
		"Hokkaido_C2",
		"Hokkaido_C3",
		"Hokkaido_C4",
		"Hokkaido_C5",
		"Hokkaido_E1",
		"Hokkaido_N1",
		"Hokkaido_N2",
		"Hokkaido_N3",
		"Hokkaido_N4",
		"Hokkaido_NE1",
		"Hokkaido_NE2",
		"Hokkaido_S1",
		"Hokkaido_S2",
		"Hokkaido_SW1",
		"Hokkaido_SW2",
	},

	bridges = {},

	paths = {
		points = {
			{ 3069.8, 17.0, -54.5 },
			{ 3126.1, 22.5, -9.5 },
			{ 3153.8, 24.5, 5.8 },
			{ 3174.6, 19.9, 34.8 },
			{ 3209.4, 16.1, 60.0 },
			{ 3228.9, 16.2, 87.7 },
			{ 3244.1, 16.1, 111.2 },
		},
		width = 24, -- 道の幅（stud）
		method = "terrain", -- "terrain"（地形を塗る） or "parts"（パーツ敷き）
		material = Enum.Material.Ground, -- method="terrain"時の塗り材質
		step = 3, -- サンプリング間隔（小さいほど滑らか＆重い）
		alignToSlope = false, -- 斜面に道面を傾けるか（見た目：true、歩きやすさ：false）
		groundOffset = 4.8, -- めり込み回避の微小オフセット
	},

	portals = {
		{
			name = "Hokkaido_to_Town",
			toZone = "ContinentTown",
			islandName = "Hokkaido_C3",
			offsetX = 0,
			offsetZ = 0,
			label = "→ Town",
			color = Color3.fromRGB(255, 200, 100),
		},
	},

	fieldObjects = {
		{
			model = "Tree1",
			position = { 3237.0, 22.0, -10.8 },
			size = 1.5,
			rotation = { 0, 0, 0 },
			stickToGround = true, -- 省略可（trueが既定）
			groundOffset = 0.15, -- 芝生で少し浮かせたい時
			alignToSlope = true, -- 斜面に木を傾けたくないならfalse
		},
		{
			model = "Tree1",
			position = { 3092.5, 9.1, -175.5 },
			size = 1.0,
			rotation = { 0, 0, 0 },
			stickToGround = true, -- 省略可（trueが既定）
			groundOffset = 0.15, -- 芝生で少し浮かせたい時
			alignToSlope = true, -- 斜面に木を傾けたくないならfalse
		},

		{
			model = "Tree1",
			position = { 3118.2, 7.3, -182.6 },
			size = 1.0,
			rotation = { 0, 30, 0 },
			stickToGround = true, -- 省略可（trueが既定）
			groundOffset = 0.15, -- 芝生で少し浮かせたい時
			alignToSlope = true, -- 斜面に木を傾けたくないならfalse
		},

		{
			model = "Small House",
			position = { 3080.8, 32.0, -162.8 },
			size = 1.8,
			rotation = { 0, 180, 0 },
			stickToGround = false, -- 省略可（trueが既定）
			groundOffset = 0.15, -- 芝生で少し浮かせたい時
			alignToSlope = false, -- 斜面に木を傾けたくないならfalse
		},

		{
			-- model = "Chest",
			model = "koki3D",
			position = { -0.0, 56.3, -12.0 },
			size = 1.0,
			rotation = { 0, 0, 0 },
			stickToGround = true, -- 省略可（trueが既定）
			groundOffset = 0, -- 芝生で少し浮かせたい時
			alignToSlope = true, -- 斜面に木を傾けたくないならfalse
		},

		{
			model = "box_closed",
			position = { 3152.0, 59.5, -75.2 },
			mode = "fixed",
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
				chestId = "hokkaido_chest_01", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ポーション", count = 2 },
					{ item = "ゴールド", count = 45 },
				},
				displayDuration = 3, -- 報酬表示時間（秒）
			},
		},

		{
			model = "box_closed",
			position = { 2997.1, 28.9, 10.8 },
			mode = "fixed",
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
				chestId = "hokkaido_chest_02", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ポーション", count = 2 },
				},
				displayDuration = 10, -- 報酬表示時間（秒）
			},
		},

		{
			model = "box_closed",
			position = { 3125.8, 47.2, -60.7 },
			mode = "fixed",
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
				chestId = "hokkaido_chest_03", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ゴールド", count = 120 },
				},
				displayDuration = 3, -- 報酬表示時間（秒）
			},
		},

		{
			model = "box_closed",
			position = { 3136.9, 47.1, -49.5 },
			mode = "fixed",
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
				chestId = "hokkaido_chest_04", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ゴールド", count = 70 },
				},
				displayDuration = 3, -- 報酬表示時間（秒）
			},
		},

		{
			model = "box_closed",
			position = { 3125.2, 48.0, -65.6 },
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
				chestId = "hokkaido_chest_05", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ゴールド", count = 50 },
				},
				displayDuration = 3, -- 報酬表示時間（秒）
			},
		},
		{
			model = "box_closed",
			position = { 3140.0, 234.3, -140.9 },
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
				chestId = "hokkaido_chest_05", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ゴールド", count = 500000 },
				},
				displayDuration = 3, -- 報酬表示時間（秒）
			},
		},
	},

	BGM = "rbxassetid://115666507179769", -- 後でアセットIDに変更
	BGMVolume = 0.2, -- 音量（0.0-1.0）
}
