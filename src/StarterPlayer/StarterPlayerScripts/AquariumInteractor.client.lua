local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- 等待远程函数 (增加超时保护)
local remotes = RS:WaitForChild("FishingResources", 30):WaitForChild("Remotes", 30)
local placeFunc = remotes:WaitForChild("PlaceFishInAquarium", 30)

if not placeFunc then return end
print("[CLIENT] 水族箱互动脚本启动 (等待加载版)...")

local tycoonsFolder = workspace:WaitForChild("Tycoons", 10)

local function setupInteractions(baseModel)
	local standsFolder = baseModel:WaitForChild("Stands", 10)
	if not standsFolder then return end

	local stands = {}
	for _, v in ipairs(standsFolder:GetChildren()) do
		if v.Name == "CharacterStand" then table.insert(stands, v) end
	end

	-- 排序
	table.sort(stands, function(a, b) return a:GetPivot().Position.Z < b:GetPivot().Position.Z end)
	print("[CLIENT] 找到 " .. #stands .. " 个展示台，开始配置交互...")

	local count = 0
	for index, stand in ipairs(stands) do
		-- [关键修改] 使用 WaitForChild 等待零件加载，最多等 5 秒
		local placementPoint = stand:WaitForChild("PlacementPoint", 5)

		if placementPoint then
			-- 清理旧提示
			if placementPoint:FindFirstChild("PlacePrompt") then placementPoint.PlacePrompt:Destroy() end

			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PlacePrompt"
			prompt.ObjectText = "展示台 #" .. index
			prompt.ActionText = "放置手中的鱼"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.5
			prompt.MaxActivationDistance = 8 
			prompt.RequiresLineOfSight = false
			prompt.Parent = placementPoint

			count = count + 1

			prompt.Triggered:Connect(function()
				-- 模拟数据
				local testFish = { FishId = 9, Value = 5000, Weight = 100 }

				local success, msg = placeFunc:InvokeServer(testFish, index)
				if success then
					print("[CLIENT] ✅ 放置成功！")
					prompt.Enabled = false; task.wait(2); prompt.Enabled = true
				else
					warn("[CLIENT] ❌ 放置失败: " .. tostring(msg))
				end
			end)
		else
			-- 如果等了5秒还没来，那可能是真没有，或者流加载范围太小
			warn("[CLIENT] ⚠️ 第 " .. index .. " 个展示台等待 'PlacementPoint' 超时。")
			warn(">>> 调试：该模型当前包含：")
			for _, c in pairs(stand:GetChildren()) do print("   - " .. c.Name) end
		end
	end

	if count > 0 then
		print("[CLIENT] ✅ 成功添加 " .. count .. " 个交互点。")
	end
end

local function findMyBase()
	task.spawn(function()
		local attempts = 0
		while attempts < 30 do
			if tycoonsFolder then
				for _, base in pairs(tycoonsFolder:GetChildren()) do
					local ownerVal = base:FindFirstChild("# Owner") or base:FindFirstChild("Owner")
					if ownerVal and tostring(ownerVal.Value) == tostring(player.UserId) then
						print("[CLIENT] 找到基地: " .. base.Name)
						setupInteractions(base)
						return 
					end
				end
			end
			attempts = attempts + 1
			task.wait(1) 
		end
	end)
end

findMyBase()