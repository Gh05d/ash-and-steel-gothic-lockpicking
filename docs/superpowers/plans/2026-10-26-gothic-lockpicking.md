# Gothic Lockpicking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein UE4SS-Lua-Mod für Of Ash and Steel. Er ersetzt das Dreh-Minigame bei Truhen und Türen durch Gothic-2-Schlossknacken: feste L/R-Folge pro Schloss, Neustart bei Fehler, Bruchchance, Fortschrittsanzeige für den Meister-Perk.

**Architecture:** Wie bei `fair-combat` gibt es drei Dateien:
- `policy.lua`: reine Logik ohne Unreal-Aufrufe (Folge aus Schlüssel, Eingabe-Zustand, Bruchchance, bester Fortschritt), getestet mit lupa.
- `main.lua`: Adapter mit Hooks, Scan, Tönen und Türansicht.
- `config.lua`: Nutzereinstellungen.

Ablauf im Adapter:
1. Er stellt Schlösser in der Nähe auf das Code-Schloss des Spiels um (`isExtraLocked?`, BP-Code unerreichbar).
2. Er führt die Folge selbst per Hook auf `LockPickExtraKey_C:AddRotation`.
3. Bei Erfolg öffnet er wie das Original.

**Tech Stack:** UE4SS v3.0.1-1181 (Lua 5.4) auf dem Deck. Tests mit Python 3 + `lupa==2.8` + `luaparser==4.2.0`. Asset-Recherche mit `rekit`, Live-Prüfung über RekitBridge.

**Spec:** `docs/superpowers/specs/2026-10-26-gothic-lockpicking-design.md`. Der Spike-Code liegt nur im Scratchpad. Die nötigen Werte daraus stehen in der Spec unter „Was der Spike gezeigt hat“.

## Global Constraints

- Längen: Easy 3–5, Normal 6–7, Hard 8–12. Höchstens 12.
- Folge immer gleich für dasselbe Schloss: in jedem Spielstand, bei jedem Spieler, nach Neustart. Der Mod speichert dafür nichts.
- Bruchchance: 50 % bei niedriger DEX, linear sinkend bis mindestens 10 %. Der Perk `Perk_11_Picklocked` halbiert sie. Alle Zahlen stehen in `config.lua`.
- Bruch zieht 1× `item_lockpick` ab. Danach geht es von vorn weiter, ohne Dietrich endet das Minigame.
- Meister-Perk zeigt die bisher korrekten Richtungen des besten Versuchs an diesem Schloss (z. B. `← ← → ←  (4 von 9)`). Gilt nur für die laufende Sitzung.
- Türen zeigen nie eine Truhe, das Dreh-Minigame kommt nie.
- `KeyNeeded? = true` und Schlösser, die schon im Original `isExtraLocked? = true` haben, bleiben unangetastet.
- Spielstände bleiben unangetastet. Nach einer Deinstallation sind alle Schlösser wieder normal.
- UE4SS-Regeln aus `../camp-everywhere/CLAUDE.md`:
  - kein `LoopAsync`/`ExecuteWithDelay`, nur `LoopInGameThreadWithDelay`/`ExecuteInGameThreadWithDelay`
  - keine Hooks auf häufig feuernde BP-Funktionen
  - Hooks über `ClientRestart` registrieren, plus ein direkter Versuch beim Laden (für Strg+R)
- Hooks auf BP-Funktionen laufen **nach** der Funktion.
- Struct-Felder von `GS_Chest_Code`:
  - `Direction_5_9BFD83684F973D41ED9946BCF058CFCD`
  - `CurrentNumber_14_F800B10F461076F5C6D12FAD2D7F3322`
  - `TargetNumber_15_E394EB464421F2E25D1F04964C1DEBD5`
  - `Status_11_6C83963B49D4242A071D2A8E479D608F`
- Nutzertexte (README, Anzeige im Spiel, Kommentare in `config.lua`) auf Englisch. Doku für Pascal (`CLAUDE.md`, `docs/findings.md`) auf Deutsch.
- Keine Spieldaten aus `../research/` ins Repo. Namen, Pfade und kurze Ausschnitte sind ok.
- Vor jeder Änderung im Spielordner fragen, ob Pascal spielt. Vor Live-Tests Spielstände sichern. Pascal testet selbst, Claude drückt keine Tasten.

## Review Focus

1. **Strg+R oder ein Deploy mitten im Minigame:** Danach muss das Schloss beim nächsten Versuch normal knackbar sein, und kein Schloss darf mit Code 99 hängen bleiben. → Test in Task 3 (Live-Schritt) plus Wiederherstellung über `armed`.
2. **Speichern, während Schlösser umgestellt sind,** und danach Laden ohne Mod: Die Schlösser müssen normal sein. → Task 2 klärt es, Task 3 setzt die Gegenmaßnahme um.
3. **Kein Dietrich mehr nach einem Bruch:** Das Minigame endet sauber, ohne negativen Bestand und ohne hängendes UI. → Task 3.
4. **Gepoolte oder neu gespawnte Truhen** (`gs_pool_*`, `ReInit`): Eine Truhe, die erst nach dem Scan auftaucht, darf beim ersten Versuch nicht das Dreh-Minigame zeigen. → Scan-Radius und Takt in Task 3, Live-Test an einer frisch nachgeladenen Truhe.
5. **Zwei Schlösser direkt nebeneinander** (Tür plus Truhe): Folge und Fortschritt dürfen sich nicht vermischen. → Policy-Test `test_keys_are_independent` in Task 1.

---

### Task 1: Repo-Gerüst und `policy.lua`

**Files:**
- Create: `mod/GothicLockpicking/enabled.txt` (leer), `mod/GothicLockpicking/Scripts/policy.lua`, `mod/GothicLockpicking/Scripts/config.lua`
- Create: `tests/run.sh`, `tests/requirements.txt`, `tests/__init__.py`, `tests/test_policy.py` (Muster: `../fair-combat/tests/`)
- Create: `.gitignore` (wie fair-combat, ohne `blocking.flag`), `CLAUDE.md` (Kurzfassung: Zweck, Aufbau, Regeln, Verweis auf Spec, Plan und Findings)

**Interfaces:**
- Produces (`policy.lua`, Modul-Tabelle `Policy`):
  - `Policy.hash(s: string) -> integer`: FNV-1a 32 Bit (`0x811C9DC5`, Prime `0x01000193`, `& 0xFFFFFFFF`).
  - `Policy.sequence(key: string, difficulty: integer 0|1|2, cfg) -> {integer...}`: Werte 0 = links, 1 = rechts. Zufall per xorshift32 aus `hash(key)`, Startwert 0 → 1. Länge `cfg.lengths[difficulty+1][1] .. [2]` inklusive. Unbekannte Schwierigkeit zählt wie Hard.
  - `Policy.breakChance(dex: number, hasPerk: boolean, cfg) -> number`: `cfg.breakMax` bei `dex <= cfg.dexLow`, `cfg.breakMin` bei `dex >= cfg.dexHigh`, dazwischen linear. Mit Perk mal `cfg.perkFactor`.
  - `Policy.new(cfg) -> p`
  - `p:start(key, difficulty)`: setzt `p.key`, `p.seq`, `p.pos = 0`, `p.done = false`.
  - `p:press(dir: integer) -> "ok"|"wrong"|"open"|"ignored"`: `"ignored"` nach `open` oder ohne `start`. Bei `"wrong"` gilt `pos = 0`. Höchstes `pos` je Schlüssel steht in `p.best[key]`.
  - `p:progress(key) -> {integer...}`: die ersten `p.best[key]` Werte von `sequence(key, …)` des zuletzt gestarteten Schwierigkeitsgrads dieses Schlüssels. Leere Tabelle, wenn unbekannt.
- `config.lua` gibt eine Tabelle zurück:
  - `lengths = {{3,5},{6,7},{8,12}}`
  - `breakMax = 0.5`, `breakMin = 0.1`, `perkFactor = 0.5`
  - `dexLow = 10`, `dexHigh = 100`: vorläufig, Task 2 setzt die echten Werte.
  - `scanRadius = 3000` (cm), `scanMs = 2000`
  - `doors = true`, `chests = true`, `debug = false`

- [ ] **Step 1: Failing tests in `tests/test_policy.py`** (Lader und Syntaxcheck wie fair-combat, `SCRIPTS = …/mod/GothicLockpicking/Scripts`, `cfg` aus `config.lua` geladen):
  - `test_lua_syntax`: alle `*.lua` parsen.
  - `test_hash_known_value`: `hash("")` ist `0x811C9DC5`, `hash("a")` ist `0xE40C292C`.
  - `test_sequence_deterministic`: `sequence("BP_Chest_C@1,2,3", 1, cfg)` liefert zweimal hintereinander dieselbe Liste.
  - `test_sequence_lengths`: Für 200 Schlüssel `"k"..i` liegen die Längen bei Schwierigkeit 0/1/2 jeweils in [3,5]/[6,7]/[8,12]. Jede Grenze kommt mindestens einmal vor, alle Werte sind 0 oder 1.
  - `test_unknown_difficulty_is_hard`: Länge bei 7 liegt in [8,12].
  - `test_press_flow`: `start`, alle Richtungen richtig → letzter Druck `"open"`, danach `"ignored"`.
  - `test_wrong_resets`: zwei richtige, ein falscher → `"wrong"`, `pos == 0`, `best == 2`. Danach wieder ab Position 1.
  - `test_best_is_max_not_last`: erst bis 4, dann Fehler bei 2 → `progress` hat 4 Einträge, und die sind gleich `seq[1..4]`.
  - `test_keys_are_independent`: Fortschritt an Schlüssel A ändert `progress(B)` nicht.
  - `test_break_chance`: dex 0 → 0.5; dex 100 → 0.1; dex 55 → 0.3; mit Perk dex 0 → 0.25.
- [ ] **Step 2:** `tests/run.sh` → FAIL (`policy` fehlt).
- [ ] **Step 3:** `policy.lua` und `config.lua` gemäß Interfaces schreiben. Bitoperationen mit Lua-5.4-Operatoren (`~`, `<<`, `>>`, `&`).
- [ ] **Step 4:** `tests/run.sh` → alle Tests OK.
- [ ] **Step 5:** Commit `Add policy: fixed sequences, reset on error, break chance`.

### Task 2: Offene Fragen live und statisch klären → `docs/findings.md`

Das ist Recherche, kein Mod-Code. Jede Antwort kommt mit Beleg (rekit-Befehl bzw. Bridge-Ausgabe) in `docs/findings.md`. Live-Schritte nur mit Pascal: Er sagt, wann er vor einem passenden Schloss steht, und speichert vorher.

**Interfaces:**
- Produces (in `docs/findings.md`, von Task 3–5 genutzt):
  - **Schlüssel-Regel** `lockKey(actor) -> string`: Welche Merkmale sind über Neustarts stabil? Live prüfen: dieselbe Truhe bzw. Tür vor und nach einem Spielneustart vergleichen (Klasse, gerundete `K2_GetActorLocation`, Pool-ID der Truhe). Ergebnis: das exakte Format, z. B. `"<Klassenname>@<x>,<y>,<z>"` auf 10 cm gerundet.
  - **Liste der Klassen**, die über `BP_Chest:PickLock` bzw. `BP_Door:PickLock` laufen: `ue refs PickLock --kind call`, Kinder von `BP_Chest`/`BP_Door` (`BP_Chest_Digged_C`, `BP_Chest_Bag_C`, `BP_CrystallLoot_C`, `BP_CageDoor_C`, `BP_Door_Child*`).
  - **Speicherverhalten:** Liest `gs_pool_chestdata`/`SetChestData`/`SaveToPool` `isExtraLocked?`/`GSChestCode` in die Speicherdaten (`ChestData`)? Speichern Türen `isExtraLocked?`? Statisch mit `ue bp BP_Chest func SaveToPool` usw. prüfen. Live: Schloss umstellen, speichern, Spiel ohne Mod-Aktivität neu laden (Strg+R reicht nicht; neu laden ohne Scan), Wert lesen. Ergebnis ist eine der beiden Varianten:
    - (a) wird nicht gespeichert → nichts zu tun
    - (b) wird gespeichert → Gegenmaßnahme, siehe Task 3, Schritt „Speicherschutz“.
  - **Erfolgspfad Truhe:** Reicht `ExtraKey:Open()` und danach `ExitPickLock()`, oder braucht es `ChestOpen?`/`LockpickOpen` an der Truhe? Live an einer Truhe testen. Dabei auch prüfen, ob das Original nach erfolgreichem Knacken XP vergibt oder `wasPickLocked?` setzt (`ue bp LockPickGrass func ExecuteUbergraph_LockPickGrass` um `LockPickOpen`). Was das Original tut, muss der Mod auch tun.
  - **DEX-Bereich:** Stat-Byte 13 per `AC_Stats` „Get Stat Value“. Startwert und Maximum im Spiel. Daraus `dexLow`/`dexHigh` für `config.lua`.
  - **Aufrufe:**
    - Perk-Abfrage: `QS_CheckPerk` mit `"Perk_11_Picklocked"`, Ziel und Signatur aus `ue bp LockPickExtraKey func ExecuteUbergraph_LockPickExtraKey`.
    - Dietrich abziehen: `AC_PlayerInventory` „Get Item by ID“ + „Remove Item Quantity“ mit `item_lockpick`, Parameterreihenfolge aus demselben Ubergraph.
  - **Anzeige-Ort für den Perk:** Was `LockPickWidgetKey` an Texten hat (`ue bp LockPickWidgetKey`). Notifications des Spiels (die Funktion, die `CampChecks` nutzt) als Alternative.
  - **Truhenansicht:** Sieht das Code-Schloss bei Wald- und Haus-Truhen (`Forest?`, `ChestType`) aus wie die Original-Truhenansicht (`LockPickGrass` mit `Door? = false`)? Screenshot von Pascal, beide Fälle.
  - **Decal der Türansicht:** Material, `DecalSize` und Transform von `LockPickGrass.Decal` live auslesen, solange das Original-Tür-Minigame offen ist (dazu einmal eine Tür nicht umstellen).
- [ ] **Step 1:** Statische Fragen per rekit beantworten, in `docs/findings.md` eintragen.
- [ ] **Step 2:** Live-Fragen mit Pascal klären (Schlüssel-Stabilität über Neustart, Speichern, Truhen-Erfolgspfad, Truhenansicht, Decal). Spiel-Backup vorher: `~/backups/oas-saves-<datum>.tar.gz` auf dem Deck.
- [ ] **Step 3:** `config.lua`: `dexLow`/`dexHigh` setzen. `tests/run.sh` muss weiter grün sein (der Test nimmt Werte aus der Config: `test_break_chance` auf `cfg.dexLow`/`cfg.dexHigh` umstellen, Erwartungen unverändert relativ zu beiden).
- [ ] **Step 4:** Commit `Add findings: lock keys, save behavior, success paths`.

### Task 3: Adapter `main.lua`: Umstellen, Folge, Bruch, Öffnen

**Files:**
- Create: `mod/GothicLockpicking/Scripts/main.lua` (`local VERSION = "0.1.0"`)
- Create: `scripts/deploy-deck.sh`, Kopie von `../fair-combat/scripts/deploy-deck.sh` mit Modname `GothicLockpicking`.

**Interfaces:**
- Consumes: `Policy.*` aus Task 1, alle Antworten aus `docs/findings.md` (Task 2).
- Produces (lokale Funktionen in `main.lua`, von Task 4/5 genutzt):
  - `armed: table<actorFullName, {actor, extra=bool, code=snapshot}>`
  - `session = {lock=actor, kind="door"|"chest", key=string, widget=ExtraKey|nil}`
  - `onSessionStart(lockActor, kind)`
  - `onSessionEnd()`

- [ ] **Step 1: Scan.** Alle `cfg.scanMs` per `LoopInGameThreadWithDelay`:
  - Schlösser im `scanRadius` um den Spieler aus den Klassen von Task 2 werden umgestellt.
  - Bedingung: `LockPickOpen`/`LockpickOpen == false`, `KeyNeeded? == false`, Original-`isExtraLocked? == false`.
  - Umstellen heißt `isExtraLocked? = true` und `GS Chest Code` = 4 Einträge mit `TargetNumber = 99` und abwechselnder Richtung.
  - Vorher den Originalzustand in `armed` sichern. Was den Radius verlässt, wird auf den gesicherten Zustand zurückgesetzt.
- [ ] **Step 2: Session.**
  - Post-Hooks auf `BP_Chest_C:PickLock` und `BP_Door_C:PickLock` → `onSessionStart`: `key = lockKey(actor)` gemäß Findings, `policy:start(key, LockPickDificulty)`.
  - Hook auf `LockPickExtraKey_C:StopPickLock` → `onSessionEnd`.
  - Nur Schlösser aus `armed` starten eine Session.
- [ ] **Step 3: Eingabe.** Hook auf `LockPickExtraKey_C:AddRotation` (post, `dir = param1:get()`):
  - `"ok"` → Ton `a_gs_correct_angle_01`.
  - `"wrong"`:
    - lauter Fehlerton (Kandidat `a_gs_Lockpick_Closed_01`, Pascal entscheidet beim Live-Test)
    - `TargetRotation.Roll` auf das nächste Vielfache von 360 setzen
    - Bruch würfeln mit `breakChance(dex, perk)`. Bei Bruch Ton `a_gs_Lockpick_Break_01`, 1× `item_lockpick` abziehen, ohne Bestand `ExitPickLock()`.
  - `"open"` → Ton `a_gs_Lockpick_Open_01`, Erfolgspfad gemäß Findings (Tür: `LockPickOpen = true` + `ExitPickLock()`), danach `armed`-Eintrag entfernen. Das Schloss ist jetzt offen.
  - Töne per `Default__GameplayStatics:PlaySound2D` (siehe Spike).
- [ ] **Step 4: Strg+R und Deinstallation.**
  - Beim Laden des Scripts und bei `ClientRestart` alle `BP_Chest_C`/`BP_Door_C` mit unserem Marker zurücksetzen: Code 4× `TargetNumber = 99` und `isExtraLocked? = true`, kein `KeyNeeded?`. Zurück heißt `isExtraLocked? = false`, Code leer. Dann neu scannen.
  - Zeigt Task 2 (Variante b), dass das gespeichert wird: **Speicherschutz**. Vor dem Speichern (Hook auf die Speicherfunktion aus den Findings, feuert selten) alle `armed` zurücksetzen und danach neu scannen.
- [ ] **Step 5:** `tests/run.sh` grün (Syntax).
- [ ] **Step 6: Live mit Pascal** (Deploy: `scripts/deploy-deck.sh`, dann Strg+R):
  - Tür und Truhe je einmal öffnen.
  - Fehler setzt zurück, mit Ton und Zurückspringen.
  - Einen Bruch erzwingen (`breakMin = breakMax = 1.0` in der Deploy-Kopie) und ohne Dietrich enden.
  - Strg+R mitten im Minigame → danach normal knackbar.
  - Folge nach Spielneustart gleich.
- [ ] **Step 7:** Commit `Add adapter: arm locks, run sequences, break picks, open locks`.

### Task 4: Türansicht

**Files:**
- Modify: `mod/GothicLockpicking/Scripts/main.lua`. Eigener Abschnitt, oder `doorview.lua`, wenn `main.lua` über ~400 Zeilen wächst.

**Interfaces:**
- Consumes: `onSessionStart`/`onSessionEnd` (Task 3), Decal-Werte aus `docs/findings.md`.
- Produces: `decorateDoor(extraKey)`, `clearDoor()`.

- [ ] **Step 1:** `decorateDoor` (Werte aus der Spec, Abschnitt Spike):
  - Komponenten ausblenden: `SkeletalMesh`, `Ground`, `Bush`…`Bush9`, `Grass`, `Grass1`, `Floor`…`Floor6`.
  - `StaticMeshActor`s anhängen: Tür, Wand, 3 Balken.
  - Decal gemäß Findings dazu.
  - Aufruf bei `kind == "door"`, `clearDoor` in `onSessionEnd`.
- [ ] **Step 2:** Live: Pascal vergleicht per Screenshot mit der Original-Türansicht (Boden jetzt sichtbar).
- [ ] **Step 3:** Commit `Add door view`.

### Task 5: Meister-Anzeige

**Files:**
- Modify: `mod/GothicLockpicking/Scripts/main.lua`

**Interfaces:**
- Consumes: `policy:progress(key)` (Task 1), Perk-Abfrage und Anzeige-Ort aus `docs/findings.md`.
- Produces: `showProgress()`, aufgerufen bei `onSessionStart` und nach jedem `"ok"`/`"wrong"`.

- [ ] **Step 1:** Nur mit Perk `Perk_11_Picklocked` den Text `"Best so far: ← ← → ←  (4 of 9)"` zeigen (Pfeile `←`/`→`, englisch). Prüfen, ob der Spiel-Font `←`/`→` darstellt. Wenn nicht, `L`/`R` nehmen.
- [ ] **Step 2:** Live: mit und ohne Perk. Ohne Perk keine Anzeige. Mit Perk wächst die Anzeige nur bei neuem Bestwert.
- [ ] **Step 3:** Commit `Add master lockpicker progress display`.

### Task 6: Paket und Doku

**Files:**
- Create: `scripts/package.py` (Kopie von fair-combat, Name `GothicLockpicking`), `mod/GothicLockpicking/README.txt` (englisch: was der Mod tut, Installation, Config, Deinstallation), `LICENSE` (MIT wie camp-everywhere)
- Modify: `CLAUDE.md` (Status, Befunde-Verweis)

- [ ] **Step 1:** `python3 scripts/package.py` → `dist/GothicLockpicking-0.1.0.zip`. Bricht ab, wenn `debug = true`.
- [ ] **Step 2:** `tests/run.sh` grün.
- [ ] **Step 3:** Commit `Add packaging and README`. GitHub-Repo, Nexus-Seite und Release erst nach Pascals Freigabe, mit eigener Rückfrage.
