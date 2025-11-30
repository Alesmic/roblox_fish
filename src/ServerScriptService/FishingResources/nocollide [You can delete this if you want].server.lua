-- Create a Collision Group
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local PLAYER_COLLISION_GROUP = "PlayerCollisionGroup"

-- Create the collision group if it doesn't exist
pcall(function()
	PhysicsService:RegisterCollisionGroup(PLAYER_COLLISION_GROUP)
end)

-- Ensure players in the group don't collide with each other
PhysicsService:CollisionGroupSetCollidable(PLAYER_COLLISION_GROUP, PLAYER_COLLISION_GROUP, false)

-- Function to set collision group for all parts in a character
local function setCollisionGroup(character)
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = PLAYER_COLLISION_GROUP
			
			--PhysicsService:SetPartCollisionGroup(part, PLAYER_COLLISION_GROUP)
		end
	end
end

-- When a player joins, set their character's collision group
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Wait for the character to load fully
		character:WaitForChild("HumanoidRootPart")
		setCollisionGroup(character)

		-- Update for any future parts added to the character
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = PLAYER_COLLISION_GROUP
				
				--PhysicsService:CollisionGroup(descendant, PLAYER_COLLISION_GROUP)
			end
		end)
	end)
end)
