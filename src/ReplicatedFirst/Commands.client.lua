local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local textChatService = game:GetService("TextChatService")

local fishingResources = replicatedStorage:WaitForChild("FishingResources")
local remotes = fishingResources:WaitForChild("Remotes")
local useCommandRemote = remotes:WaitForChild("UseCommand")
local Config = require(fishingResources:WaitForChild("Configuration"))

local plr = players.LocalPlayer
local prefix = "/"

local function isAdmin(userId)
	for _, adminId in pairs(Config.Admins) do
		if adminId == userId then
			return true
		end
	end
	return false
end

if not isAdmin(plr.UserId) then
	return
end

textChatService.SendingMessage:Connect(function(chat)
	local message = chat.Text

	if string.sub(message, 1, 1) ~= prefix then
		return
	end

	local args = string.split(message, " ")
	local command = string.sub(args[1], 2) 
	table.remove(args, 1) 

	local success, result = pcall(function()
		return useCommandRemote:InvokeServer(command, args)
	end)

	if not success then
		warn("Command error:", result)
	end
end)