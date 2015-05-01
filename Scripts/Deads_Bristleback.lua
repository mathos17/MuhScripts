require("libs.ScriptConfig")
require("libs.Utils")
require("libs.TargetFind")
require("libs.Animations")
require("libs.Skillshot")

-- Config --
local config = ScriptConfig.new()
config:SetParameter("Chase", "S", config.TYPE_HOTKEY)
config:SetParameter("Quill", "D", config.TYPE_HOTKEY)
config:Load()

local ChaseKey = config.Chase
local toggleKey = config.Quill

-- Globals --
local reg = false
local victim = nil
local target = nil
local sleep = 0
local attack = 0
local move = 0
local start = false
local reset = nil
local active = false
local monitor = client.screenSize.x/1600
local F14 = drawMgr:CreateFont("F14","Tahoma",14*monitor,550*monitor) 
local statusText = drawMgr:CreateText(-20*monitor,80*monitor,-1,"Targeting",F14) statusText.visible = false
local quillText  = drawMgr:CreateText(10*monitor,560*monitor,-1,"(" .. string.char(toggleKey) .. ") Auto Quill: Off",F14) quillText.visible = false
local me = entityList:GetMyHero()

-- Load --
function Load()
    if PlayingGame() then
        if me.classId ~= CDOTA_Unit_Hero_Bristleback then 
            script:Disable() 
        else
            reg = true
            victim = nil
            start = false
            sleep = 0
            reset = nil
            target = nil
            quillText.visible = true
            script:RegisterEvent(EVENT_KEY,Key)
            script:RegisterEvent(EVENT_TICK,Tick)
            script:UnregisterEvent(Load)
        end
    end
end

-- Key --
function Key(msg,code)
	if not PlayingGame() or client.chat then return end	
	if IsKeyDown(toggleKey) then
		active = not active
		if active then
			quillText.text = "(" .. string.char(toggleKey) .. ") Auto Quill: On"
		else
			quillText.text = "(" .. string.char(toggleKey) .. ") Auto Quill: Off"
		end
	end
end

-- Hotkey Text --
local hotkeyText
if string.byte("A") <= toggleKey and toggleKey <= string.byte("Z") then
	hotkeyText = string.char(toggleKey)
else
	hotkeyText = ""..toggleKey
end

-- Main --
function Tick(tick)
    local attackRange = me.attackRange
    local quillRange = 625
    
    if victim and victim.visible then
        if not statusText.visible then
            statusText.visible = true
        end
    else
        statusText.visible = false
    end
    
    if active and me.alive then
        local target = targetFind:GetHighestPercentHP(quillRange,true,false)
        local W = me:GetAbility(2)
        local treads = me:FindItem("item_power_treads")
        
        if target and SleepCheck("change") then
            local distance2t = GetDistance2D(target,me)
            
            if W and W:CanBeCasted() and me:CanCast() and distance2t <= quillRange then
                if treads then
                    if treads.bootsState ~= 1 then
                        me:SetPowerTreadsState(PT_INT)
                        Sleep(200, "change")
                    end
                    if treads.bootsState == 1 then
                        me:CastAbility(W)
                    end
                end
                if not treads then
                    me:CastAbility(W)
                end               
            end
            if W and not W:CanBeCasted() and treads and treads.bootsState ~= 0 and not IsKeyDown(ChaseKey) then
                me:SetPowerTreadsState(PT_STR)
                Sleep(200, "change")
            end
        end
    end
            
    if IsKeyDown(ChaseKey) and not client.chat then
        if Animations.CanMove(me) or not start or (victim and GetDistance2D(victim,me) > attackRange+1000) then
            start = true
            local MouseOver = targetFind:GetLastMouseOver(1000)
            if MouseOver and (not victim or GetDistance2D(me,victim) > attackRange or not victim.alive) and SleepCheck("victim") then            
                victim = MouseOver
                statusText.entity = victim
                statusText.entityPosition = Vector(0,0,victim.healthbarOffset)
                Sleep(250,"victim")
            end
        end
        if victim and GetDistance2D(me,victim) <= 1000 and victim.hero then
            if tick > attack and SleepCheck("casting") then
                local Q = me:GetAbility(1)
                local W = me:GetAbility(2)
                local distance = GetDistance2D(victim,me)
                local disabled = victim:IsHexed() or victim:IsStunned()                
                local linkens = victim:IsLinkensProtected()
                local Bash = me:FindItem("item_abyssal_blade")
                local Shivas = me:FindItem("item_shivas_guard")
            
                if Bash and Bash:CanBeCasted() and distance <= attackRange+150 and not disabled and not linkens then
                    me:CastAbility(Bash, victim)
                end
                
                if Shivas and Shivas:CanBeCasted() and distance <= Q.castRange then
                    me:CastAbility(Shivas)
                end
                
                if not Animations.isAttacking(me) then
                    local immune = victim:IsMagicImmune()
                    local treads = me:FindItem("item_power_treads")
                    
                    if Q and Q:CanBeCasted() and me:CanCast() and distance <= Q.castRange and not immune then
                        if treads then
                            if treads.bootsState ~= 1 and SleepCheck("change2") then
                                me:SetPowerTreadsState(PT_INT)
                                Sleep(200, "change2")
                            end
                            if treads.bootsState == 1 then
                                me:CastAbility(Q, victim)
                                Sleep(Q:FindCastPoint()*100+me:GetTurnTime(victim)*100, "casting")
                            end
                        end
                        if not treads then
                            me:CastAbility(Q, victim)
                            Sleep(Q:FindCastPoint()*1000+me:GetTurnTime(victim)*1000, "casting")
                        end                        
                    end
                    if Q and not Q:CanBeCasted() and treads and treads.bootsState ~= 0 and SleepCheck("change2") and not W:CanBeCasted() then
                        me:SetPowerTreadsState(PT_STR)
                        Sleep(200, "change2")
                    end                                 
                end
                me:Attack(victim)
                attack = tick + 100
            end
        elseif tick > move and SleepCheck("casting") then
                if victim then
                    if victim.visible then
                        local xyz = SkillShot.PredictedXYZ(victim,me:GetTurnTime(victim)*1000+client.latency+500)
                        me:Move(xyz)
                    else
                        me:Follow(victim)
                    end
                else
                me:Move(client.mousePosition)
            end
            move = tick + 100
            start = false
        end
    elseif victim then
        if not reset then
            reset = client.gameTime
        elseif (client.gameTime - reset) >= 3 then
            victim = nil
        end
        start = false
    end
end

-- Close --
function GameClose()
    collectgarbage("collect")
    if reg then
        reg = false
        statusText.visible = false
        quillText.visible = false
        activ = false
        victim = nil
        start = false
        reset = nil
        target = nil
        script:UnregisterEvent(Tick)
        script:UnregisterEvent(Key)
        script:RegisterEvent(EVENT_TICK,Load)
    end
end

script:RegisterEvent(EVENT_CLOSE,GameClose)
script:RegisterEvent(EVENT_TICK,Load)
