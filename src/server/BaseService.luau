--!strict
-- Parcelas, pedestales, ingreso por segundo, cobro, desbloqueo de pedestales y cúpula.
-- Los datos (PlayerData.slots) son la fuente de verdad; las instancias solo los reflejan.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)

type PlayerData = Types.PlayerData
type StarData = Types.StarData
type RarityId = Types.RarityId

export type Plot = {
	parts: MapBuilder.PlotParts,
	owner: Player?,
	domeUntil: number,
	domeReadyAt: number,
	visuals: { [number]: BasePart },
}

local BaseService = {}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function slotKey(index: number): string
	return tostring(index)
end

local function starAge(star: StarData): number
	return os.time() - star.placedAt
end

local function setActive(prompt: ProximityPrompt, active: boolean, actionText: string?)
	prompt:SetAttribute("Active", active)
	if actionText then
		prompt.ActionText = actionText
	end
end

local function makeStarVisual(rarity: RarityId, cframe: CFrame, parent: Instance): BasePart
	local def = Config.RarityById[rarity]
	local star = Instance.new("Part")
	star.Name = "Star"
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.one * def.size
	star.Material = Enum.Material.Neon
	star.Color = Color3.fromHex(def.colorHex)
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CFrame = cframe
	local light = Instance.new("PointLight")
	light.Color = star.Color
	light.Range = 10
	light.Parent = star
	star.Parent = parent
	return star
end

function BaseService.isDomeActive(plot: Plot): boolean
	return now() < plot.domeUntil
end

-- Refleja PlayerData en la parcela: estrellas, carteles y qué prompts están activos.
function BaseService.renderPlot(plot: Plot)
	local owner = plot.owner
	local data = if owner then DataService.get(owner) else nil
	local domeActive = BaseService.isDomeActive(plot)

	for _, pedestal in plot.parts.pedestals do
		local index = pedestal.index
		local star = if data then data.slots[slotKey(index)] else nil
		local unlocked = data ~= nil and index <= data.unlockedSlots

		local visual: BasePart? = plot.visuals[index]
		if star then
			if visual and visual:GetAttribute("Rarity") ~= star.rarity then
				visual:Destroy()
				visual = nil
			end
			if not visual then
				local created = makeStarVisual(star.rarity, pedestal.starPoint, plot.parts.model)
				created:SetAttribute("Rarity", star.rarity)
				plot.visuals[index] = created
			end
		elseif visual then
			visual:Destroy()
			plot.visuals[index] = nil
		end

		pedestal.base.Color = if unlocked then Color3.fromRGB(150, 160, 200) else Color3.fromRGB(60, 62, 72)

		if data and star then
			local level = Economy.maturityLevel(starAge(star))
			local def = Config.RarityById[star.rarity]
			pedestal.label.Text = `{def.displayName} Nv {level}\n{Format.number(star.stored)}`
			setActive(pedestal.ownerPrompt, true, "Cobrar " .. Format.number(star.stored))
			setActive(pedestal.stealPrompt, not domeActive)
		else
			pedestal.label.Text = if unlocked then "Vacío" elseif data and index == data.unlockedSlots + 1
				then "Desbloquear\n" .. Format.number(Economy.slotCost(data.unlockedSlots))
				else ""
			setActive(pedestal.ownerPrompt, unlocked, "Colocar")
			setActive(pedestal.stealPrompt, false)
		end

		local buyable = data ~= nil and index == data.unlockedSlots + 1
		setActive(
			pedestal.buyPrompt,
			buyable,
			if data and buyable then "Desbloquear " .. Format.number(Economy.slotCost(data.unlockedSlots)) else nil
		)
	end

	plot.parts.dome.Transparency = if domeActive then 0.4 else 1
end

function BaseService.renderPlayer(player: Player)
	local plot = plotByPlayer[player]
	if plot then
		BaseService.renderPlot(plot)
	end
end

function BaseService.plots(): { Plot }
	return plots
end

function BaseService.plotOf(player: Player): Plot?
	return plotByPlayer[player]
end

-- Coloca una estrella en un pedestal propio vacío. ageSeconds es la madurez que trae.
function BaseService.placeStar(player: Player, slotIndex: number, rarity: RarityId, ageSeconds: number): boolean
	local data = DataService.get(player)
	if not data or slotIndex > data.unlockedSlots or data.slots[slotKey(slotIndex)] then
		return false
	end
	data.slots[slotKey(slotIndex)] = { rarity = rarity, placedAt = os.time() - ageSeconds, stored = 0 }
	BaseService.renderPlayer(player)
	return true
end

-- Cobra el Polvo acumulado de un pedestal.
function BaseService.collect(player: Player, slotIndex: number)
	local data = DataService.get(player)
	local star = if data then data.slots[slotKey(slotIndex)] else nil
	if not data or not star or star.stored <= 0 then
		return
	end
	data.dust += star.stored
	data.runEarned += star.stored
	star.stored = 0
	DataService.publish(player)
	BaseService.renderPlayer(player)
end

-- Saca la estrella de un pedestal ajeno. Lo acumulado se le cobra a la víctima, no al ladrón.
-- Devuelve la rareza y la edad original; el que roba aplica la penalidad de madurez.
function BaseService.takeStar(plot: Plot, slotIndex: number): (RarityId?, number)
	local owner = plot.owner
	local data = if owner then DataService.get(owner) else nil
	if not owner or not data then
		return nil, 0
	end
	local key = slotKey(slotIndex)
	local star = data.slots[key]
	if not star then
		return nil, 0
	end
	data.slots[key] = nil
	data.dust += star.stored
	data.runEarned += star.stored
	DataService.publish(owner)
	BaseService.renderPlot(plot)
	return star.rarity, starAge(star)
end

-- Saca todas las estrellas (rebirth).
function BaseService.clearStars(player: Player)
	local data = DataService.get(player)
	if data then
		data.slots = {}
	end
	BaseService.renderPlayer(player)
end

local function spawnAtPlot(player: Player)
	local plot = plotByPlayer[player]
	local character = player.Character
	if plot and character then
		character:PivotTo(plot.parts.spawnCFrame)
	end
end

local function applyOfflineIncome(data: PlayerData)
	local seconds = math.clamp(os.time() - data.lastSeen, 0, Config.Offline.maxSeconds)
	if seconds <= 0 then
		return
	end
	for _, star in data.slots do
		star.stored += Economy.starRate(star.rarity, starAge(star), data.rebirths) * seconds
	end
end

local function assignPlot(player: Player, data: PlayerData)
	local free: Plot? = nil
	for _, plot in plots do
		if plot.owner == nil then
			free = plot
			break
		end
	end
	if not free then
		player:Kick("El servidor está lleno, probá con otro.")
		return
	end

	free.owner = player
	free.domeUntil = 0
	free.domeReadyAt = 0
	plotByPlayer[player] = free
	free.parts.model:SetAttribute("OwnerUserId", player.UserId)
	free.parts.sign.Text = "Observatorio de " .. player.DisplayName
	player:SetAttribute("PlotIndex", free.parts.index)
	player:SetAttribute("DomeUntil", 0)
	player:SetAttribute("DomeReadyAt", 0)

	applyOfflineIncome(data)
	BaseService.renderPlot(free)

	player.CharacterAdded:Connect(function()
		task.defer(spawnAtPlot, player)
	end)
	spawnAtPlot(player)
end

local function releasePlot(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.owner = nil
	for index, visual in plot.visuals do
		visual:Destroy()
		plot.visuals[index] = nil
	end
	plot.parts.model:SetAttribute("OwnerUserId", 0)
	plot.parts.sign.Text = "Libre"
	BaseService.renderPlot(plot)
end

local function onBuyPrompt(plot: Plot, slotIndex: number, player: Player)
	if plot.owner ~= player then
		return
	end
	local data = DataService.get(player)
	if not data or slotIndex ~= data.unlockedSlots + 1 or data.unlockedSlots >= Config.Slots.max then
		return
	end
	local cost = Economy.slotCost(data.unlockedSlots)
	if data.dust < cost then
		return
	end
	data.dust -= cost
	data.unlockedSlots += 1
	DataService.publish(player)
	BaseService.renderPlot(plot)
end

local function onDomeRequest(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	local t = now()
	if t < plot.domeReadyAt then
		return
	end
	plot.domeUntil = t + Config.Dome.duration
	plot.domeReadyAt = t + Config.Dome.cooldown
	player:SetAttribute("DomeUntil", plot.domeUntil)
	player:SetAttribute("DomeReadyAt", plot.domeReadyAt)
	BaseService.renderPlot(plot)
	task.delay(Config.Dome.duration, function()
		if plot.owner == player then
			BaseService.renderPlot(plot)
		end
	end)
end

local function tick(dt: number)
	for player, plot in plotByPlayer do
		local data = DataService.get(player)
		if data then
			local total = 0
			for _, star in data.slots do
				local rate = Economy.starRate(star.rarity, starAge(star), data.rebirths)
				star.stored += rate * dt
				total += rate
			end
			player:SetAttribute("Rate", total)
			BaseService.renderPlot(plot)
		end
	end
end

function BaseService.init(worldFolder: Instance)
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = worldFolder

	for index = 1, Config.World.plotCount do
		local plot: Plot = {
			parts = MapBuilder.buildPlot(index, plotsFolder),
			owner = nil,
			domeUntil = 0,
			domeReadyAt = 0,
			visuals = {},
		}
		table.insert(plots, plot)
		for _, pedestal in plot.parts.pedestals do
			pedestal.buyPrompt.Triggered:Connect(function(player: Player)
				onBuyPrompt(plot, pedestal.index, player)
			end)
		end
		BaseService.renderPlot(plot)
	end

	DataService.onLoaded(assignPlot)
	DataService.onReleasing(function(player: Player)
		releasePlot(player)
	end)

	Remotes.get("RequestDome").OnServerEvent:Connect(onDomeRequest)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local t = os.clock()
			tick(t - last)
			last = t
		end
	end)
end

return BaseService
