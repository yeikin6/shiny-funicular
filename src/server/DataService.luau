--!strict
-- Carga y guardado de PlayerData con reintentos y session locking.
-- El lock evita duplicar estrellas cuando un jugador entra a otro servidor antes de que
-- el anterior termine de guardar: en un juego de robos eso rompe la economía.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerData = Types.PlayerData

type SessionLock = { jobId: string, time: number }
type Record = { data: PlayerData?, lock: SessionLock? }

type Session = {
	data: PlayerData,
	persistent: boolean, -- false en Studio sin acceso a API: se juega pero no se guarda
	saving: boolean,
}

local DATA_VERSION = 1
local RETRY_ATTEMPTS = 5

local DataService = {}

local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Player, PlayerData) -> () } = {}
local releasingCallbacks: { (Player, PlayerData) -> () } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.storeName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore no disponible:", result)
	end
end

local function defaultData(): PlayerData
	return {
		version = DATA_VERSION,
		dust = 0,
		runEarned = 0,
		rebirths = 0,
		unlockedSlots = Config.Slots.startUnlocked,
		slots = {},
		lastSeen = os.time(),
	}
end

-- Completa campos faltantes de datos viejos o corruptos sin perder lo que haya.
local function reconcile(raw: any): PlayerData
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	if type(raw.dust) == "number" then
		data.dust = raw.dust
	end
	if type(raw.runEarned) == "number" then
		data.runEarned = raw.runEarned
	end
	if type(raw.rebirths) == "number" then
		data.rebirths = raw.rebirths
	end
	if type(raw.unlockedSlots) == "number" then
		data.unlockedSlots = math.clamp(raw.unlockedSlots, Config.Slots.startUnlocked, Config.Slots.max)
	end
	if type(raw.lastSeen) == "number" then
		data.lastSeen = raw.lastSeen
	end
	if type(raw.slots) == "table" then
		for key, star in raw.slots do
			if
				type(key) == "string"
				and type(star) == "table"
				and Config.RarityById[star.rarity] ~= nil
				and type(star.placedAt) == "number"
			then
				data.slots[key] = {
					rarity = star.rarity,
					placedAt = star.placedAt,
					stored = if type(star.stored) == "number" then star.stored else 0,
				}
			end
		end
	end
	return data
end

-- Reintenta con backoff exponencial (1, 2, 4, 8 s). Devuelve ok y el error del último intento.
local function withRetries(label: string, fn: () -> ()): (boolean, string?)
	local lastError: string? = nil
	for attempt = 1, RETRY_ATTEMPTS do
		-- El wrapper devuelve string? para que el tipo de pcall tenga lugar para el error.
		local ok, err = pcall(function(): string?
			fn()
			return nil
		end)
		if ok then
			return true, nil
		end
		lastError = tostring(err)
		warn(`[DataService] {label} falló (intento {attempt}/{RETRY_ATTEMPTS}): {lastError}`)
		if attempt < RETRY_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

-- Toma el lock de sesión y devuelve los datos. "locked" si otro servidor sigue teniéndolo.
local function loadRecord(player: Player): (PlayerData?, string?)
	local activeStore = store
	if not activeStore then
		return nil, "sin DataStore"
	end

	for _ = 1, Config.Data.lockAttempts do
		local loaded: PlayerData? = nil
		local lockedByOther = false

		local ok, err = withRetries("carga", function()
			activeStore:UpdateAsync(keyFor(player), function(old: any): any
				local record: Record = if type(old) == "table" then old else { data = nil, lock = nil }
				local lock = record.lock
				local now = os.time()
				if lock and lock.jobId ~= game.JobId and now - lock.time < Config.Data.lockStaleSeconds then
					lockedByOther = true
					return nil -- cancela la escritura
				end
				lockedByOther = false
				local data = reconcile(record.data)
				loaded = data
				return { data = data, lock = { jobId = game.JobId, time = now } }
			end)
		end)

		if not ok then
			return nil, err
		end
		if not lockedByOther then
			return loaded, nil
		end
		if not player.Parent then
			return nil, "el jugador se fue"
		end
		task.wait(Config.Data.lockRetryWait)
	end

	return nil, "locked"
end

local function saveRecord(player: Player, session: Session, release: boolean): boolean
	local activeStore = store
	if not session.persistent or not activeStore then
		return true
	end

	session.data.lastSeen = os.time()
	local ok = withRetries(if release then "guardado final" else "autosave", function()
		activeStore:UpdateAsync(keyFor(player), function(old: any): any
			local record: Record = if type(old) == "table" then old else { data = nil, lock = nil }
			local lock = record.lock
			if lock and lock.jobId ~= game.JobId then
				-- Otro servidor tomó la sesión: no pisamos sus datos.
				warn(`[DataService] lock de {player.UserId} pertenece a otro servidor, no se guarda`)
				return nil
			end
			return {
				data = session.data,
				lock = if release then nil else { jobId = game.JobId, time = os.time() },
			}
		end)
	end)
	return ok
end

local function publishLeaderstats(player: Player, data: PlayerData)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local dust = Instance.new("StringValue")
		dust.Name = "Polvo"
		dust.Parent = folder
		local rebirths = Instance.new("IntValue")
		rebirths.Name = "Rebirths"
		rebirths.Parent = folder
		folder.Parent = player
		stats = folder
	end
	assert(stats)
	local dustValue = stats:FindFirstChild("Polvo") :: StringValue?
	local rebirthValue = stats:FindFirstChild("Rebirths") :: IntValue?
	if dustValue then
		dustValue.Value = Format.number(data.dust)
	end
	if rebirthValue then
		rebirthValue.Value = data.rebirths
	end
end

-- Copia el estado visible al cliente. Llamar después de cada cambio de datos.
function DataService.publish(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.data
	player:SetAttribute("Dust", data.dust)
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("RunEarned", data.runEarned)
	player:SetAttribute("UnlockedSlots", data.unlockedSlots)
	publishLeaderstats(player, data)
end

function DataService.get(player: Player): PlayerData?
	local session = sessions[player]
	return if session then session.data else nil
end

function DataService.players(): { [Player]: PlayerData }
	local result: { [Player]: PlayerData } = {}
	for player, session in sessions do
		result[player] = session.data
	end
	return result
end

function DataService.onLoaded(callback: (Player, PlayerData) -> ())
	table.insert(loadedCallbacks, callback)
end

-- Corre antes del guardado final, para que otros servicios vuelquen su estado en data.
function DataService.onReleasing(callback: (Player, PlayerData) -> ())
	table.insert(releasingCallbacks, callback)
end

local function onPlayerAdded(player: Player)
	local data, err = loadRecord(player)
	local persistent = true

	if not data then
		if RunService:IsStudio() then
			warn(`[DataService] {err}. En Studio se juega sin guardar (habilitá "Studio Access to API Services").`)
			data = defaultData()
			persistent = false
		else
			if player.Parent then
				player:Kick("No pudimos cargar tus datos. Volvé a entrar en un minuto.")
			end
			return
		end
	end

	if not player.Parent then
		-- Se fue mientras cargaba: soltamos el lock enseguida.
		if persistent and data then
			saveRecord(player, { data = data, persistent = true, saving = false }, true)
		end
		return
	end

	assert(data)
	sessions[player] = { data = data, persistent = persistent, saving = false }
	DataService.publish(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function release(player: Player)
	local session = sessions[player]
	if not session or session.saving then
		return
	end
	session.saving = true
	for _, callback in releasingCallbacks do
		local ok, err = pcall(function(): string?
			callback(player, session.data)
			return nil
		end)
		if not ok then
			warn("[DataService] onReleasing falló:", err)
		end
	end
	saveRecord(player, session, true)
	sessions[player] = nil
end

function DataService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(release)

	task.spawn(function()
		while true do
			task.wait(Config.Data.autosaveInterval)
			for player, session in sessions do
				if not session.saving then
					task.spawn(saveRecord, player, session, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return DataService
