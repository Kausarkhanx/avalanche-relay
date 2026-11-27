--!strict
-- ClientState: the latest race snapshot from the server, plus local signals the other
-- controllers listen to. The client only displays this; it never reports it back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes") :: ModuleScript) :: any

local LocalPlayer = Players.LocalPlayer

local changed = Instance.new("BindableEvent")
local notified = Instance.new("BindableEvent")

local ClientState = {
	inRace = false,
	state = nil :: string?,
	segment = 0,
	time = 0,
	receivedAt = 0,
	gap = math.huge,
	carrierId = 0,
	info = nil :: any,
	Changed = changed.Event,
	Notified = notified.Event, -- (kind: string, text: string, worldPosition: Vector3?)
}

function ClientState.isCarrier(): boolean
	return ClientState.inRace and ClientState.carrierId == LocalPlayer.UserId
end

-- Lets client controllers raise local-only messages (e.g. "No squadmate in range").
function ClientState.localNotify(kind: string, text: string, position: Vector3?)
	notified:Fire(kind, text, position)
end

function ClientState.init()
	Remotes.RaceStateUpdate().OnClientEvent:Connect(
		function(state: string, segment: number, time: number, gap: number, carrierId: number, info: any)
			ClientState.inRace = true
			ClientState.state = state
			ClientState.segment = segment
			ClientState.time = time
			ClientState.receivedAt = os.clock()
			ClientState.gap = gap
			ClientState.carrierId = carrierId
			ClientState.info = info
			changed:Fire()
		end
	)
	Remotes.Notify().OnClientEvent:Connect(function(kind: string, text: string, position: Vector3?)
		if kind == "lobby" then
			ClientState.inRace = false
			ClientState.state = nil
			ClientState.carrierId = 0
			ClientState.gap = math.huge
			changed:Fire()
		end
		notified:Fire(kind, text, position)
	end)
end

return ClientState
