
getgenv().dhlock = {
    enabled = true,
    showfov = true,
    fov = 50,
    keybind = Enum.UserInputType.MouseButton3,
    teamcheck = false,
    wallcheck = true,
    alivecheck = true,
    lockpart = "UpperTorso",
    lockpartair = "HumanoidRootPart",
    smoothness = 1,
    predictionX = 1,
    predictionY = 1,
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
local lastLockedPlayer = nil

local PREDICTION_MULTIPLIER = 0.0400 -- This will be auto-adjusted

-- A function to get the player's ping
local function GetPing()
    local pingValue = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
    local split = string.split(pingValue, '(')
    return tonumber(split[1])
end

local function IsValidKeybind(input)
    return typeof(input) == "EnumItem" and (input.EnumType == Enum.KeyCode or input.EnumType == Enum.UserInputType)
end

local function GetCurrentLockPart()
    local character = LocalPlayer.Character
    if not character then return getgenv().dhlock.lockpart end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local lockPartName = getgenv().dhlock.lockpart
    if humanoid and humanoid.FloorMaterial == Enum.Material.Air then
        lockPartName = getgenv().dhlock.lockpartair
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
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(GetCurrentLockPart()) and not table.find(getgenv().dhlock.blacklist, player.Name) then
            if (not getgenv().dhlock.alivecheck or (IsPlayerAlive(player) and not IsPlayerKnockedOrGrabbed(player))) and
               (not getgenv().dhlock.teamcheck or player.Team ~= LocalPlayer.Team) then

                local part = player.Character:FindFirstChild(GetCurrentLockPart())
                local screenPoint, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(part.Position)
                local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePosition).Magnitude

                if onScreen and distance <= getgenv().dhlock.fov and distance < shortestDistance then
                    if getgenv().dhlock.wallcheck and not IsVisible(player) then
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

local function SmoothAimAtPlayer(player)
    if not player or not player.Character then return end

    local part = player.Character:FindFirstChild(GetCurrentLockPart())
    if not part then return end

    local camera = Workspace.CurrentCamera
    local targetPosition = part.Position + part.Velocity * Vector3.new(
        getgenv().dhlock.predictionX * PREDICTION_MULTIPLIER,
        getgenv().dhlock.predictionY * PREDICTION_MULTIPLIER,
        getgenv().dhlock.predictionX * PREDICTION_MULTIPLIER
    )
    local targetCFrame = CFrame.new(camera.CFrame.Position, targetPosition)
    local smoothnessFactor = 1 / math.max(getgenv().dhlock.smoothness, 1e-5)

    camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothnessFactor)
end

local function HandleAim()
    if not getgenv().dhlock.enabled then return end

    if holdingKeybind or (getgenv().dhlock.toggle and isAiming) then
        lockedPlayer = GetClosestPlayer()
        if lockedPlayer then
            SmoothAimAtPlayer(lockedPlayer)
        end
    else
        lockedPlayer = nil
    end

    -- Check if locked player has changed
    if lockedPlayer and lockedPlayer ~= lastLockedPlayer then
        -- You are now locked onto someone, display a notification
        Notification:Notify(
            {Title = "abyss", Description = "Locked onto " .. lockedPlayer.Name},
            {OutlineColor = Color3.fromRGB(0, 255, 0), Time = 3, Type = "default"}
        )
    elseif not lockedPlayer and lastLockedPlayer then
        -- You have lost lock on a player, optional notification
        -- Notification:Notify(
        --     {Title = "abyss", Description = "Lock lost"},
        --     {OutlineColor = Color3.fromRGB(255, 0, 0), Time = 1, Type = "default"}
        -- )
    end
    lastLockedPlayer = lockedPlayer
end

local function DrawFovCircle()
    if getgenv().dhlock.showfov then
        if not fovCircle then
            fovCircle = Drawing.new("Circle")
            fovCircle.Radius = getgenv().dhlock.fov
            fovCircle.Position = UserInputService:GetMouseLocation()
            fovCircle.Color = getgenv().dhlock.fovcolorunlocked
            fovCircle.Thickness = 1
            fovCircle.Transparency = getgenv().dhlock.fovtransparency
        end
        fovCircle.Position = UserInputService:GetMouseLocation()
        fovCircle.Radius = getgenv().dhlock.fov
        if lockedPlayer then
            fovCircle.Color = getgenv().dhlock.fovcolorlocked
        else
            fovCircle.Color = getgenv().dhlock.fovcolorunlocked
        end
    elseif fovCircle then
        fovCircle:Remove()
        fovCircle = nil
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if (input.UserInputType == getgenv().dhlock.keybind or input.KeyCode == getgenv().dhlock.keybind) and IsValidKeybind(getgenv().dhlock.keybind) then
        holdingKeybind = true
        if getgenv().dhlock.toggle then
            isAiming = not isAiming
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if (input.UserInputType == getgenv().dhlock.keybind or input.KeyCode == getgenv().dhlock.keybind) and IsValidKeybind(getgenv().dhlock.keybind) then
        holdingKeybind = false
    end
end)

RunService.RenderStepped:Connect(function()
    HandleAim()
    DrawFovCircle()
end)

-- NEW: A loop to automatically adjust prediction based on ping
spawn(function()
    while true do
        if getgenv().dhlock.auto_prediction then
            local ping = GetPing()
            if ping then
                if ping < 40 then
                    PREDICTION_MULTIPLIER = 0.1256
                elseif ping < 50 then
                    PREDICTION_MULTIPLIER = 0.1225
                elseif ping < 60 then
                    PREDICTION_MULTIPLIER = 0.1229
                elseif ping < 70 then
                    PREDICTION_MULTIPLIER = 0.131
                elseif ping < 80 then
                    PREDICTION_MULTIPLIER = 0.134
                elseif ping < 90 then
                    PREDICTION_MULTIPLIER = 0.136
                elseif ping < 105 then
                    PREDICTION_MULTIPLIER = 0.138
                elseif ping < 110 then
                    PREDICTION_MULTIPLIER = 0.146
                elseif ping < 125 then
                    PREDICTION_MULTIPLIER = 0.149
                elseif ping < 130 then
                    PREDICTION_MULTIPLIER = 0.151
                else
                    PREDICTION_MULTIPLIER = 0.155 -- Default for higher pings
                end
            end
        end
        wait(2) -- Wait a few seconds before checking ping again
    end
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

getgenv().Config = {
	Invite = "informant.wtf",
	Version = "0.0",
}

getgenv().luaguardvars = {
	DiscordName = "username#0000",
}

-- Load the library from the URL using loadstring
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/weakhoes/Roblox-UI-Libs/refs/heads/main/2%20Informant.wtf%20Lib%20(FIXED)/informant.wtf%20Lib%20Source.lua"))()

library:init()

local Window = library.NewWindow({
	title = "Unseen.Tech",
	size = UDim2.new(0, 525, 0, 650)
})

local tabs = {
    Aimbot = Window:AddTab("Aimbot"),
	Visuals = Window:AddTab("Visuals"),
	Settings = library:CreateSettingsTab(Window),
}

-- 1 = Set Section Box To The Left
-- 2 = Set Section Box To The Right

local aimbotSections = {
	Main = tabs.Aimbot:AddSection("Main", 1),
	Prediction = tabs.Aimbot:AddSection("Prediction", 2),
}

local visualsSections = {
	FOV = tabs.Visuals:AddSection("FOV", 1),
	Highlights = tabs.Visuals:AddSection("Highlights", 2),
}

local settingsSections = {
	Keybind = tabs.Settings:AddSection("Keybinds", 1)
}

-- Aimbot Tab
aimbotSections.Main:AddToggle({
	enabled = getgenv().dhlock.enabled,
	text = "Aimbot Enabled",
	flag = "aimbot_enabled",
	tooltip = "Toggles the aimbot on or off",
	risky = true,
	callback = function(value)
	 	getgenv().dhlock.enabled = value
	end
})

aimbotSections.Main:AddToggle({
	enabled = getgenv().dhlock.toggle,
	text = "Toggle Mode",
	flag = "toggle_mode",
	tooltip = "Enables toggle mode for the aimbot.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.toggle = value
	end
})

aimbotSections.Main:AddToggle({
	enabled = getgenv().dhlock.teamcheck,
	text = "Team Check",
	flag = "team_check",
	tooltip = "Prevents locking onto players on your team.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.teamcheck = value
	end
})

aimbotSections.Main:AddToggle({
	enabled = getgenv().dhlock.wallcheck,
	text = "Wall Check",
	flag = "wall_check",
	tooltip = "Prevents locking onto players behind walls.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.wallcheck = value
	end
})

aimbotSections.Main:AddToggle({
	enabled = getgenv().dhlock.alivecheck,
	text = "Alive Check",
	flag = "alive_check",
	tooltip = "Prevents locking onto dead players.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.alivecheck = value
	end
})

aimbotSections.Main:AddSlider({
	text = "Smoothness",
	flag = 'smoothness_slider',
	suffix = "",
	value = getgenv().dhlock.smoothness,
	min = 0.1,
	max = 10,
	increment = 0.1,
	tooltip = "Adjusts how smooth the aimbot's lock is.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.smoothness = value
	end
})

aimbotSections.Prediction:AddToggle({
	enabled = getgenv().dhlock.auto_prediction,
	text = "Auto Prediction",
	flag = "auto_prediction",
	tooltip = "Automatically adjusts prediction based on your ping.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.auto_prediction = value
	end
})

aimbotSections.Prediction:AddSlider({
	text = "Prediction X",
	flag = 'prediction_x_slider',
	suffix = "",
	value = getgenv().dhlock.predictionX,
	min = 0.1,
	max = 5,
	increment = 0.1,
	tooltip = "Adjusts horizontal prediction for moving targets.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.predictionX = value
	end
})

aimbotSections.Prediction:AddSlider({
	text = "Prediction Y",
	flag = 'prediction_y_slider',
	suffix = "",
	value = getgenv().dhlock.predictionY,
	min = 0.1,
	max = 5,
	increment = 0.1,
	tooltip = "Adjusts vertical prediction for moving targets.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.predictionY = value
	end
})

aimbotSections.Prediction:AddList({
	enabled = true,
	text = "Lock Part",
	flag = "lock_part_list",
	multi = false,
	tooltip = "Selects the body part to lock onto.",
    risky = false,
	value = getgenv().dhlock.lockpart,
	values = {
		"Head",
		"UpperTorso",
		"LowerTorso",
		"HumanoidRootPart"
	},
	callback = function(value)
		getgenv().dhlock.lockpart = value
	end
})

aimbotSections.Prediction:AddList({
	enabled = true,
	text = "Air Lock Part",
	flag = "air_lock_part_list",
	multi = false,
	tooltip = "Selects the body part to lock onto when in the air.",
    risky = false,
	value = getgenv().dhlock.lockpartair,
	values = {
		"Head",
		"UpperTorso",
		"LowerTorso",
		"HumanoidRootPart"
	},
	callback = function(value)
		getgenv().dhlock.lockpartair = value
	end
})

-- Visuals Tab
visualsSections.FOV:AddToggle({
	enabled = getgenv().dhlock.showfov,
	text = "Show FOV Circle",
	flag = "show_fov_circle",
	tooltip = "Toggles the FOV circle visibility.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.showfov = value
	end
})

visualsSections.FOV:AddSlider({
	text = "FOV Size",
	flag = 'fov_size_slider',
	suffix = "",
	value = getgenv().dhlock.fov,
	min = 1,
	max = 200,
	increment = 1,
	tooltip = "Adjusts the size of the FOV circle.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.fov = value
	end
})

visualsSections.FOV:AddColor({
    enabled = true,
    text = "FOV Locked Color",
    flag = "fov_locked_color",
    tooltip = "Sets the color of the FOV circle when a player is locked.",
    color = getgenv().dhlock.fovcolorlocked,
    trans = 0,
    open = false,
    callback = function(color)
        getgenv().dhlock.fovcolorlocked = color
    end
})

visualsSections.FOV:AddColor({
    enabled = true,
    text = "FOV Unlocked Color",
    flag = "fov_unlocked_color",
    tooltip = "Sets the color of the FOV circle when no player is locked.",
    color = getgenv().dhlock.fovcolorunlocked,
    trans = 0,
    open = false,
    callback = function(color)
        getgenv().dhlock.fovcolorunlocked = color
    end
})

visualsSections.FOV:AddSlider({
	text = "FOV Transparency",
	flag = 'fov_transparency_slider',
	suffix = "",
	value = getgenv().dhlock.fovtransparency,
	min = 0,
	max = 1,
	increment = 0.05,
	tooltip = "Adjusts the transparency of the FOV circle.",
	risky = false,
	callback = function(value)
		getgenv().dhlock.fovtransparency = value
	end
})

visualsSections.Highlights:AddColor({
    enabled = true,
    text = "Highlight Fill Color",
    flag = "highlight_fill_color",
    tooltip = "Sets the fill color for player highlights.",
    color = FILL_COLOR,
    trans = 0,
    open = false,
    callback = function(color)
        FILL_COLOR = color
    end
})

visualsSections.Highlights:AddColor({
    enabled = true,
    text = "Highlight Outline Color",
    flag = "highlight_outline_color",
    tooltip = "Sets the outline color for player highlights.",
    color = OUTLINE_COLOR,
    trans = 0,
    open = false,
    callback = function(color)
        OUTLINE_COLOR = color
    end
})

-- Settings Tab
settingsSections.Keybind:AddBind({
	text = "Aimbot Keybind",
	flag = "aimbot_keybind",
	nomouse = false,
	noindicator = false,
	tooltip = "Sets the keybind to activate the aimbot.",
	mode = "hold",
	bind = getgenv().dhlock.keybind,
	risky = false,
	keycallback = function(bind)
	 	getgenv().dhlock.keybind = bind
	end
})
