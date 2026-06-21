-- MECHANIK HUB V13 - УБЕГАНИЕ ОТ УБИЙЦЫ + НЕТ ПРЫЖКОВ В ЛОББИ
local p = game.Players.LocalPlayer
local r = false
local c = 0
local co = {}
local afkMode = true
local farmMode = false
local currentMode = "COINS"
local Murderer = nil
local Sheriff = nil
local Hero = nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local VirtualUser = game:GetService("VirtualUser")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

-- ===== НАСТРОЙКИ =====
local LOBBY_POS = Vector3.new(14.1, 517.0, -25.2)
local LOBBY_RADIUS = 40
local KILL_DISTANCE = 5
local DANGER_DISTANCE = 25
local ESCAPE_DISTANCE = 50
local SHOOT_DISTANCE = 50
local THINK_POINT = Vector3.new(13.8, 507.4, 34.4)
local MAP_POINTS = {
    Vector3.new(14.8, 507.6, 51.4),
    Vector3.new(25.7, 507.6, 49.7),
    Vector3.new(-0.2, 507.6, 48.2)
}

local MAX_RUNTIME = 6 * 3600
local runtime = 0
local autoShutdownEnabled = true
local sessionTime = 0

local path = PathfindingService:CreatePath({
    AgentRadius = 3.5,
    AgentCanJump = true,
    AgentCanClimb = false,
    WaypointSpacing = 3,
})

p.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

local function getRoles()
    pcall(function()
        local roles = ReplicatedStorage:FindFirstChild("GetPlayerData", true):InvokeServer()
        if roles then
            for i, v in pairs(roles) do
                if v.Role == "Murderer" then Murderer = i
                elseif v.Role == "Sheriff" then Sheriff = i
                elseif v.Role == "Hero" then Hero = i
                end
            end
        end
    end)
end

spawn(function()
    while wait(1) do
        getRoles()
    end
end)

local function getKnife(char)
    char = char or p.Character
    if not char then return nil end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") and (v:FindFirstChild("KnifeScriptR15") or v:FindFirstChild("KnifeScriptR6") or v:FindFirstChild("KnifeServer")) then
            return v
        end
    end
    for _, v in ipairs(p.Backpack:GetChildren()) do
        if v:IsA("Tool") and (v:FindFirstChild("KnifeScriptR15") or v:FindFirstChild("KnifeScriptR6") or v:FindFirstChild("KnifeServer")) then
            return v
        end
    end
    return nil
end

local function getGun(char)
    char = char or p.Character
    if not char then return nil end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then
            local name = v.Name:lower()
            if name:find("gun") or name:find("pistol") or name:find("revolver") or name:find("sheriff") then
                return v
            end
            if v:FindFirstChild("GunScriptR15") or v:FindFirstChild("GunScriptR6") or v:FindFirstChild("GunServer") then
                return v
            end
        end
    end
    for _, v in ipairs(p.Backpack:GetChildren()) do
        if v:IsA("Tool") then
            local name = v.Name:lower()
            if name:find("gun") or name:find("pistol") or name:find("revolver") or name:find("sheriff") then
                return v
            end
            if v:FindFirstChild("GunScriptR15") or v:FindFirstChild("GunScriptR6") or v:FindFirstChild("GunServer") then
                return v
            end
        end
    end
    return nil
end

-- ===== УБЕГАНИЕ ОТ УБИЙЦЫ =====
local function escapeFromMurderer(rootPos, murdererPos)
    if not murdererPos then return false end
    local dir = (rootPos - murdererPos).Unit
    local escapePos = rootPos + dir * ESCAPE_DISTANCE + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
    -- Ограничиваем по Y, чтобы не улететь
    escapePos = Vector3.new(escapePos.X, rootPos.Y, escapePos.Z)
    if g and g.sl then g.sl.Text = "🏃 Убегаю от убийцы!" end
    walkToTarget(escapePos)
    return true
end

local function walkToTarget(targetPos)
    local char = p.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end

    if sessionTime > 4 * 3600 then
        hum.WalkSpeed = math.random(13, 14)
    else
        hum.WalkSpeed = 16
    end

    if (root.Position - targetPos).Magnitude < KILL_DISTANCE then
        hum:MoveTo(targetPos)
        return true
    end

    local success = pcall(function()
        path:ComputeAsync(root.Position, targetPos)
    end)
    if not success or path.Status ~= Enum.PathStatus.Success then
        hum:MoveTo(targetPos)
        return true
    end

    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then return false end

    for _, waypoint in ipairs(waypoints) do
        if not r or not farmMode then return false end
        hum:MoveTo(waypoint.Position)
        hum.MoveToFinished:Wait(2)
        if (root.Position - targetPos).Magnitude < KILL_DISTANCE then break end
    end
    return true
end

local function isInLobby(pos)
    return (pos - LOBBY_POS).Magnitude < LOBBY_RADIUS
end

local function isRoundActive()
    local coins = workspace:FindFirstChild("Coins") or workspace
    for _, v in ipairs(coins:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name:lower():find("coin") or v.Name:lower():find("money")) then
            if v:FindFirstChild("TouchInterest") and v.Parent then
                return true
            end
        end
    end
    return false
end

local function spamJump()
    local char = p.Character
    if not char then return end
    -- НЕ ПРЫГАЕМ В ЛОББИ
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and isInLobby(root.Position) then
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
end

local function isMurdererNear(rootPos)
    if not Murderer or Murderer == p.Name then return false end
    local target = Players:FindFirstChild(Murderer)
    if not target or not target.Character then return false end
    local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not tRoot then return false end
    return (rootPos - tRoot.Position).Magnitude < DANGER_DISTANCE
end

local function getMurdererPos()
    if not Murderer then return nil end
    local target = Players:FindFirstChild(Murderer)
    if not target or not target.Character then return nil end
    local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not tRoot then return nil end
    return tRoot.Position
end

local function isSheriffOrHeroNear(rootPos)
    if Sheriff then
        local target = Players:FindFirstChild(Sheriff)
        if target and target.Character then
            local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
            if tRoot and (rootPos - tRoot.Position).Magnitude < DANGER_DISTANCE then
                return true
            end
        end
    end
    if Hero then
        local target = Players:FindFirstChild(Hero)
        if target and target.Character then
            local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
            if tRoot and (rootPos - tRoot.Position).Magnitude < DANGER_DISTANCE then
                return true
            end
        end
    end
    return false
end

local stuckCheck = {}
local function isStuck(root)
    local pos = root.Position
    local last = stuckCheck.lastPos or pos
    local dist = (pos - last).Magnitude
    stuckCheck.lastPos = pos
    if dist < 0.5 then
        stuckCheck.timer = (stuckCheck.timer or 0) + 0.2
    else
        stuckCheck.timer = 0
    end
    if stuckCheck.timer > 2 then
        stuckCheck.timer = 0
        return true
    end
    return false
end

local function randomThink()
    if math.random(1, 100) < 15 then
        if g and g.sl then g.sl.Text = "🤔 Задумался..." end
        task.wait(math.random(3, 8))
        if g and g.sl then g.sl.Text = "Продолжаю..." end
    end
end

local function shouldMakeMistake()
    return math.random(1, 100) < 8
end

local function randomMouseMove()
    pcall(function()
        local mouse = p:GetMouse()
        if mouse then
            mouse.Move(Vector2.new(math.random(-50, 50), math.random(-30, 30)))
        end
    end)
end

local function voteForMap()
    local char = p.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    if not isInLobby(root.Position) then
        return
    end
    if isRoundActive() then
        return
    end

    if g and g.sl then g.sl.Text = "🗳 Иду выбирать карту..." end

    walkToTarget(THINK_POINT)
    local waitTime = math.random(2, 5)
    if g and g.sl then g.sl.Text = "🤔 Думаю... " .. waitTime .. "с" end
    task.wait(waitTime)

    for _, pos in ipairs(MAP_POINTS) do
        randomMouseMove()
        task.wait(math.random(0.3, 1))
    end

    local chosenMap = MAP_POINTS[math.random(1, #MAP_POINTS)]
    if g and g.sl then g.sl.Text = "🗳 Голосую за карту" end
    walkToTarget(chosenMap)
    task.wait(math.random(1, 2))

    if g and g.sl then g.sl.Text = "✅ Проголосовал, жду раунд" end
end

local function sheriffMode()
    while r and farmMode and Sheriff == p.Name do
        task.wait(0.1)
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root or hum.Health <= 0 then continue end

        local gun = getGun(char)
        if not gun then
            if g and g.sl then g.sl.Text = "🔫 Ищу пистолет..." end
            for _, v in ipairs(p.Backpack:GetChildren()) do
                if v:IsA("Tool") then
                    local name = v.Name:lower()
                    if name:find("gun") or name:find("pistol") or name:find("revolver") or name:find("sheriff") then
                        v.Parent = char
                        gun = v
                        break
                    end
                end
            end
            if not gun then
                task.wait(1)
                continue
            end
        end

        pcall(function()
            hum:EquipTool(gun)
        end)

        if not Murderer then
            if g and g.sl then g.sl.Text = "🔍 Убийца не найден" end
            task.wait(1)
            continue
        end

        local target = Players:FindFirstChild(Murderer)
        if not target or not target.Character then
            if g and g.sl then g.sl.Text = "🔍 Убийца мёртв" end
            task.wait(1)
            continue
        end

        local tChar = target.Character
        local tRoot = tChar:FindFirstChild("HumanoidRootPart")
        local tHum = tChar:FindFirstChildOfClass("Humanoid")
        if not tRoot or not tHum or tHum.Health <= 0 then
            if g and g.sl then g.sl.Text = "🔍 Убийца мёртв!" end
            task.wait(1)
            continue
        end

        local dist = (root.Position - tRoot.Position).Magnitude

        if dist > SHOOT_DISTANCE then
            if g and g.sl then g.sl.Text = "🔫 Иду к убийце..." end
            walkToTarget(tRoot.Position)
            continue
        end

        if g and g.sl then g.sl.Text = "🎯 Навожусь..." end
        pcall(function()
            workspace.CurrentCamera.CFrame = CFrame.lookAt(root.Position, tRoot.Position)
        end)

        task.wait(math.random(0.5, 1.5))
        randomMouseMove()

        if g and g.sl then g.sl.Text = "💨 Промах!" end
        pcall(function()
            local fakeTarget = tRoot.Position + Vector3.new(math.random(-10, 10), math.random(-5, 5), math.random(-10, 10))
            workspace.CurrentCamera.CFrame = CFrame.lookAt(root.Position, fakeTarget)
        end)
        pcall(function()
            if gun:FindFirstChild("Shoot") and gun:FindFirstChild("Shoot"):IsA("RemoteEvent") then
                gun:FindFirstChild("Shoot"):FireServer()
            else
                gun:Activate()
            end
        end)
        task.wait(0.5)

        if math.random(1, 100) <= 50 then
            if g and g.sl then g.sl.Text = "🎯 ПОПАЛ!" end
            pcall(function()
                workspace.CurrentCamera.CFrame = CFrame.lookAt(root.Position, tRoot.Position)
            end)
            pcall(function()
                if gun:FindFirstChild("Shoot") and gun:FindFirstChild("Shoot"):IsA("RemoteEvent") then
                    gun:FindFirstChild("Shoot"):FireServer()
                else
                    gun:Activate()
                end
            end)
        else
            if g and g.sl then g.sl.Text = "💨 Промах!" end
        end
        task.wait(1)
    end
end

local function autoKill()
    while r and farmMode and Murderer == p.Name do
        wait(0.05)
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root or hum.Health <= 0 then continue end

        -- Проверяем, не нужно ли убегать от шерифа/героя
        if isSheriffOrHeroNear(root.Position) then
            if g and g.sl then g.sl.Text = "🏃 Убегаю от шерифа!" end
            local escapePos = root.Position + Vector3.new(math.random(-50, 50), 0, math.random(-50, 50))
            walkToTarget(escapePos)
            wait(0.5)
            continue
        end

        if isStuck(root) then
            spamJump()
            wait(0.05)
            spamJump()
        end

        local knife = getKnife(char)
        if not knife then wait(0.3) continue end
        local handle = knife:FindFirstChild("Handle")
        if not handle then continue end

        local target, tRoot = nil, nil
        local minDist = math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == p or plr.Name == Sheriff or plr.Name == Hero then continue end
            local tChar = plr.Character
            if not tChar then continue end
            local tR = tChar:FindFirstChild("HumanoidRootPart")
            local tH = tChar:FindFirstChildOfClass("Humanoid")
            if not tR or not tH or tH.Health <= 0 then continue end
            if isInLobby(tR.Position) then continue end

            local dist = (root.Position - tR.Position).Magnitude
            if dist < minDist then
                minDist = dist
                target = plr
                tRoot = tR
            end
        end

        if not target then
            if g and g.sl then g.sl.Text = "🔪 Нет целей" end
            wait(1)
            continue
        end

        if (root.Position - tRoot.Position).Magnitude > KILL_DISTANCE then
            if g and g.sl then g.sl.Text = "🔪 Иду к " .. target.Name end
            walkToTarget(tRoot.Position)
        end

        if (root.Position - tRoot.Position).Magnitude <= KILL_DISTANCE then
            knife.Parent = char
            pcall(function() knife:Activate() end)
            pcall(function()
                firetouchinterest(handle, tRoot, 0)
                wait(0.05)
                firetouchinterest(handle, tRoot, 1)
            end)
            if g and g.sl then g.sl.Text = "💀 Убил " .. target.Name end
            wait(0.3)
        end
        wait(0.1)
    end
end

-- ===== ОБНОВЛЁННЫЙ ЦИКЛ ПРЫЖКОВ (С УБЕГАНИЕМ) =====
spawn(function()
    while true do
        wait(0.2)
        if not farmMode or not r then continue end
        local char = p.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        -- НИКАКИХ ПРЫЖКОВ В ЛОББИ
        if isInLobby(root.Position) then
            continue
        end

        -- Если ты НЕ убийца и убийца рядом — УБЕГАЕМ (а не прыгаем)
        if Murderer ~= p.Name and isMurdererNear(root.Position) then
            local murdererPos = getMurdererPos()
            if murdererPos then
                escapeFromMurderer(root.Position, murdererPos)
                continue
            end
        end

        -- Если ты убийца и рядом шериф/герой — УБЕГАЕМ
        if Murderer == p.Name and isSheriffOrHeroNear(root.Position) then
            if g and g.sl then g.sl.Text = "🏃 Убегаю от шерифа!" end
            local escapePos = root.Position + Vector3.new(math.random(-50, 50), 0, math.random(-50, 50))
            walkToTarget(escapePos)
            wait(0.5)
            continue
        end

        -- Если застрял — прыгаем (только если не в лобби)
        if isStuck(root) then
            spamJump()
            wait(0.05)
            spamJump()
            continue
        end

        -- Случайные прыжки
        if math.random(1, 100) < 15 then
            spamJump()
        end
    end
end)

function h()
    local c = p.Character
    if not c or not c.Parent then p.CharacterAdded:Wait() c = p.Character end
    return c
end

function resetCounter()
    c = 0
    co = {}
    if g and g.cl then g.cl.Text = "0 / 45" end
end

function F()
    if r then return end
    r = true
    resetCounter()
    if g then
        g.sl.Text = "Работаю"
        g.cl.Text = "0 / 45"
    end
    runtime = 0
    sessionTime = 0

    spawn(function()
        while r do
            task.wait(0.1)

            runtime = runtime + 0.1
            sessionTime = sessionTime + 0.1
            if runtime >= MAX_RUNTIME and autoShutdownEnabled then
                if g then g.sl.Text = "⏰ 6 часов прошло! Остановка..." end
                toggleFarm()
                StarterGui:SetCore("SendNotification", {
                    Title = "MECHANIK HUB",
                    Text = "Автовыключение: 6 часов прошло. Отдыхай, братан!",
                    Duration = 5
                })
                break
            end

            if g and g.timer then
                local hours = math.floor(runtime / 3600)
                local mins = math.floor((runtime % 3600) / 60)
                local secs = math.floor(runtime % 60)
                g.timer.Text = string.format("⏱ %02d:%02d:%02d", hours, mins, secs)
            end

            if Sheriff == p.Name then
                sheriffMode()
                continue
            end

            if Murderer == p.Name then
                autoKill()
                continue
            end

            local ch = h()
            if not ch or not ch.Parent then resetCounter() continue end
            local m = ch:FindFirstChild("Humanoid")
            if not m or m.Health <= 0 then
                if g then g.sl.Text = "Меня убили!" end
                resetCounter()
                wait(2)
                continue
            end
            if c >= 45 then
                resetCounter()
                wait(1)
                continue
            end

            local coins = workspace:FindFirstChild("Coins") or workspace
            local rt = ch:FindFirstChild("HumanoidRootPart")
            if not rt then continue end

            if isInLobby(rt.Position) then
                if g then g.sl.Text = "В лобби, жду..." end
                randomThink()
                if not isRoundActive() then
                    voteForMap()
                end
                wait(2)
                continue
            end

            if math.random(1, 100) < 5 then
                if g then g.sl.Text = "🧐 Осматриваюсь..." end
                randomMouseMove()
                task.wait(math.random(3, 8))
                if g then g.sl.Text = "Продолжаю..." end
            end

            local target = nil
            local minDist = math.huge
            for _, v in ipairs(coins:GetDescendants()) do
                if v:IsA("BasePart") and (v.Name:lower():find("coin") or v.Name:lower():find("money")) and v:FindFirstChild("TouchInterest") and v.Parent then
                    if not co[v] then
                        local dist = (v.Position - rt.Position).Magnitude
                        if dist < minDist then
                            minDist = dist
                            target = v
                        end
                    end
                end
            end

            if target and target.Parent then
                if shouldMakeMistake() then
                    if g then g.sl.Text = "👀 Промахнулся мимо монеты" end
                    randomMouseMove()
                    task.wait(math.random(1, 3))
                    continue
                end

                walkToTarget(target.Position)
                if (rt.Position - target.Position).Magnitude < 10 then
                    c = c + 1
                    co[target] = true
                    if g then g.cl.Text = c .. " / 45" end
                end
            else
                if g then g.sl.Text = "Нет монет" end
                wait(0.5)
            end
        end
    end)
end

function S()
    r = false
    resetCounter()
    if g then g.sl.Text = "Остановлен" end
end

function toggleAfk()
    afkMode = not afkMode
    if afkMode then
        if afkBtn then afkBtn.BackgroundColor3 = Color3.fromRGB(0,200,0) afkBtn.Text = "🛡️ Анти-АФК ВКЛ" end
        if afkStatus then afkStatus.Text = "🟢 АНТИ АФК ВКЛ" afkStatus.TextColor3 = Color3.fromRGB(0,255,0) end
    else
        if afkBtn then afkBtn.BackgroundColor3 = Color3.fromRGB(80,80,80) afkBtn.Text = "🛡️ Анти-АФК" end
        if afkStatus then afkStatus.Text = "🔴 АНТИ АФК ВЫКЛ" afkStatus.TextColor3 = Color3.fromRGB(255,0,0) end
    end
end

function toggleFarm()
    farmMode = not farmMode
    if farmMode then
        if farmBtn then farmBtn.BackgroundColor3 = Color3.fromRGB(0,200,0) farmBtn.Text = "🚀 Фарм ВКЛ" end
        F()
    else
        if farmBtn then farmBtn.BackgroundColor3 = Color3.fromRGB(80,80,80) farmBtn.Text = "🚀 Фарм" end
        S()
    end
end

function setMode(mode)
    currentMode = mode
    if mode == "COINS" then
        if modeBtnCoins then modeBtnCoins.BackgroundColor3 = Color3.fromRGB(0,200,100) modeBtnCoins.Text = "🪙 Монеты ВКЛ" end
        if modeBtnBalls then modeBtnBalls.BackgroundColor3 = Color3.fromRGB(80,80,80) modeBtnBalls.Text = "🏀 Мячи" end
    else
        if modeBtnBalls then modeBtnBalls.BackgroundColor3 = Color3.fromRGB(0,200,100) modeBtnBalls.Text = "🏀 Мячи ВКЛ" end
        if modeBtnCoins then modeBtnCoins.BackgroundColor3 = Color3.fromRGB(80,80,80) modeBtnCoins.Text = "🪙 Монеты" end
    end
end

-- ==================== GUI ====================
local pg = p:FindFirstChild("PlayerGui")
if not pg then
    pg = Instance.new("PlayerGui")
    pg.Name = "PlayerGui"
    pg.Parent = p
    wait(0.5)
end
local old = pg:FindFirstChild("MECHANIK_HUB")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "MECHANIK_HUB"
gui.ResetOnSpawn = false
gui.Parent = pg

local f = Instance.new("Frame")
f.Size = UDim2.new(0, 230, 0, 320)
f.Position = UDim2.new(0.5, -115, 0.5, -160)
f.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
f.BackgroundTransparency = 0.1
f.BorderSizePixel = 2
f.BorderColor3 = Color3.fromRGB(0, 255, 200)
f.Active = true
f.Draggable = true
f.Parent = gui

local cr = Instance.new("UICorner")
cr.CornerRadius = UDim.new(0, 12)
cr.Parent = f

local tl = Instance.new("TextLabel")
tl.Size = UDim2.new(1, 0, 0, 25)
tl.Position = UDim2.new(0, 0, 0, 5)
tl.BackgroundTransparency = 1
tl.Text = "MECHANIK HUB V13"
tl.TextColor3 = Color3.fromRGB(0, 255, 200)
tl.TextScaled = true
tl.Font = Enum.Font.GothamBold
tl.Parent = f

local sl = Instance.new("TextLabel")
sl.Size = UDim2.new(1, 0, 0, 20)
sl.Position = UDim2.new(0, 0, 0, 35)
sl.BackgroundTransparency = 1
sl.Text = "Готов"
sl.TextColor3 = Color3.fromRGB(255, 255, 255)
sl.TextScaled = true
sl.Font = Enum.Font.Gotham
sl.Parent = f

local cl = Instance.new("TextLabel")
cl.Size = UDim2.new(1, 0, 0, 20)
cl.Position = UDim2.new(0, 0, 0, 60)
cl.BackgroundTransparency = 1
cl.Text = "0 / 45"
cl.TextColor3 = Color3.fromRGB(255, 215, 0)
cl.TextScaled = true
cl.Font = Enum.Font.GothamBold
cl.Parent = f

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, 0, 0, 20)
timerLabel.Position = UDim2.new(0, 0, 0, 85)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "⏱ 00:00:00"
timerLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.Gotham
timerLabel.Parent = f

local y = 110
local function addButton(text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.Parent = f
    local cr2 = Instance.new("UICorner")
    cr2.CornerRadius = UDim.new(0, 6)
    cr2.Parent = btn
    btn.MouseButton1Click:Connect(callback)
    y = y + 38
    return btn
end

farmBtn = addButton("🚀 Фарм", toggleFarm)
afkBtn = addButton("🛡️ Анти-АФК", toggleAfk)
modeBtnCoins = addButton("🪙 Монеты", function() setMode("COINS") end)
modeBtnBalls = addButton("🏀 Мячи", function() setMode("BALLS") end)

local afkStatus = Instance.new("TextLabel")
afkStatus.Size = UDim2.new(0.9, 0, 0, 20)
afkStatus.Position = UDim2.new(0.05, 0, 0, y)
afkStatus.BackgroundTransparency = 1
afkStatus.Text = "🟢 АНТИ АФК ВКЛ"
afkStatus.TextColor3 = Color3.fromRGB(0, 255, 0)
afkStatus.TextScaled = true
afkStatus.Font = Enum.Font.Gotham
afkStatus.Parent = f
y = y + 25

g = { sl = sl, cl = cl, timer = timerLabel }
print("MECHANIK HUB V13 загружен! Убегание от убийцы + нет прыжков в лобби.")
