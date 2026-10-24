--!strict
-- Ciclo de vida de las estrellas: caen en el cráter, se agarran, se cargan, se colocan,
-- se roban y se sueltan. Todo lo decide el servidor; el cliente solo ve prompts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Types = require(ReplicatedStorage.Shared.Types)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local StarVisual = require(script.Parent.StarVisual)

type RarityId = Types.RarityId
type StarInfo = Types.StarInfo
type Plot = BaseService.Plot

type Carry = {
	info: StarInfo,
	age: number, -- madurez que trae; no crece mientras se carga
	pickedAt: number,
	parts: { Instance },
}

local StarService = {}

local random = Random.new()
local starsFolder: Folder
local worldStarCount = 0
local carries: { [Player]: Carry } = {}
local eventActive = false

local function displayName(info: StarInfo): string
	local name = Config.RarityById[info.rarity].displayName
	local traits = StarVisual.traitText(info)
	return if traits ~= "" then `{name} · {traits}` else name
end

local function getRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

function StarService.isCarrying(player: Player): boolean
	return carries[player] ~= nil
end

local function clearCarry(player: Player)
	local carry = carries[player]
	if not carry then
		return
	end
	carries[player] = nil
	for _, part in carry.parts do
		part:Destroy()
	end
	local _, humanoid = getRoot(player)
	if humanoid then
		humanoid.WalkSpeed = Config.Carry.baseWalkSpeed
	end
	player:SetAttribute("Carrying", nil)
end

local function weldTo(part: BasePart, root: BasePart, offset: CFrame)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function attachCarry(player: Player, info: StarInfo, age: number): boolean
	local root, humanoid = getRoot(player)
	local character = player.Character
	if not root or not humanoid or not character or carries[player] then
		return false
	end
	local def = Config.RarityById[info.rarity]

	local star = StarVisual.make(info)
	star.Name = "CarriedStar"
	weldTo(star, root, CFrame.new(0, 4.5, 0))
	star.Parent = character

	-- Columna de luz: todo el mapa ve quién lleva algo valioso.
	local column = Instance.new("Part")
	column.Name = "StarColumn"
	column.Shape = Enum.PartType.Cylinder
	column.Size = Vector3.new(160, 1 + def.size * 0.3, 1 + def.size * 0.3)
	column.Material = Enum.Material.Neon
	column.Color = star.Color
	column.Transparency = 0.55
	column.CastShadow = false
	weldTo(column, root, CFrame.new(0, 84, 0) * CFrame.Angles(0, 0, math.rad(90)))
	column.Parent = character

	humanoid.WalkSpeed = Config.Carry.baseWalkSpeed * def.carrySpeed
	carries[player] = { info = info, age = age, pickedAt = os.clock(), parts = { star, column } }
	player:SetAttribute("Carrying", displayName(info))
	return true
end

local function spawnWorldStar(info: StarInfo, position: Vector3, age: number, lifetime: number): BasePart
	local def = Config.RarityById[info.rarity]
	local star = StarVisual.make(info)
	star.Name = "Star_" .. info.rarity
	star.CFrame = CFrame.new(position.X, def.size / 2 + 0.5, position.Z)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Agarrar"
	prompt.ObjectText = displayName(info)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = star

	local taken = false
	prompt.Triggered:Connect(function(player: Player)
		if taken or carries[player] or not DataService.get(player) then
			return
		end
		if attachCarry(player, info, age) then
			taken = true
			worldStarCount -= 1
			star:Destroy()
		end
	end)

	star.Parent = starsFolder
	worldStarCount += 1

	task.delay(lifetime, function()
		if not taken then
			taken = true
			worldStarCount -= 1
			star:Destroy()
		end
	end)
	return star
end

local function drop(player: Player)
	local carry = carries[player]
	if not carry then
		return
	end
	local root = (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) :: BasePart?
	clearCarry(player)
	if root then
		spawnWorldStar(carry.info, root.Position, carry.age, Config.Spawn.droppedLifetime)
	end
end

-- Aviso en el piso + caída animada, y recién ahí se puede agarrar.
-- Durante el evento caen estrellas mejores y todas traen un rasgo celestial.
local function rainStar()
	local maxInWorld = if eventActive then Config.Spawn.maxInWorld * 2 else Config.Spawn.maxInWorld
	if worldStarCount >= maxInWorld then
		return
	end
	local pool = if eventActive then Config.Event.pool else Config.SpawnPool
	local rarity: RarityId = Economy.pickRarity(random:NextNumber(), pool)
	local info: StarInfo = {
		rarity = rarity,
		mutations = {},
		celestial = if eventActive then Economy.pickCelestial(random:NextNumber()) else nil,
	}
	local def = Config.RarityById[rarity]
	local radius = random:NextNumber(def.minRadius, def.maxRadius)
	local theta = random:NextNumber(0, math.pi * 2)
	local landing = Vector3.new(math.cos(theta) * radius, 0, math.sin(theta) * radius)
	local falling = StarVisual.make(info)
	falling.Name = "FallingStar"
	falling.CFrame = CFrame.new(landing + Vector3.new(0, 120, 0))
	local color = falling.Color

	local marker = Instance.new("Part")
	marker.Name = "LandingMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.2, def.size * 3, def.size * 3)
	marker.CFrame = CFrame.new(landing + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	marker.Anchored = true
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon
	marker.Color = color
	marker.Transparency = 0.5
	marker.Parent = starsFolder

	falling.Parent = starsFolder

	local tween = TweenService:Create(
		falling,
		TweenInfo.new(Config.Spawn.warning, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(landing + Vector3.new(0, def.size / 2 + 0.5, 0)) }
	)
	tween:Play()
	task.delay(Config.Spawn.warning, function()
		marker:Destroy()
		falling:Destroy()
		spawnWorldStar(info, landing, 0, Config.Spawn.lifetime)
	end)
end

local function onOwnerPrompt(plot: Plot, slotIndex: number, player: Player)
	if plot.owner ~= player then
		return
	end
	local carry = carries[player]
	local data = DataService.get(player)
	if not data then
		return
	end
	if carry and data.slots[tostring(slotIndex)] == nil then
		if BaseService.placeStar(player, slotIndex, carry.info, carry.age) then
			clearCarry(player)
		end
	else
		BaseService.collect(player, slotIndex)
	end
end

local function onStealPrompt(plot: Plot, slotIndex: number, thief: Player)
	if plot.owner == nil or plot.owner == thief or carries[thief] then
		return
	end
	if BaseService.isDomeActive(plot) or not DataService.get(thief) then
		return
	end
	local root = getRoot(thief)
	if not root then
		return
	end
	local info: StarInfo?, age: number = BaseService.takeStar(plot, slotIndex)
	if info then
		attachCarry(thief, info, Economy.stolenAge(age))
	end
end

-- Si otro jugador te alcanza mientras cargás, soltás la estrella.
local function checkKnocks()
	for carrier, carry in carries do
		if os.clock() - carry.pickedAt >= Config.Carry.pickupGrace then
			local root = getRoot(carrier)
			if root then
				for _, other in Players:GetPlayers() do
					if other ~= carrier then
						local otherRoot = getRoot(other)
						if otherRoot and (otherRoot.Position - root.Position).Magnitude <= Config.Carry.knockRadius then
							drop(carrier)
							break
						end
					end
				end
			else
				clearCarry(carrier)
			end
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	clearCarry(player)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		drop(player)
	end)
end

function StarService.setEventActive(active: boolean)
	eventActive = active
end

function StarService.init(worldFolder: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Stars"
	folder.Parent = worldFolder
	starsFolder = folder

	for _, plot in BaseService.plots() do
		for _, pedestal in plot.parts.pedestals do
			pedestal.ownerPrompt.Triggered:Connect(function(player: Player)
				onOwnerPrompt(plot, pedestal.index, player)
			end)
			pedestal.stealPrompt.Triggered:Connect(function(player: Player)
				onStealPrompt(plot, pedestal.index, player)
			end)
		end
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		drop(player)
		carries[player] = nil
	end)

	task.spawn(function()
		while true do
			rainStar()
			task.wait(if eventActive then Config.Event.spawnInterval else Config.Spawn.interval)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			checkKnocks()
		end
	end)
end

return StarService
