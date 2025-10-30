-- StarterPlayer/StarterPlayerScripts/MenuUI.client.lua
-- メニューシステム（ステータス、アイテム、スキル等）
local Logger = require(game.ReplicatedStorage.Util.Logger)
local log = Logger.get("MenuUI.client")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

log.debugf("初期化中...")

-- 状態管理
local currentModal = nil
local isInBattle = false

-- RemoteEvent取得
local RequestStatusEvent = ReplicatedStorage:WaitForChild("RequestStatus", 1)
local SaveGameEvent = ReplicatedStorage:WaitForChild("SaveGame", 1)
local SaveSuccessEvent = ReplicatedStorage:WaitForChild("SaveSuccess", 1)
local RequestLoadRespawnEvent = ReplicatedStorage:WaitForChild("RequestLoadRespawn", 1)

-- UIコンテナ
local menuGui = nil
local menuFrame = nil

-- プレイヤーステータスキャッシュ
local cachedStats = {
	Level = 1,
	MaxHP = 100,
	CurrentHP = 100,
	Speed = 10,
	Attack = 10,
	Defense = 10,
	Gold = 0,
	MonstersDefeated = 0,
}

-- === Settings helpers (UILang / VolBGM / VolSE) ===
local LANG_OPTIONS = { "ja", "es", "fr", "de", "tl" }
local DEFAULTS = { UILang = "ja", VolBGM = 0.60, VolSE = 0.70 }

local function getAttrOrDefault(name, default)
	local v = Players.LocalPlayer:GetAttribute(name)
	if v == nil then
		Players.LocalPlayer:SetAttribute(name, default)
		return default
	end
	return v
end

-- SEのベース音量をキャッシュして倍率適用
local SEBaseVolume = {} -- [sound] = baseVolume
local function applyVolSE(mult)
	mult = math.clamp(tonumber(mult) or DEFAULTS.VolSE, 0, 1)
	local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")
	if not soundsFolder then
		return
	end
	for _, inst in ipairs(soundsFolder:GetChildren()) do
		if inst:IsA("Sound") then
			if SEBaseVolume[inst] == nil then
				SEBaseVolume[inst] = inst.Volume
			end
			inst.Volume = SEBaseVolume[inst] * mult
		end
	end
end

-- VolBGM は BGMManager 側が Attribute を購読して適用する前提（ここでは属性だけ更新）
local function applyVolBGM(mult)
	mult = math.clamp(tonumber(mult) or DEFAULTS.VolBGM, 0, 1)
	Players.LocalPlayer:SetAttribute("VolBGM", mult)
end

-- 言語は Attribute へ。BattleUI 側のリスナーでカテゴリ/翻訳に反映済み
local function applyUILang(code)
	code = table.find(LANG_OPTIONS, code) and code or DEFAULTS.UILang
	Players.LocalPlayer:SetAttribute("UILang", code)
end

-- ステータス更新を受信 (既存ロジック)
local StatusUpdateEvent = ReplicatedStorage:FindFirstChild("StatusUpdate")
if StatusUpdateEvent then
	StatusUpdateEvent.OnClientEvent:Connect(function(hp, maxHP, level, exp, expToNext, gold)
		cachedStats.CurrentHP = hp or cachedStats.CurrentHP
		cachedStats.MaxHP = maxHP or cachedStats.MaxHP
		cachedStats.Level = level or cachedStats.Level
		cachedStats.Gold = gold or cachedStats.Gold
	end)
end

-- 戦歴更新を受信 (既存ロジック)
task.spawn(function()
	log.debugf("StatsDetailイベント接続を開始...")

	local StatsDetailEvent = ReplicatedStorage:WaitForChild("StatsDetail", 5)
	if not StatsDetailEvent then
		log.warnf("StatsDetailイベントが見つかりません！")
		return
	end

	log.debugf("StatsDetailイベントを発見しました")

	StatsDetailEvent.OnClientEvent:Connect(function(stats)
		log.debugf("========================================")
		log.debugf("🎯 StatsDetail受信イベント発火！")
		if stats then
			for key, value in pairs(stats) do
				cachedStats[key] = value
			end
			log.debugf("✅ キャッシュ更新完了")
		else
			log.warnf("❌ statsがnilです！")
		end
		log.debugf("========================================")
	end)

	log.debugf("StatsDetailイベント接続完了")
end)

-- バトル状態を監視 (既存ロジック)
local BattleStartEvent = ReplicatedStorage:FindFirstChild("BattleStart")
local BattleEndEvent = ReplicatedStorage:FindFirstChild("BattleEnd")

if BattleStartEvent then
	BattleStartEvent.OnClientEvent:Connect(function()
		isInBattle = true
		if menuFrame then
			for _, button in ipairs(menuFrame:GetChildren()) do
				if button:IsA("TextButton") then
					button.Active = false
					button.BackgroundTransparency = 0.7
					button.TextTransparency = 0.5
				end
			end
		end
		if currentModal then
			closeModal()
		end
	end)
end

if BattleEndEvent then
	BattleEndEvent.OnClientEvent:Connect(function()
		isInBattle = false
		if menuFrame then
			for _, button in ipairs(menuFrame:GetChildren()) do
				if button:IsA("TextButton") then
					button.Active = true
					button.BackgroundTransparency = 0.2
					button.TextTransparency = 0
				end
			end
		end
	end)
end

-- モーダルウィンドウを閉じる (既存ロジック)
function closeModal()
	if not currentModal then
		return
	end -- 防御的な早期終了

	local modalToDestroy = currentModal
	currentModal = nil -- ★即座にnilに設定し、他の処理による競合を防止

	if modalToDestroy then
		local background = modalToDestroy:FindFirstChild("Background")
		if background then
			local tween = TweenService:Create(background, TweenInfo.new(0.2), {
				BackgroundTransparency = 1,
			})
			tween:Play()
		end

		local panel = modalToDestroy:FindFirstChild("Panel")
		if panel then
			local tween = TweenService:Create(panel, TweenInfo.new(0.2), {
				BackgroundTransparency = 1,
			})
			tween:Play()

			for _, child in ipairs(panel:GetDescendants()) do
				if child:IsA("TextLabel") or child:IsA("TextButton") then
					TweenService:Create(child, TweenInfo.new(0.2), {
						TextTransparency = 1,
					}):Play()
				end
			end
		end

		task.wait(0.2)
		modalToDestroy:Destroy() -- ★ローカル参照を使用
	end
end

-- モーダルウィンドウを作成 (既存ロジック)
local function createModal(title, contentBuilder)
	if currentModal then
		closeModal()
	end

	local modal = Instance.new("ScreenGui")
	modal.DisplayOrder = 1000 -- 他UIより前面に
	modal.Name = "ModalUI"
	modal.ResetOnSpawn = false
	modal.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	modal.Parent = playerGui

	-- 背景（暗転）
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.ZIndex = 50
	background.Parent = modal

	TweenService:Create(background, TweenInfo.new(0.2), {
		BackgroundTransparency = 0.5,
	}):Play()

	-- パネル
	local panel = Instance.new("Frame")
	panel.ClipsDescendants = false
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 500, 0, 400)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.ZIndex = 51
	panel.Parent = modal

	TweenService:Create(panel, TweenInfo.new(0.2), {
		BackgroundTransparency = 0.1,
	}):Play()

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	-- タイトル
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -20, 0, 40)
	titleLabel.Position = UDim2.new(0, 10, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 24
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTransparency = 1
	titleLabel.ZIndex = 52
	titleLabel.Parent = panel

	TweenService:Create(titleLabel, TweenInfo.new(0.2), {
		TextTransparency = 0,
		TextStrokeTransparency = 0.5,
	}):Play()

	-- 閉じるボタン
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -50, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.BackgroundTransparency = 1
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 24
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextTransparency = 1
	closeButton.ZIndex = 52
	closeButton.Parent = panel

	TweenService:Create(closeButton, TweenInfo.new(0.2), {
		BackgroundTransparency = 0.2,
		TextTransparency = 0,
	}):Play()

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		closeModal()
	end)

	closeButton.MouseEnter:Connect(function()
		closeButton.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	end)
	closeButton.MouseLeave:Connect(function()
		closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	end)

	-- コンテンツエリア
	local contentFrame = Instance.new("Frame")
	contentFrame.ClipsDescendants = false
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -20, 1, -70)
	contentFrame.Position = UDim2.new(0, 10, 0, 60)
	contentFrame.BackgroundTransparency = 1
	contentFrame.ZIndex = 52
	contentFrame.Parent = panel

	if contentBuilder then
		contentBuilder(contentFrame)
	end

	-- background.InputBegan:Connect(function(input)
	-- 	if input.UserInputType == Enum.UserInputType.MouseButton1 then
	-- 		closeModal()
	-- 	end
	-- end)

	currentModal = modal
	return modal
end

local function showSaveModal()
	if not SaveGameEvent or not SaveSuccessEvent then
		createModal("セーブエラー", function(content)
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255, 100, 100)
			label.TextStrokeTransparency = 0.7
			label.Font = Enum.Font.Gotham
			label.TextSize = 18
			label.Text = "セーブ機能がサーバーで初期化されていません。"
			label.Parent = content
		end)
		return
	end

	-- セーブイベントをサーバーに送信
	SaveGameEvent:FireServer()

	local connection = nil -- ★FIX 1: connectionをローカル宣言

	createModal("セーブ中", function(content)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.7
		label.Font = Enum.Font.Gotham
		label.TextSize = 18
		label.Text = "💾 セーブ中..."
		label.Parent = content
		-- ... (label setup)

		-- セーブ完了のフィードバックを待機
		connection = SaveSuccessEvent.OnClientEvent:Connect(function(success)
			if connection and connection.Connected then
				connection:Disconnect()
			end -- ★FIX 2: Disconnect前にnil/Connectedチェック

			if success then
				label.Text = "✅ セーブ完了！"
				label.TextColor3 = Color3.fromRGB(46, 204, 113)
			else
				label.Text = "❌ セーブ失敗..."
				label.TextColor3 = Color3.fromRGB(231, 76, 60)
			end
			task.wait(1.5)
			closeModal()
		end)

		-- モーダルが強制終了された場合、接続を解除
		-- 閉じるボタン（✕）のイベント接続を再利用
		local closeButton = content.Parent:FindFirstChild("CloseButton")
		if closeButton then
			closeButton.MouseButton1Click:Connect(function()
				if connection and connection.Connected then
					connection:Disconnect()
				end -- ★FIX 3: 終了ボタンもnil/Connectedチェック
				closeModal()
			end)
		end

		-- 背景クリック（強制終了）のイベント接続を再利用
		local background = content.Parent.Parent:FindFirstChild("Background")
		if background then
			background.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					if connection and connection.Connected then
						connection:Disconnect()
					end
					closeModal()
				end
			end)
		end
	end)
end

local function showLoadModal()
	createModal("ロード", function(content)
		local warningLabel = Instance.new("TextLabel")
		warningLabel.Size = UDim2.new(1, 0, 0, 60)
		warningLabel.Position = UDim2.new(0, 0, 0, 20)
		warningLabel.BackgroundTransparency = 1
		warningLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
		warningLabel.TextStrokeTransparency = 0.7
		warningLabel.Font = Enum.Font.Gotham
		warningLabel.TextSize = 18
		warningLabel.Text =
			"現在、ロードは再接続によって行われます。\nゲームを再起動しますか？"
		warningLabel.TextWrapped = true
		warningLabel.TextTransparency = 1
		warningLabel.ZIndex = 53
		warningLabel.Parent = content

		TweenService:Create(warningLabel, TweenInfo.new(0.2), { TextTransparency = 0, TextStrokeTransparency = 0.7 })
			:Play()

		-- ロードボタン (サーバーにロード要求を送り、キックする)
		local loadButton = Instance.new("TextButton")
		loadButton.Size = UDim2.new(0, 150, 0, 50)
		loadButton.Position = UDim2.new(0.5, -160, 1, -70)
		loadButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
		loadButton.BackgroundTransparency = 0.2
		loadButton.BorderSizePixel = 0
		loadButton.Font = Enum.Font.GothamBold
		loadButton.TextSize = 18
		loadButton.Text = "ゲームを再起動"
		loadButton.TextColor3 = Color3.new(1, 1, 1)
		loadButton.TextTransparency = 1
		loadButton.ZIndex = 53
		loadButton.Parent = content

		TweenService
			:Create(loadButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.1), {
				BackgroundTransparency = 0.2,
				TextTransparency = 0,
			})
			:Play()

		local loadCorner = Instance.new("UICorner")
		loadCorner.CornerRadius = UDim.new(0, 8)
		loadCorner.Parent = loadButton

		-- ロード処理はキックを実行
		loadButton.MouseButton1Click:Connect(function()
			closeModal()

			-- ★修正ブロック開始: Studioと実環境で処理を分ける
			if game:GetService("RunService"):IsStudio() then
				if RequestLoadRespawnEvent then
					-- Studioの場合、サーバーにリスポーンを要求
					RequestLoadRespawnEvent:FireServer()
					log.debugf("Studioモード: サーバーにロードリスポーンを要求しました")
				else
					log.warnf("RequestLoadRespawnEventが見つかりません！")
				end
			else
				-- 実際のゲームの場合、キックして再接続を促す
				player:Kick("セーブデータをロードするため再起動します")
			end
			-- ★修正ブロック終了
		end)

		-- キャンセルボタン (showLogoutから流用)
		local cancelButton = Instance.new("TextButton")
		cancelButton.Size = UDim2.new(0, 150, 0, 50)
		cancelButton.Position = UDim2.new(0.5, 10, 1, -70)
		cancelButton.BackgroundColor3 = Color3.fromRGB(149, 165, 166)
		cancelButton.BackgroundTransparency = 0.2
		cancelButton.BorderSizePixel = 0
		cancelButton.Font = Enum.Font.GothamBold
		cancelButton.TextSize = 18
		cancelButton.Text = "キャンセル"
		cancelButton.TextColor3 = Color3.new(1, 1, 1)
		cancelButton.TextTransparency = 1
		cancelButton.ZIndex = 53
		cancelButton.Parent = content

		TweenService
			:Create(cancelButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.15), {
				BackgroundTransparency = 0.2,
				TextTransparency = 0,
			})
			:Play()

		local cancelCorner = Instance.new("UICorner")
		cancelCorner.CornerRadius = UDim.new(0, 8)
		cancelCorner.Parent = cancelButton

		cancelButton.MouseButton1Click:Connect(function()
			closeModal()
		end)
	end)
end

-- ★新規機能: 初期化処理
local function showResetModal()
	createModal("データ初期化", function(content)
		local warningLabel = Instance.new("TextLabel")
		warningLabel.Size = UDim2.new(1, 0, 0, 60)
		warningLabel.Position = UDim2.new(0, 0, 0, 20)
		warningLabel.BackgroundTransparency = 1
		warningLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		warningLabel.TextStrokeTransparency = 0.7
		warningLabel.Font = Enum.Font.Gotham
		warningLabel.TextSize = 18
		warningLabel.Text = "!! 警告 !!\nすべての進行状況を失います。本当に初期化しますか？"
		warningLabel.TextWrapped = true
		warningLabel.TextTransparency = 1
		warningLabel.ZIndex = 53
		warningLabel.Parent = content
		TweenService:Create(warningLabel, TweenInfo.new(0.2), { TextTransparency = 0, TextStrokeTransparency = 0.7 })
			:Play()

		-- 進捗/結果ラベル
		local resultLabel = Instance.new("TextLabel")
		resultLabel.Size = UDim2.new(1, 0, 0, 28)
		resultLabel.Position = UDim2.new(0, 0, 1, -110)
		resultLabel.BackgroundTransparency = 1
		resultLabel.Font = Enum.Font.Gotham
		resultLabel.TextSize = 18
		resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		resultLabel.TextStrokeTransparency = 0.7
		resultLabel.Text = ""
		resultLabel.ZIndex = 53
		resultLabel.Parent = content

		local resetButton = Instance.new("TextButton")
		resetButton.Size = UDim2.new(0, 150, 0, 50)
		resetButton.Position = UDim2.new(0.5, -160, 1, -70)
		resetButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		resetButton.BackgroundTransparency = 0.2
		resetButton.BorderSizePixel = 0
		resetButton.Font = Enum.Font.GothamBold
		resetButton.TextSize = 18
		resetButton.Text = "初期化する"
		resetButton.TextColor3 = Color3.new(1, 1, 1)
		resetButton.TextTransparency = 1
		resetButton.ZIndex = 53
		resetButton.Parent = content
		local resetCorner = Instance.new("UICorner")
		resetCorner.CornerRadius = UDim.new(0, 8)
		resetCorner.Parent = resetButton
		TweenService
			:Create(resetButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.1), {
				BackgroundTransparency = 0.2,
				TextTransparency = 0,
			})
			:Play()

		local cancelButton = Instance.new("TextButton")
		cancelButton.Size = UDim2.new(0, 150, 0, 50)
		cancelButton.Position = UDim2.new(0.5, 10, 1, -70)
		cancelButton.BackgroundColor3 = Color3.fromRGB(149, 165, 166)
		cancelButton.BackgroundTransparency = 0.2
		cancelButton.BorderSizePixel = 0
		cancelButton.Font = Enum.Font.GothamBold
		cancelButton.TextSize = 18
		cancelButton.Text = "キャンセル"
		cancelButton.TextColor3 = Color3.new(1, 1, 1)
		cancelButton.TextTransparency = 1
		cancelButton.ZIndex = 53
		cancelButton.Parent = content
		local cancelCorner = Instance.new("UICorner")
		cancelCorner.CornerRadius = UDim.new(0, 8)
		cancelCorner.Parent = cancelButton
		TweenService
			:Create(cancelButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.15), {
				BackgroundTransparency = 0.2,
				TextTransparency = 0,
			})
			:Play()
		cancelButton.MouseButton1Click:Connect(function()
			closeModal()
		end)

		-- RemoteEvents
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local ResetSaveRequest = ReplicatedStorage:FindFirstChild("ResetSaveRequest")
		local ResetSaveResult = ReplicatedStorage:FindFirstChild("ResetSaveResult")

		resetButton.MouseButton1Click:Connect(function()
			if not ResetSaveRequest or not ResetSaveResult then
				resultLabel.Text = "❌ サーバ側の初期化機能が見つかりません"
				resultLabel.TextColor3 = Color3.fromRGB(231, 76, 60)
				return
			end

			-- 二度押し防止
			resetButton.Active = false
			resetButton.AutoButtonColor = false
			resultLabel.Text = "🔄 初期化しています..."
			resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

			-- 結果待ちの接続（ワンショット）
			local conn
			conn = ResetSaveResult.OnClientEvent:Connect(function(success, message)
				if conn and conn.Connected then
					conn:Disconnect()
				end
				if success then
					resultLabel.Text = "✅ 初期化完了（レベル1へ）"
					resultLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
					task.wait(1.2)
					closeModal()
					-- 実環境では再接続してクリーンに読み直し（Studioはキックしない）
					if not game:GetService("RunService"):IsStudio() then
						Players.LocalPlayer:Kick("データを初期化しました。再接続してください。")
					end
				else
					resultLabel.Text = "❌ 初期化失敗: " .. (message or "不明なエラー")
					resultLabel.TextColor3 = Color3.fromRGB(231, 76, 60)
					resetButton.Active = true
					resetButton.AutoButtonColor = true
				end
			end)

			-- サーバへ要求
			ResetSaveRequest:FireServer()
		end)
	end)
end

-- ステータス画面 (既存ロジック)
local function showStatus()
	createModal("ステータス", function(content)
		local stats = {
			{ "レベル", cachedStats.Level },
			{ "最大HP", cachedStats.MaxHP },
			{ "攻撃力", cachedStats.Attack },
			{ "防御力", cachedStats.Defense },
			{ "素早さ", cachedStats.Speed },
		}

		for i, stat in ipairs(stats) do
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 0, 40)
			label.Position = UDim2.new(0, 0, 0, (i - 1) * 50)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextStrokeTransparency = 0.7
			label.Font = Enum.Font.Gotham
			label.TextSize = 20
			label.Text = string.format("%s: %d", stat[1], stat[2])
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextTransparency = 1
			label.ZIndex = 53
			label.Parent = content

			TweenService
				:Create(
					label,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, i * 0.05),
					{
						TextTransparency = 0,
						TextStrokeTransparency = 0.7,
					}
				)
				:Play()
		end
	end)
end

-- アイテム画面 (既存ロジック)
local function showItems()
	createModal("アイテム", function(content)
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.fromScale(1, 1)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		emptyLabel.TextStrokeTransparency = 0.7
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.TextSize = 18
		emptyLabel.Text = "アイテムがありません"
		emptyLabel.TextTransparency = 1
		emptyLabel.ZIndex = 53
		emptyLabel.Parent = content

		TweenService:Create(emptyLabel, TweenInfo.new(0.2), {
			TextTransparency = 0,
			TextStrokeTransparency = 0.7,
		}):Play()
	end)
end

-- スキル画面 (既存ロジック)
local function showSkills()
	createModal("スキル", function(content)
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.fromScale(1, 1)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		emptyLabel.TextStrokeTransparency = 0.7
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.TextSize = 18
		emptyLabel.Text = "習得済みスキルなし"
		emptyLabel.TextTransparency = 1
		emptyLabel.ZIndex = 53
		emptyLabel.Parent = content

		TweenService:Create(emptyLabel, TweenInfo.new(0.2), {
			TextTransparency = 0,
			TextStrokeTransparency = 0.7,
		}):Play()
	end)
end

-- 戦歴画面 (既存ロジック)
local function showRecords()
	createModal("戦歴", function(content)
		log.debugf("========================================")
		log.debugf("戦歴画面を開きました")
		log.debugf("キャッシュされた値:", cachedStats.MonstersDefeated or 0)

		-- ラベルを先に作成
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 40)
		label.Position = UDim2.new(0, 0, 0, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.7
		label.Font = Enum.Font.Gotham
		label.TextSize = 20
		label.Text = string.format("倒したモンスター数: %d (取得中...)", cachedStats.MonstersDefeated or 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTransparency = 1
		label.ZIndex = 53
		label.Parent = content

		TweenService:Create(label, TweenInfo.new(0.2), {
			TextTransparency = 0,
			TextStrokeTransparency = 0.7,
		}):Play()

		-- サーバーに最新の戦歴をリクエスト
		local RequestStatsDetailEvent = ReplicatedStorage:FindFirstChild("RequestStatsDetail")
		if RequestStatsDetailEvent then
			log.debugf("サーバーに詳細ステータスをリクエスト中...")
			RequestStatsDetailEvent:FireServer()

			-- 0.5秒後にラベルを更新（サーバーからのレスポンスを待つ）
			task.delay(0.5, function()
				if label and label.Parent then
					label.Text = string.format("倒したモンスター数: %d", cachedStats.MonstersDefeated or 0)
					log.debugf("ラベル更新: MonstersDefeated =", cachedStats.MonstersDefeated)
				end
			end)
		else
			log.warnf("RequestStatsDetailEventが見つかりません")
		end

		log.debugf("========================================")
	end)
end

-- 設定画面
local function showSettings()
	createModal("システム設定", function(content)
		-- 初期値（属性 or 既定）
		local curLang = getAttrOrDefault("UILang", DEFAULTS.UILang)
		local curBGM = getAttrOrDefault("VolBGM", DEFAULTS.VolBGM) -- 0..1
		local curSE = getAttrOrDefault("VolSE", DEFAULTS.VolSE) -- 0..1

		-- ボディ：スクロール
		local scroll = Instance.new("ScrollingFrame")
		scroll.ClipsDescendants = false
		scroll.ZIndex = 200
		scroll.Name = "SettingsList"
		scroll.Size = UDim2.new(1, 0, 1, -60)
		scroll.Position = UDim2.new(0, 0, 0, 0)
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarThickness = 8
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.ZIndex = 53
		scroll.Parent = content

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = scroll

		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Vertical
		list.Padding = UDim.new(0, 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll

		-- 行テンプレート作成ヘルパ
		local function makeRow(height)
			local row = Instance.new("Frame")
			row.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
			row.BackgroundTransparency = 0.1
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, 0, 0, height or 54)
			row.ZIndex = 53
			row.ClipsDescendants = false
			row.ZIndex = 210 -- scrollより前に

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 10)
			corner.Parent = row

			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1
			stroke.Transparency = 0.5
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = row

			row.Parent = scroll
			return row
		end

		local function addLabel(parent, text)
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(0.45, -12, 1, 0)
			label.Position = UDim2.new(0, 12, 0, 0)
			label.Font = Enum.Font.GothamMedium
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.TextSize = 18
			label.TextColor3 = Color3.fromRGB(230, 240, 255)
			label.TextStrokeTransparency = 0.7
			label.Text = text
			label.ZIndex = 54
			label.Parent = parent
			return label
		end

		-- ▼ 言語（ドロップダウン風）
		do
			local row = makeRow(54)
			addLabel(row, "言語 / Language")

			local langBtn = Instance.new("TextButton")
			langBtn.Size = UDim2.new(0.45, -12, 0, 36)
			langBtn.Position = UDim2.new(0.55, 0, 0.5, -18)
			langBtn.BackgroundColor3 = Color3.fromRGB(52, 86, 139)
			langBtn.BackgroundTransparency = 0.15
			langBtn.BorderSizePixel = 0
			langBtn.Font = Enum.Font.GothamBold
			langBtn.TextSize = 18
			langBtn.TextColor3 = Color3.new(1, 1, 1)
			langBtn.AutoButtonColor = true
			langBtn.ZIndex = 54
			langBtn.Parent = row

			local langCorner = Instance.new("UICorner")
			langCorner.CornerRadius = UDim.new(0, 8)
			langCorner.Parent = langBtn

			local function labelOf(code)
				-- 表示名（必要なら辞書に変更可）
				local map = { ja = "日本語", es = "Español", fr = "Français", de = "Deutsch", tl = "Tagalog" }
				return map[code] or code
			end

			local current = curLang
			langBtn.Text = labelOf(current)

			-- 簡易ドロップダウン（モーダル内にミニメニューを出すだけ）
			langBtn.MouseButton1Click:Connect(function()
				-- 既存をつぶさないため簡易に：トグル式の小パネル
				local dd = row:FindFirstChild("LangDD")
				if dd then
					dd:Destroy()
					return
				end

				dd = Instance.new("Frame")
				dd.Name = "LangDD"
				dd.Size = UDim2.new(0, langBtn.AbsoluteSize.X, 0, #LANG_OPTIONS * 34 + 10)
				dd.Position = UDim2.new(0.55, 0, 1, 4)
				dd.BackgroundColor3 = Color3.fromRGB(25, 26, 36)
				dd.BackgroundTransparency = 0.05
				dd.BorderSizePixel = 0
				dd.ZIndex = 1000
				dd.ClipsDescendants = false
				-- ★ 親は panel のままでOK（パネル基準で絶対位置を算出）
				dd.Parent = content.Parent -- (= panel)

				-- ★ ボタン直下に置くための正確な位置算出
				local panelAbs = content.Parent.AbsolutePosition
				local btnAbs = langBtn.AbsolutePosition
				local x = btnAbs.X - panelAbs.X
				local y = (btnAbs.Y - panelAbs.Y) + langBtn.AbsoluteSize.Y + 6
				dd.Position = UDim2.fromOffset(x, y)

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = dd

				local list = Instance.new("UIListLayout")
				list.FillDirection = Enum.FillDirection.Vertical
				list.Padding = UDim.new(0, 4)
				list.Parent = dd

				local pad = Instance.new("UIPadding")
				pad.PaddingTop = UDim.new(0, 6)
				pad.PaddingBottom = UDim.new(0, 6)
				pad.PaddingLeft = UDim.new(0, 6)
				pad.PaddingRight = UDim.new(0, 6)
				pad.Parent = dd

				for _, code in ipairs(LANG_OPTIONS) do
					local opt = Instance.new("TextButton")
					opt.Size = UDim2.new(1, 0, 0, 30)
					opt.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
					opt.BackgroundTransparency = (code == current) and 0.0 or 0.15
					opt.BorderSizePixel = 0
					opt.Font = Enum.Font.Gotham
					opt.TextSize = 16
					opt.TextColor3 = Color3.new(1, 1, 1)
					opt.Text = labelOf(code)
					opt.ZIndex = 1001
					opt.Parent = dd

					local oc = Instance.new("UICorner")
					oc.CornerRadius = UDim.new(0, 6)
					oc.Parent = opt

					opt.MouseButton1Click:Connect(function()
						current = code
						curLang = code -- ★これが無いと保存に反映されない
						langBtn.Text = labelOf(current)
						applyUILang(current)
						dd:Destroy()
					end)
				end
			end)
		end

		local UIS = game:GetService("UserInputService")

		local function sliderRow(labelText, init01, onChange)
			local row = makeRow(58)
			addLabel(row, labelText)

			-- 初期値を 0..1 に丸める（nil 対策）
			init01 = tonumber(init01) or 1
			if init01 < 0 then
				init01 = 0
			elseif init01 > 1 then
				init01 = 1
			end

			-- track
			local track = Instance.new("Frame")
			track.Size = UDim2.new(0.55, -12, 0, 8)
			track.Position = UDim2.new(0.40, 0, 0.5, 0)
			track.BackgroundColor3 = Color3.fromRGB(70, 80, 100)
			track.BackgroundTransparency = 0.2
			track.BorderSizePixel = 0
			track.ClipsDescendants = false
			track.ZIndex = 54
			track.Parent = row
			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(0, 4)
			tc.Parent = track

			-- fill
			local fill = Instance.new("Frame")
			fill.Size = UDim2.new(init01, 0, 1, 0)
			fill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
			fill.BorderSizePixel = 0
			fill.ZIndex = 55
			fill.Parent = track
			local fc = Instance.new("UICorner")
			fc.CornerRadius = UDim.new(0, 4)
			fc.Parent = fill

			-- knob
			local knob = Instance.new("Frame")
			knob.Size = UDim2.new(0, 16, 0, 16)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.Position = UDim2.new(init01, 0, 0.5, 0)
			knob.BackgroundColor3 = Color3.fromRGB(220, 230, 255)
			knob.BorderSizePixel = 0
			knob.ZIndex = 56
			knob.Parent = track
			local kc = Instance.new("UICorner")
			kc.CornerRadius = UDim.new(1, 0)
			kc.Parent = knob

			-- % ラベル（track の“すぐ右内側”固定）
			local pct = Instance.new("TextLabel")
			pct.Name = "Percent"
			pct.AutomaticSize = Enum.AutomaticSize.X
			pct.Size = UDim2.new(0, 0, 0, 16) -- 高さのみ
			pct.AnchorPoint = Vector2.new(1, 0.5) -- 右端基準
			pct.Position = UDim2.new(1, -4, 0.5, 0) -- 右端から 4px 左
			pct.BackgroundTransparency = 1
			pct.Font = Enum.Font.Gotham
			pct.TextSize = 16
			pct.TextColor3 = Color3.fromRGB(220, 230, 255)
			pct.TextXAlignment = Enum.TextXAlignment.Right
			pct.TextYAlignment = Enum.TextYAlignment.Center
			pct.ZIndex = 56
			pct.Text = string.format("%d%%", math.floor(init01 * 100 + 0.5))
			pct.Parent = track

			-- 初期レイアウトを2回適用（縦ズレ防止）
			local function layoutInit()
				knob.Position = UDim2.new(init01, 0, 0.5, 0)
				fill.Size = UDim2.new(init01, 0, 1, 0)
				pct.Position = UDim2.new(1, -4, 0.5, 0)
			end
			layoutInit()
			track:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutInit)
			task.defer(layoutInit)

			-- ドラッグ
			local dragging = false
			local function setValueFromX(x)
				local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
				fill.Size = UDim2.new(rel, 0, 1, 0)
				knob.Position = UDim2.new(rel, 0, 0.5, 0)
				pct.Text = string.format("%d%%", math.floor(rel * 100 + 0.5))
				if onChange then
					onChange(rel)
				end
			end

			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = true
					setValueFromX(input.Position.X)
				end
			end)
			knob.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = true
				end
			end)
			track.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
				end
			end)
			knob.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
				end
			end)
			UIS.InputChanged:Connect(function(input)
				if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
					setValueFromX(input.Position.X)
				end
			end)

			return row
		end

		local curLang = Players.LocalPlayer:GetAttribute("UILang") or "ja"
		local curBGM = tonumber(Players.LocalPlayer:GetAttribute("VolBGM")) or 1.0
		local curSE = tonumber(Players.LocalPlayer:GetAttribute("VolSE")) or 1.0

		-- ▼ BGM / SE スライダー（言語行の直後に置く）
		sliderRow("BGM音量", curBGM, function(v)
			curBGM = v
			applyVolBGM(v) -- その場で試聴
			Players.LocalPlayer:SetAttribute("VolBGM", v) -- 即時保存（任意）
		end)

		sliderRow("SE音量", curSE, function(v)
			curSE = v
			applyVolSE(v)
			Players.LocalPlayer:SetAttribute("VolSE", v)
		end)

		-- フッターボタン（戻る/既定に戻す/保存）
		local footer = Instance.new("Frame")
		footer.Size = UDim2.new(1, 0, 0, 52)
		footer.Position = UDim2.new(0, 0, 1, -52)
		footer.BackgroundTransparency = 1
		footer.ZIndex = 54
		footer.Parent = content

		local function makeBtn(text, anchorX)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0, 120, 0, 40)
			b.AnchorPoint = Vector2.new(anchorX, 0.5)
			b.Position = UDim2.new(anchorX, 0, 0.5, 0)
			b.BackgroundColor3 = Color3.fromRGB(60, 70, 85)
			b.BackgroundTransparency = 0.1
			b.BorderSizePixel = 0
			b.Font = Enum.Font.GothamBold
			b.TextSize = 18
			b.Text = text
			b.TextColor3 = Color3.new(1, 1, 1)
			b.ZIndex = 55
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 8)
			c.Parent = b
			b.Parent = footer
			return b
		end

		local reset = makeBtn("既定に戻す", 0.0)
		reset.Position = UDim2.new(0, 10, 0.5, 0)
		local save = makeBtn("保存", 1.0)
		save.Position = UDim2.new(1, -10, 0.5, 0)
		save.Position = UDim2.new(1, -10, 0.5, 0)

		reset.MouseButton1Click:Connect(function()
			curLang = DEFAULTS.UILang
			curBGM = DEFAULTS.VolBGM
			curSE = DEFAULTS.VolSE
			applyUILang(curLang)
			applyVolBGM(curBGM)
			applyVolSE(curSE)
			-- UI 側の表示更新（簡易：閉じて開き直すのも可）
			closeModal()
			task.defer(showSettings)
		end)

		save.MouseButton1Click:Connect(function()
			-- いまはクライアント属性への保存のみ（0.0〜1.0で保持）
			applyUILang(curLang)
			applyVolBGM(curBGM)
			applyVolSE(curSE)
			-- 将来：RemoteEventでDataStoreに永続化（必要なら後で足す）
			closeModal()
		end)

		-- 初期反映（UIを開いた瞬間にもプレビュー反映）
		applyUILang(curLang)
		applyVolBGM(curBGM)
		applyVolSE(curSE)
	end)
end

-- ★新規機能: システムメニュー (2x2グリッド)
local function showSystem()
	createModal("システム", function(content)
		-- コンテンツフレームを基準に、2x2グリッドを中央に配置
		local systemFrame = Instance.new("Frame")
		systemFrame.Size = UDim2.new(1, 0, 1, 0)
		systemFrame.BackgroundTransparency = 1
		systemFrame.Parent = content

		local systemButtons = {
			{ name = "セーブ", func = showSaveModal, row = 0, col = 0, color = Color3.fromRGB(46, 204, 113) }, -- 緑
			{ name = "ロード", func = showLoadModal, row = 0, col = 1, color = Color3.fromRGB(52, 152, 219) }, -- 青
			{ name = "初期化", func = showResetModal, row = 1, col = 0, color = Color3.fromRGB(231, 76, 60) }, -- 赤
			{
				name = "ログアウト",
				func = showLogoutInner,
				row = 1,
				col = 1,
				color = Color3.fromRGB(149, 165, 166),
			}, -- 灰色
		}

		local buttonWidth = 160
		local buttonHeight = 65
		local spacing = 15

		local totalWidth = buttonWidth * 2 + spacing
		local totalHeight = buttonHeight * 2 + spacing

		for _, btnData in ipairs(systemButtons) do
			local button = Instance.new("TextButton")
			button.Name = btnData.name .. "Button"
			button.Size = UDim2.new(0, buttonWidth, 0, buttonHeight)

			-- グリッドの中心に配置するためのオフセット計算（手動調整が容易なようにAnchorPointを使用しない）
			local gridX = btnData.col * (buttonWidth + spacing)
			local gridY = btnData.row * (buttonHeight + spacing)

			-- AbsoluteSizeは実行時にしか確定しないため、AnchorPoint 0.5で相対位置を計算
			button.Position = UDim2.new(0.5, gridX - totalWidth / 2, 0.5, gridY - totalHeight / 2)

			button.BackgroundColor3 = btnData.color
			button.BackgroundTransparency = 0.2
			button.BorderSizePixel = 0
			button.Font = Enum.Font.GothamBold
			button.TextSize = 18
			button.Text = btnData.name
			button.TextColor3 = Color3.new(1, 1, 1)
			button.TextStrokeTransparency = 0.7
			button.ZIndex = 53
			button.Parent = systemFrame

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = button

			button.MouseButton1Click:Connect(function()
				if not isInBattle then
					-- Systemモーダルを閉じてから、次のモーダルまたはアクションを実行
					-- showLogoutInnerは内部でcloseModalを呼ばないため、ここでcloseModalする
					if btnData.name ~= "ログアウト" and btnData.name ~= "初期化" then
						closeModal()
					end
					btnData.func()
				end
			end)

			button.MouseEnter:Connect(function()
				if not isInBattle then
					button.BackgroundColor3 = btnData.color:Lerp(Color3.new(1, 1, 1), 0.3)
				end
			end)
			button.MouseLeave:Connect(function()
				button.BackgroundColor3 = btnData.color
			end)
		end
	end)
end

-- メニューUI作成
local function createMenuUI()
	menuGui = Instance.new("ScreenGui")
	menuGui.Name = "MenuUI"
	menuGui.ResetOnSpawn = false
	menuGui.Parent = playerGui

	menuFrame = Instance.new("Frame")
	menuFrame.Name = "MenuFrame"
	menuFrame.Size = UDim2.new(0, 250, 0, 120)
	menuFrame.Position = UDim2.new(1, -270, 1, -270)
	menuFrame.BackgroundTransparency = 1
	menuFrame.Parent = menuGui

	local menuButtons = {
		{ name = "ステータス", func = showStatus, row = 0, col = 0 },
		{ name = "アイテム", func = showItems, row = 0, col = 1 },
		{ name = "スキル", func = showSkills, row = 0, col = 2 },
		{ name = "戦歴", func = showRecords, row = 1, col = 0 },
		{ name = "設定", func = showSettings, row = 1, col = 1 },
		{ name = "システム", func = showSystem, row = 1, col = 2 }, -- ★修正: ログアウトをシステムに置き換え
	}

	local buttonWidth = 80
	local buttonHeight = 50
	local spacing = 5

	for _, btnData in ipairs(menuButtons) do
		local button = Instance.new("TextButton")
		button.Name = btnData.name .. "Button"
		button.Size = UDim2.new(0, buttonWidth, 0, buttonHeight)
		button.Position = UDim2.new(0, btnData.col * (buttonWidth + spacing), 0, btnData.row * (buttonHeight + spacing))
		button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		button.BackgroundTransparency = 0.2
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextSize = 14
		button.Text = btnData.name
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextStrokeTransparency = 0.7
		button.Parent = menuFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			if not isInBattle then
				btnData.func()
			end
		end)

		button.MouseEnter:Connect(function()
			if not isInBattle then
				button.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
			end
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		end)
	end

	log.debugf("メニューUI作成完了")
end

createMenuUI()

if RequestStatusEvent then
	task.wait(1)
	RequestStatusEvent:FireServer()
end

log.debugf("初期化完了")
