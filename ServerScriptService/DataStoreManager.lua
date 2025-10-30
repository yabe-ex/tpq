-- ServerScriptService/DataStoreManager.lua
-- DataStoreの基本操作を管理するモジュール

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreManager = {}

-- DataStoreの定義 (バージョン管理のためV1)
local PLAYER_DATA_STORE = DataStoreService:GetDataStore("TypingQuestPlayerSaveData_V1")

-- ★修正: WaitForChildを廃止し、非ブロッキングのFindFirstChildを使用
local SAVE_SUCCESS_EVENT = ReplicatedStorage:FindFirstChild("SaveSuccess")
local LOAD_GAME_EVENT = ReplicatedStorage:FindFirstChild("LoadGame")

-- DataStoreサービス取得
local success, DataStoreService = pcall(function()
	return game:GetService("DataStoreService")
end)

if not success then
	warn("[DataStoreManager] DataStoreが無効です。Studio設定で有効化してください。")
	-- ダミーのDataStoreを返す
	return {
		SavePlayerData = function()
			warn("[DataStore] 保存スキップ（無効）")
		end,
		LoadPlayerData = function()
			warn("[DataStore] 読込スキップ（無効）")
			return nil
		end,
	}
else
	print("[DataStoreManager] ✅ DataStore設定: 有効")
end

local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

-- データの保存 (非同期)
function DataStoreManager.SaveData(player: Player, data: table)
	local success, err = pcall(function()
		-- プレイヤーのUserIdをキーとして使用
		PLAYER_DATA_STORE:SetAsync(player.UserId, data)
	end)

	-- 【修正】毎回SaveSuccessEventを取得
	local SaveSuccessEvent = ReplicatedStorage:FindFirstChild("SaveSuccess")

	if success then
		print(
			("[DataStoreManager] %s のデータを保存しました。キー: %d"):format(player.Name, player.UserId)
		)

		-- クライアントに保存成功を通知
		if SaveSuccessEvent then
			SaveSuccessEvent:FireClient(player, true)
		end
	else
		warn(("[DataStoreManager] %s のデータ保存に失敗しました: %s"):format(player.Name, err))

		-- クライアントに保存失敗を通知
		if SaveSuccessEvent then
			SaveSuccessEvent:FireClient(player, false)
		end
	end
	return success
end

-- データの読み込み (非同期)
function DataStoreManager.LoadData(player: Player)
	local data = nil
	local success, err = pcall(function()
		-- データの取得 (確実にUserIdを使用)
		data = PLAYER_DATA_STORE:GetAsync(player.UserId)
	end)

	if success then
		print(
			("[DataStoreManager] %s のデータを読み込みました。キー: %d"):format(
				player.Name,
				player.UserId
			)
		)

		-- データがnilの場合、新規プレイヤーとして空のテーブルを返す
		return data or {}
	else
		warn(("[DataStoreManager] %s のデータ読み込みに失敗しました: %s"):format(player.Name, err))
		return {} -- 失敗した場合は空のデータを返し、ゲームを継続させる
	end
end

-- 手動ロード要求イベントリスナー (ロードボタン押下時)
if LOAD_GAME_EVENT then
	LOAD_GAME_EVENT.OnServerEvent:Connect(function(player)
		-- 現状、特別な処理は不要（次の接続時に自動ロードされるため）
		print(("[DataStoreManager] %s からロード要求を受信しました。"):format(player.Name))
	end)
else
	warn(
		"[DataStoreManager] LOAD_GAME_EVENT が見つかりません。ロード要求リスナーは機能しません。"
	)
end

return DataStoreManager
