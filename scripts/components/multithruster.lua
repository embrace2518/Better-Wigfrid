local function HasSpearSkill(owner, skill)
    return owner and owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated(skill)
end

local function ShouldAddMultithrusterTag(owner)
    -- Need spear_1 to use multithrust at all
    if not HasSpearSkill(owner, "wathgrithr_arsenal_spear_1") then
        return false
    end
    -- Riding needs additional beefalo_4
    if owner.components.rider and owner.components.rider:IsRiding() then
        return HasSpearSkill(owner, "wathgrithr_beefalo_4")
    end
    return true
end

local Multithruster = Class(function(self, inst)
    self.inst = inst

    if inst.components.rechargeable then
        local old_oncharged = inst.components.rechargeable.onchargedfn
        inst.components.rechargeable:SetOnChargedFn(function(inst)
            if old_oncharged then old_oncharged(inst) end
            local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem:GetGrandOwner()
            if ShouldAddMultithrusterTag(owner) then
                self.inst:AddTag("multithruster")
            end
        end)

        local old_ondischarged = inst.components.rechargeable.ondischargedfn
        inst.components.rechargeable:SetOnDischargedFn(function(inst)
            if old_ondischarged then old_ondischarged(inst) end
            self.inst:RemoveTag("multithruster")
            local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem:GetGrandOwner()
            if owner and owner.components.rider and owner.components.rider:IsRiding() then
                owner.AnimState:SetBank("wilsonbeefalo")
            end
        end)

        if inst.components.rechargeable:IsCharged() then
            local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem:GetGrandOwner()
            if ShouldAddMultithrusterTag(owner) then
                self.inst:AddTag("multithruster")
            end
        end
    else
        self.inst:AddTag("multithruster")
    end
end)

function Multithruster:OnAttack()
    if self.inst.components.rechargeable and not self.inst.components.rechargeable:IsCharged() then
        local remaining = self.inst.components.rechargeable:GetTimeToCharge()
        if remaining > 1 then
            self.inst.components.rechargeable:Discharge(remaining - 1)
        else
            self.inst.components.rechargeable:SetPercent(1)
        end
    end
end

function Multithruster:StartThrusting(player)
    if not HasSpearSkill(player, "wathgrithr_arsenal_spear_1") then
        return false
    end
    self._thrust_repair_count = 0
    if player.sg then
        player.sg:PushEvent("start_multithrust")
        return true
    end
    return false
end

function Multithruster:DoThrust(player, target)
    if player.sg then
        player.sg:PushEvent("do_multithrust")
    end
    player.components.combat:DoAttack(target)
    target = target or (player.components.combat and player.components.combat.target)
    if target and self.inst.components.finiteuses and self.inst.components.upgradeable == nil then
        if player.IsValidVictim and player:IsValidVictim(target) then
            self._thrust_repair_count = (self._thrust_repair_count or 0) + 1
            local max_repairs = TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_MAX_REPAIRS_PER_LUNGE
            local repair_amt = TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_LUNGE_REPAIR_AMOUNT
            if self._thrust_repair_count <= max_repairs then
                self.inst.components.finiteuses:Repair(repair_amt)
            end
        end
    end
end

function Multithruster:StopThrusting(player)
    if player.sg then
        player.sg:PushEvent("stop_multithrust")
    end
    if self.inst.components.rechargeable then
        local mult = HasSpearSkill(player, "wathgrithr_arsenal_spear_2") and 2 or 4
        self.inst.components.rechargeable:Discharge(mult * (self.inst._cooldown or TUNING.SPEAR_WATHGRITHR_LIGHTNING_LUNGE_COOLDOWN))
    end
end

return Multithruster
