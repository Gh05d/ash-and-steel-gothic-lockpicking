-- Gothic Lockpicking settings.
return {
    -- Length of the left/right combination per lock difficulty (Easy, Normal, Hard): {min, max} inputs.
    lengths = { { 3, 5 }, { 6, 7 }, { 8, 12 } },

    -- Chance that a wrong input breaks the lockpick. breakMax at dexterity dexLow or below, breakMin at
    -- dexHigh or above, linear in between. The Master Lockpicker perk multiplies it by perkFactor.
    breakMax = 0.5,
    breakMin = 0.1,
    dexLow = 10,
    dexHigh = 100,
    perkFactor = 0.5,

    -- Which locks get combinations.
    doors = true,
    chests = true,

    scanRadius = 3000, -- locks within this distance (cm) of the player are prepared
    scanMs = 2000,     -- how often (ms)
    debug = false,     -- log every decision to UE4SS.log
}
