local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")
local textChatService = game:GetService("TextChatService")
local dataStoreService = game:GetService("DataStoreService")

local fishingResources = replicatedStorage:WaitForChild("FishingResources")
local serverfishingResources = serverScriptService:WaitForChild("FishingResources")
local remotes = fishingResources:WaitForChild("Remotes")
local useCommandRemote = remotes:WaitForChild("UseCommand")
local updateUI = remotes:WaitForChild("UpdateUI")

local Config = require(fishingResources:WaitForChild("Configuration"))
local globalPlayersDataModule = serverfishingResources:FindFirstChild("GlobalPlayersData")
local globalPlayerCatchingModule = serverfishingResources:FindFirstChild("GlobalPlayerCatching")
local playersData = require(globalPlayersDataModule)
local currentlyCatching = require(globalPlayerCatchingModule)

local playerDataStore = dataStoreService:GetDataStore(Config.DataStore.PlayerDataName)
local currencyDataStore = dataStoreService:GetDataStore(Config.Currency.DataStoreName)

-- Use existing popup remote or create if doesn't exist
local popupRemote = remotes:FindFirstChild("PopupNotification")
if not popupRemote then
	popupRemote = Instance.new("RemoteEvent")
	popupRemote.Name = "PopupNotification"
	popupRemote.Parent = remotes
end

local function isAdmin(userId)
	for _, adminId in pairs(Config.Admins) do
		if adminId == userId then
			return true
		end
	end
	return false
end

local function getPlayerCash(player)
	if not player or not player.Parent then
		return 0
	end

	if Config.Currency.UseLeaderstats then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local cash = leaderstats:FindFirstChild(Config.Currency.Name)
			if cash then
				return cash.Value
			end
		end
	end
	return 0
end

local function updatePlayerCash(player, newAmount)
	if not player or not player.Parent then
		return false
	end

	if type(newAmount) ~= "number" then
		return false
	end

	if Config.Currency.UseLeaderstats then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local cash = leaderstats:FindFirstChild(Config.Currency.Name)
			if cash then
				cash.Value = newAmount
			end
		end
	end

	pcall(function()
		updateUI:FireClient(player, newAmount, {
			Equipped = playersData[player.UserId] and playersData[player.UserId].EquippedRod or 1,
			OwnedRods = playersData[player.UserId] and playersData[player.UserId].Rods or {[1] = true}
		})
	end)

	return true
end

local function dataReset(playerUserId)
	if playersData[playerUserId] then
		playersData[playerUserId] = {
			EquippedRod = 1,
			Caught = 0,
			Index = {},
			Rods = {[1] = true},
			Fish = {}
		}
	end

	pcall(function()
		playerDataStore:SetAsync(playerUserId, {
			EquippedRod = 1,
			Caught = 0,
			Index = {},
			Rods = {[1] = false},
			Fish = {}
		})
	end)

	pcall(function()
		currencyDataStore:SetAsync(playerUserId, {
			Currency = 500
		})
	end)
end

local function findPlayerByName(playerName)
	for _, player in pairs(players:GetPlayers()) do
		if string.lower(player.Name):find(string.lower(playerName)) or string.lower(player.DisplayName):find(string.lower(playerName)) then
			return player
		end
	end
	return nil
end

-- Fixed giveFishFast function with unlimited scaling
local function giveFishFast(player, fishId, caught)
	if not player or not player.Parent then
		return false
	end

	local fishData = Config.Fish[tostring(caught.FishId)]
	if not fishData then
		return false
	end

	local fishName = fishData.Name
	local models = fishingResources:WaitForChild("Models")
	local fishModels = models:WaitForChild("Fish")
	local fishModel = fishModels:FindFirstChild(fishName)
	if not fishModel then
		return false
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack or not backpack.Parent then
		return false
	end

	local fishTool = fishModel:Clone()
	fishTool.Name = "[" .. caught.Size .. " kg] " .. fishName
	fishTool.ToolTip = fishName

	-- Apply effects
	local fishEffects = fishingResources:FindFirstChild("FishEffects")
	if fishEffects then
		local appliedEffect = nil
		if caught.Rainbow then
			appliedEffect = {FolderName = "Rainbow", Name = "Rainbow"}
		elseif caught.Shiny then
			appliedEffect = {FolderName = "Shiny", Name = "Shiny"}
		end

		if appliedEffect then
			local effectFolder = fishEffects:FindFirstChild(appliedEffect.FolderName)
			if effectFolder then
				for _, effectChild in pairs(effectFolder:GetChildren()) do
					local clonedEffect = effectChild:Clone()
					clonedEffect.Parent = fishTool.Handle
				end
				fishTool.ToolTip = fishTool.ToolTip .. " | " .. appliedEffect.Name
			end
		end
	end

	local id = Instance.new("IntValue")
	id.Name = "FishLocationId"
	id.Value = fishId
	id.Parent = fishTool

	local success = pcall(function()
		fishTool.Parent = backpack
	end)

	if not success then
		fishTool:Destroy()
		return false
	end

	return true
end

-- Fixed givePlayerRodFast function
local function givePlayerRodFast(player, rodId)
	if not player or not player.Parent then
		return false
	end

	local rodData = Config.Rods[rodId]
	if not rodData or not rodData.RodName then
		return false
	end

	local models = fishingResources:WaitForChild("Models")
	local rodModels = models:WaitForChild("Rods")
	local rodModel = rodModels:FindFirstChild(rodData.RodName)
	if not rodModel then
		return false
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack or not backpack.Parent then
		return false
	end

	-- Remove existing rods
	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool.Name == rodData.RodName then
			tool:Destroy()
		end
	end

	if player.Character then
		for _, tool in pairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == rodData.RodName then
				tool:Destroy()
			end
		end
	end

	local playersRod = rodModel:Clone()
	local success = pcall(function()
		playersRod.Parent = backpack
	end)

	if not success then
		playersRod:Destroy()
		return false
	end

	return true
end

local function reloadPlayerItems(player)
	if not player or not player.Parent then return end

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				tool:Destroy()
			end
		end
	end

	if player.Character then
		for _, tool in pairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") then
				tool:Destroy()
			end
		end
	end

	task.wait(1)

	-- Reload fish
	if playersData[player.UserId] and playersData[player.UserId].Fish then
		for fishId, fishInfo in pairs(playersData[player.UserId].Fish) do
			if fishInfo and type(fishInfo) == "table" then
				giveFishFast(player, fishId, fishInfo)
				task.wait(0.1)
			end
		end
	end

	-- Reload equipped rod
	if playersData[player.UserId] and playersData[player.UserId].EquippedRod and playersData[player.UserId].EquippedRod ~= 0 then
		givePlayerRodFast(player, playersData[player.UserId].EquippedRod)
	end
end

local commands = {
	["kick"] = function(args)
		local player = findPlayerByName(args[1])
		if not player then
			return "Player not found"
		end
		local reason = args[2] or "Kicked by admin"
		player:Kick(reason)
		return "Kicked " .. player.Name
	end,

	["datawipe"] = function(args)
		local player = findPlayerByName(args[1])
		if not player then
			return "Player not found"
		end

		dataReset(player.UserId)
		updatePlayerCash(player, 500)

		task.wait(0.5)
		reloadPlayerItems(player)

		return "Data wiped for " .. player.Name
	end,

	["givefish"] = function(args)
		local player = findPlayerByName(args[1])
		if not player or not args[2] or not args[3] then
			return "Usage: /givefish <username> <fishId> <size> [shiny] [rainbow]"
		end

		if not playersData[player.UserId] then
			return "Player data not loaded"
		end

		local fishId = tonumber(args[2])
		local size = tonumber(args[3])
		local isShiny = args[4] and string.lower(args[4]) == "true"
		local isRainbow = args[5] and string.lower(args[5]) == "true"

		if not fishId or not size then
			return "Invalid fishId or size"
		end

		local fishData = {
			FishId = fishId,
			Size = size
		}

		if isShiny then
			fishData.Shiny = true
		end
		if isRainbow then
			fishData.Rainbow = true
		end

		local fishArray = playersData[player.UserId].Fish
		local newIndex = #fishArray + 1
		fishArray[newIndex] = fishData

		if not playersData[player.UserId].Index[fishId] then
			playersData[player.UserId].Index[fishId] = true
		end

		local newCaughtCount = (playersData[player.UserId].Caught or 0) + 1
		playersData[player.UserId].Caught = newCaughtCount

		local success = giveFishFast(player, newIndex, fishData)

		local effectText = ""
		if isShiny then effectText = effectText .. " Shiny" end
		if isRainbow then effectText = effectText .. " Rainbow" end

		if success then
			return "Gave " .. player.Name .. " fish ID " .. fishId .. " (" .. size .. "kg)" .. effectText
		else
			return "Failed to give fish to " .. player.Name
		end
	end,

	["giverod"] = function(args)
		local player = findPlayerByName(args[1])
		if not player or not args[2] then
			return "Usage: /giverod <username> <rodId>"
		end

		local rodId = tonumber(args[2])
		if not rodId then
			return "Invalid rod ID"
		end

		if not playersData[player.UserId] then
			return "Player data not loaded"
		end

		playersData[player.UserId].Rods[rodId] = true
		playersData[player.UserId].EquippedRod = rodId

		local currentCash = getPlayerCash(player)
		updatePlayerCash(player, currentCash)

		local success = givePlayerRodFast(player, rodId)

		if success then
			return "Gave " .. player.Name .. " rod ID " .. rodId
		else
			return "Failed to give rod to " .. player.Name
		end
	end,

	["nextcatch"] = function(args)
		local player = findPlayerByName(args[1])
		if not player or not args[2] or not args[3] then
			return "Usage: /nextcatch <username> <fishId> <kg> [shiny] [rainbow]"
		end

		local fishId = tonumber(args[2])
		local kg = tonumber(args[3])
		local isShiny = args[4] and string.lower(args[4]) == "true"
		local isRainbow = args[5] and string.lower(args[5]) == "true"

		if not fishId or not kg then
			return "Invalid fishId or kg value"
		end

		local catchData = {
			FishId = fishId,
			Size = kg
		}

		if isShiny then
			catchData.Shiny = true
		end
		if isRainbow then
			catchData.Rainbow = true
		end

		currentlyCatching[player.UserId] = catchData

		local effectText = ""
		if isShiny then effectText = effectText .. " Shiny" end
		if isRainbow then effectText = effectText .. " Rainbow" end

		return "Set next catch for " .. player.Name .. ": Fish ID " .. fishId .. " (" .. kg .. "kg)" .. effectText
	end,

	["setmoney"] = function(args)
		local player = findPlayerByName(args[1])
		if not player or not args[2] then
			return "Usage: /setmoney <username> <amount>"
		end

		local amount = tonumber(args[2])
		if not amount then
			return "Invalid amount"
		end

		if not playersData[player.UserId] then
			return "Player data not loaded"
		end

		updatePlayerCash(player, amount)

		return "Set " .. player.Name .. "'s money to " .. amount
	end,

	["givemoney"] = function(args)
		local player = findPlayerByName(args[1])
		if not player or not args[2] then
			return "Usage: /givemoney <username> <amount>"
		end

		local amount = tonumber(args[2])
		if not amount then
			return "Invalid amount"
		end

		if not playersData[player.UserId] then
			return "Player data not loaded"
		end

		local currentCash = getPlayerCash(player)
		local newAmount = currentCash + amount
		updatePlayerCash(player, newAmount)

		return "Gave " .. player.Name .. " " .. amount .. " money (Total: " .. newAmount .. ")"
	end,

	["reload"] = function(args)
		local player = findPlayerByName(args[1])
		if not player then
			return "Usage: /reload <username>"
		end

		reloadPlayerItems(player)

		return "Reloaded items for " .. player.Name
	end,

	["clearinv"] = function(args)
		local player = findPlayerByName(args[1])
		if not player then
			return "Usage: /clearinv <username>"
		end

		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			for _, tool in pairs(backpack:GetChildren()) do
				if tool:IsA("Tool") then
					tool:Destroy()
				end
			end
		end

		if player.Character then
			for _, tool in pairs(player.Character:GetChildren()) do
				if tool:IsA("Tool") then
					tool:Destroy()
				end
			end
		end

		return "Cleared inventory for " .. player.Name
	end,

	["tp"] = function(args)
		local player1 = findPlayerByName(args[1])
		local player2 = findPlayerByName(args[2])

		if not player1 or not player2 then
			return "Usage: /tp <username1> <username2>"
		end

		if not player1.Character or not player1.Character:FindFirstChild("HumanoidRootPart") then
			return player1.Name .. " character not loaded"
		end

		if not player2.Character or not player2.Character:FindFirstChild("HumanoidRootPart") then
			return player2.Name .. " character not loaded"
		end

		player1.Character.HumanoidRootPart.CFrame = player2.Character.HumanoidRootPart.CFrame + Vector3.new(0, 0, 3)

		return "Teleported " .. player1.Name .. " to " .. player2.Name
	end,

	["commands"] = function(args)
		return [[Available Commands:
- /kick <username> [reason]
- /datawipe <username>
- /givefish <username> <fishId> <kg> [shiny] [rainbow]
- /giverod <username> <rodId>
- /nextcatch <username> <fishId> <kg> [shiny] [rainbow]
- /setmoney <username> <amount>
- /givemoney <username> <amount>
- /reload <username>
- /clearinv <username>
- /tp <username1> <username2>
- /commands]]
	end,
}

-- Improved sendMessage function using PopUp module
local function sendMessage(player, message, messageType)
	-- Default to success if not specified
	messageType = messageType or "Success"

	-- Try PopUp module first (most reliable)
	local success1 = pcall(function()
		popupRemote:FireClient(player, message, messageType)
	end)

	-- Fallback: Print to console for debugging
	if not success1 then
		print("[Admin Command] " .. player.Name .. ": " .. message)
	end
end

useCommandRemote.OnServerInvoke = function(plr, command, args)
	if not isAdmin(plr.UserId) then
		local errorMsg = "Access denied"
		sendMessage(plr, errorMsg, "Failed")
		return errorMsg
	end

	if commands[command] then
		local success, result = pcall(function()
			return commands[command](args)
		end)

		if success then
			if result and result ~= "" then
				-- FIXED: Determine message type based on result content
				local messageType = "Success"
				local lowerResult = string.lower(result)
				if string.find(lowerResult, "failed") or 
					string.find(lowerResult, "error") or 
					string.find(lowerResult, "not found") or
					string.find(lowerResult, "usage:") or  -- Added this line
					string.find(lowerResult, "invalid") then  -- Added this line too
					messageType = "Failed"
				end

				sendMessage(plr, result, messageType)
				return result
			else
				local successMsg = "Command executed successfully"
				sendMessage(plr, successMsg, "Success")
				return successMsg
			end
		else
			local errorMsg = "Command failed: " .. tostring(result)
			sendMessage(plr, errorMsg, "Failed")
			return errorMsg
		end
	else
		local errorMsg = "Unknown command. Use 'help' for command list."
		sendMessage(plr, errorMsg, "Failed")
		return errorMsg
	end
end

players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if not isAdmin(player.UserId) then return end

		if message:sub(1, 1) == "/" then
			local args = message:sub(2):split(" ")
			local command = table.remove(args, 1)

			if commands[command] then
				local success, result = pcall(function()
					return commands[command](args)
				end)

				if success then
					if result and result ~= "" then
						-- FIXED: Determine message type based on result content
						local messageType = "Success"
						local lowerResult = string.lower(result)
						if string.find(lowerResult, "failed") or 
							string.find(lowerResult, "error") or 
							string.find(lowerResult, "not found") or
							string.find(lowerResult, "usage:") or  -- Added this line
							string.find(lowerResult, "invalid") then  -- Added this line too
							messageType = "Failed"
						end

						sendMessage(player, result, messageType)
					else
						sendMessage(player, "Command executed successfully", "Success")
					end
				else
					sendMessage(player, "Command failed: " .. tostring(result), "Failed")
				end
			else
				sendMessage(player, "Unknown command. Use 'help' for command list.", "Failed")
			end
		end
	end)
end)