--!strict
-- GameServer: creates remotes, then starts each service in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Services = script.Parent:WaitForChild("Services")

local START_ORDER = {
	"DataService",
	"RewardService",
	"MonetizationService",
	"CourseService",
	"LanternService",
	"AvalancheService",
	"RaceService",
	"LobbyService",
}

Remotes.init()

local started = {}
for _, name in START_ORDER do
	local module = Services:FindFirstChild(name)
	if not (module and module:IsA("ModuleScript")) then
		warn("[GameServer] Missing service " .. name)
		continue
	end
	local service = require(module) :: any
	local ok, err = pcall(service.init)
	if ok then
		table.insert(started, name)
	else
		warn(string.format("[GameServer] %s failed to start: %s", name, tostring(err)))
	end
end

print("[GameServer] Avalanche Relay ready: " .. table.concat(started, ", "))
