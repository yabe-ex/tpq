-- ServerScriptService/ElevateTerrainLarge
-- ★大規模なTerrainを分割して移動するスクリプト
-- ★このスクリプトは一度だけ実行し、完了後は削除またはDisabledにしてください
--
-- 使い方:
-- 1. このスクリプトをServerScriptServiceにコピー
-- 2. 下記の設定値を変更
-- 3. ゲームを実行（F5キー）
-- 4. Outputウィンドウで進行状況を確認（時間がかかります）
-- 5. 完了後、ゲームを停止（Shift+F5キー）
-- 6. このスクリプトを削除またはDisabledにする

local terrain = workspace.Terrain

-- ========================================
-- ★★★ 設定項目（ここを変更してください） ★★★
-- ========================================

-- 移動させたいTerrainの全体範囲
local fullMinCorner = Vector3.new(-1000, 0, -1000) -- ★全体の最小座標
local fullMaxCorner = Vector3.new(1000, 300, 1000) -- ★全体の最大座標

-- 上方向に移動させる高さ（スタッド単位）
local elevationHeight = 6000 -- ★1000スタッド上に移動

-- ボクセル解像度（4が標準）
local resolution = 4

-- 分割サイズ（スタッド単位）
-- 大きいほど高速だがメモリを消費、小さいほど低速だがメモリ効率が良い
local chunkSize = 256 -- ★256スタッドごとに分割（推奨: 128〜512）

-- 元の位置のTerrainを削除するか
local deleteOriginal = true

-- チャンク処理ごとの待機時間（秒）
local waitTime = 0.1 -- ★サーバー負荷軽減のための待機時間

-- ========================================
-- ★★★ 処理開始（ここから下は変更不要） ★★★
-- ========================================

print("========================================")
print("[ElevateTerrain] 大規模Terrain移動処理を開始します")
print("========================================")
print("[ElevateTerrain] 全体範囲: " .. tostring(fullMinCorner) .. " 〜 " .. tostring(fullMaxCorner))
print("[ElevateTerrain] 移動高度: " .. elevationHeight .. " スタッド")
print("[ElevateTerrain] 分割サイズ: " .. chunkSize .. " スタッド")
print("[ElevateTerrain] 解像度: " .. resolution)
print("========================================")

local startTime = tick()

local xStart = fullMinCorner.X
local zStart = fullMinCorner.Z
local xEnd = fullMaxCorner.X
local zEnd = fullMaxCorner.Z

-- 総チャンク数を計算
local xChunks = math.ceil((xEnd - xStart) / chunkSize)
local zChunks = math.ceil((zEnd - zStart) / chunkSize)
local totalChunks = xChunks * zChunks

print("[ElevateTerrain] 総チャンク数: " .. totalChunks)
print("[ElevateTerrain] 推定処理時間: " .. string.format("%.1f", totalChunks * waitTime) .. " 秒以上")
print("========================================")

local currentChunk = 0
local successCount = 0
local errorCount = 0

-- チャンクごとに処理
for x = xStart, xEnd - 1, chunkSize do
	for z = zStart, zEnd - 1, chunkSize do
		currentChunk = currentChunk + 1

		local chunkMin = Vector3.new(x, fullMinCorner.Y, z)
		local chunkMax = Vector3.new(math.min(x + chunkSize, xEnd), fullMaxCorner.Y, math.min(z + chunkSize, zEnd))

		local progress = (currentChunk / totalChunks) * 100
		print(
			string.format(
				"[ElevateTerrain] チャンク %d/%d (%.1f%%) を処理中... 範囲: (%.0f, %.0f) 〜 (%.0f, %.0f)",
				currentChunk,
				totalChunks,
				progress,
				chunkMin.X,
				chunkMin.Z,
				chunkMax.X,
				chunkMax.Z
			)
		)

		-- チャンクの処理
		local chunkSuccess = pcall(function()
			local region = Region3.new(chunkMin, chunkMax)
			region = region:ExpandToGrid(resolution)

			-- 読み取り
			local materials, sizes = terrain:ReadVoxels(region, resolution)

			-- 新しい位置
			local offset = Vector3.new(0, elevationHeight, 0)
			local newRegion = Region3.new(chunkMin + offset, chunkMax + offset)
			newRegion = newRegion:ExpandToGrid(resolution)

			-- 書き込み
			terrain:WriteVoxels(newRegion, resolution, materials, sizes)

			-- 元の位置を削除
			if deleteOriginal then
				terrain:FillRegion(region, resolution, Enum.Material.Air)
			end
		end)

		if chunkSuccess then
			successCount = successCount + 1
		else
			errorCount = errorCount + 1
			warn(string.format("[ElevateTerrain] ⚠️ チャンク %d の処理に失敗しました", currentChunk))
		end

		-- サーバー負荷軽減のため待機
		task.wait(waitTime)
	end
end

local endTime = tick()
local elapsedTime = endTime - startTime

print("========================================")
print("[ElevateTerrain] ✅ 処理完了！")
print("[ElevateTerrain] 成功: " .. successCount .. " チャンク")
print("[ElevateTerrain] 失敗: " .. errorCount .. " チャンク")
print("[ElevateTerrain] 処理時間: " .. string.format("%.2f", elapsedTime) .. " 秒")
print("========================================")
print("[ElevateTerrain] ★このスクリプトを削除またはDisabledにしてください★")
print("========================================")
