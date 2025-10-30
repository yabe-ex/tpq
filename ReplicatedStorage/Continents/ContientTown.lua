-- ===== ./ReplicatedStorage/Continents/ContientTown.lua =====
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

	-- ★修正: 北海道、四国、九州へのポータルを追加
	portals = {
		{
			name = "Town_to_Hokkaido",
			toZone = "ContinentHokkaido",
			islandName = "StartTown",
			offsetX = 0,
			offsetZ = -50,
			size = Vector3.new(8, 12, 8),
			color = Color3.fromRGB(200, 200, 255),
			label = "→ Hokkaido",
		},
		-- {
		-- 	name = "Town_to_Shikoku", -- ★新規ポータル
		-- 	toZone = "ContinentShikoku",
		-- 	islandName = "Town_NE",
		-- 	offsetX = 0,
		-- 	offsetZ = 0,
		-- 	size = Vector3.new(8, 12, 8),
		-- 	color = Color3.fromRGB(150, 255, 150),
		-- 	label = "→ Shikoku",
		-- },
		{
			name = "Town_to_Kyushu", -- ★新規ポータル
			toZone = "ContinentKyushu",
			islandName = "Town_SE",
			offsetX = 0,
			offsetZ = 0,
			size = Vector3.new(8, 12, 8),
			color = Color3.fromRGB(255, 100, 100),
			label = "→ Kyushu",
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
			model = "ModernHouse",
			position = { 92.4, 56.5, 30.9 },
			mode = "ground",
			size = 1,
			rotation = { 0, -45, 45 },
			-- rotation = { 0, 0, 0 },
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
	--m

	BGM = "rbxassetid://139951867631287", -- 後でアセットIDに変更
	BGMVolume = 0.2,
}
