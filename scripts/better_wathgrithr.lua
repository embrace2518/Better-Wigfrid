-- 薇格弗德

-- 动作：落雷
local FEATHER_LIGHTNING = Action({ rmb=true, distance=36, mount_valid=true, encumbered_valid=true })
FEATHER_LIGHTNING.id = "FEATHER_LIGHTNING"
FEATHER_LIGHTNING.str = "落雷"

function PickSome(num, choices)
	local l_choices = choices
	local ret = {}
	for i=1,num do
		local choice = math.random(#l_choices)
		table.insert(ret, l_choices[choice])
		table.remove(l_choices, choice)
	end
	return ret
end

local function DoRevive(target, singer)
    target:PushEvent("respawnfromghost", { user = singer })
end

FEATHER_LIGHTNING.fn = function(act)
    local doer = act.doer
    local pos = act:GetActionPoint()
    if pos == nil then
        return false
    end
    if pos.y == nil then
        pos = Vector3(pos.x, 0, pos.z)
    end
    if doer.prefab == "wathgrithr" and doer.components.inventory:Has("goose_feather", 1) then
        doer.components.inventory:ConsumeByName("goose_feather", 1)

        local x, y, z = pos.x, pos.y, pos.z
        local beefalos = TheSim:FindEntities(x, y, z, 3, {"beefalo"}, {"INLIMBO", "NOCLICK"})
        for _, beefalo in ipairs(beefalos) do
            if beefalo.components.health:IsDead() and doer.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_2") then
                beefalo:OnRevived(doer)
                doer:AddDebuff("shadow_beef_bell_curse", "shadow_beef_bell_curse")
            end
        end

        local players = FindPlayersInRange(x, y, z, 3, false)
        local num = players ~= nil and math.min(#players, 1) or nil
        local picked = num ~= nil and PickSome(num, players) or nil
        local player = picked ~= nil and picked[1] or nil
        if player ~= nil and player:HasTag("playerghost") then
            player:DoTaskInTime(0.5 + (math.random() * 2.5), DoRevive, doer)
        end

        local hand_item = doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if hand_item ~= nil and hand_item:HasTag("aoeweapon_lunge") then
            if (hand_item.components.rechargeable and not hand_item.components.rechargeable:IsCharged()) or
            not doer.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_5") then
            else
                doer:AddTag("insulated")
                doer._feather_leap = {targetpos = pos, weapon = hand_item}
                doer:DoTaskInTime(2, function(doer) doer:RemoveTag("insulated") end)
                doer.components.talker:Say("我乘闪电而来！")
                if hand_item.components.rechargeable then
                    hand_item.components.rechargeable:Discharge(hand_item._cooldown or TUNING.SPEAR_WATHGRITHR_LIGHTNING_LUNGE_COOLDOWN)
                end
            end
        end

        TheWorld:PushEvent("ms_sendlightningstrike", pos)
        if math.random() < 0.3 then
            TheWorld:PushEvent("ms_forceprecipitation", true)
        end
        return true
    end
    return false
end

AddAction(FEATHER_LIGHTNING)

local function AddFeatherLightningState(stategraph)
    stategraph.states["feather_lightning"] = GLOBAL.State{
        name = "feather_lightning",
        tags = {"doing", "busy"},
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("staff")
            inst.AnimState:PushAnimation("idle", false)
            inst.sg:SetTimeout(4 * GLOBAL.FRAMES)
        end,
        ontimeout = function(inst)
            inst:PerformBufferedAction()
            if inst._feather_leap then
                local data = inst._feather_leap
                inst._feather_leap = nil
                inst.AnimState:PlayAnimation("superjump_lag")
                inst.sg:GoToState("combat_superjump", { data = data })
            elseif inst.sg:HasStateTag("busy") then
                inst.sg:GoToState("idle")
            end
        end,
        events = {
            GLOBAL.EventHandler("animqueueover", function(inst)
                if inst.sg:HasStateTag("busy") then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    }
end

AddStategraphPostInit("wilson", AddFeatherLightningState)
AddStategraphPostInit("wilson_client", AddFeatherLightningState)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(FEATHER_LIGHTNING, "feather_lightning"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(FEATHER_LIGHTNING, "feather_lightning"))

local function IsNotBlocked(pt)
    return TheWorld.Map:IsPassableAtPoint(pt:Get()) and not TheWorld.Map:IsGroundTargetBlocked(pt)
end
local function CanBlinkTo(inst, pt)
    local x, y, z = inst.Transform:GetWorldPosition()
    return IsNotBlocked(pt) and IsTeleportingPermittedFromPointToPoint(x, y, z, pt.x, pt.y, pt.z) -- NOTES(JBK): Keep in sync with blinkstaff. [BATELE]
end

local function CanBlinkFromWithMap(inst, pt)
    local x, y, z = inst.Transform:GetWorldPosition()
    return IsTeleportingPermittedFromPointToPoint(x, y, z, pt.x, pt.y, pt.z)
end

local function ReticuleTargetFn(inst)
    return ControllerReticle_Blink_GetPosition(inst, IsNotBlocked)
end

local function GetPointSpecialActions(inst, pos, useitem, right)
    if right and useitem == nil then
        -- 落雷（优先）
        local canblink
        if inst.checkingmapactions then
            canblink = inst:CanBlinkFromWithMap(inst.checkingmapactions_pos or inst:GetPosition())
        else
            canblink = inst:CanBlinkTo(pos)
        end
        if canblink and inst.replica.inventory:Has("goose_feather", 1) then
            if not (inst.components.rider and inst.components.rider:IsRiding()) or
                inst.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_4") then
                return { ACTIONS.FEATHER_LIGHTNING }
            end
        end
    end
    return {}
end

local function OnSetOwner(inst)
    if inst.components.playeractionpicker ~= nil then
        inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions
    end
end

AddPrefabPostInit("wathgrithr", function(inst)
    inst.CanBlinkTo = CanBlinkTo
    inst.CanBlinkFromWithMap = CanBlinkFromWithMap
    inst:ListenForEvent("setowner", OnSetOwner)

    inst:AddComponent("reticule")
    inst.components.reticule.targetfn = ReticuleTargetFn
    inst.components.reticule.ease = true
	inst.components.reticule.twinstickcheckscheme = true
	inst.components.reticule.twinstickmode = 1
	inst.components.reticule.twinstickrange = 15

    if not TheWorld.ismastersim then return inst end

    local old_oneatfn = inst.components.eater.oneatfn
    inst.components.eater:SetOnEatFn(
        function(inst, food, feeder)
            if old_oneatfn then old_oneatfn(inst, food, feeder) end
            if food ~= nil and food.components.edible ~= nil and
            inst.components.singinginspiration:IsSongActive({NAME = "battlesong_healthgain_buff"}) then
                local delta = food.components.edible.hungervalue + inst.components.hunger.lasthunger- inst.components.hunger.max
                if delta > 0 then
                    inst.components.health:DoDelta(delta * 0.3, true)
                end
            end
        end)

    inst:AddComponent("groundpounder")
    inst.components.groundpounder:UseRingMode()
    inst.components.groundpounder.numRings = 3
    inst.components.groundpounder.initialRadius = 1.5
    inst.components.groundpounder.radiusStepDistance = 2
    inst.components.groundpounder.ringWidth = 2
    inst.components.groundpounder.damageRings = 2
    inst.components.groundpounder.destructionRings = 3
    inst.components.groundpounder.fxRings = 2
    inst.components.groundpounder.fxRadiusOffset = 1.5
    inst.components.groundpounder.burner = true
    inst.components.groundpounder.groundpoundfx = "firesplash_fx"
    inst.components.groundpounder.groundpounddamagemult = 0.5
    inst.components.groundpounder.groundpoundringfx = "firering_fx"

    local old_onignite = inst.components.burnable.onignite
    inst.components.burnable:SetOnIgniteFn(function(inst, source, doer)
        if old_onignite then old_onignite(inst, source, doer) end
        inst.components.groundpounder:GroundPound(inst:GetPosition())
        inst.components.burnable:SetBurnTime(0.5)
    end)
end)

--为战斗而生调整
AddComponentPostInit("battleborn", function(self)

    function self:OnAttack(data)
        local victim = data.target
        local delta = 0

        if not self.inst.components.health:IsDead() and (self.validvictimfn == nil or self.validvictimfn(victim)) then
            local total_health = victim.components.health:GetMaxWithPenalty()
            local damage = (data.weapon ~= nil and data.weapon.components.weapon:GetDamage(self.inst, victim)) or self.inst.components.combat.defaultdamage

            if damage > 0 or self.allow_zero then
                local percent = (damage <= 0 and 0) or (total_health <= 0 and math.huge) or damage / total_health

                -- math and clamp does account for 0 and infinite cases
                delta = math.clamp(victim.components.combat.defaultdamage * self.battleborn_bonus * percent, self.clamp_min, self.clamp_max)
                if victim:HasTag("epic") then
                    delta = delta * 1.5
                end
                -- decay stored battleborn
                if self.battleborn > 0 then
                    local dt = GetTime() - self.battleborn_time - self.battleborn_store_time

                    if dt >= self.battleborn_decay_time then
                        self.battleborn = 0
                    elseif dt > 0 then
                        local k = dt / self.battleborn_decay_time
                        self.battleborn = Lerp(self.battleborn, 0, k * k)
                    end
                end

                -- store new battleborn
                self.battleborn = self.battleborn + delta
                self.battleborn_time = GetTime()

                --consume battleborn if enough has been stored
                if self.battleborn > self.battleborn_trigger_threshold then
                    if self.health_enabled and self.inst.components.health:IsHurt() then self.inst.components.health:DoDelta(self.battleborn, false, "battleborn") end

                    if self.inst.components.inventory ~= nil and self.inst.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_helmet_5") then
                        self.inst.components.inventory:ForEachEquipment(self.RepairEquipment, self.battleborn) end

                    if self.sanity_enabled then self.inst.components.sanity:DoDelta(self.battleborn) end

                    if self.ontriggerfn ~= nil then self.ontriggerfn(self.inst, self.battleborn) end

                    self.battleborn = 0
                end
            end
        end
    end
end)

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

--骑乘战斗
AddStategraphPostInit('wilson', function(self)
    local fun_swap = self.states['attack'].onenter
    self.states['attack'].onenter = function(inst)
        local equip = inst.components.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS)
        if inst.components.rider and inst.components.rider:IsRiding() and inst.prefab == "wathgrithr" and
            inst.components.rider:GetSaddle().prefab == "saddle_wathgrithr" and
            inst.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_3") and
            equip and equip:HasTag("weapon") then
            equip:AddTag('rangedweapon')
            fun_swap(inst)
            if equip.components.multithruster then
                equip.components.multithruster:OnAttack()
            end
        else
            fun_swap(inst)
        end
    end

    self.states['multithrust_pre'].onenter = function(inst)
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

    self.states['multithrust'].onenter = function(inst, target)
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

        --[[if inst.components.playercontroller ~= nil then
            inst.components.playercontroller:RemotePausePrediction()
        end]]
    end

    self.states['multithrust'].onexit = function(inst)
        inst.components.combat:SetTarget(nil)
        if not (inst.components.rider and inst.components.rider:IsRiding()) then
            inst.Transform:SetFourFaced()
        end
        if ValidateMultiThruster(inst) then
            inst.sg.statemem.weapon.components.multithruster:StopThrusting(inst)
        end
    end
end)

AddPrefabPostInit("beefalo", function(inst)
    if not TheWorld.ismastersim then return inst end

    local oldfn = inst.components.combat.GetAttacked
    function inst.components.combat:GetAttacked(attacker, damage, weapon, stimuli, spdamage)
        local rider = inst.components.rideable:GetRider()
        if rider ~= nil and rider.prefab == "wathgrithr" and
        rider.components.rider:GetSaddle().prefab == "saddle_wathgrithr" and
        rider.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_3") then
            local combat = rider.components.combat
            combat.redirectdamagefn, rider._saved_redirect = nil, combat.redirectdamagefn
            combat:GetAttacked(attacker, 0.75 * damage, weapon, stimuli, spdamage)
            combat.redirectdamagefn, rider._saved_redirect = rider._saved_redirect, nil
            oldfn(self, attacker, 0.75 * damage, weapon, stimuli, spdamage)
        else oldfn(self, attacker, damage, weapon, stimuli, spdamage) end
    end

    -- 当女武神用牛铃绑定时，追加暗影牛铃同款绑定逻辑
    local _SetBeefBellOwner = inst.SetBeefBellOwner
    function inst:SetBeefBellOwner(bell, bell_user, ...)
        _SetBeefBellOwner(self, bell, bell_user, ...)
        if bell_user ~= nil and bell_user.prefab == "wathgrithr" and
        bell_user.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_2") and
        bell ~= nil and not bell:HasTag("shadowbell") then
            -- 移除_onfollowerdied回调 → 牛死后不断开跟随
            local leader = inst.components.follower ~= nil and inst.components.follower.leader or nil
            if leader ~= nil and leader.components.leader ~= nil then
                leader:RemoveEventCallback("death", leader.components.leader._onfollowerdied, inst)
            end
            -- 尸体不烧焦
            if inst.components.burnable ~= nil then
                inst.components.burnable.nocharring = true
            end
        end
    end

    local _ShouldKeepCorpse = inst.ShouldKeepCorpse
    function inst:ShouldKeepCorpse()
        if inst.GetBeefBellOwner ~= nil then
            local owner = inst:GetBeefBellOwner()
            if owner ~= nil and owner:IsValid() and owner.prefab == "wathgrithr" then
                return true
            end
        end
        return _ShouldKeepCorpse(self)
    end

    -- 尸体侵蚀动画（与暗影牛铃完全一致）
    local ERodeBeefalo = function(beef)
        if beef:HasTag("NOCLICK") then return end
        beef.persists = false
        beef:AddTag("NOCLICK")
        RemovePhysicsColliders(beef)
        if beef.DynamicShadow ~= nil then
            beef.DynamicShadow:Enable(false)
        end
        local easing = require("easing")
        local multcolor = beef.AnimState:GetMultColour()
        local ticktime = TheSim:GetTickTime()
        local erodetime = 5
        beef:StartThread(function()
            local ticks = 0
            while beef:IsValid() and (ticks * ticktime < erodetime) do
                local n = ticks * ticktime / erodetime
                local alpha = easing.inQuad(1 - n, 0, 1, 1)
                local color = 1 - (n * 5)
                color = math.min(multcolor, color)
                beef.AnimState:SetErosionParams(n, .05, 1.0)
                beef.AnimState:SetMultColour(color, color, color, math.max(.3, alpha))
                ticks = ticks + 1
                Yield()
            end
            beef:Remove()
        end)
    end

    -- 解除牛铃时触发侵蚀
    local _ClearBeefBellOwner = inst.ClearBeefBellOwner
    function inst:ClearBeefBellOwner(...)
        local owner = inst.GetBeefBellOwner ~= nil and inst:GetBeefBellOwner() or nil
        local is_wathgrithr = owner ~= nil and owner:IsValid() and owner.prefab == "wathgrithr" and
            owner.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_2")
        local is_dead = inst.components.health ~= nil and inst.components.health:IsDead()
        _ClearBeefBellOwner(self, ...)
        if is_wathgrithr and is_dead then
            ERodeBeefalo(inst)
        end
    end
end)
