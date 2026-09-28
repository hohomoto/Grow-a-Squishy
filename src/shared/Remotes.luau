--!strict
-- Single source of truth for network remotes. The server creates them; the
-- client waits for them. Always go through this module instead of looking the
-- instances up by string elsewhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	-- Server -> client
	"StateUpdated", -- (state: ClientState)
	"Notify", -- (message: string)
	-- Client -> server
	"RequestState", -- ()
	"PlantSeed", -- (tileIndex: number, squishyId: string)
	"RemovePlant", -- (tileIndex: number)
	"BuySeed", -- (squishyId: string)
}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENT_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	StateUpdated = get("StateUpdated"),
	Notify = get("Notify"),
	RequestState = get("RequestState"),
	PlantSeed = get("PlantSeed"),
	RemovePlant = get("RemovePlant"),
	BuySeed = get("BuySeed"),
}
