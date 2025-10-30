--- Continents ---
return {
	name = "ContinentKyushu",
	displayName = "ContinentKyushu",
	islands = {
		"ContinentKyushu_C1",
		"ContinentKyushu_C2",
		"ContinentKyushu_C3",
		"ContinentKyushu_C4",
		"ContinentKyushu_C5",
		"ContinentKyushu_C6",
		"ContinentKyushu_C7",
		"ContinentKyushu_C8",
		"ContinentKyushu_C9",
		"ContinentKyushu_C10",
		"ContinentKyushu_C11",
		"ContinentKyushu_C12",
		"ContinentKyushu_C13",
		"ContinentKyushu_C14",
		"ContinentKyushu_C15",
		"ContinentKyushu_C16",
		"ContinentKyushu_C17",
		"ContinentKyushu_C18",
		"ContinentKyushu_C19",
		"ContinentKyushu_C20",
		"ContinentKyushu_C21",
		"ContinentKyushu_C22",
		"ContinentKyushu_C23",
		"ContinentKyushu_C24",
	},
	paths = {
		points = {
			{ 2900.0, 27.9, -520.0 },
			{ 2905.2, 24.3, -476.6 },
			{ 2913.0, 29.8, -411.3 },
			{ 2941.8, 35.9, -358.1 },
			{ 2947.1, 27.6, -297.2 },
			{ 2977.9, 26.4, -189.7 },
			{ 3017.4, 27.1, -164.7 },
			{ 3067.9, 26.6, -146.5 },
			{ 3114.1, 21.4, -114.5 },
			{ 3142.8, 19.0, -84.7 },
			{ 3176.9, 24.6, -54.0 },
			{ 3206.0, 30.2, -12.3 },
			{ 3241.6, 27.1, 26.9 },
			{ 3281.9, 20.9, 49.9 },
			{ 3354.5, 22.2, 61.4 },
		},
		width = 24, -- 道の幅（stud）
		method = "terrain", -- "terrain"（地形を塗る） or "parts"（パーツ敷き）
		material = Enum.Material.Ground, -- method="terrain"時の塗り材質
		step = 3, -- サンプリング間隔（小さいほど滑らか＆重い）
		alignToSlope = false, -- 斜面に道面を傾けるか（見た目：true、歩きやすさ：false）
		groundOffset = 4.8, -- めり込み回避の微小オフセット
	},

	--93080.8, 38.0, 166.2
	portals = {
		{
			name = "Kyushu_to_Town",
			toZone = "ContinentTown",
			islandName = "ContinentKyushu_C20",
			offsetX = 100,
			offsetZ = 100,
			label = "→ Town",
			color = Color3.fromRGB(255, 255, 255),
		},
		{
			name = "Kyushu_to_Town",
			toZone = "Hokkaido_SW2",
			islandName = "ContinentKyushu_C22",
			offsetX = 100,
			offsetZ = 100,
			label = "→ Hokkaido",
			color = Color3.fromRGB(255, 255, 255),
		},
	},

	fieldObjects = {
		{
			model = "box_closed",
			position = { 2895.2, 46.2, -205.6 },
			mode = "ground",
			size = 1,
			rotation = { 0, -90, 0 },
			stickToGround = false, -- 省略可（trueが既定）
			groundOffset = 0, -- 芝生で少し浮かせたい時
			alignToSlope = false, -- 斜面に木を傾けたくないならfalse

			interaction = {
				type = "chest", -- インタラクションタイプ
				action = "開ける", -- ボタンに表示されるテキスト
				key = "E", -- キーバインド
				range = 18, -- インタラクション可能距離（スタッド）

				-- 宝箱固有の情報
				chestId = "kyushu_chest_01", -- ユニークID
				openedModel = "box_opened", -- 開いた状態のモデル名
				rewards = {
					{ item = "ポーション", count = 1 },
				},
				displayDuration = 2, -- 報酬表示時間（秒）
			},
		}, --{2994.3, 64.1, -424.8
		{
			model = "StoneTower",
			position = { 2994.3, 64.1, -424.8 },
			mode = "ground",
			size = 1,
			rotation = { 0, 0, 0 },
			stickToGround = false, -- 省略可（trueが既定）
			groundOffset = 0, -- 芝生で少し浮かせたい時
			alignToSlope = false, -- 斜面に木を傾けたくないならfalse
		},
	},

	BGM = "",
	BGMVolume = 0.2,
}
