local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local FishingResources = RS:WaitForChild("FishingResources")
local Config = require(FishingResources:WaitForChild("Configuration"))
local FishModels = FishingResources:WaitForChild("Models")
local Remotes = FishingResources:WaitForChild("Remotes")

local PlaceFishFunc = Remotes:FindFirstChild("PlaceFishInAquarium")
if not PlaceFishFunc then
	PlaceFishFunc = Instance.new("RemoteFunction", Remotes)
	PlaceFishFunc.Name = "PlaceFishInAquarium"
end

local PlayerAccumulatedCash = {}
local PlayerAquariumData = {}

-- 自动绑定
local function autoAssignTycoon(player)
	local tycoonsFolder = workspace:FindFirstChild("Tycoons")
	if not tycoonsFolder then return nil end
	local myBase = tycoonsFolder:GetChildren()[1]
	if not myBase then return nil end

	local ownerVal = myBase:FindFirstChild("# Owner") or myBase:FindFirstChild("Owner")
	if not ownerVal then
		ownerVal = Instance.new("IntValue", myBase)
		ownerVal.Name = "# Owner"
	end
	ownerVal.Value = player.UserId
	print("[SERVER] ✅ 基地绑定成功: " .. player.Name)
	return myBase
end

-- 获取展示台
local function getStandByIndex(baseModel, index)
	local standsFolder = baseModel:FindFirstChild("Stands")
	if not standsFolder then return nil end
	local stands = {}
	for _, v in ipairs(standsFolder:GetChildren()) do
		if v.Name == "CharacterStand" then table.insert(stands, v) end
	end
	table.sort(stands, function(a, b) return a:GetPivot().Position.Z < b:GetPivot().Position.Z end)
	return stands[index]
end

-- 视觉化 (简化版：直接找 PlacementPoint)
local function visualizeFish(standModel, fishData)
	-- [修改] 你的模型现在很简单，直接找儿子就行
	local placementPoint = standModel:FindFirstChild("PlacementPoint")

	if not placementPoint then 
		warn("[SERVER] 错误：在服务端也找不到 PlacementPoint，请确认已按照上一步修改模型结构！") 
		return 
	end

	if placementPoint:FindFirstChild("DisplayFish") then placementPoint.DisplayFish:Destroy() end
	if placementPoint:FindFirstChild("InfoGui") then placementPoint.InfoGui:Destroy() end

	local fishId = tostring(fishData.FishId)
	local fishStats = Config.Fish[fishId]
	if not fishStats then return end

	local modelTemplate = FishModels:FindFirstChild(fishStats.Name) or FishModels:FindFirstChild(fishId)
	if not modelTemplate then return end 

	local displayFish = modelTemplate:Clone()
	displayFish.Name = "DisplayFish"
	displayFish.Parent = placementPoint

	-- 计算偏移
	local targetCFrame = placementPoint.CFrame * CFrame.new(0, 1.5, 0)

	if displayFish:IsA("Model") then
		displayFish:PivotTo(targetCFrame)
		for _, p in pairs(displayFish:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
	elseif displayFish:IsA("BasePart") then
		displayFish.CFrame = targetCFrame
		displayFish.Anchored = true; displayFish.CanCollide = false
	end

	-- UI
	local bbGui = Instance.new("BillboardGui", placementPoint)
	bbGui.Name = "InfoGui"; bbGui.Size = UDim2.new(0, 150, 0, 60); bbGui.StudsOffset = Vector3.new(0, 3, 0); bbGui.AlwaysOnTop = true
	local nameLabel = Instance.new("TextLabel", bbGui)
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0); nameLabel.BackgroundTransparency = 1; nameLabel.TextScaled = true
	nameLabel.Text = fishStats.Name; nameLabel.Font = Enum.Font.GothamBold; nameLabel.TextColor3 = Color3.new(1,1,1)
	local incomeLabel = Instance.new("TextLabel", bbGui)
	incomeLabel.Size = UDim2.new(1, 0, 0.5, 0); incomeLabel.Position = UDim2.new(0,0,0.5,0); incomeLabel.BackgroundTransparency = 1
	local income = math.floor((fishData.Value or 100) * Config.Aquarium.IncomePercentage)
	incomeLabel.Text = "+$" .. income .. "/s"; incomeLabel.TextColor3 = Color3.new(0, 1, 0); incomeLabel.Font = Enum.Font.GothamBold; incomeLabel.TextScaled = true
end

PlaceFishFunc.OnServerInvoke = function(player, fishData, slotIndexStr)
	local profile = _G.getProfile(player)
	if not profile then return false end

	local tycoons = workspace:FindFirstChild("Tycoons")
	local myBase = nil
	if tycoons then
		for _, t in pairs(tycoons:GetChildren()) do
			local o = t:FindFirstChild("# Owner") or t:FindFirstChild("Owner")
			if o and tostring(o.Value) == tostring(player.UserId) then myBase = t; break end
		end
	end

	if not myBase then return false end
	local standPart = getStandByIndex(myBase, tonumber(slotIndexStr))
	if not standPart then return false end

	profile.Data.Aquarium["Slot_" .. slotIndexStr] = fishData
	PlayerAquariumData[player.UserId] = profile.Data.Aquarium
	visualizeFish(standPart, fishData)
	return true
end

local function setupCollectors(baseModel, player)
	local standsFolder = baseModel:FindFirstChild("Stands")
	if not standsFolder then return end

	for _, stand in pairs(standsFolder:GetChildren()) do
		if stand.Name == "CharacterStand" then
			local cashPart = stand:FindFirstChild("CashCollect")

			if cashPart then
				if not cashPart:FindFirstChild("StatusGui") then
					local bb = Instance.new("BillboardGui", cashPart)
					bb.Name = "StatusGui"; bb.Size = UDim2.new(0,100,0,40); bb.StudsOffset = Vector3.new(0,2,0); bb.AlwaysOnTop = true
					local lbl = Instance.new("TextLabel", bb); lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.TextScaled = true; lbl.TextColor3 = Color3.new(1,1,0); lbl.Font = Enum.Font.GothamBlack; lbl.Text = "$"
				end

				local debounce = false
				cashPart.Touched:Connect(function(hit)
					if debounce then return end
					if hit.Parent == player.Character then
						local cash = PlayerAccumulatedCash[player.UserId]
						if cash and cash > 0 then
							debounce = true
							_G.addCash(player, cash)
							PlayerAccumulatedCash[player.UserId] = 0
							for _, s in pairs(standsFolder:GetChildren()) do
								local cp = s:FindFirstChild("CashCollect")
								if cp and cp:FindFirstChild("StatusGui") then cp.StatusGui.TextLabel.Text = "$" end
							end
							task.wait(1)
							debounce = false
						end
					end
				end)
			end
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	local myBase = autoAssignTycoon(player)
	local event = player:WaitForChild("AquariumDataLoaded", 10)
	if not event then return end

	event.Event:Connect(function(aquariumData, lastLogout)
		PlayerAccumulatedCash[player.UserId] = 0
		PlayerAquariumData[player.UserId] = aquariumData or {}
		if not myBase then return end

		local totalIncome = 0
		for key, data in pairs(aquariumData) do
			local index = tonumber(string.match(key, "%d+"))
			if index then
				local standModel = getStandByIndex(myBase, index)
				if standModel then
					visualizeFish(standModel, data)
					local inc = math.floor((data.Value or 0) * Config.Aquarium.IncomePercentage)
					totalIncome = totalIncome + inc
				end
			end
		end
		if lastLogout and lastLogout > 0 then
			local timeDiff = os.time() - lastLogout
			if timeDiff > Config.Aquarium.MaxOfflineTime then timeDiff = Config.Aquarium.MaxOfflineTime end
			if timeDiff > 60 and totalIncome > 0 then
				local earned = timeDiff * totalIncome
				_G.addCash(player, earned)
				print("💰 离线收益: $" .. earned)
			end
		end
		setupCollectors(myBase, player)
		task.spawn(function()
			while player.Parent and myBase.Parent do
				task.wait(Config.Aquarium.IncomeRate)
				local currentTotal = 0
				for _, d in pairs(PlayerAquariumData[player.UserId] or {}) do
					currentTotal += math.floor((d.Value or 0) * Config.Aquarium.IncomePercentage)
				end
				if currentTotal > 0 then
					PlayerAccumulatedCash[player.UserId] = (PlayerAccumulatedCash[player.UserId] or 0) + currentTotal
					local standsFolder = myBase:FindFirstChild("Stands")
					if standsFolder then
						for _, s in pairs(standsFolder:GetChildren()) do
							local cp = s:FindFirstChild("CashCollect")
							if cp and cp:FindFirstChild("StatusGui") then
								cp.StatusGui.TextLabel.Text = "$" .. PlayerAccumulatedCash[player.UserId]
							end
						end
					end
				end
			end
		end)
	end)
end)