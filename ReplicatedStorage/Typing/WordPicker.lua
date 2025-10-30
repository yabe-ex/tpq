-- ReplicatedStorage/Typing/WordPicker.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TypingWords = require(ReplicatedStorage.Typing.TypingWords)

local M = {}

local function weightedPick(levels)
	local sum = 0
	for _, e in ipairs(levels) do sum += (e.weight or 0) end
	local r = math.random() * sum
	for _, e in ipairs(levels) do
		r -= (e.weight or 0)
		if r <= 0 then return e.level end
	end
	return levels[#levels].level
end

function M.pickWord(levels, opts)
	-- opts: {category1="n"} など任意
	local levelName = weightedPick(levels)
	local pool = TypingWords[levelName]
	if opts and opts.category1 then
		local f = {}
		for _, it in ipairs(pool) do
			if it.category1 == opts.category1 then table.insert(f, it) end
		end
		if #f > 0 then pool = f end
	end
	return pool[math.random(1, #pool)], levelName
end

return M
