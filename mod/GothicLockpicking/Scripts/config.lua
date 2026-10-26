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

    -- Text in the lockpicking screen: lockpicks left and, with the Master Lockpicker perk, the correct
    -- directions of your best attempt at this lock. Position in pixels from the top left corner.
    textX = 80,
    textY = 80,
    textSize = 24,
    useArrows = true, -- false shows L/R instead of arrows
    progressWithoutPerk = false, -- true shows your best attempt even without the perk
    debug = false,     -- log every decision to UE4SS.log
}
