-- 动作：独唱
local HIRE_TAGS = { "pig", "merm" }
local CANT_TAGS = { "werepig", "player", "INLIMBO", "NOCLICK" }

local function OnSingVerse(inst)
    if not inst:HasTag("wathgrithr_singing") then return end

    inst.SoundEmitter:PlaySound("dontstarve/music/gramophone", nil, 0.5)

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.WATHGRITHR_SING_RANGE, nil, CANT_TAGS)

    for _, ent in ipairs(ents) do
        if ent:HasAnyTag(HIRE_TAGS) and ent.components.follower ~= nil then
            if not inst.components.leader:IsFollower(ent)
                and inst.components.leader:CountFollowers() < TUNING.WATHGRITHR_SING_MAX_FOLLOWERS then
                inst.components.leader:AddFollower(ent)
            end
            if inst.components.leader:IsFollower(ent) then
                ent.components.follower:AddLoyaltyTime(TUNING.WATHGRITHR_SING_HIRE_TIME)
            end
        end
        if ent.components.farmplanttendable ~= nil then
            ent.components.farmplanttendable:TendTo(inst)
        end
        if ent:HasTag("rabbit") and ent.components.follower ~= nil then
            if not inst.components.leader:IsFollower(ent)
                and inst.components.leader:CountFollowers() < TUNING.WATHGRITHR_SING_MAX_FOLLOWERS then
                inst.components.leader:AddFollower(ent)
            end
            if inst.components.leader:IsFollower(ent) then
                ent.components.follower:AddLoyaltyTime(TUNING.WATHGRITHR_SING_HIRE_TIME)
            end
        end
        if ent:HasTag("beefalo") and not (ent.components.health and ent.components.health:IsDead()) then
            if ent.components.domesticatable ~= nil then
                local day = TheWorld.state.cycles
                if ent._sing_dom_day ~= day then
                    ent._sing_dom_day = day
                    ent._sing_dom_given = 0
                end
                local cap = TUNING.WATHGRITHR_SING_DOMESTICATION_CAP_PER_DAY
                local per = TUNING.WATHGRITHR_SING_DOMESTICATION_PER_VERSE
                local to_give = math.min(per, cap - (ent._sing_dom_given or 0))
                if to_give > 0 then
                    ent.components.domesticatable:DeltaDomestication(to_give, inst)
                    ent.components.domesticatable:DeltaObedience(to_give)
                    ent._sing_dom_given = (ent._sing_dom_given or 0) + to_give
                end
            end
            if ent.components.combat ~= nil then
                ent.components.combat:GiveUp()
            end
            if ent._wathgrithr_pacified_task ~= nil then
                ent._wathgrithr_pacified_task:Cancel()
            end
            ent:AddTag("wathgrithr_pacified")
            ent._wathgrithr_pacified_task = ent:DoTaskInTime(2.5, function(e)
                e:RemoveTag("wathgrithr_pacified")
                e._wathgrithr_pacified_task = nil
            end)
        end
    end
end

local WATHGRITHR_SING = Action({ priority = 2, mount_valid = false })
WATHGRITHR_SING.id = "WATHGRITHR_SING"
WATHGRITHR_SING.str = "独唱"
WATHGRITHR_SING.fn = function(act)
    local doer = act.doer
    local now = GetTime()
    if doer._sing_cooldown and now < doer._sing_cooldown then return false end
    if doer.components.singinginspiration ~= nil then
        if doer.components.singinginspiration.current < TUNING.WATHGRITHR_SING_VERSE_COST then
            return false
        end
        doer.components.singinginspiration:DoDelta(-TUNING.WATHGRITHR_SING_VERSE_COST)
    end
    doer._sing_cooldown = now + TUNING.WATHGRITHR_SING_DURATION + TUNING.WATHGRITHR_SING_COOLDOWN
    return true
end

AddAction(WATHGRITHR_SING)

local function AddSingStates(stategraph)
    -- 屈膝礼 (参照 acting_curtsy)
    stategraph.states["wathgrithr_sing_bow"] = State{
        name = "wathgrithr_sing_bow",
        tags = { "busy", "doing" },
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("idle_wathgrithr")
        end,
        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("wathgrithr_sing_pre")
            end),
        },
    }

    -- 演唱准备
    stategraph.states["wathgrithr_sing_pre"] = State{
        name = "wathgrithr_sing_pre",
        tags = { "busy", "doing" },
        onenter = function(inst)
            inst.AnimState:PlayAnimation("sing_loop_pre")
        end,
        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("wathgrithr_sing_loop")
            end),
        },
    }

    -- 4秒演唱循环 (参照 charlie_stage_post "narrate")
    stategraph.states["wathgrithr_sing_loop"] = State{
        name = "wathgrithr_sing_loop",
        tags = { "busy", "doing" },
        onenter = function(inst)
            inst.AnimState:PlayAnimation("sing_loop", true)
            inst.sg:SetTimeout(4)
            inst:PerformBufferedAction()
        end,
        ontimeout = function(inst)
            -- 启动回声 buff
            inst:AddTag("wathgrithr_singing")
            inst._sing_notes = SpawnPrefab("wathgrithr_sing_notes")
            inst._sing_notes.entity:SetParent(inst.entity)
            inst._sing_notes.Transform:SetPosition(0, 3, 0)
            inst._sing_verse_task = inst:DoPeriodicTask(TUNING.WATHGRITHR_SING_VERSE_INTERVAL, OnSingVerse)
            inst.SoundEmitter:PlaySound("dontstarve/music/gramophone", "singing_music")
            inst.components.talker:Say("一展歌喉！")
            -- 10秒后结束回声 + 退场
            inst._sing_end_task = inst:DoTaskInTime(TUNING.WATHGRITHR_SING_DURATION, function(inst)
                inst:RemoveTag("wathgrithr_singing")
                inst.SoundEmitter:KillSound("singing_music")
                if inst._sing_notes ~= nil then
                    inst._sing_notes:Remove()
                    inst._sing_notes = nil
                end
                if inst._sing_verse_task ~= nil then
                    inst._sing_verse_task:Cancel()
                    inst._sing_verse_task = nil
                end
                inst.components.talker:Say("余音绕梁！")
                if inst.sg ~= nil then
                    inst.sg:GoToState("wathgrithr_sing_pst")
                end
            end)
            inst.sg:GoToState("idle")
        end,
    }

    -- 退场 (参照 acting_bow: PlayAnimation + PushAnimation + animqueueover)
    stategraph.states["wathgrithr_sing_pst"] = State{
        name = "wathgrithr_sing_pst",
        tags = { "busy", "doing" },
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("sing_loop_pst")
            inst.AnimState:PushAnimation("bow_pre", false)
            inst.AnimState:PushAnimation("bow_pst", false)
        end,
        events = {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    }
end

AddStategraphPostInit("wilson", AddSingStates)
AddStategraphPostInit("wilson_client", AddSingStates)

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.WATHGRITHR_SING, "wathgrithr_sing_bow"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.WATHGRITHR_SING, "wathgrithr_sing_bow"))

AddComponentAction("SCENE", "singinginspiration", function(inst, doer, actions)
    if not doer.components.showmode:IsActive()
        and (doer._sing_cooldown == nil or GetTime() >= doer._sing_cooldown)
        and doer.components.singinginspiration ~= nil
        and doer.components.singinginspiration.current >= TUNING.WATHGRITHR_SING_VERSE_COST then
        table.insert(actions, ACTIONS.WATHGRITHR_SING)
    end
end)
