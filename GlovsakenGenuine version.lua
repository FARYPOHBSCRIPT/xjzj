-- =========================================================
-- LOST: SANDBOX 手机玩家终极版 (技能过滤 + 无限体力深度修复)
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
    Title = "LOST Sentinel",
    Icon = "shield",
    Author = "Smart Detection",
    Folder = "LostSandboxScript",
    Size = UDim2.fromOffset(300, 450),
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
    BlockCooldown = 0.4,
    BlockDelay = 0.0,
    LastBlockTime = 0,
    BlockButtonName = "block",
    ShowHitboxOnAttack = false,
    AutoFitHitbox = true,
    HitboxSizeMultiplier = 1.0,
    HitboxSpacing = 1.5,
    HitboxSize = 4,
    HitboxTransparency = 0.1,
    HitboxColor = Color3.fromRGB(255, 255, 255),
    HitboxDuration = 0.3,
    HitboxSegments = 3,
    SegmentDelay = 0.1,
    OffsetY = 2,
    OffsetZ = 3,
    MaxAttackDistance = 35,
    SmartKillerNames = "Slacker, JX1DX1, Pursuer, Harken, Sonic.EXE, Slenderman, Zombie King, Erlking, Sukuna, Jeff The Killer, Herobrine, c00lkidd, Gubby, Cat, Horse, Artful, John Doe, [W.I.P]The Knight, Noli, The Stalker, 1x1x1x1, Killdroid, Doombringer, Flowers, Guest666, Buster Brawler, Nosferatu, BRIMSTONE, Azure, King, NoliRework, Duke Erisia, Baldi, Slasher, Jason",
    IgnoreAnimKeywords = "walk,run,idle,fall,jump,climb,swim,sit,laugh,emote,interact,use,equip,unequip",
    -- 【新增】忽略技能关键词，防止非攻击技能触发格挡
    IgnoreSkillKeywords = "see,vision,reveal,track,mark,scan,radar,wallhack,aura,dash,sprint,heal,buff,shield,invisible,fly,speed,transformation,summon",
    IgnoreMinions = true,
    NetKeywords = "hit,attack,damage,punch,slash,kill,m1,use,skill,ability,cast,action",
    HitboxGlobalCooldown = 0.2,
    LastHitboxTime = 0,
    RemoveBlindness = false,
    FullBright = false,
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
-- 3. UI 界面构建
---------------------------------------------------------
-- 测试版提醒
local AlertTab = Window:Tab({ Title = "⚠️ 测试版提醒", Icon = "alert-triangle" })
local AlertSection = AlertTab:Section({ Title = "使用须知", Opened = true })
AlertSection:Paragraph({ Title = "重要警告", Content = "该脚本为测试版 (Beta)，存在非常多的 Bug！请在使用前确认风险，出现任何问题由玩家自行承担。" })
AlertSection:Button({ Title = "我已知晓风险", Callback = function() WindUI:Notify({ Title = "感谢支持", Content = "请谨慎调整各项参数，祝你游戏愉快！", Duration = 3 }) end })

-- Sentinel 主栏目
local SentinelTab = Window:Tab({ Title = "Sentinel", Icon = "shield" })

local ESPSection = SentinelTab:Section({ Title = "ESP 透视", Opened = true })
ESPSection:Toggle({ Title = "启用 ESP", Default = false, Callback = function(state) Config.ESPOn = state end })
ESPSection:Toggle({ Title = "显示杀手 (红)", Default = true, Callback = function(state) Config.ESPShowKillers = state end })
ESPSection:Toggle({ Title = "显示幸存者 (绿)", Default = true, Callback = function(state) Config.ESPShowSurvivors = state end })
ESPSection:Toggle({ Title = "显示医疗包 (青)", Default = true, Callback = function(state) Config.ESPShowMedkits = state end })

SentinelTab:Divider()

local BlockSection = SentinelTab:Section({ Title = "Attack 检测格挡", Opened = true })
BlockSection:Toggle({ Title = "启用自动格挡", Default = false, Callback = function(state) Config.AutoBlockOn = state end })
BlockSection:Slider({ Title = "格挡冷却 (秒)", Step = 0.05, Value = { Min = 0.05, Max = 1.0, Default = 0.4 }, Callback = function(value) Config.BlockCooldown = value end })
BlockSection:Slider({ Title = "格挡延迟 (秒)", Step = 0.05, Value = { Min = 0, Max = 1.0, Default = 0.0 }, Callback = function(value) Config.BlockDelay = value end })
BlockSection:Input({ Title = "格挡按钮名字", Value = "block", Callback = function(text) if text and text ~= "" then Config.BlockButtonName = text end end })
BlockSection:Button({ Title = "手动触发格挡 (测试用)", Callback = function() FireBlock() end })

SentinelTab:Divider()
local HitboxSection = SentinelTab:Section({ Title = "Attack 检测参数", Opened = true })

HitboxSection:Input({ Title = "智能杀手名字 (逗号分隔)", Value = Config.SmartKillerNames, Callback = function(text) if text and text ~= "" then Config.SmartKillerNames = text; Notify("提示", "已更新杀手名单") end end })
HitboxSection:Toggle({ Title = "过滤小兵/召唤物", Default = true, Callback = function(state) Config.IgnoreMinions = state end })
HitboxSection:Slider({ Title = "最大攻击距离 (米)", Step = 1, Value = { Min = 3, Max = 35, Default = 35 }, Callback = function(value) Config.MaxAttackDistance = value end })

-- 【核心新增】忽略技能关键词
HitboxSection:Input({ 
    Title = "忽略技能关键词 (防误触)", 
    Value = Config.IgnoreSkillKeywords, 
    Callback = function(text) 
        if text and text ~= "" then 
            Config.IgnoreSkillKeywords = text 
            Notify("提示", "已更新忽略技能列表") 
        end 
    end 
})

HitboxSection:Input({ Title = "网络包监听关键词", Value = Config.NetKeywords, Callback = function(text) if text and text ~= "" then Config.NetKeywords = text end end })

HitboxSection:Divider()
HitboxSection:Toggle({ Title = "白框指示器 (fart风格)", Default = false, Callback = function(state) Config.ShowHitboxOnAttack = state end })
HitboxSection:Toggle({ Title = "智能适配模型体积", Default = true, Callback = function(state) Config.AutoFitHitbox = state end })
HitboxSection:Slider({ Title = "白框整体大小倍数", Step = 0.1, Value = { Min = 0.5, Max = 3.0, Default = 1.0 }, Callback = function(value) Config.HitboxSizeMultiplier = value end })
HitboxSection:Slider({ Title = "分块间距倍数", Step = 0.1, Value = { Min = 0.5, Max = 3.0, Default = 1.5 }, Callback = function(value) Config.HitboxSpacing = value end })

HitboxSection:Slider({ Title = "基础方块大小 (非自动)", Step = 1, Value = { Min = 1, Max = 10, Default = 4 }, Callback = function(value) Config.HitboxSize = value end })
HitboxSection:Slider({ Title = "Hitbox 透明度", Step = 0.05, Value = { Min = 0, Max = 1, Default = 0.1 }, Callback = function(value) Config.HitboxTransparency = value end })
HitboxSection:Colorpicker({ Title = "Hitbox 颜色", Default = Color3.fromRGB(255, 255, 255), Callback = function(color) Config.HitboxColor = color end })

HitboxSection:Slider({ Title = "分块间隔时间 (秒)", Step = 0.05, Value = { Min = 0.05, Max = 0.5, Default = 0.1 }, Callback = function(value) Config.SegmentDelay = value end })
HitboxSection:Slider({ Title = "分块数量 (1-6)", Step = 1, Value = { Min = 1, Max = 6, Default = 3 }, Callback = function(value) Config.HitboxSegments = value end })
HitboxSection:Slider({ Title = "方块存在时间 (秒)", Step = 0.1, Value = { Min = 0.1, Max = 2.0, Default = 0.3 }, Callback = function(value) Config.HitboxDuration = value end })
HitboxSection:Slider({ Title = "起始距离 (杀手正前方)", Step = 1, Value = { Min = 1, Max = 15, Default = 3 }, Callback = function(value) Config.OffsetZ = value end })
HitboxSection:Slider({ Title = "高度偏移", Step = 1, Value = { Min = -5, Max = 10, Default = 2 }, Callback = function(value) Config.OffsetY = value end })

SentinelTab:Divider()
local VisualSection = SentinelTab:Section({ Title = "视觉", Opened = true })
VisualSection:Toggle({ Title = "消除失明", Default = false, Callback = function(state) Config.RemoveBlindness = state end })
VisualSection:Toggle({ Title = "全图高亮 (夜视)", Default = false, Callback = function(state) Config.FullBright = state end })

SentinelTab:Divider()
local StaminaSection = SentinelTab:Section({ Title = "耐力系统", Opened = true })
StaminaSection:Paragraph({ Title = "提示", Content = "如果开启后无效，说明游戏强制使用服务器体力。本脚本会拦截消耗请求。" })
StaminaSection:Toggle({ Title = "无限耐力", Default = false, Callback = function(state) Config.InfiniteStaminaOn = state end })

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
-- 5. 阵营判定
---------------------------------------------------------
local function IsInGame()
    local killersFolder = workspaceService:FindFirstChild("Players") and workspaceService.Players:FindFirstChild("Killers") or workspaceService:FindFirstChild("Killers")
    if killersFolder and #killersFolder:GetChildren() > 0 then return true end
    return false
end

local function IsKillerCharacter(char)
    if not char or not char:IsA("Model") or not char:FindFirstChild("Humanoid") then return false end
    if char == clientPlayer.Character then return false end
    local plr = playersService:GetPlayerFromCharacter(char)
    if plr == clientPlayer then return false end
    
    local parent = char.Parent
    if not parent then return false end
    if parent.Name:lower():find("survivor") then return false end
    
    local customNames = {}
    for word in string.gmatch(Config.SmartKillerNames, '([^,]+)') do
        local trimmed = word:match("^%s*(.-)%s*$"):lower()
        if #trimmed > 0 then table.insert(customNames, trimmed) end
    end
    
    local charName = char.Name:lower()
    for _, name in ipairs(customNames) do
        if charName:find(name) then return true end
    end

    if not parent.Name:lower():find("killer") and not charName:find("killer") then return false end

    if Config.IgnoreMinions then
        if charName:find("minion") or charName:find("bot") or charName:find("summon") 
           or charName:find("clone") or charName:find("follower") or charName:find("npc") then
            return false 
        end
    end
    return true
end

---------------------------------------------------------
-- 6. 核心逻辑：ESP、白框、格挡
---------------------------------------------------------
-- ESP
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

-- 白框核心逻辑
local HitboxFolder = nil
local currentSequenceToken = 0

local function ShowAttackHitbox(killerChar)
    if not Config.ShowHitboxOnAttack then return end
    local now = tick()
    if now < Config.LastHitboxTime + Config.HitboxGlobalCooldown then return end
    Config.LastHitboxTime = now

    local killerHRP = killerChar:FindFirstChild("HumanoidRootPart")
    if not killerHRP then return end

    currentSequenceToken = currentSequenceToken + 1
    local myToken = currentSequenceToken

    if HitboxFolder then HitboxFolder:Destroy() end
    HitboxFolder = Instance.new("Folder")
    HitboxFolder.Name = "LostHitboxSegments"
    HitboxFolder.Parent = workspaceService

    local baseSize = Config.HitboxSize
    if Config.AutoFitHitbox then
        local modelSize = killerChar:GetExtentsSize()
        baseSize = (modelSize.X + modelSize.Y + modelSize.Z) / 3 * 0.4
        if baseSize < 1 then baseSize = 1 end
        if baseSize > 15 then baseSize = 15 end
    end
    
    local finalSize = baseSize * Config.HitboxSizeMultiplier

    local lookVector = killerHRP.CFrame.LookVector
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
            part.Color = Config.HitboxColor
            part.Transparency = Config.HitboxTransparency
            part.Size = Vector3.new(finalSize, finalSize, finalSize)
            part.CastShadow = false; part.Parent = HitboxFolder

            local distance = Config.OffsetZ + (i - 1) * (finalSize * Config.HitboxSpacing)
            part.CFrame = CFrame.new(startPos + lookVector * distance)

            task.delay(Config.HitboxDuration, function() if part and part.Parent then part:Destroy() end end)
        end
    end)
end

-- 安全格挡
local networkRemote = replicatedStorage:FindFirstChild("Modules") 
    and replicatedStorage.Modules:FindFirstChild("Network") 
    and replicatedStorage.Modules.Network:FindFirstChild("RemoteEvent")

local function FireBlockLocalEvent()
    local playerGui = clientPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible and obj.Active then
            local n = obj.Name:lower()
            if n:find(Config.BlockButtonName:lower()) or n:find("block") or n:find("defend") or n:find("shield") or n:find("格挡") then
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

-- 综合检测与格挡
local function IsValidAttack(killerChar)
    if not killerChar or not killerChar.Parent then return false end
    local myHRP = clientPlayer.Character and clientPlayer.Character:FindFirstChild("HumanoidRootPart")
    local killerHRP = killerChar:FindFirstChild("HumanoidRootPart")
    if not myHRP or not killerHRP then return false end
    local dist = (myHRP.Position - killerHRP.Position).Magnitude
    if dist > Config.MaxAttackDistance then return false end
    return true
end

local function AttemptAutoBlock(killerChar, source)
    if not killerChar then return end
    if not IsValidAttack(killerChar) then return end
    
    ShowAttackHitbox(killerChar)
    if not Config.AutoBlockOn then return end

    local now = tick()
    if now < Config.LastBlockTime + Config.BlockCooldown then return end
    
    if Config.BlockDelay > 0 then
        task.delay(Config.BlockDelay, function() FireBlock() end)
    else
        FireBlock()
    end
    
    Config.LastBlockTime = now
end

---------------------------------------------------------
-- 7. 智能全技能监听 (修复技能误触)
---------------------------------------------------------
local function SetupKillerHooks(killerChar)
    if not IsKillerCharacter(killerChar) then return end
    
    killerChar.DescendantAdded:Connect(function(desc)
        if desc:IsA("Tool") then 
            desc.Activated:Connect(function() AttemptAutoBlock(killerChar, "Tool") end) 
        end
    end)
    local currentTool = killerChar:FindFirstChildOfClass("Tool")
    if currentTool then
        currentTool.Activated:Connect(function() AttemptAutoBlock(killerChar, "Tool") end)
    end

    local function HookAnimator(animatorObj)
        if not animatorObj then return end
        animatorObj.AnimationPlayed:Connect(function(track)
            local animName = track.Animation and track.Animation.Name:lower() or ""
            
            -- 1. 过滤日常动作
            for _, kw in ipairs({"walk", "run", "idle", "fall", "jump", "climb", "swim", "sit", "laugh", "emote", "interact", "use", "equip", "unequip"}) do
                if animName:find(kw) then return end
            end
            
            -- 2. 【核心修复】过滤技能动作
            local ignoreSkills = {}
            for word in string.gmatch(Config.IgnoreSkillKeywords, '([^,]+)') do
                table.insert(ignoreSkills, word:lower():gsub("^%s*(.-)%s*$", "%1"))
            end
            for _, kw in ipairs(ignoreSkills) do
                if animName:find(kw) then return end
            end

            AttemptAutoBlock(killerChar, "Anim:"..animName)
        end)
    end

    local humanoid = killerChar:FindFirstChildOfClass("Humanoid")
    if humanoid then
        HookAnimator(humanoid:FindFirstChildOfClass("Animator"))
        HookAnimator(humanoid:FindFirstChildOfClass("AnimationController"))
        humanoid.DescendantAdded:Connect(function(desc)
            if desc:IsA("Animator") or desc:IsA("AnimationController") then HookAnimator(desc) end
        end)
    end
end

local function HookIncomingAttacks()
    local keywords = {}
    for word in string.gmatch(Config.NetKeywords, '([^,]+)') do
        table.insert(keywords, word:lower():gsub("^%s*(.-)%s*$", "%1"))
    end
    local function CheckRemote(remote)
        if not remote:IsA("RemoteEvent") then return end
        local n = remote.Name:lower()
        local isTarget = false
        for _, kw in ipairs(keywords) do
            if n:find(kw) then isTarget = true; break end
        end
        if isTarget then
            remote.OnClientEvent:Connect(function(...)
                if not IsInGame() then return end
                
                -- 【核心修复】如果网络包名字里有 "use"、"skill"、"ability"，但没有 "attack"、"hit"，则认定为非攻击技能，忽略
                local lowerName = remote.Name:lower()
                if (lowerName:find("use") or lowerName:find("skill") or lowerName:find("ability")) then
                    if not (lowerName:find("attack") or lowerName:find("hit") or lowerName:find("damage") or lowerName:find("punch") or lowerName:find("slash")) then
                        return
                    end
                end
                
                local myHRP = clientPlayer.Character and clientPlayer.Character:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local closestKiller, minDist = nil, Config.MaxAttackDistance
                    for _, k in ipairs(workspaceService:GetDescendants()) do
                        if IsKillerCharacter(k) and k:FindFirstChild("HumanoidRootPart") then
                            local d = (myHRP.Position - k.HumanoidRootPart.Position).Magnitude
                            if d < minDist then minDist = d; closestKiller = k end
                        end
                    end
                    if closestKiller then AttemptAutoBlock(closestKiller, "Net:"..n) end
                end
            end)
        end
    end
    for _, v in ipairs(replicatedStorage:GetDescendants()) do CheckRemote(v) end
    replicatedStorage.DescendantAdded:Connect(CheckRemote)
end

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
HookIncomingAttacks()

---------------------------------------------------------
-- 8. 【深度修复】无限体力逻辑 (拦截扣体力包 + 强行锁定)
---------------------------------------------------------
local function HookStaminaDrain()
    for _, v in ipairs(replicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local nameLower = v.Name:lower()
            if nameLower:find("stamina") or nameLower:find("sprint") or nameLower:find("dash") or nameLower:find("energy") then
                if hookmetamethod then
                    local oldFire = v.FireServer
                    v.FireServer = function(self, ...)
                        if Config.InfiniteStaminaOn then return end
                        return oldFire(self, ...)
                    end
                end
            end
        end
    end
end
HookStaminaDrain()

task.spawn(function()
    while task.wait(0.1) do
        if not Config.InfiniteStaminaOn then continue end
        
        -- 扩大扫描范围，包括 PlayerGui
        local targetsToScan = {clientPlayer, clientPlayer.Character, clientPlayer:FindFirstChild("PlayerGui")}
        
        for _, target in ipairs(targetsToScan) do
            if target then
                for _, v in ipairs(target:GetDescendants()) do
                    if v:IsA("NumberValue") or v:IsA("IntValue") then
                        local n = v.Name:lower()
                        if n:find("stamina") or n:find("energy") or n:find("endurance") or n:find("sp") then
                            local maxVal = v:GetAttribute("Max") or v:GetAttribute("MaxValue") or 100
                            if v.Value < maxVal then v.Value = maxVal end
                        end
                    end
                end
                for _, attr in ipairs(target:GetAttributes()) do
                    local a = attr:lower()
                    if a:find("stamina") or a:find("energy") or a:find("endurance") then target:SetAttribute(attr, 100) end
                end
            end
        end
    end
end)