require "behaviours/follow"
require "behaviours/faceentity"
require "behaviours/leash"
require "behaviours/chaseandattack"

local MIN_FOLLOW = 6
local TARGET_FOLLOW = 9
local MAX_FOLLOW = 12
local LEASH_RETURN_DIST = 10
local LEASH_MAX_DIST = 30
local MAX_CHASE_DIST = 3 * TUNING.STAGEUSHER_ATTACK_RANGE

local WathgrithrStageUsherBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function WathgrithrStageUsherBrain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("spawnpoint", self.inst:GetPosition())
end

function WathgrithrStageUsherBrain:OnStart()
    if not TheWorld.ismastersim then return end

    local function GetLeader()
        return self.inst.components.follower:GetLeader()
    end

    local function GetHomePos()
        return GetLeader() == nil
            and self.inst.components.knownlocations:GetLocation("spawnpoint")
            or nil
    end

    local root =
        PriorityNode({
            ChaseAndAttack(self.inst, nil, MAX_CHASE_DIST),
            Follow(self.inst, GetLeader, MIN_FOLLOW, TARGET_FOLLOW, MAX_FOLLOW, true),
            FaceEntity(self.inst, GetLeader, function(_, target) return GetLeader() == target end),
            Leash(self.inst, GetHomePos, LEASH_MAX_DIST, LEASH_RETURN_DIST),
        }, 0.3)

    self.bt = BT(self.inst, root)
end

return WathgrithrStageUsherBrain
