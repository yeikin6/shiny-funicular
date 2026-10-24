--!strict
-- Decide qué prompts de pedestal ve este jugador. El servidor marca cada prompt con Role
-- y Active; acá se cruza con el dueño de la parcela. Es solo visual: el servidor valida igual.
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local PromptController = {}

local function plotOwnerOf(prompt: ProximityPrompt): number?
	local current: Instance? = prompt.Parent
	while current do
		local owner = current:GetAttribute("OwnerUserId")
		if type(owner) == "number" then
			return owner
		end
		current = current.Parent
	end
	return nil
end

local function refresh(prompt: ProximityPrompt)
	local role = prompt:GetAttribute("Role")
	local active = prompt:GetAttribute("Active") == true
	local owner = plotOwnerOf(prompt)
	if owner == nil then
		return
	end
	local isMine = owner == localPlayer.UserId
	local visible = active
		and (
			((role == "Owner" or role == "Buy") and isMine)
			or (role == "Steal" and not isMine and owner ~= 0)
		)
	prompt.Enabled = visible
end

local function track(prompt: ProximityPrompt)
	if prompt:GetAttribute("Role") == nil then
		return
	end
	refresh(prompt)
	prompt:GetAttributeChangedSignal("Active"):Connect(function()
		refresh(prompt)
	end)
end

function PromptController.start()
	local world = workspace:WaitForChild("World")
	local plots = world:WaitForChild("Plots")

	local function watchOwner(plot: Instance)
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			for _, descendant in plot:GetDescendants() do
				if descendant:IsA("ProximityPrompt") then
					refresh(descendant)
				end
			end
		end)
	end
	for _, plot in plots:GetChildren() do
		watchOwner(plot)
	end
	plots.ChildAdded:Connect(watchOwner)

	for _, descendant in plots:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			track(descendant)
		end
	end
	plots.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			task.defer(track, descendant)
		end
	end)
end

return PromptController
