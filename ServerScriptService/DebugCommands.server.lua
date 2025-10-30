-- ServerScriptService/DebugCommands.server.lua
-- デバッグ用のコマンドを処理するサーバースクリプト

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteEventの作成/取得
local DebugCommandEvent = ReplicatedStorage:FindFirstChild("DebugCommand")
if not DebugCommandEvent then
	DebugCommandEvent = Instance.new("RemoteEvent")
	DebugCommandEvent.Name = "DebugCommand"
	DebugCommandEvent.Parent = ReplicatedStorage
	print("[DebugCommands] RemoteEventを作成しました")
end

-- 依存モジュール
local PlayerStatsModule = require(ServerScriptService:WaitForChild("PlayerStats"))

-- コマンド処理
DebugCommandEvent.OnServerEvent:Connect(function(player, command, ...)
	print(("[DebugCommands] %s が実行: %s"):format(player.Name, command))

	if command == "reset_chests" then
		-- 宝箱リセット
		print("[DebugCommands DEBUG] リセット開始")

		local stats = PlayerStatsModule.getStats(player)
		if stats then
			print("[DebugCommands DEBUG] ステータス取得成功")

			-- リセット前の状態
			local beforeCount = 0
			for _ in pairs(stats.CollectedItems) do beforeCount = beforeCount + 1 end
			print(("[DebugCommands DEBUG] リセット前: %d個"):format(beforeCount))

			-- CollectedItemsを空にする
			stats.CollectedItems = {}

			-- リセット後の状態
			local afterCount = 0
			for _ in pairs(stats.CollectedItems) do afterCount = afterCount + 1 end
			print(("[DebugCommands DEBUG] リセット後: %d個"):format(afterCount))

			print(("[DebugCommands] %s の取得済みアイテムをリセットしました"):format(player.Name))

			-- 即座にセーブ
			if _G.AutoSavePlayer then
				print("[DebugCommands DEBUG] セーブ開始")
				_G.AutoSavePlayer(player, "デバッグリセット")
				task.wait(2)
				print("[DebugCommands DEBUG] セーブ完了")
			else
				warn("[DebugCommands DEBUG] AutoSavePlayer が見つかりません - 手動セーブを試行")

				-- 【修正】手動セーブ
				local success, err = pcall(function()
					local DataStoreManager = require(ServerScriptService:WaitForChild("DataStoreManager"))
					local DataCollectors = require(ServerScriptService:WaitForChild("DataCollectors"))

					-- statsを使ってセーブデータを作成
					local saveData = DataCollectors.createSaveData(player, stats)

					if saveData then
						print(("[DebugCommands DEBUG] セーブデータ作成成功: CollectedItems = %s"):format(
							game:GetService("HttpService"):JSONEncode(saveData.CollectedItems or {})
						))

						-- 【重要な修正】関数名を SaveData に変更
						DataStoreManager.SaveData(player, saveData)
						print("[DebugCommands DEBUG] 手動セーブ完了")
					else
						warn("[DebugCommands DEBUG] セーブデータ作成失敗")
					end
				end)

				if not success then
					warn(("[DebugCommands DEBUG] 手動セーブエラー: %s"):format(tostring(err)))
				end
			end

			-- 【追加】ゾーンをリロードして宝箱を再表示
			print("[DebugCommands DEBUG] ゾーンリロード開始")
			local ZoneManager = require(ServerScriptService:WaitForChild("ZoneManager"))
			local currentZone = ZoneManager.GetPlayerZone(player)

			if currentZone then
				print(("[DebugCommands DEBUG] 現在のゾーン: %s"):format(currentZone))

				-- プレイヤーの現在位置を保存
				local character = player.Character
				local savedPosition = nil
				if character then
					local hrp = character:FindFirstChild("HumanoidRootPart")
					if hrp then
						savedPosition = hrp.CFrame
						-- 【追加】リロード中はプレイヤーを固定して落下を防ぐ
						hrp.Anchored = true
						print(("[DebugCommands DEBUG] プレイヤーを固定: %.1f, %.1f, %.1f"):format(
							savedPosition.Position.X, savedPosition.Position.Y, savedPosition.Position.Z
						))
					end
				end

				-- ゾーンをアンロード
				ZoneManager.UnloadZone(currentZone)
				print("[DebugCommands DEBUG] アンロード完了")

				-- 地形削除を待つ
				task.wait(0.3)

				-- ゾーンを再ロード
				ZoneManager.LoadZone(currentZone)
				print("[DebugCommands DEBUG] リロード完了")

				-- 地形生成とFieldObjects配置を十分待つ
				task.wait(1.5)

				-- プレイヤーの固定を解除
				if character then
					local hrp = character:FindFirstChild("HumanoidRootPart")
					if hrp then
						hrp.Anchored = false
						hrp.Velocity = Vector3.new(0, 0, 0)
						hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						print("[DebugCommands DEBUG] プレイヤーの固定を解除")
					end
				end

				print("[DebugCommands DEBUG] ゾーンリロード完了")
			else
				warn("[DebugCommands DEBUG] プレイヤーのゾーンが見つかりません")
			end
		else
			warn(("[DebugCommands] %s のステータスが見つかりません"):format(player.Name))
		end
	else
		warn(("[DebugCommands] 未知のコマンド: %s"):format(command))
	end
end)

print("[DebugCommands] 初期化完了")