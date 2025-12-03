local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local plr = players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

local function ensureVignetteGUI()
	local vignetteGUI = playerGui:FindFirstChild("VignetteGUI")
	if not vignetteGUI then
		local starterVignette = game.StarterGui:FindFirstChild("VignetteGUI")
		if starterVignette then
			vignetteGUI = starterVignette:Clone()
			vignetteGUI.Parent = playerGui
			-- Ensure vignette is hidden by default after cloning
			local vignette = vignetteGUI:FindFirstChild("Vignette")
			if vignette then
				vignette.Visible = false
			end
		end
	end
end

-- Call when player character loads
plr.CharacterAdded:Connect(function(character)
	task.wait(0.5) -- Wait for PlayerGui to fully load
	ensureVignetteGUI()
end)

-- Ensure VignetteGUI exists if player already has a character
if plr.Character then
	task.wait(0.5)
	ensureVignetteGUI()
end

-- Safely load configurations and modules
local function safeRequire(module)
	local success, result = pcall(function()
		return require(module)
	end)
	if success then
		return result
	else
		warn("Failed to require module: " .. tostring(module) .. " - " .. tostring(result))
		return nil
	end
end

local fishingResources = replicatedStorage:WaitForChild("FishingResources")
local modules = fishingResources:WaitForChild("Modules")

-- Safely load Configuration
local Config
local configModule = fishingResources:FindFirstChild("Configuration")
if configModule then
	Config = safeRequire(configModule)
else
	warn("Configuration module not found!")
end

-- Use default configuration if loading fails
if not Config then
	Config = {
		AutoFishing = {
			GamepassId = 0,
			RequireGamepass = false
		},
		Fish = {},
		FishRarity = {},
		Rods = {}
	}
end

-- Safely load other modules
local rodFunctions = safeRequire(modules:WaitForChild("RodFunctions"))
local guiModule = safeRequire(modules:WaitForChild("GuiModule"))

-- Create stub functions if module loading fails
if not rodFunctions then
	rodFunctions = {
		Cancel = function() end,
		Cast = function() return false end,
		Minigame = function() return false end,
		SetAutoMode = function() end
	}
end

if not guiModule then
	guiModule = {
		PopUpSuccess = function(msg) print("SUCCESS: " .. msg) end,
		PopUpFailed = function(msg) print("FAILED: " .. msg) end,
		PopUp = function(msg) print("INFO: " .. msg) end
	}
end

local casting = playerGui:WaitForChild("Casting")
local remotes = fishingResources:WaitForChild("Remotes")
local fishRequest = remotes:WaitForChild("RequestFish")
local caughtFish = remotes:WaitForChild("CatchFish")
local checkInventory = remotes:WaitForChild("CheckInventory")
local models = fishingResources:WaitForChild("Models")

local autoGui = playerGui:WaitForChild("AutoGui")
local autoToggle = autoGui:WaitForChild("AutoToggle")
local showInventoryWarning = remotes:WaitForChild("ShowInventoryWarning")
local isAutoEnabled = false
local autoFishingLoop = nil

if not Config.AutoFishing then
	warn("AutoFishing config not found in Configuration module! Auto fishing will be disabled.")
end

local autoFishingConfig = Config.AutoFishing or {}
local AUTO_FISHING_GAMEPASS_ID = autoFishingConfig.GamepassId
local REQUIRES_GAMEPASS = autoFishingConfig.RequireGamepass or false
local ownsGamepass = false
local isCheckingGamepass = false

local isFishing = false
local isEquipped = false
local isCasting = false
local mobileButtonActive = false
local activationStart = nil
local currentTween = nil
local charType = "R15"
local character, humanoid, hrp = nil, nil, nil
local defaultC0 = {}
local hookSyncConnection = nil
local equipDebounce = false
local unequipDebounce = false
local activatedConnection = nil
local deactivatedConnection = nil
local airCastDebounce = false

local MAX_holdTime = 2
local max_distance = 100
local minCastPowerThreshold = 0.3
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

repeat task.wait() until plr.Character

-- Safely get fishing rod components
local function getRodParts(rod)
	local hook = rod:FindFirstChild("Hook")
	local rodEnd = rod:FindFirstChild("RodEnd")

	if not hook then
		warn("Hook not found in " .. rod.Name)
		-- Try to find other possible hook names
		hook = rod:FindFirstChild("FishHook") or rod:FindFirstChildWhichIsA("Part")
	end

	if not rodEnd then
		warn("RodEnd not found in " .. rod.Name)
		-- Try to find other possible end names
		rodEnd = rod:FindFirstChild("End") or rod:FindFirstChild("Tip") or rod:FindFirstChild("Handle")
	end

	return hook, rodEnd
end

local hook, rodEnd = getRodParts(script.Parent)

if not hook or not rodEnd then
	warn("Essential parts not found in " .. script.Parent.Name .. ". Fishing disabled.")
	-- Disable fishing function but allow equipping
	script.Parent.Equipped:Connect(function()
		guiModule.PopUpFailed("This fishing rod is not properly configured.")
	end)
	return
end

local otherPlayerHooks = {}

local powerAnim, resetArmPosition, calculatePowerAndCast, weld, resetArmToDefault, stopHookSync, forceResetState

function forceResetState()
	isFishing = false
	isCasting = false
	activationStart = nil

	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	casting.Enabled = false

	local holdMinigameUI = playerGui:FindFirstChild("HoldMinigame")
	if holdMinigameUI then
		holdMinigameUI.Enabled = false
	end

	if hrp then
		hrp.Anchored = false
	end

	if character and character.Humanoid then
		character.Humanoid.WalkSpeed = 16
		character.Humanoid.JumpHeight = 7.2
	end

	if script.Parent:FindFirstChild("RopeConstraint") then
		script.Parent.RopeConstraint.Length = 0
	end

	stopHookSync()

	local reelSyncEvent = remotes:FindFirstChild("ReelSync")
	if reelSyncEvent then
		reelSyncEvent:FireServer()
	end

	weld()

	rodFunctions.Cancel()

	local reelingSound = replicatedStorage.FishingResources.SoundEffects:FindFirstChild("Reeling")
	if reelingSound and reelingSound.Playing then
		reelingSound:Stop()
	end

	tweenService:Create(game.Workspace.CurrentCamera, TweenInfo.new(0.5), {FieldOfView = 70}):Play()
end

local function checkGamepassOwnership()
	if not REQUIRES_GAMEPASS then
		ownsGamepass = true
		return ownsGamepass
	end

	if not AUTO_FISHING_GAMEPASS_ID then
		warn("Auto Fishing Gamepass ID not configured!")
		ownsGamepass = false
		return ownsGamepass
	end

	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, AUTO_FISHING_GAMEPASS_ID)
	end)

	if success then
		ownsGamepass = result
	else
		warn("Failed to check gamepass ownership:", result)
		ownsGamepass = false
	end

	return ownsGamepass
end

local function promptGamepassPurchase()
	if not REQUIRES_GAMEPASS then
		ownsGamepass = true
		return
	end

	if not AUTO_FISHING_GAMEPASS_ID then
		guiModule.PopUpFailed("Auto Fishing Gamepass not configured!")
		return
	end

	pcall(function()
		MarketplaceService:PromptGamePassPurchase(plr, AUTO_FISHING_GAMEPASS_ID)
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
	if player == plr and gamepassId == AUTO_FISHING_GAMEPASS_ID then
		if wasPurchased then
			ownsGamepass = true
			guiModule.PopUpSuccess("Auto Fishing unlocked!")
		end
	end
end)

local function updateToggleColors(enabled)
	if enabled then
		autoToggle.BackgroundColor3 = Color3.fromRGB(78, 255, 78)
		if autoToggle:FindFirstChild("UIStroke") then
			autoToggle.UIStroke.Color = Color3.fromRGB(36, 175, 12)
		end
		autoToggle.Text = "AUTO"
	else
		autoToggle.BackgroundColor3 = Color3.fromRGB(255, 64, 0)
		if autoToggle:FindFirstChild("UIStroke") then
			autoToggle.UIStroke.Color = Color3.fromRGB(218, 0, 0)
		end
		autoToggle.Text = "AUTO"
	end
end

local function toggleAutoFishing()
	if isCheckingGamepass then
		return
	end

	if not Config.AutoFishing then
		guiModule.PopUpFailed("Auto Fishing not configured in Configuration module!")
		return
	end

	if not REQUIRES_GAMEPASS then
		ownsGamepass = true
		isAutoEnabled = not isAutoEnabled
		updateToggleColors(isAutoEnabled)

		if isAutoEnabled then
			startAutoFishing()
		else
			stopAutoFishing()
		end
		return
	end

	if isStudio then
		ownsGamepass = true
		isAutoEnabled = not isAutoEnabled
		updateToggleColors(isAutoEnabled)

		if isAutoEnabled then
			guiModule.PopUpSuccess("Auto Fishing enabled! (Studio Mode)")
			startAutoFishing()
		else
			stopAutoFishing()
		end
		return
	end

	if not AUTO_FISHING_GAMEPASS_ID then
		guiModule.PopUpFailed("Auto Fishing Gamepass ID not configured!")
		return
	end

	if not ownsGamepass then
		isCheckingGamepass = true

		local success, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, AUTO_FISHING_GAMEPASS_ID)
		end)

		if success then
			ownsGamepass = result
		else
			warn("Failed to check gamepass ownership:", result)
		end

		isCheckingGamepass = false
	end

	if not ownsGamepass then
		promptGamepassPurchase()
		return
	end

	isAutoEnabled = not isAutoEnabled
	updateToggleColors(isAutoEnabled)

	if isAutoEnabled then
		guiModule.PopUpSuccess("Auto Fishing enabled!")
		startAutoFishing()
	else
		stopAutoFishing()
	end
end

function startAutoFishing()
	if autoFishingLoop then return end

	autoFishingLoop = task.spawn(function()
		while isAutoEnabled and isEquipped do
			if not isFishing and not isCasting and isAutoEnabled then
				task.wait(0.5)
				if isAutoEnabled and isEquipped then
					autoCast()
				end
			end
			task.wait(0.1)
		end

		autoFishingLoop = nil
	end)
end

function stopAutoFishing()
	if autoFishingLoop then
		task.cancel(autoFishingLoop)
		autoFishingLoop = nil
	end
end

function autoCast()
	if not isEquipped or isFishing or isCasting then
		return
	end

	local holdMinigameUI = playerGui:FindFirstChild("HoldMinigame")
	if holdMinigameUI and holdMinigameUI.Enabled then
		return
	end

	if not character or not humanoid or not hrp then
		return
	end

	-- Check inventory before casting
	local canCast = checkInventory:InvokeServer()
	if not canCast then
		return -- Server will handle the popup message
	end

	if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
		isCasting = true
		casting.Enabled = true

		hrp.Anchored = true

		activationStart = tick()

		powerAnim(character)

		local castPercentFrame = casting.Frame.Frame
		castPercentFrame.Size = UDim2.new(1, 0, 0, 0)
		castPercentFrame.BackgroundColor3 = Color3.new(1, 1, 1)

		task.spawn(function()
			local startTime = tick()
			while isCasting and (tick() - startTime) < MAX_holdTime do
				local currentTime = tick() - startTime
				local powerPercent = currentTime / MAX_holdTime

				castPercentFrame.Size = UDim2.new(1, 0, powerPercent, 0)
				castPercentFrame.BackgroundColor3 = Color3.new(1, 1, 1)

				task.wait()
			end
		end)

		task.wait(MAX_holdTime)

		if isCasting then
			isFishing = true
			isCasting = false

			resetArmPosition(character)
			calculatePowerAndCast()
		end
	end
end

local function setupHookSync()
	local syncEvent = remotes:FindFirstChild("SyncHookPosition")

	if not syncEvent then
		local maxWaitTime = 10
		local startTime = tick()

		while not syncEvent and (tick() - startTime) < maxWaitTime do
			task.wait(0.1)
			syncEvent = remotes:FindFirstChild("SyncHookPosition")
		end
	end

	if not syncEvent then
		warn("SyncHookPosition RemoteEvent not found.")
		return
	end

	showInventoryWarning.OnClientEvent:Connect(function()
		if Config.MaxFishInventory and Config.MaxFishInventory.WarningMessage then
			guiModule.PopUpFailed(Config.MaxFishInventory.WarningMessage)
		end
	end)

	syncEvent.OnClientEvent:Connect(function(syncData)
		local player = players:GetPlayerByUserId(syncData.playerUserId)
		if not player or player == plr then return end

		local character = player.Character
		if not character then return end

		local fishingRod = character:FindFirstChildWhichIsA("Tool")
		if not fishingRod then return end

		local hook = fishingRod:FindFirstChild("Hook")
		local ropeConstraint = fishingRod:FindFirstChild("RopeConstraint")
		local beam = fishingRod:FindFirstChildWhichIsA("Beam")

		if syncData.hookCFrame == nil then
			if ropeConstraint then
				ropeConstraint.Length = 0
			end
			if beam then
				beam.Enabled = false
			end
			otherPlayerHooks[syncData.playerUserId] = nil
			return
		end

		if not otherPlayerHooks[syncData.playerUserId] then
			otherPlayerHooks[syncData.playerUserId] = {
				hook = hook,
				ropeConstraint = ropeConstraint,
				beam = beam,
				targetCFrame = syncData.hookCFrame,
				currentCFrame = hook and hook.CFrame or syncData.hookCFrame,
				targetLength = syncData.ropeLength,
				currentLength = ropeConstraint and ropeConstraint.Length or 0,
				lastUpdate = tick()
			}

		else
			local hookData = otherPlayerHooks[syncData.playerUserId]
			hookData.targetCFrame = syncData.hookCFrame
			hookData.targetLength = syncData.ropeLength
			hookData.lastUpdate = tick()
		end

		if beam then
			beam.Enabled = (syncData.ropeLength or 0) > 0
		end
	end)

	runService.Heartbeat:Connect(function(deltaTime)
		for userId, hookData in pairs(otherPlayerHooks) do
			if hookData.hook and hookData.targetCFrame then
				local alpha = math.min(deltaTime * 15, 1)

				hookData.currentCFrame = hookData.currentCFrame:Lerp(hookData.targetCFrame, alpha)
				hookData.hook.CFrame = hookData.currentCFrame
			end

			if hookData.ropeConstraint and hookData.targetLength then
				local alpha = math.min(deltaTime * 15, 1)

				hookData.currentLength = hookData.currentLength + (hookData.targetLength - hookData.currentLength) * alpha
				hookData.ropeConstraint.Length = hookData.currentLength
			end

			if tick() - hookData.lastUpdate > 1 then
				otherPlayerHooks[userId] = nil
			end
		end
	end)
end

setupHookSync()

local function startHookSync()
	if hookSyncConnection then
		hookSyncConnection:Disconnect()
		hookSyncConnection = nil
	end

	local castSyncEvent = remotes:FindFirstChild("CastSync")
	if not castSyncEvent then return end

	local lastSync = 0
	local syncInterval = 0.15
	local syncThrottle = false
	local lastLen = nil
	local lastPos = nil
	local POS_EPS = 0.05
	local LEN_EPS = 0.05

	hookSyncConnection = runService.Heartbeat:Connect(function()
		if not isEquipped or not hook or not isFishing then return end
		if syncThrottle then return end

		local ropeConstraint = script.Parent:FindFirstChild("RopeConstraint")
		if not ropeConstraint or ropeConstraint.Length <= 0 then return end

		local now = tick()
		if now - lastSync < syncInterval then return end

		local pos = hook.Position
		local len = ropeConstraint.Length
		local send = false

		if not lastPos or (pos - lastPos).Magnitude > POS_EPS then
			send = true
		end
		if not lastLen or math.abs(len - lastLen) > LEN_EPS then
			send = true
		end
		if not send then return end

		syncThrottle = true
		castSyncEvent:FireServer(hook.CFrame, len)
		lastSync = now
		lastPos = pos
		lastLen = len

		task.delay(syncInterval, function()
			syncThrottle = false
		end)
	end)
end

function stopHookSync()
	if hookSyncConnection then
		hookSyncConnection:Disconnect()
		hookSyncConnection = nil
	end
end

local ACTION_NAME = "FishingCastBind"
local IMAGE_ID = "rbxassetid://5713982324"
local BUTTON_SIZE = Vector2.new(60, 60)
local BUTTON_POS  = UDim2.new(0.5, -50, 1, -120)
local SHOW_TEXT = true
local LABEL_TEXT = "CAST"

local function castButtonHandler(actionName, inputState, inputObject)
	if not isEquipped or isFishing then
		return Enum.ContextActionResult.Sink
	end
	local holdMinigameUI = playerGui:FindFirstChild("HoldMinigame")
	if holdMinigameUI and holdMinigameUI.Enabled then
		return Enum.ContextActionResult.Sink
	end
	if inputState == Enum.UserInputState.Begin then
		startCasting()
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		stopCasting()
	end
	return Enum.ContextActionResult.Sink
end

local function skinCASButton(actionName)
	local btn = ContextActionService:GetButton(actionName)
	if not btn then return end
	btn.Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y)
	ContextActionService:SetPosition(actionName, BUTTON_POS)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.ImageTransparency = 1
	btn.Image = ""
	for _, c in ipairs(btn:GetChildren()) do c:Destroy() end
	local icon = Instance.new("ImageLabel")
	icon.Name = "CustomIcon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.ImageTransparency = 0.5
	icon.Image = IMAGE_ID
	icon.Parent = btn
	if SHOW_TEXT then
		local label = Instance.new("TextLabel")
		label.Name = "CastLabel"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.7, 0.7)
		label.Text = LABEL_TEXT
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1,1,1)
		label.TextStrokeTransparency = 0.3
		label.TextStrokeColor3 = Color3.new(0,0,0)
		label.Position = UDim2.new(0.5, -22, 1, -50)
		label.Parent = btn
	end
end

local function bindMobileButton()
	if isMobile and not mobileButtonActive and isEquipped then
		task.wait(0.1)
		if not isEquipped then return end

		mobileButtonActive = true
		ContextActionService:BindAction(
			ACTION_NAME,
			castButtonHandler,
			true,
			Enum.KeyCode.ButtonR1
		)
		ContextActionService:SetTitle(ACTION_NAME, "")
		task.defer(function()
			skinCASButton(ACTION_NAME)
			local btn = ContextActionService:GetButton(ACTION_NAME)
			if btn then
				btn.AncestryChanged:Connect(function(_, parent)
					if parent then task.defer(function() skinCASButton(ACTION_NAME) end) end
				end)
			end
		end)
	end
end

local function unbindMobileButton()
	if mobileButtonActive then
		mobileButtonActive = false
		ContextActionService:UnbindAction(ACTION_NAME)
	end
end

function weld()
	hook.CFrame = rodEnd.CFrame
	if not hook:FindFirstChild("WeldConstraint") then
		local weld = Instance.new("WeldConstraint", hook)
		weld.Part1 = hook
		weld.Part0 = rodEnd
	end
end

local function cacheDefaultC0(character)
	if not humanoid or not character then return end
	if charType == "R6" then
		local rightShoulder = character:WaitForChild("Torso"):WaitForChild("Right Shoulder")
		defaultC0[humanoid.RigType] = rightShoulder.C0
	else
		local rightShoulder = character:WaitForChild("RightUpperArm"):WaitForChild("RightShoulder")
		defaultC0[humanoid.RigType] = rightShoulder.C0
	end
end

local function cancelTween()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
end

function resetArmToDefault(character)
	cancelTween()
	if not humanoid or not character then return end
	if charType == "R6" then
		local rightShoulder = character:WaitForChild("Torso"):WaitForChild("Right Shoulder")
		rightShoulder.C0 = defaultC0[humanoid.RigType]
	else
		local rightShoulder = character:WaitForChild("RightUpperArm"):WaitForChild("RightShoulder")
		rightShoulder.C0 = defaultC0[humanoid.RigType]
	end
end

function powerAnim(character)
	resetArmToDefault(character)
	if not humanoid or not character then return end

	if charType == "R6" then
		local rightShoulder = character:WaitForChild("Torso"):WaitForChild("Right Shoulder")
		local targetC0 = rightShoulder.C0 * CFrame.Angles(0, 0, math.rad(110))
		currentTween = tweenService:Create(rightShoulder, TweenInfo.new(1, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {C0 = targetC0})
		currentTween:Play()
	else
		local rightShoulder = character:WaitForChild("RightUpperArm"):WaitForChild("RightShoulder")
		local targetC0 = rightShoulder.C0 * CFrame.Angles(math.rad(110), 0, 0)
		currentTween = tweenService:Create(rightShoulder, TweenInfo.new(1, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {C0 = targetC0})
		currentTween:Play()
	end
end

function resetArmPosition(character)
	cancelTween()
	if not humanoid or not character then return end

	if charType == "R6" then
		local rightShoulder = character:WaitForChild("Torso"):WaitForChild("Right Shoulder")
		local resetC0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0)
		local tween = tweenService:Create(rightShoulder, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {C0 = resetC0})
		tween:Play()
		if tween then tween.Completed:Wait() end
	else
		local rightShoulder = character:WaitForChild("RightUpperArm"):WaitForChild("RightShoulder")
		local resetC0 = defaultC0[humanoid.RigType]
		currentTween = tweenService:Create(rightShoulder, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {C0 = resetC0})
		currentTween:Play()
		if currentTween then currentTween.Completed:Wait() end
	end
end

function calculatePowerAndCast()
	if activationStart then
		local activationDuration = tick() - activationStart
		activationStart = nil
		local power = math.clamp(activationDuration, 0, MAX_holdTime)
		local powerPercent = (power / MAX_holdTime) * 100
		casting.Enabled = false
		if power > minCastPowerThreshold then
			local distance = (power / MAX_holdTime) * max_distance
			local currentCastScore = powerPercent * 5
			startHookSync()
			local successfullCast, fish = rodFunctions.Cast(script.Parent, currentCastScore)
			plr.Character.Humanoid.WalkSpeed = 2
			plr.Character.Humanoid.JumpHeight = 0
			if not successfullCast or not fish then
				stopHookSync()
				reelIn()
				return
			end
			local successfulMinigame = rodFunctions.Minigame(script.Parent.Name)
			if not successfulMinigame then
				stopHookSync()
				reelIn()
				return
			end
			replicatedStorage.FishingResources.SoundEffects.Clicked.TimePosition = 0.12
			replicatedStorage.FishingResources.SoundEffects.FoundFish.Playing = true
			local expl = models.CatchNotifier:Clone()
			expl:PivotTo(plr.Character.Head.CFrame)
			expl.Parent = game.Workspace
			local color = Color3.new(0.67451, 0, 0)
			if fish.Rainbow then
				color = Color3.new(0.890196, 0.0745098, 1)
			elseif fish.Shiny then
				color = Color3.new(1, 0.811765, 0.0666667)
			end
			for i, v in pairs(expl:GetChildren()) do
				v.Color = color
			end
			task.delay(1, function()
				for i, v in pairs(expl:GetChildren()) do
					tweenService:Create(v, TweenInfo.new(0.4), {Transparency = 1}):Play()
				end
				task.wait(0.4)
				expl:Destroy()
			end)
			tweenService:Create(game.Workspace.CurrentCamera, TweenInfo.new(1), {FieldOfView = 60}):Play()
			local reelingSound = replicatedStorage.FishingResources.SoundEffects:FindFirstChild("Reeling")
			if reelingSound then
				reelingSound.Looped = true
				reelingSound:Play()
			end
			if isAutoEnabled then
				rodFunctions.SetAutoMode(true)
			end

			-- ========== Show rarity exclamation mark ==========
			local exclamationPart = nil

			-- Get fish ID correctly
			local fishId = fish.FishId
			local weight = nil

			-- Get weight (value from FishChances)
			if fishId and Config and Config.FishChances then
				weight = Config.FishChances[tonumber(fishId)]
			end

			-- Color selection (based on weight)
			local exclamationFolder = replicatedStorage.FishingResources.Models:FindFirstChild("Exclamation")
			if exclamationFolder then
				if weight then
					if weight >= 11 then
						exclamationPart = exclamationFolder:FindFirstChild("White") and exclamationFolder.White:Clone()
					elseif weight >= 6 then
						exclamationPart = exclamationFolder:FindFirstChild("Blue") and exclamationFolder.Blue:Clone()
					else
						exclamationPart = exclamationFolder:FindFirstChild("Cyan") and exclamationFolder.Cyan:Clone()
					end
				else
					warn("Fish weight not found, using default white exclamation mark")
					exclamationPart = exclamationFolder:FindFirstChild("White") and exclamationFolder.White:Clone()
				end
			end

			-- Safely display exclamation mark
			if exclamationPart then
				exclamationPart.Parent = workspace
				exclamationPart.CFrame = plr.Character.Head.CFrame + Vector3.new(0, 3, 0)
				exclamationPart.CanCollide = false
				exclamationPart.Anchored = true
				exclamationPart.Transparency = 0  -- Adjust transparency if needed
			end

			-- Ensure vignette UI is available in PlayerGui
			local vignetteGUI = playerGui:FindFirstChild("VignetteGUI")
			if not vignetteGUI then
				-- If VignetteGUI is not in PlayerGui, clone it from StarterGui
				local starterVignette = game.StarterGui:FindFirstChild("VignetteGUI")
				if starterVignette then
					vignetteGUI = starterVignette:Clone()
					vignetteGUI.Parent = playerGui
					-- Ensure vignette is hidden by default after cloning
					local vignette = vignetteGUI:FindFirstChild("Vignette")
					if vignette then
						vignette.Visible = false
					end
				end
			end

			-- Show vignette
			if vignetteGUI then
				local vignette = vignetteGUI:FindFirstChild("Vignette")
				if vignette then
					vignette.Visible = true
					print("Vignette ON - Game 2 starts")
				else
					warn("Vignette ImageLabel not found in VignetteGUI")
				end
			else
				warn("VignetteGUI not found")
			end

			local successfulMinigame2 = rodFunctions.Minigame2(script.Parent, fish)

			-- Hide vignette
			if vignetteGUI then
				local vignette = vignetteGUI:FindFirstChild("Vignette")
				if vignette then
					vignette.Visible = false
					print("Vignette OFF - Game 2 ends")
				end
			end

			if exclamationPart and exclamationPart.Parent then
				exclamationPart:Destroy()
			end

			if isAutoEnabled then
				rodFunctions.SetAutoMode(false)
			end

			if reelingSound and reelingSound.Playing then
				reelingSound:Stop()
			end
			if not successfulMinigame2 then
				stopHookSync()
				reelIn()
				return
			end
			replicatedStorage.FishingResources.SoundEffects.Caught.Playing = true
			caughtFish:FireServer()
			stopHookSync()
			reelIn()
		else
			isFishing = false
			guiModule.PopUp("Not enough power!")
			reelIn()
		end
	end
end


function startCasting()
	if not isEquipped or isFishing or isCasting then
		return
	end

	local holdMinigameUI = playerGui:FindFirstChild("HoldMinigame")
	if holdMinigameUI and holdMinigameUI.Enabled then
		return
	end

	-- Check inventory before castingin
	local canCast = checkInventory:InvokeServer()
	if not canCast then
		return -- Server will handle the popup message
	end

	if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
		isCasting = true
		casting.Enabled = true

		if hrp then
			hrp.Anchored = false
		end

		activationStart = tick()
		powerAnim(character)

		local castPercentFrame = casting.Frame.Frame
		castPercentFrame.Size = UDim2.new(1, 0, 0, 0)
		castPercentFrame.BackgroundColor3 = Color3.new(1, 1, 1)

		if mobileButtonActive then
			ContextActionService:SetTitle('FishingCastBind', "CAST")
		end

		task.spawn(function()
			while isCasting and activationStart do
				local currentTime = tick() - activationStart
				local power = math.clamp(currentTime, 0, MAX_holdTime)
				local powerPercent = (power / MAX_holdTime)

				castPercentFrame.Size = UDim2.new(1, 0, powerPercent, 0)
				castPercentFrame.BackgroundColor3 = Color3.new(1, 1, 1)

				task.wait()
			end
		end)
	else
		if not airCastDebounce then
			airCastDebounce = true
			guiModule.PopUp("You can't fish while in the air!")
			task.wait(1)
			airCastDebounce = false
		end
	end
end

function stopCasting()
	if isCasting then
		isFishing = true
		isCasting = false

		resetArmPosition(character)
		calculatePowerAndCast()

		if mobileButtonActive then
			ContextActionService:SetTitle('FishingCastBind', "CAST")
		end
	end
end

function reelIn()
	isFishing = false

	script.Parent.RopeConstraint.Length = 0

	local reelSyncEvent = remotes:FindFirstChild("ReelSync")
	if reelSyncEvent then
		reelSyncEvent:FireServer()
	end

	plr.Character.Humanoid.WalkSpeed = 16
	plr.Character.Humanoid.JumpHeight = 7.2

	tweenService:Create(game.Workspace.CurrentCamera, TweenInfo.new(1), {FieldOfView = 70}):Play()

	if hrp then
		hrp.Anchored = false
	end

	weld()
end

script.Parent.Equipped:Connect(function()
	if hook then
		hook.CanCollide = false
	end
	isEquipped = true

	character = script.Parent.Parent
	humanoid = character:FindFirstChild("Humanoid")
	hrp = character:FindFirstChild("HumanoidRootPart")

	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
		charType = "R15"
	elseif humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
		charType = "R6"
	end

	cacheDefaultC0(character)
	resetArmToDefault(character)

	weld()

	autoGui.Enabled = true
	updateToggleColors(isAutoEnabled)

	if Config.AutoFishing and REQUIRES_GAMEPASS then
		checkGamepassOwnership()
	elseif Config.AutoFishing and not REQUIRES_GAMEPASS then
		ownsGamepass = true
	end

	local reelSyncEvent = remotes:FindFirstChild("ReelSync")
	if reelSyncEvent then
		reelSyncEvent:FireServer()
	end

	if isMobile then
		task.spawn(bindMobileButton)
	else
		script.Parent.Activated:Connect(startCasting)
		script.Parent.Deactivated:Connect(stopCasting)
	end
end)

script.Parent.Unequipped:Connect(function()
	forceResetState()

	isEquipped = false

	if isAutoEnabled then
		isAutoEnabled = false
		stopAutoFishing()
		updateToggleColors(false)
	end

	autoGui.Enabled = false

	cancelTween()
	resetArmToDefault(character)

	unbindMobileButton()
end)

autoToggle.MouseButton1Click:Connect(toggleAutoFishing)