local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local FishingResources = RS:WaitForChild("FishingResources", 30)
local Remotes = FishingResources:WaitForChild("Remotes", 30)
local Modules = FishingResources:WaitForChild("Modules", 30)
local Config = require(FishingResources:WaitForChild("Configuration"))
local GuiModule = require(Modules:WaitForChild("GuiModule"))

local placeFunc = Remotes:WaitForChild("PlaceFishInAquarium", 30)
local retrieveFunc = Remotes:WaitForChild("RetrieveFishFromAquarium", 30)

if not placeFunc or not retrieveFunc then 
	warn("[CLIENT] ❌ Fatal Error: Remote functions not loaded!")
	return 
end

print("[CLIENT] Aquarium Interaction Script Started (v23 Sort Fix Version)...")

local function getHeldFishData(tool)
	if not tool then return nil end
	local fishId = tool:GetAttribute("FishId") or (tool:FindFirstChild("FishId") and tool.FishId.Value)
	if not fishId then
		local cleanName = string.gsub(tool.Name, "%b[]", "")
		cleanName = string.match(cleanName, "^%s*(.-)%s*$")
		for id, data in pairs(Config.Fish) do
			if data.Name == cleanName then
				fishId = id
				break
			end
		end
	end
	if fishId then return { Tool = tool, FishId = fishId } end
	return nil
end

local function setupInteractions(baseModel)
	print("[CLIENT] Configuring Interactions: " .. baseModel.Name)
	local standsFolder = baseModel:WaitForChild("Stands", 10)
	if not standsFolder then return end

	local stands = {}
	for _, v in ipairs(standsFolder:GetChildren()) do
		if v.Name == "CharacterStand" then table.insert(stands, v) end
	end

	-- [Critical Fix] Sync server-side sorting: Z first, then X
	table.sort(stands, function(a, b)
		local posA = a:GetPivot().Position
		local posB = b:GetPivot().Position

		if math.abs(posA.Z - posB.Z) < 1 then
			return posA.X < posB.X
		end
		return posA.Z < posB.Z
	end)

	print("[CLIENT] Sorted " .. #stands .. " display stands")

	for index, stand in ipairs(stands) do
		local placementPoint = stand:WaitForChild("PlacementPoint", 10)

		if placementPoint then
			for _, child in pairs(placementPoint:GetChildren()) do
				if child:IsA("ProximityPrompt") then child:Destroy() end
			end

			-- E Key: Place/Replace
			local placePrompt = Instance.new("ProximityPrompt")
			placePrompt.Name = "PlacePrompt"
			placePrompt.ObjectText = "Display Stand #" .. index
			placePrompt.ActionText = "Place Held Fish"
			placePrompt.KeyboardKeyCode = Enum.KeyCode.E
			placePrompt.HoldDuration = 0.5
			placePrompt.MaxActivationDistance = 8 
			placePrompt.RequiresLineOfSight = false
			placePrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow 
			placePrompt.UIOffset = Vector2.new(0, 0)
			placePrompt.Parent = placementPoint

			-- F Key: Retrieve
			local retrievePrompt = Instance.new("ProximityPrompt")
			retrievePrompt.Name = "RetrievePrompt"
			retrievePrompt.ObjectText = "Display Stand #" .. index
			retrievePrompt.ActionText = "Retrieve This Fish"
			retrievePrompt.KeyboardKeyCode = Enum.KeyCode.F
			retrievePrompt.HoldDuration = 0.5
			retrievePrompt.MaxActivationDistance = 8 
			retrievePrompt.RequiresLineOfSight = false
			retrievePrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow 
			retrievePrompt.UIOffset = Vector2.new(0, -80) 
			retrievePrompt.Enabled = false 
			retrievePrompt.Parent = placementPoint

			local function updatePrompts()
				task.wait(0.1) 
				local displayFish = placementPoint:FindFirstChild("DisplayFish")
				local hasFish = (displayFish ~= nil)
				retrievePrompt.Enabled = hasFish
				if hasFish then
					placePrompt.ActionText = "Replace Displayed Fish"
				else
					placePrompt.ActionText = "Place Held Fish"
				end
			end

			placementPoint.ChildAdded:Connect(updatePrompts)
			placementPoint.ChildRemoved:Connect(updatePrompts)
			updatePrompts()

			placePrompt.Triggered:Connect(function()
				local character = player.Character
				if not character then return end
				local currentTool = character:FindFirstChildWhichIsA("Tool")

				if not currentTool then
					GuiModule.PopUpFailed("Please equip a fish first!")
					return
				end

				local fishData = getHeldFishData(currentTool)
				if not fishData then
					GuiModule.PopUpFailed("This fish cannot be identified")
					return 
				end

				local success, msg = placeFunc:InvokeServer(index)
				if success then
					if msg == "Swapped" then
						GuiModule.PopUpSuccess("Swap Successful!")
					else
						GuiModule.PopUpSuccess("Placement Successful!")
					end
					updatePrompts()
				else
					GuiModule.PopUpFailed(tostring(msg))
				end
			end)

			retrievePrompt.Triggered:Connect(function()
				local success, msg = retrieveFunc:InvokeServer(index)
				if success then
					GuiModule.PopUpSuccess("Retrieval Successful!")
				else
					GuiModule.PopUpFailed(tostring(msg))
				end
			end)
		end
	end
end

local function findMyBase()
	task.spawn(function()
		local attempts = 0
		while true do
			local tycoonsFolder = workspace:FindFirstChild("Tycoons")
			if tycoonsFolder then
				for _, base in pairs(tycoonsFolder:GetChildren()) do
					local ownerVal = base:FindFirstChild("# Owner") or base:FindFirstChild("Owner")
					if ownerVal and ownerVal:IsA("ValueBase") and tostring(ownerVal.Value) == tostring(player.UserId) then
						setupInteractions(base)
						return
					end
				end
			end
			attempts = attempts + 1
			task.wait(1) 
		end
	end)
end

findMyBase()