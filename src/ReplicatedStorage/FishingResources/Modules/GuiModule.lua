local module = {}
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")

local plr = players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local notificationSystem = playerGui:WaitForChild("NotificationSystem")
local list = notificationSystem:WaitForChild("list")

local successTemplate = list:WaitForChild("Success")
local failedTemplate = list:WaitForChild("Failed")

successTemplate.Visible = false
failedTemplate.Visible = false

local activeNotifications = {}

local DISPLAY_TIME = 2.5
local ANIMATION_TIME = 0.4
local SLIDE_DISTANCE = 300

local function createNotification(text, notificationType)
	local template = (notificationType == "Success") and successTemplate or failedTemplate
	local newNotification = template:Clone()

	local notificationId = tick() .. "_" .. math.random(1000, 9999)
	newNotification.Name = notificationType .. "_" .. notificationId

	local header = newNotification:FindFirstChild("Header")
	if header then
		header.Text = text
	end

	newNotification.Visible = true
	newNotification.Parent = list

	activeNotifications[notificationId] = {
		Frame = newNotification,
		Type = notificationType,
		Id = notificationId,
		CreatedAt = tick()
	}

	local bar = newNotification:FindFirstChild("bar")
	if bar then

		bar.Size = UDim2.new(1, 0, bar.Size.Y.Scale, bar.Size.Y.Offset)

		local barTween = tweenService:Create(
			bar,
			TweenInfo.new(DISPLAY_TIME, Enum.EasingStyle.Linear),
			{Size = UDim2.new(0, 0, bar.Size.Y.Scale, bar.Size.Y.Offset)}
		)
		barTween:Play()
	end

	task.delay(DISPLAY_TIME, function()
		if activeNotifications[notificationId] then
			activeNotifications[notificationId] = nil
			newNotification:Destroy()
		end
	end)

	return newNotification
end

function module.PopUpSuccess(text)
	createNotification(text, "Success")
end

function module.PopUpFailed(text)
	createNotification(text, "Failed")
end

function module.PopUpSellSuccess(...)
	local args = {...}
	local text = ""

	if #args == 1 then

		local param = args[1]
		if type(param) == "number" then
			text = "Fish sold for $" .. param .. "!"
		else
			text = tostring(param)
		end
	elseif #args == 2 then

		local fishName = args[1]
		local amount = args[2]
		text = "You sold " .. fishName .. " for $" .. amount .. "!"
	elseif #args >= 3 then

		local fishCount = args[1]
		local amount = args[2]
		local skipped = args[3] or 0

		if fishCount > 1 then
			text = "Sold " .. fishCount .. " fish for $" .. amount .. "!"
		else
			text = "Fish sold for $" .. amount .. "!"
		end

		if skipped > 0 then
			text = text .. " (" .. skipped .. " favorites skipped)"
		end
	else
		text = "Fish sold successfully!"
	end

	createNotification(text, "Success")
end

function module.PopUpSellResult(soldCount, totalEarned, skippedFavorites)
	local text = ""

	if soldCount > 0 then
		if soldCount == 1 then
			text = "Sold 1 fish for $" .. totalEarned .. "!"
		else
			text = "Sold " .. soldCount .. " fish for $" .. totalEarned .. "!"
		end

		if skippedFavorites and skippedFavorites > 0 then
			text = text .. " (" .. skippedFavorites .. " favorites skipped)"
		end

		createNotification(text, "Success")
	else
		if skippedFavorites and skippedFavorites > 0 then
			createNotification("No fish sold (" .. skippedFavorites .. " favorites skipped)", "Failed")
		else
			createNotification("No fish to sell!", "Failed")
		end
	end
end

function module.PopUpMoney(amount, action)
	action = action or "earned"
	local text = "You " .. action .. " $" .. amount .. "!"
	createNotification(text, "Success")
end

function module.PopUpError(text)
	createNotification(text, "Failed")
end

function module.PopUp(text)

	local lowerText = string.lower(text)

	local errorKeywords = {
		"failed", "error", "can't", "cannot", "unable", "invalid", 
		"insufficient", "not enough", "missing", "wrong", "got away"
	}

	local isError = false
	for _, keyword in pairs(errorKeywords) do
		if string.find(lowerText, keyword) then
			isError = true
			break
		end
	end

	if isError then
		createNotification(text, "Failed")
	else
		createNotification(text, "Success")
	end
end

function module.ClearAllNotifications()
	for notificationId, notification in pairs(activeNotifications) do
		if notification.Frame then
			notification.Frame:Destroy()
		end
	end
	activeNotifications = {}
end

function module.GetActiveNotificationCount(notificationType)
	if not notificationType then
		local count = 0
		for _ in pairs(activeNotifications) do
			count = count + 1
		end
		return count
	end

	local count = 0
	for _, notification in pairs(activeNotifications) do
		if notification.Type == notificationType then
			count = count + 1
		end
	end
	return count
end

return module