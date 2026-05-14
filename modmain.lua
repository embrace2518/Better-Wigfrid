GLOBAL.setmetatable(env, {__index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end})
-------------------------------本地化----------------------------------
local lan = (_G.LanguageTranslator.defaultlang == "zh") and "zh" or "en"

if lan == "zh" then
    modimport("languages/chs")
end

Assets = {
    Asset("ANIM", "anim/better_wathgrithr.zip"),
}
PrefabFiles = { "wathgrithr_stageusher" }

modimport("scripts/components/multithruster")

modimport("scripts/actions/wathgrithr_lightning")
modimport("scripts/actions/wathgrithr_show")
modimport("scripts/actions/wathgrithr_sing")
modimport("scripts/better_wathgrithr")
modimport("scripts/wathgrithr_arsenal")
modimport("scripts/wathgrithr_battlesongs")
modimport("scripts/wathgrithr_rider")

-- 登记技能树
local BuildSkillsData = require("prefabs/skilltree_better_wathgrithr")
local defs = require("prefabs/skilltree_defs")
local data = BuildSkillsData(defs.FN)
defs.CreateSkillTreeFor("wathgrithr", data.SKILLS)
defs.SKILLTREE_ORDERS["wathgrithr"] = data.ORDERS

TUNING.SPEAR_WATHGRITHR_LIGHTNING_LUNGE_COOLDOWN = 6
TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_LUNGE_COOLDOWN = 3

TUNING.INSPIRATION_GAIN_RATE = 0
TUNING.BATTLESONG_DURABILITY_MOD = 0.66 --0.75
TUNING.BATTLESONG_INSTANT_VALUE = 0.5
TUNING.BATTLESONG_PANIC_TIME = 6

TUNING.WATHGRITHR_SING_INSPIRE_PER_HIRE = 5
TUNING.WATHGRITHR_SING_INSPIRE_PER_CROP = 1
TUNING.WATHGRITHR_SING_INSPIRE_COOLDOWN = 60
TUNING.WATHGRITHR_SING_DAILY_HIRE_MAX = 20
TUNING.WATHGRITHR_SING_DAILY_CROP_MAX = 10
TUNING.WATHGRITHR_SING_MAX_FOLLOWERS = 4
TUNING.WATHGRITHR_SING_HIRE_TIME = TUNING.TOTAL_DAY_TIME / 4

UPGRADETYPES.WATHGRITHR_BATTLESONG = "purebrilliance"

-- local owner = inst.components.inventoryitem:GetGrandOwner()
-- local hand_item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
-- inst.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_3")
-- inst.components.singinginspiration:IsSongActive({NAME = "battlesong_lunaraligned_buff"})

-- 配方
AddRecipe2("battlesong_fireresistance",	{Ingredient("papyrus", 1), Ingredient("featherpencil", 1), Ingredient("dragon_scales", 1)},         TECH.NONE,		{builder_tag="battlesinger"})
AddRecipe2("battlesong_instant_taunt",		{Ingredient("papyrus", 1), Ingredient("featherpencil", 1), Ingredient("sewing_mannequin", 1)}, 	                    TECH.NONE,		{builder_tag="battlesinger"})
AddRecipe2("battlesong_instant_panic",		{Ingredient("papyrus", 1), Ingredient("featherpencil", 1), Ingredient("sewing_mannequin", 1)}, 						    TECH.NONE,		{builder_tag="battlesinger"})
AddRecipe2("battlesong_instant_revive",	{Ingredient("papyrus", 1),    Ingredient("featherpencil", 1),     Ingredient("goose_feather", 3)},						TECH.NONE,		{builder_skill="wathgrithr_songs_revivewarrior"  })
AddRecipe2("wathgrithr_improvedhat",		{Ingredient("goldnugget", 4), Ingredient("beefalowool", 4),       Ingredient("marble", 2)},							TECH.NONE,		{builder_skill="wathgrithr_arsenal_helmet_3"    })
