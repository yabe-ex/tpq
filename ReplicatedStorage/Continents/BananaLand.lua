return {
	name = "BananaLand",
	displayName = "バナナランド",
	islands = {
		"Banana_C1",
		"Banana_C2",
		"Banana_C3",
		"Banana_C4",
		"Banana_C5",
		"Banana_C6",
		"Banana_C7",
		"Banana_C8",
		"Banana_C9",
		"Banana_C10",
		"Banana_C11",
		"Banana_C12",
		"Banana_C13",
		"Banana_C14",
		"Banana_C15",
		"Banana_C16",
		"Banana_C17",
		"Banana_C18",
		"Banana_C19",
		"Banana_C20",
		"Banana_C21",
		"Banana_C22",
		"Banana_C23",
		"Banana_C24",
		"Banana_C25",
		"Banana_C26",
		"Banana_C27",
		"Banana_C28",
		"Banana_C29",
		"Banana_C30",
		"Banana_C31",
		"Banana_C32",
		"Banana_C33",
		"Banana_C34",
		"Banana_C35",
		"Banana_C36",
		"Banana_C37",
		"Banana_C38",
		"Banana_C39",
		"Banana_C40",
		"Banana_C41",
		"Banana_C42",
		"Banana_C43",
		"Banana_C44",
		"Banana_C45",
		"Banana_C46",
		"Banana_C47",
		"Banana_C48",
		"Banana_C49",
		"Banana_C50",
	},

	paths = {
		points = {
			{ 10101.0, 26.3, 71.1 },
			{ 10075.8, 26.4, 102.6 },
			{ 10038.3, 26.4, 122.0 },
			{ 9995.3, 26.6, 120.9 },
			{ 9957.1, 26.6, 103.3 },
			{ 9934.4, 26.3, 66.2 },
			{ 9901.0, 26.6, 11.6 },
			{ 9855.1, 26.6, -7.1 },
			{ 9927.7, 27.1, 56.1 },
			{ 9954.1, 26.2, 54.9 },
			{ 9985.8, 34.5, 48.5 },
		},
		width = 24, -- 道の幅（stud）
		-- method = "terrain", -- "terrain"（地形を塗る） or "parts"（パーツ敷き）
		material = Enum.Material.Ground, -- method="terrain"時の塗り材質
		step = 3, -- サンプリング間隔（小さいほど滑らか＆重い）
		alignToSlope = false, -- 斜面に道面を傾けるか（見た目：true、歩きやすさ：false）
		groundOffset = 4.8, -- めり込み回避の微小オフセット
	},

	--

	-- paths = {
	-- 	{
	-- 		name = "MainRoad01",
	-- 		points = {
	-- 			{ 12720, 10, -220 },
	-- 			{ 12850, 10, -120 },
	-- 			{ 13000, 10, 0 },
	-- 			{ 13150, 10, 40 },
	-- 			{ 13280, 10, 60 },
	-- 		},
	-- 		width = 20,
	-- 		method = "terrain",
	-- 		material = Enum.Material.Ground,
	-- 		step = 3,
	-- 		alignToSlope = false,
	-- 		groundOffset = 0.05,
	-- 	},
	-- },
	-- {
	-- 	model = "Tree1",
	-- 	position = { 12783.8, 25.5, -62.1 },
	-- 	size = 1.8,
	-- 	rotation = { 0, 180, 0 },
	-- 	stickToGround = true, -- 省略可（trueが既定）
	-- 	groundOffset = 0.15, -- 芝生で少し浮かせたい時
	-- 	alignToSlope = true, -- 斜面に木を傾けたくないならfalse
	-- },
	-- {
	-- 	model = "Chest",
	-- 	position = { 12799.3, 25.2, -99.8 },
	-- 	size = 1.8,
	-- 	rotation = { 0, 180, 0 },
	-- 	stickToGround = true, -- 省略可（trueが既定）
	-- 	groundOffset = 0.15, -- 芝生で少し浮かせたい時
	-- 	alignToSlope = true, -- 斜面に木を傾けたくないならfalse
	-- },

	fieldObjects = {
		{
			model = "box_closed",
			position = { 9938.7, 26.5, 64.1 },
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
				range = 5, -- インタラクション可能距離（スタッド）

				-- 宝箱固有の情報
				chestId = "banana_chest_01", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ポーション", count = 1 },
					{ item = "ゴールド", count = 25 },
				},
				displayDuration = 3, -- 報酬表示時間（秒）
			},
		},
		{
			model = "box_closed",
			position = { 9963.4, 47.0, 105.5 },
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
				range = 5, -- インタラクション可能距離（スタッド）

				-- 宝箱固有の情報
				chestId = "banana_chest_02", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ポーション", count = 1 },
					{ item = "ゴールド", count = 25 },
				},
				displayDuration = 3, -- 報酬表示時間（秒）
			},
		},
	},

	fieldObjects = {},
	BGM = "",
	BGMVolume = 0.2,
}
--
