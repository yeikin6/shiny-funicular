--!strict
-- Aviso de tormenta y de evento arriba al centro, y tinte de pantalla durante la tormenta.
-- Lee los atributos de workspace que publica WeatherService.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local localPlayer = Players.LocalPlayer

local WeatherFx = {}

local function numberAttribute(name: string): number?
	local value = workspace:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

function WeatherFx.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Weather"
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 12)
	banner.Size = UDim2.fromOffset(460, 34)
	banner.BackgroundColor3 = Color3.fromRGB(16, 18, 30)
	banner.BackgroundTransparency = 0.3
	banner.TextColor3 = Color3.new(1, 1, 1)
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 18
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = banner
	banner.Parent = gui

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "StormTint"
	tint.Parent = Lighting

	local currentStorm: string? = nil
	local function updateTint()
		local storm = workspace:GetAttribute("Storm")
		local id = if type(storm) == "string" then storm else nil
		if id == currentStorm then
			return
		end
		currentStorm = id
		local def = if id then Config.MutationById[id :: any] else nil
		local target = if def then Color3.fromHex(def.colorHex):Lerp(Color3.new(1, 1, 1), 0.6) else Color3.new(1, 1, 1)
		TweenService:Create(tint, TweenInfo.new(2), { TintColor = target }):Play()
	end

	local function update()
		updateTint()
		local t = workspace:GetServerTimeNow()
		local eventEnds = numberAttribute("EventEndsAt")
		local stormEnds = numberAttribute("StormEndsAt")
		local storm = workspace:GetAttribute("Storm")
		local nextEvent = numberAttribute("NextEventAt")

		if eventEnds then
			banner.Text = `Lluvia celestial: caen estrellas únicas · {Format.seconds(eventEnds - t)}`
			banner.TextColor3 = Color3.fromRGB(255, 210, 120)
		elseif stormEnds and type(storm) == "string" then
			local def = Config.MutationById[storm :: any]
			local name = if def then def.displayName else storm
			local multiplier = if def then def.multiplier else 1
			banner.Text = `Tormenta: {name} (x{multiplier}) · {Format.seconds(stormEnds - t)}`
			banner.TextColor3 = if def then Color3.fromHex(def.colorHex) else Color3.new(1, 1, 1)
		elseif nextEvent then
			banner.Text = `Próxima lluvia celestial en {Format.seconds(nextEvent - t)}`
			banner.TextColor3 = Color3.fromRGB(200, 205, 230)
		else
			banner.Text = ""
		end
		banner.Visible = banner.Text ~= ""
	end

	task.spawn(function()
		while gui.Parent do
			update()
			task.wait(0.25)
		end
	end)
end

return WeatherFx
