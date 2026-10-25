--!strict
-- Arranque del cliente.
local HudController = require(script.Parent.HudController)
local PromptController = require(script.Parent.PromptController)
local WeatherFx = require(script.Parent.WeatherFx)

HudController.start()
PromptController.start()
WeatherFx.start()
