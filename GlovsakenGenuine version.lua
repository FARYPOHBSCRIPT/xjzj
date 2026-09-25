-- =========================================================
-- LOST: SANDBOX 手机玩家终极版 (无文字ESP + 全套防漏报)
-- =========================================================

repeat task.wait() until game:IsLoaded()
task.wait(2)

local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local workspaceService = game:GetService("Workspace")
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpService = game:GetService("HttpService")

local clientPlayer = playersService.LocalPlayer

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "LOST Sentinel",
    Icon = "shield",
    Author = "Ultimate Fix",
    Folder = "LostSandboxScript",
    Size = UDim2.fromOffset(300, 420),
    Transparent = false,
    Theme = "Dark",
    Resizable = false,
    SideBarWidth = 110,
})

Window:SetToggleKey(Enum.KeyCode.K)

Window:EditOpenButton({
    Title = "Sentinel",
    Icon = "shield",
    OnlyMobile = true,
    Enabled = true,
    Draggable = true,
})

---------------------------------------------------------
-- 全局配置
---------------------------------------------------------
local Config = {
    AutoBlockOn = false,
    BlockCooldown = 1.0,
    LastBlockTime = 0,
    BlockButtonName = "block",
    ShowHitboxOnAttack = false,
    HitboxSize = 3,
    HitboxTransparency = 0.2,
    HitboxDuration = 0.3,
    HitboxSegments = 3,
    SegmentDelay = 0.1,
    OffsetY = 2,
    OffsetZ = 3,
    EnableToolDetection = true,
    EnableAnimDetection = true,
    EnableHealthFallback = true,
    BruteForceMode = true,
    MaxAttackDistance = 15,
    FacingCheckOn = false,
    FacingThreshold = 0.3,
    DebugAnimations = false,
    IgnoreKeywords = "walk,run,idle,fall,jump,climb,swim,sit,laugh,emote,interact,use,fix,repair,equip,drop",
    ESPOn = false,
    ESPShowKillers = true,
    ESPShowSurvivors = true,
    ESPShowMedkits = true,
    InfiniteStaminaOn = false,
}

local function Notify(title, content)
    WindUI:Notify({ Title = title, Content = content, Duration = 3 })
end

---------------------------------------------------------
-- 配置文件管理
---------------------------------------------------------
local CONFIG_FILE = "LostSentinel_Config.json"

local function SaveConfig()
    if not writefile then Notify("保存失败", "不支持 writefile"); return end
    local success, err = pcall(function() writefile(CONFIG_FILE, httpService:JSONEncode(Config)) end)
    if success then Notify("配置保存", "所有设置已成功保存到本地！") else Notify("保存失败", tostring(err)) end
end

local function LoadConfig()
    if not readfile or not isfile then Notify("加载失败", "不支持文件读取"); return end
    if not isfile(CONFIG_FILE) then Notify("加载失败", "未找到配置文件"); return end
    local success, data = pcall(function() return httpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if success and type(data) == "table" then
        for k, v in pairs(data) do if Config[k] ~= nil then Config[k] = v end end
        Notify("配置加载", "配置已加载！部分滑块需重开界面生效。")
    else
        Notify("加载失败", "配置文件损坏")
    end
end

---------------------------------------------------------
-- 阵营判定
---------------------------------------------------------
local function IsKillerCharacter(char)
    if Config.BruteForceMode then
        local plr = playersService:GetPlayerFromCharacter(char)
        if not plr or plr == clientPlayer then
            if char.Parent and char.Parent.Name:lower():find("survivor") then return false end
            return true
        end
        return false
    end
    local parent = char.Parent
    if not parent then return false end
    if parent.Name:lower():find("killer") or char.Name:lower():find("killer") then return true end
    return false
end

---------------------------------------------------------
-- 1. ESP 系统 (已移除文字)
---------------------------------------------------------
local espHighlights = {}

local function CreateESP(target, isKiller, isMedkit)
    if not target:IsA("Model") and not target:IsA("BasePart") then return end
    if espHighlights[target] then espHighlights[target]:Destroy() end

    local highlight = Instance.new("Highlight")
    highlight.Name = "LostESP"
    highlight.Adornee = target
    if isMedkit then highlight.FillColor = Color3.fromRGB(0, 200, 255)
    elseif isKiller then highlight.FillColor = Color3.fromRGB(255, 50, 50)
    else highlight.FillColor = Color3.fromRGB(50, 255, 50) end
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = target

    espHighlights[target] = highlight
end

local function UpdateESP()
    if not Config.ESPOn then
        for _, h in pairs(espHighlights) do h:Destroy() end
        espHighlights = {}
        return
    end

    local function ScanFolder(folderName, isKiller)
        local folder = workspaceService:FindFirstChild("Players") and workspaceService.Players:FindFirstChild(folderName) or workspaceService:FindFirstChild(folderName)
        if folder then
            for _, target in ipairs(folder:GetChildren()) do
                if target:IsA("Model") and target:FindFirstChild("HumanoidRootPart") then
                    if not espHighlights[target] then CreateESP(target, isKiller, false) end
                end
            end
        end
    end

    if Config.ESPShowKillers then ScanFolder("Killers", true) end
    if Config.ESPShowSurvivors then ScanFolder("Survivors", false) end

    if Config.ESPShowMedkits then
        for _, folder in ipairs({ workspaceService:FindFirstChild("Items"), workspaceService:FindFirstChild("Medkits"), workspaceService }) do
            if folder then
                for _, v in ipairs(folder:GetChildren()) do
                    local n = v.Name:lower()
                    if n:find("med") or n:find("health") or n:find("heal") or n:find("kit") then
                        if not espHighlights[v] then CreateESP(v, false, true) end
                    end
                end
            end
        end
    end

    -- 清理已消失的对象
    for target, highlight in pairs(espHighlights) do
        if not target.Parent then
            highlight:Destroy()
            espHighlights[target] = nil
        end
    end
end

task.spawn(function() while task.wait(0.5) do UpdateESP() end end)

---------------------------------------------------------
-- 2. 分段脉冲攻击指示器 (fart风格)
---------------------------------------------------------
local HitboxFolder = nil
local currentSequenceToken = 0

local function ShowAttackHitbox(killerChar)
    if not Config.ShowHitboxOnAttack then return end
    local killerHRP = killerChar:FindFirstChild("HumanoidRootPart")
    local myHRP = clientPlayer.Character and clientPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not killerHRP or not myHRP then return end

    currentSequenceToken = currentSequenceToken + 1
    local myToken = currentSequenceToken

    if HitboxFolder then HitboxFolder:Destroy() end
    HitboxFolder = Instance.new("Folder")
    HitboxFolder.Name = "LostHitboxSegments"
    HitboxFolder.Parent = workspaceService

    local dirToPlayer = (myHRP.Position - killerHRP.Position).Unit
    local startPos = killerHRP.Position + Vector3.new(0, Config.OffsetY, 0)

    task.spawn(function()
        for i = 1, Config.HitboxSegments do
            if myToken ~= currentSequenceToken then return end
            if i > 1 then task.wait(Config.SegmentDelay) end
            if myToken ~= currentSequenceToken then return end

            local part = Instance.new("Part")
            part.Name = "HitboxSegment_" .. i
            part.Anchored = true; part.CanCollide = false
            part.Material = Enum.Material.ForceField
            part.Color = Color3.fromRGB(255, 255, 255)
            part.Transparency = Config.HitboxTransparency
            part.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
            part.CastShadow = false; part.Parent = HitboxFolder

            local distance = Config.OffsetZ + (i - 1) * (Config.HitboxSize * 1.5)
            part.CFrame = CFrame.new(startPos + dirToPlayer * distance)

            task.delay(Config.HitboxDuration, function() if part and part.Parent then part:Destroy() end end)
        end
    end)
end

---------------------------------------------------------
-- 3. 安全的格挡逻辑
---------------------------------------------------------
local networkRemote = replicatedStorage:FindFirstChild("Modules") 
    and replicatedStorage.Modules:FindFirstChild("Network") 
    and replicatedStorage.Modules.Network:FindFirstChild("RemoteEvent")

local function FireBlockLocalEvent()
    local playerGui = clientPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible and obj.Active then
            if obj.Name:lower() == Config.BlockButtonName:lower() then
                if getconnections then
                    local success, connections = pcall(getconnections, obj.MouseButton1Click)
                    if success and connections then
                        for _, conn in ipairs(connections) do pcall(function() conn:Fire() end) end
                        return true
                    end
                end
                pcall(function() obj:Activated() end)
                return true
            end
        end
    end
    return false
end

local function FireBlock()
    local localSuccess = FireBlockLocalEvent()
    if not localSuccess and networkRemote then
        pcall(function() networkRemote:FireServer("UseActorAbility", { buffer.fromstring("\"Block\"") }) end)
    end
end

---------------------------------------------------------
-- 4. Attack 综合检测核心逻辑
---------------------------------------------------------
local function IsValidAttack(killerChar)
    local myHRP = clientPlayer.Character and clientPlayer.Character:FindFirstChild("HumanoidRootPart")
    local killerHRP = killerChar:FindFirstChild("HumanoidRootPart")
    if not myHRP or not killerHRP then return false end
    
    local dist = (myHRP.Position - killerHRP.Position).Magnitude
    if dist > Config.MaxAttackDistance then return false end
    
    if Config.FacingCheckOn then
        local dirToMe = (myHRP.Position - killerHRP.Position).Unit
        local dot = killerHRP.CFrame.LookVector:Dot(dirToMe)
        if dot < Config.FacingThreshold then return false end
    end
    return true
end

local function AttemptAutoBlock(killerChar, isFallback)
    if not IsValidAttack(killerChar) then return end
    ShowAttackHitbox(killerChar)
    if not Config.AutoBlockOn then return end

    local now = tick()
    if now < Config.LastBlockTime + Config.BlockCooldown then return end
    FireBlock()
    Config.LastBlockTime = now
    if isFallback then print("[Sentinel] 血量兜底触发了格挡！") end
end

---------------------------------------------------------
-- 5. 杀手监听 (工具 + 动画 + 血量兜底)
---------------------------------------------------------
local hookedHealth = {}

local function SetupKillerHooks(killerChar)
    if not IsKillerCharacter(killerChar) then return end
    
    killerChar.DescendantAdded:Connect(function(desc)
        if desc:IsA("Tool") then 
            desc.Activated:Connect(function() 
                if Config.EnableToolDetection then AttemptAutoBlock(killerChar) end
            end) 
        end
    end)
    local currentTool = killerChar:FindFirstChildOfClass("Tool")
    if currentTool and Config.EnableToolDetection then
        currentTool.Activated:Connect(function() AttemptAutoBlock(killerChar) end)
    end

    local humanoid = killerChar:FindFirstChildOfClass("Humanoid")
    if humanoid and Config.EnableAnimDetection then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            animator.AnimationPlayed:Connect(function(track)
                if Config.DebugAnimations then print("[动画调试]", track.Animation.Name) end

                local animName = track.Animation and track.Animation.Name:lower() or ""
                local isIgnored = false
                for word in string.gmatch(Config.IgnoreKeywords, '([^,]+)') do
                    if animName:find(word:lower():gsub("^%s*(.-)%s*$", "%1")) then isIgnored = true; break end
                end
                if not isIgnored then AttemptAutoBlock(killerChar) end
            end)
        end
    end
end

local function SetupPlayerHealthHook()
    local myChar = clientPlayer.Character
    if myChar then
        local humanoid = myChar:FindFirstChildOfClass("Humanoid")
        if humanoid and not hookedHealth[myChar] then
            hookedHealth[myChar] = true
            humanoid.HealthChanged:Connect(function(newHealth)
                local oldHealth = humanoid:GetAttribute("LastHealth") or newHealth
                humanoid:SetAttribute("LastHealth", newHealth)
                
                if newHealth < oldHealth and Config.EnableHealthFallback and Config.ShowHitboxOnAttack then
                    print("[Sentinel] 玩家掉血！触发兜底检测")
                    local closestKiller, minDist = nil, math.huge
                    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
                    if myHRP then
                        for _, k in ipairs(workspaceService:GetDescendants()) do
                            if k:IsA("Model") and k:FindFirstChild("Humanoid") and k:FindFirstChild("HumanoidRootPart") and k ~= myChar then
                                if IsKillerCharacter(k) then
                                    local d = (myHRP.Position - k.HumanoidRootPart.Position).Magnitude
                                    if d < minDist then minDist = d; closestKiller = k end
                                end
                            end
                        end
                    end
                    if closestKiller then AttemptAutoBlock(closestKiller, true) end
                end
            end)
        end
    end
end

clientPlayer.CharacterAdded:Connect(function() task.wait(1); SetupPlayerHealthHook() end)
if clientPlayer.Character then SetupPlayerHealthHook() end

for _, desc in ipairs(workspaceService:GetDescendants()) do
    if desc:IsA("Model") and desc:FindFirstChild("Humanoid") and desc:FindFirstChild("HumanoidRootPart") then
        if desc ~= clientPlayer.Character then SetupKillerHooks(desc) end
    end
end

workspaceService.DescendantAdded:Connect(function(desc)
    if desc:IsA("Model") and desc:FindFirstChild("Humanoid") and desc:FindFirstChild("HumanoidRootPart") then
        if desc ~= clientPlayer.Character then task.wait(0.5); SetupKillerHooks(desc) end
    end
end)

---------------------------------------------------------
-- 6. 无限体力逻辑
---------------------------------------------------------
task.spawn(function()
    while task.wait(0.2) do
        if not Config.InfiniteStaminaOn then continue end
        local char = clientPlayer.Character
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("NumberValue") or v:IsA("IntValue") then
                    local n = v.Name:lower()
                    if n:find("stamina") or n:find("energy") or n:find("endurance") then v.Value = 100 end
                end
            end
        end
    end
end)

---------------------------------------------------------
-- 7. UI 界面
---------------------------------------------------------
local SentinelTab = Window:Tab({ Title = "Sentinel", Icon = "shield" })

local ESPSection = SentinelTab:Section({ Title = "ESP 透视 (纯高亮)", Opened = true })
ESPSection:Toggle({ Title = "启用 ESP", Default = false, Callback = function(state) Config.ESPOn = state end })
ESPSection:Toggle({ Title = "显示杀手 (红)", Default = true, Callback = function(state) Config.ESPShowKillers = state end })
ESPSection:Toggle({ Title = "显示幸存者 (绿)", Default = true, Callback = function(state) Config.ESPShowSurvivors = state end })
ESPSection:Toggle({ Title = "显示医疗包 (青)", Default = true, Callback = function(state) Config.ESPShowMedkits = state end })

SentinelTab:Divider()

local BlockSection = SentinelTab:Section({ Title = "Attack 检测格挡", Opened = true })
BlockSection:Toggle({ Title = "启用自动格挡", Default = false, Callback = function(state) Config.AutoBlockOn = state end })
BlockSection:Slider({ Title = "格挡冷却 (秒)", Step = 0.1, Value = { Min = 0.1, Max = 3.0, Default = 1.0 }, Callback = function(value) Config.BlockCooldown = value end })
BlockSection:Input({ Title = "格挡按钮名字", Value = "block", Callback = function(text) if text and text ~= "" then Config.BlockButtonName = text; Notify("提示", "已改为: " .. text) end end })
BlockSection:Button({ Title = "手动触发格挡 (测试用)", Callback = function() FireBlock() end })

SentinelTab:Divider()
local HitboxSection = SentinelTab:Section({ Title = "Attack 检测参数", Opened = true })
HitboxSection:Toggle({ Title = "启用工具检测", Default = true, Callback = function(state) Config.EnableToolDetection = state end })
HitboxSection:Toggle({ Title = "启用动画检测", Default = true, Callback = function(state) Config.EnableAnimDetection = state end })
HitboxSection:Toggle({ Title = "掉血兜底检测 (防漏报)", Default = true, Callback = function(state) Config.EnableHealthFallback = state end })
HitboxSection:Toggle({ Title = "暴力模式 (无视阵营皮肤)", Default = true, Callback = function(state) Config.BruteForceMode = state end })
HitboxSection:Toggle({ Title = "朝向检测 (自定义皮肤慎开)", Default = false, Callback = function(state) Config.FacingCheckOn = state end })
HitboxSection:Slider({ Title = "最大攻击距离 (米)", Step = 1, Value = { Min = 3, Max = 25, Default = 15 }, Callback = function(value) Config.MaxAttackDistance = value end })
HitboxSection:Slider({ Title = "朝向阈值 (0-1)", Step = 0.1, Value = { Min = 0, Max = 1, Default = 0.3 }, Callback = function(value) Config.FacingThreshold = value end })

HitboxSection:Divider()
HitboxSection:Toggle({ Title = "白框指示器 (fart风格)", Default = false, Callback = function(state) Config.ShowHitboxOnAttack = state end })
HitboxSection:Toggle({ Title = "调试模式 (打印动画)", Default = false, Callback = function(state) Config.DebugAnimations = state; if state then Notify("提示", "请查看控制台") end end })
HitboxSection:Slider({ Title = "分块间隔时间 (秒)", Step = 0.05, Value = { Min = 0.05, Max = 0.5, Default = 0.1 }, Callback = function(value) Config.SegmentDelay = value end })
HitboxSection:Slider({ Title = "单个方块大小", Step = 1, Value = { Min = 1, Max = 10, Default = 3 }, Callback = function(value) Config.HitboxSize = value end })
HitboxSection:Slider({ Title = "分块数量 (1-6)", Step = 1, Value = { Min = 1, Max = 6, Default = 3 }, Callback = function(value) Config.HitboxSegments = value end })
HitboxSection:Slider({ Title = "方块存在时间 (秒)", Step = 0.1, Value = { Min = 0.1, Max = 2.0, Default = 0.3 }, Callback = function(value) Config.HitboxDuration = value end })
HitboxSection:Slider({ Title = "起始距离 (离杀手)", Step = 1, Value = { Min = 1, Max = 15, Default = 3 }, Callback = function(value) Config.OffsetZ = value end })
HitboxSection:Slider({ Title = "高度偏移", Step = 1, Value = { Min = -5, Max = 10, Default = 2 }, Callback = function(value) Config.OffsetY = value end })

SentinelTab:Divider()
local StaminaSection = SentinelTab:Section({ Title = "耐力系统", Opened = true })
StaminaSection:Toggle({ Title = "无限耐力", Default = false, Callback = function(state) Config.InfiniteStaminaOn = state; if state then Notify("无限耐力", "已开启") end end })

SentinelTab:Divider()
local SaveSection = SentinelTab:Section({ Title = "配置管理", Opened = true })
SaveSection:Button({ Title = "保存当前配置", Callback = function() SaveConfig() end })
SaveSection:Button({ Title = "加载已保存配置", Callback = function() LoadConfig() end })
SaveSection:Button({ Title = "重置配置 (恢复默认)", Callback = function() 
    if not isfile(CONFIG_FILE) then Notify("提示", "没有配置文件可重置") return end
    pcall(function() delfile(CONFIG_FILE) end)
    Notify("重置成功", "配置文件已删除，重启脚本后生效")
end })

task.wait(0.5)
pcall(function() Window:SelectTab(1) end)