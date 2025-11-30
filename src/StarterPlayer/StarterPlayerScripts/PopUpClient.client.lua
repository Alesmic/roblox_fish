local replicatedStorage = game:GetService("ReplicatedStorage")

local fishingResources = replicatedStorage:WaitForChild("FishingResources")
local modules = fishingResources:WaitForChild("Modules")
local PopUpModule = require(modules:WaitForChild("GuiModule"))
local remotes = fishingResources:WaitForChild("Remotes")
local popupRemote = remotes:WaitForChild("PopupNotification")

popupRemote.OnClientEvent:Connect(function(message, messageType)

	messageType = messageType or "Success"

	if messageType == "Success" then
		PopUpModule.PopUpSuccess("[Admin] " .. message)
	elseif messageType == "Failed" then
		PopUpModule.PopUpFailed("[Admin] " .. message)
	else

		PopUpModule.PopUp("[Admin] " .. message)
	end
end)