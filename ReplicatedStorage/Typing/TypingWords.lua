local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelsFolder = ReplicatedStorage:WaitForChild("Typing"):WaitForChild("Levels")

local cache = {}
local TypingWords = {}

local function load(levelName)
  if not cache[levelName] then
    local m = LevelsFolder:FindFirstChild(levelName)
    if m and m:IsA("ModuleScript") then
      cache[levelName] = require(m)
    else
      warn("[TypingWords] level not found: " .. tostring(levelName))
      cache[levelName] = {}
    end
  end
  return cache[levelName]
end

-- === TypingWords.lua の末尾に置く（ここから） ===
setmetatable(TypingWords, {
  __index = function(_, k)
    -- 通常ロード（キャッシュ使用）
    return load(k, false)
  end
})

-- 関数としての reload（ドット定義！）
function TypingWords.reload(levelName)
  return load(levelName, true)  -- 強制再読込（クローン require）
end

return TypingWords
