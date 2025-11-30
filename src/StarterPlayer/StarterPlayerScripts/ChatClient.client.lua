local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local fishingResources = ReplicatedStorage:WaitForChild("FishingResources")
local remotes = fishingResources:WaitForChild("Remotes")
local sendChatNotification = remotes:WaitForChild("SendChatNotification")

local RarityColors = {
	["Legendary"] = Color3.fromRGB(255, 215, 0),
	["Ultra Rare"] = Color3.fromRGB(255, 0, 255),
	["Epic"] = Color3.fromRGB(163, 53, 238),
	["Rare"] = Color3.fromRGB(0, 170, 255),
	["Uncommon"] = Color3.fromRGB(0, 255, 0),
	["Common"] = Color3.fromRGB(200, 200, 200),
	["Shiny"] = Color3.fromRGB(255, 215, 0),
	["Rainbow"] = Color3.fromRGB(255, 0, 255),
}

local function rgbToHex(color)
	return string.format("#%02X%02X%02X", 
		math.floor(color.R * 255), 
		math.floor(color.G * 255), 
		math.floor(color.B * 255)
	)
end

local function displayChatMessage(message, rarity)
	local messageColor = RarityColors[rarity] or Color3.fromRGB(255, 255, 0)

	local fishChannel = TextChatService:WaitForChild("FishNotifications", 30)

	if fishChannel then
		local hexColor = rgbToHex(messageColor)
		local formattedMessage = string.format('<font color="%s"><b>%s</b></font>', hexColor, message)

		local success, err = pcall(function()
			fishChannel:DisplaySystemMessage(formattedMessage)
		end)

		if success then
			return
		else
			warn("Failed to display message in FishNotifications channel:", err)
		end
	else
		warn("FishNotifications channel not found, falling back to legacy chat")
	end

	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = message,
			Color = messageColor,
			Font = Enum.Font.SourceSansBold,
			FontSize = Enum.FontSize.Size18
		})
	end)
end

sendChatNotification.OnClientEvent:Connect(function(message, rarity)
	if type(message) == "string" then
		displayChatMessage(message, rarity)
	else
		warn("Invalid message received:", message)
	end
end)