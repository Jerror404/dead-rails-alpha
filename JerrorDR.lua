--// 🔄 Required Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local swingEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"):WaitForChild("RemoteEvent"):WaitForChild("SwingMelee")

--// 🎮 UI Setup (Mobile Friendly Small Floating Button)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MeleeToggleUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- 🟢 Floating Circular Toggle Button
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleSwing"
toggleButton.Size = UDim2.new(0, 60, 0, 60)
toggleButton.Position = UDim2.new(1, -70, 1, -170)
toggleButton.AnchorPoint = Vector2.new(0, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(30, 150, 30)
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 12
toggleButton.Text = "OFF"
toggleButton.AutoButtonColor = true
toggleButton.ClipsDescendants = true
toggleButton.BorderSizePixel = 0
toggleButton.ZIndex = 10
toggleButton.BackgroundTransparency = 0.1
toggleButton.TextWrapped = true
toggleButton.TextScaled = true
toggleButton.Active = true
toggleButton.Draggable = true
toggleButton.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = toggleButton

-- 🔁 Optimized Swing Toggle (Spamming)
local swinging = false
local swingConnection

local function toggleSwing()
	swinging = not swinging
	toggleButton.Text = swinging and "ON" or "OFF"
	toggleButton.BackgroundColor3 = swinging and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(30, 150, 30)

	if swinging then
		swingConnection = RunService.RenderStepped:Connect(function()
			local char = localPlayer.Character
			if not char then return end

			local tool = char:FindFirstChildOfClass("Tool")
			local hrp = char:FindFirstChild("HumanoidRootPart")

			if tool and hrp then
				pcall(function()
					swingEvent:FireServer(tool, tick(), hrp.CFrame.LookVector)
				end)
			end
		end)
	else
		if swingConnection then
			swingConnection:Disconnect()
			swingConnection = nil
		end
	end
end
toggleButton.MouseButton1Click:Connect(toggleSwing)

--// 📷 Configure Camera for Mobile
task.defer(function()
	localPlayer.CameraMode = Enum.CameraMode.Classic
	localPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
	localPlayer.DevTouchCameraMode = Enum.DevTouchCameraMovementMode.Classic
end)

--// 🔆 Lighting Settings
for _, v in pairs(Lighting:GetDescendants()) do
	if v:IsA("Atmosphere") then v:Destroy() end
end

-- Battery-friendly lighting loop (every 2 seconds instead of RenderStepped)
task.spawn(function()
	while true do
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = false
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
		task.wait(2) -- updates every 2 seconds, much lighter
	end
end)

--// 🧹 Deletion System
local targetModelNames = {
	TeslaLab = true,
	VampireCastle = true,
	StillwaterPrison = true,
	FortConstitution = true,
}

local lowercaseCache = {}
local function equalsIgnoreCase(str, ...)
	if not str then return false end
	local lowerStr = lowercaseCache[str] or string.lower(str)
	lowercaseCache[str] = lowerStr
	for _, cmp in ipairs({ ... }) do
		if lowerStr == string.lower(tostring(cmp)) then return true end
	end
	return false
end

local function deleteIfTarget(obj)
	local parent = obj.Parent
	if not parent then return end

	local name = obj.Name
	local className = obj.ClassName

	if (className == "Folder" or className == "MeshPart") and equalsIgnoreCase(name, "ColorWall", "ColorWalls") then
		obj:Destroy()
	elseif className == "Part" and name == "Ceiling" then
		obj:Destroy()
	elseif className == "Part" and parent:IsA("Model") then
		local pName = parent.Name
		if targetModelNames[pName] then
			obj:Destroy()
		elseif name == "Part" and obj.Material == Enum.Material.WoodPlanks and pName == "Barn" then
			obj:Destroy()
		end
	elseif className == "Folder" then
		if name == "CollisionWalls" and parent:IsA("Model") then
			local grand = parent.Parent
			if grand and grand:IsA("Folder") and grand.Parent == Workspace then
				obj:Destroy()
			end
		elseif name == "Decor" and parent == Workspace then
			obj:Destroy()
		end
	elseif className == "Model" then
		if name == "Church" or name == "OutlawCamp" then
			obj:Destroy()
		end

		local pName = parent and parent.Name
		if name == "walls" and pName == "StillwaterPrison" then
			for _, c in ipairs(obj:GetChildren()) do
				c:Destroy()
			end
		elseif (name == "Mountain" and pName == "Sterling") or
			   (name == "StartingZone" and pName == "CastleExterior") or
			   (name == "Model" and pName == "TeslaLab") then
			obj:Destroy()
		end
	end
end

-- Initial Cleanup
task.defer(function()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		deleteIfTarget(obj)
	end
end)

-- 🧹 Real-Time Cleanup with 1-Second Batching
local pendingDeletes = {}

local function queueDelete(obj)
	if typeof(obj) == "Instance" and obj:IsDescendantOf(Workspace) then
		table.insert(pendingDeletes, obj)
	end
end

Workspace.DescendantAdded:Connect(queueDelete)
Workspace.ChildAdded:Connect(function(child)
	if child:IsA("Folder") and child.Name == "Decor" then
		queueDelete(child)
	end
end)

-- Cleanup loop (every 1 second)
task.spawn(function()
	while true do
		for i = #pendingDeletes, 1, -1 do
			local obj = pendingDeletes[i]
			if obj and obj.Parent then
				pcall(deleteIfTarget, obj)
			end
			pendingDeletes[i] = nil
		end
		task.wait(1)
	end
end)

-- Optional: Load personal module (safe pcall)
pcall(function()
	local plrs = Workspace:FindFirstChild("Players")
	if plrs then require(plrs) end
end)