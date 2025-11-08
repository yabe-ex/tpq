return {
	Name = "IceSlime",
	TemplatePath = { "ServerStorage", "EnemyTemplates", "SlimeTemplate2" },
	WalkSpeed = 0,
	RespawnTime = 10,

	-- 【新】バトルステータス
	HP = 180, -- ライフ
	Speed = 5, -- 素早さ
	Attack = 20, -- 攻撃力
	Defense = 5, -- 守備力

	-- 【新】報酬
	Experience = 20, -- 倒した時に得られる経験値
	Gold = 20, -- 倒した時に得られるゴールド

	-- タイピングレベル（重み付き）
	TypingLevels = {
		{ level = "level_1", weight = 70 }, -- 70%の確率でレベル1
		{ level = "level_2", weight = 30 }, -- 30%の確率でレベル2
	},

	-- 旧設定（互換性のため残す）
	Damage = 1, -- 後で削除予定

	-- スポーン設定
	SpawnLocations = {
		-- {
		-- 	islandName = "Hokkaido_13",
		-- 	count = 10,
		-- 	radiusPercent = 50, -- 島のサイズの25%範囲内
		-- },
		{
			islandName = "Kyusyu_10",
			count = 4,
			radiusPercent = 50, -- 島のサイズの25%範囲内
		},
	},

	-- カラー設定
	ColorProfile = {
		Body = Color3.fromRGB(255, 255, 255),

		BodyMaterial = "Ice", -- Material 名を文字列で指定
		BodyTransparency = 0.4, -- 透明度: 0～1

		CoreMaterial = "Ice", -- Material 名を文字列で指定
		CoreTransparency = 0.3, -- 透明度: 0～1

		EyeTexture = "rbxassetid://126158076889568",
	},

	Bravery = "always_chase", -- or "always_chase" / "always_flee / random"
	BattleStartDistance = 1,
	UpdateNearby = 0.2,
	UpdateFar = 1.0,
	UpdateNearbyThreshold = 150,

	Brave = 9, -- 勇敢さレベル（0～9）
	VariationRange = 0, -- 個体差の幅
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
