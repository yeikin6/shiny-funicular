--!strict
-- Todos los números tuneables del juego en un solo lugar.
local Types = require(script.Parent.Types)

type RarityDef = Types.RarityDef
type RarityId = Types.RarityId

local Rarities: { RarityDef } = {
	{
		id = "Comun",
		displayName = "Común",
		weight = 70,
		baseRate = 1,
		carrySpeed = 1.0,
		size = 2,
		minRadius = 0,
		maxRadius = 40,
		colorHex = "#d9e4ff",
	},
	{
		id = "Rara",
		displayName = "Rara",
		weight = 22,
		baseRate = 8,
		carrySpeed = 0.9,
		size = 2.5,
		minRadius = 15,
		maxRadius = 55,
		colorHex = "#4fa3ff",
	},
	{
		id = "Epica",
		displayName = "Épica",
		weight = 6,
		baseRate = 60,
		carrySpeed = 0.8,
		size = 3,
		minRadius = 30,
		maxRadius = 65,
		colorHex = "#b45cff",
	},
	{
		id = "Legendaria",
		displayName = "Legendaria",
		weight = 1.8,
		baseRate = 500,
		carrySpeed = 0.7,
		size = 3.5,
		minRadius = 40,
		maxRadius = 70,
		colorHex = "#ffb020",
	},
	{
		id = "Mitica",
		displayName = "Mítica",
		weight = 0.2,
		baseRate = 4000,
		carrySpeed = 0.6,
		size = 4,
		minRadius = 50,
		maxRadius = 75,
		colorHex = "#ff4f8b",
	},
}

local byId: { [RarityId]: RarityDef } = {}
for _, def in Rarities do
	byId[def.id] = def
end

-- El MVP solo hace caer estas tres; las otras quedan definidas para cuando haya contenido.
local SpawnPool: { RarityId } = { "Comun", "Rara", "Epica" }

local Config = {
	Rarities = Rarities,
	RarityById = byId,
	SpawnPool = SpawnPool,

	Spawn = {
		interval = 8, -- segundos entre estrellas
		warning = 2, -- segundos de aviso antes de que caiga
		lifetime = 30, -- segundos que una estrella queda en el piso
		maxInWorld = 12,
		droppedLifetime = 30,
	},

	Maturity = {
		minutesDivisor = 2, -- L = floor(sqrt(minutos / 2))
		maxLevel = 40,
		growthPerLevel = 1.08, -- ingreso x1.08 por nivel
		stolenLevelFactor = 0.5, -- una estrella robada conserva la mitad del nivel
	},

	Rebirth = {
		baseCost = 10_000,
		costGrowth = 6,
		multiplier = 2.5,
	},

	Slots = {
		startUnlocked = 3,
		max = 8,
		baseCost = 50,
		costGrowth = 8,
	},

	Dome = {
		duration = 60,
		cooldown = 90,
	},

	Carry = {
		baseWalkSpeed = 16,
		knockRadius = 4, -- si otro jugador se acerca a menos de esto, soltás la estrella
		pickupGrace = 1.5, -- segundos de inmunidad al agarrar
	},

	Steal = {
		holdDuration = 2,
	},

	Offline = {
		maxSeconds = 8 * 60 * 60,
	},

	Data = {
		storeName = "PlayerData_v1",
		autosaveInterval = 60,
		lockStaleSeconds = 180, -- un lock sin refrescar por más de esto se considera muerto
		lockAttempts = 5,
		lockRetryWait = 4,
	},

	Leaderboard = {
		storeName = "Leaderboard_v1",
		writeInterval = 120,
		readInterval = 60,
		size = 10,
	},

	World = {
		plotCount = 6,
		plotRadius = 150, -- distancia del centro del cráter a cada parcela
		craterRadius = 80,
	},
}

return Config
