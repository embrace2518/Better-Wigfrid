local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.AnimState:SetBank("wilson")
    inst.AnimState:SetBuild("wathgrithr_sing")
    inst.AnimState:PlayAnimation("sing_loop_only", true)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end
    inst:AddComponent("aoetargeting")
    inst.components.aoetargeting:SetEnabled(true)
    inst.components.aoetargeting:SetRange(TUNING.WATHGRITHR_SING_RANGE)
    return inst
end

return Prefab("wathgrithr_sing_notes", fn)
