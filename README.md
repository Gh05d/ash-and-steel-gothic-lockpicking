# Gothic Lockpicking

A UE4SS mod for **Of Ash and Steel** that brings back lockpicking as in Gothic 2: every lock has a fixed left/right combination, a wrong turn starts over and may break your lockpick.

Download: [Nexus Mods](https://www.nexusmods.com/ofashandsteel/mods/61) or the [GitHub releases](https://github.com/Gh05d/ash-and-steel-gothic-lockpicking/releases).

## How it works

- Every locked chest and door gets a fixed combination of left and right turns (A / D). Easy locks have 3–5 turns, normal locks 6–7, hard locks 8–12.
- The combination never changes: the same lock has the same combination in every save game.
- A right turn clicks and the lock turns further. A wrong turn makes the lock snap back to the start, and your lockpick may break. Higher dexterity means fewer broken lockpicks.
- The **Master Lockpicker** perk halves the break chance and shows the correct turns of your best attempt at that lock, e.g. `← ← → ←  (4 of 9)`.
- The lockpicking screen shows how many lockpicks you have left.
- Doors show a door, chests show a chest. Locks that need a key and the game's own combination locks stay as they are.

The mod uses the game's own combination-lock minigame, sounds and lockpicks. It switches a lock only while you pick it, so your save games stay clean.

## Installation

1. Install [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) (experimental build, tested with v3.0.1-1181): `dwmapi.dll` and the `ue4ss` folder go into `ofAshAndSteel/ofAshAndSteelGame/Binaries/Win64/`.
2. Extract the release zip into the game folder `ofAshAndSteel/`. The mod ends up in `ofAshAndSteelGame/Binaries/Win64/ue4ss/Mods/GothicLockpicking/`.
3. Steam Deck / Linux (Proton): add `WINEDLLOVERRIDES="dwmapi=n,b" %command%` to the game's launch options.

Settings (combination lengths, break chance, text position) are in `Scripts/config.lua`.

## Development

- `tests/run.sh` runs the Lua tests (`policy.lua`, `display.lua`, syntax of all scripts).
- `scripts/deploy-deck.sh` copies the mod to the Steam Deck (with debug log on; `DEBUG=0` for the release build, `PROGRESS=1` shows the perk display without the perk). Reload in game with Ctrl+R.
- `scripts/package.py` builds `dist/GothicLockpicking-<version>.zip`; `./release.sh` tags, creates the GitHub release and triggers the Nexus upload.

## License

MIT
