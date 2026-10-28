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
- Schlösser nur zwischen `Interaction` und `ExitPickLock` umstellen, nie im Voraus: `SetChestData` schreibt `isExtraLocked?` in die Pool- bzw. Speicherdaten (Befund + Review C1 in `docs/findings.md`).
- Den Bruch des Spiels (`CheckPickLockStatus`) nicht verwenden: Er hält das Minigame an und blendet das Schloss aus. Türen öffnen nur mit `OpenDoor(true)`, sonst bleibt der „Pick“-Prompt.
- Keine Spieldaten aus `../research/` in dieses Repo (öffentlich, sobald veröffentlicht).
- Pascal testet selbst im Spiel; Claude startet nichts und drückt keine Tasten.

## Status & Release

- **v1.0.0 (2026-10-26):** Live getestet auf dem Deck (P: „funktioniert jetzt super“): Tür, Truhe, Bruch, Esc + Neuansatz, Türansicht, Meister-Anzeige. Nicht live getestet: Bruch des **letzten** Dietrichs (`Remove Item from Inventory Array`).
- GitHub: `Gh05d/ash-and-steel-gothic-lockpicking` (öffentlich, `master`, MIT). Release per `./release.sh` (Tag aus `VERSION` in `main.lua`, Zip, GitHub-Release). `.github/workflows/nexus-upload.yml` lädt ab dem zweiten Release zu Nexus hoch: Dafür müssen das Secret `NEXUSMODS_API_KEY` und die Variable `NEXUSMODS_FILE_ID` gesetzt sein, und Pascal muss die Seite und die erste Datei von Hand angelegt haben. Der Lauf beim ersten Release scheitert absichtlich.
- Nexus: https://www.nexusmods.com/ofashandsteel/mods/61 (Mod-ID 61, numerisch `35897336660029`, Mod-File-ID **`8254908`** = Repo-Variable `NEXUSMODS_FILE_ID`, Secret gesetzt) → ab v1.0.1 lädt `./release.sh` automatisch hoch. IDs: `gh workflow run nexus-file-ids.yml -f mod=61`.
- Nexus-Texte: Beschreibung `docs/nexus-description.bbcode` (englisch), Bild-Prompts `docs/nexus-art-prompts.md`, Bilder per `scripts/make_nexus_images.py` aus `docs/art/`.
