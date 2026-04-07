-- [[ PRIV HUB - PVP SYSTEM ]] --

-- Rayfield Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Priv Hub",
    LoadingTitle = "Pvp System",
    LoadingSubtitle = "by gg/pjl7",
    ConfigurationSaving = {
        Enabled = false
    }
})

-- Tabs
local AimbotTab = Window:CreateTab("Aimbot")
local ESPTab = Window:CreateTab("ESP")
local MiscTab = Window:CreateTab("Misc")

-- Services
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local Camera       = workspace.CurrentCamera
local LocalPlayer  = Players.LocalPlayer

-- ================= SETTINGS & VARIABLES =================

local AimbotSettings = {
    Enabled            = true,
    TeamCheck          = true,
    FOV                = 225,
    SmoothnessFactor   = 5,
    MaxDistance        = 300,
    MinPrediction      = 0.01,
    MaxPrediction      = 0.08,
}

local target       = nil
local isMouseHeld  = false
local ESPEnabled   = false
local ShowBoxes    = true
local ShowNames    = true
local ESPObjects   = {}
local BoxColor     = Color3.fromRGB(255, 255, 255)
local NameColor    = Color3.fromRGB(255, 255, 255)

-- Referências para as conexões (Essencial para o Self Destruct)
local AimbotConnection
local ESPConnection
local InputBeganConnection
local InputEndedConnection

-- ================= FUNCTIONS =================

local function IsPlayerValid(player)
    if player == LocalPlayer then return false end
    if AimbotSettings.TeamCheck and player.Team == LocalPlayer.Team then return false end

    local char = player.Character
    if not char or not char:FindFirstChild("Head") or not char:FindFirstChild("HumanoidRootPart") then
        return false
    end

    local dist = (char.Head.Position - LocalPlayer.Character.Head.Position).Magnitude
    return dist <= AimbotSettings.MaxDistance
end

local function HasShield(player)
    local char = player.Character
    if not char then return false end

    for _, obj in pairs(char:GetChildren()) do
        if obj:IsA("Model") and obj.Name:match("^Escudo %[.+%]$") then
            return true
        end
    end
    return false
end

local function GetTargetPosition(player)
    local char = player.Character
    if not char then return nil end

    if HasShield(player) then
        local arm = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftArm")
        return arm and arm.Position or char.HumanoidRootPart.Position
    else
        return char.Head.Position
    end
end

local function PredictPosition(pos, velocity, distance)
    local factor = math.clamp(distance / 1000, AimbotSettings.MinPrediction, AimbotSettings.MaxPrediction)
    return pos + (velocity * factor)
end

local function GetClosestTarget()
    local closest, bestScore = nil, AimbotSettings.FOV
    local cursorPos = UIS:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if IsPlayerValid(player) then
            local char = player.Character
            local basePos = GetTargetPosition(player)

            if basePos then
                local distWorld = (char.Head.Position - LocalPlayer.Character.Head.Position).Magnitude
                local predicted = PredictPosition(basePos, char.HumanoidRootPart.Velocity, distWorld)

                local screenPos, onScreen = Camera:WorldToViewportPoint(predicted)
                if onScreen then
                    local dCursor = (Vector2.new(screenPos.X, screenPos.Y) - cursorPos).Magnitude
                    local score = dCursor + distWorld * 0.5

                    if score < bestScore then
                        bestScore = score
                        closest = player
                    end
                end
            end
        end
    end
    return closest
end

local function SmoothMouseMove(screenPos)
    local cursorPos = UIS:GetMouseLocation()
    local dx = (screenPos.X - cursorPos.X) / AimbotSettings.SmoothnessFactor
    local dy = (screenPos.Y - cursorPos.Y) / AimbotSettings.SmoothnessFactor
    if mousemoverel then
        mousemoverel(dx, dy)
    end
end

local function CreateESP(player)
    if player == LocalPlayer then return end

    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Visible = false

    local name = Drawing.new("Text")
    name.Size = 13
    name.Center = true
    name.Outline = true
    name.Visible = false

    ESPObjects[player] = {
        Box = box,
        Name = name
    }
end

-- ================= SELF DESTRUCT =================

local function SelfDestruct()
    -- 1. Desconecta todos os eventos
    if AimbotConnection then AimbotConnection:Disconnect() end
    if ESPConnection then ESPConnection:Disconnect() end
    if InputBeganConnection then InputBeganConnection:Disconnect() end
    if InputEndedConnection then InputEndedConnection:Disconnect() end
    
    -- 2. Limpa os desenhos do ESP (importante para não crashar ou poluir a tela)
    for _, v in pairs(ESPObjects) do
        if v.Box then v.Box:Destroy() end
        if v.Name then v.Name:Destroy() end
    end
    table.clear(ESPObjects)
    
    -- 3. Destrói a UI do Rayfield
    Rayfield:Destroy()
    
    print("Priv Hub: Self Destruct executado com sucesso.")
end

-- ================= UI ELEMENTS =================

-- Aimbot Tab
AimbotTab:CreateToggle({
    Name = "Aimbot",
    CurrentValue = true,
    Callback = function(Value) AimbotSettings.Enabled = Value end
})

AimbotTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = true,
    Callback = function(Value) AimbotSettings.TeamCheck = Value end
})

AimbotTab:CreateSlider({
    Name = "FOV",
    Range = {50, 500},
    Increment = 5,
    CurrentValue = 225,
    Callback = function(Value) AimbotSettings.FOV = Value end
})

AimbotTab:CreateSlider({
    Name = "Smoothness",
    Range = {1, 20},
    Increment = 0.5,
    CurrentValue = 5,
    Callback = function(Value) AimbotSettings.SmoothnessFactor = Value end
})

-- ESP Tab
ESPTab:CreateToggle({
    Name = "ESP Players",
    CurrentValue = false,
    Callback = function(Value)
        ESPEnabled = Value
        if not Value then
            for _, v in pairs(ESPObjects) do
                if v.Box then v.Box.Visible = false end
                if v.Name then v.Name.Visible = false end
            end
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Box",
    CurrentValue = true,
    Callback = function(Value) ShowBoxes = Value end
})

ESPTab:CreateToggle({
    Name = "Show Name",
    CurrentValue = true,
    Callback = function(Value) ShowNames = Value end
})

ESPTab:CreateColorPicker({
    Name = "Box Color",
    Color = Color3.fromRGB(255, 255, 255),
    Callback = function(Value) BoxColor = Value end
})

ESPTab:CreateColorPicker({
    Name = "Name Color",
    Color = Color3.fromRGB(255, 255, 255),
    Callback = function(Value) NameColor = Value end
})

-- Misc Tab
MiscTab:CreateKeybind({
    Name = "Toggle UI",
    CurrentKeybind = "K",
    HoldToInteract = false,
    Callback = function() Rayfield:Toggle() end
})

MiscTab:CreateButton({
    Name = "Self Destruct",
    Callback = function()
        SelfDestruct()
    end
})

-- ================= MAIN LOOPS =================

AimbotConnection = RunService.RenderStepped:Connect(function()
    if AimbotSettings.Enabled and isMouseHeld then
        if (not target) or (not target.Character) or (target.Character:FindFirstChild("Humanoid") and target.Character.Humanoid.Health <= 0) then
            target = GetClosestTarget()
        end

        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local pos = GetTargetPosition(target)
            local distWorld = (target.Character.Head.Position - LocalPlayer.Character.Head.Position).Magnitude
            pos = PredictPosition(pos, target.Character.HumanoidRootPart.Velocity, distWorld)

            local scr, on = Camera:WorldToViewportPoint(pos)
            if on then
                SmoothMouseMove(Vector2.new(scr.X, scr.Y))
            end
        end
    end
end)

ESPConnection = RunService.RenderStepped:Connect(function()
    if not ESPEnabled then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not ESPObjects[player] then CreateESP(player) end

            local char = player.Character
            local hrp = char.HumanoidRootPart
            local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            local esp = ESPObjects[player]

            if onScreen then
                local headPos = Camera:WorldToViewportPoint(char.Head.Position + Vector3.new(0, 0.5, 0))
                local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                local sizeY = math.abs(headPos.Y - legPos.Y)
                local sizeX = sizeY * 0.6

                if ShowBoxes then
                    esp.Box.Size = Vector2.new(sizeX, sizeY)
                    esp.Box.Position = Vector2.new(rootPos.X - sizeX / 2, rootPos.Y - sizeY / 2)
                    esp.Box.Color = BoxColor
                    esp.Box.Visible = true
                else
                    esp.Box.Visible = false
                end

                if ShowNames then
                    esp.Name.Text = player.Name
                    esp.Name.Position = Vector2.new(rootPos.X, rootPos.Y - (sizeY / 2) - 15)
                    esp.Name.Color = NameColor
                    esp.Name.Visible = true
                else
                    esp.Name.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.Name.Visible = false
            end
        end
    end
end)

InputBeganConnection = UIS.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseHeld = true
    end
end)

InputEndedConnection = UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseHeld = false
        target = nil
    end
end)