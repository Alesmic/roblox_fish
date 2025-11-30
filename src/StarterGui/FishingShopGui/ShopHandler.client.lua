local contentProvider = game:GetService("ContentProvider")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local marketplaceService = game:GetService("MarketplaceService")

local function formatCurrency(amount)
	if amount < 1000 then
		return "$ " .. tostring(amount)
	elseif amount < 1000000 then
		return "$ " .. string.format("%.1f", amount / 1000) .. "K"
	elseif amount < 1000000000 then
		return "$ " .. string.format("%.1f", amount / 1000000) .. "M"
	elseif amount < 1000000000000 then
		return "$ " .. string.format("%.1f", amount / 1000000000) .. "B"
	else
		return "$ " .. string.format("%.1f", amount / 1000000000000) .. "T"
	end
end

local fishingResources = replicatedStorage:WaitForChild("FishingResources")
local remotes = fishingResources:WaitForChild("Remotes")
local updateUI = remotes:WaitForChild("UpdateUI")
local getPlayerData = remotes:WaitForChild("GetPlayerData", 10)

local plr = players.LocalPlayer
local shopGui = script.Parent
local shopFrame = shopGui:WaitForChild("ShopFrame")
local rodGrid = shopFrame:WaitForChild("RodGrid")
local template = rodGrid:WaitForChild("Template")

repeat
	task.wait(1)
until #fishingResources:WaitForChild("Animations"):GetChildren() > 4

contentProvider:PreloadAsync(fishingResources:WaitForChild("Animations"):GetChildren())

local modules = fishingResources:WaitForChild("Modules")
local Config = require(fishingResources:WaitForChild("Configuration"))
local guiModule = require(modules:WaitForChild("GuiModule"))

local rodModels = fishingResources:WaitForChild("Models"):WaitForChild("Rods")
local rods = Config.Rods
local admins = Config.Admins

local currentCash = 0
local currentRodsStats = {}
local buttonCooldowns = {}
local BUTTON_COOLDOWN_TIME = 3

local function isPlayerAdmin()
	for _, adminId in pairs(admins) do
		if adminId == plr.UserId then
			return true
		end
	end
	return false
end

local function doesPlayerOwnGamepass(gamepassId)
	local success, ownsGamepass = pcall(function()
		return marketplaceService:UserOwnsGamePassAsync(plr.UserId, gamepassId)
	end)

	if success then
		return ownsGamepass
	end
	return false
end

local function getAvailableRods()
	local availableRods = {}
	for rodId, rodData in pairs(rods) do
		if type(rodId) == "number" then
			if not rodData.AdminOnly then
				availableRods[rodId] = rodData
			end
		end
	end
	return availableRods
end

local function getCurrentCash()
	local leaderstats = plr:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then
			return cash.Value
		end
	end
	return currentCash
end

local function setRodImage(imageLabel, rodInfo)
	if rodInfo.ImageId then
		imageLabel.Image = rodInfo.ImageId
	else
		imageLabel.Image = ""
		warn("No ImageId found for rod: " .. (rodInfo.RodName or "Unknown"))
	end

	imageLabel.ScaleType = Enum.ScaleType.Fit
	imageLabel.BackgroundTransparency = 1
end

local function isRodCurrentlyEquipped(rodId)
	local allRods = rods
	local rodInfo = allRods[rodId]
	if not rodInfo then return false end

	local rodName = rodInfo.RodName

	if plr.Character then
		for _, tool in pairs(plr.Character:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == rodName then
				return true
			end
		end
	end

	return false
end

local function doesPlayerHaveRod(rodId)
	local allRods = rods
	local rodInfo = allRods[rodId]
	if not rodInfo then return false end

	local rodName = rodInfo.RodName

	if rodInfo.AdminOnly and isPlayerAdmin() then
		return true
	end

	if rodInfo.Gamepass and rodInfo.GamepassId then
		if doesPlayerOwnGamepass(rodInfo.GamepassId) then
			return true
		end
	end

	local backpack = plr:FindFirstChild("Backpack")
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == rodName then
				return true
			end
		end
	end

	if plr.Character then
		for _, tool in pairs(plr.Character:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == rodName then
				return true
			end
		end
	end

	return false
end

local function promptGamepassPurchase(gamepassId, rodInfo)
	local success, result = pcall(function()
		marketplaceService:PromptGamePassPurchase(plr, gamepassId)
	end)

	if not success then
		guiModule.PopUpFailed("Failed to open gamepass purchase: " .. tostring(result))
	end
end

local function updateBuyButton(button, rodId, isOwned, serverEquipped)
	local availableRods = getAvailableRods()
	local rodInfo = availableRods[rodId]

	if not rodInfo then
		button.Visible = false
		return
	end

	local buttonKey = "rod_" .. tostring(rodId)
	if buttonCooldowns[buttonKey] and buttonCooldowns[buttonKey] > tick() then
		local timeLeft = math.ceil(buttonCooldowns[buttonKey] - tick())
		button.Text = "Please wait (" .. timeLeft .. ")"
		button.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
		button.TextColor3 = Color3.new(0.8, 0.8, 0.8)
		return
	end

	local hasRodFromServer = currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[rodId]
	local actuallyHasRod = hasRodFromServer or doesPlayerHaveRod(rodId)
	local actuallyEquipped = (currentRodsStats.Equipped == rodId) or isRodCurrentlyEquipped(rodId)

	if serverEquipped or actuallyEquipped then
		button.Text = "Unequip"
		button.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
		button.TextColor3 = Color3.new(1, 1, 1)
	elseif actuallyHasRod or isOwned then
		button.Text = "Equip"
		button.BackgroundColor3 = Color3.new(0.2, 0.6, 1)
		button.TextColor3 = Color3.new(1, 1, 1)
	else
		if rodInfo.Currency then
			button.Text = "Buy (" .. formatCurrency(rodInfo.Cost) .. ")"
			button.BackgroundColor3 = Color3.new(1, 0.6, 0.2)
			button.TextColor3 = Color3.new(1, 1, 1)
		elseif rodInfo.Gamepass and rodInfo.GamepassId then
			button.Text = "Buy (R$ " .. tostring(rodInfo.GamepassPrice or 0) .. ")"
			button.BackgroundColor3 = Color3.new(0.2, 0.8, 0.2)
			button.TextColor3 = Color3.new(1, 1, 1)
		else
			button.Text = "Unavailable"
			button.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
			button.TextColor3 = Color3.new(0.8, 0.8, 0.8)
		end
	end
end

local function startButtonCooldown(rodId)
	local buttonKey = "rod_" .. tostring(rodId)
	buttonCooldowns[buttonKey] = tick() + BUTTON_COOLDOWN_TIME

	task.spawn(function()
		while buttonCooldowns[buttonKey] and buttonCooldowns[buttonKey] > tick() do
			task.wait(1)
			local availableRods = getAvailableRods()
			for _, item in pairs(rodGrid:GetChildren()) do
				if item ~= template and item:IsA("Frame") and item.Name:match("Rod") then
					local itemRodIdStr = item.Name:match("Rod(.+)")
					local itemRodId = tonumber(itemRodIdStr) or itemRodIdStr
					if itemRodId == rodId and availableRods[itemRodId] then
						updateBuyButton(item.BuyButton, itemRodId, 
							currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[itemRodId], 
							currentRodsStats.Equipped == itemRodId)
					end
				end
			end
		end

		local availableRods = getAvailableRods()
		for _, item in pairs(rodGrid:GetChildren()) do
			if item ~= template and item:IsA("Frame") and item.Name:match("Rod") then
				local itemRodIdStr = item.Name:match("Rod(.+)")
				local itemRodId = tonumber(itemRodIdStr) or itemRodIdStr
				if itemRodId == rodId and availableRods[itemRodId] then
					updateBuyButton(item.BuyButton, itemRodId, 
						currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[itemRodId], 
						currentRodsStats.Equipped == itemRodId)
				end
			end
		end
	end)
end

local function initializeShop()
	template.Visible = false

	for _, child in pairs(rodGrid:GetChildren()) do
		if child ~= template and child:IsA("Frame") then
			child:Destroy()
		end
	end

	local availableRods = getAvailableRods()

	for rodId, rodInfo in pairs(availableRods) do
		local rodItem = template:Clone()
		rodItem.Name = "Rod" .. tostring(rodId)
		rodItem.Visible = true
		rodItem.Parent = rodGrid

		rodItem.RodName.Text = rodInfo.RodName

		if rodInfo.Currency then
			rodItem.Price.Text = formatCurrency(rodInfo.Cost)
			rodItem.Price.TextColor3 = Color3.new(1, 1, 1)
		elseif rodInfo.Gamepass and rodInfo.GamepassId then
			rodItem.Price.Text = "R$ " .. tostring(rodInfo.GamepassPrice or 0)
			rodItem.Price.TextColor3 = Color3.new(0.2, 1, 0.2)
		else
			rodItem.Price.Text = "UNAVAILABLE"
			rodItem.Price.TextColor3 = Color3.new(0.8, 0.8, 0.8)
		end

		local stats = rodItem.Stats
		stats.Control.Text = "Control: " .. rodInfo.Control
		stats.LureSpeed.Text = "Lure Speed: " .. rodInfo.LureSpeed
		stats.Luck.Text = "Luck: " .. rodInfo.Luck
		stats.Strength.Text = "Strength: " .. rodInfo.Strength
		stats.Resillience.Text = "Resilience: " .. rodInfo.Resilience
		stats.MaxKg.Text = "Max Kg: " .. rodInfo.MaxKg

		local imageLabel = rodItem.RodImage:FindFirstChild("ImageLabel")
		if imageLabel then
			setRodImage(imageLabel, rodInfo)
		else
			warn("ImageLabel not found in RodImage for rod: " .. rodInfo.RodName)
		end

		local buyButton = rodItem.BuyButton
		updateBuyButton(buyButton, rodId, 
			currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[rodId], 
			currentRodsStats.Equipped == rodId)

		buyButton.MouseButton1Click:Connect(function()
			local buttonKey = "rod_" .. tostring(rodId)
			if buttonCooldowns[buttonKey] and buttonCooldowns[buttonKey] > tick() then
				return
			end

			startButtonCooldown(rodId)

			local hasRodFromServer = currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[rodId]
			local rodInInventory = doesPlayerHaveRod(rodId)
			local isOwned = hasRodFromServer or rodInInventory

			if currentRodsStats.Equipped == rodId then
				local success = remotes:WaitForChild("UseRod"):InvokeServer(rodId)
				if success then
					currentRodsStats = success
					for _, item in pairs(rodGrid:GetChildren()) do
						if item ~= template and item:IsA("Frame") and item.Name:match("Rod") then
							local itemRodIdStr = item.Name:match("Rod(.+)")
							local itemRodId = tonumber(itemRodIdStr) or itemRodIdStr
							if itemRodId and availableRods[itemRodId] then
								updateBuyButton(item.BuyButton, itemRodId, 
									currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[itemRodId], 
									currentRodsStats.Equipped == itemRodId)
							end
						end
					end
					guiModule.PopUpSuccess("Rod unequipped!")
				else
					guiModule.PopUpFailed("Failed to unequip rod!")
				end

			elseif isOwned then
				local success = remotes:WaitForChild("UseRod"):InvokeServer(rodId)
				if success then
					currentRodsStats = success
					for _, item in pairs(rodGrid:GetChildren()) do
						if item ~= template and item:IsA("Frame") and item.Name:match("Rod") then
							local itemRodIdStr = item.Name:match("Rod(.+)")
							local itemRodId = tonumber(itemRodIdStr) or itemRodIdStr
							if itemRodId and availableRods[itemRodId] then
								updateBuyButton(item.BuyButton, itemRodId, 
									currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[itemRodId], 
									currentRodsStats.Equipped == itemRodId)
							end
						end
					end
					guiModule.PopUpSuccess("Equipped " .. rodInfo.RodName .. "!")
				else
					guiModule.PopUpFailed("Failed to equip rod!")
				end

			else
				if rodInfo.Currency then
					local playerCash = getCurrentCash()
					if playerCash >= rodInfo.Cost then
						local success = remotes:WaitForChild("UseRod"):InvokeServer(rodId)
						if success then
							currentRodsStats = success
							currentCash = playerCash - rodInfo.Cost

							local cashGUI = plr.PlayerGui:FindFirstChild("CashGUI")
							if cashGUI and cashGUI:FindFirstChild("Frame") and cashGUI.Frame:FindFirstChild("TextLabel") then
								cashGUI.Frame.TextLabel.Text = formatCurrency(currentCash)
							end

							for _, item in pairs(rodGrid:GetChildren()) do
								if item ~= template and item:IsA("Frame") and item.Name:match("Rod") then
									local itemRodIdStr = item.Name:match("Rod(.+)")
									local itemRodId = tonumber(itemRodIdStr) or itemRodIdStr
									if itemRodId and availableRods[itemRodId] then
										updateBuyButton(item.BuyButton, itemRodId, 
											currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[itemRodId], 
											currentRodsStats.Equipped == itemRodId)
									end
								end
							end

							guiModule.PopUpSuccess("Purchased " .. rodInfo.RodName .. " for " .. formatCurrency(rodInfo.Cost) .. "!")
						else
							guiModule.PopUpFailed("Purchase failed!")
						end
					else
						local needed = rodInfo.Cost - playerCash
						guiModule.PopUpFailed("Insufficient cash! You need " .. formatCurrency(needed) .. " more.")
					end

				elseif rodInfo.Gamepass and rodInfo.GamepassId then
					promptGamepassPurchase(rodInfo.GamepassId, rodInfo)

				else
					guiModule.PopUpFailed("This rod is not available for purchase!")
				end
			end
		end)
	end
end

marketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
	if player == plr and wasPurchased then
		local availableRods = getAvailableRods()
		for rodId, rodInfo in pairs(availableRods) do
			if rodInfo.GamepassId == gamepassId then

				task.spawn(function()
					task.wait(1) 

					local success, result = pcall(function()
						return remotes:WaitForChild("UseRod"):InvokeServer(rodId)
					end)

					if success and result then
						currentRodsStats = result
						guiModule.PopUpSuccess("Successfully purchased and equipped " .. rodInfo.RodName .. "!")
					else
						guiModule.PopUpSuccess("Successfully purchased " .. rodInfo.RodName .. "! Equip it to use.")
					end

					task.wait(0.5)
					for _, item in pairs(rodGrid:GetChildren()) do
						if item ~= template and item:IsA("Frame") and item.Name:match("Rod") then
							local itemRodIdStr = item.Name:match("Rod(.+)")
							local itemRodId = tonumber(itemRodIdStr) or itemRodIdStr
							if itemRodId and availableRods[itemRodId] then
								updateBuyButton(item.BuyButton, itemRodId, 
									currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[itemRodId], 
									currentRodsStats.Equipped == itemRodId)
							end
						end
					end
				end)
				break
			end
		end
	end
end)

local function waitForPlayerDataReady()
	local leaderstats = plr:WaitForChild("leaderstats", 30)
	if not leaderstats then
		return false
	end

	local cash = leaderstats:WaitForChild("Cash", 10)
	if not cash then
		return false
	end

	local backpack = plr:WaitForChild("Backpack", 10)
	if not backpack then
		return false
	end

	return true
end

task.spawn(function()
	repeat 
		task.wait(1) 
	until plr.PlayerGui:FindFirstChild("FishingShopGui")

	if not waitForPlayerDataReady() then
		return
	end

	task.wait(8)

	local initialData = nil

	for attempt = 1, 10 do
		local success, result = pcall(function()
			return getPlayerData:InvokeServer()
		end)

		if success and result then
			initialData = result
			break
		else
			if attempt <= 5 then
				task.wait(3)
			else
				task.wait(5)
			end
		end
	end

	if initialData then
		currentCash = initialData.Cash or 0
		currentRodsStats = {
			Equipped = initialData.Equipped,
			OwnedRods = initialData.OwnedRods or {}
		}

		local cashGUI = plr.PlayerGui:FindFirstChild("CashGUI")
		if cashGUI and cashGUI:FindFirstChild("Frame") and cashGUI.Frame:FindFirstChild("TextLabel") then
			cashGUI.Frame.TextLabel.Text = formatCurrency(currentCash)
		end
	else
		currentCash = getCurrentCash()
		currentRodsStats = {
			Equipped = 1,
			OwnedRods = {[1] = true}
		}

		local cashGUI = plr.PlayerGui:FindFirstChild("CashGUI")
		if cashGUI and cashGUI:FindFirstChild("Frame") and cashGUI.Frame:FindFirstChild("TextLabel") then
			cashGUI.Frame.TextLabel.Text = formatCurrency(currentCash)
		end
	end

	initializeShop()

	local function updateAllButtons()
		local availableRods = getAvailableRods()
		for _, item in pairs(rodGrid:GetChildren()) do
			if item ~= template and item:IsA("Frame") and item.Name:match("Rod") then
				local itemRodIdStr = item.Name:match("Rod(.+)")
				local itemRodId = tonumber(itemRodIdStr) or itemRodIdStr
				if itemRodId and availableRods[itemRodId] then
					updateBuyButton(item.BuyButton, itemRodId, 
						currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[itemRodId], 
						currentRodsStats.Equipped == itemRodId)
				end
			end
		end
	end

	local function connectBackpackEvents()
		local backpack = plr:FindFirstChild("Backpack")
		if backpack then
			backpack.ChildAdded:Connect(function(child)
				task.wait(0.3)
				updateAllButtons()
			end)
			backpack.ChildRemoved:Connect(function(child)
				task.wait(0.3)
				updateAllButtons()
			end)
		end
	end

	connectBackpackEvents()

	plr.ChildAdded:Connect(function(child)
		if child.Name == "Backpack" then
			task.wait(1)
			connectBackpackEvents()
		end
	end)

	plr.CharacterAdded:Connect(function(character)
		task.wait(2)

		character.ChildAdded:Connect(function(child)
			task.wait(0.3)
			updateAllButtons()
		end)
		character.ChildRemoved:Connect(function(child)
			task.wait(0.3)
			updateAllButtons()
		end)

		task.wait(1)
		connectBackpackEvents()
		updateAllButtons()
	end)

	if plr.Character then
		plr.Character.ChildAdded:Connect(function(child)
			task.wait(0.3)
			updateAllButtons()
		end)
		plr.Character.ChildRemoved:Connect(function(child)
			task.wait(0.3)
			updateAllButtons()
		end)
	end

	task.spawn(function()
		local lastBackpackCount = 0
		local lastCharacterCount = 0

		while task.wait(2) do
			local currentBackpackCount = 0
			local currentCharacterCount = 0

			local backpack = plr:FindFirstChild("Backpack")
			if backpack then
				for _, item in pairs(backpack:GetChildren()) do
					if item:IsA("Tool") then
						currentBackpackCount = currentBackpackCount + 1
					end
				end
			end

			if plr.Character then
				for _, item in pairs(plr.Character:GetChildren()) do
					if item:IsA("Tool") then
						currentCharacterCount = currentCharacterCount + 1
					end
				end
			end

			if currentBackpackCount ~= lastBackpackCount or currentCharacterCount ~= lastCharacterCount then
				lastBackpackCount = currentBackpackCount
				lastCharacterCount = currentCharacterCount
				updateAllButtons()
			end
		end
	end)

	task.spawn(function()
		while task.wait(5) do
			local success, serverData = pcall(function()
				return getPlayerData:InvokeServer()
			end)

			if success and serverData then
				currentCash = serverData.Cash or currentCash
				if serverData.OwnedRods then
					currentRodsStats.OwnedRods = serverData.OwnedRods
				end
				if serverData.Equipped then
					currentRodsStats.Equipped = serverData.Equipped
				end

				if shopFrame.Visible then
					local availableRods = getAvailableRods()
					for _, item in pairs(rodGrid:GetChildren()) do
						if item ~= template and item:IsA("Frame") and item.Name:match("Rod") then
							local itemRodIdStr = item.Name:match("Rod(.+)")
							local itemRodId = tonumber(itemRodIdStr) or itemRodIdStr
							if itemRodId and availableRods[itemRodId] then
								updateBuyButton(item.BuyButton, itemRodId, 
									currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[itemRodId], 
									currentRodsStats.Equipped == itemRodId)
							end
						end
					end
				end
			end
		end
	end)

	local function onLeaderstatsChanged()
		local leaderstats = plr:FindFirstChild("leaderstats")
		if leaderstats then
			local cash = leaderstats:FindFirstChild("Cash")
			if cash then
				local cashGUI = plr.PlayerGui:FindFirstChild("CashGUI")
				if cashGUI and cashGUI:FindFirstChild("Frame") and cashGUI.Frame:FindFirstChild("TextLabel") then
					cashGUI.Frame.TextLabel.Text = formatCurrency(cash.Value)
				end
				currentCash = cash.Value
			end
		end
	end

	plr.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			child.ChildAdded:Connect(function(stat)
				if stat.Name == "Cash" then
					stat.Changed:Connect(onLeaderstatsChanged)
					onLeaderstatsChanged()
				end
			end)

			local cash = child:FindFirstChild("Cash")
			if cash then
				cash.Changed:Connect(onLeaderstatsChanged)
				onLeaderstatsChanged()
			end
		end
	end)

	local existingLeaderstats = plr:FindFirstChild("leaderstats")
	if existingLeaderstats then
		local cash = existingLeaderstats:FindFirstChild("Cash")
		if cash then
			cash.Changed:Connect(onLeaderstatsChanged)
			onLeaderstatsChanged()
		end
	end
end)

local closeButton = shopFrame:FindFirstChild("CloseButton")
if closeButton then
	closeButton.MouseButton1Click:Connect(function()
		shopFrame.Visible = false
	end)
end

updateUI.OnClientEvent:Connect(function(cash, rodstats)
	currentCash = cash

	local cashGUI = plr.PlayerGui:FindFirstChild("CashGUI")
	if cashGUI and cashGUI:FindFirstChild("Frame") and cashGUI.Frame:FindFirstChild("TextLabel") then
		cashGUI.Frame.TextLabel.Text = formatCurrency(cash)
	end

	if rodstats then
		currentRodsStats = rodstats

		local availableRods = getAvailableRods()
		for _, item in pairs(rodGrid:GetChildren()) do
			if item ~= template and item:IsA("Frame") and item.Name:match("Rod") then
				local itemRodIdStr = item.Name:match("Rod(.+)")
				local itemRodId = tonumber(itemRodIdStr) or itemRodIdStr
				if itemRodId and availableRods[itemRodId] then
					updateBuyButton(item.BuyButton, itemRodId, 
						currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[itemRodId], 
						currentRodsStats.Equipped == itemRodId)
				end
			end
		end
	end
end)

_G.FishingShop = {
	initializeShop = initializeShop,
	updateShop = function()
		local availableRods = getAvailableRods()
		for _, item in pairs(rodGrid:GetChildren()) do
			if item ~= template and item:IsA("Frame") and item.Name:match("Rod") then
				local itemRodIdStr = item.Name:match("Rod(.+)")
				local itemRodId = tonumber(itemRodIdStr) or itemRodIdStr
				if itemRodId and availableRods[itemRodId] then
					updateBuyButton(item.BuyButton, itemRodId, 
						currentRodsStats.OwnedRods and currentRodsStats.OwnedRods[itemRodId], 
						currentRodsStats.Equipped == itemRodId)
				end
			end
		end
	end
}