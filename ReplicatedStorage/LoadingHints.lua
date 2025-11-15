-- ReplicatedStorage/LoadingHints.lua
-- ローディング画面に表示するヒントテキスト集

-- return {
-- 	getHintByLevel = '',
-- 	getGeneralHint = '',
-- 	hints = '',
-- }

local hints = {
	-- general = {
	-- 	"敵に接触すると自動的にバトルが始まります",
	-- 	"ポーション効果は一時的です。大事に使おう",
	-- 	"高いレベルの敵には経験値が多くもらえる",
	-- 	"ゴールドを集めて装備を強化しよう",
	-- 	"ポータルで別の大陸へワープできます",
	-- 	"E キーを押すことでアイテムと相互作用できます",
	-- 	"敵を倒すと経験値とゴールドが手に入ります",
	-- 	"レベルが上がるとステータスが上昇します",
	-- },

	-- level_1_10 = {
	-- 	"初心者向けエリアで基礎を学びましょう",
	-- 	"弱い敵から始めて徐々に強い敵に挑戦しよう",
	-- 	"バトルに負けてもペナルティはありません",
	-- 	"繰り返し敵を倒して経験を積みましょう",
	-- 	"HPが減ったらポーションで回復しよう",
	-- },

	level_11_30 = {
		"複数の敵が出現するエリアに挑戦しよう",
		"敵の強さに応じて戦略を変えましょう",
		"レアなドロップを狙ってボスに挑戦してみては",
		"他の大陸への冒険も視野に入れよう",
	},

	level_31_plus = {
		"強力な敵ほど多くの経験値をくれます",
		"最難関エリアはやりがいがあります",
		"全制覇を目指してコンプリートを狙おう",
		"自分の限界に挑戦してみましょう",
	},

	general = {
		"",
	},
	level_1_10 = {
		"",
	},
}

local function getHintByLevel(level)
	if level <= 10 then
		return hints.level_1_10[math.random(#hints.level_1_10)]
	elseif level <= 30 then
		return hints.level_11_30[math.random(#hints.level_11_30)]
	else
		return hints.level_31_plus[math.random(#hints.level_31_plus)]
	end
end

local function getGeneralHint()
	return hints.general[math.random(#hints.general)]
end

return {
	getHintByLevel = getHintByLevel,
	getGeneralHint = getGeneralHint,
	hints = hints,
}
