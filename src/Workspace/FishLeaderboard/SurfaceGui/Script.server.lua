local statsName = "FishCaught"
local maxItems = 100
local minValueDisplay = 1
local maxValueDisplay = 10e15
local abbreviateValue = true
local updateEvery = 60

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local DataStore = DataStoreService:GetOrderedDataStore("FishCaughtLeaderboard" .. statsName)

local Frame = script.Parent.Frame
local Contents = Frame.Contents
local Template = script.objTemplate

local COLORS = {
	Default = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(255, 215, 0),
	Silver = Color3.fromRGB(192, 192, 192),
	Bronze = Color3.fromRGB(205, 127, 50)
}

local function formatWithCommas(num)
	local formatted = tostring(num):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return formatted:sub(1, 1) == "," and formatted:sub(2) or formatted
end

local function getPlayerStat(player, statName)
	local statsValue

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		statsValue = leaderstats:FindFirstChild(statName)
		if statsValue then
			return statsValue
		end
	end

	statsValue = player:FindFirstChild(statName)
	if statsValue then
		return statsValue
	end

	return nil
end

local function getItems()
	local data = DataStore:GetSortedAsync(false, maxItems, minValueDisplay, maxValueDisplay)
	local topPage = data:GetCurrentPage()

	Contents.Items.Nothing.Visible = #topPage == 0 and true or false

	for position, v in ipairs(topPage) do
		local userId = v.key
		local value = v.value
		local username = "[Not Available]"
		local color = COLORS.Default

		local success, err = pcall(function()
			username = Players:GetNameFromUserIdAsync(userId)
		end)

		if position == 1 then
			color = COLORS.Gold
		elseif position == 2 then
			color = COLORS.Silver
		elseif position == 3 then
			color = COLORS.Bronze
		end

		local item = Template:Clone()
		item.Name = username
		item.LayoutOrder = position
		item.Values.Number.TextColor3 = color
		item.Values.Username.TextColor3 = color
		item.Values.Number.Text = position
		item.Values.Username.Text = "" .. username
		item.ProfilePicture.Image = "https://www.roblox.com/bust-thumbnail/image?userId=".. userId .."&width=420&height=420&format=png"
		item.Values.Value.Text = "🎣" .. formatWithCommas(value)
		item.Parent = Contents.Items
	end
end

while true do

	for _, player in pairs(Players:GetPlayers()) do
		local statsValue = getPlayerStat(player, statsName)

		if statsValue and statsValue.Value then

			local currentValue = tonumber(statsValue.Value)
			if currentValue and currentValue >= 0 then
				local success, error = pcall(function()
					DataStore:UpdateAsync(player.UserId, function(oldValue)

						if oldValue ~= currentValue then
							return currentValue
						end
						return oldValue
					end)
				end)

				if not success then
					warn("Failed to update " .. player.Name .. "'s data: " .. tostring(error))
				end
			end
		else

		end
	end

	for _, item in pairs(Contents.Items:GetChildren()) do
		if item:IsA("Frame") then
			item:Destroy()
		end
	end

	local success, error = pcall(getItems)
	if not success then
		warn("Failed to get leaderboard items: " .. tostring(error))
	end

	task.wait(updateEvery)
end