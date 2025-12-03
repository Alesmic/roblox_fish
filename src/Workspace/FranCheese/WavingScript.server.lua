local animation = script:WaitForChild('AnimationID')
local humanoid = script.Parent:WaitForChild('Humanoid')
local dance = humanoid:LoadAnimation(animation)
dance:Play()
dance.Looped = true