-- 奔雷矛切换攻击模式
local SWITCH_ATTACK_MODE = Action({ priority=2, mount_valid=true })
SWITCH_ATTACK_MODE.id = "SWITCH_ATTACK_MODE"
	SWITCH_ATTACK_MODE.strfn = function(act)
	    if act.invobject and act.invobject:HasTag("attackmode_leap") then
	        return "LEAP"
	    elseif act.invobject and act.invobject:HasTag("attackmode_lunge") then
	        return "LUNGE"
	    end
	    return "MULTITHRUST"
	end
	SWITCH_ATTACK_MODE.fn = function(act)
	    local weapon = act.invobject
	    if weapon == nil then return false end
	    if weapon:HasTag("attackmode_leap") then
	        weapon:RemoveTag("attackmode_leap")
	        weapon:AddTag("attackmode_lunge")
	    elseif weapon:HasTag("attackmode_lunge") then
	        weapon:RemoveTag("attackmode_lunge")
	    else
	        weapon:AddTag("attackmode_leap")
	    end
	    if weapon.UpdateAoeTargeting then weapon:UpdateAoeTargeting() end
	    weapon.components.rechargeable:Discharge(weapon._cooldown)
	    return true
	end

AddAction(SWITCH_ATTACK_MODE)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(ACTIONS.SWITCH_ATTACK_MODE, "doshortaction"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(ACTIONS.SWITCH_ATTACK_MODE, "doshortaction"))

AddComponentAction("INVENTORY", "equippable", function(inst, doer, actions)
    if doer.prefab == "wathgrithr" and inst.components.equippable:IsEquipped() and
    inst.components.rechargeable ~= nil and inst.components.rechargeable:IsCharged() then
        if inst.prefab == "playbill_the_doll"  then
            table.insert(actions, doer.components.showmode:IsActive() and ACTIONS.CLOSESHOW or ACTIONS.OPENSHOW)
        elseif inst:HasTag("aoeweapon_lunge") and doer.components.showmode:IsActive() then
            table.insert(actions, ACTIONS.SWITCH_ATTACK_MODE)
        end
    end
end)
