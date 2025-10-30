-- ServerScriptService/BattleSystem.lua
-- バトルシステムの管理（敵の定期攻撃対応版）
-- ステップ4: SharedState統合版

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- 【ステップ4】SharedStateとGameEventsをロード
local SharedState = require(ReplicatedStorage:WaitForChild("SharedState"))
local GameEvents = require(ReplicatedStorage:WaitForChild("GameEvents"))

local BattleSystem = {}

-- PlayerStatsモジュールをロード
local PlayerStats = require(ServerScriptService:WaitForChild("PlayerStats"))

-- 【ステップ4】グローバル変数をSharedStateに移行
-- SharedState.ActiveBattles = {}  -- 既にSharedStateで定義済み
-- SharedState.GlobalBattleActive = false  -- 追加が必要
-- SharedState.EndingBattles = {}  -- 追加が必要
-- SharedState.DefeatedByMonster = {}  -- 追加が必要

-- 初期化（SharedStateに追加のフィールドを設定）
if not SharedState.GlobalBattleActive then
	SharedState.GlobalBattleActive = false
end
if not SharedState.EndingBattles then
	SharedState.EndingBattles = {}
end
if not SharedState.DefeatedByMonster then
	SharedState.DefeatedByMonster = {}
end

-- バトル終了直後のクールダウン
local LastBattleEndTime = 0
local BATTLE_COOLDOWN = 0.5

-- ★ 攻撃間隔の基準（拮抗=4s、+100→8s、-100→1s）
local function computeBaseEnemyInterval(playerSpeed: number, enemySpeed: number): number
	local diff = (playerSpeed or 0) - (enemySpeed or 0)
	if diff <= 0 then
		-- diff: -100→0 を 1s→4s に線形マップ
		return 1 + 0.03 * math.clamp(diff + 100, 0, 100) -- 1～4
	else
		-- diff: 0→+100 を 4s→8s に線形マップ
		return 4 + 0.04 * math.clamp(diff, 0, 100) -- 4～8
	end
end

-- ★ 将来のバフ/デバフ倍率を掛ける（逸脱許容のため緩い最終クランプ）
local MIN_INTERVAL, MAX_INTERVAL = 0.5, 12
local function applyIntervalModifiers(baseInterval: number, multiplier: number?): number
	return math.clamp(baseInterval * (multiplier or 1), MIN_INTERVAL, MAX_INTERVAL)
end

-- ★（任意拡張）状態から倍率を集計する入口。現状は1固定。
local function getIntervalMultiplierFor(player: Player, monsterDef): number
	-- 例：SharedStateや一時的なStatusからスロウ/ヘイストを読む
	-- return (SharedState.IntervalMult[player] or 1)
	return 1
end

-- RemoteEvent の作成/取得
local function getOrCreateRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
		-- print(("[BattleSystem] RemoteEvent作成: %s"):format(name))
	end
	return event
end

-- RemoteEventsを作成
local BattleStartEvent = getOrCreateRemoteEvent("BattleStart")
local BattleEndEvent = getOrCreateRemoteEvent("BattleEnd")
local BattleVictoryEvent = getOrCreateRemoteEvent("BattleVictory")
local BattleDamageEvent = getOrCreateRemoteEvent("BattleDamage")
local BattleHPUpdateEvent = getOrCreateRemoteEvent("BattleHPUpdate")
local PlayerHPUpdateEvent = getOrCreateRemoteEvent("PlayerHPUpdate")
local StatusUpdateEvent = getOrCreateRemoteEvent("StatusUpdate")
local RequestStatusEvent = getOrCreateRemoteEvent("RequestStatus")
local LevelUpEvent = getOrCreateRemoteEvent("LevelUp")
local ShowDeathUIEvent = getOrCreateRemoteEvent("ShowDeathUI")
local DeathChoiceEvent = getOrCreateRemoteEvent("DeathChoice")
local TypingMistakeEvent = getOrCreateRemoteEvent("TypingMistake")
local EnemyAttackCycleStartEvent = getOrCreateRemoteEvent("EnemyAttackCycleStart")
local EnemyDamageEvent = getOrCreateRemoteEvent("EnemyDamage")
local RequestEnemyCycleSyncEvent = getOrCreateRemoteEvent("RequestEnemyCycleSync")


print("[BattleSystem] RemoteEvents準備完了")

-- モンスター定義を取得
local MonstersRegistry = require(ReplicatedStorage:WaitForChild("Monsters"):WaitForChild("Registry"))

-- プレイヤーのステータスをクライアントに送信
local function sendStatusUpdate(player: Player)
	local stats = PlayerStats.getStats(player)
	if not stats then return end

	-- PlayerStats.getExpToNext を使う
	local expToNext = 0
	if PlayerStats.getExpToNext then
		expToNext = PlayerStats.getExpToNext(stats.Level)
	else
		expToNext = math.floor(50 * (stats.Level ^ 1.7) + 0.5) -- 念のためのフォールバック
	end

	StatusUpdateEvent:FireClient(
		player,
		stats.CurrentHP,
		stats.MaxHP,
		stats.Level,
		stats.Experience,
		expToNext,
		stats.Gold
	)
end

-- プレイヤーが戦闘中かチェック
function BattleSystem.isInBattle(player: Player): boolean
	return SharedState.ActiveBattles[player] ~= nil
end

-- グローバルなバトル状態を取得
function BattleSystem.isAnyBattleActive(): boolean
	return SharedState.GlobalBattleActive
end

-- モンスター定義を名前から取得
local function getMonsterDef(monsterName)
	for _, def in ipairs(MonstersRegistry) do
		if def.Name == monsterName then
			return def
		end
	end
	return nil
end

-- ダメージを計算（敵→プレイヤー）
local function calculateDamage(attackerAttack: number, defenderDefense: number): number
	-- 基本ダメージ = 攻撃力 * 0.5 - 守備力 * 0.25
	local baseDamage = attackerAttack * 0.5 - defenderDefense * 0.25
	baseDamage = math.max(1, baseDamage)  -- 最低1ダメージ

	-- ±10%のランダム幅
	local randomMultiplier = 0.9 + math.random() * 0.2  -- 0.9 ~ 1.1
	local finalDamage = baseDamage * randomMultiplier

	return math.floor(finalDamage)  -- 整数に丸める
end

-- 攻撃間隔を計算
local function calculateAttackInterval(playerSpeed: number, enemySpeed: number, player: Player, monsterDef): number
	local base = computeBaseEnemyInterval(playerSpeed, enemySpeed)
	local mult = getIntervalMultiplierFor(player, monsterDef) -- 将来拡張
	return applyIntervalModifiers(base, mult)
end

-- 敵の攻撃処理
-- 敵の攻撃処理
local function enemyAttack(player: Player, battleData)
	-- 安全ガード
	if not battleData or not battleData.monster or not battleData.monsterDef then
		warn(("[BattleSystem] invalid battleData; aborting enemyAttack for %s"):format(player.Name))
		return
	end

	local monsterDef = battleData.monsterDef
	local playerStats = PlayerStats.getStats(player)
	if not playerStats then
		warn(("[BattleSystem] %s のステータスが見つかりません"):format(player.Name))
		return
	end

	-- ダメージ計算
	local damage = calculateDamage(monsterDef.Attack, playerStats.Defense)
	print(("[BattleSystem] %s が %s から %d ダメージを受けた"):format(player.Name, battleData.monster.Name, damage))

	-- ダメージ反映
	local isDead = PlayerStats.takeDamage(player, damage)

	-- クライアントに「敵ターンの被弾」を通知（赤点滅＋SE用）
	EnemyDamageEvent:FireClient(player, { amount = damage })

	-- HP更新を通知
	PlayerHPUpdateEvent:FireClient(player, playerStats.CurrentHP, playerStats.MaxHP)

	if isDead then
		print(("[BattleSystem] %s は倒れた！"):format(player.Name))
		BattleSystem.endBattle(player, false)
		return
	end

	-- 次サイクルを確定
	local attackInterval = calculateAttackInterval(playerStats.Speed, monsterDef.Speed, player, monsterDef)
	local nowTick = tick()
	battleData.nextAttackTime = nowTick + attackInterval

	-- クライアントに次サイクル開始を通知（プログレス同期）
	EnemyAttackCycleStartEvent:FireClient(player, { intervalSec = attackInterval, startedAt = nowTick })

	print(("[BattleSystem] 次の攻撃まで %.1f 秒"):format(attackInterval))
end


-- バトル開始
function BattleSystem.startBattle(player: Player, monster: Model)
	print(("[BattleSystem] startBattle呼び出し: %s vs %s"):format(player.Name, monster.Name))

	-- クールダウンチェック
	local timeSinceLastBattle = tick() - LastBattleEndTime
	if timeSinceLastBattle < BATTLE_COOLDOWN then
		return false
	end

	-- 二重チェック
	if SharedState.GlobalBattleActive then
		return false
	end

	if BattleSystem.isInBattle(player) then
		return false
	end

	-- 終了処理中チェック
	if SharedState.EndingBattles[player] then
		print(("[BattleSystem] %s は終了処理中です"):format(player.Name))
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local monsterHumanoid = monster:FindFirstChildOfClass("Humanoid")
	local monsterHrp = monster.PrimaryPart

	if not humanoid or not hrp or not monsterHumanoid or not monsterHrp then
		return false
	end

	-- モンスターの種類を取得
	local monsterKind = monster:GetAttribute("MonsterKind") or "Unknown"
	local monsterDef = getMonsterDef(monsterKind)

	if not monsterDef then
		warn(("[BattleSystem] モンスター定義が見つかりません: %s"):format(monsterKind))
		return false
	end

	-- プレイヤーステータスを取得
	local playerStats = PlayerStats.getStats(player)
	if not playerStats then
		warn(("[BattleSystem] %s のステータスが見つかりません"):format(player.Name))
		return false
	end

	print(("[BattleSystem] バトル開始: %s vs %s"):format(player.Name, monster.Name))
	print(("  プレイヤー: HP %d/%d, 素早さ %d, 攻撃 %d, 守備 %d"):format(
		playerStats.CurrentHP, playerStats.MaxHP,
		playerStats.Speed, playerStats.Attack, playerStats.Defense
		))
	print(("  モンスター: HP %d, 素早さ %d, 攻撃 %d, 守備 %d"):format(
		monsterDef.HP, monsterDef.Speed, monsterDef.Attack, monsterDef.Defense
		))

	-- グローバルバトルフラグをON
	SharedState.GlobalBattleActive = true

	-- 元の速度を保存
	local originalPlayerSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower
	local originalMonsterSpeed = monsterHumanoid.WalkSpeed

	-- プレイヤーを完全停止
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	-- アニメーションを完全停止
	for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	task.wait(0.05)
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	hrp.Anchored = true
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	-- モンスターを完全停止
	monsterHumanoid.WalkSpeed = 0
	monsterHumanoid.JumpPower = 0
	monsterHumanoid:MoveTo(monsterHrp.Position)

	-- モンスターの全パーツをAnchor
	for _, part in ipairs(monster:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	-- プレイヤーの1文字あたりのダメージを計算
	local damagePerKey = math.floor(playerStats.Attack * 0.8)
	damagePerKey = math.max(1, damagePerKey)  -- 最低1ダメージ

	-- 敵の最初の攻撃タイミングを計算
	local attackInterval = calculateAttackInterval(playerStats.Speed, monsterDef.Speed, player, monsterDef)
	local nowTick = tick()
	local nextAttackTime = nowTick + attackInterval

	-- ★ 戦闘データを先に記録（ここが最優先！）
	SharedState.ActiveBattles[player] = {
		monster = monster,
		monsterDef = monsterDef,
		monsterHP = monsterDef.HP,
		monsterMaxHP = monsterDef.HP,
		damagePerKey = damagePerKey,
		nextAttackTime = nextAttackTime,
		startTime = tick(),
		originalPlayerSpeed = originalPlayerSpeed,
		originalJumpPower = originalJumpPower,
		originalMonsterSpeed = originalMonsterSpeed
	}

	-- ★ クライアントにバトル開始を通知（この時点で inBattle = true になる）
	BattleStartEvent:FireClient(
		player,
		monster.Name,
		monsterDef.HP,
		monsterDef.HP,
		damagePerKey,
		monsterDef.TypingLevels or {{level = "level_1", weight = 100}},
		playerStats.CurrentHP,
		playerStats.MaxHP
	)

	-- ★ 初回サイクルをクライアントへ通知（順序は BattleStart の“後”）
	EnemyAttackCycleStartEvent:FireClient(player, { intervalSec = attackInterval, startedAt = nowTick })

	-- ★ 敵の攻撃ループを開始（最後に）
	task.spawn(function()
		while SharedState.ActiveBattles[player] and not SharedState.EndingBattles[player] do
			local bd = SharedState.ActiveBattles[player]
			if not bd then break end

			if tick() >= bd.nextAttackTime then
				enemyAttack(player, bd)
			end

			task.wait(0.1)
		end
	end)
	-- ここから追記（関数を閉じる）
	return true
end


-- プレイヤーからのダメージ処理
local function onDamageReceived(player, damageAmount)
	-- バトル終了処理中はダメージを無視
	if SharedState.EndingBattles[player] then
		print(("[BattleSystem] %s は終了処理中のため、ダメージを無視"):format(player.Name))
		return
	end

	local battleData = SharedState.ActiveBattles[player]
	if not battleData then
		warn(("[BattleSystem] %s はバトル中ではありません（ダメージ無視）"):format(player.Name))
		return
	end

	-- HPを減らす
	local oldHP = battleData.monsterHP
	battleData.monsterHP = math.max(0, battleData.monsterHP - damageAmount)

	print(("[BattleSystem] ========================================"):format())
	print(("[BattleSystem] ダメージ処理"):format())
	print(("  プレイヤー: %s"):format(player.Name))
	print(("  ダメージ量: %d"):format(damageAmount))
	print(("  HP変化: %d → %d"):format(oldHP, battleData.monsterHP))
	print(("  最大HP: %d"):format(battleData.monsterMaxHP))
	print(("[BattleSystem] ========================================"):format())

	-- クライアントにHP更新を通知
	BattleHPUpdateEvent:FireClient(player, battleData.monsterHP)

	-- HPが0になったら勝利
	if battleData.monsterHP <= 0 then
		print(("[BattleSystem] ========================================"):format())
		print(("[BattleSystem] 🎉 勝利条件達成！"):format())
		print(("  %s が %s を倒しました！"):format(player.Name, battleData.monster.Name))
		print(("  モンスターHP: %d"):format(battleData.monsterHP))
		print(("[BattleSystem] endBattle(true) を呼び出します"):format())
		print(("[BattleSystem] ========================================"):format())

		BattleSystem.endBattle(player, true)

		print(("[BattleSystem] endBattle(true) 呼び出し完了"):format())
	end
end

-- バトル終了
function BattleSystem.endBattle(player: Player, victory: boolean)
	print(("[BattleSystem] バトル終了: %s - %s"):format(
		player.Name, victory and "勝利" or "敗北"
		))

	-- 二重終了チェック
	if SharedState.EndingBattles[player] then
		warn(("[BattleSystem] %s は既に終了処理中です"):format(player.Name))
		return
	end

	-- 終了処理中フラグを立てる
	SharedState.EndingBattles[player] = true

	-- 【重要】勝利時のみグローバルバトルフラグをOFF
	-- 敗北時は死亡選択が完了するまで維持
	if victory then
		SharedState.GlobalBattleActive = false
	end

	-- クールダウン開始
	LastBattleEndTime = tick()

	local battleData = SharedState.ActiveBattles[player]
	if not battleData then
		warn("[BattleSystem] battleDataが存在しません！")

		-- 最低限の復元
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if humanoid then
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
				humanoid.JumpHeight = 7.2
			end
			if hrp then
				hrp.Anchored = false
			end
		end

		-- クライアントに通知
		BattleEndEvent:FireClient(player, victory, nil)

		SharedState.ActiveBattles[player] = nil

		-- 終了処理完了後にフラグを解除
		task.delay(1, function()
			SharedState.EndingBattles[player] = nil
		end)

		return
	end

	local character = player.Character
	local monster = battleData.monster
	local monsterDef = battleData.monsterDef

	-- 勝利時の処理
	if victory then
		-- プレイヤーの移動を復元
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if humanoid then
				humanoid.WalkSpeed = battleData.originalPlayerSpeed or 16
				humanoid.JumpPower = battleData.originalJumpPower or 50
				humanoid.JumpHeight = 7.2
			end
			if hrp then
				hrp.Anchored = false
			end
		end

		-- 経験値とゴールドを付与
		if monsterDef.Experience then
			print(("[BattleSystem] 経験値 %d を付与"):format(monsterDef.Experience))
			PlayerStats.addExperience(player, monsterDef.Experience)
		end
		if monsterDef.Gold then
			print(("[BattleSystem] ゴールド %d を付与"):format(monsterDef.Gold))
			PlayerStats.addGold(player, monsterDef.Gold)
		end

		print(("[BattleSystem] ========================================"):format())
		print(("[BattleSystem] モンスター撃破カウント処理開始"):format())
		print(("[BattleSystem] プレイヤー: %s"):format(player.Name))
		print(("[BattleSystem] モンスター: %s"):format(battleData.monster.Name))


		PlayerStats.addMonstersDefeated(player, 1)

		print(("[BattleSystem] モンスター撃破カウント処理完了"):format())
		print(("[BattleSystem] ========================================"):format())


		-- 少し待ってからステータス更新を送信（念のため）
		task.wait(0.1)
		sendStatusUpdate(player)

		-- モンスターを非表示
		monster:SetAttribute("Defeated", true)

		for _, part in ipairs(monster:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 1
			end
		end

		local hrp = monster:FindFirstChild("HumanoidRootPart")
		if hrp then
			local gui = hrp:FindFirstChild("DebugInfo")
			if gui then
				gui.Enabled = false
			end
		end

		-- 1秒後に削除
		task.delay(1, function()
			if monster and monster.Parent then
				monster:Destroy()
			end
		end)
	else
		-- 敗北時：プレイヤーは移動制限を維持（死亡選択UIで選んだ後に復元）
		-- モンスターを復元
		monster:SetAttribute("InBattle", false)

		local monsterHumanoid = monster:FindFirstChildOfClass("Humanoid")
		if monsterHumanoid then
			monsterHumanoid.WalkSpeed = battleData.originalMonsterSpeed or 14
		end

		-- Anchor解除
		local partsToUnanchor = {}
		for _, part in ipairs(monster:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				table.insert(partsToUnanchor, part)
			end
		end

		for _, part in ipairs(partsToUnanchor) do
			part.Anchored = false
		end

		if monster.PrimaryPart then
			task.wait(0.1)
			monster.PrimaryPart.Anchored = false
		end

		-- 死亡時の選択UIを表示
		local playerStats = PlayerStats.getStats(player)
		if playerStats then
			local reviveCost = math.floor(playerStats.Level * 50)  -- レベル * 50ゴールド
			print(("[BattleSystem] ========================================"):format())
			print(("[BattleSystem] 死亡UI表示を送信"):format())
			print(("[BattleSystem] 所持金: %d G, 復活コスト: %d G"):format(playerStats.Gold, reviveCost))
			print(("[BattleSystem] ========================================"):format())

			-- プレイヤーに死亡フラグを立てる（モンスターが接触しないように）
			if character then
				character:SetAttribute("IsDead", true)
				print(("[BattleSystem] %s に死亡フラグを設定"):format(player.Name))
			end

			-- 【重要】倒したモンスターを記録（選択後に消去するため）
			SharedState.DefeatedByMonster[player] = monster
			print(("[BattleSystem] 倒したモンスター %s を記録"):format(monster.Name))

			ShowDeathUIEvent:FireClient(player, playerStats.Gold, reviveCost)
		else
			warn("[BattleSystem] プレイヤーステータスが見つかりません！")
		end
	end

	-- クライアントに通知
	local summary = nil
	if victory then
		local exp = (monsterDef and monsterDef.Experience) or 0
		local gold = (monsterDef and monsterDef.Gold) or 0
		-- ドロップ定義があれば使う。なければ空配列でOK
		local drops = (monsterDef and monsterDef.Drops) or {}
		summary = { exp = exp, gold = gold, drops = drops }
	end

	BattleEndEvent:FireClient(player, victory, summary)

	-- 勝利時は戦闘データをクリアして終了処理フラグも解除
	if victory then
		SharedState.ActiveBattles[player] = nil

		-- 終了処理完了後にフラグを解除（1秒後）
		task.delay(1, function()
			SharedState.EndingBattles[player] = nil
			print(("[BattleSystem] %s の終了処理フラグを解除"):format(player.Name))
		end)
	else
		-- 敗北時は戦闘データをクリアするが、終了処理フラグは維持
		-- （死亡選択UIで選んだ後に解除する）
		SharedState.ActiveBattles[player] = nil
		print(("[BattleSystem] 敗北 - 終了処理フラグを維持します（選択まで）"))
	end
end

-- 初期化
function BattleSystem.init()
	-- ステータスリクエストイベント
	RequestStatusEvent.OnServerEvent:Connect(function(player)
		print(("[BattleSystem] %s がステータスを要求しました"):format(player.Name))
		sendStatusUpdate(player)
	end)

	-- ダメージイベント
	BattleDamageEvent.OnServerEvent:Connect(function(player, damageAmount)
		print(("[BattleSystem] ダメージ通知受信: %s -> %d"):format(player.Name, damageAmount))
		onDamageReceived(player, damageAmount)
	end)

	-- クライアントからのサイクル再同期リクエスト
	RequestEnemyCycleSyncEvent.OnServerEvent:Connect(function(player)
		-- バトル中＆終了処理中でないことを確認
		local bd = SharedState.ActiveBattles[player]
		if not bd or SharedState.EndingBattles[player] then
			return
		end

		-- 必要情報を取得
		local stats = PlayerStats.getStats(player)
		if not stats or not bd.monsterDef then
			return
		end

		-- 現在の（設計上の）インターバルを計算
		local intervalSec = calculateAttackInterval(stats.Speed, bd.monsterDef.Speed, player, bd.monsterDef)

		-- 経過と残り時間から startedAt を逆算（クライアントのプログレスを滑らかに）
		local now = tick()
		local remaining = math.max(0.05, bd.nextAttackTime - now)              -- もうすぐ発動の場合も最低0.05秒
		local elapsed = math.clamp(intervalSec - remaining, 0, intervalSec)    -- 経過時間をクランプ
		local startedAt = now - elapsed

		-- クライアントに「今このペースで回ってるよ」を即通知
		EnemyAttackCycleStartEvent:FireClient(player, {
			intervalSec = intervalSec,
			startedAt   = startedAt
		})
	end)


	-- 勝利イベント（念のため残しておく）
	BattleVictoryEvent.OnServerEvent:Connect(function(player)
		print(("[BattleSystem] 勝利通知受信: %s"):format(player.Name))

		if BattleSystem.isInBattle(player) then
			BattleSystem.endBattle(player, true)
		end
	end)

	-- 死亡時の選択イベント
	DeathChoiceEvent.OnServerEvent:Connect(function(player, choice)
		print(("[BattleSystem] %s が選択: %s"):format(player.Name, choice))

		-- 【重要】グローバルバトルフラグを解除（敗北時に維持していた）
		SharedState.GlobalBattleActive = false
		print("[BattleSystem] グローバルバトルフラグを解除")

		-- 【重要】終了処理フラグを解除（モンスターが接触できるようにする）
		SharedState.EndingBattles[player] = nil
		print(("[BattleSystem] %s の終了処理フラグを解除"):format(player.Name))

		local playerStats = PlayerStats.getStats(player)
		if not playerStats then return end

		-- 死亡フラグを解除
		local character = player.Character
		if character then
			character:SetAttribute("IsDead", false)
			print(("[BattleSystem] %s の死亡フラグを解除"):format(player.Name))
		end

		-- プレイヤーの移動制限を解除
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if humanoid then
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
				humanoid.JumpHeight = 7.2
			end
			if hrp then
				hrp.Anchored = false
			end
		end

		-- 【重要】倒したモンスターを消去（両方の選択肢で消去）
		local defeatedMonster = SharedState.DefeatedByMonster[player]
		if defeatedMonster and defeatedMonster.Parent then
			print(("[BattleSystem] 倒したモンスター %s を消去"):format(defeatedMonster.Name))

			-- 非表示化
			defeatedMonster:SetAttribute("Defeated", true)
			for _, part in ipairs(defeatedMonster:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 1
				end
			end

			-- ラベル非表示
			local hrp = defeatedMonster:FindFirstChild("HumanoidRootPart")
			if hrp then
				local gui = hrp:FindFirstChild("DebugInfo")
				if gui then
					gui.Enabled = false
				end
			end

			-- 削除
			task.delay(0.5, function()
				if defeatedMonster and defeatedMonster.Parent then
					defeatedMonster:Destroy()
				end
			end)
		end

		-- 記録をクリア
		SharedState.DefeatedByMonster[player] = nil

		if choice == "return" then
			-- 街に戻る
			print(("[BattleSystem] %s を街に戻します"):format(player.Name))

			-- HPを全回復
			PlayerStats.fullHeal(player)

			-- StartTownの座標を取得
			print("[BattleSystem] StartTownの座標を取得中...")
			local IslandsRegistry = require(ReplicatedStorage:WaitForChild("Islands"):WaitForChild("Registry"))
			print(("[BattleSystem] IslandsRegistry取得完了。島の数: %d"):format(#IslandsRegistry))

			local townConfig = nil
			for i, island in ipairs(IslandsRegistry) do
				print(("[BattleSystem] 島 %d: name=%s"):format(i, tostring(island.name)))
				if island.name == "StartTown" then
					townConfig = island
					print("[BattleSystem] StartTownを発見！")
					break
				end
			end

			-- 街にテレポート
			if character and townConfig then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local spawnX = townConfig.centerX
					local spawnZ = townConfig.centerZ
					local spawnY = townConfig.baseY + 50  -- 高めに設定
					print(("[BattleSystem] テレポート座標: X=%.0f, Y=%.0f, Z=%.0f"):format(
						spawnX, spawnY, spawnZ
						))

					-- テレポート実行
					hrp.CFrame = CFrame.new(spawnX, spawnY, spawnZ)

					-- 少し待ってから再度設定（他のシステムの干渉を防ぐ）
					task.wait(0.1)
					hrp.CFrame = CFrame.new(spawnX, spawnY, spawnZ)

					print(("[BattleSystem] %s を街にテレポート完了"):format(player.Name))

					-- ZoneManagerにも通知
					local ZoneManager = require(ServerScriptService:WaitForChild("ZoneManager"))
					ZoneManager.PlayerZones[player] = "StartTown"
					print("[BattleSystem] ZoneManagerにStartTownを記録")

					-- 【重要】StartTownのポータルを再生成
					if _G.CreatePortalsForZone then
						print("[BattleSystem] StartTownのポータルを再生成")
						_G.CreatePortalsForZone("StartTown")
					else
						warn("[BattleSystem] CreatePortalsForZone関数が見つかりません")
					end
				end
			elseif character then
				-- フォールバック：townConfigが見つからない場合
				warn("[BattleSystem] StartTownが見つかりません！")
				print("[BattleSystem] フォールバック：原点にテレポート")
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.CFrame = CFrame.new(0, 50, 0)
				end
			end

			-- ステータス更新
			sendStatusUpdate(player)

		elseif choice == "revive" then
			-- ゴールドで復活
			local reviveCost = math.floor(playerStats.Level * 50)

			if PlayerStats.removeGold(player, reviveCost) then
				print(("[BattleSystem] %s がゴールド %d で復活"):format(player.Name, reviveCost))

				-- HPを全回復
				PlayerStats.fullHeal(player)

				-- 【重要】復活後のクールダウンを設定（3秒間バトル不可）
				LastBattleEndTime = tick()
				print("[BattleSystem] 復活後のクールダウン開始")

				-- ステータス更新
				sendStatusUpdate(player)
			else
				warn(("[BattleSystem] %s のゴールドが不足しています"):format(player.Name))
			end
		end
	end)

	-- ダメージイベント
	BattleDamageEvent.OnServerEvent:Connect(function(player, damageAmount)
		print(("[BattleSystem] ダメージ通知受信: %s -> %d"):format(player.Name, damageAmount))
		onDamageReceived(player, damageAmount)
	end)

	-- タイプミスイベント（新規追加）
	TypingMistakeEvent.OnServerEvent:Connect(function(player)
		print(("[BattleSystem] タイプミス受信: %s"):format(player.Name))

		local battleData = SharedState.ActiveBattles[player]
		if not battleData then
			warn(("[BattleSystem] %s はバトル中ではありません（タイプミス無視）"):format(player.Name))
			return
		end

		local monsterDef = battleData.monsterDef
		local playerStats = PlayerStats.getStats(player)

		if not playerStats then
			warn(("[BattleSystem] %s のステータスが見つかりません"):format(player.Name))
			return
		end

		-- タイプミスダメージ = 敵の通常攻撃の半分
		local normalDamage = calculateDamage(monsterDef.Attack, playerStats.Defense)
		local mistakeDamage = math.floor(normalDamage * 0.5)
		mistakeDamage = math.max(1, mistakeDamage)  -- 最低1ダメージ

		print(("[BattleSystem] %s がタイプミスで %d ダメージ"):format(player.Name, mistakeDamage))

		-- ダメージ処理
		local isDead = PlayerStats.takeDamage(player, mistakeDamage)

		-- HPをクライアントに通知
		PlayerHPUpdateEvent:FireClient(player, playerStats.CurrentHP, playerStats.MaxHP)

		-- 死亡判定
		if isDead then
			print(("[BattleSystem] %s はタイプミスで倒れた！"):format(player.Name))
			BattleSystem.endBattle(player, false)  -- 敗北
		end
	end)

	-- 勝利イベント（念のため残しておく）

	-- デッドロック検出
	task.spawn(function()
		while true do
			task.wait(5)

			for player, battleData in pairs(SharedState.ActiveBattles) do
				local duration = tick() - battleData.startTime

				if duration > 60 then
					warn(("[BattleSystem] デッドロック検出！ %s のバトルを強制終了"):format(player.Name))
					BattleSystem.endBattle(player, false)
				end
			end
		end
	end)

	print("[BattleSystem] 初期化完了（敵攻撃システム対応）")
end

-- バトル状態を強制リセット
function BattleSystem.resetAllBattles()
	print("[BattleSystem] 全バトル状態をリセット")

	SharedState.GlobalBattleActive = false

	for player, _ in pairs(SharedState.ActiveBattles) do
		SharedState.ActiveBattles[player] = nil
		SharedState.EndingBattles[player] = nil

		if player.Character then
			player.Character:SetAttribute("InBattle", false)

			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if humanoid then
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
				humanoid.JumpHeight = 7.2
			end
			if hrp then
				hrp.Anchored = false
			end
		end
	end

	local monstersFolder = workspace:FindFirstChild("Monsters")
	if monstersFolder then
		for _, model in ipairs(monstersFolder:GetChildren()) do
			if model:IsA("Model") then
				model:SetAttribute("InBattle", false)
				model:SetAttribute("Defeated", false)
			end
		end
	end

	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("IsEnemy") then
			model:SetAttribute("InBattle", false)
			model:SetAttribute("Defeated", false)
		end
	end

	print("[BattleSystem] リセット完了")
end

return BattleSystem