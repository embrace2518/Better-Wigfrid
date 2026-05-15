-- 动作：独唱（WATHGRITHR_SING）
-- 效果：演唱期间雇佣附近的猪人/鱼人、照料作物，并根据数量提供灵感值

local ONEOF_TAGS = { "pig", "merm", "farm_plant" }
local CANT_TAGS = { "werepig", "player" }

local function CountNearbyCrops(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local count = 0
    for _, v in ipairs(TheSim:FindEntities(x, y, z, TUNING.ONEMANBAND_RANGE, nil, CANT_TAGS, ONEOF_TAGS)) do
        if v.components.farmplanttendable ~= nil then
            count = count + 1
        end
    end
    return count
end

local function EnsureDailyReset(inst)
    local day = GLOBAL.TheWorld.state.cycles
    if inst._sing_daily_day ~= day then
        inst._sing_daily_day = day
        inst._sing_daily_hire = 0
        inst._sing_daily_crop = 0
    end
end

local function OnSingRollCall(inst)
    if inst.sg.statemem.phase ~= 3 then return end
    local now = GLOBAL.GetTime()
    if inst._sing_inspire_cooldown ~= nil and now < inst._sing_inspire_cooldown then
        inst._sing_prev_followers = inst.components.leader:GetNumFollowers()
        return
    end

    EnsureDailyReset(inst)

    local prev_followers = inst._sing_prev_followers or 0
    local curr_followers = inst.components.leader:GetNumFollowers()
    inst._sing_prev_followers = curr_followers
    local hire_delta = curr_followers - prev_followers
    local crop_count = CountNearbyCrops(inst)

    -- 分别计算生物和作物灵感，受每日上限约束
    local hire_inspire = math.min(hire_delta * TUNING.WATHGRITHR_SING_INSPIRE_PER_HIRE, TUNING.WATHGRITHR_SING_DAILY_HIRE_MAX - inst._sing_daily_hire)
    local crop_inspire = math.min(crop_count * TUNING.WATHGRITHR_SING_INSPIRE_PER_CROP, TUNING.WATHGRITHR_SING_DAILY_CROP_MAX - inst._sing_daily_crop)
    local total = math.max(hire_inspire, 0) + math.max(crop_inspire, 0)

    if hire_delta > 0 then
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_SING_HIRE"))
    end
    if crop_count > 0 then
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_SING_CROP"))
    end

    if total > 0 and inst.components.singinginspiration ~= nil then
        inst.components.singinginspiration:DoDelta(total)
        inst._sing_daily_hire = inst._sing_daily_hire + math.max(hire_inspire, 0)
        inst._sing_daily_crop = inst._sing_daily_crop + math.max(crop_inspire, 0)
        inst._sing_inspire_cooldown = now + TUNING.WATHGRITHR_SING_INSPIRE_COOLDOWN
    end
end

local function SetHireTime(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    for ent in pairs(inst.components.leader.followers) do
        if ent:HasAnyTag(ONEOF_TAGS) and ent.components.follower ~= nil then
            ent.components.follower:AddLoyaltyTime(TUNING.WATHGRITHR_SING_HIRE_TIME)
        end
    end
end

local WATHGRITHR_SING = Action({ priority=2, mount_valid=false })
WATHGRITHR_SING.id = "WATHGRITHR_SING"
WATHGRITHR_SING.str = "独唱"
WATHGRITHR_SING.fn = function(act)
    local doer = act.doer
    if doer.components.leaderrollcall ~= nil then
        doer._sing_prev_followers = doer.components.leader:GetNumFollowers()
        doer.components.leaderrollcall:SetOnRollCallFn(OnSingRollCall)
        doer.components.leaderrollcall:Enable()
    end
    if doer.components.rechargeable ~= nil then
        doer.components.rechargeable:Discharge(60)
    end
    return true
end

AddAction(WATHGRITHR_SING)

local function AddWathgrithrSingState(stategraph)
    stategraph.states["wathgrithr_sing"] = GLOBAL.State{
        name = "wathgrithr_sing",
        tags = {"doing", "busy", "nopredict"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.sg.statemem.phase = 1
            -- 1. 屈膝礼
            inst.AnimState:PlayAnimation("idle_wathgrithr")
        end,

        ontimeout = function(inst)
            -- 3. 演唱循环结束(6秒), 播放收尾
            inst.sg.statemem.phase = 4
            inst.AnimState:PlayAnimation("sing_loop_pst")
            SetHireTime(inst)
            if inst.components.leaderrollcall ~= nil then
                inst.components.leaderrollcall:Disable()
            end
        end,

        onexit = function(inst)
            -- 安全关闭：状态意外退出时也停止
            SetHireTime(inst)
            if inst.components.leaderrollcall ~= nil then
                inst.components.leaderrollcall:Disable()
            end
        end,

        events = {
            GLOBAL.EventHandler("animover", function(inst)
                local phase = inst.sg.statemem.phase
                if phase == 1 then
                    -- 1→2: 屈膝礼结束, 演唱准备
                    inst.sg.statemem.phase = 2
                    inst.AnimState:PlayAnimation("sing_loop_pre")
                elseif phase == 2 then
                    -- 2→3: 准备结束, 开始循环演唱(6秒)，PerformBufferedAction 开启雇佣/照料
                    inst.sg.statemem.phase = 3
                    inst.AnimState:PlayAnimation("sing_loop", true)
                    inst.sg:SetTimeout(6)
                    inst:PerformBufferedAction()
                elseif phase == 4 then
                    -- 4→5: 收尾结束, 鞠躬
                    inst.sg.statemem.phase = 5
                    inst.AnimState:PlayAnimation("bow_pre")
                    inst.AnimState:PushAnimation("bow_pst", false)
                end
            end),
            GLOBAL.EventHandler("animqueueover", function(inst)
                if inst.sg.statemem.phase == 5 then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    }
end

AddStategraphPostInit("wilson", AddWathgrithrSingState)
AddStategraphPostInit("wilson_client", AddWathgrithrSingState)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(WATHGRITHR_SING, "wathgrithr_sing"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(WATHGRITHR_SING, "wathgrithr_sing"))

AddComponentAction("SCENE", "singinginspiration", function(inst, doer, actions)
    if not doer.components.showmode:IsActive()
        and doer.components.rechargeable ~= nil
        and doer.components.rechargeable:IsCharged() then
        table.insert(actions, ACTIONS.WATHGRITHR_SING)
    end
end)
