-- 薇格弗德
print("[BetterWigfrid] Script loaded")
local song_lunarseed = GetModConfigData("song_lunarseed")

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

local FEATHER_LIGHTNING = Action({ rmb=true, distance=36, mount_valid=true, encumbered_valid=true })
FEATHER_LIGHTNING.id = "FEATHER_LIGHTNING"
FEATHER_LIGHTNING.str = "落雷"

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
            if beefalo.components.health:IsDead() and beefalo.GetBeefBellOwner ~= nil and beefalo:GetBeefBellOwner() == doer and
            doer.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_3") then
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
        if hand_item ~= nil and (hand_item.prefab == "spear_wathgrithr_lightning" or hand_item.prefab == "spear_wathgrithr_lightning_charged") then
            doer:AddTag("insulated")
            doer._feather_leap = {targetpos = pos, weapon = hand_item}
            doer:DoTaskInTime(2, function(doer) doer:RemoveTag("insulated") end)
            doer.components.talker:Say("我乘闪电而来！")
        end

        TheWorld:PushEvent("ms_sendlightningstrike", pos)
        if math.random() < 0.2 then
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
        local canblink
        if inst.checkingmapactions then
            canblink = inst:CanBlinkFromWithMap(inst.checkingmapactions_pos or inst:GetPosition())
        else
            canblink = inst:CanBlinkTo(pos)
        end
        if canblink and inst.replica.inventory:Has("goose_feather", 1) then
            return { ACTIONS.FEATHER_LIGHTNING }
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

AddComponentPostInit("beefalo", function(inst)
    if not TheWorld.ismastersim then return inst end

    local oldfn = inst.components.combat.GetAttacked
    function inst.components.combat:GetAttacked(attacker, damage, weapon, stimuli, spdamage)
        local rider = inst.rideable:GetRider()
        if rider ~= nil and rider.prefab == "wathgrithr" and rider.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_saddle") then
            rider.saved_redirectdamagefn = rider.combat.redirectdamagefn
            rider.combat.redirectdamagefn = nil
            rider.components.combat:GetAttacked(attacker, 0.5*damage, weapon, stimuli, spdamage)
            rider.combat.redirectdamagefn = rider.saved_redirectdamagefn
            rider.saved_redirectdamagefn = nil
            oldfn(self, attacker, 0.5*damage, weapon, stimuli, spdamage)
        else oldfn(self, attacker, damage, weapon, stimuli, spdamage) end
    end
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

--骑乘战斗
AddStategraphPostInit('wilson', function(self)
    local fun_swap = self.states['attack'].onenter
    self.states['attack'].onenter = function(inst)
        local equip = inst.components.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS)
        if inst.prefab == "wathgrithr" and inst.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_saddle") and
            equip and equip:HasTag("weapon") and inst.components.rider and inst.components.rider:IsRiding() and
            inst.components.rider:GetSaddle() == "saddle_wathgrithr" then
            equip:AddTag('rangedweapon')
            fun_swap(inst)
        else
            fun_swap(inst)
        end
    end
end)

local function CalcBatteryChargeMult(inst, battery)
    local per = inst.components.finiteuses:GetPercent()
	return (per >= 0.99 and 0) or (per >= 0.5 and 1) or 2
end

local function OnBatteryUsed(inst, battery, mult)
    local owner = inst.components.inventoryitem:GetGrandOwner()
	if mult <= 0 or inst.components.finiteuses:IsFull() then
        return false, "CHARGE_FULL"
    elseif not owner.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_5") then
        return false, "SKILL_NEEDED"
    end
    local per = inst.components.fueled:GetPercent()
    per = math.clamp(per + 0.5 * mult, 0, 1)
    inst.components.finiteuses:SetPercent(per)
    return true
end

local function OnLightningCharge(inst)
    inst.components.finiteuses:SetPercent(1)
end

-- 奔雷矛
AddPrefabPostInit("spear_wathgrithr_lightning", function(inst)
    inst:AddTag("lightningrod")

    if not TheWorld.ismastersim then return inst end

    inst:ListenForEvent("lightningstrike", OnLightningCharge)

    inst:AddComponent("aoeweapon_leap")
    inst.components.aoeweapon_leap:SetAOERadius(3)
    inst.components.aoeweapon_leap:SetDamage(48)

    inst:AddComponent("batteryuser")
    inst.components.batteryuser:SetChargeMultFn(CalcBatteryChargeMult)
    inst.components.batteryuser:SetOnBatteryUsedFn(OnBatteryUsed)
    inst.components.batteryuser:SetAllowPartialCharge(true)
end)

local function OnMultChanged(inst)
    if inst.electric > 0 then
        if inst.electric > 2 then inst.electric = 2 end
        inst.components.weapon:SetElectric(1, TUNING.SPEAR_WATHGRITHR_LIGHTNING_WET_DAMAGE_MULT + 0.5 * inst.electric)
    else
        inst.electric = 0
        inst.components.weapon:SetElectric(1, TUNING.SPEAR_WATHGRITHR_LIGHTNING_WET_DAMAGE_MULT)
    end
end

local function ondaycomplete(inst)
    if inst.electric > 1 then
        inst.electric = inst.electric - 1
    else
        inst.electric = 0
        inst:StopWatchingWorldState("cycles", ondaycomplete)
    end
    OnMultChanged(inst)
end

local function CalcBatteryChargeMult_Charged(inst, battery)
    local per = inst.components.finiteuses:GetPercent()
	return (per >= 0.99 and 2 - inst.electric) or (3 - inst.electric)
end

local function OnBatteryUsed_Charged(inst, battery, mult)
    local owner = inst.components.inventoryitem:GetGrandOwner()
	if mult <= 0 or inst.components.finiteuses:IsFull() then
        return false, "CHARGE_FULL"
    elseif not owner.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_5") then
        return false, "SKILL_NEEDED"
    end

    if mult >= 1 then
        inst.components.finiteuses:SetPercent(1)
        mult = mult - 1
    end
    inst.electric = inst.electric + mult
    OnMultChanged(inst)
    if inst.electric > 0 then inst:WatchWorldState("cycles", ondaycomplete) end
    return true
end

local function OnLightningCharge_Charged(inst)
    inst.components.finiteuses:SetPercent(1)
    inst.electric = 2
    OnMultChanged(inst)
end

-- 充能奔雷矛
AddPrefabPostInit("spear_wathgrithr_lightning_charged", function(inst)
    inst:AddTag("lightningrod")

    if not TheWorld.ismastersim then return inst end

    inst.electric = 0
    inst:ListenForEvent("lightningstrike", OnLightningCharge_Charged)

    inst:AddComponent("aoeweapon_leap")
    inst.components.aoeweapon_leap:SetAOERadius(4)
    inst.components.aoeweapon_leap:SetDamage(68)

    inst:AddComponent("batteryuser")
    inst.components.batteryuser:SetChargeMultFn(CalcBatteryChargeMult_Charged)
    inst.components.batteryuser:SetOnBatteryUsedFn(OnBatteryUsed_Charged)
    inst.components.batteryuser:SetAllowPartialCharge(true)
end)

local function EquipTick(inst, dt)
    local owner = inst.components.inventoryitem:GetGrandOwner()
    if owner ~= nil and owner.prefab == "wathgrithr" and owner.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_helmet_4") then
        owner.components.singinginspiration:OnRidingTick(dt)
    end
end

-- 统帅头盔
AddPrefabPostInit("wathgrithr_improvedhat", function(inst)
    if not TheWorld.ismastersim then return inst end
    inst.components.armor:InitCondition(2 * TUNING.ARMOR_WATHGRITHR_IMPROVEDHAT, TUNING.ARMOR_WATHGRITHR_IMPROVEDHAT_ABSORPTION)
    inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_MED)
    inst.components.insulator:SetInsulation(TUNING.INSULATION_MED)

    local old_oneuipfn = inst.components.equippable.onequipfn
    inst.components.equippable:SetOnEquip(function(inst, owner, from_ground)
        old_oneuipfn(inst, owner, from_ground)
        if inst.equiptask == nil then
            inst.equiptask = inst:DoPeriodicTask(6, EquipTick, 0, 6)
        end
    end)

    local old_onunequipfn = inst.components.equippable.onunequipfn
    inst.components.equippable:SetOnUnequip(function(inst, owner, from_ground)
        old_onunequipfn(inst, owner, from_ground)
        if inst.equiptask ~= nil then
            inst.equiptask:Cancel()
            inst.equiptask = nil
        end
    end)
end)

local function BattleSong_CanBeUpgraded(inst, item)
    return not inst:HasTag("lunarseed")
end

local function BattleSong_OnUpgraded(inst, upgrader, item)
    inst:AddTag("lunarseed")
end

local battlesongs = {
    "battlesong_durability",
    "battlesong_healthgain",
    "battlesong_sanitygain",
    "battlesong_sanityaura",
    "battlesong_fireresistance"
}

if song_lunarseed then
    AddPrefabPostInit("wathgrithr", function(inst)
        inst:AddTag(UPGRADETYPES.WATHGRITHR_BATTLESONG.."_upgradeuser")
    end)

    for _, song in ipairs(battlesongs) do
        AddPrefabPostInit(song, function(inst)
            inst:AddTag("spore")
            if not TheWorld.ismastersim then return inst end
            if not inst:HasTag("lunarseed") then
                inst:AddComponent("upgradeable")
                inst.components.upgradeable.upgradetype = UPGRADETYPES.WATHGRITHR_BATTLESONG
                inst.components.upgradeable:SetOnUpgradeFn(BattleSong_OnUpgraded)
                inst.components.upgradeable:SetCanUpgradeFn(BattleSong_CanBeUpgraded)
            end
        end)
    end

    AddPrefabPostInit("purebrilliance", function(inst)
        if not TheWorld.ismastersim then return inst end
        inst:AddComponent("upgrader")
        inst.components.upgrader.upgradetype = UPGRADETYPES.WATHGRITHR_IMPROVEDHAT_PRO
    end)
end

AddPrefabPostInit("battlesong_sanityaura", function(inst)
    if not TheWorld.ismastersim then return inst end

    local oldfn = inst.songdata.ONAPPLY
    inst.songdata.ONAPPLY = function(songbuff, target)
        oldfn(songbuff, target)
        if target.prefab == "wathgrithr" then
            target.components.playerspeedmult:SetSpeedMult("battlesong_sanityaura", 1 + TUNING.BATTLESONG_SANITYURA_SPEEDMULT)
        end
    end

    oldfn = inst.songdata.ONDETACH
    inst.songdata.ONDETACH = function(songbuff, target)
        oldfn(songbuff, target)
        if target.prefab == "wathgrithr" then
            target.components.playerspeedmult:RemoveSpeedMult("battlesong_sanityaura")
        end
    end
end)

local function FireTick(inst, dt)
    local owner = inst.components.inventoryitem:GetGrandOwner()
    owner.components.groundpounder:GroundPound(owner:GetPosition())
end

AddPrefabPostInit("battlesong_fireresistance", function(inst)
    if not TheWorld.ismastersim then return inst end

    local oldfn = inst.songdata.ONAPPLY
    inst.songdata.ONAPPLY = function(songbuff, target)
        oldfn(songbuff, target)
        if target.prefab == "wathgrithr" then
            target.components.groundpounder:GroundPound(inst:GetPosition())
            target.components.combat.externaldamagemultipliers:SetModifier(inst, TUNING.BATTLESONG_FIRE_VALUE, "battlesong_instant_taunt")
            target.components.combat.externaldamagetakenmultipliers:SetModifier(inst, TUNING.BATTLESONG_FIRE_VALUE, "battlesong_instant_panic")
            if target.firetask == nil then
                target.firetask = inst:DoPeriodicTask(6, FireTick, 0, 6)
            end
        end
    end

    oldfn = inst.songdata.ONDETACH
    inst.songdata.ONDETACH = function(songbuff, target)
        oldfn(songbuff, target)
        if target.prefab == "wathgrithr" then
            target.components.combat.externaldamagemultipliers:RemoveModifier(inst, "battlesong_fireresistance")
            target.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "battlesong_fireresistance")
             if inst.firetask ~= nil then
                inst.firetask:Cancel()
                inst.firetask = nil
            end
        end
    end
end)

AddPrefabPostInit("battlesong_instant_taunt", function(inst)
    if not TheWorld.ismastersim then return inst end

    local old_instant = inst.songdata.ONINSTANT
    inst.songdata.ONAPPLY = function(singer, target)
        if old_instant then old_instant(singer, target) end
        if not target:HasTag("wathgrithr_mock") then
            target:Addtag("wathgrithr_mock")
            target.components.combat.externaldamagemultipliers:SetModifier(singer, TUNING.BATTLESONG_INSTANT_VALUE, "battlesong_instant_taunt")
        end
    end
end)

AddPrefabPostInit("battlesong_instant_panic", function(inst)
    if not TheWorld.ismastersim then return inst end

    local old_panic = inst.songdata.ONPANIC
    inst.songdata.ONAPPLY = function(singer, target)
        if old_panic then old_panic(singer,target) end
        if not target:HasTag("wathgrithr_panic") then
            target:Addtag("wathgrithr_panic")
            target.panic_time = TUNING.BATTLESONG_PANIC_TIME

            target.components.combat.externaldamagetakenmultipliers:SetModifier(singer, 1 + TUNING.BATTLESONG_INSTANT_VALUE, "battlesong_instant_panic")

            target.panicfn = target:DoPeriodicTask(1, function(target)
                target.panic_time = target.panic_time - 1
                if target.panic_time < 1 then
                    target.components.combat.externaldamagetakenmultipliers:RemoveModifier(singer, "battlesong_instant_panic")
                    target:RemoveTag("wathgrithr_taunt")
                    target.panicfn:Cancel()
                    target.panicfn = nil
                end
            end)
        end
    end
end)



