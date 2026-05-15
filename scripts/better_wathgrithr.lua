-- 薇格弗德
local function IsNotBlocked(pt)
    return TheWorld.Map:IsPassableAtPoint(pt:Get()) and not TheWorld.Map:IsGroundTargetBlocked(pt)
end
local function CanBlinkTo(inst, pt)
    local x, y, z = inst.Transform:GetWorldPosition()
    return IsNotBlocked(pt) and IsTeleportingPermittedFromPointToPoint(x, y, z, pt.x, pt.y, pt.z)
end

local function CanBlinkFromWithMap(inst, pt)
    local x, y, z = inst.Transform:GetWorldPosition()
    return IsTeleportingPermittedFromPointToPoint(x, y, z, pt.x, pt.y, pt.z)
end

local function GetPointSpecialActions(inst, pos, useitem, right)
    if right and useitem == nil then
        local hand_item = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if hand_item ~= nil then
            if hand_item.prefab == "playbill_the_doll" then
                return { ACTIONS.WATHGRITHR_LIGHTNING }
            end
            if inst:HasTag("wathgrithr_show") and inst.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_5") and
            hand_item:HasTag("attackmode_leap") and
            hand_item.components.rechargeable and hand_item.components.rechargeable:IsCharged() then
                local canblink
                if inst.checkingmapactions then
                    canblink = inst:CanBlinkFromWithMap(inst.checkingmapactions_pos or inst:GetPosition())
                else
                    canblink = inst:CanBlinkTo(pos)
                end
                if canblink then
                    return { ACTIONS.WATHGRITHR_LIGHTNING }
                end
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

    if not TheWorld.ismastersim then return inst end

    inst.components.eater:SetDiet({ FOODGROUP.OMNI })
    inst.components.combat.damagemultiplier = 1
    inst.components.health:SetAbsorptionAmount(0)

    inst:AddComponent("showmode")

    -- 剧本进度追踪
    inst._wathgrithr_acts_done = {}
    inst.GetActDone = function(inst, act) return inst._wathgrithr_acts_done ~= nil and inst._wathgrithr_acts_done[act] or false end
    inst.SetActDone = function(inst, act) if inst._wathgrithr_acts_done ~= nil then inst._wathgrithr_acts_done[act] = true end end
    inst.HasPlaybill = function(inst)
        if inst.components.inventory then
            local items = inst.components.inventory:FindItems(function(item) return item.prefab == "playbill_the_doll" end)
            return items ~= nil and next(items) ~= nil
        end
        return false
    end

    inst:AddComponent("rechargeable")

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
        data._wathgrithr_acts_done = {}
        for k, v in pairs(inst._wathgrithr_acts_done) do
            data._wathgrithr_acts_done[k] = v
        end
    end

    local old_onload = inst._OnLoad
    inst._OnLoad = function(inst, data)
        if old_onload then old_onload(inst, data) end
        inst:StartUpdatingComponent(inst.components.singinginspiration)
        if data ~= nil and data._wathgrithr_acts_done ~= nil then
            inst._wathgrithr_acts_done = data._wathgrithr_acts_done
        end
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
