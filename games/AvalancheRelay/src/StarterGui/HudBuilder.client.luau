--!strict
-- HudBuilder: builds the Avalanche Relay HUD layout (no logic). HudController in
-- StarterPlayerScripts finds "AvalancheHUD" in PlayerGui and drives it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
if playerGui:FindFirstChild("AvalancheHUD") then
	return -- already built (this script re-runs on respawn)
end

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config") :: ModuleScript) :: any

local NIGHT = Color3.fromRGB(16, 24, 38)
local ICE = Color3.fromRGB(111, 168, 220)
local GOLD = Color3.fromRGB(255, 209, 102)
local WHITE = Color3.fromRGB(245, 249, 255)
local GREY = Color3.fromRGB(92, 102, 118)

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className :: any)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: UDim?): UICorner
	return make("UICorner", { CornerRadius = radius or UDim.new(0, 12) })
end

local function border(color: Color3, thickness: number, transparency: number?): UIStroke
	return make("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = WHITE,
		TextStrokeColor3 = NIGHT,
		TextStrokeTransparency = 0.5,
		TextSize = 20,
	}
	for k, v in props do
		defaults[k] = v
	end
	return make("TextLabel", defaults)
end

local gui = make("ScreenGui", {
	Name = "AvalancheHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
})
make("UIScale", { Name = "Scale", Parent = gui })

-- Race HUD -------------------------------------------------------------------------
local raceHud = make("Frame", {
	Name = "RaceHud",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})

-- Top: progress dots
local totalDots = Config.SEGMENTS_PER_RUN + 1
local progress = make("Frame", {
	Name = "Progress",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(totalDots * 36 + 28, 44),
	BackgroundColor3 = NIGHT,
	BackgroundTransparency = 0.25,
	Parent = raceHud,
}, {
	corner(UDim.new(1, 0)),
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
for i = 1, totalDots do
	make("Frame", {
		Name = "Dot" .. i,
		LayoutOrder = i,
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = ICE,
		BackgroundTransparency = 0.6,
		Parent = progress,
	}, {
		corner(UDim.new(1, 0)),
		border(WHITE, 2, 0.2),
		make("UIScale", { Name = "Pulse" }),
	})
end

label({
	Name = "CarrierLabel",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.fromOffset(420, 28),
	Text = "",
	TextColor3 = GOLD,
	TextSize = 22,
	Parent = raceHud,
})

-- Top right: timer
make("Frame", {
	Name = "Timer",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(160, 50),
	BackgroundColor3 = NIGHT,
	BackgroundTransparency = 0.25,
	Parent = raceHud,
}, {
	corner(),
	label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Text = "0:00.00",
		Font = Enum.Font.RobotoMono,
		TextSize = 28,
		TextStrokeTransparency = 1,
	}),
})

-- Left: avalanche gap meter
make("Frame", {
	Name = "GapMeter",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(70, 270),
	BackgroundColor3 = NIGHT,
	BackgroundTransparency = 0.25,
	Parent = raceHud,
}, {
	corner(),
	label({ Name = "Title", Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 20), Text = "GAP", TextSize = 18, TextColor3 = ICE }),
	make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 32),
		Size = UDim2.new(0, 18, 1, -82),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.82,
	}, {
		corner(UDim.new(1, 0)),
		make("Frame", {
			Name = "Fill",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.5),
			BackgroundColor3 = ICE,
		}, { corner(UDim.new(1, 0)) }),
	}),
	label({ Name = "Value", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 24), Text = "--", TextSize = 22 }),
	label({ Name = "Unit", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 16), Text = "studs", TextSize = 14, TextColor3 = ICE }),
})

-- Bottom right: TOSS button with radial cooldown
local function cooldownHalf(name: string, position: UDim2, discPosition: UDim2, transparency: NumberSequence): Frame
	return make("Frame", {
		Name = name,
		Position = position,
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, {
		make("Frame", {
			Name = "Disc",
			Position = discPosition,
			Size = UDim2.fromScale(2, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.45,
		}, {
			corner(UDim.new(1, 0)),
			make("UIGradient", { Name = "Gradient", Transparency = transparency, Rotation = 0 }),
		}),
	})
end

local rightSeq = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})
local leftSeq = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(0.501, 0),
	NumberSequenceKeypoint.new(1, 0),
})

make("TextButton", {
	Name = "TossButton",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -24),
	Size = UDim2.fromOffset(116, 116), -- UIScale never goes below 0.75, so it stays >= 87px
	BackgroundColor3 = GOLD,
	AutoButtonColor = false,
	Text = "",
	Parent = raceHud,
}, {
	corner(UDim.new(1, 0)),
	border(NIGHT, 4, 0.1),
	make("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREY, ZIndex = 2, Visible = false }, {
		corner(UDim.new(1, 0)),
	}),
	make("Frame", { Name = "Cooldown", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Visible = false }, {
		cooldownHalf("Right", UDim2.fromScale(0.5, 0), UDim2.fromScale(-1, 0), rightSeq),
		cooldownHalf("Left", UDim2.fromScale(0, 0), UDim2.fromScale(0, 0), leftSeq),
	}),
	label({ Name = "Label", Size = UDim2.new(1, 0, 1, -16), Text = "TOSS", TextSize = 32, TextColor3 = NIGHT, TextStrokeTransparency = 1, ZIndex = 4 }),
	label({ Name = "Hint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(60, 18), Text = "[E]", TextSize = 16, TextColor3 = NIGHT, TextStrokeTransparency = 1, ZIndex = 4 }),
})

-- Center: countdown numbers
label({
	Name = "Countdown",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.38),
	Size = UDim2.fromOffset(360, 200),
	Text = "",
	TextSize = 150,
	TextColor3 = GOLD,
	TextStrokeTransparency = 0,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
})
make("UIScale", { Name = "Pop", Parent = gui:FindFirstChild("Countdown") })

-- Top: finish banner (slides down)
make("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -240),
	Size = UDim2.fromOffset(540, 214),
	BackgroundColor3 = NIGHT,
	BackgroundTransparency = 0.08,
	ZIndex = 8,
	Parent = gui,
}, {
	corner(UDim.new(0, 18)),
	border(GOLD, 3),
	label({ Name = "Title", Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 48), Text = "", TextSize = 42, TextColor3 = GOLD, ZIndex = 9 }),
	label({ Name = "Detail", Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 30), Text = "", TextSize = 26, ZIndex = 9 }),
	label({ Name = "Extra", Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 0, 26), Text = "", TextSize = 20, TextColor3 = ICE, ZIndex = 9 }),
	make("TextButton", {
		Name = "AgainButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(240, 48),
		BackgroundColor3 = GOLD,
		Font = Enum.Font.FredokaOne,
		Text = "RUN AGAIN",
		TextColor3 = NIGHT,
		TextSize = 26,
		ZIndex = 9,
	}, { corner(UDim.new(1, 0)), border(NIGHT, 3, 0.2) }),
})

-- Bottom center: "X is starting a run! [JOIN]" invite
make("Frame", {
	Name = "Invite",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(500, 64),
	BackgroundColor3 = NIGHT,
	BackgroundTransparency = 0.1,
	Visible = false,
	ZIndex = 7,
	Parent = gui,
}, {
	corner(UDim.new(1, 0)),
	border(GOLD, 3),
	label({ Name = "Label", Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -170, 1, 0), Text = "", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 8 }),
	make("TextButton", {
		Name = "JoinButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(130, 46),
		BackgroundColor3 = GOLD,
		Font = Enum.Font.FredokaOne,
		Text = "JOIN!",
		TextColor3 = NIGHT,
		TextSize = 24,
		ZIndex = 8,
	}, { corner(UDim.new(1, 0)) }),
})

-- Bottom center: toast
label({
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -160),
	Size = UDim2.fromOffset(520, 46),
	BackgroundColor3 = NIGHT,
	BackgroundTransparency = 0.2,
	Text = "",
	TextSize = 22,
	Visible = false,
	ZIndex = 7,
	Parent = gui,
})
make("UICorner", { CornerRadius = UDim.new(0, 12), Parent = gui:FindFirstChild("Toast") })

-- Top left: daily panel (lobby only)
local function panelButton(name: string, text: string, order: number): TextButton
	return make("TextButton", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = ICE,
		AutoButtonColor = true,
		Font = Enum.Font.FredokaOne,
		Text = text,
		TextColor3 = NIGHT,
		TextSize = 18,
	}, { corner(UDim.new(0, 10)) })
end

make("Frame", {
	Name = "DailyPanel",
	Position = UDim2.fromOffset(12, 64),
	Size = UDim2.fromOffset(260, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = NIGHT,
	BackgroundTransparency = 0.2,
	Parent = gui,
}, {
	corner(UDim.new(0, 14)),
	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}),
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	label({ Name = "Title", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26), Text = "DAILY RUN", TextSize = 24, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }),
	make("TextButton", {
		Name = "FindButton",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = GOLD,
		Font = Enum.Font.FredokaOne,
		Text = "▶  FIND SQUAD",
		TextColor3 = NIGHT,
		TextSize = 22,
	}, { corner(UDim.new(0, 12)), border(NIGHT, 2, 0.4) }),
	label({
		Name = "Segments",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = "Loading today's mountain...",
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextWrapped = true,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}),
	label({ Name = "Best", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 22), Text = "Best today: --", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left }),
	label({ Name = "Badges", LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 22), Text = "Frost Badges: 0", TextSize = 18, TextColor3 = ICE, TextXAlignment = Enum.TextXAlignment.Left }),
	label({ Name = "Streak", LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "🔥 Streak: 0 days", TextSize = 17, TextColor3 = Color3.fromRGB(255, 160, 90), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true }),
	panelButton("RewardsButton", "❄  Rewards", 7),
	panelButton("FlameButton", "Flame: Gold", 8),
	panelButton("KitButton", "Get Trailblazer Kit", 9),
})


-- Top right: compact leaderboard (replaces Roblox's big player list; lobby only)
make("Frame", {
	Name = "Leaderboard",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(250, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = NIGHT,
	BackgroundTransparency = 0.25,
	Parent = gui,
}, {
	corner(UDim.new(0, 12)),
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}),
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("Frame", { Name = "Header", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 }, {
		label({ Name = "PlayerName", Size = UDim2.new(0.52, 0, 1, 0), Text = "PLAYER", TextSize = 13, TextColor3 = ICE, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left }),
		label({ Name = "Today", Position = UDim2.fromScale(0.52, 0), Size = UDim2.new(0.16, 0, 1, 0), Text = "TODAY", TextSize = 12, TextColor3 = ICE, TextStrokeTransparency = 1 }),
		label({ Name = "Badges", Position = UDim2.fromScale(0.68, 0), Size = UDim2.new(0.16, 0, 1, 0), Text = "❄", TextSize = 13, TextColor3 = ICE, TextStrokeTransparency = 1 }),
		label({ Name = "Streak", Position = UDim2.fromScale(0.84, 0), Size = UDim2.new(0.16, 0, 1, 0), Text = "🔥", TextSize = 13, TextColor3 = ICE, TextStrokeTransparency = 1 }),
	}),
})

-- Center: Frost Badge rewards panel (rows are filled in by HudController)
make("Frame", {
	Name = "Rewards",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(460, 470),
	BackgroundColor3 = NIGHT,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 20,
	Parent = gui,
}, {
	corner(UDim.new(0, 18)),
	border(ICE, 3),
	label({ Name = "Title", Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 36), Text = "❄ FROST BADGE REWARDS", TextSize = 30, TextColor3 = GOLD, ZIndex = 21 }),
	label({ Name = "Progress", Position = UDim2.fromOffset(20, 54), Size = UDim2.new(1, -40, 0, 22), Text = "", Font = Enum.Font.GothamMedium, TextSize = 16, TextStrokeTransparency = 1, ZIndex = 21 }),
	make("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(20, 82),
		Size = UDim2.new(1, -40, 0, 12),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.82,
		ZIndex = 21,
	}, {
		corner(UDim.new(1, 0)),
		make("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = ICE, ZIndex = 22 }, { corner(UDim.new(1, 0)) }),
	}),
	make("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(16, 106),
		Size = UDim2.new(1, -32, 1, -170),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	}),
	make("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(160, 40),
		BackgroundColor3 = ICE,
		Font = Enum.Font.FredokaOne,
		Text = "CLOSE",
		TextColor3 = NIGHT,
		TextSize = 20,
		ZIndex = 21,
	}, { corner(UDim.new(1, 0)) }),
})

gui.Parent = playerGui
