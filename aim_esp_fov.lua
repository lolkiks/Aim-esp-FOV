--!strict
-- Roblox Luau LocalScript: ESP + Aim Assist + FOV Circle
-- For learning/testing in your own experience.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CONFIG = {
    TeamCheck = true,
    Enabled = true,

    ESP = {
        Enabled = true,
        FillTransparency = 0.65,
        OutlineTransparency = 0,
        Color = Color3.fromRGB(255, 85, 85),
    },

    FOV = {
        Enabled = true,
        Radius = 180,
        Thickness = 2,
        Color = Color3.fromRGB(85, 255, 127),
        Filled = false,
        Transparency = 1,
    },

    Aim = {
        Enabled = true,
        HoldMouseButton2 = true,
        Smoothness = 0.16, -- 0..1 (higher = faster lock)
        TargetPart = "Head",
        MaxDistance = 900,
    },

    ToggleKeys = {
        ToggleMain = Enum.KeyCode.RightShift,
        ToggleESP = Enum.KeyCode.E,
        ToggleAim = Enum.KeyCode.Q,
    },
}

local drawings = {
    FOVCircle = nil :: any,
}

local espByPlayer: {[Player]: Highlight} = {}
local rightMouseHeld = false

local function isValidTarget(player: Player): boolean
    if player == LocalPlayer then
        return false
    end

    if CONFIG.TeamCheck and player.Team ~= nil and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team then
        return false
    end

    local character = player.Character
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then
        return false
    end

    local distance = (Camera.CFrame.Position - root.Position).Magnitude
    return distance <= CONFIG.Aim.MaxDistance
end

local function getTargetPart(player: Player): BasePart?
    local char = player.Character
    if not char then
        return nil
    end

    local preferred = char:FindFirstChild(CONFIG.Aim.TargetPart)
    if preferred and preferred:IsA("BasePart") then
        return preferred
    end

    local fallback = char:FindFirstChild("HumanoidRootPart")
    if fallback and fallback:IsA("BasePart") then
        return fallback
    end

    return nil
end

local function getClosestTargetInFOV(): BasePart?
    local bestPart: BasePart? = nil
    local bestDistanceToMouse = math.huge

    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if isValidTarget(player) then
            local part = getTargetPart(player)
            if part then
                local screenPoint, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local distToMouse = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
                    if distToMouse <= CONFIG.FOV.Radius and distToMouse < bestDistanceToMouse then
                        bestDistanceToMouse = distToMouse
                        bestPart = part
                    end
                end
            end
        end
    end

    return bestPart
end

local function updateFOVCircle()
    if not CONFIG.FOV.Enabled then
        if drawings.FOVCircle then
            drawings.FOVCircle.Visible = false
        end
        return
    end

    if not Drawing then
        return
    end

    if drawings.FOVCircle == nil then
        drawings.FOVCircle = Drawing.new("Circle")
    end

    local circle = drawings.FOVCircle
    circle.Visible = CONFIG.Enabled
    circle.Radius = CONFIG.FOV.Radius
    circle.Thickness = CONFIG.FOV.Thickness
    circle.Color = CONFIG.FOV.Color
    circle.Filled = CONFIG.FOV.Filled
    circle.Transparency = CONFIG.FOV.Transparency
    circle.Position = UserInputService:GetMouseLocation()
end

local function createESP(player: Player)
    if espByPlayer[player] or player == LocalPlayer then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = CONFIG.ESP.Color
    highlight.FillTransparency = CONFIG.ESP.FillTransparency
    highlight.OutlineColor = CONFIG.ESP.Color
    highlight.OutlineTransparency = CONFIG.ESP.OutlineTransparency

    local function attachToCharacter(character: Model)
        highlight.Adornee = character
        highlight.Parent = character
    end

    if player.Character then
        attachToCharacter(player.Character)
    end

    player.CharacterAdded:Connect(function(character)
        task.wait(0.2)
        if highlight.Parent ~= nil then
            attachToCharacter(character)
        end
    end)

    espByPlayer[player] = highlight
end

local function removeESP(player: Player)
    local highlight = espByPlayer[player]
    if highlight then
        highlight:Destroy()
        espByPlayer[player] = nil
    end
end

local function refreshESPVisibility()
    for player, highlight in pairs(espByPlayer) do
        local visible = CONFIG.Enabled and CONFIG.ESP.Enabled and isValidTarget(player)
        highlight.Enabled = visible
        highlight.FillColor = CONFIG.ESP.Color
        highlight.OutlineColor = CONFIG.ESP.Color
        highlight.FillTransparency = CONFIG.ESP.FillTransparency
        highlight.OutlineTransparency = CONFIG.ESP.OutlineTransparency
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    createESP(player)
end

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then
        return
    end

    if input.KeyCode == CONFIG.ToggleKeys.ToggleMain then
        CONFIG.Enabled = not CONFIG.Enabled
    elseif input.KeyCode == CONFIG.ToggleKeys.ToggleESP then
        CONFIG.ESP.Enabled = not CONFIG.ESP.Enabled
    elseif input.KeyCode == CONFIG.ToggleKeys.ToggleAim then
        CONFIG.Aim.Enabled = not CONFIG.Aim.Enabled
    end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightMouseHeld = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightMouseHeld = false
    end
end)

RunService.RenderStepped:Connect(function()
    updateFOVCircle()
    refreshESPVisibility()

    if not CONFIG.Enabled or not CONFIG.Aim.Enabled then
        return
    end

    if CONFIG.Aim.HoldMouseButton2 and not rightMouseHeld then
        return
    end

    local target = getClosestTargetInFOV()
    if target then
        local camPos = Camera.CFrame.Position
        local desired = CFrame.new(camPos, target.Position)
        Camera.CFrame = Camera.CFrame:Lerp(desired, CONFIG.Aim.Smoothness)
    end
end)
