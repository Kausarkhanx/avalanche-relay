--!strict
-- AudioController: plays the SoundService groups built by the world script.
-- Music: a cute lobby loop and an upbeat race loop that crossfade, and the race loop
-- speeds up a little as the avalanche closes in. A heartbeat kicks in when it's very close.
-- Sounds still on the placeholder id (rbxassetid://0) are skipped silently.

local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ClientState = require(script.Parent.ClientState)

local AudioController = {}

local PLACEHOLDER = "rbxassetid://0"
local CROSSFADE = TweenInfo.new(1.2, Enum.EasingStyle.Sine)

local function findSound(group: string, name: string): Sound?
	local folder = SoundService:FindFirstChild(group)
	local sound = folder and folder:FindFirstChild(name)
	return if sound and sound:IsA("Sound") then sound else nil
end

local function playable(sound: Sound?): boolean
	return sound ~= nil and sound.SoundId ~= "" and sound.SoundId ~= PLACEHOLDER
end

function AudioController.play(group: string, name: string, pitch: number?)
	local sound = findSound(group, name)
	if not sound or not playable(sound) then
		return
	end
	local copy = sound:Clone()
	copy.Looped = false
	copy.PlaybackSpeed = pitch or sound.PlaybackSpeed
	copy.Parent = sound.Parent
	copy:Play()
	Debris:AddItem(copy, 6)
end

-- Big-toss slow-mo: the race music drops in pitch for a moment.
local slowmoUntil = 0
function AudioController.slowmo(seconds: number)
	slowmoUntil = os.clock() + seconds
end

function AudioController.click()
	AudioController.play("UI", "Click", 1.3)
end

-- Starts a loop at volume 0 and returns it with its authored volume.
local function prepareLoop(group: string, name: string): (Sound?, number)
	local sound = findSound(group, name)
	if not sound or not playable(sound) then
		return nil, 0
	end
	local base = sound.Volume
	sound.Looped = true
	sound.Volume = 0
	sound:Play()
	return sound, base
end

function AudioController.init()
	local lobbyMusic, lobbyBase = prepareLoop("Music", "LobbyMusic")
	local raceMusic, raceBase = prepareLoop("Music", "RaceMusic")
	local wind, windBase = prepareLoop("Ambience", "Wind")
	local rumble, rumbleBase = prepareLoop("Ambience", "Rumble")
	local heartbeat = findSound("SFX", "Heartbeat")

	if wind then
		wind.Volume = windBase
	end

	local currentMode = ""
	local function setMode(mode: string)
		if mode == currentMode then
			return
		end
		currentMode = mode
		if lobbyMusic then
			TweenService:Create(lobbyMusic, CROSSFADE, { Volume = if mode == "lobby" then lobbyBase else 0 }):Play()
		end
		if raceMusic then
			if mode == "race" then
				raceMusic.TimePosition = 0
				raceMusic.PlaybackSpeed = 1
			end
			TweenService:Create(raceMusic, CROSSFADE, { Volume = if mode == "race" then raceBase else 0 }):Play()
		end
	end
	setMode("lobby")

	local lastResult: any = nil
	ClientState.Changed:Connect(function()
		setMode(if ClientState.inRace then "race" else "lobby")
		local info = ClientState.info
		local result = info and info.result
		if ClientState.state == "Ended" and result and result ~= lastResult then
			lastResult = result
			if result.reason == "Caught" then
				AudioController.play("SFX", "Caught")
			end
		end
	end)

	ClientState.Notified:Connect(function(kind: string)
		if kind == "countdown" then
			AudioController.play("SFX", "Beep")
		elseif kind == "go" then
			AudioController.play("SFX", "Beep", 1.6)
		elseif kind == "toss" then
			AudioController.play("SFX", "Toss")
		elseif kind == "bigToss" then
			AudioController.play("SFX", "Toss", 0.7)
		elseif kind == "catch" then
			AudioController.play("SFX", "Catch")
		elseif kind == "checkpoint" then
			AudioController.play("SFX", "Checkpoint")
		elseif kind == "gate" then
			AudioController.play("SFX", "Bell")
			AudioController.play("SFX", "Checkpoint", 1.25)
		elseif kind == "unlock" or kind == "badge" or kind == "streak" then
			AudioController.play("SFX", "Bell", 1.2)
		elseif kind == "puff" then
			AudioController.play("SFX", "Catch", 0.7)
		end
	end)

	-- Tension: rumble swells, race music speeds up a touch, heartbeat inside 15 studs.
	RunService.RenderStepped:Connect(function()
		local running = ClientState.inRace and ClientState.state == "Running"
		local closeness = if running then math.clamp(1 - ClientState.gap / 60, 0, 1) else 0
		if rumble then
			rumble.Volume = rumbleBase * closeness
		end
		if raceMusic and currentMode == "race" then
			local target = if os.clock() < slowmoUntil then 0.78 else 1 + closeness * 0.1
			raceMusic.PlaybackSpeed += (target - raceMusic.PlaybackSpeed) * 0.25
		end
		if heartbeat and playable(heartbeat) then
			local want = running and ClientState.gap < 15
			if want and not heartbeat.IsPlaying then
				heartbeat.Looped = true
				heartbeat:Play()
			elseif not want and heartbeat.IsPlaying then
				heartbeat:Stop()
			end
		end
	end)
end

return AudioController
