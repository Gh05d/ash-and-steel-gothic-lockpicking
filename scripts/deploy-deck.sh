#!/bin/bash
# Kopiert den Mod (mod/GothicLockpicking) aufs Steam Deck. Danach im Spiel Strg+R (Hot-Reload).
# PROGRESS=1 zeigt den Meister-Fortschritt auch ohne Perk (zum Testen).
# Standardmäßig mit Debug-Log (jede Entscheidung in ue4ss/UE4SS.log); DEBUG=0 deployt genau die Release-Fassung.
# Voraussetzung: UE4SS ist im Spiel installiert (siehe ../camp-everywhere/CLAUDE.md).
set -e
cd "$(dirname "$0")/.."
W=/run/media/mmcblk0p1/steamapps/common/ofAshAndSteel/ofAshAndSteelGame/Binaries/Win64/ue4ss/Mods
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cp -r mod/GothicLockpicking "$T/"
[ "${DEBUG:-1}" = 1 ] && sed -i "s/^\(    debug = \)false/\1true/" "$T/GothicLockpicking/Scripts/config.lua"
[ "${PROGRESS:-0}" = 1 ] && sed -i "s/^\(    progressWithoutPerk = \)false/\1true/" "$T/GothicLockpicking/Scripts/config.lua"
grep -m1 "^    debug = " "$T/GothicLockpicking/Scripts/config.lua"
grep -m1 "^    progressWithoutPerk = " "$T/GothicLockpicking/Scripts/config.lua"
tar czf - -C "$T" GothicLockpicking | ssh -i "$HOME/.ssh/deck_citadel" -o IdentitiesOnly=yes -o BatchMode=yes deck-direct \
  "tar xzf - -C $W && ls -la $W/GothicLockpicking/Scripts"
