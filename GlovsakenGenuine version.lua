-- =========================================================
-- LOST: SANDBOX 手机玩家终极版 (Fixsaken核心 + 彻底修复走路误判)
-- =========================================================

repeat task.wait() until game:IsLoaded()
task.wait(2)

local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local workspaceService = game:GetService("Workspace")
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpService = game:GetService("HttpService")
local lightingService = game:GetService("Lighting")

local clientPlayer = playersService.LocalPlayer

---------------------------------------------------------
-- 1. UI 优先加载
---------------------------------------------------------
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "小雨",
    Icon = "shield",
    Author = "Plus Core",
    Folder = "LostSandboxScript",
    Size = UDim2.fromOffset(300, 520),
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
-- 2. 全局配置
---------------------------------------------------------
local Config = {
    AutoBlockOn = false,
    HitboxTransparency = 0.5,
    HitboxColor = Color3.fromRGB(255, 255, 255),
    HitboxSizeMultiplier = 1.0,
    HitboxOffset = -1.4,
    HitboxDuration = 0.4,
    BlockDelay = 0,
    ShowHitboxOnAttack = false,
    EnableSkillDetection = true,
    EnableM1Detection = true,
    EnableToolDetection = true,
    -- 【核心修复】动画过滤配置
    StrictAnimDetection = true, -- 严格模式
    AttackAnimKeywords = "attack,punch,slash,hit,m1,swing,kick,stab,shoot,cast,skill,ability,heavy,combo",
    IgnoreAnimKeywords = "walk,run,idle,fall,jump,climb,swim,sit,laugh,emote,interact,use,equip,unequip",
    InfiniteStaminaOn = false,
    RemoveBlindness = false,
    FullBright = false,
    ESPOn = false,
    ESPShowKillers = true,
    ESPShowSurvivors = true,
    ESPShowMedkits = true,
    DebugMode = true,
}

local function Notify(title, content)
    WindUI:Notify({ Title = title, Content = content, Duration = 3 })
end

---------------------------------------------------------
-- 3. UI 界面构建
---------------------------------------------------------
local AlertTab = Window:Tab({ Title = "⚠️ 测试版提醒", Icon = "alert-triangle" })
local AlertSection = AlertTab:Section({ Title = "使用须知", Opened = true })
AlertSection:Paragraph({ Title = "该脚本已警告过您 任何封禁与我们无关", Content = "该脚本为测试版，已彻底修复走路误判。" })
AlertSection:Button({ Title = "我已知晓风险", Callback = function() WindUI:Notify({ Title = "感谢支持", Content = "祝你游戏愉快！", Duration = 3 }) end })

local SentinelTab = Window:Tab({ Title = "Sentinel", Icon = "shield" })

local ESPSection = SentinelTab:Section({ Title = "ESP 透视", Opened = true })
ESPSection:Toggle({ Title = "启用 ESP", Default = false, Callback = function(state) Config.ESPOn = state end })
ESPSection:Toggle({ Title = "显示杀手 (红)", Default = true, Callback = function(state) Config.ESPShowKillers = state end })
ESPSection:Toggle({ Title = "显示幸存者 (绿)", Default = true, Callback = function(state) Config.ESPShowSurvivors = state end })
ESPSection:Toggle({ Title = "显示医疗包 (青)", Default = true, Callback = function(state) Config.ESPShowMedkits = state end })

SentinelTab:Divider()

local BlockSection = SentinelTab:Section({ Title = "Attack 检测格挡 (Mine核心)", Opened = true })
BlockSection:Toggle({ Title = "启用自动格挡", Default = false, Callback = function(state) 
    Config.AutoBlockOn = state 
    if state then EnableAutoBlock() else DisableAutoBlock() end
end })
BlockSection:Slider({ Title = "格挡延迟 (秒)", Step = 0.05, Value = { Min = 0, Max = 1.0, Default = 0.0 }, Callback = function(value) Config.BlockDelay = value end })
BlockSection:Toggle({ Title = "调试模式", Default = true, Callback = function(state) Config.DebugMode = state end })

BlockSection:Divider()
BlockSection:Toggle({ Title = "监听技能 (属性)", Default = true, Callback = function(state) Config.EnableSkillDetection = state end })
BlockSection:Toggle({ Title = "监听 M1 (动画)", Default = true, Callback = function(state) Config.EnableM1Detection = state end })
BlockSection:Toggle({ Title = "监听武器 (工具)", Default = true, Callback = function(state) Config.EnableToolDetection = state end })

BlockSection:Divider()
BlockSection:Toggle({ Title = "白框指示器 (fart风格)", Default = false, Callback = function(state) Config.ShowHitboxOnAttack = state end })
BlockSection:Slider({ Title = "Hitbox 透明度", Step = 0.05, Value = { Min = 0, Max = 1, Default = 0.5 }, Callback = function(value) Config.HitboxTransparency = value end })
BlockSection:Colorpicker({ Title = "Hitbox 颜色", Default = Color3.fromRGB(255, 255, 255), Callback = function(color) Config.HitboxColor = color end })

SentinelTab:Divider()
local HitboxSection = SentinelTab:Section({ Title = "Attack 检测参数", Opened = true })
HitboxSection:Slider({ Title = "最大攻击距离 (米)", Step = 1, Value = { Min = 3, Max = 35, Default = 35 }, Callback = function(value) Config.MaxAttackDistance = value end })
HitboxSection:Slider({ Title = "白框整体大小倍数", Step = 0.1, Value = { Min = 0.5, Max = 3.0, Default = 1.0 }, Callback = function(value) Config.HitboxSizeMultiplier = value end })
HitboxSection:Slider({ Title = "判定盒停留时间 (秒)", Step = 0.05, Value = { Min = 0.05, Max = 2.0, Default = 0.4 }, Callback = function(value) Config.HitboxDuration = value end })

-- 【核心新增】动画过滤高级设置
HitboxSection:Divider()
HitboxSection:Toggle({ 
    Title = "严格动画过滤 (防走路误判)", 
    Default = true, 
    Callback = function(state) Config.StrictAnimDetection = state end 
})
HitboxSection:Input({ 
    Title = "攻击关键词 (白名单)", 
    Value = Config.AttackAnimKeywords, 
    Callback = function(text) if text and text ~= "" then Config.AttackAnimKeywords = text end end 
})
HitboxSection:Input({ 
    Title = "忽略动作关键词 (黑名单)", 
    Value = Config.IgnoreAnimKeywords, 
    Callback = function(text) if text and text ~= "" then Config.IgnoreAnimKeywords = text end end 
})

SentinelTab:Divider()
local VisualSection = SentinelTab:Section({ Title = "视觉", Opened = true })
VisualSection:Toggle({ Title = "消除失明", Default = false, Callback = function(state) Config.RemoveBlindness = state end })
VisualSection:Toggle({ Title = "全图高亮 (夜视)", Default = false, Callback = function(state) Config.FullBright = state end })

SentinelTab:Divider()
local StaminaSection = SentinelTab:Section({ Title = "耐力系统 (Sewimsaken核心)", Opened = true })
StaminaSection:Toggle({ Title = "无限耐力", Default = false, Callback = function(state) 
    Config.InfiniteStaminaOn = state 
    SetInfiniteStamina(state)
end })

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

---------------------------------------------------------
-- 4. 配置文件管理
---------------------------------------------------------
local CONFIG_FILE = "LostSentinel_Config.json"
function SaveConfig()
    if not writefile then Notify("保存失败", "不支持 writefile"); return end
    local success, err = pcall(function() writefile(CONFIG_FILE, httpService:JSONEncode(Config)) end)
    if success then Notify("配置保存", "所有设置已成功保存到本地！") else Notify("保存失败", tostring(err)) end
end

function LoadConfig()
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
-- 5. 【核心】格挡发包与空间检测
---------------------------------------------------------
local BlockRemote = nil
local lastBlockTime = 0
local BLOCK_COOLDOWN = 0.25

local function getBlockRemote()
    if BlockRemote then return BlockRemote end
    local success, remote = pcall(function()
        return replicatedStorage:WaitForChild("Modules", 10):WaitForChild("Network", 5):WaitForChild("Network", 5):WaitForChild("RemoteEvent", 5)
    end)
    if success and remote then
        BlockRemote = remote
        return remote
    end
    return nil
end

local function fireBlockRemote()
    if tick() - lastBlockTime < BLOCK_COOLDOWN then return end
    lastBlockTime = tick()
    
    local remote = getBlockRemote()
    if remote then
        pcall(function()
            remote:FireServer("UseActorAbility", { buffer.fromstring("\003\005\000\000\000Block") })
            if Config.DebugMode then print("[Sentinel Debug] ✅ 已发送二进制格挡包") end
        end)
    end

    local playerGui = clientPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible and obj.Active then
                local n = obj.Name:lower()
                if n:find("block") or n:find("defend") or n:find("shield") or n:find("格挡") then
                    pcall(function()
                        if getconnections then
                            local conns = getconnections(obj.MouseButton1Click)
                            for _, c in ipairs(conns) do c:Fire() end
                        end
                    end)
                    break
                end
            end
        end
    end
end

local function createSpatialOverlapBox(creatorChar, size, onHitDetected)
    local creatorRoot = creatorChar:FindFirstChild("HumanoidRootPart") or creatorChar:FindFirstChild("RootPart")
    if not creatorRoot then return end
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = { creatorChar }
    
    task.spawn(function()
        local timePast = 0
        while creatorChar.Parent and creatorRoot and creatorRoot.Parent and timePast < Config.HitboxDuration do
            local Part = Instance.new("Part")
            Part.Name = "AutoBlockHitbox_Frame"
            Part.Transparency = Config.HitboxTransparency
            Part.CanCollide = false
            Part.Anchored = true
            Part.Size = size
            Part.Color = Config.HitboxColor
            Part.Material = Enum.Material.ForceField
            Part.CFrame = creatorRoot.CFrame * CFrame.new(0, 0, Config.HitboxOffset)
            Part.Parent = workspaceService
            
            task.delay(0.05, function() if Part then Part:Destroy() end end)
            
            local parts = workspaceService:GetPartsInPart(Part, overlapParams)
            local localPlayerHit = false
            for _, v in ipairs(parts) do
                local character = v:FindFirstAncestorOfClass("Model")
                if character then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        local player = playersService:GetPlayerFromCharacter(character)
                        if player == clientPlayer then
                            localPlayerHit = true
                            break
                        end
                    end
                end
            end
            
            if not localPlayerHit then
                local myChar = clientPlayer.Character
                local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local distanceToBox = (myHRP.Position - Part.Position).Magnitude
                    if distanceToBox <= (size.Magnitude * 0.8) then
                        localPlayerHit = true
                        if Config.DebugMode then print("[Sentinel Debug] 📏 距离兜底检测触发！") end
                    end
                end
            end

            if localPlayerHit then
                if Config.DebugMode then print("[Sentinel Debug] 🎯 攻击判定命中！") end
                task.wait(Config.BlockDelay)
                if onHitDetected then onHitDetected() end
                break
            end
            timePast = timePast + runService.Heartbeat:Wait()
        end
    end)
end

local function TriggerDefense(killerChar, source)
    if not Config.AutoBlockOn then return end
    if Config.DebugMode then print("[Sentinel Debug] ⚔️ 检测到攻击事件 (" .. source .. ")，生成判定盒...") end
    local baseSize = Vector3.new(4.5, 6, 7.5) * Config.HitboxSizeMultiplier
    createSpatialOverlapBox(
        killerChar,
        baseSize,
        function()
            fireBlockRemote()
        end
    )
end

---------------------------------------------------------
-- 6. 【核心修复】严格阵营过滤与动画过滤
---------------------------------------------------------
local hookedKillers = {}

local function IsKillerCharacter(char)
    if not char or not char:IsA("Model") or not char:FindFirstChild("Humanoid") then return false end
    if char == clientPlayer.Character then return false end
    
    local killersFolder = workspaceService:FindFirstChild("Players") and workspaceService.Players:FindFirstChild("Killers") or workspaceService:FindFirstChild("Killers")
    if not killersFolder or not char:IsDescendantOf(killersFolder) then return false end
    
    local plr = playersService:GetPlayerFromCharacter(char)
    if plr == clientPlayer then return false end
    
    local charName = char.Name:lower()
    if charName:find("minion") or charName:find("bot") or charName:find("summon") 
       or charName:find("clone") or charName:find("follower") or charName:find("npc") then
        return false 
    end
    
    return true
end

-- 解析关键词列表
local function ParseKeywords(str)
    local list = {}
    for word in string.gmatch(str, '([^,]+)') do
        table.insert(list, word:lower():gsub("^%s*(.-)%s*$", "%1"))
    end
    return list
end

local function SetupKillerMonitoring(killerChar)
    if not IsKillerCharacter(killerChar) then return end
    if hookedKillers[killerChar] then return end
    hookedKillers[killerChar] = true

    if Config.EnableSkillDetection then
        killerChar:GetAttributeChangedSignal("AbilitiesUsed"):Connect(function()
            TriggerDefense(killerChar, "技能属性")
        end)
    end

    if Config.EnableToolDetection then
        killerChar.DescendantAdded:Connect(function(desc)
            if desc:IsA("Tool") then
                desc.Activated:Connect(function() TriggerDefense(killerChar, "工具激活") end)
            end
        end)
        local currentTool = killerChar:FindFirstChildOfClass("Tool")
        if currentTool then
            currentTool.Activated:Connect(function() TriggerDefense(killerChar, "工具激活") end)
        end
    end

    if Config.EnableM1Detection then
        local humanoid = killerChar:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:FindFirstChildOfClass("AnimationController")
            if animator then
                animator.AnimationPlayed:Connect(function(track)
                    local animName = track.Animation and track.Animation.Name:lower() or ""
                    local priority = track.Priority

                    -- 1. 底层过滤：屏蔽掉核心移动和待机优先级
                    if priority == Enum.AnimationPriority.Core or 
                       priority == Enum.AnimationPriority.Movement or 
                       priority == Enum.AnimationPriority.Idle then 
                        return 
                    end

                    -- 2. 名字过滤：排除走路、跑步、交互等
                    local ignoreList = ParseKeywords(Config.IgnoreAnimKeywords)
                    for _, kw in ipairs(ignoreList) do
                        if animName:find(kw) then return end
                    end

                    -- 3. 严格模式：必须满足动作优先级或包含攻击关键词
                    if Config.StrictAnimDetection then
                        local isAttackName = false
                        local attackList = ParseKeywords(Config.AttackAnimKeywords)
                        for _, kw in ipairs(attackList) do
                            if animName:find(kw) then isAttackName = true; break end
                        end

                        local isActionPriority = priority == Enum.AnimationPriority.Action or 
                                                 priority == Enum.AnimationPriority.Action2 or 
                                                 priority == Enum.AnimationPriority.Action3 or 
                                                 priority == Enum.AnimationPriority.Action4
                        
                        -- 如果既不是攻击名字，也不是动作优先级，则跳过（防走路误判）
                        if not isAttackName and not isActionPriority then return end
                    end

                    -- 经过层层过滤，确认为攻击动作
                    if Config.DebugMode then print("[Sentinel Debug] 动画命中: " .. animName .. " | 优先级: " .. priority.Name) end
                    TriggerDefense(killerChar, "M1动画")
                end)
            end
        end
    end

    if Config.DebugMode then print("[Sentinel Debug] 🎯 已成功挂钩杀手: " .. killerChar.Name) end
end

local function ScanKillers()
    local killersFolder = workspaceService:FindFirstChild("Players") and workspaceService.Players:FindFirstChild("Killers") or workspaceService:FindFirstChild("Killers")
    if killersFolder then
        for _, child in ipairs(killersFolder:GetChildren()) do
            if child:IsA("Model") then SetupKillerMonitoring(child) end
        end
    end
end

workspaceService.DescendantAdded:Connect(function(desc)
    if desc:IsA("Model") and desc:FindFirstChild("Humanoid") then
        task.wait(0.5)
        SetupKillerMonitoring(desc)
    end
end)

function EnableAutoBlock()
    ScanKillers()
    getBlockRemote()
    if Config.DebugMode then print("[Sentinel Debug] ✅ 自动格挡已开启") end
end

function DisableAutoBlock()
    if Config.DebugMode then print("[Sentinel Debug] ❌ 自动格挡已关闭") end
end

task.spawn(function()
    while task.wait(1) do
        if Config.AutoBlockOn then ScanKillers() end
    end
end)

---------------------------------------------------------
-- 7. 【核心】Fixsaken 无限体力
---------------------------------------------------------
local SprintingModule = nil
local function GetSprintingModule()
    if SprintingModule then return SprintingModule end
    local success, mod = pcall(function()
        return replicatedStorage:WaitForChild("Systems"):WaitForChild("Character"):WaitForChild("Game"):WaitForChild("Sprinting")
    end)
    if success and mod then
        SprintingModule = mod
        return mod
    end
    return nil
end

function SetInfiniteStamina(state)
    local mod = GetSprintingModule()
    if not mod then
        Notify("无限耐力", "无法找到游戏体力模块")
        return
    end
    if state then
        local success, err = pcall(function()
            local sprinting = require(mod)
            if sprinting then
                sprinting.StaminaLoss = 0
                sprinting.StaminaGain = 9999
            end
        end)
        if success then Notify("无限耐力", "已成功修改底层模块") else Notify("无限耐力", "修改失败: " .. tostring(err)) end
    else
        pcall(function()
            local sprinting = require(mod)
            if sprinting then
                sprinting.StaminaLoss = 10
                sprinting.StaminaGain = 25
            end
        end)
    end
end

---------------------------------------------------------
-- 8. ESP 与视觉
---------------------------------------------------------
local espHighlights = {}
local function CreateESP(target, isKiller, isMedkit)
    if not target:IsA("Model") then return end
    if espHighlights[target] then 
        for _, obj in ipairs(espHighlights[target]) do pcall(function() obj:Destroy() end) end 
    end
    local objects = {}
    local mainColor = isMedkit and Color3.fromRGB(0, 200, 255) or (isKiller and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50))
    local highlight = Instance.new("Highlight")
    highlight.Name = "LostESP_Highlight"
    highlight.Adornee = target
    highlight.FillColor = mainColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = target
    table.insert(objects, highlight)
    local hrp = target:FindFirstChild("HumanoidRootPart")
    if hrp then
        local box = Instance.new("SelectionBox")
        box.Name = "LostESP_Box"
        box.Adornee = hrp
        box.LineThickness = 0.05
        box.Color3 = mainColor
        box.Transparency = 0.5
        box.Visible = true
        box.Parent = target
        table.insert(objects, box)
    end
    espHighlights[target] = objects
end

local function UpdateESP()
    if not Config.ESPOn then
        for _, objs in pairs(espHighlights) do
            for _, obj in ipairs(objs) do pcall(function() obj:Destroy() end) end
        end
        espHighlights = {}
        return
    end
    local function ScanFolder(folderName, isKiller)
        local folder = workspaceService:FindFirstChild("Players") and workspaceService.Players:FindFirstChild(folderName) or workspaceService:FindFirstChild(folderName)
        if folder then
            for _, target in ipairs(folder:GetDescendants()) do
                if target:IsA("Model") and target:FindFirstChild("Humanoid") and target:FindFirstChild("HumanoidRootPart") then
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
    for target, objs in pairs(espHighlights) do
        if not target.Parent then
            for _, obj in ipairs(objs) do pcall(function() obj:Destroy() end) end
            espHighlights[target] = nil
        end
    end
end
task.spawn(function() while task.wait(0.5) do UpdateESP() end end)

-- 视觉系统
task.spawn(function()
    while task.wait(0.2) do
        if Config.RemoveBlindness then
            for _, v in ipairs(lightingService:GetChildren()) do
                if v:IsA("BlurEffect") then v.Enabled = false; v.Size = 0
                elseif v:IsA("ColorCorrectionEffect") then v.Enabled = false; v.Brightness = 0; v.Contrast = 0; v.Saturation = 0; v.TintColor = Color3.fromRGB(255, 255, 255)
                elseif v:IsA("BloomEffect") then v.Enabled = false end
            end
        end
        if Config.FullBright then
            lightingService.Brightness = 3
            lightingService.Ambient = Color3.fromRGB(255, 255, 255)
            lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            lightingService.GlobalShadows = false
            lightingService.FogEnd = 100000
            lightingService.FogStart = 0
            lightingService.ClockTime = 14
            for _, v in ipairs(lightingService:GetChildren()) do
                if v:IsA("Atmosphere") then
                    v.Density = 0; v.Offset = 0; v.Color = Color3.fromRGB(255, 255, 255); v.Decay = Color3.fromRGB(255, 255, 255); v.Glare = 0; v.Haze = 0
                elseif v:IsA("PostEffect") then
                    v.Enabled = false
                end
            end
        end
    end
end)