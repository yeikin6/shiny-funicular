--!strict
-- Definición única de los RemoteEvents. El servidor los crea, el cliente los espera.
-- El estado (Polvo, rebirths, cúpula) viaja por atributos del Player, no por remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteName = "RequestRebirth" | "RequestDome"

local NAMES: { RemoteName } = { "RequestRebirth", "RequestDome" }
local FOLDER_NAME = "Remotes"

local folder: Instance
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		for _, name in NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = created
		end
		created.Parent = ReplicatedStorage
		folder = created
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local Remotes = {}

function Remotes.get(name: RemoteName): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
