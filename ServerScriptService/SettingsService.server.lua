-- ServerScriptService/SettingsService.server.lua（新規）
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreManager = require(game.ServerScriptService.DataStoreManager)

Players.PlayerAdded:Connect(function(player)
	local data = DataStoreManager.LoadData(player) or {}
	local s = data.Settings or {}

	player:SetAttribute("UILang", s.UILang or "ja")
	player:SetAttribute("VolBGM", tonumber(s.VolBGM) or 1.0)
	player:SetAttribute("VolSE", tonumber(s.VolSE) or 1.0)
end)

Players.PlayerRemoving:Connect(function(player)
	-- 退室時も保存（保険）
	local data = DataStoreManager.LoadData(player) or {}
	data.Settings = {
		UILang = player:GetAttribute("UILang") or "ja",
		VolBGM = tonumber(player:GetAttribute("VolBGM")) or 1.0,
		VolSE = tonumber(player:GetAttribute("VolSE")) or 1.0,
	}
	DataStoreManager.SaveData(player, data)
end)
