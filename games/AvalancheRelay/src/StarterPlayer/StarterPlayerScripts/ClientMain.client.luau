--!strict
-- ClientMain: boots the client controllers in order.

local Controllers = script.Parent:WaitForChild("Controllers")

local BOOT_ORDER = {
	"ClientState",
	"AudioController",
	"FloatingText",
	"AvalancheFX",
	"PassController",
	"HudController",
	"JuiceController",
	"TutorialController",
}

for _, name in BOOT_ORDER do
	local module = Controllers:WaitForChild(name, 10)
	if not (module and module:IsA("ModuleScript")) then
		warn("[ClientMain] Missing controller " .. name)
		continue
	end
	local controller = require(module) :: any
	local ok, err = pcall(controller.init)
	if not ok then
		warn(string.format("[ClientMain] %s failed to start: %s", name, tostring(err)))
	end
end
