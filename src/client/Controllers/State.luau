--!strict
-- Client-side mirror of the server state, plus the currently selected hotbar
-- tool. Other controllers read from here and listen to the signals.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

local State = {}

State.SHOVEL = "__shovel"

State.current = nil :: Types.ClientState?
State.selected = nil :: string?

State.Changed = Signal.new() :: Signal.Signal<Types.ClientState>
State.SelectionChanged = Signal.new() :: Signal.Signal<string?>

function State.select(tool: string?)
	if State.selected == tool then
		tool = nil -- clicking the selected slot again deselects it
	end
	State.selected = tool
	State.SelectionChanged:Fire(tool)
end

function State.Start()
	Remotes.StateUpdated.OnClientEvent:Connect(function(state: Types.ClientState)
		State.current = state
		-- Drop the selection if the player just used their last seed of it.
		local selected = State.selected
		if selected and selected ~= State.SHOVEL and (state.seeds[selected] or 0) < 1 then
			State.select(nil)
		end
		State.Changed:Fire(state)
	end)
	Remotes.RequestState:FireServer()
end

return State
