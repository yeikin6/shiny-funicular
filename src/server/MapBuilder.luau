--!strict
-- Mapa gris generado por código: piso, cráter, parcelas con pedestales y tablero del leaderboard.
-- Así el MVP no depende de nada armado a mano en Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type PromptRole = "Owner" | "Steal" | "Buy"

export type PedestalParts = {
	index: number,
	base: BasePart,
	starPoint: CFrame, -- donde se apoya la estrella visual
	ownerPrompt: ProximityPrompt,
	stealPrompt: ProximityPrompt,
	buyPrompt: ProximityPrompt,
	label: TextLabel,
}

export type PlotParts = {
	index: number,
	model: Model,
	spawnCFrame: CFrame,
	dome: BasePart,
	sign: TextLabel,
	pedestals: { PedestalParts },
}

local MapBuilder = {}

local function makePart(props: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	parent: Instance,
}): BasePart
	local part = Instance.new("Part")
	part.Name = props.name
	part.Anchored = true
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Shape = props.shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.parent
	return part
end

local function makePrompt(parent: Instance, role: PromptRole, actionText: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = role .. "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = ""
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- el cliente decide qué ve cada jugador según Role y Active
	prompt:SetAttribute("Role", role)
	prompt:SetAttribute("Active", false)
	prompt.Parent = parent
	return prompt
end

local function makeBillboard(parent: BasePart, offset: Vector3, size: UDim2): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	label.Parent = gui
	return label
end

function MapBuilder.buildWorld(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = workspace

	makePart({
		name = "Ground",
		size = Vector3.new(700, 2, 700),
		cframe = CFrame.new(0, -1, 0),
		color = Color3.fromRGB(40, 44, 58),
		material = Enum.Material.Slate,
		parent = folder,
	})

	local craterRadius = Config.World.craterRadius
	local crater = makePart({
		name = "Crater",
		size = Vector3.new(0.2, craterRadius * 2, craterRadius * 2),
		cframe = CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(24, 26, 40),
		material = Enum.Material.Basalt,
		shape = Enum.PartType.Cylinder,
		parent = folder,
	})
	crater.CanCollide = false

	return folder
end

function MapBuilder.buildPlot(index: number, parent: Instance): PlotParts
	local angle = (index - 1) / Config.World.plotCount * math.pi * 2
	local center = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.World.plotRadius
	-- La parcela mira al cráter.
	local origin = CFrame.lookAt(center, Vector3.zero)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local floor = makePart({
		name = "Floor",
		size = Vector3.new(40, 1, 40),
		cframe = origin * CFrame.new(0, 0.5, 0),
		color = Color3.fromRGB(70, 76, 98),
		parent = model,
	})
	model.PrimaryPart = floor

	local signPost = makePart({
		name = "Sign",
		size = Vector3.new(1, 1, 1),
		cframe = origin * CFrame.new(0, 14, 0),
		color = Color3.new(0, 0, 0),
		parent = model,
	})
	signPost.Transparency = 1
	signPost.CanCollide = false
	local sign = makeBillboard(signPost, Vector3.zero, UDim2.fromOffset(260, 50))
	sign.Text = "Libre"

	local dome = makePart({
		name = "Dome",
		size = Vector3.new(48, 48, 48),
		cframe = origin * CFrame.new(0, 1, 0),
		color = Color3.fromRGB(120, 200, 255),
		material = Enum.Material.ForceField,
		shape = Enum.PartType.Ball,
		parent = model,
	})
	dome.CanCollide = false
	dome.CanQuery = false
	dome.CanTouch = false
	dome.Transparency = 1

	local pedestals: { PedestalParts } = {}
	for i = 1, Config.Slots.max do
		local row = (i - 1) // 4
		local col = (i - 1) % 4
		-- Dos filas de 4 al fondo de la parcela, lejos del cráter.
		local local_ = CFrame.new(-12 + col * 8, 1.5, 6 + row * 8)
		local base = makePart({
			name = "Pedestal" .. i,
			size = Vector3.new(4, 2, 4),
			cframe = origin * local_,
			color = Color3.fromRGB(110, 116, 140),
			parent = model,
		})
		base:SetAttribute("SlotIndex", i)

		table.insert(pedestals, {
			index = i,
			base = base,
			starPoint = base.CFrame * CFrame.new(0, 3, 0),
			ownerPrompt = makePrompt(base, "Owner", "Colocar", 0),
			stealPrompt = makePrompt(base, "Steal", "Robar", Config.Steal.holdDuration),
			buyPrompt = makePrompt(base, "Buy", "Desbloquear", 0),
			label = makeBillboard(base, Vector3.new(0, 6, 0), UDim2.fromOffset(160, 50)),
		})
	end

	model.Parent = parent

	return {
		index = index,
		model = model,
		-- Spawn al frente de la parcela, mirando al cráter.
		spawnCFrame = origin * CFrame.new(0, 4, -14),
		dome = dome,
		sign = sign,
		pedestals = pedestals,
	}
end

function MapBuilder.buildBoard(parent: Instance): TextLabel
	-- Entre la parcela 1 y la 2, al borde del cráter.
	local angle = 0.5 / Config.World.plotCount * math.pi * 2
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (Config.World.craterRadius + 20)
	local board = makePart({
		name = "LeaderboardBoard",
		size = Vector3.new(22, 16, 1),
		cframe = CFrame.lookAt(position + Vector3.new(0, 9, 0), Vector3.new(0, 9, 0)),
		color = Color3.fromRGB(18, 20, 30),
		parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 30
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 230, 150)
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = "Top estelar\n\nCargando..."
	label.Parent = gui

	return label
end

return MapBuilder
