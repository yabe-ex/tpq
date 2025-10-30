-- ReplicatedStorage/Typing/WordInfo.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TypingWords = require(ReplicatedStorage.Typing.TypingWords)

local sizeCache = {}
local M = {}

function M.levelSize(levelName)
  if not sizeCache[levelName] then
    -- 初回だけ数えてキャッシュ
    sizeCache[levelName] = #TypingWords[levelName]
  end
  return sizeCache[levelName]
end

return M
