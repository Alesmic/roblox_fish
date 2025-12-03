-- 这个脚本负责把钓到的鱼存入 ProfileService 的库存里
local module = {}
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS.FishingResources:WaitForChild("Remotes")

-- 监听钓鱼事件 (如果你的加密脚本有发送事件出来)
-- 如果没有，我们需要自己暴露一个函数给 MainServerScript 调用

-- 假设你的 MainServerScript 会在钓到鱼后调用这个函数
function module.OnFishCaught(player, fishData)
	if not player or not fishData then return end

	local profile = _G.getProfile(player)
	if profile then
		-- 存入库存
		table.insert(profile.Data.FishInventory, fishData)
		print("[GlobalPlayerCatching] 鱼已存入背包: " .. tostring(fishData.FishId))

		-- 这里可以触发客户端更新 UI 事件
		-- Remotes.UpdateInventory:FireClient(player, profile.Data.FishInventory)
	end
end

return module