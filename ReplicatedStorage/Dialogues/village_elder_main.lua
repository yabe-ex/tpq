-- ReplicatedStorage/Dialogues/village_elder_main.lua
-- 村長との会話ツリー（ノードベース設計）
-- ノード構造：text（本文）、choices（選択肢の配列）
-- 選択肢：text（表示文）、action（実行アクション）、questId（クエストID）、nextNode（遷移先）

return {
	-- 【初回会話】
	greeting = {
		text = "ようこそ、我が町へ。何かお手伝いできることはあるかい？",
		choices = {
			{
				text = "クエストを受けたいのですが",
				nextNode = "quest_offer",
			},
			{
				text = "町について教えてください",
				nextNode = "town_info",
			},
			{
				text = "では失礼します",
				nextNode = "goodbye",
			},
		},
	},

	-- 【クエスト提供ノード】
	quest_offer = {
		text = "ふむ、それなら良い仕事がある。このあたりのスライムが増殖してな、困っているのじゃ。\n数体倒してくれたら、報酬も用意しておる。",
		choices = {
			{
				text = "引き受けます！",
				action = "acceptQuest",
				questId = "quest_slime_hunt_001",
				nextNode = "quest_accepted",
			},
			{
				text = "考えさせてください",
				nextNode = "greeting",
			},
		},
	},

	-- 【クエスト受注完了】
	quest_accepted = {
		text = "よろしい！では、スライムを倒して報告に来てくれ。\nスライムはこの町の東に多く出現する。気をつけるんじゃぞ。",
		choices = {
			{
				text = "了解しました。頑張ります",
				nextNode = "goodbye",
			},
		},
	},

	-- 【町情報】
	town_info = {
		text = "この町は冒険者の拠点じゃ。宿屋もあるし、武器屋もある。\nそして我が家での相談も随時受け付けておる。困った時は頼ってくれ。",
		choices = {
			{
				text = "ありがとうございます",
				nextNode = "greeting",
			},
			{
				text = "失礼します",
				nextNode = "goodbye",
			},
		},
	},

	-- 【別れ】
	goodbye = {
		text = "また何かあれば、いつでも来たまえ。",
		choices = {}, -- 選択肢なし＝会話終了
	},
}
