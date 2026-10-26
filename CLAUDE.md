# Gothic Lockpicking – Mod für Of Ash and Steel

Pascals Mod: Schlossknacken wie in Gothic 2. Jedes Schloss hat eine feste Links/Rechts-Folge. Eine falsche Eingabe startet die Folge neu, und der Dietrich kann dabei brechen. Der Perk „Meister-Schlossknacker“ zeigt die bisher richtigen Richtungen an.

- **Design (freigegeben 2026-10-26):** `docs/superpowers/specs/2026-10-26-gothic-lockpicking-design.md`. Was dort mit (P) markiert ist, hat Pascal gesagt; (C) ist Claudes Entscheidung.
- **Plan:** `docs/superpowers/plans/2026-10-26-gothic-lockpicking.md`. Fortschritt im git-ignorierten Ledger `.superpowers/sdd/…/progress.md`.
- **Befunde:** `docs/findings.md` (stabile Schloss-ID, Speicherverhalten, Erfolgspfade, Aufrufe).

## Aufbau

- `mod/GothicLockpicking/Scripts/main.lua`: UE4SS-Adapter. Er stellt Schlösser auf das Code-Schloss `LockPickExtraKey` um, hängt sich mit Hooks ein, spielt Töne und baut die Türansicht. `VERSION` steht hier.
- `mod/GothicLockpicking/Scripts/policy.lua`: reine Regelmaschine ohne Unreal-Aufrufe. Sie berechnet die Folge aus einem Schlüssel (FNV-1a + xorshift32), verwaltet die Eingaben, die Bruchchance und den besten Fortschritt.
- `mod/GothicLockpicking/Scripts/config.lua`: Einstellungen für Nutzer (englisch kommentiert).
- Tests: `tests/run.sh` (lupa = echtes Lua 5.4, luaparser für die Syntax).
- Aufs Deck: `scripts/deploy-deck.sh` (schaltet `debug` ein; `DEBUG=0` = Release-Fassung), danach im Spiel Strg+R.

## Regeln

- UE4SS-, Deck- und Release-Regeln wie in `../camp-everywhere/CLAUDE.md` und `../fair-combat/CLAUDE.md`.
- Hooks auf BP-Funktionen laufen erst nach der Funktion.
- Strg+R und Deploys löschen den Lua-Zustand. Der Mod muss sich danach selbst wieder scharf schalten und hängengebliebene Schlösser zurücksetzen.
- Keine Spieldaten aus `../research/` in dieses Repo (öffentlich, sobald veröffentlicht).
- Pascal testet selbst im Spiel; Claude startet nichts und drückt keine Tasten.
