-- StarterPlayer/StarterPlayerScripts/BattleUI.client.lua
-- タイピングバトルUI制御（クライアント側）
local Logger = require(game.ReplicatedStorage.Util.Logger)
local log = Logger.get("BattleUI") -- ファイル名などをタグに

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local LocalizationService = game:GetService("LocalizationService")
local BattleDamageEvent = ReplicatedStorage:WaitForChild("BattleDamage")

local Labels = require(ReplicatedStorage.Typing.CategoryLabels)
local TypingWords = require(ReplicatedStorage.Typing.TypingWords)
local renderCategory

local UI_READY = false
local PENDING_ENTRY = nil

local Labels = require(ReplicatedStorage.Typing.CategoryLabels)

local renderCategory

local wordFrame = nil
local wordLabel = nil

-- 表示言語（この塊で1回だけ定義）
local LANG = "ja"

-- カラー定義
local CATEGORY_STYLE = {
	n = { bg = Color3.fromRGB(54, 118, 255), text = Color3.fromRGB(255, 255, 255) }, -- 名詞: 青
	v = { bg = Color3.fromRGB(68, 201, 91), text = Color3.fromRGB(0, 24, 0) }, -- 動詞: 緑
	a = { bg = Color3.fromRGB(255, 149, 0), text = Color3.fromRGB(40, 16, 0) }, -- 形容詞: 橙
	o = { bg = Color3.fromRGB(120, 120, 120), text = Color3.fromRGB(255, 255, 255) }, -- その他: 灰
}
local DEFAULT_STYLE = { bg = Color3.fromRGB(240, 240, 240), text = Color3.fromRGB(20, 20, 20) }

-- 言語切替
local function setLang(lang)
	lang = tostring(lang or ""):lower()
	if Labels[lang] then
		LANG = lang
	else
		LANG = "ja"
	end
end

local function getTranslation(entry, lang)
	if not entry then
		return ""
	end
	lang = (lang or LANG)
	return entry[lang] or entry.ja or entry.es or entry.fr or entry.de or entry.tl or ""
end

-- 起動時に一度適用（localeCode は既存の変数を利用）
-- setLang(Players.LocalPlayer:GetAttribute("UILang") or localeCode)
setLang(Players.LocalPlayer:GetAttribute("UILang") or "fr")

-- 属性変化で再描画
Players.LocalPlayer:GetAttributeChangedSignal("UILang"):Connect(function()
	setLang(Players.LocalPlayer:GetAttribute("UILang"))
	if wordFrame and currentWordData then
		renderCategory(wordFrame, currentWordData)
	end
	if translationLabel and currentWordData then
		translationLabel.Text = getTranslation(currentWordData, LANG)
		translationLabel.Visible = translationLabel.Text ~= ""
	end
end)

local function showWord(entry)
	log.debug(
		("[showWord] entry=%s UI_READY=%s wf=%s wl=%s"):format(
			entry and entry.word or "nil",
			tostring(UI_READY),
			tostring(wordFrame),
			tostring(wordLabel)
		)
	)
	if not entry then
		return
	end
	if not UI_READY or not (wordFrame and wordLabel) then
		PENDING_ENTRY = entry
		return
	end
	wordLabel.Text = entry.word

	-- ★ 安全ガード（nil なら呼ばない）
	local f = renderCategory
	if type(f) == "function" then
		f(wordFrame, entry)
	else
		warn("[BattleUI] renderCategory is nil (not assigned yet). Check forward declaration / duplicate locals.")
	end
end

-- バッジ生成（控えめデザイン）
local function ensureCategoryBadge(parentFrame: Frame?)
	if not parentFrame then
		return nil
	end
	local badge = parentFrame:FindFirstChild("CategoryBadge")
	if not badge then
		badge = Instance.new("TextLabel")
		badge.Name = "CategoryBadge"
		badge.AnchorPoint = Vector2.new(0, 0)
		badge.Position = UDim2.fromOffset(8, 6)
		badge.Size = UDim2.new(0, 0, 0, 0)
		badge.AutomaticSize = Enum.AutomaticSize.XY
		badge.BackgroundTransparency = 0.15
		badge.BackgroundColor3 = DEFAULT_STYLE.bg
		badge.TextColor3 = DEFAULT_STYLE.text
		badge.Font = Enum.Font.GothamSemibold
		badge.TextSize = 22
		badge.TextXAlignment = Enum.TextXAlignment.Left
		badge.TextYAlignment = Enum.TextYAlignment.Top
		badge.BorderSizePixel = 0
		badge.ZIndex = (parentFrame.ZIndex or 1) + 2

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = badge

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.25
		stroke.Transparency = 0.4
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = badge

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = badge

		badge.Parent = parentFrame
	end
	return badge
end

-- 文言生成（[名詞] 生き物）
local function buildCategoryText(entry, lang)
	if not entry then
		return ""
	end
	local L = Labels[lang] or Labels.ja
	local c1 = entry.category1 and (L[entry.category1] or entry.category1) or ""
	local c2 = (entry.category2 and entry.category2[lang]) or ""
	if c1 ~= "" and c2 ~= "" then
		return string.format("[%s] %s", c1, c2)
	elseif c1 ~= "" then
		return string.format("[%s]", c1)
	else
		return c2 or ""
	end
end

-- 反映
renderCategory = function(frame: Frame?, entry: table)
	if not frame or not entry then
		return
	end
	local badge = ensureCategoryBadge(frame)
	if not badge then
		return
	end

	local text = buildCategoryText(entry, LANG)
	badge.Text = text or ""
	badge.Visible = (badge.Text ~= "")

	local style = CATEGORY_STYLE[entry.category1] or DEFAULT_STYLE
	badge.BackgroundColor3 = style.bg
	badge.TextColor3 = style.text
end
-- === カテゴリ表示：準備ここまで ===

-- 効果音の取りこぼしを戦闘開始時に再解決する保険
if not resolveSoundsIfNeeded then
	function resolveSoundsIfNeeded()
		local s = ReplicatedStorage:FindFirstChild("Sounds")
		if not s then
			return
		end
		if not TypingCorrectSound or not TypingCorrectSound.Parent then
			TypingCorrectSound = s:FindFirstChild("TypingCorrect")
		end
		if not TypingErrorSound or not TypingErrorSound.Parent then
			TypingErrorSound = s:FindFirstChild("TypingError")
		end
		if not EnemyHitSound or not EnemyHitSound.Parent then
			EnemyHitSound = s:FindFirstChild("EnemyHit")
		end
	end
end

local countdownFrame: Frame? = nil
local countdownLabel: TextLabel? = nil

local function runCountdown(seconds: number)
	if not countdownFrame or not countdownLabel then
		return
	end
	countdownFrame.Visible = true
	for n = seconds, 1, -1 do
		countdownLabel.Text = tostring(n)
		-- 簡単な演出
		countdownLabel.TextTransparency = 0
		game:GetService("TweenService"):Create(countdownLabel, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
		task.wait(1)
	end
	countdownFrame.Visible = false
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local enemyProgContainer = nil
local enemyProgFill = nil
local enemyProgConn = nil

local pendingCyclePayload = nil -- { intervalSec=..., startedAt=... }
local progressStartedOnce = false -- 一度でも startEnemyProgress を呼んだか

-- === 攻撃プログレスの起動挙動 ===
local PROGRESS_COUNTDOWN_ON_START = false -- trueで3,2,1のカウントダウン後に開始
local COUNTDOWN_SECONDS = 3
local DEFAULT_FIRST_INTERVAL = 4 -- サーバーが来るまでの仮インターバル(秒)

-- === 共通レイアウト定数（横幅を揃える） ===
local STACK_WIDTH = 700 -- 3つの横幅を統一（WordFrame の幅と同じ）
local WORD_H = 150
local HP_BAR_H = 40
local PROG_H = 14
local STACK_PAD = 10 -- 縦の隙間

-- ========= 予知（次単語の先行描画）設定 =========
local PRECOGNITION_ENABLED = false -- デフォはOFF（手動スイッチ）
local function hasPrecog()
	-- 手動スイッチ or 指輪装備で付与される属性（サーバ側からSetAttribute想定）
	return PRECOGNITION_ENABLED or (Players.LocalPlayer:GetAttribute("HasPrecognition") == true)
end

-- 予知UI／データ（他の関数から参照するので先に宣言）
local wordLabelNext = nil
local precogNextWordData = nil -- 次に来る“予約”単語
local function hasPrecog()
	return true -- 予知ワード表示フラグ
end

local enemyProgConn = nil

local function stopEnemyProgress()
	if enemyProgConn then
		enemyProgConn:Disconnect()
		enemyProgConn = nil
	end
	if enemyProgFill then
		enemyProgFill.Size = UDim2.new(0, 0, 1, 0)
	end
	if enemyProgContainer then
		enemyProgContainer.Visible = false
	end
	log.debug("[BattleUI] stopEnemyProgress: disconnected & hidden")
end

local function startEnemyProgress(durationSec: number, startedAtServer: number?)
	log.debugf(
		("[BattleUI] startEnemyProgress ENTER (dur=%.2f, startedAtServer=%s)"):format(
			tonumber(durationSec) or -1,
			tostring(startedAtServer)
		)
	)

	if not enemyProgContainer or not enemyProgFill then
		log.warn("[BattleUI] progress UI not ready; skip startEnemyProgress")
		return
	end

	enemyProgContainer.Visible = true
	enemyProgFill.Size = UDim2.new(0, 0, 1, 0)

	if enemyProgConn then
		enemyProgConn:Disconnect()
		enemyProgConn = nil
	end

	local startedAt = tonumber(startedAtServer) or tick()
	enemyProgConn = game:GetService("RunService").RenderStepped:Connect(function()
		local estT = math.clamp((tick() - startedAt) / durationSec, 0, 1)
		enemyProgFill.Size = UDim2.new(estT, 0, 1, 0)
		if estT >= 1 then
			enemyProgConn:Disconnect()
			enemyProgConn = nil
		end
	end)
end

local function applyEnemyCycle(payload)
	if not payload then
		return
	end
	local duration = tonumber(payload.intervalSec) or DEFAULT_FIRST_INTERVAL
	local startedAt = tonumber(payload.startedAt)

	log.debugf(("[BattleUI] sync interval=%.2f startedAt=%.3f"):format(duration, startedAt or -1))
	startEnemyProgress(duration, startedAt)
	-- ★ 同期受信時刻を tick() 基準で記録（ウォッチドッグと同一基準）
	lastCycleAt = tick()
end

-- 入力制御（カウントダウン中はタイピング無効）
local TypingEnabled = true

log.debug("[BattleUI] クライアント起動中...")

-- ユーザーのロケールを取得
local userLocale = string.lower(LocalizationService.RobloxLocaleId)
local localeCode = string.match(userLocale, "^(%a+)") or "en" -- "ja-jp" → "ja"

-- 【開発用】強制的に日本語表示（本番では削除可能）
local FORCE_LOCALE = "ja" -- ここを変更すると表示言語が変わる（nil で自動検出）
if FORCE_LOCALE then
	localeCode = FORCE_LOCALE
	log.debugf(("[BattleUI] 言語を強制設定: %s"):format(localeCode))
end

log.debugf(("[BattleUI] ユーザーロケール: %s → 表示言語: %s"):format(userLocale, localeCode))

local RunService = game:GetService("RunService")

-- サイクルの再同期要求イベント
local RequestEnemyCycleSyncEvent = ReplicatedStorage:WaitForChild("RequestEnemyCycleSync", 10)

-- 最後にサイクル同期を受信した時刻（sec）
local lastCycleAt = 0

-- サーバーに再同期を要求
local function requestEnemyCycleSync(reason: string?)
	if not inBattle then
		return
	end
	if not RequestEnemyCycleSyncEvent then
		return
	end
	RequestEnemyCycleSyncEvent:FireServer()
end

if not BattleStartEvent or not BattleEndEvent or not BattleDamageEvent then
	warn("[BattleUI] RemoteEventの取得に失敗しました")
end

-- 単語リストを読み込み
-- local TypingWords = require(ReplicatedStorage:WaitForChild("TypingWords"))
local TypingFolder = ReplicatedStorage:WaitForChild("Typing", 30)
local TypingWords = require(TypingFolder:WaitForChild("TypingWords", 30))

-- デバッグ：単語リストの内容を確認
log.debug("[BattleUI DEBUG] TypingWords.level_1[1]:")
if TypingWords.level_1 and TypingWords.level_1[1] then
	local firstWord = TypingWords.level_1[1]
	log.debug("  Type:", type(firstWord))
	if type(firstWord) == "table" then
		log.debug("  word:", firstWord.word)
		log.debug("  ja:", firstWord.ja)
	else
		log.debug("  Value:", firstWord)
	end
end

log.debug("[BattleUI] RemoteEvents取得完了")

-- 状態
local inBattle = false
local currentWord = ""
local currentWordData = nil -- 翻訳データを含む単語情報
local lastWord = nil -- 前回の単語（連続回避用）
local currentIndex = 1
local typingLevels = {}
local currentBattleTimeout = nil
local monsterHP = 0
local monsterMaxHP = 0
local playerHP = 0 -- プレイヤーの現在HP
local playerMaxHP = 0 -- プレイヤーの最大HP
local damagePerKey = 1

-- カメラ設定保存用
local originalCameraMaxZoom = nil
local originalCameraMinZoom = nil

-- UI要素
local battleGui = nil
local darkenFrame = nil
-- local wordFrame = nil
-- local wordLabel = nil
local translationLabel = nil -- 翻訳表示用
local hpBarBackground = nil
local hpBarFill = nil
local hpLabel = nil

-- システムキーをブロックする関数
local function blockSystemKeys()
	-- カメラズームを完全に固定
	originalCameraMaxZoom = player.CameraMaxZoomDistance
	originalCameraMinZoom = player.CameraMinZoomDistance

	-- 現在のズーム距離を取得して固定
	local camera = workspace.CurrentCamera
	local currentZoom = (camera.CFrame.Position - player.Character.HumanoidRootPart.Position).Magnitude
	player.CameraMaxZoomDistance = currentZoom
	player.CameraMinZoomDistance = currentZoom
end

-- ブロック解除
local function unblockSystemKeys()
	-- カメラズームを復元
	if originalCameraMaxZoom and originalCameraMinZoom then
		player.CameraMaxZoomDistance = originalCameraMaxZoom
		player.CameraMinZoomDistance = originalCameraMinZoom
	end
end

-- 【forward declaration】
local onBattleEnd
local updateDisplay
local setNextWord
local startEnemyProgress
local stopEnemyProgress
local playHitFlash

-- HPバーの色を取得（HP割合に応じて変化）
local function getHPColor(hpPercent)
	if hpPercent > 0.6 then
		-- 緑
		return Color3.fromRGB(46, 204, 113)
	elseif hpPercent > 0.3 then
		-- 黄色
		return Color3.fromRGB(241, 196, 15)
	else
		-- 赤
		return Color3.fromRGB(231, 76, 60)
	end
end

-- 表示を更新
updateDisplay = function()
	if not wordLabel then
		return
	end

	-- 入力済み文字を緑、未入力を白で表示
	local typedPart = string.sub(currentWord, 1, currentIndex - 1)
	local remainingPart = string.sub(currentWord, currentIndex)

	wordLabel.Text = string.format('<font color="#00FF00">%s</font>%s', typedPart, remainingPart)

	-- 敵HPバー更新
	if hpBarFill and hpLabel then
		local hpPercent = monsterHP / monsterMaxHP

		-- バーの長さをアニメーション
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(hpBarFill, tweenInfo, {
			Size = UDim2.new(hpPercent, 0, 1, 0),
		})
		tween:Play()

		-- 色を変更
		hpBarFill.BackgroundColor3 = getHPColor(hpPercent)

		-- テキスト更新
		hpLabel.Text = string.format("Enemy HP: %d / %d", monsterHP, monsterMaxHP)
	end
end

-- 単語を選択する関数
local function selectWord()
	if #typingLevels == 0 then
		-- デフォルト：level_1のみ
		typingLevels = { { level = "level_1", weight = 100 } }
	end

	-- 重み付きランダム選択
	local totalWeight = 0
	for _, config in ipairs(typingLevels) do
		totalWeight = totalWeight + config.weight
	end

	local randomValue = math.random(1, totalWeight)
	local cumulativeWeight = 0
	local selectedLevel = "level_1"

	for _, config in ipairs(typingLevels) do
		cumulativeWeight = cumulativeWeight + config.weight
		if randomValue <= cumulativeWeight then
			selectedLevel = config.level
			break
		end
	end

	-- 選択されたレベルから単語を取得
	local wordList = TypingWords[selectedLevel]
	if wordList and #wordList > 0 then
		-- 前回と同じ単語を避ける（最大5回まで再抽選）
		local wordData = nil
		local attempts = 0

		repeat
			wordData = wordList[math.random(1, #wordList)]
			attempts = attempts + 1

			-- 新形式（テーブル）か旧形式（文字列）か判定
			local currentWordStr = type(wordData) == "table" and wordData.word or wordData

			-- 前回と違う単語が出たら、または5回試したらループ終了
			if currentWordStr ~= lastWord or attempts >= 5 or #wordList == 1 then
				break
			end
		until false

		-- 新形式（テーブル）か旧形式（文字列）か判定
		if type(wordData) == "table" then
			return wordData
		else
			-- 旧形式の場合は互換性のためテーブルに変換
			return { word = wordData }
		end
	else
		return { word = "apple", ja = "りんご" } -- フォールバック
	end
end

-- 予知UIの更新
local function refreshPrecogUI()
	if not wordLabelNext then
		return
	end
	if hasPrecog() and precogNextWordData and precogNextWordData.word then
		wordLabelNext.Text = "次: " .. tostring(precogNextWordData.word)
		wordLabelNext.Visible = true
	else
		wordLabelNext.Visible = false
		wordLabelNext.Text = ""
	end
end

-- “currentWordData”とは別に、次の予約単語を用意（連続回避も考慮）
local function rollNextPrecogWord()
	local tries = 0
	local candidate
	repeat
		candidate = selectWord()
		tries += 1
	-- 直前と同じは避ける（最大5回まで）
	until (not currentWordData or candidate.word ~= currentWordData.word) or tries >= 5
	precogNextWordData = candidate
	refreshPrecogUI()
end

-- 次の単語を設定（予知に対応）
-- 引数 nextData は任意。与えなければ従来どおりランダム選択。
setNextWord = function(nextData)
	-- 1) 今回出す単語を決定（外部指定が無ければ従来の selectWord()）
	currentWordData = nextData or selectWord()
	currentWord = currentWordData.word
	currentIndex = 1
	lastWord = currentWord

	log.debug(("[setNextWord] choose=%s"):format(currentWordData.word))
	showWord(currentWordData)
	log.debug("[setNextWord] after showWord")

	-- 2) 翻訳表示（従来どおり）
	if translationLabel then
		local translation = getTranslation(currentWordData, LANG)
		translationLabel.Text = translation
		translationLabel.Visible = translation ~= ""
	end

	-- 3) 表示更新（従来どおり）
	updateDisplay()

	-- 4) 予知（先行描画）
	if hasPrecog() then
		-- まだ予約が無い/古い場合は新しく引いておく
		if not precogNextWordData then
			-- 連続同一単語を避けて1回引く（必要なら再抽選ロジックを足してOK）
			local candidate = selectWord()
			if candidate and candidate.word == currentWord and #typingLevels > 0 then
				-- 同一回避の簡易リトライ
				candidate = selectWord()
			end
			precogNextWordData = candidate
		end

		-- 先行UIを出す
		if wordLabelNext then
			local previewWord = precogNextWordData and precogNextWordData.word or ""
			wordLabelNext.Visible = previewWord ~= ""
			wordLabelNext.Text = ("Next: %s"):format(previewWord)
		end
	else
		-- OFF：非表示＆予約クリア（好みで残しても良い）
		precogNextWordData = nil
		if wordLabelNext then
			wordLabelNext.Visible = false
		end
	end
end

-- UI作成
local function createBattleUI()
	battleGui = Instance.new("ScreenGui")
	battleGui.Name = "BattleUI"
	battleGui.ResetOnSpawn = false
	battleGui.Enabled = false
	battleGui.Parent = playerGui

	-- 中央の縦スタック（幅を統一）
	local centerStack = Instance.new("Frame")
	centerStack.Name = "CenterStack"
	centerStack.AnchorPoint = Vector2.new(0.5, 0.5)
	centerStack.Position = UDim2.new(0.5, 0, 0.5, 0)
	centerStack.Size = UDim2.new(0, STACK_WIDTH, 0, WORD_H + HP_BAR_H + PROG_H + (STACK_PAD * 2))
	centerStack.BackgroundTransparency = 1
	centerStack.BorderSizePixel = 0
	centerStack.ZIndex = 1
	centerStack.Parent = battleGui

	local stackLayout = Instance.new("UIListLayout")
	stackLayout.FillDirection = Enum.FillDirection.Vertical
	stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stackLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	stackLayout.Padding = UDim.new(0, STACK_PAD)
	stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stackLayout.Parent = centerStack

	-- 暗転用フレーム
	darkenFrame = Instance.new("Frame")
	darkenFrame.Name = "DarkenFrame"
	darkenFrame.Size = UDim2.fromScale(1, 1)
	darkenFrame.Position = UDim2.fromScale(0, 0)
	darkenFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	darkenFrame.BackgroundTransparency = 1
	darkenFrame.BorderSizePixel = 0
	darkenFrame.ZIndex = 1
	darkenFrame.Parent = battleGui

	-- 敵HPバー背景
	hpBarBackground = Instance.new("Frame")
	hpBarBackground.Name = "HPBarBackground"
	hpBarBackground.Size = UDim2.new(1, 0, 0, HP_BAR_H)
	hpBarBackground.Position = UDim2.new(0.5, -250, 0.25, 0)
	hpBarBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	hpBarBackground.BorderSizePixel = 0
	hpBarBackground.ZIndex = 2
	hpBarBackground.Parent = centerStack

	-- HPバー背景の角を丸くする
	local hpBarCorner = Instance.new("UICorner")
	hpBarCorner.CornerRadius = UDim.new(0, 8)
	hpBarCorner.Parent = hpBarBackground

	-- HPバー（塗りつぶし部分）
	hpBarFill = Instance.new("Frame")
	hpBarFill.Name = "HPBarFill"
	hpBarFill.Size = UDim2.new(1, 0, 1, 0)
	hpBarFill.Position = UDim2.new(0, 0, 0, 0)
	hpBarFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	hpBarFill.BorderSizePixel = 0
	hpBarFill.ZIndex = 3
	hpBarFill.Parent = hpBarBackground

	-- HPバーの角を丸くする
	local hpFillCorner = Instance.new("UICorner")
	hpFillCorner.CornerRadius = UDim.new(0, 8)
	hpFillCorner.Parent = hpBarFill

	-- HPテキスト（バーの上に表示）
	hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HPLabel"
	hpLabel.Size = UDim2.new(1, 0, 1, 0)
	hpLabel.Position = UDim2.new(0, 0, 0, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextStrokeTransparency = 0.5
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextSize = 20
	hpLabel.Text = "HP: 10 / 10"
	hpLabel.ZIndex = 4
	hpLabel.Parent = hpBarBackground

	-- 単語表示用フレーム（枠）
	wordFrame = Instance.new("Frame")
	wordFrame.Name = "WordFrame"
	wordFrame.Size = UDim2.new(1, 0, 0, WORD_H)
	wordFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	wordFrame.BorderSizePixel = 3
	wordFrame.BorderColor3 = Color3.fromRGB(100, 200, 255)
	wordFrame.ZIndex = 2
	wordFrame.Parent = centerStack

	-- 枠の角を丸くする
	local wordFrameCorner = Instance.new("UICorner")
	wordFrameCorner.CornerRadius = UDim.new(0, 12)
	wordFrameCorner.Parent = wordFrame

	-- 枠に光るエフェクト（UIStroke）
	local wordFrameStroke = Instance.new("UIStroke")
	wordFrameStroke.Color = Color3.fromRGB(100, 200, 255)
	wordFrameStroke.Thickness = 3
	wordFrameStroke.Transparency = 0
	wordFrameStroke.Parent = wordFrame

	-- ★ 予知用のゴーストラベル（WordFrameの右下／小さめ）
	wordLabelNext = Instance.new("TextLabel")
	wordLabelNext.Name = "NextWordHint"
	wordLabelNext.BackgroundTransparency = 1
	wordLabelNext.Size = UDim2.new(1, -40, 0, 24) -- 枠内いっぱい、左右20px余白
	wordLabelNext.Position = UDim2.new(0, 20, 0, 6) -- 枠の上側に小さく表示
	wordLabelNext.Font = Enum.Font.Gotham
	wordLabelNext.TextSize = 22
	wordLabelNext.TextColor3 = Color3.fromRGB(180, 190, 220)
	wordLabelNext.TextStrokeTransparency = 0.8
	wordLabelNext.TextXAlignment = Enum.TextXAlignment.Right
	wordLabelNext.ZIndex = (wordLabel and wordLabel.ZIndex or 3) + 1
	wordLabelNext.Text = ""
	wordLabelNext.Visible = false
	wordLabelNext.Parent = wordFrame

	-- 単語表示（RichText対応）
	wordLabel = Instance.new("TextLabel")
	wordLabel.Name = "WordLabel"
	wordLabel.Size = UDim2.new(1, -40, 0.6, 0)
	wordLabel.Position = UDim2.new(0, 20, 0, 10)
	wordLabel.BackgroundTransparency = 1
	wordLabel.TextColor3 = Color3.new(1, 1, 1)
	wordLabel.TextStrokeTransparency = 0
	wordLabel.Font = Enum.Font.GothamBold
	wordLabel.TextSize = 60
	wordLabel.Text = ""
	wordLabel.RichText = true
	wordLabel.ZIndex = 3
	wordLabel.Parent = wordFrame

	UI_READY = true
	if PENDING_ENTRY then
		showWord(PENDING_ENTRY)
		PENDING_ENTRY = nil
	end

	-- 翻訳表示（単語の下）
	translationLabel = Instance.new("TextLabel")
	translationLabel.Name = "TranslationLabel"
	translationLabel.Size = UDim2.new(1, -40, 0.35, 0)
	translationLabel.Position = UDim2.new(0, 20, 0.65, 0)
	translationLabel.BackgroundTransparency = 1
	translationLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	translationLabel.TextStrokeTransparency = 0.3
	translationLabel.Font = Enum.Font.Gotham
	translationLabel.TextSize = 28
	translationLabel.Text = ""
	translationLabel.TextYAlignment = Enum.TextYAlignment.Top
	translationLabel.Visible = true
	translationLabel.ZIndex = 3
	translationLabel.Parent = wordFrame

	log.debug("[BattleUI DEBUG] translationLabel 作成完了")

	-- === Enemy Attack Progress ===
	enemyProgContainer = Instance.new("Frame")
	enemyProgContainer.Name = "EnemyAttackProgress"
	enemyProgContainer.AnchorPoint = Vector2.new(0.5, 1)
	enemyProgContainer.Size = UDim2.new(1, 0, 0, PROG_H)
	enemyProgContainer.Position = UDim2.new(0.5, 0, 0.98, 0)
	enemyProgContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	enemyProgContainer.BorderSizePixel = 0
	enemyProgContainer.Visible = false
	enemyProgContainer.ZIndex = 5
	enemyProgContainer.Parent = centerStack

	local enemyProgCorner = Instance.new("UICorner")
	enemyProgCorner.CornerRadius = UDim.new(0, 7)
	enemyProgCorner.Parent = enemyProgContainer

	enemyProgFill = Instance.new("Frame")
	enemyProgFill.Name = "Fill"
	enemyProgFill.Size = UDim2.new(0, 0, 1, 0)
	enemyProgFill.Position = UDim2.new(0, 0, 0, 0)
	enemyProgFill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	enemyProgFill.BorderSizePixel = 0
	enemyProgFill.ZIndex = 6
	enemyProgFill.Parent = enemyProgContainer

	local enemyProgFillCorner = Instance.new("UICorner")
	enemyProgFillCorner.CornerRadius = UDim.new(0, 7)
	enemyProgFillCorner.Parent = enemyProgFill

	-- === Countdown overlay ===
	countdownFrame = Instance.new("Frame")
	countdownFrame.Name = "Countdown"
	countdownFrame.BackgroundTransparency = 1
	countdownFrame.Size = UDim2.new(1, 0, 1, 0)
	countdownFrame.Visible = false
	countdownFrame.ZIndex = 20
	countdownFrame.Parent = battleGui

	countdownLabel = Instance.new("TextLabel")
	countdownLabel.Size = UDim2.new(1, 0, 1, 0)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Font = Enum.Font.GothamBlack
	countdownLabel.TextScaled = true
	countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countdownLabel.TextStrokeTransparency = 0.2
	countdownLabel.ZIndex = 21
	countdownLabel.Parent = countdownFrame

	log.debug("[BattleUI] UI作成完了")
end

-- ▼▼▼ ここから：createBattleUI() の定義“直後”に入れる ▼▼▼
local function connectRemoteEvent(name, handler)
	-- 先に探す
	local ev = ReplicatedStorage:FindFirstChild(name)
	if not ev then
		warn(("[BattleUI] waiting RemoteEvent: %s"):format(name))
		-- 生成されるまで待機（タイムアウトなし）
		ev = ReplicatedStorage:WaitForChild(name)
	end
	if not ev or not ev:IsA("RemoteEvent") then
		error(
			("[BattleUI] RemoteEvent not found or wrong type: %s (got %s)"):format(name, ev and ev.ClassName or "nil")
		)
	end
	return ev.OnClientEvent:Connect(handler)
end
-- ▲▲▲ ここまで追加 ▲▲▲

-- === 攻撃プログレス開始（0→満了）===
startEnemyProgress = function(durationSec: number, startedAt: number?)
	if not enemyProgContainer or not enemyProgFill then
		return
	end

	-- 旧ループ停止
	if enemyProgConn then
		enemyProgConn:Disconnect()
		enemyProgConn = nil
	end

	enemyProgContainer.Visible = true
	enemyProgFill.Size = UDim2.new(0, 0, 1, 0)

	-- ★ tick() に統一（サーバの startedAt と同基準）
	local s = tonumber(startedAt) or tick()

	enemyProgConn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = math.clamp((tick() - s) / durationSec, 0, 1)
		enemyProgFill.Size = UDim2.new(t, 0, 1, 0)
		if t >= 1 then
			enemyProgConn:Disconnect()
			enemyProgConn = nil
		end
	end)
end

-- === 攻撃プログレス停止 ===
stopEnemyProgress = function()
	if enemyProgConn then
		enemyProgConn:Disconnect()
		enemyProgConn = nil
	end
	if enemyProgContainer and enemyProgFill then
		enemyProgContainer.Visible = false
		enemyProgFill.Size = UDim2.new(0, 0, 1, 0)
	end
end

-- === 被弾エフェクト（タイプミス／敵ターン共通）===
playHitFlash = function()
	if not wordFrame then
		return
	end

	-- 枠線キャッシュ
	local frameStroke = wordFrame:FindFirstChildOfClass("UIStroke")

	-- 赤く点滅
	wordFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	wordFrame.BackgroundTransparency = 0.3
	if frameStroke then
		frameStroke.Color = Color3.fromRGB(255, 50, 50)
	end

	TweenService:Create(wordFrame, TweenInfo.new(0.3), {
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.2,
	}):Play()

	if frameStroke then
		TweenService:Create(frameStroke, TweenInfo.new(0.3), {
			Color = Color3.fromRGB(100, 200, 255),
		}):Play()
	end
end

if not TypingCorrectSound then
	warn("[BattleUI] TypingCorrect効果音が見つかりません (WaitForChild タイムアウト)")
end
if not TypingErrorSound then
	warn("[BattleUI] TypingError効果音が見つかりません (WaitForChild タイムアウト)")
end

-- バトル開始処理（省略なし・整備版）
local function onBattleStart(monsterName, hp, maxHP, damage, levels, pHP, pMaxHP)
	log.debug("[BattleUI] === onBattleStart呼び出し ===")

	-- nil チェックとデフォルト値
	monsterName = monsterName or "Unknown"
	hp = hp or 10
	maxHP = maxHP or 10
	damage = damage or 1
	levels = levels or { { level = "level_1", weight = 100 } }
	pHP = pHP or 100
	pMaxHP = pMaxHP or 100

	log.debugf(
		("[BattleUI] バトル開始: vs %s (敵HP: %d, プレイヤーHP: %d/%d, Damage: %d)"):format(
			monsterName,
			hp,
			pHP,
			pMaxHP,
			damage
		)
	)

	-- すでに戦闘中なら無視
	if inBattle then
		log.debug("[BattleUI DEBUG] すでに戦闘中")
		return
	end

	-- 状態セット
	inBattle = true
	monsterHP = hp
	monsterMaxHP = maxHP
	playerHP = pHP
	playerMaxHP = pMaxHP
	damagePerKey = damage
	typingLevels = levels

	-- カメラ・入力ブロック
	blockSystemKeys()
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
		end
	end

	-- RobloxのUIを無効化
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
	end)

	-- UI表示
	battleGui.Enabled = true

	-- バトル開始時点で予知パネルをリセット
	precogNextWordData = nil
	if wordLabelNext then
		wordLabelNext.Text = ""
		wordLabelNext.Visible = hasPrecog() and false or false
		-- ↑ true/false は開始時に出すかどうかの好み（開始時は false 推奨）
	end

	-- ★ 単語ボックスを開始時に必ず再表示＆初期状態へ
	if wordFrame then
		wordFrame.Visible = true
		wordFrame.BackgroundTransparency = 0.2
		local frameStroke = wordFrame:FindFirstChildOfClass("UIStroke")
		if frameStroke then
			frameStroke.Transparency = 0
			frameStroke.Color = Color3.fromRGB(100, 200, 255)
		end
	end
	if wordLabel then
		wordLabel.Visible = true
		wordLabel.RichText = true
		wordLabel.Text = ""
		wordLabel.TextTransparency = 0
		wordLabel.TextStrokeTransparency = 0
		wordLabel.TextColor3 = Color3.new(1, 1, 1)
	end
	if translationLabel then
		translationLabel.Visible = true
		translationLabel.Text = ""
		translationLabel.TextTransparency = 0
		translationLabel.TextStrokeTransparency = 0.3
		translationLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	end

	-- ★ HPバーは開始時点で必ず表示に戻す
	if hpBarBackground then
		hpBarBackground.Visible = true
	end

	-- ★ プログレス初期化（確実に1本化）
	if stopEnemyProgress then
		stopEnemyProgress()
	else
		-- フォールバック：接続解除＆非表示
		if enemyProgConn then
			enemyProgConn:Disconnect()
			enemyProgConn = nil
		end
		if enemyProgContainer then
			enemyProgContainer.Visible = false
		end
	end
	if enemyProgContainer and enemyProgFill then
		enemyProgContainer.Visible = true
		enemyProgFill.Size = UDim2.new(0, 0, 1, 0)
	end

	-- 効果音の取りこぼし保険
	if resolveSoundsIfNeeded then
		resolveSoundsIfNeeded()
	end

	-- カウントダウン有無に応じて入力制御
	TypingEnabled = not PROGRESS_COUNTDOWN_ON_START

	-- 背景の暗転
	if darkenFrame then
		darkenFrame.BackgroundTransparency = 0.4
	end

	-- ラベルなどリセット
	if wordLabel then
		wordLabel.RichText = true
		wordLabel.TextColor3 = Color3.new(1, 1, 1)
		wordLabel.Text = ""
		wordLabel.TextTransparency = 0
		wordLabel.TextStrokeTransparency = 0
	end
	if translationLabel then
		translationLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
		translationLabel.Text = ""
		translationLabel.Visible = true
		translationLabel.TextTransparency = 0
		translationLabel.TextStrokeTransparency = 0.3
	end
	if hpLabel then
		hpLabel.TextColor3 = Color3.new(1, 1, 1)
		hpLabel.Text = ""
		hpLabel.TextTransparency = 0
		hpLabel.TextStrokeTransparency = 0.5
	end
	if hpBarFill then
		hpBarFill.Size = UDim2.new(1, 0, 1, 0)
		hpBarFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
		hpBarFill.BackgroundTransparency = 0
	end
	if hpBarBackground then
		hpBarBackground.BackgroundTransparency = 0
	end
	if playerHPBarFill then
		playerHPBarFill.Size = UDim2.new(1, 0, 1, 0)
		playerHPBarFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	end
	if wordFrame then
		wordFrame.BorderColor3 = Color3.fromRGB(100, 200, 255)
		wordFrame.BackgroundTransparency = 0.2
		local frameStroke = wordFrame:FindFirstChildOfClass("UIStroke")
		if frameStroke then
			frameStroke.Color = Color3.fromRGB(100, 200, 255)
			frameStroke.Transparency = 0
		end
	end

	-- 最初の単語を設定（※ カウントダウンONのときは後で出す）
	local function setFirstWordNow()
		if type(setNextWord) == "function" then
			setNextWord()
		else
			warn("[BattleUI] setNextWord が未定義です")
		end
	end

	-- カウントダウン動作
	if PROGRESS_COUNTDOWN_ON_START then
		-- カウントダウン表示
		if type(runCountdown) == "function" then
			if countdownFrame then
				countdownFrame.Visible = true
			end
			runCountdown(COUNTDOWN_SECONDS or 3)
			if countdownFrame then
				countdownFrame.Visible = false
			end
		end
		-- 入力解禁＆単語表示
		TypingEnabled = true
		setFirstWordNow()
		-- ★ 初回プログレスはここでは回さない（サーバからの EnemyAttackCycleStart を待つ）
	else
		-- カウントダウン無し：即座に単語表示
		setFirstWordNow()
		-- ★ 初回プログレスは「仮速度」で回さない（サーバ通知で正しい速度・開始時刻に同期）
		-- ※ 以前の不具合（初回だけ途中で被弾）を避けるため、ここは何もしない
	end

	-- 戦闘タイムアウト（お守り）
	-- if currentBattleTimeout then
	-- 	task.cancel(currentBattleTimeout)
	-- 	currentBattleTimeout = nil
	-- end
	-- currentBattleTimeout = task.delay(30, function()
	-- 	if inBattle then
	-- 		warn("[BattleUI] バトルタイムアウト！強制終了します")
	-- 		if onBattleEnd then
	-- 			onBattleEnd(false)
	-- 		end
	-- 	end
	-- end)

	-- ★ 初回サイクル・ウォッチドッグ：0.35秒待っても同期が来なければ要求
	task.delay(0.35, function()
		-- ★ 比較も tick() に統一
		if inBattle and (tick() - lastCycleAt) > 0.30 then
			requestEnemyCycleSync("first-cycle watchdog")
		end
	end)
end

-- バトル終了処理
onBattleEnd = function(victory, summary)
	log.debugf("=== バトル終了開始: " .. tostring(victory) .. " ===")

	-- 既にバトルが終了している場合はスキップ
	if not inBattle and not battleGui.Enabled then
		log.debug("既にバトル終了済み")
		return
	end

	-- 【最優先】バトル状態を即座にクリア（キー入力を停止）
	inBattle = false
	currentWord = ""
	currentWordData = nil
	currentIndex = 1
	playerHP = 0
	playerMaxHP = 0

	-- タイムアウトをキャンセル
	if currentBattleTimeout then
		task.cancel(currentBattleTimeout)
		currentBattleTimeout = nil
	end

	-- 敵攻撃プログレスを停止＆隠す ← ココが「直後」
	stopEnemyProgress()

	-- 敵HP表示を即座に消す
	if hpBarBackground then
		hpBarBackground.Visible = false -- 子の hpLabel / hpBarFill もまとめて非表示
	end
	if hpBarFill then
		hpBarFill.Size = UDim2.new(0, 0, 1, 0) -- 念のためリセット
	end
	if hpLabel then
		hpLabel.Text = "" -- 念のためリセット
	end

	-- 単語ボックスを即座に非表示
	if wordFrame then
		wordFrame.Visible = false
	end
	if wordLabel then
		wordLabel.Text = ""
		-- 念のため（残像対策）
		wordLabel.TextTransparency = 0
		wordLabel.TextStrokeTransparency = 0
	end
	if translationLabel then
		translationLabel.Visible = false
		translationLabel.Text = ""
	end

	-- 勝利時の処理
	if victory then
		-- システムキーのブロックを解除
		unblockSystemKeys()

		-- Roblox UIを再有効化
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
		end)

		-- 勝利メッセージを表示
		-- ★ 勝利サマリーを上部に表示（2秒後フェードアウト）
		do
			local exp = (summary and tonumber(summary.exp)) or 0
			local gold = (summary and tonumber(summary.gold)) or 0
			local dropsList = (summary and summary.drops) or {}
			-- 表示テキスト（「なし」を含む）
			local function formatDrops(drops)
				if type(drops) ~= "table" or #drops == 0 then
					return "なし"
				end
				local t = {}
				for _, d in ipairs(drops) do
					if typeof(d) == "string" then
						table.insert(t, d)
					elseif type(d) == "table" then
						local name = d.name or d.item or "???"
						local n = d.count or d.qty or 1
						table.insert(t, string.format("%s×%d", name, n))
					else
						table.insert(t, tostring(d))
					end
				end
				return table.concat(t, ", ")
			end

			local panel = Instance.new("Frame")
			panel.Name = "ResultSummary"
			panel.Size = UDim2.new(0, 520, 0, 110)
			panel.Position = UDim2.new(0.5, -260, 0.10, 0) -- ← 上部に配置（中央寄せ）
			panel.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
			panel.BackgroundTransparency = 0.1
			panel.BorderSizePixel = 0
			panel.ZIndex = 50
			panel.Parent = battleGui

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 10)
			corner.Parent = panel

			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = Color3.fromRGB(100, 200, 255)
			stroke.Transparency = 0.2
			stroke.Parent = panel

			local function addLine(text, order)
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.new(1, -24, 0, 30)
				label.Position = UDim2.new(0, 12, 0, 10 + (order - 1) * 32)
				label.Font = Enum.Font.GothamBold
				label.TextSize = 22
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.TextColor3 = Color3.fromRGB(230, 240, 255)
				label.Text = text
				label.ZIndex = 51
				label.Parent = panel
				return label
			end

			addLine(("経験値: +%d"):format(exp), 1)
			addLine(("ゴールド: +%d"):format(gold), 2)
			addLine(("ドロップ: %s"):format(formatDrops(dropsList)), 3)

			-- 2秒キープ → 0.6秒フェードアウト → 破棄
			task.delay(2.0, function()
				if panel then
					TweenService:Create(panel, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
					TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
					for _, child in ipairs(panel:GetChildren()) do
						if child:IsA("TextLabel") then
							TweenService:Create(child, TweenInfo.new(0.6), {
								TextTransparency = 1,
								TextStrokeTransparency = 1,
							}):Play()
						end
					end
					task.wait(0.65)
					if panel then
						panel:Destroy()
					end
				end
			end)
		end

		-- プレイヤーの入力ブロックを解除
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
				humanoid.JumpHeight = 7.2
			end
		end

		-- 画面を明るく戻す
		TweenService:Create(darkenFrame, TweenInfo.new(0.5), {
			BackgroundTransparency = 1,
		}):Play()

		-- UIを非表示にするための遅延実行（別スレッドで）
		task.spawn(function()
			task.wait(2.6) -- アニメーション完了を待つ
			if not inBattle then -- まだ次のバトルが始まっていないことを確認
				battleGui.Enabled = false

				-- プログレスバーを隠す＆進行ループ停止
				if enemyProgConn then
					enemyProgConn:Disconnect()
					enemyProgConn = nil
				end
				if enemyProgContainer then
					enemyProgContainer.Visible = false
				end

				-- 敵攻撃プログレスバーを非表示
				if enemyProgContainer then
					enemyProgContainer.Visible = false
				end
			end
		end)
	else
		-- 敗北時：UIを維持したまま死亡選択UIを待つ
		log.debug("[BattleUI] 敗北 - UIを維持します")

		-- 敗北メッセージ
		if wordLabel then
			wordLabel.RichText = false
			wordLabel.Text = "DEFEAT..."
			wordLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		end

		-- 翻訳ラベルを非表示
		if translationLabel then
			translationLabel.Visible = false
		end

		-- 枠の色も変更
		if wordFrame then
			local frameStroke = wordFrame:FindFirstChildOfClass("UIStroke")
			if frameStroke then
				frameStroke.Color = Color3.fromRGB(255, 100, 100)
			end
		end

		-- システムキーのブロックとRoblox UIは維持
		-- プレイヤーの移動制限も維持
		-- 死亡選択UIで選んだ後に解除する
	end

	log.debug("[BattleUI] === バトル終了完了 ===")
end

-- HP更新処理（敵）
local function onHPUpdate(newHP)
	monsterHP = newHP
	updateDisplay()

	-- HPが0になったら勝利（サーバーからの通知も来るが念のため）
	if monsterHP <= 0 then
		log.debug("[BattleUI] ⚠️ 敵HPが0になりました（クライアント側で検出）")
	end
end

-- HP更新処理（プレイヤー）
local function onPlayerHPUpdate(newHP, newMaxHP)
	playerHP = newHP
	playerMaxHP = newMaxHP or playerMaxHP
	updateDisplay()
end

-- システムキーをブロックする入力処理（最優先）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- バトル中にシステムキーが押された場合、先に処理して消費する
	if inBattle and input.UserInputType == Enum.UserInputType.Keyboard then
		local blockedKeys = {
			[Enum.KeyCode.I] = true,
			[Enum.KeyCode.O] = true,
			[Enum.KeyCode.Slash] = true,
			[Enum.KeyCode.Backquote] = true,
			[Enum.KeyCode.Tab] = true,
			[Enum.KeyCode.BackSlash] = true,
			[Enum.KeyCode.Equals] = true,
			[Enum.KeyCode.Minus] = true,
		}

		if blockedKeys[input.KeyCode] then
			-- このキーはタイピング処理に回す（ズームなどは発動させない）
			return
		end
	end
end)

playHitFlash = function()
	if not wordFrame then
		return
	end
	local frameStroke = wordFrame:FindFirstChildOfClass("UIStroke")

	-- 赤く点滅
	wordFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	wordFrame.BackgroundTransparency = 0.3
	if frameStroke then
		frameStroke.Color = Color3.fromRGB(255, 50, 50)
	end

	TweenService:Create(wordFrame, TweenInfo.new(0.3), {
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.2,
	}):Play()

	if frameStroke then
		TweenService:Create(frameStroke, TweenInfo.new(0.3), {
			Color = Color3.fromRGB(100, 200, 255),
		}):Play()
	end
end

-- (793行目あたり)
-- キー入力処理
local function onKeyPress(input, gameProcessed)
	if not inBattle then
		return
	end
	if not TypingEnabled then
		return
	end

	-- (800行目あたりから)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local keyCode = input.KeyCode
		local keyString = UserInputService:GetStringForKeyCode(keyCode):lower()

		-- 英字のみ受け付け
		if #keyString == 1 and keyString:match("%a") then
			local expectedChar = string.sub(currentWord, currentIndex, currentIndex):lower()

			if keyString == expectedChar then
				-- 正解
				currentIndex = currentIndex + 1

				-- 正解音を再生
				if TypingCorrectSound then
					TypingCorrectSound:Play()
				end

				-- ★★★【重要】ダメージ処理の復活 ★★★
				-- サーバーにダメージ通知
				BattleDamageEvent:FireServer(damagePerKey)
				-- ★★★ ここまで復活させる ★★★

				-- 単語完成チェック
				if currentIndex > #currentWord then
					task.wait(0.3)
					if inBattle then
						-- 予知ONなら予約を使う
						local useNext = (hasPrecog and hasPrecog()) and precogNextWordData or nil

						-- ★ 修正済みの予知ロジック
						-- 予約は使い切ったので、setNextWord を呼ぶ「前」にクリアする
						precogNextWordData = nil

						if type(setNextWord) == "function" then
							setNextWord(useNext)
						else
							warn("[BattleUI] setNextWord が未定義です")
							-- (フォールバック処理 ... )
							currentWordData = useNext or selectWord()
							currentWord = currentWordData.word
							currentIndex = 1
							lastWord = currentWord
							if translationLabel then
								local translation = getTranslation(currentWordData, LANG)
								translationLabel.Text = translation
								translationLabel.Visible = translation ~= ""
							end

							updateDisplay()
						end

						-- (予知クリアの行は移動したので、ここには不要)
					end
				else
					updateDisplay()
				end
			else
				-- タイプミス
				if TypingErrorSound then
					TypingErrorSound:Play()
				end

				if playHitFlash then
					playHitFlash()
				end

				-- タイプミス時のダメージをサーバーに通知
				local TypingMistakeEvent = ReplicatedStorage:FindFirstChild("TypingMistake")
				if TypingMistakeEvent then
					TypingMistakeEvent:FireServer()
				end
			end
		end
	end
end

-- 初期化
createBattleUI()

log.debug("イベント接続中...")
connectRemoteEvent("BattleStart", onBattleStart)
connectRemoteEvent("BattleEnd", onBattleEnd)

local RS = ReplicatedStorage

-- 必須イベント：サーバが出すまで待つ（タイムアウト無しでOK）
RS:WaitForChild("BattleStart").OnClientEvent:Connect(onBattleStart)
RS:WaitForChild("BattleEnd").OnClientEvent:Connect(onBattleEnd)
RS:WaitForChild("EnemyAttackCycleStart").OnClientEvent:Connect(function(payload)
	-- UI 未準備なら一旦保留
	if not battleGui or not battleGui.Enabled then
		pendingEnemyCycle = payload
		return
	end
	applyEnemyCycle(payload)
end)
RS:WaitForChild("EnemyDamage").OnClientEvent:Connect(function(payload)
	if not inBattle then
		return
	end
	playHitFlash()
	if EnemyHitSound and EnemyHitSound.Play then
		EnemyHitSound:Play()
	end
end)

-- 任意イベント：無い環境も想定して“待ち時間つきで取得”
do
	local ev = RS:WaitForChild("BattleHPUpdate", 10)
	if ev then
		ev.OnClientEvent:Connect(onHPUpdate)
	else
		warn("[BattleUI] BattleHPUpdate が見つからない（スキップ）")
	end
end
do
	local ev = RS:WaitForChild("PlayerHPUpdate", 10)
	if ev then
		ev.OnClientEvent:Connect(onPlayerHPUpdate)
	else
		warn("[BattleUI] PlayerHPUpdate が見つからない（スキップ）")
	end
end

-- ついでに他も安全化
connectRemoteEvent("EnemyDamage", function(payload)
	if not inBattle then
		return
	end
	playHitFlash()
	if EnemyHitSound and EnemyHitSound.Play then
		EnemyHitSound:Play()
	end
end)

connectRemoteEvent("EnemyAttackCycleStart", function(payload)
	if not battleGui or not battleGui.Enabled then
		pendingEnemyCycle = payload
		return
	end
	applyEnemyCycle(payload)
end)

local EnemyDamageEvent = ReplicatedStorage:WaitForChild("EnemyDamage", 30)
EnemyDamageEvent.OnClientEvent:Connect(function(payload)
	-- バトル中だけ反応
	if not inBattle then
		return
	end

	-- 敵ターンの被弾エフェクト
	playHitFlash()

	-- 敵被弾SE
	if EnemyHitSound and EnemyHitSound.Play then
		EnemyHitSound:Play()
	end
end)

ReplicatedStorage:WaitForChild("EnemyAttackCycleStart").OnClientEvent:Connect(function(payload)
	if not battleGui or not battleGui.Enabled then
		pendingEnemyCycle = payload
		return
	end
	applyEnemyCycle(payload)
end)

-- HP更新イベント（敵）
local HPUpdateEvent = ReplicatedStorage:FindFirstChild("BattleHPUpdate")
if HPUpdateEvent then
	HPUpdateEvent.OnClientEvent:Connect(onHPUpdate)
end

-- HP更新イベント（プレイヤー）
local PlayerHPUpdateEvent = ReplicatedStorage:FindFirstChild("PlayerHPUpdate")

if PlayerHPUpdateEvent then
	PlayerHPUpdateEvent.OnClientEvent:Connect(onPlayerHPUpdate)
else
	warn("[BattleUI] PlayerHPUpdate イベントが見つかりません")
end

UserInputService.InputBegan:Connect(onKeyPress)

-- 緊急脱出用：Escキーで強制終了
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Escape and battleGui.Enabled then
		warn("[BattleUI] Escキーで強制終了")

		-- システムキーのブロックを解除
		unblockSystemKeys()

		-- Roblox UIを再有効化
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
		end)

		darkenFrame.BackgroundTransparency = 1
		battleGui.Enabled = false
		inBattle = false
		currentWord = ""
		currentWordData = nil
		currentIndex = 1
		playerHP = 0
		playerMaxHP = 0

		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
				humanoid.JumpHeight = 7.2
			end
		end
	end
end)

-- ★ フォーカス復帰で再同期
UserInputService.WindowFocused:Connect(function()
	if inBattle then
		requestEnemyCycleSync("window focused")
	end
end)
