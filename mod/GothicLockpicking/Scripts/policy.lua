-- Gothic Lockpicking rules: pure Lua, no Unreal calls. Directions are 0 = left, 1 = right.
--
-- Every lock has a fixed combination computed from a stable key, so it is the same in every save and for
-- every player. A wrong input starts over. The best progress per lock is kept for the session.
local Policy = {}
Policy.__index = Policy

local MASK = 0xFFFFFFFF

-- FNV-1a, 32 bit.
function Policy.hash(s)
    local h = 0x811C9DC5
    for i = 1, #s do
        h = ((h ~ s:byte(i)) * 0x01000193) & MASK
    end
    return h
end

local function xorshift(x)
    x = (x ~ (x << 13)) & MASK
    x = x ~ (x >> 17)
    x = (x ~ (x << 5)) & MASK
    return x
end

function Policy.sequence(key, difficulty, cfg)
    local range = cfg.lengths[difficulty + 1] or cfg.lengths[#cfg.lengths]
    local x = Policy.hash(key)
    if x == 0 then x = 1 end
    x = xorshift(x)
    local len = range[1] + x % (range[2] - range[1] + 1)
    local seq = {}
    for i = 1, len do
        x = xorshift(x)
        seq[i] = (x >> 7) & 1
    end
    return seq
end

function Policy.breakChance(dex, hasPerk, cfg)
    local t = (dex - cfg.dexLow) / (cfg.dexHigh - cfg.dexLow)
    t = math.max(0, math.min(1, t))
    local c = cfg.breakMax + (cfg.breakMin - cfg.breakMax) * t
    if hasPerk then c = c * cfg.perkFactor end
    return c
end

-- Whether to switch a lock to the combination minigame. The game checks danger, skill and lockpicks before
-- its 2 s fade to PickLock and skips the checks for locks that are already "isExtraLocked?" - so a lock the
-- mod armed without a PickLock following would let the player pick it without skill or lockpicks, and would
-- end up in the save game. A lock the mod left armed earlier (s.ours) is taken over.
function Policy.mayArm(s)
    return s.enabled and s.open == false and not s.keyNeeded and (not s.extraLocked or s.ours)
        and not s.isBag and s.picks > 0 and s.hasSkill and s.noDanger
end

-- As the game's own minigame: the last lockpick removes the stack instead of leaving a stack of 0.
function Policy.removeAction(qty)
    if qty > 1 then return "decrease" end
    if qty == 1 then return "remove" end
    return "none"
end

function Policy.new(cfg)
    return setmetatable({ cfg = cfg, best = {}, difficulty = {}, pos = 0, done = false }, Policy)
end

function Policy:start(key, difficulty)
    self.key, self.seq, self.pos, self.done = key, Policy.sequence(key, difficulty, self.cfg), 0, false
    self.difficulty[key] = difficulty
end

-- Returns "ok", "wrong", "open" or "ignored" (no lock started, or already open).
function Policy:press(dir)
    if not self.seq or self.done then return "ignored" end
    if dir ~= self.seq[self.pos + 1] then
        self.pos = 0
        return "wrong"
    end
    self.pos = self.pos + 1
    if self.pos > (self.best[self.key] or 0) then self.best[self.key] = self.pos end
    if self.pos == #self.seq then
        self.done = true
        return "open"
    end
    return "ok"
end

-- The correct directions of the best attempt at this lock.
function Policy:progress(key)
    local n = self.best[key] or 0
    if n == 0 then return {} end
    local seq = Policy.sequence(key, self.difficulty[key], self.cfg)
    return { table.unpack(seq, 1, n) }
end

return Policy
