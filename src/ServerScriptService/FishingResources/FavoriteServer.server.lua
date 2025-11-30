local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local fishingResources = ReplicatedStorage:WaitForChild("FishingResources")
local remotes = fishingResources:WaitForChild("Remotes")

local favoritesDataStore
local dataStoreEnabled = false

local function initializeDataStore()
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("FishFavorites_v1")
	end)

	if success then
		favoritesDataStore = result
		dataStoreEnabled = true
	else
		dataStoreEnabled = false
	end
end

initializeDataStore()

local playerFavorites = {}
local favoritesSaveQueue = {}

local function createOrValidateRemote(name, remoteType)
	local remote = remotes:FindFirstChild(name)
	local expectedClass = remoteType == "Event" and "RemoteEvent" or "RemoteFunction"

	if not remote or not remote:IsA(expectedClass) then
		if remote then
			remote:Destroy()
		end

		if remoteType == "Event" then
			remote = Instance.new("RemoteEvent")
		else
			remote = Instance.new("RemoteFunction")
		end

		remote.Name = name
		remote.Parent = remotes
	end

	return remote
end

local saveFavorites = createOrValidateRemote("SaveFavorites", "Event")
local loadFavorites = createOrValidateRemote("LoadFavorites", "Function")

local function saveFavoritesData(userId)
	if not dataStoreEnabled or not favoritesDataStore then
		return false
	end

	if not playerFavorites[userId] then
		return false
	end

	local maxRetries = 3
	local success = false

	for attempt = 1, maxRetries do
		local saveSuccess, errorMsg = pcall(function()
			favoritesDataStore:SetAsync("Player_" .. tostring(userId), playerFavorites[userId])
		end)

		if saveSuccess then
			success = true
			break
		else
			if attempt < maxRetries then
				task.wait(1)
			end
		end
	end

	return success
end

local function queueFavoritesSave(userId)
	if favoritesSaveQueue[userId] then
		return
	end

	favoritesSaveQueue[userId] = true
	task.spawn(function()
		task.wait(3)
		saveFavoritesData(userId)
		favoritesSaveQueue[userId] = nil
	end)
end

local function loadFavoritesData(userId)
	if not dataStoreEnabled or not favoritesDataStore then
		return {}
	end

	local maxRetries = 3

	for attempt = 1, maxRetries do
		local success, data = pcall(function()
			return favoritesDataStore:GetAsync("Player_" .. tostring(userId))
		end)

		if success then
			if data and type(data) == "table" then
				return data
			else
				return {}
			end
		else
			if attempt < maxRetries then
				task.wait(1)
			end
		end
	end

	return {}
end

local function isFishFavorited(tool, userId)
	local favorites = playerFavorites[userId]
	if not favorites or not tool:FindFirstChild("FishLocationId") then
		return false
	end

	local locationId = tool.FishLocationId.Value
	local uniqueId = tostring(userId) .. "_" .. tostring(locationId) .. "_" .. tool.Name

	return favorites[uniqueId] == true
end

saveFavorites.OnServerEvent:Connect(function(player, favoritesData)
	if not player or not player.Parent then
		return
	end

	if type(favoritesData) ~= "table" then
		return
	end

	playerFavorites[player.UserId] = favoritesData
	queueFavoritesSave(player.UserId)
end)

loadFavorites.OnServerInvoke = function(player)
	if not player or not player.Parent then
		return {}
	end

	local userId = player.UserId

	if not playerFavorites[userId] then
		playerFavorites[userId] = loadFavoritesData(userId)
	end

	local favorites = playerFavorites[userId]
	if not favorites or type(favorites) ~= "table" then
		favorites = {}
		playerFavorites[userId] = favorites
	end

	return favorites
end

Players.PlayerAdded:Connect(function(player)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	task.wait(2)

	local userId = player.UserId
	playerFavorites[userId] = loadFavoritesData(userId)
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId

	if playerFavorites[userId] then
		saveFavoritesData(userId)
	end

	task.spawn(function()
		task.wait(5)
		playerFavorites[userId] = nil
		favoritesSaveQueue[userId] = nil
	end)
end)

task.spawn(function()
	while true do
		task.wait(300)

		for userId, favorites in pairs(playerFavorites) do
			if favorites and type(favorites) == "table" then
				task.spawn(function()
					saveFavoritesData(userId)
				end)
			end
		end
	end
end)

game:BindToClose(function()
	for userId, favorites in pairs(playerFavorites) do
		if favorites and type(favorites) == "table" then
			saveFavoritesData(userId)
		end
	end

	task.wait(5)
end)

if not dataStoreEnabled then
	task.spawn(function()
		task.wait(10)
		initializeDataStore()
	end)
end