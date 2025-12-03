local replicatedStorage = game:GetService("ReplicatedStorage")
local fishingResources = replicatedStorage:WaitForChild("FishingResources")
local modules = fishingResources:WaitForChild("Modules")
local guiModule = require(modules:WaitForChild("GuiModule"))
local remotes = fishingResources:WaitForChild("Remotes")
local sellFish = remotes:WaitForChild("SellFish")
local players = game:GetService("Players")
local plr = players.LocalPlayer

local module = {
	{Say = "Hey, what would you like?"}
}

local function formatMoney(amount)
	if amount >= 1000000000000000 then 
		return string.format("%.1fQD", amount / 1000000000000000):gsub("%.0QD", "QD")
	elseif amount >= 1000000000000 then 
		return string.format("%.1fT", amount / 1000000000000):gsub("%.0T", "T")
	elseif amount >= 1000000 then 
		return string.format("%.1fM", amount / 1000000):gsub("%.0M", "M")
	elseif amount >= 1000 then 
		return string.format("%.1fK", amount / 1000):gsub("%.0K", "K")
	else
		return tostring(amount):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	end
end

local function getCurrentCash()
	local cashGui = plr.PlayerGui:FindFirstChild("CashGUI")
	if cashGui and cashGui:FindFirstChild("Frame") and cashGui.Frame:FindFirstChild("TextLabel") then
		local cashText = cashGui.Frame.TextLabel.Text
		cashText = cashText:gsub("%$", ""):gsub(",", ""):gsub("%s", "")
		local number, suffix = cashText:match("([%d%.]+)(%a*)")
		number = tonumber(number) or 0

		if suffix == "K" then number = number * 1000
		elseif suffix == "M" then number = number * 1000000
		elseif suffix == "T" then number = number * 1000000000000
		elseif suffix == "QD" then number = number * 1000000000000000
		end

		return math.floor(number)
	end
	return 0
end

local function getFishName(tool)
	if tool and tool:IsA("Tool") then
		return tool.Name
	end
	return "Fish"
end

local function getMultiplierFromName(fishName)
	local hasRainbow = fishName:find("%[Rainbow%]")
	local hasShiny = fishName:find("%[Shiny%]")
	local hasGolden = fishName:find("%[Golden%]")

	local multiplier = 1
	local effects = {}

	if hasGolden then
		multiplier = multiplier * 5
		table.insert(effects, "5x Golden")
	end
	if hasRainbow then
		multiplier = multiplier * 3
		table.insert(effects, "3x Rainbow")
	end
	if hasShiny then
		multiplier = multiplier * 2
		table.insert(effects, "2x Shiny")
	end

	if #effects > 1 then
		multiplier = multiplier * 1.5
		table.insert(effects, "1.5x Combo")
	end

	if #effects > 0 then
		return " (" .. table.concat(effects, " + ") .. ")"
	end

	return ""
end

local function countSellableFish()
	local count = 0
	local backpack = plr:FindFirstChild("Backpack")
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:FindFirstChild("FishLocationId") then
				count = count + 1
			end
		end
	end
	return count
end

module.AnswerFunctions = {
	["1"] = function() 
		local currentCash = getCurrentCash()
		local fishCount = countSellableFish()

		local result = sellFish:InvokeServer(false) 
		if result and type(result) == "table" then
			local newCash = result.newCash
			local skippedFavorites = result.skippedFavorites or 0

			if newCash then
				local amountEarned = newCash - currentCash

				plr.PlayerGui.CashGUI.Frame.TextLabel.Text = "$" .. formatMoney(newCash)

				if amountEarned > 0 then
					local soldCount = fishCount - skippedFavorites
					if soldCount > 1 then
						guiModule.PopUpSuccess("Sold " .. soldCount .. " fish for $" .. formatMoney(amountEarned) .. "!")
					else
						guiModule.PopUpSuccess("Sold 1 fish for $" .. formatMoney(amountEarned) .. "!")
					end

					if skippedFavorites > 0 then
						task.wait(0.5)
						guiModule.PopUp("(" .. skippedFavorites .. " favorites kept)")
					end
				else
					if skippedFavorites > 0 then
						guiModule.PopUpFailed("No fish sold - all " .. skippedFavorites .. " fish are favorited!")
					else
						guiModule.PopUpFailed("No fish to sell!")
					end
				end
			else
				if skippedFavorites > 0 then
					guiModule.PopUpFailed("No fish sold - all " .. skippedFavorites .. " fish are favorited!")
				else
					guiModule.PopUpFailed("No fish to sell!")
				end
			end
		elseif result and type(result) == "number" then
			local amountEarned = result - currentCash
			plr.PlayerGui.CashGUI.Frame.TextLabel.Text = "$" .. formatMoney(result)
			if amountEarned > 0 then
				guiModule.PopUpSuccess("Fish sold for $" .. formatMoney(amountEarned) .. "!")
			else
				guiModule.PopUpSuccess("Fish sold successfully!")
			end
		else
			guiModule.PopUpFailed("No fish to sell!")
		end
	end,

	["2"] = function() 
		local fishInHand = nil
		if plr.Character then
			fishInHand = plr.Character:FindFirstChildOfClass("Tool")
		end

		if not fishInHand or not fishInHand:FindFirstChild("FishLocationId") then
			guiModule.PopUpFailed("No fish in hand!")
			return
		end

		local fishNameToSell = getFishName(fishInHand)
		local multiplierText = getMultiplierFromName(fishNameToSell)
		local currentCash = getCurrentCash()

		local result = sellFish:InvokeServer(true) 
		if result and type(result) == "table" then
			local newCash = result.newCash
			local skippedFavorites = result.skippedFavorites or 0

			if newCash then
				local amountEarned = newCash - currentCash

				plr.PlayerGui.CashGUI.Frame.TextLabel.Text = "$" .. formatMoney(newCash)

				if amountEarned > 0 then
					guiModule.PopUpSuccess("Sold " .. fishNameToSell .. " for $" .. formatMoney(amountEarned) .. "!" .. multiplierText)
				end
			else
				if skippedFavorites > 0 then
					guiModule.PopUpFailed("Cannot sell " .. fishNameToSell .. " - it's favorited!")
				else
					guiModule.PopUpFailed("Failed to sell " .. fishNameToSell .. "!")
				end
			end
		elseif result and type(result) == "number" then
			local amountEarned = result - currentCash
			plr.PlayerGui.CashGUI.Frame.TextLabel.Text = "$" .. formatMoney(result)
			if amountEarned > 0 then
				guiModule.PopUpSuccess("Sold " .. fishNameToSell .. " for $" .. formatMoney(amountEarned) .. "!" .. multiplierText)
			else
				guiModule.PopUpSuccess("Sold " .. fishNameToSell .. "!")
			end
		else
			guiModule.PopUpFailed("Failed to sell fish!")
		end
	end,

	["3"] = function() 
		guiModule.PopUpSuccess("See you later!")
	end,

	["4"] = function() 
		local fishingShopGui = plr.PlayerGui:WaitForChild("FishingShopGui")
		local shopFrame = fishingShopGui:WaitForChild("ShopFrame")
		shopFrame.Visible = true

		local remotes = fishingResources:WaitForChild("Remotes")
		remotes:WaitForChild("UpdateUI"):FireServer()

		guiModule.PopUpSuccess("Shop opened!")
	end
}

return module