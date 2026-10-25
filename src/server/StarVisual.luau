--!strict
-- Cómo se ve una estrella según su rareza, mutaciones y rasgo celestial.
-- Lo usan los pedestales, las estrellas en el piso y la que se carga.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Types = require(ReplicatedStorage.Shared.Types)

type StarInfo = Types.StarInfo
type MutationId = Types.MutationId
type CelestialId = Types.CelestialId

local StarVisual = {}

-- Identifica el aspecto: si cambia, hay que rearmar la parte.
function StarVisual.key(info: StarInfo): string
	return `{info.rarity}|{info.celestial or ""}|{table.concat(info.mutations, ",")}`
end

-- "Rayos · Volcán", con el rasgo celestial adelante si lo tiene.
function StarVisual.traitText(info: StarInfo): string
	local names: { string } = {}
	local celestial: CelestialId? = info.celestial
	if celestial then
		table.insert(names, Config.CelestialById[celestial].displayName)
	end
	for _, id: MutationId in info.mutations do
		table.insert(names, Config.MutationById[id].displayName)
	end
	return table.concat(names, " · ")
end

-- "Épica · Eclipse" arriba, "25 kg · 1.2K/s base" abajo.
function StarVisual.displayName(info: StarInfo): string
	local name = Config.RarityById[info.rarity].displayName
	local traits = StarVisual.traitText(info)
	return if traits ~= "" then `{name} · {traits}` else name
end

-- Cartel flotante con nombre, peso e ingreso base (ya multiplicado por mutaciones y rasgo).
function StarVisual.addInfoLabel(part: BasePart, info: StarInfo)
	local def = Config.RarityById[info.rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(200, 44)
	gui.StudsOffset = Vector3.new(0, def.size / 2 + 1.8, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Parent = part

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = part.Color
	title.TextStrokeTransparency = 0.3
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Text = StarVisual.displayName(info)
	title.Parent = gui

	local stats = Instance.new("TextLabel")
	stats.Position = UDim2.fromScale(0, 0.55)
	stats.Size = UDim2.new(1, 0, 0.45, 0)
	stats.BackgroundTransparency = 1
	stats.TextColor3 = Color3.new(1, 1, 1)
	stats.TextStrokeTransparency = 0.3
	stats.TextScaled = true
	stats.Font = Enum.Font.GothamMedium
	stats.Text = `{def.kg} kg · {Format.number(Economy.baseStarRate(info))}/s base`
	stats.Parent = gui
end

function StarVisual.make(info: StarInfo): Part
	local def = Config.RarityById[info.rarity]
	local celestial: CelestialId? = info.celestial
	local color = if celestial
		then Color3.fromHex(Config.CelestialById[celestial].colorHex)
		else Color3.fromHex(def.colorHex)

	local star = Instance.new("Part")
	star.Name = "Star"
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.one * def.size
	star.Material = Enum.Material.Neon
	star.Color = color
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CastShadow = false

	-- Cada mutación agranda el halo.
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10 + #info.mutations * 4
	light.Brightness = 1.5 + #info.mutations * 0.5
	light.Parent = star

	local attachment = Instance.new("Attachment")
	attachment.Parent = star

	for index, id: MutationId in info.mutations do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = id
		emitter.Color = ColorSequence.new(Color3.fromHex(Config.MutationById[id].colorHex))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(0.3, 0)
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Rate = 6
		emitter.Speed = NumberRange.new(1 + index, 2 + index)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = attachment
	end

	if celestial then
		local ring = Instance.new("ParticleEmitter")
		ring.Name = "Celestial"
		ring.Color = ColorSequence.new(color)
		ring.LightEmission = 1
		ring.Size = NumberSequence.new(def.size * 0.8, def.size * 1.6)
		ring.Transparency = NumberSequence.new(0.6, 1)
		ring.Lifetime = NumberRange.new(1)
		ring.Rate = 3
		ring.Speed = NumberRange.new(0)
		ring.LockedToPart = true
		ring.Parent = attachment
	end

	star:SetAttribute("VisualKey", StarVisual.key(info))
	return star
end

return StarVisual
