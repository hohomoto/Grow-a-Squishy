--!strict
-- Plays sound effects from Config/Sounds, locally for this player. The server
-- asks for gameplay sounds through the Sfx remote; UI and weather code call
-- Sfx.play directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local Sfx = {}

local random = Random.new()

-- Plays a sound by name. With `parent` (a part), the sound is 3D and comes
-- from that spot; otherwise it plays as flat 2D audio.
function Sfx.play(name: string, parent: Instance?)
	local def = Sounds[name]
	if not def or def.id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = random:NextNumber(def.pitch[1], def.pitch[2])
	sound.Parent = parent or SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	-- Cleanup even if the sound never loads or ends.
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

return Sfx
