-- 灵感消耗配方支持（参考重生护肤的 CHARACTER_INGREDIENT.HEALTH）
GLOBAL.CHARACTER_INGREDIENT.INSPIRATION = "decrease_inspiration"

AddComponentPostInit("builder", function(self)
    local _old_HasCharacterIngredient = self.HasCharacterIngredient
    function self:HasCharacterIngredient(ingredient)
        if ingredient.type == GLOBAL.CHARACTER_INGREDIENT.INSPIRATION then
            if self.inst.components.singinginspiration ~= nil then
                local current = math.ceil(self.inst.components.singinginspiration.current)
                return current >= ingredient.amount, current
            end
            return false, 0
        end
        return _old_HasCharacterIngredient(self, ingredient)
    end

    local _old_ConsumeIngredients = self.ConsumeIngredients
    function self:ConsumeIngredients(recname, ...)
        _old_ConsumeIngredients(self, recname, ...)
        local recipe = GLOBAL.AllRecipes[recname]
        if recipe then
            for _, v in pairs(recipe.character_ingredients) do
                if v.type == GLOBAL.CHARACTER_INGREDIENT.INSPIRATION then
                    self.inst.components.singinginspiration:DoDelta(-v.amount)
                end
            end
        end
    end
end)
