local Configuration = {}

-- ============================================
-- 1. Basic Settings (Critical Fix: FishCaught)
-- ============================================
Configuration.Currency = {
	Name = "Cash",
	FishCaughtName = "FishCaught",
	UseLeaderstats = true,
	Type = "IntValue",
	LeaderstatsFolderName = "leaderstats",
	DataStoreName = "PlayerCurrency_AquariumV1" -- Modify name to reset data and avoid old data conflicts
}

-- !!!! This is the missing part that caused errors before !!!!
Configuration.FishCaught = {
	UseLeaderstats = false,
	Name = "FishCaught" 
}

Configuration.AutoFishing = {
	RequireGamepass = false,
	GamepassId = 1538286405,
}

Configuration.MaxFishInventory = {
	Enabled = true,
	MaxFish = 200,
	WarningMessage = "Inventory is full! Please sell your fish first."
}

-- ============================================
-- 2. Zone Settings (ZONE SETTINGS)
-- ============================================
-- Name must match the Part name in Workspace (e.g., Workspace.FishingZones.Ocean)
Configuration.Zones = {
	["Default"] = {1, 2, 7, 11}, -- Default Fishing Spot (when zone not found)
	["Ocean"] = {3, 5, 6, 8, 9, 10, 13}, -- Ocean Fish
	["Lake"] = {1, 2, 4, 12}, -- Lake Fish
}

-- ============================================
-- 3. Aquarium & Income Settings (AQUARIUM)
-- ============================================
Configuration.Aquarium = {
	IncomePercentage = 0.2, -- Income Rate 20% (0.2)
	IncomeRate = 1,         -- How often income is distributed (in seconds)
	MaxOfflineTime = 43200, -- Maximum offline income duration (seconds) - 12 hours here
}

-- ============================================
-- 4. Rarity & Notifications
-- ============================================
Configuration.ChatNotification = {
	Enabled = true,
	MessageFormat = "[System] %s caught a %s (%.1fkg) %s!",
	ShowCommon = false, ShowUncommon = false, ShowRare = true, ShowUltraRare = true, ShowLegendary = true, ShowSpecialEffects = true,

	RarityTiers = {
		{threshold = 1, name = "Legendary", color = Color3.fromRGB(255, 215, 0)},
		{threshold = 3, name = "Epic", color = Color3.fromRGB(128, 0, 128)},
		{threshold = 8, name = "Rare", color = Color3.fromRGB(0, 100, 255)},
		{threshold = 20, name = "Uncommon", color = Color3.fromRGB(0, 200, 0)},
		{threshold = 100, name = "Common", color = Color3.fromRGB(255, 255, 255)} -- Add Common to prevent errors
	},
	EffectColors = { Rainbow = Color3.fromRGB(255, 0, 255), Shiny = Color3.fromRGB(255, 215, 0) }
}

-- ============================================
-- 5. Fishing Rod & Fish Attributes (Keep as is)
-- ============================================
Configuration.Admins = { 579734219, 987654321 }

Configuration.Rods = {
	[1] = { RodName = "Rod1", Cost = 0, Control = 1, LureSpeed = 1, Luck = 1, Strength = 1, Resilience = 1, MaxKg = 2000, ImageId = "rbxassetid://5938101762", Currency = true, Gamepass = false },
	[2] = { RodName = "Rod2", Cost = 500, Control = 1.05, LureSpeed = 2, Luck = 1.5, Strength = 1.5, Resilience = 1.4, MaxKg = 2000, ImageId = "rbxassetid://5938101762", Currency = true, Gamepass = false },
	[3] = { RodName = "Rod3", Cost = 500, Control = 1, LureSpeed = 1, Luck = 3, Strength = 1, Resilience = 3, MaxKg = 10000, ImageId = "rbxassetid://5938101762", Currency = false, Gamepass = true, GamepassId = 1118205115, GamepassPrice = 500 },
	[4] = { RodName = "Ocean Rod", Cost = 1000, Control = 1, LureSpeed = 1, Luck = 3, Strength = 1, Resilience = 3, MaxKg = 10000, ImageId = "rbxassetid://5938101762", Currency = true, Gamepass = false, GamepassId = 1118205115, GamepassPrice = 500 },
	[5] = { RodName = "AdminRod", Cost = 1000, Control = 1, LureSpeed = 8, Luck = 300, Strength = 10, Resilience = 10, MaxKg = 10000, ImageId = "rbxassetid://5938101762", Currency = true, Gamepass = false, GamepassId = 1118205115, GamepassPrice = 500 },
	[6] = { RodName = "MusketRod", Cost = 1000, Control = 1, LureSpeed = 8, Luck = 300, Strength = 10, Resilience = 10, MaxKg = 10000, ImageId = "rbxassetid://5938101762", Currency = true, Gamepass = false, GamepassId = 1118205115, GamepassPrice = 500 },
	["Legend"] = { RodName = "Legend", Cost = 0, Control = 1, LureSpeed = 1, Luck = 999, Strength = 1, Resilience = 3, MaxKg = 10000, ImageId = "rbxassetid://5938101762", AdminOnly = true, Currency = false, Gamepass = false }
}

Configuration.Fish = {
	["1"] = { Name = "Diaper", LowWeightRange = 0.5, HighWeightRange = 3, CostPerKG = 1, Movement = 1, UltraRare = true },
	["2"] = { Name = "Butete", LowWeightRange = 2.5, HighWeightRange = 3, CostPerKG = 2, Movement = 1 },
	["3"] = { Name = "Blue fish", LowWeightRange = 2.4, HighWeightRange = 5.3, CostPerKG = 34, Movement = 1.3, Rare = true },
	["4"] = { Name = "Jellyfish", LowWeightRange = 3, HighWeightRange = 9, CostPerKG = 326, Movement = 0.7, UltraRare = true },
	["5"] = { Name = "Barracuda", LowWeightRange = 5, HighWeightRange = 20, CostPerKG = 120, Movement = 0.9, Rare = true },
	["6"] = { Name = "Amberjack", LowWeightRange = 4, HighWeightRange = 15, CostPerKG = 85, Movement = 1.1 },
	["7"] = { Name = "Bicolor Blenny", LowWeightRange = 0.2, HighWeightRange = 0.8, CostPerKG = 40, Movement = 1.5, Common = true },
	["8"] = { Name = "Longbill Spearfish", LowWeightRange = 10, HighWeightRange = 30, CostPerKG = 200, Movement = 0.8, Rare = true },
	["9"] = { Name = "Shark", LowWeightRange = 50, HighWeightRange = 300, CostPerKG = 500, Movement = 0.6, Legendary = true },
	["10"] = { Name = "Tuna", LowWeightRange = 10, HighWeightRange = 50, CostPerKG = 150, Movement = 1 },	
	["11"] = { Name = "Boxfish", LowWeightRange = 1, HighWeightRange = 5, CostPerKG = 25, Movement = 1.4 },
	["12"] = { Name = "Clown Trigger Fish", LowWeightRange = 3, HighWeightRange = 7, CostPerKG = 95, Movement = 1.2, Rare = true },
	["13"] = { Name = "Opah", LowWeightRange = 20, HighWeightRange = 60, CostPerKG = 220, Movement = 0.9, UltraRare = true }
}

Configuration.FishChances = { [1]=20, [2]=15, [3]=10, [4]=5, [5]=6, [6]=8, [7]=18, [8]=5, [9]=2, [10]=7, [11]=12, [12]=6, [13]=3 }
Configuration.SpecialRates = { Shiny = 50, Rainbow = 100 }
Configuration.FishEffects = {
	Enabled = true, CombinationChance = 100, CombinationMultiplier = 1.5,
	Effects = {
		Shiny = { Name = "Shiny", FolderName = "Shiny", Chance = 50, SellMultiplier = 2, Priority = 2 },
		Rainbow = { Name = "Rainbow", FolderName = "Rainbow", Chance = 100, SellMultiplier = 3, Priority = 3 },
	}
}
Configuration.FishScaling = { Enabled = true, MinScale = 0.5, MaxScale = 2.0 }
Configuration.DataStore = { PlayerDataName = Configuration.Currency.DataStoreName, SaveDelay = 2, AutoSaveInterval = 300, MaxRetries = 3 }
Configuration.Loading = { PlayerReadyTimeout = 15, ItemLoadDelay = 1, UIUpdateDelay = 0.5, FishBatchSize = 10, RodGiveDelay = 0.1 }
Configuration.Gameplay = { RodUseCooldown = 3, WaterCheckRadius = 1 }

return Configuration