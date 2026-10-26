Gothic Lockpicking for Of Ash and Steel (UE4SS Lua mod)

Lockpicking as in Gothic 2. Every locked chest and door has a fixed left/right combination:
- Easy locks 3-5 inputs, normal locks 6-7, hard locks 8-12.
- The combination never changes: same lock, same combination, in every save.
- A wrong input starts over, and your lockpick may break. Higher dexterity means fewer broken lockpicks,
  the Master Lockpicker perk halves the chance.
- With the Master Lockpicker perk the lockpicking screen shows the correct directions of your best attempt
  at that lock.
- Doors show a door, chests show a chest. Locks that need a key and the game's own combination locks
  are not changed.

Controls: A / D (turn left / right), Esc to stop.

Settings: Scripts/config.lua (combination lengths, break chance, text position, ...).

Requires UE4SS (experimental build) in ofAshAndSteelGame/Binaries/Win64/.
Install: extract into the game folder (ofAshAndSteel/), so the mod ends up in
ofAshAndSteelGame/Binaries/Win64/ue4ss/Mods/GothicLockpicking/.
Uninstall: delete that folder. The mod never writes to your save games.
