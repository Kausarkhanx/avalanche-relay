-- Pulls every script from disk into Studio (Edit mode). Serve the project folder first:
--   cd games/AvalancheRelay && python3 -m http.server 34999 --bind 127.0.0.1
-- Then run this from the command bar. Creates folders/scripts as needed and overwrites Source.

local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:34999/src/"

-- { disk path under src/, Studio path, class }
local MANIFEST = {
	{ "ReplicatedStorage/Shared/Types.luau", "ReplicatedStorage.Shared.Types", "ModuleScript" },
	{ "ReplicatedStorage/Shared/Config.luau", "ReplicatedStorage.Shared.Config", "ModuleScript" },
	{ "ReplicatedStorage/Shared/SegmentCatalog.luau", "ReplicatedStorage.Shared.SegmentCatalog", "ModuleScript" },
	{ "ReplicatedStorage/Shared/DailySeed.luau", "ReplicatedStorage.Shared.DailySeed", "ModuleScript" },
	{ "ReplicatedStorage/Shared/Remotes.luau", "ReplicatedStorage.Shared.Remotes", "ModuleScript" },
	{ "ReplicatedStorage/Shared/Rewards.luau", "ReplicatedStorage.Shared.Rewards", "ModuleScript" },
	{ "ServerScriptService/Services/RewardService.luau", "ServerScriptService.Services.RewardService", "ModuleScript" },
	{ "ServerScriptService/GameServer.server.luau", "ServerScriptService.GameServer", "Script" },
	{ "ServerScriptService/Services/DataService.luau", "ServerScriptService.Services.DataService", "ModuleScript" },
	{ "ServerScriptService/Services/MonetizationService.luau", "ServerScriptService.Services.MonetizationService", "ModuleScript" },
	{ "ServerScriptService/Services/CourseService.luau", "ServerScriptService.Services.CourseService", "ModuleScript" },
	{ "ServerScriptService/Services/LanternService.luau", "ServerScriptService.Services.LanternService", "ModuleScript" },
	{ "ServerScriptService/Services/AvalancheService.luau", "ServerScriptService.Services.AvalancheService", "ModuleScript" },
	{ "ServerScriptService/Services/RaceService.luau", "ServerScriptService.Services.RaceService", "ModuleScript" },
	{ "ServerScriptService/Services/LobbyService.luau", "ServerScriptService.Services.LobbyService", "ModuleScript" },
	{ "StarterPlayer/StarterPlayerScripts/ClientMain.client.luau", "StarterPlayer.StarterPlayerScripts.ClientMain", "LocalScript" },
	{ "StarterPlayer/StarterPlayerScripts/Controllers/ClientState.luau", "StarterPlayer.StarterPlayerScripts.Controllers.ClientState", "ModuleScript" },
	{ "StarterPlayer/StarterPlayerScripts/Controllers/AudioController.luau", "StarterPlayer.StarterPlayerScripts.Controllers.AudioController", "ModuleScript" },
	{ "StarterPlayer/StarterPlayerScripts/Controllers/FloatingText.luau", "StarterPlayer.StarterPlayerScripts.Controllers.FloatingText", "ModuleScript" },
	{ "StarterPlayer/StarterPlayerScripts/Controllers/AvalancheFX.luau", "StarterPlayer.StarterPlayerScripts.Controllers.AvalancheFX", "ModuleScript" },
	{ "StarterPlayer/StarterPlayerScripts/Controllers/PassController.luau", "StarterPlayer.StarterPlayerScripts.Controllers.PassController", "ModuleScript" },
	{ "StarterPlayer/StarterPlayerScripts/Controllers/HudController.luau", "StarterPlayer.StarterPlayerScripts.Controllers.HudController", "ModuleScript" },
	{ "StarterPlayer/StarterPlayerScripts/Controllers/JuiceController.luau", "StarterPlayer.StarterPlayerScripts.Controllers.JuiceController", "ModuleScript" },
	{ "StarterPlayer/StarterPlayerScripts/Controllers/TutorialController.luau", "StarterPlayer.StarterPlayerScripts.Controllers.TutorialController", "ModuleScript" },
	{ "StarterGui/HudBuilder.client.luau", "StarterGui.HudBuilder", "LocalScript" },
}

local function ensure(path: string, className: string): Instance
	local parts = string.split(path, ".")
	local node: Instance = game:GetService(parts[1])
	for i = 2, #parts do
		local child = node:FindFirstChild(parts[i])
		local isLeaf = i == #parts
		local want = if isLeaf then className else "Folder"
		-- Only a leaf of the wrong script class is replaced; existing containers are kept.
		if child and isLeaf and child.ClassName ~= want then
			child:Destroy()
			child = nil
		end
		if not child then
			child = Instance.new(want)
			child.Name = parts[i]
			child.Parent = node
		end
		node = child :: Instance
	end
	return node
end

local synced = {}
for _, entry in MANIFEST do
	local source = HttpService:GetAsync(BASE .. entry[1] .. "?t=" .. tostring(os.clock()))
	local script = ensure(entry[2], entry[3]);
	(script :: any).Source = source
	table.insert(synced, entry[2])
end
return string.format("Synced %d scripts", #synced)
