--[[
    MoonBlock - Eternal Destination 终极完全体 V55
    1. 【UI 升级】采用最新 Obsidian 库，并加入 SaveManager 和 ThemeManager，新增“配置 (Config)”分组
    2. 【核心修复】DrakoBloxxer 专属音效智能识别，解决不触发判定框的问题
    3. 保留：帧同步碰撞检测、预测格挡、全功能英文化、Noli/Slasher 硬编码 ID
--]]

-- ============================================================
-- Services
-- ============================================================
local Players  = game:GetService("Players")
local LP       = Players.LocalPlayer
local RS       = game:GetService("ReplicatedStorage")
local WS       = game:GetService("Workspace")
local Debris   = game:GetService("Debris")
local RunSvc   = game:GetService("RunService")
local MPS      = game:GetService("MarketplaceService")

pcall(function()
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("ScreenGui") and (g.Name == "Obsidian" or g.Name:find("Obsidian")) then
                g:Destroy()
            end
        end
    end
end)

-- ============================================================
-- Obsidian UI Library (最新版)
-- ============================================================
local repo    = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

pcall(function()
    Library:SetNotifySound("rbxassetid://4590657391", 3)
end)

local gameName = game.Name
pcall(function()
    local info = MPS:GetProductInfo(game.PlaceId)
    if info and info.Name then gameName = info.Name end
end)

local versionText = "V55"
pcall(function()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, o in ipairs(pg:GetDescendants()) do
            if (o:IsA("TextLabel") or o:IsA("TextButton"))
                and (o.Name == "Version" or o.Name:lower():find("version")) then
                versionText = o.Text; break
            end
        end
    end
end)

local Window = Library:CreateWindow({
    Title            = "永恒的目的 (Eternal Destination " .. versionText .. ")",
    Footer           = tostring(gameName) .. " | " .. tostring(versionText),
    Icon             = 95816097006870,
    NotifySide       = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    ["Main"]        = Window:AddTab("永恒的目的 (Main)", "shield"),
    ["ESP"]         = Window:AddTab("ESP", "eye"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

-- ============================================================
-- 配置管理器与主题管理器
-- ============================================================
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

ThemeManager:SetDefaultTheme({
    BackgroundColor = Color3.fromRGB(0, 0, 0),
    MainColor       = Color3.fromRGB(25, 25, 25),
    AccentColor     = Color3.fromRGB(162, 162, 162),
    OutlineColor    = Color3.fromRGB(40, 40, 40),
    FontColor       = Color3.fromRGB(255, 255, 255),
    FontFace        = Enum.Font.Gotham,
})

SaveManager:SetFolder("MoonBlockConfig")
SaveManager:SetSubFolder(tostring(game.PlaceId))
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

SaveManager:LoadAutoloadConfig()

local function notify(t, d)
    pcall(function()
        Library:Notify({ Title = t, Description = d, Time = 3 })
    end)
end

-- ============================================================
-- Settings
-- ============================================================
local REFRESH_INTERVAL = 2.0
local AUTO_PUNCH_DELAY = 0.15
local COLLISION_CHECK_DURATION = 1.0

local HAS_DRAWING = pcall(function() local d = Drawing.new("Line"); d:Remove() end)

-- Slasher 与 Noli 攻击动画 ID
local MANUAL_ATTACK_ANIM_IDS = {
    ["135033589919052"] = true,
    ["117031678277507"] = true,
    ["112172210278019"] = true,
    ["135935437641829"] = true,
    ["96539474379048"] = true,
    ["117106550659611"] = true,
    ["77145727901172"] = true,
    ["134269996268880"] = true,
    ["138272065054122"] = true,
}

-- 眩晕/受击过滤
local STUN_KEYWORDS = {
    "stun", "dizzy", "ragdoll", "hurt", "injured", "dead", "death", 
    "fall", "land", "stagger", "knock", "knockback", "down", 
    "tumble", "shove", "push"
}

local Settings = {
    AutoBlockEnabled   = false,
    AutoSolve          = false,
    AutoPunch          = false,
    PunchAimbot        = false,
    AimbotRadius       = 500,
    AimbotYawOnly      = true,
    AimbotMode         = "角色+相机+同步 (Char+Cam+Sync)",
    ForceSync          = true,
    AimbotLockFrames   = 4,

    BlockDelay         = 0,
    BlockCooldown      = 5,
    RespectCooldown    = true,
    GlobalBlockCooldown = 0,
    
    AutoMoveOnBlock    = false,
    PredictiveBlock    = true,

    BaseHitboxSize     = Vector3.new(4.5, 6, 7.5),
    HitboxScale        = 1.0,
    HitboxOffset       = -1.5,
    HitboxColor        = Color3.fromRGB(255, 255, 255),
    
    HitboxTransparency = 0.6,
    HitboxLineThickness = 0.05,
    NORMAL_LIFETIME    = 0.5,
    HIT_LIFETIME       = 0.6,
    
    DebugLog           = false,
    IgnoreStun         = true,
}

-- ============================================================
-- 全局白框跟随系统与帧同步碰撞检测
-- ============================================================
local FollowHitboxes = {}
local lastGlobalBlockTime = 0

RunSvc.RenderStepped:Connect(function()
    local myChar = LP.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("QueryHitbox"))
    if not myRoot then return end

    for part, data in pairs(FollowHitboxes) do
        if not part.Parent or not data.slasher.Parent then
            FollowHitboxes[part] = nil
        else
            local slasherRoot = data.slasher:FindFirstChild("HumanoidRootPart") or data.slasher:FindFirstChild("QueryHitbox") or data.slasher:FindFirstChild("RootPart")
            if slasherRoot then
                part.CFrame = slasherRoot.CFrame * CFrame.new(0, 0, data.offset)
                
                if Settings.AutoBlockEnabled and not data.triggered then
                    local dist = (myRoot.Position - part.Position).Magnitude
                    if dist <= (part.Size.Magnitude / 2 + myRoot.Size.Magnitude / 2 + 1.5) then
                        data.triggered = true
                        if not Settings.RespectCooldown or (tick() - lastGlobalBlockTime >= Settings.GlobalBlockCooldown) then
                            lastGlobalBlockTime = tick()
                            local r = getRemote()
                            if r then
                                r:FireServer("UseActorAbility", { "Block" })
                            end
                            if Settings.AutoPunch then
                                task.delay(AUTO_PUNCH_DELAY, firePunchRemote)
                            end
                        end
                    end
                end
            else
                FollowHitboxes[part] = nil
            end
        end
    end
end)

-- ============================================================
-- ✨ 全自动适配核心
-- ============================================================
local ATTACK_KEYWORDS = {
    "attack", "slash", "stab", "swing", "hit", "punch", "kick", "shoot",
    "strike", "execute", "m1", "pummel", "chomp", "perforate", "enraged",
    "claw", "bite", "scratch", "smash", "slam", "charge", "dash", "lunge",
    "slap", "stomp", "grab", "fist", "arm", "weapon", "skill"
}
local IGNORE_KEYWORDS = {
    "walk", "run", "sprint", "idle", "jump", "fall", "land", "crouch",
    "crawl", "swim", "climb", "death", "dead", "hurt", "injured",
    "stunned", "intro", "victory", "loop", "theme", "ambience", "spawn"
}

local AutoAnimCache   = {}
local AutoSoundCache  = {}
local AutoSkinCache   = {}

local function isAttackName(name)
    local n = name:lower()
    for _, kw in ipairs(ATTACK_KEYWORDS) do
        if n:find(kw, 1, true) then return true end
    end
    return false
end

local function isIgnoreName(name)
    local n = name:lower()
    for _, kw in ipairs(IGNORE_KEYWORDS) do
        if n:find(kw, 1, true) then return true end
    end
    return false
end

local function extractIDs(data, animOut, soundOut)
    local function scan(tbl, isSound)
        for k, v in pairs(tbl) do
            local name = tostring(k)
            if type(v) == "string" then
                local id = v:match("%d+")
                if id and isAttackName(name) and not isIgnoreName(name) then
                    if isSound then soundOut[id] = true else animOut[id] = true end
                end
            elseif type(v) == "table" then
                local subId = v.SoundId or v.ID
                if type(subId) == "string" then
                    local id = subId:match("%d+")
                    if id and isAttackName(name) and not isIgnoreName(name) then
                        if isSound then soundOut[id] = true else animOut[id] = true end
                    end
                end
                scan(v, isSound or name:lower():find("sound") ~= nil)
            end
        end
    end
    if data.Animations then scan(data.Animations, false) end
    if data.Sounds then scan(data.Sounds, true) end
end

local function runAutoAdapter()
    local assets = RS:FindFirstChild("Assets")
    if not assets then return end

    local baseKillers = assets:FindFirstChild("Killers")
    if baseKillers then
        for _, killerFolder in ipairs(baseKillers:GetChildren()) do
            local config = killerFolder:FindFirstChild("Config")
            if config and config:IsA("ModuleScript") then
                local ok, data = pcall(require, config)
                if ok and type(data) == "table" then
                    local baseName = killerFolder.Name:lower()
                    AutoAnimCache[baseName] = AutoAnimCache[baseName] or {}
                    AutoSoundCache[baseName] = AutoSoundCache[baseName] or {}
                    extractIDs(data, AutoAnimCache[baseName], AutoSoundCache[baseName])
                end
            end
        end
    end

    local skinsFolder = assets:FindFirstChild("Skins")
    local skinKillers = skinsFolder and skinsFolder:FindFirstChild("Killers")
    if skinKillers then
        for _, baseKillerFolder in ipairs(skinKillers:GetChildren()) do
            local baseName = baseKillerFolder.Name:lower()
            AutoSkinCache[baseName] = AutoSkinCache[baseName] or {}
            for _, skinFolder in ipairs(baseKillerFolder:GetChildren()) do
                local skinName = skinFolder.Name:lower()
                AutoSkinCache[baseName][skinName] = { anim = {}, sound = {} }
                for _, obj in ipairs(skinFolder:GetDescendants()) do
                    if obj:IsA("ModuleScript") and obj.Name:lower():find("config") then
                        local ok, data = pcall(require, obj)
                        if ok and type(data) == "table" then
                            extractIDs(data, AutoSkinCache[baseName][skinName].anim, AutoSkinCache[baseName][skinName].sound)
                        end
                    end
                end
            end
        end
    end
end

task.spawn(function()
    task.wait(3)
    runAutoAdapter()
    notify("自动适配 (Auto Adapter)", "已完成全杀手/皮肤音效智能扫描")
end)

-- ============================================================
-- 冷却锁定
-- ============================================================
local lastBlockTime = 0
local function isBlockOnCooldown()
    return (tick() - lastBlockTime) < Settings.BlockCooldown
end
local function markBlockUsed()
    lastBlockTime = tick()
end

local function hookLocalBlockAnimation()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    animator.AnimationPlayed:Connect(function(track)
        if not track or not track.Animation then return end
        local name = (track.Animation.Name or ""):lower()
        if name:find("block") or name:find("guard") or name:find("parry") then
            markBlockUsed()
        end
    end)
end
LP.CharacterAdded:Connect(function()
    task.wait(1)
    hookLocalBlockAnimation()
end)
if LP.Character then hookLocalBlockAnimation() end

-- ============================================================
-- Killer 列表与瞄准函数
-- ============================================================
local function getKillerModels()
    local out = {}
    local pf = WS:FindFirstChild("Players")
    local kf = (pf and pf:FindFirstChild("Killers")) or WS:FindFirstChild("Killers") or WS:FindFirstChild("Entities")
    if kf then
        for _, c in ipairs(kf:GetChildren()) do
            if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then
                table.insert(out, c)
            end
        end
    end
    local char = LP.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        local alreadyIn = false
        for _, m in ipairs(out) do if m == char then alreadyIn = true; break end end
        if not alreadyIn then table.insert(out, char) end
    end
    return out
end

local function getModelRoot(m)
    return m and (m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("QueryHitbox") or m:FindFirstChild("RootPart"))
end

local function findNearestKillerRoot()
    local char = LP.Character
    if not char then return nil end
    local myRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("QueryHitbox")
    if not myRoot then return nil end
    local myPos = myRoot.Position
    local best, bestDist = nil, Settings.AimbotRadius
    for _, m in ipairs(getKillerModels()) do
        local r = getModelRoot(m)
        if r then
            local d = (r.Position - myPos).Magnitude
            if d < bestDist then bestDist = d; best = r end
        end
    end
    return best
end

local function aimAtRoot(targetRoot)
    local char = LP.Character
    if not char or not targetRoot or not targetRoot.Parent then return end
    local myRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("QueryHitbox")
    if not myRoot then return end
    local cam = WS.CurrentCamera

    local mp = myRoot.Position
    local dir = targetRoot.Position - mp
    if Settings.AimbotYawOnly then dir = Vector3.new(dir.X, 0, dir.Z) end
    if dir.Magnitude < 0.01 then return end

    if Settings.AimbotMode ~= "仅相机 (Camera Only)" then
        myRoot.CFrame = CFrame.lookAt(mp, mp + dir)
    end
    if (Settings.AimbotMode == "角色+相机+同步 (Char+Cam+Sync)" or Settings.AimbotMode == "仅相机 (Camera Only)") and cam then
        local cp = cam.CFrame.Position
        local cd = targetRoot.Position - cp
        if Settings.AimbotYawOnly then cd = Vector3.new(cd.X, 0, cd.Z) end
        if cd.Magnitude > 0.01 then cam.CFrame = CFrame.lookAt(cp, cp + cd) end
    end
end

-- ============================================================
-- Remote
-- ============================================================
local BlockRemote = nil
local function getRemote()
    if BlockRemote and BlockRemote.Parent then return BlockRemote end
    local paths = {
        {"Modules", "Network", "RemoteEvent"},
        {"Modules", "Network", "Network", "RemoteEvent"},
        {"Network", "RemoteEvent"},
        {"RemoteEvent"}
    }
    for _, path in ipairs(paths) do
        local ok, remote = pcall(function()
            local current = RS
            for _, name in ipairs(path) do
                current = current:WaitForChild(name, 2)
                if not current then return nil end
            end
            return current
        end)
        if ok and remote and remote:IsA("RemoteEvent") then
            BlockRemote = remote
            print("[MoonBlock] 成功获取远程事件: " .. table.concat(path, "."))
            return BlockRemote
        end
    end
    return nil
end

-- ============================================================
-- 【攻击核心】组合拳攻击函数
-- ============================================================
local function firePunchRemote()
    local r = getRemote()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    if Settings.PunchAimbot then
        local target = findNearestKillerRoot()
        if target then
            local oldAutoRotate = hum and hum.AutoRotate
            if hum then hum.AutoRotate = false end
            
            for _ = 1, Settings.AimbotLockFrames do
                if not target.Parent then break end
                aimAtRoot(target)
                RunSvc.RenderStepped:Wait()
            end
            
            if hum and oldAutoRotate ~= nil then hum.AutoRotate = oldAutoRotate end
        end
    end

    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function() tool:Activate() end)
        end
    end

    if r then
        pcall(function()
            r:FireServer("UseActorAbility", { "Punch" })
            r:FireServer("UseActorAbility", "Punch")
        end)
    end
end

-- ============================================================
-- 格挡触发（仅生成白框，碰撞检测已移入帧同步循环）
-- ============================================================
local function spawnBlockHitbox(slasher)
    if not slasher or not slasher.Parent then return end
    local root = slasher:FindFirstChild("HumanoidRootPart") or slasher:FindFirstChild("QueryHitbox") or slasher:FindFirstChild("RootPart")
    if not root then return end

    local hb = Instance.new("Part")
    hb.Name = "AutoBlockHitbox"
    hb.Size = Settings.BaseHitboxSize * Settings.HitboxScale
    hb.CFrame = root.CFrame * CFrame.new(0, 0, Settings.HitboxOffset)
    hb.Anchored = true
    hb.CanCollide = false
    hb.CanTouch = false
    hb.CanQuery = false
    hb.Color = Settings.HitboxColor
    hb.Material = Enum.Material.ForceField
    hb.Transparency = Settings.HitboxTransparency
    hb.Parent = WS
    
    FollowHitboxes[hb] = { slasher = slasher, offset = Settings.HitboxOffset, triggered = false }
    Debris:AddItem(hb, math.max(0.1, Settings.NORMAL_LIFETIME))

    local o = Instance.new("SelectionBox")
    o.Adornee = hb
    o.Color3 = Settings.HitboxColor
    o.Transparency = Settings.HitboxTransparency
    o.LineThickness = Settings.HitboxLineThickness
    o.Parent = hb
    Debris:AddItem(o, math.max(0.1, Settings.HIT_LIFETIME))
end

local tryTrigger
do
    local lastTriggerTime = {}
    tryTrigger = function(slasher)
        if not Settings.AutoBlockEnabled or not slasher or not slasher.Parent then return end
        
        local hum = slasher:FindFirstChildOfClass("Humanoid")
        if hum then
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Ragdoll or hum.PlatformStand then
                return
            end
        end
        
        if tick() - (lastTriggerTime[slasher] or 0) < 0.05 then return end
        lastTriggerTime[slasher] = tick()
        
        if Settings.PredictiveBlock then
            if not Settings.RespectCooldown or (tick() - lastGlobalBlockTime >= Settings.GlobalBlockCooldown) then
                lastGlobalBlockTime = tick()
                local r = getRemote()
                if r then
                    r:FireServer("UseActorAbility", { "Block" })
                end
            end
        end
        
        spawnBlockHitbox(slasher)
    end
end

-- ============================================================
-- 运行时白名单匹配（包含 DrakoBloxxer 音效智能识别）
-- ============================================================
local hookedKillers   = setmetatable({}, {__mode = "k"})
local hookedAnimators = setmetatable({}, {__mode = "k"})
local hookedSounds    = setmetatable({}, {__mode = "k"})

local function getKillerBaseName(killer)
    local name = killer.Name:lower()
    for base, _ in pairs(AutoAnimCache) do
        if name:find(base, 1, true) then return base end
    end
    return name
end

local function setupKiller(killer)
    if not killer or not killer.Parent or hookedKillers[killer] then return end
    hookedKillers[killer] = true

    local baseName = getKillerBaseName(killer)
    local skinName = nil
    local skinAttrs = {"SkinName","Skin","CurrentSkin","EquippedSkin","ActiveSkin"}
    for _, a in ipairs(skinAttrs) do
        local v = killer:GetAttribute(a)
        if type(v) == "string" and v ~= "" then skinName = v:lower(); break end
    end
    if not skinName then
        for _, c in ipairs(killer:GetChildren()) do
            if c:IsA("StringValue") and c.Name:lower():find("skin") then
                skinName = c.Value:lower(); break
            end
        end
    end
    if not skinName and AutoSkinCache[baseName] then
        for skinKey, _ in pairs(AutoSkinCache[baseName]) do
            if killer.Name:lower():find(skinKey, 1, true) then skinName = skinKey; break end
        end
    end

    local finalAnimIds = {}
    local finalSoundIds = {}
    if AutoAnimCache[baseName] then for id in pairs(AutoAnimCache[baseName]) do finalAnimIds[id] = true end end
    if AutoSoundCache[baseName] then for id in pairs(AutoSoundCache[baseName]) do finalSoundIds[id] = true end end
    if skinName and AutoSkinCache[baseName] and AutoSkinCache[baseName][skinName] then
        for id in pairs(AutoSkinCache[baseName][skinName].anim) do finalAnimIds[id] = true end
        for id in pairs(AutoSkinCache[baseName][skinName].sound) do finalSoundIds[id] = true end
    end

    -- 精准注入 Slasher 与 Noli 的专属硬编码攻击 ID
    if baseName:find("slasher") or baseName:find("noli") or killer.Name:lower():find("slasher") or killer.Name:lower():find("noli") then
        for id, _ in pairs(MANUAL_ATTACK_ANIM_IDS) do
            finalAnimIds[id] = true
        end
    end

    local hasConfig = next(finalAnimIds) ~= nil or next(finalSoundIds) ~= nil
    if hasConfig then
        print(string.format("[MoonBlock] 自动适配：%s (皮肤: %s)", baseName, skinName or "默认"))
    end

    local function hookAnimator()
        local hum = killer:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then return end
        if hookedAnimators[animator] then return end
        hookedAnimators[animator] = true

        animator.AnimationPlayed:Connect(function(track)
            if not track or not track.Animation then return end
            local id = track.Animation.AnimationId:match("%d+"); if not id then return end
            local animName = (track.Animation.Name or ""):lower()

            if Settings.DebugLog then
                print("[调试动画 (Debug Anim)] " .. killer.Name .. " 播放了: " .. tostring(track.Animation.Name) .. " ID: " .. id .. " 在白名单: " .. tostring(finalAnimIds[id]))
            end

            local killerHum = killer:FindFirstChildOfClass("Humanoid")
            if killerHum then
                local state = killerHum:GetState()
                if state == Enum.HumanoidStateType.Ragdoll or killerHum.PlatformStand then
                    return
                end
            end

            if Settings.IgnoreStun then
                for _, kw in ipairs(STUN_KEYWORDS) do
                    if animName:find(kw, 1, true) then
                        return
                    end
                end
            end

            if finalAnimIds[id] then
                tryTrigger(killer)
            end
        end)
    end
    hookAnimator()

    local function hookSound(d)
        if not d:IsA("Sound") or hookedSounds[d] then return end
        hookedSounds[d] = true

        local function onPlay()
            local id = tostring(d.SoundId):match("%d+"); if not id then return end
            local sName = d.Name:lower()

            if Settings.DebugLog then
                print("[调试音效 (Debug Sound)] " .. killer.Name .. " 播放了: " .. d.Name .. " ID: " .. id .. " 在白名单: " .. tostring(finalSoundIds[id]) .. " 名字含攻击词: " .. tostring(isAttackName(sName) and not isIgnoreName(sName)))
            end

            local killerHum = killer:FindFirstChildOfClass("Humanoid")
            if killerHum then
                local state = killerHum:GetState()
                if state == Enum.HumanoidStateType.Ragdoll or killerHum.PlatformStand then
                    return
                end
            end

            if Settings.IgnoreStun then
                for _, kw in ipairs(STUN_KEYWORDS) do
                    if sName:find(kw, 1, true) then return end
                end
            end

            -- 音效智能识别：白名单ID 或 名字含攻击关键词，都会触发
            if finalSoundIds[id] or (isAttackName(sName) and not isIgnoreName(sName)) then 
                tryTrigger(killer)
            end
        end

        d.Played:Connect(onPlay)
        d:GetPropertyChangedSignal("IsPlaying"):Connect(function() if d.IsPlaying then onPlay() end end)
    end
    for _, d in ipairs(killer:GetDescendants()) do hookSound(d) end
    killer.DescendantAdded:Connect(hookSound)
end

local function watchKillersFolder(kf)
    for _, k in ipairs(kf:GetChildren()) do
        if k:IsA("Model") then setupKiller(k) end
    end
    kf.ChildAdded:Connect(function(c)
        if c:IsA("Model") then task.wait(0.3); setupKiller(c) end
    end)
end

task.spawn(function()
    while true do
        local pf = WS:FindFirstChild("Players")
        local kf = (pf and pf:FindFirstChild("Killers")) or WS:FindFirstChild("Killers") or WS:FindFirstChild("Entities")
        if kf then watchKillersFolder(kf) end
        local char = LP.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            setupKiller(char)
        end
        task.wait(REFRESH_INTERVAL)
    end
end)

-- ============================================================
-- 🛡️ 智能攻击箱检测
-- ============================================================
local lastHitboxTrigger = {}

local IGNORE_PARTS = {
    ["collisionhitbox"] = true, ["queryhitbox"] = true, ["humanoidrootpart"] = true,
    ["head"] = true, ["torso"] = true, ["upper torso"] = true, ["lower torso"] = true,
    ["left arm"] = true, ["right arm"] = true, ["left leg"] = true, ["right leg"] = true,
    ["handl"] = true, ["handr"] = true, ["endohandl"] = true, ["endohandr"] = true,
}

local function isPartOfPlayer(part)
    local parent = part.Parent
    while parent and parent ~= Workspace do
        if Players:GetPlayerFromCharacter(parent) then return true end
        if parent:IsA("Model") and Players:GetPlayerFromCharacter(parent) then return true end
        parent = parent.Parent
    end
    return false
end

local function hookKillerHitbox(kf)
    kf.DescendantAdded:Connect(function(child)
        if not Settings.AutoBlockEnabled then return end
        if not child:IsA("BasePart") then return end
        
        local name = child.Name:lower()
        if IGNORE_PARTS[name] then return end
        if isPartOfPlayer(child) then return end
        
        local isRealHitbox = name:find("hitbox") or name:find("weapon") 
                             or name:find("sword") or name:find("blade") or name:find("attack")
                             or name:find("slap") or name:find("stomp") or name:find("grab")
        if not isRealHitbox then return end
        
        local killer = child:FindFirstAncestorOfClass("Model")
        if not killer or not killer:FindFirstChildOfClass("Humanoid") then return end
        
        local hum = killer:FindFirstChildOfClass("Humanoid")
        if hum then
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Ragdoll or hum.PlatformStand then
                return
            end
        end

        local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local dist = (child.Position - myRoot.Position).Magnitude
        if dist > 15 then return end
        
        local now = tick()
        if now - (lastHitboxTrigger[killer] or 0) < 0.3 then return end
        lastHitboxTrigger[killer] = now
        
        tryTrigger(killer)
    end)
end

task.spawn(function()
    while true do
        local pf = WS:FindFirstChild("Players")
        local kf = (pf and pf:FindFirstChild("Killers")) or WS:FindFirstChild("Killers") or WS:FindFirstChild("Entities")
        if kf then
            pcall(function() hookKillerHitbox(kf) end)
        end
        task.wait(REFRESH_INTERVAL)
    end
end)

-- ============================================================
-- ✨ ESP 透视核心
-- ============================================================
local ESP = {
    Enabled = false,
    Killers = true,
    Players = false,
    Generators = false,
    Medkits = false,
    ShowNames = true,
    ShowDistance = true,
    KillerColor = Color3.fromRGB(255, 70, 70),
    PlayerColor = Color3.fromRGB(70, 255, 130),
    GeneratorColor = Color3.fromRGB(255, 255, 0),
    MedkitColor = Color3.fromRGB(0, 255, 255),
    FillTransparency = 0.8,
    OutlineTransparency = 0,
    MaxDistance = 2000,
    UpdateRate = 0.5,
}

local espData = {}
local espTracers = {}
local generatorLines = {}

local function removeESP(model)
    local d = espData[model]; if not d then return end
    if d.highlight then pcall(function() d.highlight:Destroy() end) end
    if d.billboard then pcall(function() d.billboard:Destroy() end) end
    if espTracers[model] then
        pcall(function() espTracers[model]:Remove() end)
        espTracers[model] = nil
    end
    espData[model] = nil
end

local function applyESP(model, eType, customColor)
    if not model or not model.Parent or espData[model] then return end
    local root = getModelRoot(model) or model:FindFirstChild("ItemRoot") or model:FindFirstChildWhichIsA("BasePart")
    if not root then return end

    local color = customColor
    local hl = Instance.new("Highlight")
    hl.Name = "MoonBlockESP"
    hl.Adornee = model
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = ESP.FillTransparency
    hl.OutlineTransparency = ESP.OutlineTransparency
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = model

    local bb, label
    if ESP.ShowNames or ESP.ShowDistance then
        bb = Instance.new("BillboardGui")
        bb.Name = "MoonBlockESP_BB"
        bb.Adornee = root
        bb.Size = UDim2.new(0, 220, 0, 44)
        bb.StudsOffset = Vector3.new(0, 3.2, 0)
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.Parent = root

        label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = color
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.Text = model.Name
        label.Parent = bb
    end

    espData[model] = { highlight = hl, billboard = bb, label = label, eType = eType, color = color }
end

local function scanItemsESP()
    if not (ESP.Generators or ESP.Medkits) then return end
    
    local targetMap = WS:FindFirstChild("Map")
    if targetMap then targetMap = targetMap:FindFirstChild("Ingame") end
    if targetMap then targetMap = targetMap:FindFirstChild("Map") end
    
    if targetMap then
        for _, obj in ipairs(targetMap:GetChildren()) do
            if obj:IsA("Model") and not espData[obj] then
                local name = obj.Name:lower()
                
                if ESP.Generators and (name:find("generator") or name:find("fuse")) then
                    applyESP(obj, "generator", ESP.GeneratorColor)
                elseif ESP.Medkits and (name:find("medkit") or name:find("cola") or name:find("health") or name:find("bandage")) then
                    applyESP(obj, "medkit", ESP.MedkitColor)
                end
            end
        end
    end
end

-- ============================================================
-- ✨ 发电机解谜线路绘制
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        for _, line in pairs(generatorLines) do
            pcall(function() line:Remove() end)
        end
        generatorLines = {}

        if Settings.AutoSolve and HAS_DRAWING then
            local nodes = {}
            local playerGui = LP:FindFirstChild("PlayerGui")
            if playerGui then
                for _, gui in ipairs(playerGui:GetDescendants()) do
                    if gui:IsA("TextLabel") and gui.Visible 
                       and gui.AbsoluteSize.X > 15 and gui.AbsoluteSize.X < 60 
                       and gui.AbsoluteSize.Y > 15 and gui.AbsoluteSize.Y < 60 then
                        local txt = gui.Text or ""
                        local num = tonumber(txt)
                        if num and num >= 1 and num <= 9 then
                            table.insert(nodes, {obj = gui, num = num})
                        end
                    end
                end
            end

            if #nodes >= 2 then
                local groups = {}
                for _, node in ipairs(nodes) do
                    groups[node.num] = groups[node.num] or {}
                    table.insert(groups[node.num], node)
                end

                local colorMap = {
                    [1] = Color3.fromRGB(255, 0, 0),
                    [2] = Color3.fromRGB(0, 150, 255),
                    [3] = Color3.fromRGB(255, 255, 0),
                    [4] = Color3.fromRGB(0, 255, 0),
                    [5] = Color3.fromRGB(255, 0, 255),
                    [6] = Color3.fromRGB(255, 165, 0),
                    [7] = Color3.fromRGB(255, 105, 180),
                    [8] = Color3.fromRGB(0, 255, 255),
                    [9] = Color3.fromRGB(128, 0, 128)
                }

                for num, group in pairs(groups) do
                    if #group >= 2 then
                        for i = 1, #group - 1 do
                            local nodeA = group[i]
                            local nodeB = group[i+1]
                            local posA = nodeA.obj.AbsolutePosition + (nodeA.obj.AbsoluteSize / 2)
                            local posB = nodeB.obj.AbsolutePosition + (nodeB.obj.AbsoluteSize / 2)

                            local line = Drawing.new("Line")
                            line.From = Vector2.new(posA.X, posA.Y)
                            line.To = Vector2.new(posB.X, posB.Y)
                            line.Color = colorMap[num] or Color3.new(1,1,1)
                            line.Thickness = 3
                            line.Transparency = 0.9
                            line.Visible = true
                            table.insert(generatorLines, line)
                        end
                    end
                end
            end
        end
    end
end)

-- 主 ESP 循环
task.spawn(function()
    while true do
        if ESP.Enabled then
            if ESP.Killers then
                for _, m in ipairs(getKillerModels()) do
                    if not espData[m] then applyESP(m, "killer", ESP.KillerColor) end
                end
            end
            if ESP.Players then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character and not espData[p.Character] then
                        applyESP(p.Character, "player", ESP.PlayerColor)
                    end
                end
            end
            for m, d in pairs(espData) do
                local shouldRemove = false
                if not m.Parent then shouldRemove = true end
                if d.eType == "killer" and not ESP.Killers then shouldRemove = true end
                if d.eType == "player" and not ESP.Players then shouldRemove = true end
                if d.eType == "generator" and not ESP.Generators then shouldRemove = true end
                if d.eType == "medkit" and not ESP.Medkits then shouldRemove = true end
                if shouldRemove then removeESP(m) end
            end
        else
            for m in pairs(espData) do removeESP(m) end
        end
        task.wait(ESP.UpdateRate)
    end
end)

task.spawn(function()
    while true do
        if ESP.Enabled then
            scanItemsESP()
            for m, d in pairs(espData) do
                if (d.eType == "generator" or d.eType == "medkit") and not m.Parent then
                    removeESP(m)
                end
            end
        end
        task.wait(1.5)
    end
end)

RunSvc.RenderStepped:Connect(function()
    if not ESP.Enabled then return end
    local cam = WS.CurrentCamera; if not cam then return end
    local camPos = cam.CFrame.Position

    for m, d in pairs(espData) do
        local root = getModelRoot(m) or m:FindFirstChild("ItemRoot") or m:FindFirstChildWhichIsA("BasePart")
        if root then
            local dist = (root.Position - camPos).Magnitude
            if d.label then
                local txt = tostring(m.Name)
                if ESP.ShowDistance then txt = string.format("%s  [%dm]", m.Name, math.floor(dist)) end
                d.label.Text = txt
                d.label.Visible = dist <= ESP.MaxDistance
            end
            if d.highlight then d.highlight.Enabled = dist <= ESP.MaxDistance end
        end
    end
end)

-- ============================================================
-- UI
-- ============================================================
local LeftTabbox = Tabs["Main"]:AddLeftTabbox()
local MainSub    = LeftTabbox:AddTab("永恒的目的 (Main)")
local ConfigSub  = LeftTabbox:AddTab("配置 (Config)")

MainSub:AddToggle("SurvivorBlockToggle", {
    Text = "自动格挡 (Auto Block)", Default = false,
    Callback = function(v)
        Settings.AutoBlockEnabled = v
        if v then
            lastGlobalBlockTime = 0
            notify("MoonBlock", "自动格挡已开启 (Auto Block Enabled)")
        else
            notify("MoonBlock", "自动格挡已关闭 (Auto Block Disabled)")
        end
    end,
})

MainSub:AddToggle("PredictiveBlockToggle", {
    Text = "预测格挡 (Predictive Block) - 推荐开启", Default = true,
    Callback = function(v) 
        Settings.PredictiveBlock = v 
        notify("预测格挡 (Predictive)", v and "已开启 (Enabled) - 白框出现即格挡" or "已关闭 (Disabled)")
    end,
})

MainSub:AddButton("【测试】自动出拳 (Test Auto Punch)", function()
    notify("测试 (Test)", "正在执行出拳与自瞄测试...")
    firePunchRemote()
end)

MainSub:AddToggle("AutoPunchToggle", {
    Text = "格挡后自动出拳 (Auto Punch on Block)", Default = false,
    Callback = function(v) Settings.AutoPunch = v end,
})

MainSub:AddToggle("PunchAimbotToggle", {
    Text = "出拳自瞄 (Punch Aimbot)", Default = false,
    Callback = function(v) Settings.PunchAimbot = v end,
})

MainSub:AddDropdown("AimbotMode", {
    Values = { "角色+相机+同步 (Char+Cam+Sync)", "仅角色 (Char Only)", "仅相机 (Camera Only)" },
    Default = "角色+相机+同步 (Char+Cam+Sync)", Multi = false, Text = "自瞄模式 (Aimbot Mode)",
    Callback = function(v)
        if type(v) == "table" then for k in pairs(v) do Settings.AimbotMode = k; break end
        else Settings.AimbotMode = v end
    end,
})

MainSub:AddSlider("AimbotRadius", {
    Text = "自瞄范围 (Aimbot Radius)", Default = 500, Min = 10, Max = 1000, Rounding = 0,
    Callback = function(v) Settings.AimbotRadius = v end,
})

MainSub:AddToggle("AutoSolve", {
    Text = "发电机解谜辅助 (Generator Solver Assist)", Default = false,
    Callback = function(v)
        Settings.AutoSolve = v
        if v and not HAS_DRAWING then
            notify("解谜辅助 (Solver)", "当前执行器不支持 Drawing API，无法绘制连线！")
            Settings.AutoSolve = false
        else
            notify("解谜辅助 (Solver)", v and "开启 (Enabled)" or "关闭 (Disabled)")
        end
    end,
})

ConfigSub:AddToggle("IgnoreStunToggle", {
    Text = "忽略眩晕/受击动作 (Ignore Stun/Hurt)", Default = true,
    Callback = function(v) 
        Settings.IgnoreStun = v 
        notify("过滤 (Filter)", v and "已开启 (Enabled)" or "已关闭 (Disabled)")
    end,
})

ConfigSub:AddToggle("AutoMoveOnBlockToggle", {
    Text = "格挡时走向杀手 (Walk to Killer on Block) [默认关]", Default = false,
    Callback = function(v) 
        Settings.AutoMoveOnBlock = v 
        notify("走位 (Move)", v and "已开启 (Enabled) - 可能会增加格挡延迟" or "已关闭 (Disabled) - 保证格挡最快发送")
    end,
})

ConfigSub:AddSlider("GlobalBlockCooldown", {
    Text = "全局格挡冷却 (Global Block Cooldown)", Default = 0, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) 
        Settings.GlobalBlockCooldown = v 
        notify("格挡 (Block)", "全局冷却已设为: " .. tostring(v) .. "秒")
    end,
})

ConfigSub:AddToggle("RespectCooldown", {
    Text = "冷却时不触发格挡 (Respect Cooldown)", Default = true,
    Callback = function(v) Settings.RespectCooldown = v end,
})

ConfigSub:AddSlider("BlockCooldown", {
    Text = "格挡冷却时间 (Block Cooldown)", Default = 5, Min = 0.5, Max = 15, Rounding = 2,
    Callback = function(v) Settings.BlockCooldown = v end,
})

ConfigSub:AddToggle("DebugLogToggle", {
    Text = "开启调试日志 (Enable Debug Log)", Default = false,
    Callback = function(v) Settings.DebugLog = v end,
})

local HitboxRight = Tabs["Main"]:AddRightGroupbox("判定框设置 (Hitbox Settings)", "sliders")
HitboxRight:AddSlider("HitboxSize", {
    Text = "整体大小 (Overall Size)", Default = 1.0, Min = 0.2, Max = 3.0, Rounding = 2,
    Callback = function(v) Settings.HitboxScale = v end,
})
HitboxRight:AddSlider("SpawnDuration", {
    Text = "存在时间 (Spawn Duration)", Default = 0.6, Min = 0.1, Max = 3.0, Rounding = 2,
    Callback = function(v) Settings.SpawnDuration = v end,
})
HitboxRight:AddSlider("HitboxOffset", {
    Text = "前后偏移 (Forward Offset)", Default = -1.5, Min = -15, Max = 0, Rounding = 2,
    Callback = function(v) 
        Settings.HitboxOffset = v 
        notify("Hitbox", "偏移量已调整为: " .. tostring(v))
    end,
})

HitboxRight:AddSlider("HitboxLineThickness", {
    Text = "白框粗细 (Line Thickness)", Default = 0.05, Min = 0.01, Max = 0.5, Rounding = 2,
    Callback = function(v) 
        Settings.HitboxLineThickness = v 
        notify("Hitbox", "白框粗细已调整为: " .. tostring(v))
    end,
})
HitboxRight:AddSlider("HitboxTransparencySlider", {
    Text = "透明度 (Transparency)", Default = 0.6, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) Settings.HitboxTransparency = v end,
})
HitboxRight:AddSlider("NormalLifetime", {
    Text = "白框显示时间 (Normal Lifetime)", Default = 0.5, Min = 0.1, Max = 3.0, Rounding = 2,
    Callback = function(v) Settings.NORMAL_LIFETIME = v end,
})
HitboxRight:AddSlider("HitLifetime", {
    Text = "命中框显示时间 (Hit Lifetime)", Default = 0.6, Min = 0.1, Max = 3.0, Rounding = 2,
    Callback = function(v) Settings.HIT_LIFETIME = v end,
})

-- ESP Tab
local EspLeft  = Tabs["ESP"]:AddLeftGroupbox("ESP", "eye")
local EspRight = Tabs["ESP"]:AddRightGroupbox("过滤 (Filter)", "filter")

EspLeft:AddToggle("ESP_Enabled", { Text = "启用透视 (Enable ESP)", Default = false, Callback = function(v) ESP.Enabled = v end })
EspLeft:AddToggle("ESP_Names", { Text = "显示名字 (Show Names)", Default = true, Callback = function(v) ESP.ShowNames = v end })
EspLeft:AddToggle("ESP_Dist", { Text = "显示距离 (Show Distance)", Default = true, Callback = function(v) ESP.ShowDistance = v end })
EspLeft:AddSlider("ESP_Max", { Text = "最大距离 (Max Distance)", Default = 2000, Min = 100, Max = 5000, Rounding = 0, Callback = function(v) ESP.MaxDistance = v end })

EspRight:AddToggle("ESP_Killers", { Text = "杀手透视 (Killers)", Default = true, Callback = function(v) ESP.Killers = v end })
EspRight:AddToggle("ESP_Players", { Text = "玩家透视 (Players)", Default = false, Callback = function(v) ESP.Players = v end })
EspRight:AddToggle("ESP_Generators", { Text = "发电机透视 (Generators)", Default = false, Callback = function(v) ESP.Generators = v end })
EspRight:AddToggle("ESP_Medkits", { Text = "医疗包透视 (Medkits)", Default = false, Callback = function(v) ESP.Medkits = v end })

EspRight:AddLabel("杀手颜色 (Killer Color)"):AddColorPicker("ESP_KColor", { Default = ESP.KillerColor, Title = "Killer Color", Callback = function(c) ESP.KillerColor = c end })
EspRight:AddLabel("玩家颜色 (Player Color)"):AddColorPicker("ESP_PColor", { Default = ESP.PlayerColor, Title = "Player Color", Callback = function(c) ESP.PlayerColor = c end })
EspRight:AddLabel("发电机颜色 (Generator Color)"):AddColorPicker("ESP_GColor", { Default = ESP.GeneratorColor, Title = "Generator Color", Callback = function(c) ESP.GeneratorColor = c end })
EspRight:AddLabel("医疗包颜色 (Medkit Color)"):AddColorPicker("ESP_MColor", { Default = ESP.MedkitColor, Title = "Medkit Color", Callback = function(c) ESP.MedkitColor = c end })

EspRight:AddSlider("ESP_FillT", { Text = "填充透明度 (Fill Transparency)", Default = 0.8, Min = 0, Max = 1, Rounding = 2, Callback = function(v) ESP.FillTransparency = v end })
EspRight:AddSlider("ESP_UpdateRate", { Text = "扫描频率 (Scan Rate)", Default = 0.5, Min = 0.1, Max = 2, Rounding = 2, Callback = function(v) ESP.UpdateRate = v end })

-- UI Settings
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("菜单 (Menu)", "wrench")
MenuGroup:AddLabel("菜单按键 (Menu Keybind)"):AddKeyPicker("MenuKeybind", { Default = "F", NoUI = true, Text = "Menu keybind" })

MenuGroup:AddButton("卸载 (Unload)", function()
    for _, tr in pairs(espTracers) do pcall(function() tr:Remove() end) end
    for m in pairs(espData) do pcall(removeESP, m) end
    for _, line in pairs(generatorLines) do pcall(function() line:Remove() end) end
    Library:Unload()
end)
Library.ToggleKeybind = Library.Options.MenuKeybind

notify("永恒的目的 (Eternal Destination)", "V55已加载 - 已升级UI并加入配置分组，修复DrakoBloxxer识别")