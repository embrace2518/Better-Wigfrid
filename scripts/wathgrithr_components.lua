-- 战歌系统重写
AddComponentPostInit("singinginspiration", function(self)
    self.OnHitOther = function() end
    self.OnAttacked = function() end

    function self:CanAddSong(songdata, inst)

        if songdata.REQUIRE_SKILL ~= nil and not self.inst.components.skilltreeupdater:IsActivated(songdata.REQUIRE_SKILL) then
            return false
        end

        if songdata.INSTANT and self.inst.components.showmode:IsActive() then
            return self.current >= songdata.DELTA and (
                inst == nil or inst.components.rechargeable == nil or inst.components.rechargeable:IsCharged()
            )
        end

        return #self.active_songs < self.available_slots and not self.inst.components.showmode:IsActive()
    end

    function self:OnAddInstantSong(songdata, inst)
    if inst ~= nil and inst.components.rechargeable ~= nil then
        inst.components.rechargeable:Discharge(songdata.COOLDOWN or TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN)
    end

    self:InstantInspire(songdata)
end

    function self:DoDelta(delta, forceupdate)
        self.current = math.min(math.max(self.current + delta, 0), self.max)

        local newpercent = self:GetPercent()
        local old_slots_available = self.available_slots
        self.available_slots = self.CalcAvailableSlotsForInspirationFn(self.inst, newpercent)

        self.inst:PushEvent("inspirationdelta", { newpercent = newpercent, slots_available = self.available_slots })

        if self.available_slots ~= old_slots_available then
            for i = #self.active_songs, self.available_slots + 1, -1 do
                self:PopSong()
            end
        end
    end

    function self:OnUpdate(dt)
        if self.inst.components.showmode:IsActive() then
            self.is_draining = true
            local head_item = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEADS)
            if head_item ~= nil and head_item.prefab == "wathgrithr_improvedhat" and
            self.inst.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_helmet_4") then
                self:DoDelta(-(50 / TUNING.TOTAL_DAY_TIME) * dt) -- 50 per 8 minutes
            else
                self:DoDelta(-(100 / TUNING.TOTAL_DAY_TIME) * dt)
            end
        elseif self.inst:HasTag("wathgrithr_singing") then
            self.is_draining = true
        else
            self.is_draining = false
            self:DoDelta((20 / TUNING.TOTAL_DAY_TIME) * dt)
        end

        if self.current == self.max and not self.inst.components.showmode:IsActive()
            and not self.inst:HasTag("wathgrithr_singing") then
            self.inst:PushBufferedAction(BufferedAction(self.inst, nil, ACTIONS.OPENSHOW))
        elseif self.current == 0 and self.inst.components.showmode:IsActive() then
            self.inst:PushBufferedAction(BufferedAction(self.inst, nil, ACTIONS.CLOSESHOW))
        end
    end
end)

-- 演出剧本握持
AddPrefabPostInit("playbill_the_doll", function(inst)
    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.HANDS
    inst.components.equippable.restrictedtag = "battlesinger"
    inst:AddComponent("rechargeable")
end)

-- 为战斗而生调整：攻击吸血 + 武器充能加速（battleborn 收益）
AddComponentPostInit("battleborn", function(self)

    function self:OnAttack(data)
        if not self.inst.components.showmode:IsActive() then return end

        local victim = data.target
        local delta = 0

        if not self.inst.components.health:IsDead() and (self.validvictimfn == nil or self.validvictimfn(victim)) then
            local total_health = victim.components.health:GetMaxWithPenalty()
            local damage = (data.weapon ~= nil and data.weapon.components.weapon:GetDamage(self.inst, victim)) or self.inst.components.combat.defaultdamage

            if damage > 0 or self.allow_zero then
                local percent = (damage <= 0 and 0) or (total_health <= 0 and math.huge) or damage / total_health

                delta = math.clamp(victim.components.combat.defaultdamage * self.battleborn_bonus * percent, self.clamp_min, self.clamp_max)
                if victim:HasTag("epic") then
                    delta = delta * 2
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

        -- 武器充能加速（battleborn 收益）
        local equip = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if equip.components.rechargeable and not equip.components.rechargeable:IsCharged() then
            local remaining = equip.components.rechargeable:GetTimeToCharge()
            if remaining > 1 then
                equip.components.rechargeable:Discharge(remaining - 1)
            else
                equip.components.rechargeable:SetPercent(1)
            end
        end
    end
end)
