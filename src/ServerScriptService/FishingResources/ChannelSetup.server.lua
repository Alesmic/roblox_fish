local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local fishChannel = Instance.new("TextChannel")
fishChannel.Name = "FishNotifications"
fishChannel.Parent = TextChatService

fishChannel.ShouldDeliverCallback = function(message)
	return false
end

Players.PlayerAdded:Connect(function(player)
	task.wait(2)
	local success, err = pcall(function()
		fishChannel:AddUserAsync(player.UserId)
	end)
	if not success then
		warn("Failed to add player to FishNotifications channel:", err)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		task.wait(1)
		pcall(function()
			fishChannel:AddUserAsync(player.UserId)
		end)
	end)
end