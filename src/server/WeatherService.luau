--!strict
-- Tormentas y evento celestial.
-- Tormenta: cada pocos minutos, durante un rato, cada estrella colocada de los jugadores
-- conectados puede ganar la mutación de esa tormenta (una sola vez por tipo; se apilan).
-- Evento: cada 30 min caen estrellas con rasgo celestial (Nocturna, Lunar, Solar, Eclipse).
-- El estado viaja al cliente por atributos de workspace.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Types = require(ReplicatedStorage.Shared.Types)
local BaseService = require(script.Parent.BaseService)
local StarService = require(script.Parent.StarService)

type MutationId = Types.MutationId

local WeatherService = {}

local random = Random.new()
local timeScale = if RunService:IsStudio() then Config.StudioTimeScale else 1

local function now(): number
	return workspace:GetServerTimeNow()
end

local function runStorm()
	local mutation: MutationId = Economy.pickMutation(random:NextNumber())
	local duration = Config.Storms.duration
	workspace:SetAttribute("Storm", mutation)
	workspace:SetAttribute("StormEndsAt", now() + duration)

	local rolls = math.max(1, math.floor(Config.Storms.duration / Config.Storms.rollEvery))
	for _ = 1, rolls do
		task.wait(duration / rolls)
		BaseService.forEachPlacedStar(function(plot, star)
			if random:NextNumber() < Config.Storms.chancePerRoll and Economy.addMutation(star, mutation) then
				BaseService.renderPlot(plot)
			end
		end)
	end

	workspace:SetAttribute("Storm", nil)
	workspace:SetAttribute("StormEndsAt", nil)
end

local function runEvent()
	local duration = Config.Event.duration
	workspace:SetAttribute("EventEndsAt", now() + duration)
	StarService.setEventActive(true)
	task.wait(duration)
	StarService.setEventActive(false)
	workspace:SetAttribute("EventEndsAt", nil)
end

function WeatherService.init()
	task.spawn(function()
		while true do
			local wait = Config.Storms.interval * timeScale
			workspace:SetAttribute("NextStormAt", now() + wait)
			task.wait(wait)
			runStorm()
		end
	end)

	task.spawn(function()
		while true do
			local wait = Config.Event.interval * timeScale
			workspace:SetAttribute("NextEventAt", now() + wait)
			task.wait(wait)
			runEvent()
		end
	end)
end

return WeatherService
