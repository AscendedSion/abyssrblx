local NotificationHolder = loadstring(game:HttpGet("https://raw.githubusercontent.com/BocusLuke/UI/main/STX/Module.Lua"))()
local Notification = loadstring(game:HttpGet("https://raw.githubusercontent.com/BocusLuke/UI/main/STX/Client.Lua"))()

-- These are your settings, keep enabled, wallcheck and alivecheck on if u dont want ur lock to be asslol
-- These premade sets are good for 60 - 80 ping ig
getgenv().dhlock = {
    enabled = true,
    showfov = true,
    fov = 50,
    keybind = Enum.UserInputType.MouseButton3,
    teamcheck = false,
    wallcheck = true,
    alivecheck = true,
    lockpart = "Head",
    lockpartair = "UpperTorso",
    smoothness = 1,
    auto_prediction = true, -- NEW: Toggle for auto-prediction
    fovcolorlocked = Color3.new(1, 1, 1),
    fovcolorunlocked = Color3.new(0, 0, 0),
    fovtransparency = 0.6,
    toggle = true,
    blacklist = {}
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local isAiming = false
local fovCircle
local lockedPlayer = nil
local holdingKeybind = false

local PREDICTION_VALUE = 0.1 -- Default value, will be auto-adjusted

-- A function to get the player's ping in seconds
local function GetPingInSeconds()
    local pingValue = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
    local split = string.split(pingValue, '(')
    local ping = tonumber(split[1])
    if ping then
        return ping / 1000 -- Convert ms to seconds
    end
    return 0
end

local function IsValidKeybind(input)
    return typeof(input) == "EnumItem" and (input.EnumType == Enum.KeyCode or input.EnumType == Enum.UserInputType)
end

local function GetCurrentLockPart()
    local character = LocalPlayer.Character
    if not character then return dhlock.lockpart end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local lockPartName = dhlock.lockpart
    if humanoid and humanoid.FloorMaterial == Enum.Material.Air then
        lockPartName = dhlock.lockpartair
    end

    if character:FindFirstChild(lockPartName) then
        return lockPartName
    else
        return "HumanoidRootPart"
    end
end

local function IsPlayerAlive(player)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function IsPlayerKnockedOrGrabbed(player)
    if not player or not player.Character then
        return false
    end

    local bodyEffects = player.Character:FindFirstChild("BodyEffects")
    local isKOd = bodyEffects and bodyEffects:FindFirstChild("K.O")
    
    local isGrabbed = player.Character:FindFirstChild("GRABBING_CONSTRAINT") ~= nil

    return isKOd or isGrabbed
end

local function IsVisible(player)
    local localCharacter = LocalPlayer.Character
    local targetCharacter = player.Character

    if not localCharacter or not targetCharacter then
        return false
    end

    local origin = Workspace.CurrentCamera.CFrame.Position
    local target = targetCharacter:FindFirstChild(GetCurrentLockPart())

    if not target then
        return false
    end

    local direction = (target.Position - origin)

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {localCharacter, targetCharacter}

    local result = Workspace:Raycast(origin, direction, raycastParams)

    if result then
        return false
    else
        return true
    end
end

local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local mousePosition = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(GetCurrentLockPart()) and not table.find(dhlock.blacklist, player.Name) then
            if (not dhlock.alivecheck or (IsPlayerAlive(player) and not IsPlayerKnockedOrGrabbed(player))) and
               (not dhlock.teamcheck or player.Team ~= LocalPlayer.Team) then

                local part = player.Character:FindFirstChild(GetCurrentLockPart())
                local screenPoint, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(part.Position)
                local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePosition).Magnitude

                if onScreen and distance <= dhlock.fov and distance < shortestDistance then
                    if dhlock.wallcheck and not IsVisible(player) then
                        continue
                    end

                    closestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end

    return closestPlayer
end

local function SmoothAimAtPlayer(player, dt)
    if not player or not player.Character then return end

    local part = player.Character:FindFirstChild(GetCurrentLockPart())
    if not part then return end

    local camera = Workspace.CurrentCamera
    local ping_in_seconds = GetPingInSeconds()

    -- Calculate the predicted target position based on delta time and ping
    local targetPosition = part.Position + part.Velocity * (dt + ping_in_seconds)

    local targetCFrame = CFrame.new(camera.CFrame.Position, targetPosition)
    local smoothnessFactor = 1 / math.max(dhlock.smoothness, 1e-5)

    -- Interpolate the camera CFrame towards the predicted target position
    camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothnessFactor)
end

local function HandleAim(dt)
    if not dhlock.enabled then return end

    if holdingKeybind or (dhlock.toggle and isAiming) then
        if not lockedPlayer or not lockedPlayer.Character or not lockedPlayer.Character:FindFirstChild(GetCurrentLockPart()) then
            lockedPlayer = GetClosestPlayer()
        end

        if lockedPlayer then
            SmoothAimAtPlayer(lockedPlayer, dt)
        end
    else
        lockedPlayer = nil
    end
end

local function DrawFovCircle()
    if dhlock.showfov then
        if not fovCircle then
            fovCircle = Drawing.new("Circle")
            fovCircle.Radius = dhlock.fov
            fovCircle.Position = UserInputService:GetMouseLocation()
            fovCircle.Color = dhlock.fovcolorunlocked
            fovCircle.Thickness = 1
            fovCircle.Transparency = dhlock.fovtransparency
        end
        fovCircle.Position = UserInputService:GetMouseLocation()
        fovCircle.Radius = dhlock.fov
        fovCircle.Color = dhlock.fovcolorunlocked
    elseif fovCircle then
        fovCircle:Remove()
        fovCircle = nil
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if (input.UserInputType == dhlock.keybind or input.KeyCode == dhlock.keybind) and IsValidKeybind(dhlock.keybind) then
        holdingKeybind = true
        if dhlock.toggle then
            isAiming = not isAiming
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if (input.UserInputType == dhlock.keybind or input.KeyCode == dhlock.keybind) and IsValidKeybind(dhlock.keybind) then
        holdingKeybind = false
    end
end)

RunService.RenderStepped:Connect(function(dt)
    HandleAim(dt)
    DrawFovCircle()
end)

local FILL_COLOR = Color3.new(1, 0.5, 0.5)
local OUTLINE_COLOR = Color3.new(1, 0, 0)

local function applyHighlight(character)
    if not character:FindFirstChildOfClass("Highlight") then
        local highlight = Instance.new("Highlight")
        highlight.Name = "PlayerHighlight"
        highlight.FillColor = FILL_COLOR
        highlight.OutlineColor = OUTLINE_COLOR
        highlight.FillTransparency = 0.5
        highlight.Enabled = true
        highlight.Parent = character
    end
end

local function onPlayerAdded(player)
    local function onCharacterAdded(character)
        applyHighlight(character)
    end

    player.CharacterAdded:Connect(onCharacterAdded)

    if player.Character then
        applyHighlight(player.Character)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

Notification:Notify(
    {Title = "abyss", Description = "hands on ya burners, bamas on deck."},
    {OutlineColor = Color3.fromRGB(80, 80, 80), Time = 5, Type = "default"}
)