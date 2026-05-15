-- 舞台之手 stategraph 修正
AddStategraphPostInit("stageusher", function(sg)
    local walk_start = sg.states["walk_start"]
    if walk_start then
        local old_onenter = walk_start.onenter
        walk_start.onenter = function(inst, ...)
            if inst.IsStanding and not inst:IsStanding() then
                inst.sg:GoToState("standup")
                return
            end
            old_onenter(inst, ...)
        end
    end

    local idle = sg.states["idle"]
    if idle then
        local old_onenter = idle.onenter
        idle.onenter = function(inst, ...)
            if inst.IsStanding and inst:IsStanding()
                and not inst.components.locomotor:WantsToMoveForward()
                and not (inst.components.combat and inst.components.combat:HasTarget()) then
                inst.sg.mem.wants_to_sit = true
            end
            old_onenter(inst, ...)
        end
    end
end)

-- 连击/骑乘攻击 stategraph
local function IsWeaponEquipped(inst, weapon)
    return weapon ~= nil
        and weapon.components.equippable ~= nil
        and weapon.components.equippable:IsEquipped()
        and weapon.components.inventoryitem ~= nil
        and weapon.components.inventoryitem:IsHeldBy(inst)
end

local function ValidateMultiThruster(inst)
    return IsWeaponEquipped(inst, inst.sg.statemem.weapon) and inst.sg.statemem.weapon.components.multithruster ~= nil
end

AddStategraphPostInit('wilson', function(sg)
    local _old_attack_onenter = sg.states['attack'].onenter
    sg.states['attack'].onenter = function(inst)
        if inst:HasTag("wathgrithr_show") then
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if inst.components.rider and inst.components.rider:IsRiding() and
                inst.components.rider:GetSaddle().prefab == "saddle_wathgrithr" and
                inst.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_saddle") and
                equip and equip:HasTag("weapon") then
                equip:AddTag('rangedweapon')
                _old_attack_onenter(inst)
            else
                _old_attack_onenter(inst)
            end
        else
            _old_attack_onenter(inst)
        end
    end

    sg.states['multithrust_pre'].onenter = function(inst)
        inst.components.locomotor:Stop()
        if inst.components.rider and inst.components.rider:IsRiding() then
            inst.AnimState:PlayAnimation("player_atk_pre")
        else
            inst.AnimState:PlayAnimation("multithrust_yell")
        end
        if inst.bufferedaction ~= nil and inst.bufferedaction.target ~= nil and inst.bufferedaction.target:IsValid() then
            inst.sg.statemem.target = inst.bufferedaction.target
            inst.components.combat:SetTarget(inst.sg.statemem.target)
            inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
        end

        if inst.components.playercontroller ~= nil then
            inst.components.playercontroller:RemotePausePrediction()
        end
    end

    sg.states['multithrust'].onenter = function(inst, target)
        inst.components.locomotor:Stop()
        inst.AnimState:PlayAnimation("multithrust")
        if not (inst.components.rider and inst.components.rider:IsRiding()) then
            inst.Transform:SetEightFaced()
        end

        if target ~= nil and target:IsValid() then
            inst.sg.statemem.target = target
            inst:ForceFacePoint(target.Transform:GetWorldPosition())
        end

        inst.sg:SetTimeout(30 * FRAMES)
    end

    sg.states['multithrust'].onexit = function(inst)
        inst.components.combat:SetTarget(nil)
        if not (inst.components.rider and inst.components.rider:IsRiding()) then
            inst.Transform:SetFourFaced()
        end
        if ValidateMultiThruster(inst) then
            inst.sg.statemem.weapon.components.multithruster:StopThrusting(inst)
        end
    end
end)

-- 第二幕：手持剧本右键敌人指令舞台之手攻击
local COMMAND_STAGEUSher = Action({ priority = 2 })
COMMAND_STAGEUSher.id = "WATHGRITHR_COMMAND_STAGEUSER"
COMMAND_STAGEUSher.str = "舞台之手攻击"
COMMAND_STAGEUSher.fn = function(act)
    local doer = act.doer
    local target = act.target
    if doer._stageusher ~= nil and doer._stageusher:IsValid()
        and target ~= nil and target:IsValid()
        and doer._stageusher.components.combat ~= nil then
        doer._stageusher.components.combat:SetTarget(target)
        return true
    end
    return false
end
AddAction(COMMAND_STAGEUSher)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(COMMAND_STAGEUSher, "doshortaction"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(COMMAND_STAGEUSher, "doshortaction"))

AddComponentAction("SCENE", "combat", function(inst, doer, actions)
    if doer.prefab == "wathgrithr"
        and doer:GetActDone("act2")
        and doer:HasPlaybill()
        and doer._stageusher ~= nil
        and doer._stageusher:IsValid() then
        table.insert(actions, ACTIONS.WATHGRITHR_COMMAND_STAGEUSER)
    end
end)
