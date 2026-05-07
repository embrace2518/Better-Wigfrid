GLOBAL.setmetatable(env, {__index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end})
-------------------------------本地化----------------------------------
local lan = (_G.LanguageTranslator.defaultlang == "zh") and "zh" or "en"

if lan == "zh" then
    modimport("languages/chs")
else
    modimport("languages/en")
end

modimport("scripts/better_wathgrithr")

-- 登记技能树
local BuildSkillsData = require("prefabs/skilltree_better_wathgrithr")
local defs = require("prefabs/skilltree_defs")
local data = BuildSkillsData(defs.FN)
defs.CreateSkillTreeFor("wathgrithr", data.SKILLS)
defs.SKILLTREE_ORDERS["wathgrithr"] = data.ORDERS

TUNING.BATTLESONG_DURABILITY_MOD = 0.5
TUNING.BATTLESONG_SANITYURA_SPEEDMULT = 0.15
TUNING.BATTLESONG_FIRE_VALUE = 2
TUNING.BATTLESONG_INSTANT_VALUE = 0.5

UPGRADETYPES.WATHGRITHR_BATTLESONG = "purebrilliance"

-- local owner = inst.components.inventoryitem:GetGrandOwner()
-- local hand_item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
-- inst.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_3")
-- inst.components.singinginspiration:IsSongActive({NAME = "battlesong_lunaraligned_buff"})

-- 配方
AddRecipe2("battlesong_fireresistance",	{Ingredient("papyrus", 1), Ingredient("featherpencil", 1), Ingredient("dragon_scales", 1)},         TECH.NONE,		{builder_tag="battlesinger"})
AddRecipe2("battlesong_instant_taunt",		{Ingredient("papyrus", 1), Ingredient("featherpencil", 1), Ingredient("sewing_mannequin", 1)}, 	                    TECH.NONE,		{builder_tag="battlesinger"})
AddRecipe2("battlesong_instant_panic",		{Ingredient("papyrus", 1), Ingredient("featherpencil", 1), Ingredient("purplegem", 1)}, 						    TECH.NONE,		{builder_tag="battlesinger"})
AddRecipe2("battlesong_instant_revive",	{Ingredient("papyrus", 1),    Ingredient("featherpencil", 1),     Ingredient("goose_feather", 3)},						TECH.NONE,		{builder_skill="wathgrithr_songs_revivewarrior"  })
AddRecipe2("wathgrithr_improvedhat",		{Ingredient("goldnugget", 4), Ingredient("beefalowool", 4),       Ingredient("marble", 2)},							TECH.NONE,		{builder_skill="wathgrithr_arsenal_helmet_3"    })
