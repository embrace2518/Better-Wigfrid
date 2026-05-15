-- 剧本开幕/谢幕动作

local SHOW_COOLDOWN = TUNING.TOTAL_DAY_TIME * 0.5 -- 4 minutes

-- 动作定义
local OPENSHOW = Action({ priority=2, mount_valid=false })
OPENSHOW.str = "开幕"
OPENSHOW.id = "OPENSHOW"
OPENSHOW.fn = function(act)
    local doer = act.doer
    if doer.components.showmode:IsActive() then
        doer.components.talker:Say("演出正在进行！")
    elseif #doer.components.singinginspiration.active_songs < 2 then
        doer.components.talker:Say("至少有两首歌曲作为开场白")
        return false
    end
    doer.components.talker:Say("演出正式开始！")
    doer.components.showmode:Enter(#doer.components.singinginspiration.active_songs)
    if act.invobject ~= nil then
        act.invobject.components.rechargeable:Discharge(SHOW_COOLDOWN)
    end
    return true
end

local CLOSESHOW = Action({ priority=3, mount_valid=false })
CLOSESHOW.id = "CLOSESHOW"
CLOSESHOW.str = "谢幕"
CLOSESHOW.fn = function(act)
    local doer = act.doer
    if not doer.components.showmode:IsActive() then
        doer.components.talker:Say("演出已经结束！")
    end
    doer.components.talker:Say("演出到此为止！")
    doer.components.showmode:Exit()
    if act.invobject ~= nil then
        act.invobject.components.rechargeable:Discharge(SHOW_COOLDOWN)
    end
    return true
end

AddAction(OPENSHOW)
AddAction(CLOSESHOW)

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
