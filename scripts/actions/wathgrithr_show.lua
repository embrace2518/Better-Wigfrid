-- 剧本开幕/谢幕动作

local SHOW_COOLDOWN = TUNING.TOTAL_DAY_TIME * 0.5 -- 4 minutes

local function SpawnShadowHands(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local num_hands = 4
    for i = 1, num_hands do
        local angle = (i - 1) * (TWOPI / num_hands)
        local radius = 1.5
        local hx = x + math.cos(angle) * radius
        local hz = z + math.sin(angle) * radius
        local hy = y + 2.5 + math.random() * 1.5
        local fx = SpawnPrefab("shadowhand_fx")
        if fx ~= nil then
            fx.Transform:SetPosition(hx, hy, hz)
        end
    end
end

-- 动作定义
ACTIONS.OPENSHOW = Action({ priority=2, mount_valid=true })
ACTIONS.OPENSHOW.str = "开幕"
ACTIONS.OPENSHOW.id = "OPENSHOW"
ACTIONS.OPENSHOW.fn = function(act)
    local doer = act.doer
    if doer:HasTag("wathgrithr_show") then
        doer.components.talker:Say("演出正在进行！")
    elseif #doer.components.singinginspiration.active_songs < 2 then
        doer.components.talker:Say("至少有两首歌曲作为开场白")
    end
    doer.components.talker:Say("演出正式开始！")
    doer:AddTag("wathgrithr_show")
    if doer._showlight ~= nil then doer._showlight:Remove() end
    doer._showlight = SpawnPrefab("booklight", nil, 0)
    doer._showlight.entity:SetParent(doer.entity)
    doer._show_start_time = GetTime()
    doer.components.eater:SetDiet({FOODGROUP.OMNI}, {FOODTYPE.MEAT, FOODTYPE.GOODIES})
    doer.components.combat.damagemultiplier = 1 + 0.1 * #doer.components.singinginspiration.active_songs
    doer.components.health:SetAbsorptionAmount(1 - 0.1 * #doer.components.singinginspiration.active_songs)
    doer.SoundEmitter:PlaySound("stageplay_set/statue_lyre/stinger_intro_act1")
    if act.invobject ~= nil then
        act.invobject.components.rechargeable:Discharge(SHOW_COOLDOWN)
    end
    SpawnShadowHands(doer)
    local fx = SpawnPrefab("marionette_appear_fx")
    if fx ~= nil then fx.Transform:SetPosition(doer.Transform:GetWorldPosition()) end
    return true
end

ACTIONS.CLOSESHOW = Action({ priority=3, mount_valid=true })
ACTIONS.CLOSESHOW.str = "谢幕"
ACTIONS.CLOSESHOW.id = "CLOSESHOW"
ACTIONS.CLOSESHOW.fn = function(act)
    local doer = act.doer
    if not doer:HasTag("wathgrithr_show") then
        doer.components.talker:Say("演出已经结束！")
    end
    doer.components.talker:Say("演出到此为止！")
    doer:RemoveTag("wathgrithr_show")
    if doer._showlight ~= nil then
        doer._showlight:Remove()
        doer._showlight = nil
    end
    doer._show_start_time = nil
    doer.components.eater:SetDiet({ FOODGROUP.OMNI })
    doer.components.combat.damagemultiplier = 1
    doer.components.health:SetAbsorptionAmount(1)
    doer.SoundEmitter:PlaySound("stageplay_set/statue_lyre/stinger_outro")
    if act.invobject ~= nil then
        act.invobject.components.rechargeable:Discharge(SHOW_COOLDOWN)
    end
    SpawnShadowHands(doer)
    local fx = SpawnPrefab("marionette_disappear_fx")
    if fx ~= nil then fx.Transform:SetPosition(doer.Transform:GetWorldPosition()) end
    return true
end

AddAction(ACTIONS.OPENSHOW)
AddAction(ACTIONS.CLOSESHOW)

-- stategraph 状态
local function AddShowState(stategraph, state_name, anim_pre, anim_main)
    stategraph.states[state_name] = State{
        name = state_name,
        tags = {"busy", "doing"},
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation(anim_pre)
            inst.AnimState:PushAnimation(anim_main, false)
            inst.AnimState:PushAnimation("idle", false)
            inst.sg:SetTimeout(4 * FRAMES)
        end,
        ontimeout = function(inst)
            inst:PerformBufferedAction()
        end,
        events = {
            EventHandler("animqueueover", function(inst)
                if inst.sg:HasStateTag("busy") then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    }
end

local function AddShowStates(stategraph)
    AddShowState(stategraph, "show_open", "sing_pre", "sing")
    AddShowState(stategraph, "show_close", "bow_pre", "bow_pst")
end

AddStategraphPostInit("wilson", AddShowStates)
AddStategraphPostInit("wilson_client", AddShowStates)

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.OPENSHOW, "show_open"))
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.CLOSESHOW, "show_close"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.OPENSHOW, "show_open"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.CLOSESHOW, "show_close"))
