
AddPrefabPostInit("beefalo", function(inst)
    if not TheWorld.ismastersim then return inst end

    -- 独唱安抚：被歌声安抚时不主动攻击
    local old_shouldaggro = inst.components.combat.shouldaggrofn
    inst.components.combat:SetShouldAggroFn(function(inst, target)
        if inst:HasTag("wathgrithr_pacified") then
            return false
        end
        return old_shouldaggro ~= nil and old_shouldaggro(inst, target) or nil
    end)

    local oldfn = inst.components.combat.GetAttacked
    function inst.components.combat:GetAttacked(attacker, damage, weapon, stimuli, spdamage)
        local rider = inst.components.rideable:GetRider()
        local saddle = rider ~= nil and rider.components.rider:GetSaddle() or nil
        if rider ~= nil and rider.prefab == "wathgrithr" and
        saddle ~= nil and saddle.prefab == "saddle_wathgrithr" and
        rider.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_saddle") then
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
