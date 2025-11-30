local fishingResources = game.ReplicatedStorage:WaitForChild("FishingResources")
local rods = fishingResources:WaitForChild("Models"):WaitForChild("Rods"):GetChildren()
for i, v in pairs(rods) do
	script.Controller:Clone().Parent = v
end
