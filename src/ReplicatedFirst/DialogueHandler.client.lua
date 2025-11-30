local contentProvider = game:GetService("ContentProvider")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local fishingResources = replicatedStorage:WaitForChild("FishingResources")

local remotes = fishingResources:WaitForChild("Remotes")
local loadNewLeaderboard = remotes:WaitForChild("LoadNewLeaderboard")

local plr = players.LocalPlayer

repeat
	task.wait(1)
until #fishingResources:WaitForChild("Animations"):GetChildren() > 4

contentProvider:PreloadAsync(fishingResources:WaitForChild("Animations"):GetChildren())

local keeper = game.Workspace:WaitForChild("FranCheese")

local modules = fishingResources:WaitForChild("Modules")
local Config = require(fishingResources:WaitForChild("Configuration"))

local dialogue = require(keeper:WaitForChild("Dialogue"))
local guiModule = require(modules:WaitForChild("GuiModule"))

local admins = Config.Admins

local dialogueUI = plr.PlayerGui:WaitForChild("Dialogue")
local sayLabel = dialogueUI.Say.TextLabel
local answersFrame = dialogueUI.Answers

local fishingShopGui = plr.PlayerGui:WaitForChild("FishingShopGui")
local shopFrame = fishingShopGui:WaitForChild("ShopFrame")

local canOpen = true
local functions = {}
local currentTweens = {} 

local function isPlayerAdmin()
	for _, adminId in pairs(admins) do
		if adminId == plr.UserId then
			return true
		end
	end
	return false
end

local function cleanupAndReset()

	for _, tween in pairs(currentTweens) do
		if tween then
			tween:Cancel()
		end
	end
	currentTweens = {}

	for i, connection in pairs(functions) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	functions = {}

	dialogueUI.Enabled = false

	task.wait(0.1)
	canOpen = true
end

local function createTrackedTween(instance, tweenInfo, properties)
	local tween = tweenService:Create(instance, tweenInfo, properties)
	table.insert(currentTweens, tween)
	return tween
end

keeper:WaitForChild("ProximityPrompt").Triggered:Connect(function()
	if not canOpen then
		return
	end

	canOpen = false

	local success, errorMsg = pcall(function()
		sayLabel.Text = dialogue[1].Say

		dialogueUI:WaitForChild("Say").Position = UDim2.new(0.5, 0, -0.25, 0)
		dialogueUI:WaitForChild("Answers").Position = UDim2.new(0.5, 0, 1.3, 0)

		local sayTween = createTrackedTween(dialogueUI.Say, 
			TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), 
			{Position = UDim2.new(0.5, 0, 0.4, 0)})

		local answersTween = createTrackedTween(dialogueUI.Answers, 
			TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), 
			{Position = UDim2.new(0.5, 0, 0.65, 0)})

		sayTween:Play()
		answersTween:Play()

		dialogueUI.Enabled = true

		for _, frame in pairs(answersFrame:GetChildren()) do
			if frame.ClassName == "Frame" then
				local button = frame:FindFirstChild("TextButton")
				if not button then continue end

				local functionName = frame.Name

				local click = button.MouseButton1Click:Connect(function()

					canOpen = false

					local buttonSuccess, buttonError = pcall(function()
						if functionName == "4" then

							shopFrame.Visible = true

							if _G.FishingShop and _G.FishingShop.initializeShop then
								_G.FishingShop.initializeShop()
							end
						else

							if dialogue.AnswerFunctions and dialogue.AnswerFunctions[functionName] then
								dialogue.AnswerFunctions[functionName]()
							end
						end

						local closeSayTween = createTrackedTween(dialogueUI.Say, 
							TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), 
							{Position = UDim2.new(0.5, 0, -0.25, 0)})

						local closeAnswersTween = createTrackedTween(dialogueUI.Answers, 
							TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), 
							{Position = UDim2.new(0.5, 0, 1.3, 0)})

						closeSayTween:Play()
						closeAnswersTween:Play()

						task.spawn(function()
							task.wait(0.6) 
							cleanupAndReset()
						end)
					end)

					if not buttonSuccess then
						warn("Error in button click handler:", buttonError)
						cleanupAndReset() 
					end
				end)

				table.insert(functions, click)
			end
		end
	end)

	if not success then
		warn("Error in dialogue system:", errorMsg)
		cleanupAndReset() 
	end
end)

task.spawn(function()
	while true do
		task.wait(30)

		if dialogueUI.Enabled and not canOpen then
			warn("Dialogue system stuck - forcing cleanup")
			cleanupAndReset()
		end
	end
end)

local function loadPlayerCharacter(userId, setCFrame, anim)
	local success, model = pcall(function()
		return game.Players:CreateHumanoidModelFromUserId(userId)
	end)

	if success and model then
		local npcContainer = game.Workspace:FindFirstChild("NpcToDel")
		if npcContainer then
			model.Parent = npcContainer
			if model:FindFirstChild("HumanoidRootPart") then
				model.HumanoidRootPart.Anchored = true
				model:SetPrimaryPartCFrame(setCFrame)
			end
			model.Name = ""
			if model:FindFirstChild("Humanoid") and anim then
				model.Humanoid:LoadAnimation(anim):Play()
			end
		end
	else
		warn("Failed to load player character for userId:", userId)
	end
end

loadNewLeaderboard.OnClientEvent:Connect(function(newStats)
	local success, errorMsg = pcall(function()
		local npcContainer = game.Workspace:FindFirstChild("NpcToDel")
		if npcContainer then
			for i, v in pairs(npcContainer:GetChildren()) do
				v:Destroy()
			end
		end

		for _, playerStats in pairs(newStats) do
			local leaderboardName = playerStats[2] .. "Leaderboard"
			local leaderboard = game.Workspace:FindFirstChild(leaderboardName)

			if leaderboard then
				local scrollingFrame = leaderboard:FindFirstChild("Main")
				if scrollingFrame then
					scrollingFrame = scrollingFrame:FindFirstChild("SurfaceGui")
					if scrollingFrame then
						scrollingFrame = scrollingFrame:FindFirstChild("ScrollingFrame")
						if scrollingFrame then

							for i, v in pairs(scrollingFrame:GetChildren()) do
								if v.ClassName == "Frame" then
									v:Destroy()
								end
							end

							for place, stat in pairs(playerStats[1]) do
								local playerUI = script:FindFirstChild("Player")
								if playerUI then
									playerUI = playerUI:Clone()
									local formattedPlace = string.format("%03d", place)
									playerUI.Name = formattedPlace

									if playerUI:FindFirstChild("Placement") then
										playerUI.Placement.Text = place .. "."
									end

									task.spawn(function()
										local success, name = pcall(function()
											return players:GetNameFromUserIdAsync(stat.UserId)
										end)
										if success and name and playerUI:FindFirstChild("PlayerName") then
											playerUI.PlayerName.Text = name
										end
									end)

									if playerUI:FindFirstChild("PlayerStat") then
										playerUI.PlayerStat.Text = tostring(stat.Stat)
									end

									if place == 1 and playerUI:FindFirstChild("Placement") then
										playerUI.Placement.TextColor3 = Color3.new(0.917647, 0.898039, 0.647059)
										task.spawn(function()
											local npcFolder = game.Workspace:FindFirstChild("loaderboardNPC")
											if npcFolder then
												local npcModel = npcFolder:FindFirstChild(playerStats[2])
												if npcModel and npcModel:FindFirstChild("HumanoidRootPart") and npcModel:FindFirstChild("Idle") then
													loadPlayerCharacter(stat.UserId, npcModel.HumanoidRootPart.CFrame, npcModel.Idle)
												end
											end
										end)
									elseif place == 2 and playerUI:FindFirstChild("Placement") then
										playerUI.Placement.TextColor3 = Color3.new(0.862745, 1, 0.682353)
									end

									playerUI.Parent = scrollingFrame
								end
							end
						end
					end
				end
			end
		end
	end)

	if not success then
		warn("Error updating leaderboard:", errorMsg)
	end
end)