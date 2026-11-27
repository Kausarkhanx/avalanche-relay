--!strict
-- FloatingText: world-space pop-ups like "Nice Toss!" and "+Checkpoint".

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local ClientState = require(script.Parent.ClientState)

local FloatingText = {}

local COLORS: { [string]: Color3 } = {
	toss = Color3.fromRGB(235, 245, 255),
	bigToss = Color3.fromRGB(255, 209, 102),
	catch = Color3.fromRGB(255, 209, 102),
	checkpoint = Color3.fromRGB(111, 168, 220),
	gate = Color3.fromRGB(255, 209, 102),
	puffOther = Color3.fromRGB(220, 230, 245),
}

function FloatingText.show(text: string, position: Vector3, color: Color3?)
	local anchor = Instance.new("Part")
	anchor.Name = "FloatingTextAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(16, 24, 38)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label

	anchor.Parent = Workspace
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(anchor, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(position + Vector3.new(0, 5, 0)),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.8), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 1.5)
end

function FloatingText.init()
	ClientState.Notified:Connect(function(kind: string, text: string, position: Vector3?)
		if position and COLORS[kind] then
			FloatingText.show(text, position, COLORS[kind])
		end
	end)
end

return FloatingText
