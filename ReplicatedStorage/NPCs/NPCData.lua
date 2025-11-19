-- ReplicatedStorage/NPCs/NPCData.lua
return {
	-- NPCID は自動生成されます
	village_elder = {
		name = "村長エルダー",
		description = "この町の長。困った時は相談してみよう",
		dialogueTree = "village_elder_main",
		quests = { "quest_slime_hunt_001" },
	},

	amie = {
		name = "Amie",
		description = "町の住人",
		dialogueTree = "amie_main",
		quests = {},
	},

	cara = {
		name = "Cara",
		description = "町の住人",
		dialogueTree = "cara_main",
		quests = {},
	},

	dustin = {
		name = "Dustin",
		description = "町の住人",
		dialogueTree = "dustin_main",
		quests = {},
	},

	-- ... 他のNPCも同様
}
