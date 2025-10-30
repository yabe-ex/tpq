local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = {}

local SOUND_DEFS = {
    { name = "TypingCorrect", id = "rbxassetid://159534615",        volume = 0.4 },
    { name = "TypingError",   id = "rbxassetid://113721818600044",   volume = 0.5 },
    { name = "EnemyHit",      id = "rbxassetid://155288625",         volume = 0.6 }, -- 敵ターンSE
}

function SoundRegistry.init()
    local folder = ReplicatedStorage:FindFirstChild("Sounds")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Sounds"
        folder.Parent = ReplicatedStorage
    end

    for _, def in ipairs(SOUND_DEFS) do
        local s = folder:FindFirstChild(def.name)
        if not s then
            s = Instance.new("Sound")
            s.Name = def.name
            s.SoundId = def.id
            s.Volume = def.volume or 0.5
            s.RollOffMode = Enum.RollOffMode.InverseTapered
            s.Parent = folder
        end
    end
end

return SoundRegistry
