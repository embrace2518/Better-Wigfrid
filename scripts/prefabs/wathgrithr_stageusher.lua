local assets =
{
    Asset("ANIM", "anim/stagehand.zip"),
    Asset("ANIM", "anim/stagehand_sts.zip"),
}

local prefabs =
{
    "stageusher_attackarm",
    "stageusher_attackhand",
}

local brain = require("brains/wathgrithr_stageusherbrain")

--------------------------------------------------------------------------------
-- Owner helpers
--------------------------------------------------------------------------------

local function GetOwner(inst)
    return inst.components.follower ~= nil and inst.components.follower:GetLeader() or nil
end

-- Owner exists and is NOT performing; enables combat
local function IsOwnerNotPerforming(inst)
    local owner = GetOwner(inst)
    return owner ~= nil and not owner:HasTag("wathgrithr_show")
end

local function OnLeaderChanged(inst, data)
    if data.old ~= nil and data.old:IsValid() and inst._on_leader_attacked ~= nil then
        inst:RemoveEventCallback("attacked", inst._on_leader_attacked, data.old)
    end

    if data.new ~= nil then
        inst._on_leader_attacked = function(leader, attacked_data)
            if attacked_data ~= nil and attacked_data.attacker ~= nil
                and IsOwnerNotPerforming(inst)
                and inst.components.combat:CanTarget(attacked_data.attacker) then
                inst.components.combat:SuggestTarget(attacked_data.attacker)
            end
        end
        inst:ListenForEvent("attacked", inst._on_leader_attacked, data.new)
        inst:PushEvent("standup")
    end
end

--------------------------------------------------------------------------------
-- Stageusher helpers (from original stageusher.lua)
--------------------------------------------------------------------------------

local function SetPhysicsState(inst, set_to_standing)
    local is_blocker = inst:HasTag("blocker")
    if set_to_standing then
        if is_blocker then
            inst:RemoveTag("blocker")
            inst:RemoveTag("notarget")
            inst.Physics:SetMass(100)
            inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
            inst.Physics:CollidesWith(COLLISION.WORLD)
        end
    else
        if not is_blocker then
            inst:AddTag("blocker")
            inst:AddTag("notarget")
            inst.Physics:SetMass(0)
            inst.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
            inst.Physics:SetCollisionMask(
                COLLISION.ITEMS,
                COLLISION.CHARACTERS,
                COLLISION.GIANTS
            )
        end
    end
end

local function StartAttackingTarget(inst, target)
    if target == nil or not target:IsValid() then
        return false
    end

    local ipos = inst:GetPosition()
    local tpos = target:GetPosition()
    local unit_target_vec = (tpos - ipos):GetNormalized()

    local attack_hand = SpawnPrefab("stageusher_attackhand")
    attack_hand.Transform:SetPosition((ipos + unit_target_vec * 0.5):Get())
    attack_hand:SetOwner(inst)
    attack_hand:SetCreepTarget(target)

    if inst._on_hand_removed == nil then
        inst._on_hand_removed = function(hand) inst:PushEvent("handfinished") end
    end
    inst:ListenForEvent("onremove", inst._on_hand_removed, attack_hand)

    return true
end

local function IsStanding(inst)
    return inst._is_standing
end

local function ChangeStanding(inst, new_standing)
    new_standing = new_standing or not inst._is_standing
    if new_standing and not inst._is_standing then
        inst._is_standing = true
        inst.components.combat.canattack = true
        SetPhysicsState(inst, inst._is_standing)
    elseif not new_standing and inst._is_standing then
        inst._is_standing = false
        inst.components.combat.canattack = false
        SetPhysicsState(inst, inst._is_standing)
        inst.components.health:SetPercent(1)
    end
end

local function GetStatus(inst)
    return (IsStanding(inst) and "STANDING") or "SITTING"
end

--------------------------------------------------------------------------------
-- Combat helpers
--------------------------------------------------------------------------------

local function usher_keep_target(inst, target)
    return inst.components.combat:CanTarget(target)
        and inst:IsNear(target, 2 * TUNING.STAGEUSHER_ATTACK_RANGE)
        and IsOwnerNotPerforming(inst)
end

local function usher_should_aggro(inst, target)
    return target ~= GetOwner(inst)
        and IsOwnerNotPerforming(inst)
        and (inst.components.burnable == nil or not inst.components.burnable:IsBurning())
end

local function on_giveup_timer_done(inst)
    inst._giveup_timer = nil
    if inst.components.combat:HasTarget() then
        inst.components.combat:GiveUp()
    end
end

local function restart_giveup_timer(inst)
    if inst._giveup_timer ~= nil then
        inst._giveup_timer:Cancel()
    end
    inst._giveup_timer = inst:DoTaskInTime(TUNING.STAGEUSHER_GIVEUP_TIME, on_giveup_timer_done)
end

local function on_new_combat_target(inst)
    inst:PushEvent("standup")
    restart_giveup_timer(inst)
end

local function on_dropped_target(inst)
    if inst._giveup_timer ~= nil then
        inst._giveup_timer:Cancel()
        inst._giveup_timer = nil
    end
end

--------------------------------------------------------------------------------
-- Save/Load
--------------------------------------------------------------------------------

local function OnSave(inst, data)
    data.is_standing = inst:IsStanding()
end

local function OnLoad(inst, data)
    if data ~= nil and data.is_standing then
        ChangeStanding(inst, true)
    end
end

--------------------------------------------------------------------------------
-- Main prefab function
--------------------------------------------------------------------------------

local USHER_PATHCAPS = { ignorecreep = true }
local FIRE_OFFSET = Vector3(0, 0, 0)

local function stageusher_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddPhysics()
    inst.entity:AddNetwork()
    inst.entity:AddLight()

    inst.DynamicShadow:SetSize(2.5, 1.5)

    inst.Transform:SetFourFaced()

    inst.Physics:SetFriction(0)
    inst.Physics:SetDamping(5)
    SetPhysicsState(inst, false)
    inst.Physics:SetCapsule(0.5, 1.0)

    inst.AnimState:SetBank("stagehand")
    inst.AnimState:SetBuild(IsSpecialEventActive(SPECIAL_EVENTS.YOTH) and "stagehand_yoth_princess" or "stagehand_sts")
    inst.AnimState:PlayAnimation("idle")

    inst.AnimState:OverrideSymbol("dark_spew", "stagehand", "dark_spew")
    inst.AnimState:OverrideSymbol("fx", "stagehand", "fx")
    inst.AnimState:OverrideSymbol("stagehand_fingers", "stagehand", "stagehand_fingers")

    inst.persists = false

    inst:AddTag("antlion_sinkhole_blocker")
    inst:AddTag("electricdamageimmune")
    inst:AddTag("notarget")
    inst:AddTag("notraptrigger")
    inst:AddTag("stageusher")
    inst:AddTag("shadow_aligned")

    inst.Light:Enable(false)

    inst._is_standing = false

    inst.IsStanding = IsStanding
    inst.ChangeStanding = ChangeStanding
    inst.StartAttackingTarget = StartAttackingTarget

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        print("[BetterWigfrid] stageusher client spawn, GUID:", inst.GUID)
        return inst
    end
    print("[BetterWigfrid] stageusher server spawn begin, GUID:", inst.GUID)

    inst.scrapbook_hidehealth = true
    inst.scrapbook_speechstatus = "SITTING"

    MakeSnowCovered(inst)
    SetLunarHailBuildupAmountSmall(inst)

    ----------------------------------------------------------------------------
    inst:AddComponent("burnable")
    inst.components.burnable:SetFXLevel(2)
    inst.components.burnable:SetBurnTime(10)
    inst.components.burnable:AddBurnFX("campfirefire", FIRE_OFFSET, "swap_fire")

    ----------------------------------------------------------------------------
    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = 6
    inst.components.locomotor.runspeed = 10
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.pathcaps = USHER_PATHCAPS

    ----------------------------------------------------------------------------
    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    ----------------------------------------------------------------------------
    inst:AddComponent("knownlocations")

    ----------------------------------------------------------------------------
    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.STAGEUSHER_GIVEUP_HEALTH)
    inst.components.health:SetMinHealth(1)

    ----------------------------------------------------------------------------
    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.STAGEUSHER_ATTACK_DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.STAGEUSHER_ATTACK_PERIOD)
    inst.components.combat:SetRange(TUNING.STAGEUSHER_ATTACK_RANGE)
    inst.components.combat:SetKeepTargetFunction(usher_keep_target)
    inst.components.combat:SetShouldAggroFn(usher_should_aggro)
    inst.components.combat.ignorehitrange = true
    inst.components.combat.canattack = false

    ----------------------------------------------------------------------------
    -- Follower component: handles following, wormhole/cave teleport, death/revival
    inst:AddComponent("follower")
    inst.components.follower:KeepLeaderOnAttacked()
    inst.components.follower.canaccepttarget = false

    ----------------------------------------------------------------------------
    inst:ListenForEvent("newcombattarget", on_new_combat_target)
    inst:ListenForEvent("droppedtarget", on_dropped_target)

    inst:ListenForEvent("leaderchanged", OnLeaderChanged)

    ----------------------------------------------------------------------------
    inst:SetStateGraph("SGstageusher")
    inst:SetBrain(brain)

    ----------------------------------------------------------------------------
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    print("[BetterWigfrid] stageusher server spawn done, GUID:", inst.GUID)
    return inst
end

return Prefab("wathgrithr_stageusher", stageusher_fn, assets, prefabs)
