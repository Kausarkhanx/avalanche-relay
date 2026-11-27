--!strict
-- Creates (server) or fetches (client) the Remotes folder and exposes typed getters.
--
-- RequestPass      RemoteEvent    client -> server  (targetUserId: number)
-- RaceStateUpdate  RemoteEvent    server -> client  (state, segment, time, avalancheGap, carrierId, info)
-- Notify           RemoteEvent    server -> client  (kind: string, text: string, worldPosition: Vector3?)
-- GetDailyInfo     RemoteFunction client -> server  -> { seed, segments, personalBest, ... }
-- SetFlameColor    RemoteEvent    client -> server  (flameName: string)  Trailblazer Kit cosmetic
-- QuickJoin        RemoteEvent    client -> server  ()  Find Squad in the lobby, or Run Again after a run

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local IS_SERVER = RunService:IsServer()

local Remotes = {}

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if IS_SERVER then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function getRemote(name: string, className: string): Instance
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	if IS_SERVER then
		local remote = Instance.new(className :: any)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

function Remotes.RequestPass(): RemoteEvent
	return getRemote("RequestPass", "RemoteEvent") :: RemoteEvent
end

function Remotes.RaceStateUpdate(): RemoteEvent
	return getRemote("RaceStateUpdate", "RemoteEvent") :: RemoteEvent
end

function Remotes.Notify(): RemoteEvent
	return getRemote("Notify", "RemoteEvent") :: RemoteEvent
end

function Remotes.GetDailyInfo(): RemoteFunction
	return getRemote("GetDailyInfo", "RemoteFunction") :: RemoteFunction
end

function Remotes.SetFlameColor(): RemoteEvent
	return getRemote("SetFlameColor", "RemoteEvent") :: RemoteEvent
end

function Remotes.QuickJoin(): RemoteEvent
	return getRemote("QuickJoin", "RemoteEvent") :: RemoteEvent
end

-- client -> server (): "Skip tips" on the first-run tutorial
function Remotes.TutorialDone(): RemoteEvent
	return getRemote("TutorialDone", "RemoteEvent") :: RemoteEvent
end

-- client -> server (rewardId: string, on: boolean): wear or take off an earned wearable
function Remotes.SetWearable(): RemoteEvent
	return getRemote("SetWearable", "RemoteEvent") :: RemoteEvent
end

-- Server: create every remote up front so clients never wait on a missing one.
function Remotes.init()
	Remotes.QuickJoin()
	Remotes.SetWearable()
	Remotes.TutorialDone()
	Remotes.RequestPass()
	Remotes.RaceStateUpdate()
	Remotes.Notify()
	Remotes.GetDailyInfo()
	Remotes.SetFlameColor()
end

return Remotes
