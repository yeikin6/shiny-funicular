--!strict
-- HUD mínimo: Polvo, Polvo/s, botón de cúpula y botón de rebirth.
-- Lee todo de los atributos del Player que publica el servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer

local HudController = {}

local function numberAttribute(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function makeLabel(parent: Instance, position: UDim2, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Position = position
	button.Size = UDim2.fromOffset(200, 48)
	button.AnchorPoint = Vector2.new(1, 1)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Parent = parent
	return button
end

function HudController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(16, 16)
	panel.Size = UDim2.fromOffset(320, 84)
	panel.BackgroundColor3 = Color3.fromRGB(16, 18, 30)
	panel.BackgroundTransparency = 0.3
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel
	panel.Parent = gui

	local dustLabel = makeLabel(panel, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 36), 30)
	dustLabel.TextColor3 = Color3.fromRGB(255, 225, 140)
	local rateLabel = makeLabel(panel, UDim2.fromOffset(14, 46), UDim2.new(1, -28, 0, 28), 18)

	local domeButton = makeButton(gui, UDim2.new(1, -16, 1, -76), Color3.fromRGB(40, 110, 180))
	local rebirthButton = makeButton(gui, UDim2.new(1, -16, 1, -16), Color3.fromRGB(150, 60, 190))

	domeButton.Activated:Connect(function()
		Remotes.get("RequestDome"):FireServer()
	end)
	rebirthButton.Activated:Connect(function()
		Remotes.get("RequestRebirth"):FireServer()
	end)

	local function update()
		local dust = numberAttribute("Dust")
		local rebirths = numberAttribute("Rebirths")
		dustLabel.Text = "✦ " .. Format.number(dust)
		local carrying = localPlayer:GetAttribute("Carrying")
		local multiplier = Format.number(Economy.rebirthMultiplier(rebirths))
		rateLabel.Text = `{Format.number(numberAttribute("Rate"))}/s  ·  x{multiplier}`
			.. if type(carrying) == "string" then "  ·  cargando " .. carrying else ""

		local cost = Economy.rebirthCost(rebirths)
		rebirthButton.Text = `Rebirth ({Format.number(cost)})`
		rebirthButton.BackgroundTransparency = if dust >= cost then 0 else 0.55

		local t = workspace:GetServerTimeNow()
		local domeUntil = numberAttribute("DomeUntil")
		local domeReadyAt = numberAttribute("DomeReadyAt")
		if t < domeUntil then
			domeButton.Text = "Cúpula activa " .. Format.seconds(domeUntil - t)
			domeButton.BackgroundTransparency = 0
		elseif t < domeReadyAt then
			domeButton.Text = "Cúpula en " .. Format.seconds(domeReadyAt - t)
			domeButton.BackgroundTransparency = 0.55
		else
			domeButton.Text = "Cerrar cúpula"
			domeButton.BackgroundTransparency = 0
		end
	end

	localPlayer.AttributeChanged:Connect(update)
	task.spawn(function()
		while gui.Parent do
			update()
			task.wait(0.25)
		end
	end)
end

return HudController
