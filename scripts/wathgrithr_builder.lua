-- 普通战歌制作消耗80灵感
local SONG_INSP_COST = 50

AddComponentPostInit("builder", function(self)
    local _old_HasIngredients = self.HasIngredients
    function self:HasIngredients(recipe, ...)
        if type(recipe) == "table" and recipe.name then
            local name = recipe.name
            if name:match("^battlesong_") and not name:match("^battlesong_instant") then
                if not self.inst.components.singinginspiration
                    or self.inst.components.singinginspiration.current < SONG_INSP_COST then
                    return false
                end
            end
        end
        return _old_HasIngredients(self, recipe, ...)
    end

    local _old_DoBuild = self.DoBuild
    function self:DoBuild(recname, pt, rot, skin, onsuccess)
        if type(recname) == "string"
            and recname:match("^battlesong_")
            and not recname:match("^battlesong_instant") then
            self.inst.components.singinginspiration:DoDelta(-SONG_INSP_COST)
        end
        return _old_DoBuild(self, recname, pt, rot, skin, onsuccess)
    end
end)
