-- ServerScriptService/LoadTest (Script)
local startTime = os.clock()
local startMemory = gcinfo()

-- ゲーム開始を待つ
-- task.wait(5)

-- local endTime = os.clock()
-- local endMemory = gcinfo()

-- print("=== 負荷テスト結果 ===")
-- print(("地形生成時間: %.2f秒"):format(endTime - startTime))
-- print(("メモリ使用量: %.2f MB"):format((endMemory - startMemory) / 1024))
-- print(("総オブジェクト数: %d"):format(#workspace:GetDescendants()))

-- 継続モニタリング
task.spawn(function()
	while true do
		task.wait(5)
		local fps = 1 / game:GetService("RunService").Heartbeat:Wait()
		print(("FPS: %.1f | メモリ: %.1f MB"):format(fps, gcinfo() / 1024))
	end
end)