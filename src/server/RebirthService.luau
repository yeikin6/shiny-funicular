--!strict
-- Rebirth: cuesta 10.000 · 6^R de Polvo, borra Polvo y estrellas, deja el multiplicador
-- 2.5^R y los pedestales desbloqueados.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)

local REQUEST_COOLDOWN = 1

local RebirthService = {}

local lastRequest: { [Player]: number } = {}

local function onRequest(player: Player)
	local t = os.clock()
	if t - (lastRequest[player] or 0) < REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = t

	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Economy.rebirthCost(data.rebirths)
	if data.dust < cost then
		return
	end

	data.rebirths += 1
	data.dust = 0
	data.runEarned = 0
	BaseService.clearStars(player)
	DataService.publish(player)
end

function RebirthService.init()
	Remotes.get("RequestRebirth").OnServerEvent:Connect(onRequest)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return RebirthService
