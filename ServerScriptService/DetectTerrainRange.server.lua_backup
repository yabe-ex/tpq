-- ServerScriptService/DetectTerrainRange
-- Terrainの範囲を自動検出するスクリプト
-- 
-- 使い方:
-- 1. このスクリプトをServerScriptServiceにコピー
-- 2. ゲームを実行（F5キー）
-- 3. Outputウィンドウで範囲を確認
-- 4. 確認した座標を ElevateTerrainOnce.lua にコピー
-- 5. このスクリプトを削除またはDisabledにする

local terrain = workspace.Terrain

print("========================================")
print("[DetectTerrain] Terrainの範囲を検出します")
print("========================================")

-- Terrainの最大範囲を取得
local region = terrain:MaxExtents()

if region then
	local center = region.CFrame.Position
	local size = region.Size
	
	local minCorner = center - size / 2
	local maxCorner = center + size / 2
	
	print("[DetectTerrain] ✓ Terrainが見つかりました")
	print("========================================")
	print("[DetectTerrain] 中心座標: " .. tostring(center))
	print("[DetectTerrain] サイズ: " .. tostring(size))
	print("========================================")
	print("[DetectTerrain] 最小座標（minCorner）:")
	print(string.format("  Vector3.new(%.1f, %.1f, %.1f)", minCorner.X, minCorner.Y, minCorner.Z))
	print("")
	print("[DetectTerrain] 最大座標（maxCorner）:")
	print(string.format("  Vector3.new(%.1f, %.1f, %.1f)", maxCorner.X, maxCorner.Y, maxCorner.Z))
	print("========================================")
	print("[DetectTerrain] ★上記の座標を ElevateTerrainOnce.lua にコピーしてください★")
	print("========================================")
	
	-- より詳細な情報
	print("")
	print("[DetectTerrain] 詳細情報:")
	print("  X範囲: " .. string.format("%.1f 〜 %.1f (幅: %.1f)", minCorner.X, maxCorner.X, size.X))
	print("  Y範囲: " .. string.format("%.1f 〜 %.1f (高さ: %.1f)", minCorner.Y, maxCorner.Y, size.Y))
	print("  Z範囲: " .. string.format("%.1f 〜 %.1f (奥行: %.1f)", minCorner.Z, maxCorner.Z, size.Z))
	
	-- 推奨される分割サイズ
	local maxDimension = math.max(size.X, size.Z)
	local recommendedChunkSize = 256
	
	if maxDimension > 2000 then
		recommendedChunkSize = 512
		print("")
		print("[DetectTerrain] ⚠️ 非常に大きなTerrainです")
		print("[DetectTerrain] ElevateTerrainLarge.lua の使用を推奨します")
		print("[DetectTerrain] 推奨分割サイズ: " .. recommendedChunkSize .. " スタッド")
	elseif maxDimension > 1000 then
		recommendedChunkSize = 256
		print("")
		print("[DetectTerrain] ⚠️ 大きなTerrainです")
		print("[DetectTerrain] ElevateTerrainLarge.lua の使用を推奨します")
		print("[DetectTerrain] 推奨分割サイズ: " .. recommendedChunkSize .. " スタッド")
	else
		print("")
		print("[DetectTerrain] ✓ 標準サイズのTerrainです")
		print("[DetectTerrain] ElevateTerrainOnce.lua で処理できます")
	end
	
else
	warn("[DetectTerrain] ❌ Terrainが見つかりませんでした")
	warn("[DetectTerrain] Terrainが存在するか確認してください")
end

print("========================================")
print("[DetectTerrain] 検出完了")
print("========================================")
