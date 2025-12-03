local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local ProfileService = require(SSS:WaitForChild("ProfileService"))
local FishingResources = RS:WaitForChild("FishingResources")
local Configuration = require(FishingResources:WaitForChild("Configuration"))
local Players = game:GetService("Players")

local ProfileTemplate = {
	[Configuration.Currency.Name] = 0,
	FishInventory = {}, 
	Aquarium = {}, 
	LastLogout = 0
}

local ProfileStore = ProfileService.GetProfileStore(Configuration.DataStore.PlayerDataName, ProfileTemplate)
local Profiles = {}

-- [Core Fix] Create Leaderstats Immediately
local function ensureLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	-- Create Value object immediately (default 0)
	local cashName = Configuration.Currency.Name
	local cashValue = leaderstats:FindFirstChild(cashName)
	if not cashValue then
		if Configuration.Currency.Type == "NumberValue" then
			cashValue = Instance.new("NumberValue")
		else
			cashValue = Instance.new("IntValue")
		end
		cashValue.Name = cashName
		cashValue.Value = 0
		cashValue.Parent = leaderstats
	end
	return cashValue
end

Players.PlayerAdded:Connect(function(player)
	-- 1. As soon as the player joins, even before data loads, immediately create empty data structure
	-- This prevents errors in the encrypted main script
	local cashValue = ensureLeaderstats(player)

	-- 2. Start loading real data
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick()
		end)

		if player:IsDescendantOf(Players) == true then
			Profiles[player] = profile

			-- Data loaded successfully, update value
			cashValue.Value = profile.Data[Configuration.Currency.Name]

			-- Bind synchronization
			cashValue.Changed:Connect(function()
				profile.Data[Configuration.Currency.Name] = cashValue.Value
			end)

			-- Notify Aquarium system
			task.defer(function()
				local AquariumLoaded = Instance.new("BindableEvent")
				AquariumLoaded.Name = "AquariumDataLoaded"
				AquariumLoaded.Parent = player
				AquariumLoaded:Fire(profile.Data.Aquarium, profile.Data.LastLogout)
				game.Debris:AddItem(AquariumLoaded, 10)
			end)
		else
			profile:Release()
		end
	else
		player:Kick("Profile load fail")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile.Data.LastLogout = os.time()
		profile:Release()
	end
end)

local function addCash(player, amount)
	local profile = Profiles[player]
	if profile then
		local current = profile.Data[Configuration.Currency.Name]
		profile.Data[Configuration.Currency.Name] = current + amount
		ensureLeaderstats(player).Value = profile.Data[Configuration.Currency.Name]
		return true
	end
	return false
end

local function getProfile(player)
	return Profiles[player]
end

_G.addCash = addCash
_G.getProfile = getProfile