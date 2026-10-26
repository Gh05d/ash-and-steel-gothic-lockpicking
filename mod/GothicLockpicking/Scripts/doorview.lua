-- Door view for the combination minigame. The game only shows a chest there; its door view belongs to the
-- other minigame (LockPickGrass with Door? = true). Same layout, so the mod hides the chest scenery and
-- attaches copies of that door, wall and beams (transforms read live from LockPickGrass, 2026-10-26).
local M = {}

local TAG = "GothicLockpickingDoorView"
local MODELS = "/Game/Models/Grayshaft_Buildings/"
local DOOR = MODELS .. "carpets/models/wooden/m_gs_carpets_door_01.m_gs_carpets_door_01"
local WALL = MODELS .. "Village_01c/Models/abandoned_walls/m_gs_village_01_wall_08.m_gs_village_01_wall_08"
local BEAM = MODELS .. "WoodPack_01/Models/wood_boards_old/m_gs_WoodPack_01_beam_02.m_gs_WoodPack_01_beam_02"
local PARTS = {
    { DOOR, { X = -6.1, Y = -97.1, Z = 74.1 }, { Pitch = 0, Yaw = 90, Roll = 0 } },
    { WALL, { X = -6.1, Y = -50.3, Z = -92.3 }, { Pitch = 0, Yaw = 90, Roll = 0 }, { X = 1.115, Y = 1, Z = 1 } },
    { BEAM, { X = 7.7, Y = 23.6, Z = 13.4 }, { Pitch = 90, Yaw = -6.7, Roll = -6.7 }, { X = 2.34, Y = 2.34, Z = 2.34 } },
    { BEAM, { X = -11.7, Y = -109.4, Z = 13.4 }, { Pitch = 90, Yaw = 0, Roll = 180 }, { X = 2.34, Y = 2.34, Z = 2.34 } },
    { BEAM, { X = 12.0, Y = -43.7, Z = 116.6 }, { Pitch = 0, Yaw = 90, Roll = 90 }, { X = 1.8, Y = 2.34, Z = 1.31 } },
}
local HIDE = { "SkeletalMesh", "Ground", "Grass", "Grass1" }
for i = 0, 9 do HIDE[#HIDE + 1] = i == 0 and "Bush" or ("Bush" .. i) end
for i = 0, 6 do HIDE[#HIDE + 1] = i == 0 and "Floor" or ("Floor" .. i) end

local parts = {} -- actors this module spawned; only these are ever destroyed

local function valid(o)
    return o ~= nil and o:IsValid()
end

local function asset(path)
    local o = StaticFindObject(path)
    if not valid(o) and LoadAsset then
        pcall(LoadAsset, path)
        o = StaticFindObject(path)
    end
    return valid(o) and o or nil
end

local function isTagged(a)
    local tagged = false
    pcall(function()
        a.Tags:ForEach(function(_, t)
            if t:get():ToString() == TAG then tagged = true end
        end)
    end)
    return tagged
end

function M.clear()
    for _, a in ipairs(parts) do
        if valid(a) then pcall(function() a:K2_DestroyActor() end) end
    end
    parts = {}
end

-- After a script reload the list is gone: find the leftovers by their tag (never by mesh name - the same
-- meshes are placed in the level, and destroying those crashed the game).
function M.clearLeftovers()
    for _, a in ipairs(FindAllOf("StaticMeshActor") or {}) do
        if valid(a) and isTagged(a) then pcall(function() a:K2_DestroyActor() end) end
    end
end

local function addPart(keylock, mesh, loc, rot, scale)
    local cls = StaticFindObject("/Script/Engine.StaticMeshActor")
    local a = keylock:GetWorld():SpawnActor(cls, keylock:K2_GetActorLocation(), { Pitch = 0, Yaw = 0, Roll = 0 })
    if not valid(a) then return end
    parts[#parts + 1] = a
    a.Tags[1] = FName(TAG)
    a:SetActorEnableCollision(false)
    local c = a.StaticMeshComponent
    c:SetMobility(2) -- Movable
    c:SetStaticMesh(mesh)
    a:K2_AttachToActor(keylock, FName("None"), 0, 0, 0, false) -- KeepRelative
    a:K2_SetActorRelativeLocation(loc, false, {}, false)
    a:K2_SetActorRelativeRotation(rot, false, {}, false)
    if scale then a:SetActorRelativeScale3D(scale) end
end

function M.show(keylock)
    M.clear()
    for _, name in ipairs(HIDE) do
        pcall(function() keylock[name]:SetVisibility(false, true) end)
    end
    for _, p in ipairs(PARTS) do
        local mesh = asset(p[1])
        if mesh then addPart(keylock, mesh, p[2], p[3], p[4]) end
    end
end

return M
