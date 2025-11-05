return {
	Name = "NeonSlime",
	TemplatePath = { "ServerStorage", "EnemyTemplates", "SlimeTemplate2" },
	RespawnTime = 10,

	-- 【新】バトルステータス
	HP = 150, -- ライフ
	Speed = 600, -- 素早さ
	Attack = 18, -- 攻撃力
	Defense = 5, -- 守備力

	-- 【新】報酬

	Experience = 10, -- 得られる経験値
	Gold = 15, -- 得られるゴールド

	-- タイピングレベル（重み付き）
	TypingLevels = {
		{ level = "level_1", weight = 70 }, -- 70%の確率でレベル1
		{ level = "level_2", weight = 30 }, -- 30%の確率でレベル2
	},

	-- 旧設定（互換性のため残す）
	Damage = 1, -- 後で削除予定

	-- スポーン設定
	-- SpawnLocations = {
	-- 	{
	-- 		islandName = "Hokkaido_31",
	-- 		count = 10,
	-- 		radiusPercent = 50,
	-- 	},
	-- },
	SpawnLocations = {
		{
			islandName = "Hokkaido_02",
			count = 10,
			radiusPercent = 50, -- 島のサイズの25%範囲内
		},
	},

	ColorProfile = {
		Body = Color3.fromRGB(255, 255, 0),

		BodyMaterial = "Plastic",
		BodyTransparency = 0.4,

		CoreMaterial = "Plastic",
		CoreTransparency = 0.3,

		EyeTexture = "rbxassetid://126158076889568",
	},

	Bravery = "always_chase", -- or "always_chase" / "always_flee / random"
	BattleStartDistance = 5,
	UpdateNearby = 0.2,
	UpdateFar = 1.0,
	UpdateNearbyThreshold = 150,

	WalkSpeed = 10, -- 歩く速さ
	Brave = 4, -- 勇敢さレベル（0～9）
	VariationRange = 2, -- 個体差の幅
}

-- "Plastic"
-- "Brick"
-- "Granite"
-- "Marble"
-- "Slate"
-- "Concrete"
-- "Ground"
-- "Grass"
-- "Wood"
-- "Metal"
-- "Neon"
-- "Glass"
-- "Ice"
-- "Pebble"
-- "Asphalt"
-- "Foil"
-- "DiamondPlate"
