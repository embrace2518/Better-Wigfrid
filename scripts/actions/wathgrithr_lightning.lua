-- 动作：落雷
local WATHGRITHR_LIGHTNING = Action({ priority=2, rmb=true, distance=36, mount_valid=true, encumbered_valid=true })
WATHGRITHR_LIGHTNING.id = "WATHGRITHR_LIGHTNING"
WATHGRITHR_LIGHTNING.str = "落雷"

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

WATHGRITHR_LIGHTNING.fn = function(act)
    local doer = act.doer
    local pos = act:GetActionPoint()
    if pos == nil then
        return false
    end
    if pos.y == nil then
        pos = Vector3(pos.x, 0, pos.z)
    end
    if not doer:HasTag("wathgrithr_show")and doer.components.singinginspiration:GetPercent() > 0.2 then
        doer.components.singinginspiration:DoDelta(-20)

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

        TheWorld:PushEvent("ms_sendlightningstrike", pos)
        if math.random() < 0.1 then
            TheWorld:PushEvent("ms_forceprecipitation", true)
        end
    else
        local hand_item = doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if hand_item.components.rechargeable and hand_item.components.rechargeable:IsCharged() and
            doer.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_5") then
            doer._feather_leap = {targetpos = pos, weapon = hand_item}
            doer.components.talker:Say("我乘闪电而来！")
            if hand_item.components.rechargeable then
                hand_item.components.rechargeable:Discharge(hand_item._cooldown or TUNING.SPEAR_WATHGRITHR_LIGHTNING_LUNGE_COOLDOWN)
            end
        end
    end
    return false
end

AddAction(WATHGRITHR_LIGHTNING)

local function AddWathgrithrLightningState(stategraph)
    stategraph.states["wathgrithr_lightning"] = GLOBAL.State{
        name = "wathgrithr_lightning",
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

AddStategraphPostInit("wilson", AddWathgrithrLightningState)
AddStategraphPostInit("wilson_client", AddWathgrithrLightningState)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(WATHGRITHR_LIGHTNING, "wathgrithr_lightning"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(WATHGRITHR_LIGHTNING, "wathgrithr_lightning"))