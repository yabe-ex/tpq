-- ReplicatedStorage/Continents/Registry.lua
local RS = game:GetService("ReplicatedStorage")
local ContinentsFolder = RS:WaitForChild("Continents")

return {
	require(ContinentsFolder.TerrainBase_C),
	require(ContinentsFolder.ContinentTown), -- TerrainBase_C に移行するためコメントアウト
	-- require(ContinentsFolder.ContinentHokkaido),
	-- require(ContinentsFolder.ContinentShikoku),
	-- require(ContinentsFolder.ContinentKyushu),
	-- require(ContinentsFolder.Snowland),
	-- require(ContinentsFolder.BananaLand),
	-- require(ContinentsFolder.ContinentVendant),
	-- require(ContinentsFolder.ContinentVendant2),
	-- require(ContinentsFolder.ContinentVendant3),
	require(ContinentsFolder.Hokkaido_C),
	require(ContinentsFolder.Kyusyu_C),
}
