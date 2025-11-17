return {
	Name = "RubySlime",
	TemplatePath = { "ServerStorage", "EnemyTemplates", "SlimeTemplate2" },
	RespawnTime = 10,

	-- 【新】バトルステータス
	HP = 70, -- ライフ
	Speed = 60, -- 素早さ
	Attack = 18, -- 攻撃力
	Defense = 5, -- 守備力

	-- 【新】報酬

	Experience = 40, -- 得られる経験値
	Gold = 15, -- 得られるゴールド

	-- タイピングレベル（重み付き）
	TypingLevels = {
		{ level = "level_1", weight = 20 }, -- 70%の確率でレベル1
		{ level = "level_2", weight = 80 }, -- 30%の確率でレベル2
	},

	-- スポーン設定
	SpawnLocations = {
		{
			islandName = "Hokkaido_02",
			count = 10,
			radiusPercent = 50, -- 島のサイズの25%範囲内
		},
	},

	ColorProfile = {
		Body = Color3.fromRGB(255, 60, 60),

		BodyMaterial = "Plastic", -- Material 名を文字列で指定
		BodyTransparency = 0.3, -- 透明度: 0～1

		CoreMaterial = "Plastic", -- Material 名を文字列で指定
		CoreTransparency = 0.3, -- 透明度: 0～1

		EyeTexture = "rbxassetid://126158076889568",
	},

	Bravery = "always_chase", -- or "always_chase" / "always_flee / random"
	BattleStartDistance = 5,
	UpdateNearby = 0.2,
	UpdateFar = 1.0,
	UpdateNearbyThreshold = 150,

	WalkSpeed = 2, -- 歩く速さ
	Brave = 6, -- 勇敢さレベル（0～9）
	VariationRange = 2, -- 個体差の幅
}
