--!strict
-- Arranque del servidor. El orden importa: el mapa antes que los servicios que lo usan,
-- y BaseService antes que StarService (que se cuelga de sus pedestales).
local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local StarService = require(script.Parent.StarService)
local RebirthService = require(script.Parent.RebirthService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local world = MapBuilder.buildWorld()
local board = MapBuilder.buildBoard(world)

BaseService.init(world)
StarService.init(world)
RebirthService.init()
LeaderboardService.init(board)
-- Último: recién ahora empiezan a cargar jugadores, con todos los callbacks registrados.
DataService.init()
