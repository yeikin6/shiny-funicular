--!strict
-- Funciones puras de la economía. No tocan instancias: el servidor las usa para decidir,
-- el cliente solo para mostrar.
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type RarityId = Types.RarityId

local Economy = {}

function Economy.maturityLevel(ageSeconds: number): number
	local minutes = math.max(ageSeconds, 0) / 60
	local level = math.floor(math.sqrt(minutes / Config.Maturity.minutesDivisor))
	return math.min(level, Config.Maturity.maxLevel)
end

-- Edad mínima (s) para tener un nivel dado; inversa de maturityLevel.
function Economy.ageForLevel(level: number): number
	return Config.Maturity.minutesDivisor * level * level * 60
end

-- Edad que conserva una estrella robada: la mitad del nivel, redondeado para abajo.
function Economy.stolenAge(ageSeconds: number): number
	local level = Economy.maturityLevel(ageSeconds)
	return Economy.ageForLevel(math.floor(level * Config.Maturity.stolenLevelFactor))
end

function Economy.rebirthMultiplier(rebirths: number): number
	return Config.Rebirth.multiplier ^ rebirths
end

function Economy.starRate(rarity: RarityId, ageSeconds: number, rebirths: number): number
	local def = Config.RarityById[rarity]
	local level = Economy.maturityLevel(ageSeconds)
	return def.baseRate * Config.Maturity.growthPerLevel ^ level * Economy.rebirthMultiplier(rebirths)
end

function Economy.rebirthCost(rebirths: number): number
	return Config.Rebirth.baseCost * Config.Rebirth.costGrowth ^ rebirths
end

-- Costo de desbloquear el siguiente pedestal teniendo `unlocked` desbloqueados.
function Economy.slotCost(unlocked: number): number
	return Config.Slots.baseCost * Config.Slots.costGrowth ^ (unlocked - Config.Slots.startUnlocked)
end

-- OrderedDataStore solo guarda enteros: rebirths en los dígitos altos,
-- log10 del Polvo de la run (x1000, máx ~308000) en los bajos.
function Economy.leaderboardScore(rebirths: number, runEarned: number): number
	local dustPart = math.floor(math.log10(math.max(runEarned, 0) + 1) * 1000)
	return math.floor(rebirths) * 1_000_000 + math.clamp(dustPart, 0, 999_999)
end

function Economy.decodeScore(score: number): (number, number)
	local rebirths = score // 1_000_000
	local dust = 10 ^ ((score % 1_000_000) / 1000) - 1
	return rebirths, dust
end

-- roll en [0, 1). Recibe el número aleatorio para que la función siga siendo pura.
function Economy.pickRarity(roll: number, pool: { RarityId }): RarityId
	-- Las variables van anotadas: sin anotación, Luau ensancha los literales de RarityId a string.
	local total = 0
	for _, id: RarityId in pool do
		total += Config.RarityById[id].weight
	end
	local target = roll * total
	for _, id: RarityId in pool do
		target -= Config.RarityById[id].weight
		if target < 0 then
			return id
		end
	end
	return pool[#pool]
end

return Economy
