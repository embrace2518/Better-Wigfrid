GLOBAL.setmetatable(env, {__index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end})
-------------------------------本地化----------------------------------
local lan = (_G.LanguageTranslator.defaultlang or ""):match("^zh") and "zh" or "en"

if lan == "zh" then
    modimport("languages/chs")
end

Assets = {
    Asset("ANIM", "anim/better_wathgrithr_mount.zip"),
    Asset("ANIM", "anim/better_wathgrithr_sing.zip"),
}
PrefabFiles = { "wathgrithr_stageusher", "wathgrithr_sing_notes" }

modimport("scripts/tuning")

modimport("scripts/components/multithruster")
modimport("scripts/components/showmode")

modimport("scripts/actions/wathgrithr_lightning")
modimport("scripts/actions/wathgrithr_show")
modimport("scripts/actions/wathgrithr_sing")
modimport("scripts/actions/wathgrithr_switch_attack")

modimport("scripts/better_wathgrithr")
modimport("scripts/wathgrithr_arsenal")
modimport("scripts/wathgrithr_builder")
modimport("scripts/wathgrithr_battlesongs")
modimport("scripts/wathgrithr_components")
modimport("scripts/wathgrithr_rider")
modimport("scripts/wathgrithr_stategraph")

-- 登记技能树
local BuildSkillsData = require("prefabs/skilltree_better_wathgrithr")
local defs = require("prefabs/skilltree_defs")
local data = BuildSkillsData(defs.FN)
defs.CreateSkillTreeFor("wathgrithr", data.SKILLS)
defs.SKILLTREE_ORDERS["wathgrithr"] = data.ORDERS

UPGRADETYPES.WATHGRITHR_BATTLESONG = "purebrilliance"

-- 配方
-- 普通战歌：莎草纸+羽毛笔+80灵感
AddRecipe2("battlesong_durability",     {Ingredient("papyrus", 1), Ingredient("featherpencil", 1)}, TECH.NONE, {builder_tag="battlesinger"})
AddRecipe2("battlesong_healthgain",     {Ingredient("papyrus", 1), Ingredient("featherpencil", 1)}, TECH.NONE, {builder_tag="battlesinger"})
AddRecipe2("battlesong_sanitygain",     {Ingredient("papyrus", 1), Ingredient("featherpencil", 1)}, TECH.NONE, {builder_tag="battlesinger"})
AddRecipe2("battlesong_sanityaura",     {Ingredient("papyrus", 1), Ingredient("featherpencil", 1)}, TECH.NONE, {builder_tag="battlesinger"})
AddRecipe2("battlesong_fireresistance", {Ingredient("papyrus", 1), Ingredient("featherpencil", 1)}, TECH.NONE, {builder_tag="battlesinger"})

AddRecipe2("playbill_the_doll",         {Ingredient("papyrus", 4), Ingredient("featherpencil", 1), Ingredient("livinglog", 2)},   TECH.NONE, {builder_tag="battlesinger"})

-- 即时战歌：配方材料锁定（sewing_mannequin 不可制作）
AddRecipe2("battlesong_instant_taunt",  {Ingredient("papyrus", 1), Ingredient("featherpencil", 1), Ingredient("sewing_mannequin", 1)}, TECH.NONE, {builder_tag="battlesinger"})
AddRecipe2("battlesong_instant_panic",  {Ingredient("papyrus", 1), Ingredient("featherpencil", 1), Ingredient("sewing_mannequin", 1)}, TECH.NONE, {builder_tag="battlesinger"})
AddRecipe2("battlesong_instant_revive", {Ingredient("papyrus", 1), Ingredient("featherpencil", 1), Ingredient("sewing_mannequin", 1)}, TECH.NONE, {builder_skill="wathgrithr_songs_revivewarrior"})

AddRecipe2("wathgrithr_improvedhat",    {Ingredient("goldnugget", 4), Ingredient("beefalowool", 4), Ingredient("marble", 2)},          TECH.NONE, {builder_skill="wathgrithr_arsenal_helmet_3"})
