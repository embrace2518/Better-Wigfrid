local function SpawnShadowHands(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local num_hands = 4
    for i = 1, num_hands do
        local angle = (i - 1) * (TWOPI / num_hands)
        local radius = 1.5
        local hx = x + math.cos(angle) * radius
        local hz = z + math.sin(angle) * radius
        local hy = y + 2.5 + math.random() * 1.5
        local fx = SpawnPrefab("shadowhand_fx")
        if fx ~= nil then
            fx.Transform:SetPosition(hx, hy, hz)
        end
    end
end

local ShowMode = Class(function(self, inst)
    self.inst = inst
    self._light = nil
end)

function ShowMode:IsActive()
    return self.inst:HasTag("wathgrithr_show")
end

function ShowMode:Enter(song_count)
    if self:IsActive() then return end
    self.inst:AddTag("wathgrithr_show")

    local mult = song_count or 0
    self.inst._show_start_time = GetTime()

    self.inst.components.eater:SetDiet({FOODGROUP.OMNI}, {FOODTYPE.MEAT, FOODTYPE.GOODIES})
    self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "wathgrithr_show", 1 + 0.1 * mult)
    self.inst.components.combat.damagemultiplier = 1 + 0.1 * mult
    self.inst.components.health:SetAbsorptionAmount(0.1 * mult)
    self.inst.SoundEmitter:PlaySound("stageplay_set/statue_lyre/stinger_intro_act1")

    if self._light == nil then
        self._light = SpawnPrefab("booklight", nil, 0)
        self._light.entity:SetParent(self.inst.entity)
    end

    SpawnShadowHands(self.inst)
    local fx = SpawnPrefab("marionette_appear_fx")
    if fx ~= nil then fx.Transform:SetPosition(self.inst.Transform:GetWorldPosition()) end
end

function ShowMode:Exit()
    if not self:IsActive() then return end
    self.inst:RemoveTag("wathgrithr_show")

    self.inst._show_start_time = nil

    self.inst.components.eater:SetDiet({FOODGROUP.OMNI})
    self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, "wathgrithr_show")
    self.inst.components.combat.damagemultiplier = 1
    self.inst.components.health:SetAbsorptionAmount(0)
    self.inst.SoundEmitter:PlaySound("stageplay_set/statue_lyre/stinger_outro")

    if self._light ~= nil then
        self._light:Remove()
        self._light = nil
    end

    SpawnShadowHands(self.inst)
    local fx = SpawnPrefab("marionette_disappear_fx")
    if fx ~= nil then fx.Transform:SetPosition(self.inst.Transform:GetWorldPosition()) end
end

return ShowMode
