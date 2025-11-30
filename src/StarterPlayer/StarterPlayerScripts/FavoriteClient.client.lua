local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local fishingResources = ReplicatedStorage:WaitForChild("FishingResources")
local modules = fishingResources:WaitForChild("Modules")
local guiModule = require(modules:WaitForChild("GuiModule"))

local remotes = fishingResources:WaitForChild("Remotes")
local saveFavorites = remotes:WaitForChild("SaveFavorites")
local loadFavorites = remotes:WaitForChild("LoadFavorites")

local FAVORITE_ICON = "rbxassetid://12492678201"
local FAVORITE_COLOR_FAVORITED = Color3.fromRGB(255, 85, 127)
local DOUBLE_TAP_TIME = 0.5 -- Maximum time between taps for double-tap

_G.FavoritedFish = _G.FavoritedFish or {}

-- Double-tap tracking
local lastTapTime = {}
local tapCount = {}
local setupSlots = {} -- Track which slots we've already setup

local function isFishTool(tool)
	return tool:IsA("Tool") and tool:FindFirstChild("FishLocationId")
end

local function getUniqueFishId(tool)
	if not isFishTool(tool) then return nil end
	local locationId = tool:FindFirstChild("FishLocationId")
	if not locationId then return nil end
	return Player.UserId .. "_" .. tostring(locationId.Value) .. "_" .. tool.Name
end

local function saveFavoritesToServer()
	pcall(function()
		saveFavorites:FireServer(_G.FavoritedFish)
	end)
end

local function loadFavoritesFromServer()
	local success, data = pcall(function()
		return loadFavorites:InvokeServer()
	end)
	if success and type(data) == "table" then
		_G.FavoritedFish = data
	end
end

local function attachFavoriteButton(slotFrame)
	local btn = slotFrame:FindFirstChild("FavoriteButton")
	if btn then return btn end

	local heart = Instance.new("ImageLabel")
	heart.Name = "FavoriteButton"
	heart.BackgroundTransparency = 1
	heart.Image = FAVORITE_ICON
	heart.Size = UDim2.fromOffset(16, 16)
	heart.AnchorPoint = Vector2.new(1, 0)
	heart.Position = UDim2.new(1, -3, 0, 3)
	heart.ZIndex = 10
	heart.Visible = false
	heart.ImageColor3 = FAVORITE_COLOR_FAVORITED
	heart.Parent = slotFrame

	return heart
end

local function findToolByName(toolName)
	local tool = Player.Backpack:FindFirstChild(toolName)
	if not tool then
		tool = Player.Character and Player.Character:FindFirstChild(toolName)
	end
	return tool
end

local function updateSlotFavoriteDisplay(slotFrame)
	local btn = slotFrame:FindFirstChild("FavoriteButton")
	local toolNameLabel = slotFrame:FindFirstChild("ToolName")

	if not toolNameLabel or toolNameLabel.Text == "" then
		if btn then
			btn.Visible = false
		end
		return
	end

	local tool = findToolByName(toolNameLabel.Text)
	if tool and isFishTool(tool) then
		local uniqueId = getUniqueFishId(tool)
		if uniqueId and _G.FavoritedFish[uniqueId] then
			local button = attachFavoriteButton(slotFrame)
			button.Visible = true
			return
		end
	end

	if btn then
		btn.Visible = false
	end
end

local function toggleFavorite(slotFrame)
	local toolNameLabel = slotFrame:FindFirstChild("ToolName")
	if not toolNameLabel or toolNameLabel.Text == "" then
		return
	end

	local tool = findToolByName(toolNameLabel.Text)
	if not tool or not isFishTool(tool) then
		return
	end

	local uniqueId = getUniqueFishId(tool)
	if not uniqueId then
		return
	end

	local btn = attachFavoriteButton(slotFrame)
	local isFav = not _G.FavoritedFish[uniqueId]
	local fishName = tool.Name -- Get the actual fish name

	_G.FavoritedFish[uniqueId] = isFav or nil
	btn.Visible = isFav

	-- Show notification with fish name
	if isFav then
		guiModule.PopUpSuccess(fishName .. " has been favorited!")
	else
		guiModule.PopUpSuccess(fishName .. " has been unfavorited!")
	end

	saveFavoritesToServer()
end

local function setupSlot(slotFrame)
	-- Prevent duplicate setup
	local slotId = tostring(slotFrame)
	if setupSlots[slotId] then return end
	setupSlots[slotId] = true

	slotFrame.InputBegan:Connect(function(input, gp)
		if gp then return end

		-- Right-click support (PC)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			toggleFavorite(slotFrame)
			return
		end

		-- Double-tap support (Mobile & PC)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local currentTime = tick()

			-- Initialize tracking for this slot if it doesn't exist
			if not lastTapTime[slotId] then
				lastTapTime[slotId] = 0
				tapCount[slotId] = 0
			end

			local timeSinceLastTap = currentTime - lastTapTime[slotId]

			if timeSinceLastTap <= DOUBLE_TAP_TIME then
				tapCount[slotId] = tapCount[slotId] + 1

				-- Double-tap detected
				if tapCount[slotId] >= 2 then
					toggleFavorite(slotFrame)
					-- Reset counters
					tapCount[slotId] = 0
					lastTapTime[slotId] = 0
					return
				end
			else
				-- Reset if too much time has passed
				tapCount[slotId] = 1
			end

			lastTapTime[slotId] = currentTime

			-- Reset tap count after the double-tap window
			task.spawn(function()
				task.wait(DOUBLE_TAP_TIME + 0.1)
				if tick() - lastTapTime[slotId] >= DOUBLE_TAP_TIME then
					tapCount[slotId] = 0
				end
			end)
		end
	end)

	local toolNameLabel = slotFrame:FindFirstChild("ToolName")
	if toolNameLabel then
		toolNameLabel:GetPropertyChangedSignal("Text"):Connect(function()
			updateSlotFavoriteDisplay(slotFrame)
		end)
	end

	-- Clean up when slot is removed
	slotFrame.AncestryChanged:Connect(function()
		if not slotFrame.Parent then
			setupSlots[slotId] = nil
		end
	end)

	updateSlotFavoriteDisplay(slotFrame)
end

-- GENERIC FUNCTION: Find and setup all inventory slots
local function findAndSetupAllSlots(gui)
	local function recursiveSetup(parent)
		for _, child in pairs(parent:GetChildren()) do
			-- Check if this looks like an inventory slot
			if child:IsA("TextButton") and child:FindFirstChild("ToolName") then
				setupSlot(child)
			end

			-- Continue searching in children
			if child:IsA("GuiObject") and #child:GetChildren() > 0 then
				recursiveSetup(child)
			end
		end
	end

	recursiveSetup(gui)
end

-- GENERIC FUNCTION: Setup child added connections for dynamic slots
local function setupDynamicSlotDetection(gui)
	local function connectChildAdded(parent)
		parent.ChildAdded:Connect(function(child)
			task.wait(0.1) -- Small delay for slot to initialize

			-- If it's a slot, set it up
			if child:IsA("TextButton") and child:FindFirstChild("ToolName") then
				setupSlot(child)
			end

			-- If it's a container, connect to its children too
			if child:IsA("GuiObject") then
				connectChildAdded(child)
				findAndSetupAllSlots(child)
			end
		end)

		-- Also connect to existing children
		for _, existingChild in pairs(parent:GetChildren()) do
			if existingChild:IsA("GuiObject") then
				connectChildAdded(existingChild)
			end
		end
	end

	connectChildAdded(gui)
end

local function updateAllSlots()
	task.wait(0.1)

	-- Update all slots in PlayerGui
	for _, gui in pairs(PlayerGui:GetChildren()) do
		if gui:IsA("ScreenGui") then
			local function recursiveUpdate(parent)
				for _, child in pairs(parent:GetChildren()) do
					-- Update if this is a slot
					if child:IsA("TextButton") and child:FindFirstChild("ToolName") then
						updateSlotFavoriteDisplay(child)
					end

					-- Continue searching in children
					if child:IsA("GuiObject") and #child:GetChildren() > 0 then
						recursiveUpdate(child)
					end
				end
			end

			recursiveUpdate(gui)
		end
	end
end

task.spawn(function()
	loadFavoritesFromServer()

	-- Wait for BackpackGui to load
	local backpackGui = PlayerGui:WaitForChild("BackpackGui", 10)
	if backpackGui then
		-- Setup all existing slots
		findAndSetupAllSlots(backpackGui)

		-- Setup dynamic detection for new slots
		setupDynamicSlotDetection(backpackGui)
	end

	-- Also monitor other GUIs that might contain inventory slots
	PlayerGui.ChildAdded:Connect(function(gui)
		if gui:IsA("ScreenGui") then
			task.wait(0.5) -- Wait for GUI to initialize
			findAndSetupAllSlots(gui)
			setupDynamicSlotDetection(gui)
		end
	end)

	Player.Backpack.ChildAdded:Connect(updateAllSlots)
	Player.Backpack.ChildRemoved:Connect(updateAllSlots)

	if Player.Character then
		Player.Character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and isFishTool(child) then
				updateAllSlots()
			end
		end)
		Player.Character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				updateAllSlots()
			end
		end)
	end

	Player.CharacterAdded:Connect(function(character)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and isFishTool(child) then
				updateAllSlots()
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				updateAllSlots()
			end
		end)
	end)
end)