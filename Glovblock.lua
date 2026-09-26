-- =========================================================
-- LOST: SANDBOX 手机玩家终极版 (Moonblock核心 + 高延迟动态补偿)
-- =========================================================

repeat task.wait() until game:IsLoaded()
task.wait(2)

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local clientPlayer = LP
local PlayerGui = clientPlayer:WaitForChild("PlayerGui", 10)

---------------------------------------------------------
-- 1. WindUI 优先加载
---------------------------------------------------------
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "LOST Sentinel",
    Icon = "shield",
    Author = "Moonblock Core",
    Folder = "LostSandboxScript",
    Size = UDim2.fromOffset(300, 540),
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
    AutoBlockEnabled = false,
    AutoPunch = false,
    BlockDelay = 0,
    BaseHitboxSize = Vector3.new(4.5, 6, 7.5),
    HitboxScale = 1.0,
    HitboxOffset = -1.4,
    HitboxColor = Color3.fromRGB(255, 255, 255),
    HitboxTransparency = 0.6,
    SpawnDuration = 0.6,
    -- 【核心优化】延迟补偿参数
    EnableDelayCompensation = true,
    DelayCompensationDistance = 10, -- 增大预判距离
    TriggerCooldown = 0.15,         -- 缩短发包间隔
    -- 其他
    InfiniteStaminaOn = false,
    RemoveBlindness = false,
    FullBright = false,
    ESPOn = false,
    ESPShowKillers = true,
    ESPShowSurvivors = true,
    ESPShowMedkits = true,
    ESPKillerColor = Color3.fromRGB(255, 50, 50),
    ESPSurvivorColor = Color3.fromRGB(50, 255, 50),
    ESPMedkitColor = Color3.fromRGB(0, 200, 255),
    ESPFillTransparency = 0.8,
    ESPOutlineTransparency = 0.3,
    DebugMode = true,
}

local SPAWN_INTERVAL   = 0.05
local DEBOUNCE         = 0.15
local NORMAL_LIFETIME  = 0.3
local HIT_LIFETIME     = 0.5
local REFRESH_INTERVAL = 0.5
local AUTO_PUNCH_DELAY = 0.15

local KILLER_ALIASES = {
    ["Guest 666"] = "Sixer",
    ["Guest666"]  = "Sixer",
}

local PRIMARY_ATTACK_ANIM = {
    Slash = true, SlashAir = true, EnragedSlash = true, Stab = true, Attack = true,
    Perforation = true, Perforating = true, Perforate = true,
    Pummeling = true, Pummel = true,
}

local PRIMARY_ATTACK_SOUND = {
    Swing = true, Slash = true, SlashWindup = true, SlashGround = true, Chomp = true,
    Perforation = true, PerforationWindup = true, Perforating = true, Perforate = true,
    Pummeling = true, PummelingWindup = true, Pummel = true,
}

local GENERIC_ATTACK_ANIM_WORDS = {"slash", "punch", "hit", "swing", "chomp", "attack", "stab", "kick", "shoot", "cast"}
local GENERIC_ATTACK_SOUND_WORDS = {"slash", "punch", "hit", "swing", "chomp", "attack", "stab", "windup"}

local hookedKillers   = setmetatable({}, {__mode = "k"})
local hookedAnimators = setmetatable({}, {__mode = "k"})
local hookedSounds    = setmetatable({}, {__mode = "k"})
local watchedFolders  = setmetatable({}, {__mode = "k"})

local function Notify(title, content)
    WindUI:Notify({ Title = title, Content = content, Duration = 3 })
end

---------------------------------------------------------
-- 3. UI 界面构建
---------------------------------------------------------
local AlertTab = Window:Tab({ Title = "⚠️ 测试版提醒", Icon = "alert-triangle" })
local AlertSection = AlertTab:Section({ Title = "使用须知", Opened = true })
AlertSection:Paragraph({ Title = "重要警告", Content = "该脚本融合Moonblock核心，已加入高延迟动态补偿。" })
AlertSection:Button({ Title = "我已知晓风险", Callback = function() WindUI:Notify({ Title = "感谢支持", Content = "祝你游戏愉快！", Duration = 3 }) end })

local SentinelTab = Window:Tab({ Title = "Sentinel", Icon = "shield" })

local ESPSection = SentinelTab:Section({ Title = "ESP 透视 (极简轮廓)", Opened = true })
ESPSection:Toggle({ Title = "启用 ESP", Default = false, Callback = function(state) Config.ESPOn = state end })
ESPSection:Toggle({ Title = "显示杀手 (红)", Default = true, Callback = function(state) Config.ESPShowKillers = state end })
ESPSection:Toggle({ Title = "显示幸存者 (绿)", Default = true, Callback = function(state) Config.ESPShowSurvivors = state end })
ESPSection:Toggle({ Title = "显示医疗包 (青)", Default = true, Callback = function(state) Config.ESPShowMedkits = state end })
ESPSection:Slider({ Title = "ESP 填充透明度", Step = 0.05, Value = { Min = 0, Max = 1, Default = 0.8 }, Callback = function(value) Config.ESPFillTransparency = value end })
ESPSection:Slider({ Title = "ESP 轮廓透明度", Step = 0.05, Value = { Min = 0, Max = 1, Default = 0.3 }, Callback = function(value) Config.ESPOutlineTransparency = value end })

SentinelTab:Divider()

local BlockSection = SentinelTab:Section({ Title = "Attack 检测格挡 (Moonblock核心)", Opened = true })
BlockSection:Toggle({ Title = "启用自动格挡", Default = false, Callback = function(state) 
    Config.AutoBlockEnabled = state 
    if state then getBlockRemote() end
    Notify("MoonBlock", state and "Enabled" or "Disabled")
end })
BlockSection:Toggle({ Title = "自动 Punch", Default = false, Callback = function(state) Config.AutoPunch = state end })
BlockSection:Slider({ Title = "格挡延迟 (秒)", Step = 0.05, Value = { Min = 0, Max = 1.0, Default = 0 }, Callback = function(value) Config.BlockDelay = value end })
BlockSection:Toggle({ Title = "调试模式", Default = true, Callback = function(state) Config.DebugMode = state end })

-- 【核心优化】延迟补偿 UI
BlockSection:Divider()
BlockSection:Toggle({ 
    Title = "🔥 高延迟补偿 (提前格挡)", 
    Default = true, 
    Callback = function(state) 
        Config.EnableDelayCompensation = state 
        if state then Notify("提示", "已开启延迟补偿，杀手靠近时提前格挡") end
    end 
})
BlockSection:Slider({ 
    Title = "补偿触发距离 (米)", 
    Step = 1, 
    Value = { Min = 3, Max = 20, Default = 10 }, 
    Callback = function(value) Config.DelayCompensationDistance = value end 
})
BlockSection:Slider({ 
    Title = "格挡发包间隔 (秒)", 
    Step = 0.05, 
    Value = { Min = 0.05, Max = 0.5, Default = 0.15 }, 
    Callback = function(value) Config.TriggerCooldown = value end 
})

BlockSection:Divider()
BlockSection:Slider({ Title = "白框整体大小倍数", Step = 0.1, Value = { Min = 0.5, Max = 3.0, Default = 1.0 }, Callback = function(value) Config.HitboxScale = value end })
BlockSection:Slider({ Title = "判定盒停留时间 (秒)", Step = 0.05, Value = { Min = 0.05, Max = 2.0, Default = 0.6 }, Callback = function(value) Config.SpawnDuration = value end })
BlockSection:Slider({ Title = "Hitbox 透明度", Step = 0.05, Value = { Min = 0, Max = 1, Default = 0.6 }, Callback = function(value) Config.HitboxTransparency = value end })
BlockSection:Colorpicker({ Title = "Hitbox 颜色", Default = Color3.fromRGB(255, 255, 255), Callback = function(color) Config.HitboxColor = color end })

SentinelTab:Divider()
local VisualSection = SentinelTab:Section({ Title = "视觉", Opened = true })
VisualSection:Toggle({ Title = "消除失明", Default = false, Callback = function(state) Config.RemoveBlindness = state end })
VisualSection:Toggle({ Title = "全图高亮 (夜视)", Default = false, Callback = function(state) Config.FullBright = state end })

SentinelTab:Divider()
local StaminaSection = SentinelTab:Section({ Title = "耐力系统", Opened = true })
StaminaSection:Toggle({ Title = "无限耐力 (锁移速)", Default = false, Callback = function(state) Config.InfiniteStaminaOn = state end })

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
    local success, err = pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(Config)) end)
    if success then Notify("配置保存", "所有设置已成功保存到本地！") else Notify("保存失败", tostring(err)) end
end

function LoadConfig()
    if not readfile or not isfile then Notify("加载失败", "不支持文件读取"); return end
    if not isfile(CONFIG_FILE) then Notify("加载失败", "未找到配置文件"); return end
    local success, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if success and type(data) == "table" then
        for k, v in pairs(data) do if Config[k] ~= nil then Config[k] = v end end
        Notify("配置加载", "配置已加载！部分滑块需重开界面生效。")
    else
        Notify("加载失败", "配置文件损坏")
    end
end

---------------------------------------------------------
-- 5. 格挡发包（网络包 + UI按钮双保险）
---------------------------------------------------------
local BlockRemote = nil
local function getBlockRemote()
    if BlockRemote then return BlockRemote end
    local ok, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("Modules", 10)
            :WaitForChild("Network", 5)
            :WaitForChild("Network", 5)
            :WaitForChild("RemoteEvent", 5)
    end)
    if ok and remote then BlockRemote = remote; return remote end
end

local lastBlockTime = 0
local lastPunchTime = 0

local function fireBlockRemote()
    if tick() - lastBlockTime < Config.TriggerCooldown then return end
    lastBlockTime = tick()
    
    local remote = getBlockRemote()
    if remote then
        pcall(function()
            remote:FireServer("UseActorAbility", { buffer.fromstring("\003\005\000\000\000Block") })
            if Config.DebugMode then print("[Sentinel Debug] ✅ 已发送二进制格挡包") end
        end)
    end

    if PlayerGui then
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible and obj.Active then
                local n = obj.Name:lower()
                if n:find("block") or n:find("defend") or n:find("shield") or n:find("格挡") then
                    pcall(function()
                        if getconnections then
                            local conns = getconnections(obj.MouseButton1Click)
                            for _, c in ipairs(conns) do c:Fire() end
                        end
                        obj:Activate()
                    end)
                    break
                end
            end
        end
    end
end

local function firePunchRemote()
    if tick() - lastPunchTime < Config.TriggerCooldown then return end
    lastPunchTime = tick()
    
    local remote = getBlockRemote()
    if remote then
        pcall(function()
            remote:FireServer("UseActorAbility", { buffer.fromstring("\003\005\000\000\000Punch") })
            if Config.DebugMode then print("[Sentinel Debug] 👊 已发送Punch包") end
        end)
    end
end

local killerAnimIds  = {}
local killerSoundIds = {}

local function collectAttackAnimations(animTable, output, depth)
    depth = depth or 0
    if depth > 3 or type(animTable) ~= "table" then return end
    for k, v in pairs(animTable) do
        if PRIMARY_ATTACK_ANIM[k] then
            if type(v) == "string" then
                local id = v:match("%d+"); if id then output[id] = true end
            elseif type(v) == "table" then
                for _, sub in pairs(v) do
                    if type(sub) == "string" then
                        local id = sub:match("%d+"); if id then output[id] = true end
                    end
                end
            end
        end
        if type(v) == "table" then collectAttackAnimations(v, output, depth + 1) end
    end
end

local function collectAttackSounds(soundTable, output, depth)
    depth = depth or 0
    if depth > 3 or type(soundTable) ~= "table" then return end
    for k, v in pairs(soundTable) do
        if PRIMARY_ATTACK_SOUND[k] then
            if type(v) == "string" then
                local id = v:match("%d+"); if id then output[id] = true end
            elseif type(v) == "table" and not v.SoundId and not v.ID then
                for _, sub in pairs(v) do
                    if type(sub) == "string" then
                        local id = sub:match("%d+"); if id then output[id] = true end
                    end
                end
            end
        end
        if type(v) == "table" then collectAttackSounds(v, output, depth + 1) end
    end
end

local function findKillerConfig(killer)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then return nil end
    local killersFolder = assets:FindFirstChild("Killers")
    if not killersFolder then return nil end

    local name  = killer.Name
    local alias = KILLER_ALIASES[name]
    local baseFolder = killersFolder:FindFirstChild(name)
        or (alias and killersFolder:FindFirstChild(alias))

    if not baseFolder then
        for _, f in ipairs(killersFolder:GetChildren()) do
            local c = f:FindFirstChild("Config")
            if c and c:IsA("ModuleScript") then
                local ok, data = pcall(require, c)
                if ok and type(data) == "table"
                    and (data.DisplayName == name or (alias and data.DisplayName == alias)) then
                    baseFolder = f; break
                end
            end
        end
    end
    if not baseFolder then return nil end

    local skinName = killer:GetAttribute("SkinName") or killer:GetAttribute("Skin")
    if type(skinName) == "string" and skinName ~= "" then
        local skinsFolder = assets:FindFirstChild("Skins")
        local skinKillers = skinsFolder and skinsFolder:FindFirstChild("Killers")
        local killerSkins = skinKillers and skinKillers:FindFirstChild(baseFolder.Name)
        if killerSkins then
            local skinFolder = killerSkins:FindFirstChild(skinName)
            if skinFolder then
                local c = skinFolder:FindFirstChild("Config")
                if c and c:IsA("ModuleScript") then return c end
            end
        end
    end

    local baseConfig = baseFolder:FindFirstChild("Config")
    if baseConfig and baseConfig:IsA("ModuleScript") then return baseConfig end
    return nil
end

local function buildKillerIds(killer)
    local animIds, soundIds = {}, {}
    local config = findKillerConfig(killer)
    if config then
        local ok, data = pcall(require, config)
        if ok and type(data) == "table" then
            if data.Animations then collectAttackAnimations(data.Animations, animIds) end
            if data.Sounds     then collectAttackSounds(data.Sounds, soundIds) end
        end
    end
    killerAnimIds[killer]  = animIds
    killerSoundIds[killer] = soundIds
end

task.spawn(function()
    while true do
        local pf = Workspace:FindFirstChild("Players")
        local kf = (pf and pf:FindFirstChild("Killers")) or Workspace:FindFirstChild("Killers")
        if kf then
            for _, killer in ipairs(kf:GetChildren()) do
                if killer:IsA("Model") then
                    pcall(buildKillerIds, killer)
                end
            end
        end
        task.wait(REFRESH_INTERVAL)
    end
end)

---------------------------------------------------------
-- 6. 【Moonblock 核心】碰撞盒与攻击触发
---------------------------------------------------------
local cachedPlayerQuery = nil
local function getPlayerQuery()
    if not cachedPlayerQuery or not cachedPlayerQuery.Parent then
        local myChar = LP.Character
        cachedPlayerQuery = myChar and (
            myChar:FindFirstChild("QueryHitbox") or myChar:FindFirstChild("HumanoidRootPart")
        ) or nil
    end
    return cachedPlayerQuery
end

LP.CharacterAdded:Connect(function() cachedPlayerQuery = nil end)

local function createHitboxPart(cf, withOutline, lifetime)
    local part = Instance.new("Part")
    part.Name         = withOutline and "AutoBlockHitbox_Hit" or "AutoBlockHitbox"
    part.Size         = Config.BaseHitboxSize * Config.HitboxScale
    part.CFrame       = cf
    part.Anchored     = true
    part.CanCollide   = false
    part.CanTouch     = false
    part.CastShadow   = false
    part.Color        = Config.HitboxColor
    part.Material     = Enum.Material.ForceField
    part.Transparency = Config.HitboxTransparency
    part.Parent       = Workspace

    if withOutline then
        local outline = Instance.new("SelectionBox")
        outline.Adornee       = part
        outline.Color3        = Config.HitboxColor
        outline.LineThickness = 0.02
        outline.Transparency  = Config.HitboxTransparency
        outline.Visible       = true
        outline.Parent        = part
    end

    Debris:AddItem(part, lifetime)
    return part
end

local function hitboxTouchesPlayer(hb)
    local pq = getPlayerQuery()
    if not pq then return false end
    
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { pq }
    local hits = Workspace:GetPartBoundsInBox(hb.CFrame, hb.Size, params)
    if #hits > 0 then return true end

    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then
        local dist = (myHRP.Position - hb.Position).Magnitude
        local boxRadius = hb.Size.Magnitude / 2
        if dist <= boxRadius + 3 then
            if Config.DebugMode then print("[Sentinel Debug] 📏 距离兜底触发！距离:", math.floor(dist)) end
            return true
        end
    end
    
    return false
end

local activeLoops = {}

local function fireBlockAndPunch()
    fireBlockRemote()
    if Config.AutoPunch then
        task.delay(AUTO_PUNCH_DELAY, firePunchRemote)
    end
end

local function startSnapshotLoop(slasher)
    if activeLoops[slasher] then
        activeLoops[slasher].cancelled = true
    end
    local token = { cancelled = false }
    activeLoops[slasher] = token

    task.spawn(function()
        local startTime = tick()
        while true do
            if token.cancelled then break end
            if not Config.AutoBlockEnabled then break end
            if not slasher or not slasher.Parent then break end
            if tick() - startTime >= Config.SpawnDuration then break end

            local root = slasher:FindFirstChild("HumanoidRootPart")
                or slasher:FindFirstChild("QueryHitbox")
                or slasher:FindFirstChild("RootPart")
            if root then
                local cf = root.CFrame * CFrame.new(0, 0, Config.HitboxOffset)
                local hb = createHitboxPart(cf, false, NORMAL_LIFETIME)

                if hitboxTouchesPlayer(hb) then
                    createHitboxPart(cf, true, HIT_LIFETIME)
                    if Config.BlockDelay > 0 then
                        task.delay(Config.BlockDelay, fireBlockAndPunch)
                    else
                        fireBlockAndPunch()
                    end
                    token.cancelled = true
                    break
                end
            end

            task.wait(SPAWN_INTERVAL)
        end
        if activeLoops[slasher] == token then
            activeLoops[slasher] = nil
        end
    end)
end

local lastTriggerTime = {}
local function tryTrigger(slasher)
    if not Config.AutoBlockEnabled then return end
    if not slasher or not slasher.Parent then return end
    local now = tick()
    if now - (lastTriggerTime[slasher] or 0) < DEBOUNCE then return end
    lastTriggerTime[slasher] = now
    if Config.DebugMode then print("[Sentinel Debug] ⚔️ 触发攻击检测: " .. slasher.Name) end
    startSnapshotLoop(slasher)
end

---------------------------------------------------------
-- 7. 攻击监听
---------------------------------------------------------
local function setupKiller(killer)
    if not killer or not killer.Parent then return end
    if hookedKillers[killer] then return end
    hookedKillers[killer] = true

    killer:GetAttributeChangedSignal("AbilitiesUsed"):Connect(function()
        tryTrigger(killer)
    end)

    killer.DescendantAdded:Connect(function(desc)
        if desc:IsA("Tool") then
            desc.Activated:Connect(function() tryTrigger(killer) end)
        end
    end)
    local currentTool = killer:FindFirstChildOfClass("Tool")
    if currentTool then
        currentTool.Activated:Connect(function() tryTrigger(killer) end)
    end

    local function hookAnimator()
        local hum = killer:FindFirstChildOfClass("Humanoid")
        if not hum then
            killer.ChildAdded:Connect(function() task.wait(0.2); hookAnimator() end)
            return
        end
        local animator = hum:FindFirstChildOfClass("Animator") or hum:FindFirstChildOfClass("AnimationController")
        if not animator then
            hum.ChildAdded:Connect(function(c)
                if c:IsA("Animator") or c:IsA("AnimationController") then
                    task.wait(0.2); hookAnimator()
                end
            end)
            return
        end
        if hookedAnimators[animator] then return end
        hookedAnimators[animator] = true

        animator.AnimationPlayed:Connect(function(track)
            if not track or not track.Animation then return end
            local aid = track.Animation.AnimationId
            if type(aid) ~= "string" then return end
            local id = aid:match("%d+")
            local animName = track.Animation.Name:lower() or ""
            local priority = track.Priority

            if priority == Enum.AnimationPriority.Core or priority == Enum.AnimationPriority.Movement or priority == Enum.AnimationPriority.Idle then return end
            for _, kw in ipairs({"walk", "run", "idle", "fall", "jump", "swim", "sit", "laugh", "emote", "interact", "use", "equip"}) do
                if animName:find(kw) then return end
            end

            local currentIds = killerAnimIds[killer]
            if currentIds and id and currentIds[id] then tryTrigger(killer); return end

            local isActionPriority = priority == Enum.AnimationPriority.Action or priority == Enum.AnimationPriority.Action2 or priority == Enum.AnimationPriority.Action3 or priority == Enum.AnimationPriority.Action4
            local isAttackName = false
            for _, kw in ipairs(GENERIC_ATTACK_ANIM_WORDS) do if animName:find(kw) then isAttackName = true; break end end

            if isActionPriority or isAttackName then tryTrigger(killer) end
        end)
    end
    hookAnimator()

    local function hookKillerSound(d)
        if not d:IsA("Sound") or hookedSounds[d] then return end
        hookedSounds[d] = true
        local function onPlay()
            if not Config.AutoBlockEnabled then return end
            local id = tostring(d.SoundId):match("%d+")
            local soundName = d.Name:lower()
            local currentIds = killerSoundIds[killer]
            if currentIds and id and currentIds[id] then tryTrigger(killer); return end
            for _, kw in ipairs(GENERIC_ATTACK_SOUND_WORDS) do
                if soundName:find(kw) then tryTrigger(killer); return end
            end
        end
        d.Played:Connect(onPlay)
        d:GetPropertyChangedSignal("IsPlaying"):Connect(function() if d.IsPlaying then onPlay() end end)
        if d.IsPlaying then task.spawn(onPlay) end
    end
    for _, d in ipairs(killer:GetDescendants()) do hookKillerSound(d) end
    killer.DescendantAdded:Connect(hookKillerSound)
end

local function watchKillersFolder(kf)
    for _, k in ipairs(kf:GetChildren()) do
        if k:IsA("Model") then task.spawn(function() task.wait(0.3); setupKiller(k) end) end
    end
    kf.ChildAdded:Connect(function(c) if c:IsA("Model") then task.wait(0.3); setupKiller(c) end end)
end

task.spawn(function()
    while true do
        local pf = Workspace:FindFirstChild("Players")
        local kf = (pf and pf:FindFirstChild("Killers")) or Workspace:FindFirstChild("Killers")
        if kf and not watchedFolders[kf] then watchedFolders[kf] = true; watchKillersFolder(kf) end
        task.wait(1)
    end
end)

---------------------------------------------------------
-- 8. 高延迟补偿（提前格挡）
---------------------------------------------------------
task.spawn(function()
    while task.wait(0.1) do -- 频率提高到 0.1 秒
        if not Config.AutoBlockEnabled or not Config.EnableDelayCompensation then continue end
        
        local myChar = LP.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHRP then continue end
        
        local killersFolder = Workspace:FindFirstChild("Players") and Workspace.Players:FindFirstChild("Killers") or Workspace:FindFirstChild("Killers")
        if not killersFolder then continue end
        
        for _, killer in ipairs(killersFolder:GetChildren()) do
            if killer:IsA("Model") and killer:FindFirstChild("HumanoidRootPart") then
                local dist = (myHRP.Position - killer.HumanoidRootPart.Position).Magnitude
                if dist <= Config.DelayCompensationDistance then
                    fireBlockRemote()
                    break
                end
            end
        end
    end
end)

---------------------------------------------------------
-- 9. 无限体力 (锁移速)
---------------------------------------------------------
task.spawn(function()
    while task.wait(0.1) do
        if not Config.InfiniteStaminaOn then continue end
        local char = LP.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.WalkSpeed < 16 then humanoid.WalkSpeed = 16 end
        end
    end
end)

---------------------------------------------------------
-- 10. 极简 ESP
---------------------------------------------------------
local espHighlights = {}
local function CreateESP(target, color)
    if not target:IsA("Model") then return end
    if espHighlights[target] then espHighlights[target]:Destroy() end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "LostESP_Highlight"
    highlight.Adornee = target
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = Config.ESPFillTransparency
    highlight.OutlineTransparency = Config.ESPOutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = target
    
    espHighlights[target] = highlight
end

local function UpdateESP()
    if not Config.ESPOn then
        for _, h in pairs(espHighlights) do pcall(function() h:Destroy() end) end
        espHighlights = {}
        return
    end
    
    local function ScanFolder(folderName, color)
        local folder = Workspace:FindFirstChild("Players") and Workspace.Players:FindFirstChild(folderName) or Workspace:FindFirstChild(folderName)
        if folder then
            for _, target in ipairs(folder:GetDescendants()) do
                if target:IsA("Model") and target:FindFirstChild("Humanoid") and target:FindFirstChild("HumanoidRootPart") then
                    if espHighlights[target] then
                        espHighlights[target].FillColor = color
                        espHighlights[target].OutlineColor = color
                        espHighlights[target].FillTransparency = Config.ESPFillTransparency
                        espHighlights[target].OutlineTransparency = Config.ESPOutlineTransparency
                    else
                        CreateESP(target, color)
                    end
                end
            end
        end
    end
    
    if Config.ESPShowKillers then ScanFolder("Killers", Config.ESPKillerColor) end
    if Config.ESPShowSurvivors then ScanFolder("Survivors", Config.ESPSurvivorColor) end
    
    if Config.ESPShowMedkits then
        for _, folder in ipairs({ Workspace:FindFirstChild("Items"), Workspace:FindFirstChild("Medkits"), Workspace }) do
            if folder then
                for _, v in ipairs(folder:GetChildren()) do
                    local n = v.Name:lower()
                    if n:find("med") or n:find("health") or n:find("heal") or n:find("kit") then
                        if espHighlights[v] then
                            espHighlights[v].FillColor = Config.ESPMedkitColor
                            espHighlights[v].OutlineColor = Config.ESPMedkitColor
                        else
                            CreateESP(v, Config.ESPMedkitColor)
                        end
                    end
                end
            end
        end
    end
    
    for target, h in pairs(espHighlights) do
        if not target.Parent then
            h:Destroy()
            espHighlights[target] = nil
        end
    end
end
task.spawn(function() while task.wait(0.5) do UpdateESP() end end)

-- 视觉系统
task.spawn(function()
    while task.wait(0.2) do
        if Config.RemoveBlindness then
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("BlurEffect") then v.Enabled = false; v.Size = 0
                elseif v:IsA("ColorCorrectionEffect") then v.Enabled = false; v.Brightness = 0; v.Contrast = 0; v.Saturation = 0; v.TintColor = Color3.fromRGB(255, 255, 255)
                elseif v:IsA("BloomEffect") then v.Enabled = false end
            end
        end
        if Config.FullBright then
            Lighting.Brightness = 3
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
            Lighting.FogStart = 0
            Lighting.ClockTime = 14
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") then
                    v.Density = 0; v.Offset = 0; v.Color = Color3.fromRGB(255, 255, 255); v.Decay = Color3.fromRGB(255, 255, 255); v.Glare = 0; v.Haze = 0
                elseif v:IsA("PostEffect") then
                    v.Enabled = false
                end
            end
        end
    end
end)