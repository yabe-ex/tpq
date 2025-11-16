-- StarterPlayer/StarterPlayerScripts/BGMManager.client.lua
-- 大陸BGM管理システム (バトル中の音量調整対応版)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService") -- TweenServiceを追加

local player = Players.LocalPlayer

-- 大陸情報を読み込み
local ContinentsRegistry = require(ReplicatedStorage.Continents.Registry)
local Continents = {}
for _, continent in ipairs(ContinentsRegistry) do
	Continents[continent.name] = continent
end

-- BGM状態
local currentBGM = nil
local currentZone = nil
local isBattleActive = false
local bgmSound = nil
local originalVolume = 0.3 -- 【追加・修正1】元の音量を保持する変数を追加（デフォルト値 0.3）

-- === User Settings bridge ===
local function getAttrNum(name, default)
	local v = Players.LocalPlayer:GetAttribute(name)
	return (type(v) == "number") and v or default
end

-- SE/BGMの反映（SEはSoundService全体、BGMはbgmSoundに適用）
local function applyVolumes()
	local se = getAttrNum("SEVolume", 1.0)
	local bgm = getAttrNum("BGMVolume", 1.0)

	-- 注: SoundServiceにVolumeプロパティは存在しないため、SE音量は個別のSoundオブジェクトで調整する必要がある

	-- BGMは isBattleActive 中はディミング係数(0.3)が乗る
	if bgmSound then
		local base = originalVolume -- originalVolume は createBGMSound で更新
		local dim = isBattleActive and 0.3 or 1.0
		bgmSound.Volume = base * dim
	end
end

-- BGMサウンドを作成
local function createBGMSound(assetId, volume)
	if bgmSound then
		bgmSound:Stop()
		bgmSound:Destroy()
	end

	bgmSound = Instance.new("Sound")
	bgmSound.Name = "BGM"
	bgmSound.SoundId = assetId

	-- 【修正2】音量を設定し、originalVolumeを更新
	local userBGM = tonumber(Players.LocalPlayer:GetAttribute("BGMVolume")) or 1.0
	local finalVolume = (volume or 0.3) * userBGM
	bgmSound.Volume = finalVolume
	originalVolume = finalVolume

	bgmSound.Looped = true
	bgmSound.Parent = SoundService

	return bgmSound
end

-- BGMを再生
local function playBGM(assetId, volume)
	if currentBGM == assetId and bgmSound and bgmSound.IsPlaying and not isBattleActive then
		-- 既に同じBGMが再生中で、戦闘中でなければ何もしない
		return
	end

	print(("[BGMManager] BGM再生: %s, Volume: %.2f"):format(assetId, volume or 0.3))

	currentBGM = assetId
	local sound = createBGMSound(assetId, volume)
	sound:Play()

	-- 新しく再生するBGMが戦闘中に切り替わった場合、音量を下げる
	if isBattleActive and bgmSound then
		bgmSound.Volume = originalVolume * 0.3
	end
end

-- BGMを停止
local function stopBGM()
	if bgmSound then
		print("[BGMManager] BGM停止")

		-- 【修正3】Tweenを使ってスムーズに停止
		TweenService:Create(bgmSound, TweenInfo.new(0.5), {
			Volume = 0,
		}):Play()

		task.delay(0.5, function()
			-- 0.5秒後、音量が0であることを確認して停止・削除
			if bgmSound and bgmSound.Volume == 0 then
				bgmSound:Stop()
				bgmSound:Destroy()
				bgmSound = nil -- 参照をクリア
			end
		end)
	end
	currentBGM = nil
end

-- ゾーン変更時のBGM処理
local function onZoneChange(zoneName, isActive)
	if isActive then
		-- ゾーンに入った
		currentZone = zoneName

		-- 大陸のBGM設定を取得
		local continent = Continents[zoneName]
		if continent and continent.BGM then
			-- BGMVolumeをplayBGMに渡して、originalVolumeに保存させる
			playBGM(continent.BGM, continent.BGMVolume or 0.3)
		else
			-- BGM設定がない場合は停止
			stopBGM()
		end
	else
		-- ゾーンから出た場合もBGMを停止
		if currentZone == zoneName then
			stopBGM()
			currentZone = nil
		end
	end
end

-- バトル開始イベント
local BattleStartEvent = ReplicatedStorage:WaitForChild("BattleStart", 10)
if BattleStartEvent then
	BattleStartEvent.OnClientEvent:Connect(function()
		print("[BGMManager] バトル開始を検知")
		isBattleActive = true

		-- 【修正4】BGMを停止せず、音量を50%に下げる
		if bgmSound and bgmSound.IsPlaying then
			local targetVolume = originalVolume * 0.3 -- 元の音量の50%
			print(("[BGMManager] BGM音量を %.2f から %.2f に調整"):format(bgmSound.Volume, targetVolume))
			TweenService:Create(bgmSound, TweenInfo.new(0.5), {
				Volume = targetVolume,
			}):Play()
		end
	end)
end

-- バトル終了イベント
local BattleEndEvent = ReplicatedStorage:WaitForChild("BattleEnd", 10)
if BattleEndEvent then
	BattleEndEvent.OnClientEvent:Connect(function()
		print("[BGMManager] バトル終了を検知")
		isBattleActive = false

		-- 【修正5】BGMを元の音量に戻す
		if bgmSound and bgmSound.IsPlaying then
			print(("[BGMManager] BGM音量を %.2f に戻す"):format(originalVolume))
			TweenService:Create(bgmSound, TweenInfo.new(0.5), {
				Volume = originalVolume,
			}):Play()
		end
	end)
end

-- ゾーン変更を監視
task.spawn(function()
	local ZoneChangeEvent = ReplicatedStorage:FindFirstChild("ZoneChange")
	if not ZoneChangeEvent then
		warn("[BGMManager] ZoneChangeイベントが見つかりません")
		return
	end

	ZoneChangeEvent.OnClientEvent:Connect(function(zoneName, isActive)
		print(("[BGMManager] ゾーン変更: %s - %s"):format(zoneName, isActive and "入った" or "出た"))
		onZoneChange(zoneName, isActive)
	end)

	-- プレイヤー属性の変化を監視して随時反映
	Players.LocalPlayer:GetAttributeChangedSignal("SEVolume"):Connect(applyVolumes)
	Players.LocalPlayer:GetAttributeChangedSignal("BGMVolume"):Connect(function()
		-- originalVolume は createBGMSound 時に更新済みなので、
		-- ここでは現在の originalVolume を使って音量だけ再適用
		applyVolumes()
	end)

	print("[BGMManager] ZoneChangeイベント接続完了")
end)

applyVolumes()
print("[BGMManager] 初期化完了")
