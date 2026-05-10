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

local function SpearWathgrithrLightning_Common(inst)
    inst:AddTag("lightningrod")

    if not TheWorld.ismastersim then return inst end

    inst:ListenForEvent("lightningstrike", OnLightningCharge)
    inst:AddComponent("batteryuser")
    inst.components.batteryuser:SetChargeMultFn(CalcBatteryChargeMult)
    inst.components.batteryuser:SetOnBatteryUsedFn(OnBatteryUsed)
    inst.components.batteryuser:SetAllowPartialCharge(true)

    inst:AddComponent("multithruster")
end

local function SpearWathgrithrLightning_Base(inst)
    SpearWathgrithrLightning_Common(inst)
    inst:AddComponent("aoeweapon_leap")
    inst.components.aoeweapon_leap:SetAOERadius(3)
    inst.components.aoeweapon_leap:SetDamage(48)
end

local function SpearWathgrithrLightning_Charged(inst)
    SpearWathgrithrLightning_Common(inst)
    inst:AddComponent("aoeweapon_leap")
    inst.components.aoeweapon_leap:SetAOERadius(3)
    inst.components.aoeweapon_leap:SetDamage(68)
end
-- 奔雷矛
AddPrefabPostInit("spear_wathgrithr_lightning", SpearWathgrithrLightning_Base)

AddPrefabPostInit("spear_wathgrithr_lightning_charged", SpearWathgrithrLightning_Charged)


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
