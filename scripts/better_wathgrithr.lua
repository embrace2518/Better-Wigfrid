-- 薇格弗德
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
        local hand_item = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if not inst:HasTag("wathgrithr_show") and hand_item ~= nil and hand_item.prefab == "playbill_the_doll" or
        canblink and inst:HasTag("wathgrithr_show") and hand_item ~= nil and hand_item:HasTag("attackmode_leap") then
            return { ACTIONS.WATHGRITHR_LIGHTNING }
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

    inst.components.eater:SetDiet({ FOODGROUP.OMNI })
    inst.components.combat.damagemultiplier = 1
    inst.components.health:SetAbsorptionAmount(1)

    if inst.components.leader == nil then
        inst:AddComponent("leader")
    end

    inst:AddComponent("rechargeable")

    inst:AddComponent("leaderrollcall")
    inst.components.leaderrollcall:SetRadius(TUNING.ONEMANBAND_RANGE)
    inst.components.leaderrollcall:SetMaxFollowers(TUNING.WATHGRITHR_SING_MAX_FOLLOWERS)
    inst.components.leaderrollcall:SetCanTendFarmPlant(true)
    inst.components.leaderrollcall:SetUpdateTime(1)
    inst.components.leaderrollcall:Disable()

    local function LinkUsher(inst, usher)
        inst.components.leader:AddFollower(usher)
        inst._stageusher = usher
        inst:ListenForEvent("onremove", function() inst._stageusher = nil end, usher)
    end

    local old_onnewspawn = inst._OnNewSpawn
    inst._OnNewSpawn = function(inst)
        if old_onnewspawn then old_onnewspawn(inst) end
        if inst.components.inventory ~= nil then
            local doll = SpawnPrefab("playbill_the_doll")
            inst.components.inventory:GiveItem(doll)
            inst:StartUpdatingComponent(inst.components.singinginspiration)
            local x, y, z = inst.Transform:GetWorldPosition()
            local angle = math.random() * 2 * PI
            local usher = SpawnPrefab("wathgrithr_stageusher")
            if usher ~= nil then
                usher.Transform:SetPosition(x + math.cos(angle) * 3, 0, z + math.sin(angle) * 3)
                LinkUsher(inst, usher)
            end
        end
    end

    local old_onsave = inst._OnSave
    inst._OnSave = function(inst, data)
        if old_onsave then old_onsave(inst, data) end
        if inst._stageusher ~= nil and inst._stageusher:IsValid() then
            data._stageusher = inst._stageusher:GetSaveRecord()
        end
    end

    local old_onload = inst._OnLoad
    inst._OnLoad = function(inst, data)
        if old_onload then old_onload(inst, data) end
        inst:StartUpdatingComponent(inst.components.singinginspiration)
        if data ~= nil and data._stageusher ~= nil then
            local usher = SpawnSaveRecord(data._stageusher)
            if usher ~= nil then
                if inst.migrationpets ~= nil then
                    table.insert(inst.migrationpets, usher)
                end
                LinkUsher(inst, usher)
            end
        end
    end

    local old_ondespawn = inst._OnDespawn
    inst._OnDespawn = function(inst, migrationdata)
        if migrationdata == nil and inst._stageusher ~= nil and inst._stageusher:IsValid() then
            inst._stageusher:DoTaskInTime(0, inst._stageusher.Remove)
        end
        if old_ondespawn then old_ondespawn(inst, migrationdata) end
    end
end)

AddComponentPostInit("singinginspiration", function(self)
    self.OnHitOther = function() end
    self.OnAttacked = function() end
    function self:DoDelta(delta, forceupdate)
        self.current = math.min(math.max(self.current + delta, 0), self.max)

        local newpercent = self:GetPercent()
        local old_slots_available = self.available_slots
        self.available_slots = self.CalcAvailableSlotsForInspirationFn(self.inst, newpercent)

        self.inst:PushEvent("inspirationdelta", { newpercent = newpercent, slots_available = self.available_slots })

        --print("slots_available", self.available_slots, old_slots_available)
        if self.available_slots ~= old_slots_available then
            for i = #self.active_songs, self.available_slots + 1, -1 do
                self:PopSong()
                self.inst.components.combat.damagemultiplier = 1 + 0.1 * #self.active_songs
                self.inst.components.health:SetAbsorptionAmount(1 - 0.1 * #self.active_songs)
            end
        end
    end

    function self:OnUpdate(dt)
        if self.inst:HasTag("wathgrithr_show") then
            self.is_draining = true
            local head_item = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEADS)
            if head_item ~= nil and head_item.prefab == "wathgrithr_improvedhat" and
            self.inst.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_helmet_4") then
                self:DoDelta(-(50 / TUNING.TOTAL_DAY_TIME) * dt) -- 50 per 8 minutes
            else
                self:DoDelta(-(100 / TUNING.TOTAL_DAY_TIME) * dt)
            end
        else
            self.is_draining = false
            self:DoDelta((20 / TUNING.TOTAL_DAY_TIME) * dt)
        end

        if self.current == self.max and not self.inst:HasTag("wathgrithr_show") then
            self.inst:PushBufferedAction(BufferedAction(self.inst, nil, ACTIONS.OPENSHOW))
        elseif self.current == 0 and self.inst:HasTag("wathgrithr_show") then
            self.inst:PushBufferedAction(BufferedAction(self.inst, nil, ACTIONS.CLOSESHOW))
        end
    end
end)

AddPrefabPostInit("playbill_the_doll", function(inst)
    if inst.components.equippable == nil then
        inst:AddComponent("equippable")
        inst.components.equippable.equipslot = EQUIPSLOTS.HANDS
        inst.components.equippable.restrictedtag = "battlesinger"
    end
    inst:AddComponent("rechargeable")
end)

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

-- 奔雷矛切换攻击模式
ACTIONS.SWITCH_ATTACK_MODE = Action({ priority=2, mount_valid=true })
ACTIONS.SWITCH_ATTACK_MODE.id = "SWITCH_ATTACK_MODE"
ACTIONS.SWITCH_ATTACK_MODE.strfn = function(act)
    local mode = act.invobject and act.invobject._attack_mode or 1
    return ({"切换：连击", "切换：跃击", "切换：冲刺"})[mode]
end
ACTIONS.SWITCH_ATTACK_MODE.fn = function(act)
    local weapon = act.invobject
    local doer = act.doer
    if weapon == nil then return false end
    local names = {"连击", "跃击", "冲刺"}
    weapon._attack_mode = (weapon._attack_mode or 1) % 3 + 1
    weapon:RemoveTag("attackmode_leap")
    weapon:RemoveTag("attackmode_lunge")
    if weapon._attack_mode == 2 then
        weapon:AddTag("attackmode_leap")
    elseif weapon._attack_mode == 3 then
        weapon:AddTag("attackmode_lunge")
    end
    doer.components.talker:Say(names[weapon._attack_mode])
    if weapon.UpdateAoeTargeting then weapon:UpdateAoeTargeting() end
    weapon.components.rechargeable:Discharge(weapon._cooldown)
    return true
end

AddAction(ACTIONS.SWITCH_ATTACK_MODE)

AddComponentAction("INVENTORY", "equippable", function(inst, doer, actions)
    if doer.prefab == "wathgrithr" and inst.components.equippable:IsEquipped() and
    inst.components.rechargeable ~= nil and inst.components.rechargeable:IsCharged() then
        if inst.prefab == "playbill_the_doll"  then
            table.insert(actions, doer:HasTag("wathgrithr_show") and ACTIONS.CLOSESHOW or ACTIONS.OPENSHOW)
        elseif inst:HasTag("aoeweapon_lunge") then
            table.insert(actions, ACTIONS.SWITCH_ATTACK_MODE)
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

AddStategraphPostInit('wilson', function(sg)
    local _old_attack_onenter = sg.states['attack'].onenter
    sg.states['attack'].onenter = function(inst)
        if inst.prefab == "wathgrithr" then
            local equip = inst.components.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS)
            if inst.components.rider and inst.components.rider:IsRiding() and
                inst.components.rider:GetSaddle().prefab == "saddle_wathgrithr" and
                inst.components.skilltreeupdater:IsActivated("wathgrithr_beefalo_saddle") and
                equip and equip:HasTag("weapon") then
                equip:AddTag('rangedweapon')
                _old_attack_onenter(inst)
            else
                _old_attack_onenter(inst)
            end
            if equip and equip.components.multithruster then
                equip.components.multithruster:OnAttack()
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

        --[[if inst.components.playercontroller ~= nil then
            inst.components.playercontroller:RemotePausePrediction()
        end]]
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
    end
end)


