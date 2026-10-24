--!strict
-- Leaderboard global: un OrderedDataStore ordenado por rebirths y desempatado por el
-- Polvo de la run (empaquetados en un entero por Economy.leaderboardScore).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)

local RETRY_ATTEMPTS = 3

local LeaderboardService = {}

local store: OrderedDataStore? = nil
local board: TextLabel? = nil
local nameCache: { [number]: string } = {}

local function withRetries<T>(fn: () -> T): (boolean, T?)
	for attempt = 1, RETRY_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[Leaderboard] intento {attempt}/{RETRY_ATTEMPTS}: {result}`)
		if attempt < RETRY_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	return false, nil
end

local function writePlayer(player: Player)
	local activeStore = store
	local data = DataService.get(player)
	if not activeStore or not data then
		return
	end
	local score = Economy.leaderboardScore(data.rebirths, data.runEarned)
	withRetries(function()
		activeStore:SetAsync(tostring(player.UserId), score)
		return true
	end)
end

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok and type(name) == "string" then name else "#" .. userId
	nameCache[userId] = resolved
	return resolved
end

local function refreshBoard()
	local activeStore = store
	local label = board
	if not activeStore or not label then
		return
	end
	local ok, pages = withRetries(function()
		return activeStore:GetSortedAsync(false, Config.Leaderboard.size)
	end)
	if not ok or not pages then
		return
	end

	local lines = { "Top estelar", "" }
	for rank, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		local score = tonumber(entry.value)
		if userId and score then
			local rebirths, dust = Economy.decodeScore(score)
			table.insert(lines, `{rank}. {nameFor(userId)}  ·  R{rebirths}  ·  {Format.number(dust)}`)
		end
	end
	if #lines == 2 then
		table.insert(lines, "Todavía nadie. ¡Sé el primero!")
	end
	label.Text = table.concat(lines, "\n")
end

function LeaderboardService.init(boardLabel: TextLabel)
	board = boardLabel
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Leaderboard.storeName)
	end)
	if ok then
		store = result
	else
		warn("[Leaderboard] OrderedDataStore no disponible:", result)
		boardLabel.Text = "Top estelar\n\nSin acceso a DataStore"
		return
	end

	DataService.onReleasing(function(player: Player)
		task.spawn(writePlayer, player)
	end)

	task.spawn(function()
		while true do
			for player in DataService.players() do
				task.spawn(writePlayer, player)
			end
			task.wait(Config.Leaderboard.writeInterval)
		end
	end)

	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(Config.Leaderboard.readInterval)
		end
	end)
end

return LeaderboardService
