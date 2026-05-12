-- 战歌相关
local song_lunarseed = GetModConfigData("song_lunarseed")

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

AddPrefabPostInit("charlie_stage_post", function(inst)
    if not TheWorld.ismastersim then return end

    inst:ListenForEvent("play_performed", function(inst, data)
        local cast = inst.components.stageactingprop.cast
        print("[BetterWigfrid] play_performed fired, cast:", cast ~= nil)
        if cast then
            for _, role_data in pairs(cast) do
                print("[BetterWigfrid] cast member:", role_data.castmember ~= nil and role_data.castmember.prefab or "nil")
                if role_data.castmember
                    and role_data.castmember.prefab == "wathgrithr" then
                    inst._wathgrithr_performed = true
                    print("[BetterWigfrid] _wathgrithr_performed set to TRUE")
                    if inst._clear_wathgrithr_task then
                        inst._clear_wathgrithr_task:Cancel()
                    end
                    inst._clear_wathgrithr_task = inst:DoTaskInTime(15,function()
                        inst._wathgrithr_performed = nil
                        inst._clear_wathgrithr_task = nil
                    end)
                    break
                end
            end
        end
    end)
end)

AddPrefabPostInit("hedgehound", function(inst)
    if not TheWorld.ismastersim then return end

    inst:DoTaskInTime(0, function(inst)
        if inst.hedgeitem then
            local x, y, z = inst.Transform:GetWorldPosition()
            local stages = TheSim:FindEntities(x, y, z, 30, nil, {"INLIMBO", "FX", "NOCLICK", "DECOR"})
            for _, stage in ipairs(stages) do
                if stage._wathgrithr_performed then
                    inst._wathgrithr_bonus = true
                    print("[BetterWigfrid] _wathgrithr_bonus set to TRUE")
                    break
                end
            end
        end
    end)

    inst:ListenForEvent("death", function(inst)
        if inst._wathgrithr_bonus and math.random() < 0.5 then
            local loot = (math.random() < 0.5) and "battlesong_instant_taunt" or "battlesong_instant_panic"
            inst.components.lootdropper:FlingItem(SpawnPrefab(loot))
        end
    end)
end)

