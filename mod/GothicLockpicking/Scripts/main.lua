-- Gothic Lockpicking for Of Ash and Steel - UE4SS Lua mod
--
-- Lockpicking as in Gothic 2: every lock has a fixed left/right combination, a wrong input starts over and
-- may break the lockpick.
--
-- The game has a combination lock minigame (LockPickExtraKey) that BP_Chest/BP_Door.PickLock start when the
-- lock's "isExtraLocked?" is set. UE4SS calls hooks on blueprint functions after the function ran, so:
--   * Interaction (post) runs 2 s before PickLock (the screen fades out in between): the mod switches the
--     lock to the combination minigame there, with a code the minigame itself can never complete.
--   * AddRotation (post, once per key press) feeds the input to policy.lua, which owns the combination.
--   * ExitPickLock and every new Interaction switch the lock back, so nothing ends up in a save game.
local VERSION = "1.0.0"

local UEHelpers = require("UEHelpers")
local CFG = require("config")
local Policy = require("policy")
local DoorView = require("doorview")
local Display = require("display")

local CHEST = "/Game/RPG_InventorySystem/Classes/Interactable/BP_Chest.BP_Chest_C"
local DOOR = "/Game/RPG_InventorySystem/Classes/Interactable/BP_Door.BP_Door_C"
local KEYLOCK = "/Game/Components/MP_Lockpick/Meshes/LockPickExtraKey.LockPickExtraKey_C"
local STATS = "/Game/RPG_InventorySystem/Blueprints/Components/AC_Stats.AC_Stats_C"
local CHECKS = "/Game/DialogsAndQuests/Quests/BP/QuestSystem_Checks.Default__QuestSystem_Checks_C"
local STATICS = "/Script/Engine.Default__GameplayStatics"
local AUDIO = "/Game/Audio_Grayshaft/01_GS_Audio/"
local SOUND = {
    ok = AUDIO .. "Interaction/LockPick/Correct_Angle/a_gs_correct_angle_01.a_gs_correct_angle_01",
    wrong = AUDIO .. "Interaction/PickPocket/Pocket_FailSlot_01.Pocket_FailSlot_01",
    broken = AUDIO .. "Interaction/LockPick/Lockpick_Break/a_gs_Lockpick_Break_01.a_gs_Lockpick_Break_01",
    open = AUDIO .. "Interaction/LockPick/Open_Closed/a_gs_Lockpick_Open_01.a_gs_Lockpick_Open_01",
}
-- GS_Chest_Code fields (user defined struct, names carry a GUID)
local CODE_DIR = "Direction_5_9BFD83684F973D41ED9946BCF058CFCD"
local CODE_CUR = "CurrentNumber_14_F800B10F461076F5C6D12FAD2D7F3322"
local CODE_TARGET = "TargetNumber_15_E394EB464421F2E25D1F04964C1DEBD5"
local CODE_DONE = "Status_11_6C83963B49D4242A071D2A8E479D608F"
local UNREACHABLE = 1000000 -- turns per code step: the minigame never opens or fails on its own
local OLD_UNREACHABLE = 99 -- what 0.1.0 test builds used
-- S_ItemData fields
local ITEM_ID = "ID_71_E0AE465E423DCDD08FF98D87A5C0B84F"
local ITEM_QTY = "Quantity_76_AD4B883E4427C3E60B4B22B072F4E7C9"
local LOCKPICK = "item_lockpick"
local DEX = 13 -- E_StatCategory
local PERK = "Perk_11_Picklocked"
local SKILL = "skill_picklocking"
local ARM_TIMEOUT_MS = 4000 -- Interaction to PickLock takes 2 s (fade)

local policy = Policy.new(CFG)
local armed = nil   -- { lock = actor, kind = "door"|"chest" } while the mod switched a lock to the combination minigame
local session = nil -- { lock, kind, key, keylock } while the player picks an armed lock
local onSessionStart, onSessionEnd, onProgress = {}, {}, {} -- listeners: function(session)

local function log(fmt, ...)
    print("[GothicLockpicking] " .. string.format(fmt, ...) .. "\n")
end

local function dbg(fmt, ...)
    if CFG.debug then log(fmt, ...) end
end

local function valid(o)
    return o ~= nil and o:IsValid()
end

-- Assets the game does not reference itself are garbage collected after a while, and a pointer kept in Lua
-- then crashes the game (live 2026-10-26). So assets are looked up again every time they are used.
local function asset(path)
    local o = StaticFindObject(path)
    if not valid(o) and LoadAsset then
        pcall(LoadAsset, path)
        o = StaticFindObject(path)
    end
    return valid(o) and o or nil
end

local function playerPawn()
    local pc = UEHelpers.GetPlayerController()
    local pawn = valid(pc) and pc.Pawn or nil
    return valid(pawn) and pawn or nil
end

local function play(name, volume)
    local s, gs = asset(SOUND[name]), StaticFindObject(STATICS)
    local pawn = playerPawn()
    if s and valid(gs) and pawn then
        pcall(function() gs:PlaySound2D(pawn, s, volume or 1.0, 1.0, 0.0, nil, nil, true) end)
    end
end

local function isOpen(lock, kind)
    if kind == "door" then return lock.LockPickOpen end
    return lock["ChestOpen?"]
end

-- Fixed per lock across saves, players and restarts: level actors keep their position, door names do not.
local function lockKey(lock)
    local l = lock:K2_GetActorLocation()
    local function r(v) return math.floor(v / 10 + 0.5) * 10 end
    return string.format("%s@%d,%d,%d", lock:GetClass():GetFName():ToString(), r(l.X), r(l.Y), r(l.Z))
end

local function setCode(lock)
    local code = lock["GS Chest Code"]
    for i = 1, 4 do
        code[i] = { [CODE_DIR] = (i + 1) % 2, [CODE_CUR] = 0, [CODE_TARGET] = UNREACHABLE, [CODE_DONE] = false }
    end
end

-- A lock this mod switched (and a script reload forgot): isExtraLocked? with the unreachable code.
local function isOurs(lock)
    if lock["isExtraLocked?"] ~= true then return false end
    local code = lock["GS Chest Code"]
    if code:GetArrayNum() ~= 4 then return false end
    local ours = true
    code:ForEach(function(_, e)
        local t = e:get()[CODE_TARGET]
        if t ~= UNREACHABLE and t ~= OLD_UNREACHABLE then ours = false end
    end)
    return ours
end

local function restore(lock)
    lock["isExtraLocked?"] = false
    lock["GS Chest Code"]:Empty()
end

local function disarm()
    if armed and valid(armed.lock) and isOurs(armed.lock) then restore(armed.lock) end
    armed = nil
end

local lockpicks -- defined below

local function hasSkill(pawn)
    local skills = pawn.Skills
    if not valid(skills) then return false end
    local out = {}
    local ok = pcall(function() skills["PlayerHaveSkill?"](skills, SKILL, out) end)
    return ok and out.Result == true
end

local function noDanger(lock)
    local checks = StaticFindObject(CHECKS)
    if not valid(checks) then return true end
    local out = {}
    local ok = pcall(function() checks:QS_CheckDanger(lock, out) end)
    return not ok or out.NoDanger ~= false
end

local function arm(lock, kind)
    local pawn = playerPawn()
    if not pawn then return end
    local _, _, picks = lockpicks()
    local state = {
        enabled = (kind == "door" and CFG.doors) or (kind == "chest" and CFG.chests),
        open = isOpen(lock, kind), keyNeeded = lock["KeyNeeded?"] ~= false,
        extraLocked = lock["isExtraLocked?"] ~= false, ours = isOurs(lock),
        isBag = kind == "chest" and lock["isBag?"] == true,
        picks = picks, hasSkill = hasSkill(pawn), noDanger = noDanger(lock),
    }
    if not Policy.mayArm(state) then
        if state.ours then restore(lock) end -- left armed earlier: give it back to the game
        return
    end
    setCode(lock)
    lock["isExtraLocked?"] = true
    local mine = { lock = lock, kind = kind }
    armed = mine
    dbg("armed %s %s", kind, lockKey(lock))
    -- If no PickLock follows (the game refused after all), switch the lock back before it can be saved.
    ExecuteInGameThreadWithDelay(ARM_TIMEOUT_MS, function()
        if armed == mine and not session then
            dbg("no PickLock after Interaction: switching back")
            disarm()
        end
    end)
end

-- After a script reload: switch back every lock the previous script instance left armed.
local function restoreLeftovers()
    local chest, door = StaticFindObject(CHEST), StaticFindObject(DOOR)
    if not (valid(chest) and valid(door)) then return end
    local n = 0
    for _, a in ipairs(FindAllOf("Actor") or {}) do
        if valid(a) and (a:IsA(chest) or a:IsA(door)) and isOurs(a) then
            restore(a)
            n = n + 1
        end
    end
    if n > 0 then log("restored %d lock(s) left over from a script reload", n) end
end

local function newestKeylock()
    local found = nil
    for _, k in ipairs(FindAllOf("LockPickExtraKey_C") or {}) do
        if valid(k) then found = k end
    end
    return found
end

local function dexterity(pawn)
    local stats = pawn.AC_Stats
    if not valid(stats) then return CFG.dexLow end
    local out = {}
    local ok = pcall(function() stats["Get Stat Value"](stats, DEX, out) end)
    return (ok and type(out.Value) == "number") and out.Value or CFG.dexLow
end

local function hasPerk(pawn)
    local checks = StaticFindObject(CHECKS)
    if not valid(checks) then return false end
    local out = {}
    local ok = pcall(function() checks:QS_CheckPerk(PERK, pawn, out) end)
    return ok and out.Result == true
end

lockpicks = function()
    local pawn = playerPawn()
    local inv = pawn and pawn.AC_PlayerInventory or nil
    if not valid(inv) then return nil, nil, 0 end
    local item, qty = nil, 0
    inv.InventoryP3:ForEach(function(_, e)
        local s = e:get()
        if s[ITEM_ID]:ToString() == LOCKPICK then item, qty = s, s[ITEM_QTY] end
    end)
    return inv, item, qty
end

-- The game's own break (PickLockStatus 0 + CheckPickLockStatus) stops the minigame and hides the lock,
-- so the mod removes the lockpick itself, like the game: the last one ends the minigame and removes the stack.
local function breakLockpick(keylock)
    local inv, item, qty = lockpicks()
    play("broken", 1.5)
    local action = Policy.removeAction(qty)
    dbg("lockpick broke: %d left before, %s", qty, action)
    if action == "decrease" then
        pcall(function() inv["Remove Item Quantity"](inv, item, 1) end)
    elseif action == "remove" then
        pcall(function() keylock:ExitPickLock() end)
        pcall(function() inv["Remove Item from Inventory Array"](inv, item) end)
    end
end

local function springBack(keylock)
    pcall(function()
        local roll = keylock.TargetRotation.Roll
        keylock.TargetRotation = { Pitch = 0.0, Yaw = 0.0, Roll = math.floor(roll / 360 + 0.5) * 360.0 }
    end)
end

local function notify(listeners)
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, session)
        if not ok then log("listener error: %s", tostring(err)) end
    end
end

local function endSession()
    if session then notify(onSessionEnd) end
    session = nil
    disarm()
end

local function succeed(keylock)
    play("open")
    if session.kind == "door" then
        -- as the game's own door minigame does on success: OpenDoor(AfterPickLock = true) unlocks the door and
        -- swings it open; without it the door keeps its "Pick" prompt and can't be used (live 2026-10-26)
        local door = session.lock
        door.LockPickOpen = true
        keylock:ExitPickLock()
        if valid(door) then door:OpenDoor(true) end
    else
        keylock:Open()
        endSession() -- the chest is open now; switch it back before the pool saves its data
    end
end

local function onInteraction(kind)
    return function(ctx)
        disarm()
        local lock = ctx:get()
        if valid(lock) then arm(lock, kind) end
    end
end

local function onPickLock(kind)
    return function(ctx)
        local lock = ctx:get()
        if not (armed and valid(lock) and valid(armed.lock) and armed.lock:GetFullName() == lock:GetFullName()) then
            return
        end
        local keylock = newestKeylock()
        if not keylock then return end
        local key = lockKey(lock)
        policy:start(key, lock.LockPickDificulty)
        session = { lock = lock, kind = kind, key = key, keylock = keylock }
        dbg("start %s %s length %d", kind, key, #policy.seq)
        notify(onSessionStart)
    end
end

local function onAddRotation(ctx, dir)
    if not session then return end
    local keylock = ctx:get()
    local result = policy:press(dir:get())
    dbg("press %d -> %s (%d/%d)", dir:get(), result, policy.pos, #policy.seq)
    if result == "ok" then
        play("ok")
    elseif result == "wrong" then
        play("wrong", 1.5)
        springBack(keylock)
        local pawn = playerPawn()
        if pawn and math.random() < Policy.breakChance(dexterity(pawn), hasPerk(pawn), CFG) then
            breakLockpick(keylock)
        end
    elseif result == "open" then
        succeed(keylock)
    end
    if session then notify(onProgress) end
end

local hooked = {}
local function registerGameHooks()
    local hooks = {
        { DOOR .. ":Interaction", onInteraction("door") }, { CHEST .. ":Interaction", onInteraction("chest") },
        { DOOR .. ":PickLock", onPickLock("door") }, { CHEST .. ":PickLock", onPickLock("chest") },
        { KEYLOCK .. ":AddRotation", onAddRotation }, { KEYLOCK .. ":ExitPickLock", endSession },
    }
    for _, h in ipairs(hooks) do
        local path, fn = h[1], h[2]
        if not hooked[path] and valid(StaticFindObject(path)) then
            local ok, err = pcall(RegisterHook, path, function(...)
                local ok2, err2 = pcall(fn, ...)
                if not ok2 then log("%s: %s", path, tostring(err2)) end
            end)
            hooked[path] = ok
            if ok then dbg("hooked %s", path) else log("hook %s failed: %s", path, tostring(err)) end
        end
    end
end

onSessionStart[#onSessionStart + 1] = function(s)
    if s.kind == "door" then DoorView.show(s.keylock) end
end
onSessionEnd[#onSessionEnd + 1] = function() DoorView.clear() end

local function showStatus(s)
    local _, _, picks = lockpicks()
    local lines = { string.format("Lockpicks: %d", picks) }
    local pawn = playerPawn()
    if pawn and (CFG.progressWithoutPerk or hasPerk(pawn)) then
        local best = policy:progress(s.key)
        if #best > 0 then
            lines[2] = string.format("Best so far: %s  (%d of %d)", Display.directions(best, CFG.useArrows), #best,
                #policy.seq)
        end
    end
    Display.show(s.keylock, lines, CFG)
end
onSessionStart[#onSessionStart + 1] = showStatus
onProgress[#onProgress + 1] = showStatus
onSessionEnd[#onSessionEnd + 1] = function() Display.clear() end

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    session, armed = nil, nil
    pcall(restoreLeftovers)
    pcall(DoorView.clearLeftovers)
    registerGameHooks()
end)
registerGameHooks()
pcall(restoreLeftovers)
pcall(DoorView.clearLeftovers)

log("v%s loaded", VERSION)
