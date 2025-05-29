-- SERVICES 
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- SETTINGS
local aimbotSmoothing = 0
local aimbotFOV = 60
local scanCooldown = 0.15
local aimbotEnabled = true
local hitboxExpanderEnabled = true -- nowy toggle dla hitbox expander

-- VARIABLES
local aiming = false
local currentTarget = nil
local lastScan = 0
local cachedNPCs = {}
local createdESP = {}
local originalFogEnd = Lighting.FogEnd
local originalAtmospheres = {}
local currentHitboxSize = 3 -- domyślny rozmiar jak w GUI

-- HOOK METATABLE TO HIDE HITBOX EXPANDER
local mt = getrawmetatable(game)
local oldIndex = mt.__index
setreadonly(mt, false)

mt.__index = newcclosure(function(self, key)
    if hitboxExpanderEnabled and key == "Size" and self.Name == "Head" and self.Parent and self.Parent.Name == "Male" then
        -- Zwracaj oryginalny rozmiar zamiast powiększonego
        return Vector3.new(1,1,1)
    elseif hitboxExpanderEnabled and key == "Transparency" and self.Name == "Head" and self.Parent and self.Parent.Name == "Male" then
        -- Zwracaj oryginalną przezroczystość (0), nawet jeśli jest 0.5 fizycznie
        return 0
    elseif hitboxExpanderEnabled and key == "Material" and self.Name == "Head" and self.Parent and self.Parent.Name == "Male" then
        return Enum.Material.SmoothPlastic
    elseif hitboxExpanderEnabled and key == "Color" and self.Name == "Head" and self.Parent and self.Parent.Name == "Male" then
        return Color3.new(1,1,1)
    end
    return oldIndex(self, key)
end)

setreadonly(mt, true)

-- HELPER
local function hasAllowedWeapon(npc)
    for _, item in ipairs(npc:GetChildren()) do
        if typeof(item.Name) == "string" and item.Name:match("^AI_") then
            return true
        end
    end
    return false
end

local function isAlive(npc)
    for _, d in ipairs(npc:GetDescendants()) do
        if d:IsA("BallSocketConstraint") then return false end
    end
    return true
end

local function updateAllHitboxes(size)
    for npc, data in pairs(cachedNPCs) do
        local head = data.head
        if head then
            -- Przywróć fizyczną zmianę rozmiaru head
            local oldCFrame = head.CFrame
            head.Size = Vector3.new(size, size, size)
            head.CFrame = oldCFrame
            local esp = head:FindFirstChild("HeadESP")
            if esp then
                esp.Size = head.Size
            end
        end
    end
end

local function resetAllHitboxes()
    for npc, data in pairs(cachedNPCs) do
        local head = data.head
        if head then
            local oldCFrame = head.CFrame
            head.Size = Vector3.new(1,1,1)
            head.CFrame = oldCFrame
            head.Transparency = 0
            head.Material = Enum.Material.SmoothPlastic
            head.Color = Color3.new(1,1,1)
            local esp = head:FindFirstChild("HeadESP")
            if esp then
                esp.Size = head.Size
            end
        end
    end
end

-- ESP + Hitbox Expander (fizycznie powiększamy head)
local function createNpcHeadESP(npc)
    if createdESP[npc] then return end
    local head = npc:FindFirstChild("Head")
    if head and not head:FindFirstChild("HeadESP") then
        -- Fizycznie powiększ hitbox zawsze na aktualny rozmiar
        head.Size = Vector3.new(currentHitboxSize, currentHitboxSize, currentHitboxSize)
        head.Transparency = 0.5
        head.Material = Enum.Material.Neon
        head.Color = Color3.new(1, 0, 0)

        local esp = Instance.new("BoxHandleAdornment")
        esp.Name = "HeadESP"
        esp.Adornee = head
        esp.AlwaysOnTop = true
        esp.ZIndex = 5
        esp.Size = head.Size
        esp.Transparency = 0.5
        esp.Color3 = Color3.new(0, 1, 0)
        esp.Parent = head
        createdESP[npc] = true

        -- Dodaj natychmiastową eliminację przy trafieniu w head
        if not head:FindFirstChild("OneTap") then
            local oneTap = Instance.new("BoolValue")
            oneTap.Name = "OneTap"
            oneTap.Parent = head
            head.Touched:Connect(function(hit)
                -- Każde dotknięcie przez BasePart natychmiast zabija NPC
                if hit:IsA("BasePart") then
                    for _, d in ipairs(npc:GetDescendants()) do
                        if d:IsA("BallSocketConstraint") then
                            d:Destroy()
                        end
                    end
                end
            end)
        end

        task.spawn(function()
            while isAlive(npc) do task.wait(0.5) end
            if esp and esp.Parent then esp:Destroy() end
            createdESP[npc] = nil
        end)
    end
end

-- CACHE NPC (optymalizacja: osobna tabela na głowy)
local npcHeads = {}

local function processNPC(npc)
    if cachedNPCs[npc] then return end
    if npc:IsA("Model") and npc.Name == "Male" and hasAllowedWeapon(npc) and isAlive(npc) then
        local head = npc:FindFirstChild("Head")
        if head then
            cachedNPCs[npc] = {npc = npc, head = head}
            npcHeads[#npcHeads+1] = head
            createNpcHeadESP(npc)
        end
    end
end

workspace.ChildAdded:Connect(function(child)
    task.wait(0.1)
    processNPC(child)
end)

-- Skanuj NPC tylko co 0.2s (optymalizacja FPS)
local lastNpcScan = 0
RunService.Heartbeat:Connect(function()
    if tick() - lastNpcScan > 0.2 then
        lastNpcScan = tick()
        for _, npc in ipairs(workspace:GetChildren()) do
            processNPC(npc)
        end
    end
end)

-- AIMBOT (optymalizacja: najpierw wybierz najbliższego, potem raycast)
RunService.RenderStepped:Connect(function()
    if not aiming or not aimbotEnabled then
        currentTarget = nil
        return
    end

    local mousePos = UserInputService:GetMouseLocation()
    local closestDist = math.huge
    local newTarget = nil

    -- Skanuj tylko co scanCooldown
    if tick() - lastScan > scanCooldown or not currentTarget or not currentTarget:IsDescendantOf(workspace) or not isAlive(currentTarget.Parent) then
        lastScan = tick()
        for _, data in pairs(cachedNPCs) do
            local head = data.head
            if head and head:IsA("BasePart") then
                local screen3D, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local screenPos = Vector2.new(screen3D.X, screen3D.Y)
                    local dist = (screenPos - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
                    if dist < aimbotFOV and dist < closestDist then
                        closestDist = dist
                        newTarget = head
                    end
                end
            end
        end

        -- Sprawdź widoczność tylko dla najbliższego
        if newTarget then
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Blacklist
            rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
            local direction = (newTarget.Position - Camera.CFrame.Position).Unit * 1000
            local result = workspace:Raycast(Camera.CFrame.Position, direction, rayParams)
            if result and result.Instance and result.Instance:IsDescendantOf(newTarget.Parent) then
                currentTarget = newTarget
            else
                currentTarget = nil
            end
        else
            currentTarget = nil
        end
    end

    if currentTarget then
        local head = currentTarget
        local screen3D, onScreen = Camera:WorldToViewportPoint(head.Position)
        if onScreen then
            local mousePos = UserInputService:GetMouseLocation()
            local screenPos = Vector2.new(screen3D.X, screen3D.Y)
            local dx = (screenPos.X - mousePos.X) / math.clamp(aimbotSmoothing, 0.6, 100)
            local dy = (screenPos.Y - mousePos.Y) / math.clamp(aimbotSmoothing, 0.6, 100)
            if typeof(mousemoverel) == "function" then
                mousemoverel(dx, dy)
            end
        end
    end
end)

-- MOUSE INPUT
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aiming = true
    end
end)
UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aiming = false
        currentTarget = nil
    end
end)

-- GUI
local gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
gui.Name = "AimbotMenu"

local function createToggle(text, defaultState, posY, callback)
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 120, 0, 30)
    toggle.Position = UDim2.new(0, 20, 0, posY)
    toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    toggle.TextColor3 = Color3.new(1, 1, 1)
    toggle.Text = text .. ": " .. (defaultState and "ON" or "OFF")
    toggle.Parent = gui

    toggle.MouseButton1Click:Connect(function()
        defaultState = not defaultState
        toggle.Text = text .. ": " .. (defaultState and "ON" or "OFF")
        callback(defaultState)
    end)
end

local function createSlider(text, posY, min, max, initial, callback)
    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(0, 200, 0, 20)
    sliderBar.Position = UDim2.new(0, 20, 0, posY)
    sliderBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    sliderBar.Parent = gui

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((initial - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    sliderFill.Parent = sliderBar

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 0, -20)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Text = text .. ": " .. tostring(initial)
    label.Parent = sliderBar

    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local function move(inputMove)
                local relativeX = math.clamp(inputMove.Position.X - sliderBar.AbsolutePosition.X, 0, sliderBar.AbsoluteSize.X)
                local value = math.floor(min + (relativeX / sliderBar.AbsoluteSize.X) * (max - min))
                sliderFill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
                label.Text = text .. ": " .. tostring(value)
                callback(value)
            end
            local moveConn
            moveConn = UserInputService.InputChanged:Connect(function(inputChanged)
                if inputChanged.UserInputType == Enum.UserInputType.MouseMovement then
                    move(inputChanged)
                end
            end)
            local inputEndConn
            inputEndConn = UserInputService.InputEnded:Connect(function(inputEnded)
                if inputEnded.UserInputType == Enum.UserInputType.MouseButton1 then
                    moveConn:Disconnect()
                    inputEndConn:Disconnect()
                end
            end)
        end
    end)
end

-- TOGGLES
createToggle("Aimbot", aimbotEnabled, 20, function(state)
    aimbotEnabled = state
end)

createToggle("Hitbox Expander", hitboxExpanderEnabled, 60, function(state)
    hitboxExpanderEnabled = state
    if not state then
        resetAllHitboxes()
    else
        updateAllHitboxes(currentHitboxSize)
        for npc, data in pairs(cachedNPCs) do
            local head = data.head
            if head then
                head.Transparency = 0.5
                head.Material = Enum.Material.Neon
                head.Color = Color3.new(1,0,0)
            end
        end
    end
end)

createSlider("Aimbot FOV", 100, 10, 180, aimbotFOV, function(value)
    aimbotFOV = value
end)

-- Pole tekstowe do wpisywania rozmiaru hitboxa + przycisk "Ustaw"
local hitboxSizeInput = Instance.new("TextBox")
hitboxSizeInput.Size = UDim2.new(0, 100, 0, 30)
hitboxSizeInput.Position = UDim2.new(0, 20, 0, 150)
hitboxSizeInput.PlaceholderText = "Size of Head Hitbox"
hitboxSizeInput.Text = ""
hitboxSizeInput.TextColor3 = Color3.new(1, 1, 1)
hitboxSizeInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
hitboxSizeInput.Parent = gui

local setHitboxSizeBtn = Instance.new("TextButton")
setHitboxSizeBtn.Size = UDim2.new(0, 100, 0, 30)
setHitboxSizeBtn.Position = UDim2.new(0, 130, 0, 150)
setHitboxSizeBtn.Text = "Apply"
setHitboxSizeBtn.TextColor3 = Color3.new(1, 1, 1)
setHitboxSizeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
setHitboxSizeBtn.Parent = gui

setHitboxSizeBtn.MouseButton1Click:Connect(function()
    local value = tonumber(hitboxSizeInput.Text)
    if value and value >= 1 and value <= 25 then
        currentHitboxSize = value
        updateAllHitboxes(currentHitboxSize)
    else
        hitboxSizeInput.Text = "MAX 24"
    end
end)
