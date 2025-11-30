local rod = {}

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")

local plr = players.LocalPlayer
local mouse = plr:GetMouse()

repeat
	task.wait(1)
until plr.Character

local character = plr.Character

local fishingResources = replicatedStorage:WaitForChild("FishingResources")
local modules = fishingResources:WaitForChild("Modules")
local guis = fishingResources:WaitForChild("Gui")
local minigameButton = guis:WaitForChild("MinigameButton")
local playerGui = plr:WaitForChild("PlayerGui")
local animations = fishingResources:WaitForChild("Animations")

-- 加载动画
local castAnim = character.Humanoid.Animator:LoadAnimation(animations.Cast)
local castingIdle = character.Humanoid.Animator:LoadAnimation(animations.CastingIdle)
local tugRodAnim = character.Humanoid.Animator:LoadAnimation(animations.TugRod)
local reelAnim = character.Humanoid.Animator:LoadAnimation(animations.Reeling)

local guiModule = require(modules:WaitForChild("GuiModule"))
local Config = require(fishingResources:WaitForChild("Configuration")) -- 必须引入配置以读取 Zones
local rods = Config.Rods

local isActive = false
local canCancel = true
local canCast = true
local touchFunction
local minigameActive = false
local clicked = 0 
local autoMode = false

function rod.SetAutoMode(enabled)
	autoMode = enabled
end

-- 检测钩子是否在水中
local function isHookInWater(position)
	local terrain = workspace.Terrain
	local checkRadius = 1
	local region = Region3.new(
		position - Vector3.new(checkRadius, checkRadius, checkRadius),
		position + Vector3.new(checkRadius, checkRadius, checkRadius)
	)

	local minPoint = region.CFrame.Position - region.Size/2
	local maxPoint = region.CFrame.Position + region.Size/2

	minPoint = Vector3.new(
		math.floor(minPoint.X/4)*4,
		math.floor(minPoint.Y/4)*4,
		math.floor(minPoint.Z/4)*4
	)
	maxPoint = Vector3.new(
		math.ceil(maxPoint.X/4)*4,
		math.ceil(maxPoint.Y/4)*4,
		math.ceil(maxPoint.Z/4)*4
	)

	region = Region3.new(minPoint, maxPoint)

	local success, materials, occupancies = pcall(function()
		return terrain:ReadVoxels(region, 4)
	end)

	if not success then return false end

	local size = materials.Size
	if size.X == 0 or size.Y == 0 or size.Z == 0 then return false end

	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				local material = materials[x][y][z]
				local occupancy = occupancies[x][y][z]
				if material == Enum.Material.Water and occupancy > 0.1 then
					return true
				end
			end
		end
	end
	return false
end

-- ============================================================
-- [新增] 区域检测函数
-- ============================================================
local function getZone(position)
	-- 必须在 Workspace 中有一个名为 "FishingZones" 的文件夹
	-- 里面包含名为 "Ocean", "Lake" 等的 Part (CanCollide=false)
	local zonesFolder = workspace:FindFirstChild("FishingZones")
	if not zonesFolder then return "Default" end

	-- 使用空间查询检测钩子位置是否与区域 Part 重叠
	local parts = workspace:GetPartBoundsInRadius(position, 2)
	for _, part in ipairs(parts) do
		if part.Parent == zonesFolder then
			return part.Name -- 返回区域名称 (如 "Ocean")
		end
	end
	return "Default"
end
-- ============================================================

function rod.Reset()
	if touchFunction then touchFunction:Disconnect() end
	castAnim:Stop()
	castingIdle:Stop()
	reelAnim:Stop()
	isActive = false
	canCancel = true
	minigameActive = false
	local holdMinigameUI = playerGui:FindFirstChild("HoldMinigame")
	if holdMinigameUI then holdMinigameUI.Enabled = false end
end

function rod.Cancel()
	canCancel = true
	spawn(function()
		if not isActive and not minigameActive then return end
		canCast = false
		rod.Reset()
		task.wait(2)
		canCast = true
	end)
end

-- 变量定义 (小游戏相关)
local currentPos = 50
local velocity = 0
local direction = -1
local maxVelocity = 5
local score = 50
local edgeDrag = 4
local speed = 1
local controllerSize = 0.345
local requiredScore = 600

local globalFish = require(fishingResources:WaitForChild("Configuration")).Fish
local remotes = fishingResources:WaitForChild("Remotes")
local fishRequest = remotes:WaitForChild("RequestFish")

local function getFishName(fish)
	if not fish or not fish.FishId then return "Unknown Fish" end
	local fishStats = globalFish[tostring(fish.FishId)]
	if fishStats and fishStats.Name then return fishStats.Name end
	return "Fish #" .. tostring(fish.FishId)
end

-- 收杆小游戏 (滑块跟随)
function rod.Minigame2(fishingRod, fish)
	canCancel = false  
	minigameActive = true
	reelAnim:Play()

	if not fish or not fish.FishId then
		warn("Invalid fish data provided to Minigame2")
		canCancel = true
		minigameActive = false
		rod.Cancel()
		return false
	end

	local fishStats = globalFish[tostring(fish.FishId)]
	if not fishStats then
		warn("Fish stats not found for FishId:", fish.FishId)
		canCancel = true
		minigameActive = false
		rod.Cancel()
		return false
	end

	local holdMinigameUI = playerGui:WaitForChild("HoldMinigame")
	local completeFrame = holdMinigameUI:WaitForChild("CompleteFrame"):WaitForChild("Frame")
	local playerControllerUI = holdMinigameUI.Frame.PlayerController
	local fishControllerUI = holdMinigameUI.Frame.FishController
	local rodStats

	for i, v in pairs(rods) do
		if v.RodName == fishingRod.Name then
			rodStats = v
			break
		end
	end

	fishControllerUI.Position = UDim2.new(0.5, 0, 0.5, 0)
	playerControllerUI.Position = UDim2.new(0.5, 0, 0.5, 0)
	playerControllerUI.Size = UDim2.new(controllerSize * rodStats.Control, 0, 1, 0)
	playerControllerUI.Left.Visible = true
	playerControllerUI.Right.Visible = false

	currentPos = 50
	velocity = 0
	direction = -1
	score = requiredScore / 3
	completeFrame.Size = UDim2.new(0.333, 0, 1, 0)

	local actualControllerSize = controllerSize * rodStats.Control
	local maxPos = (1-actualControllerSize/2)*100
	local minPos = (actualControllerSize/2)*100

	holdMinigameUI.Enabled = true
	task.wait(2)

	local tweenFishBool = true
	local function tweenFish()
		while tweenFishBool and minigameActive do
			local targetX = math.random(0, 100) / 100
			local tween = tweenService:Create(
				fishControllerUI,
				TweenInfo.new(fishStats.Movement+0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
				{Position = UDim2.new(targetX, 0, 0.5, 0)}
			)
			tween:Play()
			tween.Completed:Wait()
			local minWait = math.max(1, (rodStats.Resilience * 30) - (fishStats.Movement / 3) * 30)
			local maxWait = math.max(minWait + 1, (rodStats.Resilience * 100) - (fishStats.Movement / 3) * 100)
			task.wait((math.random(minWait, maxWait) / 100) + 0.5)
		end
	end
	coroutine.wrap(tweenFish)()

	local autoDirectionConnection
	if autoMode then
		autoDirectionConnection = runService.Heartbeat:Connect(function()
			if not minigameActive then
				if autoDirectionConnection then autoDirectionConnection:Disconnect() end
				return
			end
			local playerX = playerControllerUI.AbsolutePosition.X
			local playerWidth = playerControllerUI.AbsoluteSize.X
			local fishX = fishControllerUI.AbsolutePosition.X
			local fishWidth = fishControllerUI.AbsoluteSize.X
			local playerCenter = playerX + playerWidth / 2
			local fishCenter = fishX + fishWidth / 2
			if playerCenter < fishCenter then direction = 1 else direction = -1 end
		end)
	end

	local runConnection
	runConnection = runService.Heartbeat:Connect(function(deltaTime)
		if not minigameActive then
			runConnection:Disconnect()
			return
		end
		local normalizedDelta = deltaTime * 60
		velocity = math.clamp(velocity + (direction * (rodStats.Strength / 50) * normalizedDelta), -maxVelocity, maxVelocity)
		currentPos = currentPos + velocity * normalizedDelta

		if currentPos > maxPos then
			currentPos = maxPos
			velocity = (velocity * -1) / edgeDrag
		elseif currentPos < minPos then
			currentPos = minPos
			velocity = (velocity * -1) / edgeDrag
		end

		playerControllerUI.Position = UDim2.new(currentPos / 100, 0, 0.5, 0)
		playerControllerUI.Left.Visible = direction < 0
		playerControllerUI.Right.Visible = direction > 0

		local playerX = playerControllerUI.AbsolutePosition.X
		local playerWidth = playerControllerUI.AbsoluteSize.X
		local fishX = fishControllerUI.AbsolutePosition.X
		local fishWidth = fishControllerUI.AbsoluteSize.X
		local isOverlapping = playerX < fishX + fishWidth and playerX + playerWidth > fishX
		local scoreSpeed = 1 * normalizedDelta

		if isOverlapping then
			score = math.min(score + scoreSpeed, requiredScore)
		else
			score = math.max(score - scoreSpeed, 0)
		end
		completeFrame.Size = UDim2.new(score / requiredScore, 0, 1, 0)
	end)

	repeat task.wait() until score <= 0 or score >= requiredScore or not minigameActive

	runConnection:Disconnect()
	if autoDirectionConnection then autoDirectionConnection:Disconnect() end

	local finalScore = score
	local wasActive = minigameActive

	rod.Cancel()
	canCancel = true  
	tweenFishBool = false
	minigameActive = false
	holdMinigameUI.Enabled = false

	local rope = fishingRod:FindFirstChild("RopeConstraint")
	if rope and rope.Attachment0 and rope.Attachment1 then
		local currentDist = (rope.Attachment0.WorldPosition - rope.Attachment1.WorldPosition).Magnitude
		rope.Length = math.max(currentDist, 1)
	end

	reelAnim:Stop()

	if finalScore >= requiredScore and wasActive then
		local fishName = getFishName(fish)
		guiModule.PopUpSuccess("You caught a " .. fishName .. "!")
		return true
	else
		guiModule.PopUpFailed("It got away...")
		return false
	end
end

-- 等待鱼上钩的小游戏
function rod.Minigame(rodName, castPower)
	canCancel = false  
	clicked = 0  
	local rodStats
	for i, v in pairs(rods) do
		if v.RodName == rodName then
			rodStats = v
			break
		end
	end

	local baseWaitTime = 1
	local powerReduction = (castPower or 0) / 100 * 1
	local minWaitTime = math.max(3, baseWaitTime - rodStats.LureSpeed - powerReduction)
	local maxWaitTime = math.max(5, baseWaitTime + 3 - rodStats.LureSpeed - powerReduction)
	local randomWaitTime = math.random(minWaitTime * 10, maxWaitTime * 10) / 10

	repeat
		if not isActive then
			canCancel = true  
			return false
		end
		task.wait(0.1)
		randomWaitTime -= 0.1
	until randomWaitTime <= 0

	canCancel = true  
	return true
end

-- 抛竿主逻辑 (修改版: 支持区域判定)
function rod.Cast(rodModel, currentCastScore)
	if isActive or not canCast then return end

	local hookLanded = false
	local validWaterPosition = nil
	local alreadyRequested = false

	isActive = true
	canCancel = true

	replicatedStorage.FishingResources.SoundEffects.Cast.Playing = true

	if rodModel.Hook:FindFirstChild("WeldConstraint") then
		rodModel.Hook.WeldConstraint:Destroy()
	end

	task.delay(0.1, function()
		task.wait(0.15)
		rodModel.Hook.CanCollide = true
		local character = plr.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local direction = character.HumanoidRootPart.CFrame.LookVector
			local castPower = currentCastScore / 100
			local launchVelocity = direction * (castPower * 4) + Vector3.new(0, castPower * 1.2, 0)
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.MaxForce = Vector3.new(8000, 8000, 8000)
			bodyVelocity.Velocity = launchVelocity
			bodyVelocity.Parent = rodModel.Hook
			task.delay(0.5, function()
				if bodyVelocity and bodyVelocity.Parent then bodyVelocity:Destroy() end
			end)
		end
		local rope = rodModel.RopeConstraint
		local targetLength = math.max(currentCastScore, 50)
		tweenService:Create(rope, TweenInfo.new(0.3), {Length = targetLength}):Play()
	end)

	touchFunction = rodModel.Hook.Touched:Connect(function(hit)
		if hookLanded or alreadyRequested then return end
		local hookPosition = rodModel.Hook.Position
		if isHookInWater(hookPosition) then
			hookLanded = true
			validWaterPosition = hookPosition
			touchFunction:Disconnect()
		else
			if hit.Parent ~= character and hit.Parent.Name ~= rodModel.Name then
				task.wait(0.2)
				if not hookLanded and not alreadyRequested and rodModel.Hook.AssemblyLinearVelocity.Magnitude < 1 then
					local checkPosition = rodModel.Hook.Position
					if not isHookInWater(checkPosition) then
						if not alreadyRequested then
							alreadyRequested = true
							guiModule.PopUpFailed("You need to cast into water!")
							rod.Cancel()
							if touchFunction then touchFunction:Disconnect() end
						end
						return
					end
				end
			end
		end
	end)

	castingIdle:Play()
	local waitTime = 0
	local maxWaitTime = 3

	repeat
		task.wait(0.1)
		waitTime = waitTime + 0.1
		if not hookLanded and not alreadyRequested and rodModel.Hook.AssemblyLinearVelocity.Magnitude < 1 then
			local hookPosition = rodModel.Hook.Position
			if isHookInWater(hookPosition) then
				hookLanded = true
				validWaterPosition = hookPosition
			end
		end
	until hookLanded or not isActive or waitTime >= maxWaitTime

	if not isActive then return end

	if not hookLanded or not validWaterPosition or alreadyRequested then
		if not alreadyRequested then guiModule.PopUpFailed("You need to cast into water!") end
		rod.Cancel()
		return false
	end

	alreadyRequested = true

	-- ===========================================================
	-- [NEW] 区域钓鱼逻辑 (Zone Fishing Logic)
	-- ===========================================================
	local currentZone = getZone(validWaterPosition)

	-- 从 Config 读取该区域允许的鱼
	local allowedFishIds = Config.Zones[currentZone] or Config.Zones["Default"]

	-- 将允许的 ID 转换为 Set 方便查找
	local allowedSet = {}
	for _, id in pairs(allowedFishIds) do allowedSet[tostring(id)] = true end

	local fishData = nil
	local maxRetries = 10 -- 最大重试次数，防止服务器无限随机不到
	local attempts = 0

	guiModule.PopUp("Fishing in: " .. currentZone)

	-- 循环请求，直到获取到属于该区域的鱼
	repeat
		attempts = attempts + 1
		fishData = fishRequest:InvokeServer(validWaterPosition)

		if not fishData then break end -- 服务器返回空，停止

		local fishId = tostring(fishData.FishId)

		-- 1. 鱼属于该区域，通过
		-- 2. 或者是重试次数用完了，勉强通过 (防止卡死)
		if allowedSet[fishId] then
			break
		end

		if attempts < maxRetries then
			task.wait(0.1) -- 稍微等待再重试
		end
	until attempts >= maxRetries

	-- ===========================================================

	if not fishData then
		guiModule.PopUpFailed("Invalid fishing location!")
		rod.Cancel()
		return false
	end

	return true, fishData
end

local clicked = 0

mouse.Button1Down:Connect(function()
	direction = 1
	if not canCancel then
		clicked = 0
		return
	end
	clicked += 1
	if isActive and clicked >= 2 then
		rod.Cancel()
		clicked = 0
	end
end)

mouse.Button1Up:Connect(function()
	direction = -1
end)

game:GetService("UserInputService").InputBegan:Connect(function(input, things)
	if things then return end
	if input.KeyCode == Enum.KeyCode.Space then
		direction = 1
	end
end)

game:GetService("UserInputService").InputEnded:Connect(function(input, things)
	if things then return end
	if input.KeyCode == Enum.KeyCode.Space then
		direction = -1
	end
end)

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	castAnim = animator:LoadAnimation(animations.Cast)
	castingIdle = animator:LoadAnimation(animations.CastingIdle)
	tugRodAnim = animator:LoadAnimation(animations.TugRod)
	reelAnim = animator:LoadAnimation(animations.Reeling)

	game.Workspace.CurrentCamera.FieldOfView = 70
	canCast = true
	clicked = 0
	direction = 1
	rod.Cancel()
end

plr.CharacterAdded:Connect(function(character)
	setupCharacter(character)
end)

return rod