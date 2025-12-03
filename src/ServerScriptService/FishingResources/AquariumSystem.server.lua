local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local FishingResources = RS:WaitForChild("FishingResources", 10)
if not FishingResources then return end

local Remotes = FishingResources:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder", FishingResources)
	Remotes.Name = "Remotes"
end

local PlaceFishFunc = Remotes:FindFirstChild("PlaceFishInAquarium")
if not PlaceFishFunc then
	PlaceFishFunc = Instance.new("RemoteFunction", Remotes)
	PlaceFishFunc.Name = "PlaceFishInAquarium"
end

local RetrieveFishFunc = Remotes:FindFirstChild("RetrieveFishFromAquarium")
if not RetrieveFishFunc then
	RetrieveFishFunc = Instance.new("RemoteFunction", Remotes)
	RetrieveFishFunc.Name = "RetrieveFishFromAquarium"
end

local ConfigModule = FishingResources:WaitForChild("Configuration", 10)
local Config = ConfigModule and require(ConfigModule) or {}
local FishModels = FishingResources:FindFirstChild("Models")

local PlayerPendingCash = {} 
local PlayerAquariumData = {}

-- [Configuration] UI Visible Distance
local UI_MAX_DISTANCE = 30 

-- Clean Fish Name
local function cleanFishName(rawName)
	local name = string.gsub(rawName, "%b[]", "")
	return string.match(name, "^%s*(.-)%s*$")
end

-- [Critical Fix] Grant Fish Tool to Player
local function giveFishTool(player, fishData)
	local toolName = fishData.Name
	print("[SERVER-DEBUG] Attempting to return tool: " .. tostring(toolName))

	-- 1. Try to find the tool with the same name globally in ReplicatedStorage
	-- (Use true for recursive search since I don't know the exact subfolder of your tools)
	local sourceTool = RS:FindFirstChild(toolName, true)

	if not sourceTool then
		-- If not found, try searching in FishingResources
		if FishingResources then
			sourceTool = FishingResources:FindFirstChild(toolName, true)
		end
	end

	if sourceTool and sourceTool:IsA("Tool") then
		local newTool = sourceTool:Clone()

		-- 2. Restore Data (Attributes)
		newTool:SetAttribute("Weight", fishData.Weight or 1)
		newTool:SetAttribute("Value", fishData.Value or 0)
		newTool:SetAttribute("FishId", fishData.FishId) -- Ensure ID is also set

		-- 3. Restore Data (ValueObjects - For backward compatibility with old systems using Value objects)
		local wVal = newTool:FindFirstChild("Weight") or Instance.new("NumberValue", newTool)
		wVal.Name = "Weight"; wVal.Value = fishData.Weight or 1

		local vVal = newTool:FindFirstChild("Value") or Instance.new("NumberValue", newTool)
		vVal.Name = "Value"; vVal.Value = fishData.Value or 0

		local idVal = newTool:FindFirstChild("FishId") or Instance.new("IntValue", newTool)
		idVal.Name = "FishId"; idVal.Value = fishData.FishId or 0

		-- 4. Grant the tool
		newTool.Parent = player.Backpack
		print("[SERVER-DEBUG] ✅ Successfully sent " .. toolName .. " to player's backpack.")
	else
		warn("---------------------------------------------------")
		warn("[SERVER-ERROR] ❌ Failed to return fish! Could not find tool in ReplicatedStorage: " .. tostring(toolName))
		warn("Please ensure your fish Tool objects are stored somewhere in ReplicatedStorage with names matching those in the Config.")
		warn("---------------------------------------------------")
	end
end

local function getFishRarityInfo(fishId)
	if not Config.Fish then return "Unknown", Color3.new(1,1,1) end
	local stats = Config.Fish[tostring(fishId)]
	if not stats then return "Common", Color3.new(1,1,1) end
	if stats.Legendary then return "Legendary", Color3.fromRGB(255, 215, 0) end
	if stats.UltraRare then return "Ultra Rare", Color3.fromRGB(255, 0, 255) end
	if stats.Rare then return "Rare", Color3.fromRGB(0, 100, 255) end
	if stats.Uncommon then return "Uncommon", Color3.fromRGB(0, 200, 0) end
	return "Common", Color3.fromRGB(255, 255, 255)
end

-- Sorting Logic: Z first, then X
local function getSortedStands(baseModel)
	local standsFolder = baseModel:FindFirstChild("Stands")
	if not standsFolder then return {} end
	local stands = {}
	for _, v in ipairs(standsFolder:GetChildren()) do
		if v.Name == "CharacterStand" then table.insert(stands, v) end
	end

	table.sort(stands, function(a, b)
		local posA = a:GetPivot().Position
		local posB = b:GetPivot().Position
		if math.abs(posA.Z - posB.Z) < 1 then
			return posA.X < posB.X
		end
		return posA.Z < posB.Z
	end)

	return stands
end

local function getStandByIndex(baseModel, index)
	local stands = getSortedStands(baseModel)
	return stands[index]
end

-- [Visual Update]
local function visualizeFish(standModel, fishData)
	local placementPoint = standModel:FindFirstChild("PlacementPoint")
	if not placementPoint then return end

	if placementPoint:FindFirstChild("DisplayFish") then placementPoint.DisplayFish:Destroy() end
	if placementPoint:FindFirstChild("InfoGui") then placementPoint.InfoGui:Destroy() end

	if not fishData then return end

	local fishId = tostring(fishData.FishId)
	local fishStats = Config.Fish and Config.Fish[fishId]
	if not fishStats then return end

	local modelTemplate = FishModels and (FishModels:FindFirstChild(fishStats.Name) or FishModels:FindFirstChild(fishId))

	if modelTemplate then 
		local displayFish = modelTemplate:Clone()
		displayFish.Name = "DisplayFish" 
		displayFish.Parent = placementPoint

		local targetCFrame = placementPoint.CFrame * CFrame.new(0, 1.5, 0)
		if displayFish:IsA("Model") then
			displayFish:PivotTo(targetCFrame)
			for _, p in pairs(displayFish:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
		elseif displayFish:IsA("BasePart") then
			displayFish.CFrame = targetCFrame
			displayFish.Anchored = true; displayFish.CanCollide = false
		end
	else
		-- Fallback for missing model
		local fallbackPart = Instance.new("Part")
		fallbackPart.Name = "DisplayFish"
		fallbackPart.Size = Vector3.new(2, 1, 1)
		fallbackPart.Color = Color3.fromRGB(255, 50, 50)
		fallbackPart.Material = Enum.Material.Neon
		fallbackPart.Anchored = true; fallbackPart.CanCollide = false
		fallbackPart.CFrame = placementPoint.CFrame * CFrame.new(0, 1.5, 0)
		fallbackPart.Parent = placementPoint
	end

	-- UI
	local rarityName, rarityColor = getFishRarityInfo(fishId)
	local bbGui = Instance.new("BillboardGui", placementPoint)
	bbGui.Name = "InfoGui"
	bbGui.Size = UDim2.new(0, 150, 0, 80)
	bbGui.StudsOffset = Vector3.new(0, 3.5, 0)
	bbGui.AlwaysOnTop = true
	bbGui.MaxDistance = UI_MAX_DISTANCE

	local nameLabel = Instance.new("TextLabel", bbGui)
	nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1; nameLabel.TextScaled = false
	nameLabel.TextSize = 14 -- [CONFIG] Fish Name Font Size
	nameLabel.Text = fishStats.Name
	nameLabel.Font = Enum.Font.SourceSansBold; nameLabel.TextColor3 = Color3.new(1,1,1); nameLabel.TextStrokeTransparency = 0.5

	local rarityLabel = Instance.new("TextLabel", bbGui)
	rarityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rarityLabel.Position = UDim2.new(0, 0, 0.3, 0)
	rarityLabel.BackgroundTransparency = 1; rarityLabel.TextScaled = false
	rarityLabel.TextSize = 12 -- [CONFIG] Rarity Font Size
	rarityLabel.Text = rarityName
	rarityLabel.Font = Enum.Font.SourceSansBold; rarityLabel.TextColor3 = rarityColor; rarityLabel.TextStrokeTransparency = 0.5

	local incomeLabel = Instance.new("TextLabel", bbGui)
	incomeLabel.Size = UDim2.new(1, 0, 0.3, 0)
	incomeLabel.Position = UDim2.new(0,0, 0.6, 0)
	incomeLabel.BackgroundTransparency = 1
	local income = math.floor((fishData.Value or 0) * (Config.Aquarium and Config.Aquarium.IncomePercentage or 0.2))
	incomeLabel.Text = "+$" .. income .. "/s"
	incomeLabel.TextColor3 = Color3.new(0, 1, 0)
	incomeLabel.Font = Enum.Font.SourceSansBold; incomeLabel.TextScaled = false
	incomeLabel.TextSize = 14 -- [CONFIG] Income Font Size
	incomeLabel.TextStrokeTransparency = 0.5
end

local function forceUpdatePartUI(part, uiName, uiText, player, isCashCollect, slotIndex, myBase)
	for _, child in pairs(part:GetChildren()) do
		if child:IsA("Script") then child:Destroy() end
		if (child:IsA("BillboardGui") or child:IsA("SurfaceGui")) and child.Name ~= uiName then child:Destroy() end
	end
	local bb = part:FindFirstChild(uiName)
	if not bb then
		bb = Instance.new("BillboardGui", part)
		bb.Name = uiName
		bb.Size = UDim2.new(0, 120, 0, 40)
		bb.AlwaysOnTop = true
		bb.MaxDistance = UI_MAX_DISTANCE
		if isCashCollect then bb.StudsOffset = Vector3.new(0, 2.5, 0) else bb.StudsOffset = Vector3.new(0, 6.5, 0) end
		local lbl = Instance.new("TextLabel", bb)
		lbl.Name = "Label"
		lbl.Size = UDim2.new(1,0,1,0)
		lbl.BackgroundTransparency = 1
		lbl.TextScaled = false
		lbl.TextSize = 20 -- [CONFIG] Pending Cash Font Size
		lbl.Font = Enum.Font.SourceSansBold; lbl.TextStrokeTransparency = 0.3
		if isCashCollect then lbl.TextColor3 = Color3.new(1, 0.9, 0.4) else lbl.TextColor3 = Color3.new(0.4, 1, 0.4) end
	end
	if bb:FindFirstChild("Label") then bb.Label.Text = uiText end

	if isCashCollect and slotIndex and not part:GetAttribute("IsLinked") then
		part:SetAttribute("IsLinked", true)
		local debounce = false
		part.Touched:Connect(function(hit)
			if debounce then return end
			if hit.Parent == player.Character then
				local pendingData = PlayerPendingCash[player.UserId]
				local amount = pendingData and pendingData[slotIndex] or 0
				if amount > 0 then
					debounce = true
					_G.addCash(player, amount)
					if pendingData then pendingData[slotIndex] = 0 end
					if bb:FindFirstChild("Label") then bb.Label.Text = "$0" end
					if myBase then
						local currentTotal = 0
						if pendingData then for _, v in pairs(pendingData) do currentTotal = currentTotal + v end end
						local sp = myBase:FindFirstChild("SpawnPoint")
						if sp and sp:FindFirstChild("IncomeGui") and sp.IncomeGui:FindFirstChild("Label") then
							sp.IncomeGui.Label.Text = "Pending: $" .. currentTotal
						end
					end
					task.wait(1)
					debounce = false
				end
			end
		end)
	end
end

PlaceFishFunc.OnServerInvoke = function(player, slotIndexStr)
	local profile = _G.getProfile(player)
	if not profile then return false, "Profile not loaded" end
	if not player.Character then return false, "Character not loaded" end

	local tool = player.Character:FindFirstChildWhichIsA("Tool")
	if not tool then return false, "No item in hand" end

	local fishId = tool:GetAttribute("FishId") or (tool:FindFirstChild("FishId") and tool.FishId.Value)
	if not fishId then
		local cleanName = cleanFishName(tool.Name)
		if Config.Fish then
			for id, data in pairs(Config.Fish) do
				if data.Name == cleanName then fishId = id; break end
			end
		end
	end
	if not fishId then return false, "This is not a valid fish" end

	local fishConfig = Config.Fish and Config.Fish[tostring(fishId)]
	local weight = tool:GetAttribute("Weight") or (tool:FindFirstChild("Weight") and tool.Weight.Value)
	if not weight or weight <= 0 then
		local wMatch = string.match(tool.Name, "%[([%d%.]+)%s*kg%]")
		if wMatch then weight = tonumber(wMatch) end
	end
	if not weight then weight = 1 end

	local value = tool:GetAttribute("Value") or (tool:FindFirstChild("Value") and tool.Value.Value)
	if not value or value <= 0 then
		if fishConfig and fishConfig.CostPerKG then
			value = math.floor(weight * fishConfig.CostPerKG)
		else
			value = 100 
		end
	end

	local fishDataToSave = {
		FishId = tonumber(fishId),
		Weight = weight,
		Value = value,
		Name = fishConfig and fishConfig.Name or "Unknown Fish"
	}

	local inventory = profile.Data.FishInventory or profile.Data.Inventory
	if not inventory then return false, "Inventory missing" end

	for i, f in ipairs(inventory) do
		if tostring(f.FishId) == tostring(fishId) then
			table.remove(inventory, i)
			break
		end
	end

	local tycoons = workspace:FindFirstChild("Tycoons")
	local myBase = nil
	if tycoons then
		for _, t in pairs(tycoons:GetChildren()) do
			local o = t:FindFirstChild("# Owner") or t:FindFirstChild("Owner")
			if o and tostring(o.Value) == tostring(player.UserId) then myBase = t; break end
		end
	end
	if not myBase then return false, "Your base not found" end

	local standPart = getStandByIndex(myBase, tonumber(slotIndexStr))
	if not standPart then return false, "Invalid display stand" end

	tool:Destroy()

	if not profile.Data.Aquarium then profile.Data.Aquarium = {} end

	-- [Replacement Logic]
	local oldFish = profile.Data.Aquarium["Slot_" .. slotIndexStr]
	local statusMessage = "Placed"

	if oldFish then
		table.insert(inventory, oldFish)
		statusMessage = "Swapped" 
		print("[SERVER] Database updated: Returned " .. oldFish.Name)
		-- [Added] Actually return the item
		giveFishTool(player, oldFish)
	end

	profile.Data.Aquarium["Slot_" .. slotIndexStr] = fishDataToSave
	PlayerAquariumData[player.UserId] = profile.Data.Aquarium

	visualizeFish(standPart, fishDataToSave)
	return true, statusMessage
end

RetrieveFishFunc.OnServerInvoke = function(player, slotIndex)
	local profile = _G.getProfile(player)
	if not profile then return false, "Profile not loaded" end

	if not profile.Data.Aquarium then return false, "Aquarium is empty" end
	local slotKey = "Slot_" .. slotIndex
	local fishData = profile.Data.Aquarium[slotKey]

	if not fishData then return false, "Slot is empty" end

	local inventory = profile.Data.FishInventory or profile.Data.Inventory
	if not inventory then return false, "Inventory missing" end

	local tycoons = workspace:FindFirstChild("Tycoons")
	local myBase = nil
	if tycoons then
		for _, t in pairs(tycoons:GetChildren()) do
			local o = t:FindFirstChild("# Owner") or t:FindFirstChild("Owner")
			if o and tostring(o.Value) == tostring(player.UserId) then myBase = t; break end
		end
	end
	if not myBase then return false, "Base not found" end
	local standPart = getStandByIndex(myBase, tonumber(slotIndex))

	table.insert(inventory, fishData)
	profile.Data.Aquarium[slotKey] = nil
	PlayerAquariumData[player.UserId] = profile.Data.Aquarium

	print("[SERVER] Database updated: Retrieved " .. fishData.Name)
	-- [Added] Actually return the item
	giveFishTool(player, fishData)

	if standPart then
		visualizeFish(standPart, nil) 
		if PlayerPendingCash[player.UserId] then
			PlayerPendingCash[player.UserId][tonumber(slotIndex)] = 0
		end
		local cp = standPart:FindFirstChild("CashCollect")
		if cp then forceUpdatePartUI(cp, "StatusGui", "$0", player, true, tonumber(slotIndex), myBase) end
	end
	return true
end

-- Base Assignment & Loop (No changes, keep previous logic)
local function tryAssignBase(player)
	local tycoonsFolder = workspace:FindFirstChild("Tycoons")
	if not tycoonsFolder then return nil end
	local allTycoons = tycoonsFolder:GetChildren()
	if #allTycoons == 0 then return nil end
	for _, t in pairs(allTycoons) do
		local o = t:FindFirstChild("# Owner") or t:FindFirstChild("Owner")
		if o and tostring(o.Value) == tostring(player.UserId) then return t end
	end
	for _, t in pairs(allTycoons) do
		local o = t:FindFirstChild("# Owner") or t:FindFirstChild("Owner")
		local v = o and tonumber(o.Value)
		if not o or v == 0 or v == nil then
			if not o then o = Instance.new("IntValue", t); o.Name = "# Owner" end
			o.Value = player.UserId
			return t
		end
	end
	local fallback = allTycoons[1]
	local o = fallback:FindFirstChild("# Owner") or fallback:FindFirstChild("Owner")
	if not o then o = Instance.new("IntValue", fallback); o.Name = "# Owner" end
	o.Value = player.UserId
	return fallback
end

Players.PlayerAdded:Connect(function(player)
	local event = player:WaitForChild("AquariumDataLoaded", 10)
	if event then
		local conn
		conn = event.Event:Connect(function(aquariumData)
			PlayerPendingCash[player.UserId] = {}
			PlayerAquariumData[player.UserId] = aquariumData or {}
			conn:Disconnect()
		end)
	else
		PlayerPendingCash[player.UserId] = {}
		PlayerAquariumData[player.UserId] = {}
	end

	task.spawn(function()
		local myBase = nil
		local visualRestored = false
		workspace:WaitForChild("Tycoons", 120)

		while player.Parent do
			if not myBase then
				myBase = tryAssignBase(player)
				if myBase then
					local spawnPoint = myBase:FindFirstChild("SpawnPoint")
					if spawnPoint then
						player.CharacterAdded:Connect(function(char)
							task.wait(0.5)
							if char and char:FindFirstChild("HumanoidRootPart") then
								char:PivotTo(spawnPoint.CFrame * CFrame.new(0, 3, 0))
							end
						end)
					end

					-- Delay 4 seconds to wait for data loading
					if not visualRestored then
						print("[SERVER] Waiting for data sync (4 seconds)...")
						task.wait(4)
					end
				end
			end

			if myBase then
				if not visualRestored and PlayerAquariumData[player.UserId] then
					for key, data in pairs(PlayerAquariumData[player.UserId]) do
						local index = tonumber(string.match(key, "%d+"))
						if index then
							local standModel = getStandByIndex(myBase, index)
							if standModel then visualizeFish(standModel, data) end
						end
					end
					visualRestored = true
					print("[SERVER] Visual sync completed.")
				end

				local pendingData = PlayerPendingCash[player.UserId] or {}
				local incomePerc = Config.Aquarium and Config.Aquarium.IncomePercentage or 0.2
				local totalPending = 0

				for key, d in pairs(PlayerAquariumData[player.UserId] or {}) do
					local slotIndex = tonumber(string.match(key, "%d+"))
					if slotIndex then
						local inc = math.floor((d.Value or 0) * incomePerc)
						if inc > 0 then
							pendingData[slotIndex] = (pendingData[slotIndex] or 0) + inc
						end
					end
				end

				for _, v in pairs(pendingData) do totalPending = totalPending + v end
				PlayerPendingCash[player.UserId] = pendingData

				local sortedStands = getSortedStands(myBase)
				for i, stand in ipairs(sortedStands) do
					local cp = stand:FindFirstChild("CashCollect")
					if cp then
						local standCash = pendingData[i] or 0
						forceUpdatePartUI(cp, "StatusGui", "$" .. standCash, player, true, i, myBase)
					end
				end

				local sp = myBase:FindFirstChild("SpawnPoint")
				if sp then
					forceUpdatePartUI(sp, "IncomeGui", "Pending: $" .. totalPending, player, false)
				end
			end
			task.wait(1)
		end
	end)
end)

print("[SERVER] AquariumSystem startup completed.")