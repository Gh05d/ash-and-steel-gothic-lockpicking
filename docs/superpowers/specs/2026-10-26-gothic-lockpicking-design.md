# Gothic Lockpicking – Design

Mod für Of Ash and Steel (UE 4.27, UE4SS-Lua wie `camp-everywhere` und `fair-combat`).
Legende: **(P)** = Pascal hat es so gesagt · **(C)** = Claudes Entscheidung, Pascal kann sie kippen.

## Warum

Pascal will das Schlossknacken aus Gothic 2 zurück (P). In OaS dreht man den Dietrich nach Gefühl: Leertaste halten, mit A/D die richtige Stelle suchen, Gefahrenzone, Verschleiß. Gothic 2 funktioniert anders. Jedes Schloss hat eine **feste Folge aus links/rechts**. Das Spiel besteht darin, sich die Folge zu merken und genug Dietriche dabeizuhaben.

## Ziele

1. **Feste Kombination pro Schloss (P).** Jede verschlossene Truhe und Tür hat eine L/R-Folge, die immer gleich ist (P): bei jedem Versuch, nach einem Neustart, in jedem Spielstand und bei jedem Spieler, wie in Gothic 2. Die Folge wird also aus festen Merkmalen des Schlosses berechnet, und der Mod speichert dafür nichts.
2. **Länge nach Schwierigkeit (P):** Easy 3–5 (C), Normal 6–7 (P), Hard 8–12 (P; Maximum 12). Grundlage ist das vorhandene Feld `LockPickDificulty` (Easy/Normal/Hard) an `BP_Chest`/`BP_Door`.
3. **Falsche Eingabe (P):**
   - Die Folge beginnt von vorn, wie in Gothic 2 (P).
   - Das Schloss springt sichtbar zurück (P).
   - Es kommt ein deutlich hörbarer Fehlerton (P: `a_gs_wrong_angle` geht neben dem Drehgeräusch unter). Welcher Ton es wird, entscheidet der Builder.
   - Der Dietrich bricht mit einer gewissen Chance (P).
4. **Bruchchance (C, nicht widersprochen):**
   - 50 % bei niedriger DEX, mit steigender DEX linear sinkend bis mindestens 10 %.
   - Der Perk „Meister-Schlossknacker“ halbiert die Chance (das macht der Perk schon heute).
   - Alle Zahlen stehen in `config.lua`.
   - Bricht der Dietrich, wird 1× `item_lockpick` abgezogen. Liegt noch einer im Inventar, geht es von vorn weiter, sonst endet das Minigame (C).
5. **Meister-Schlossknacker = Fortschrittsanzeige (C, von P angenommen):** Mit dem Perk (`ui_perk_10`, intern `Perk_11_Picklocked`) zeigt das Minigame an genau diesem Schloss die **bisher korrekt eingegebenen Richtungen** (P), z. B. `← ← → ←  (4 von 9)`.
   - Es zählt der beste Versuch an diesem Schloss, nicht der letzte (C).
   - Weil die Folge fest ist, entsprechen die angezeigten Richtungen genau dem Anfang der Folge bis zur weitesten Position.
   - Es gibt keine Checkpoints. Die Folge muss jedes Mal komplett eingegeben werden (P: Checkpoints lohnen erst bei viel längeren Folgen).
   - Die Anzeige muss nicht über dem Kopf sein (P). Ort und Form entscheidet der Builder, sie muss aber im Minigame lesbar sein.
   - Der Fortschritt gilt nur für die laufende Spielsitzung (C).
6. **Richtige Eingabe:** hörbarer Klick, das Schloss dreht ein Stück weiter (das macht das Spiel selbst).
7. **Folge komplett:** Ton fürs Öffnen. Das Minigame schließt, und die Truhe bzw. Tür ist offen, genau wie nach erfolgreichem Knacken im Original.
8. **Ansicht:**
   - Truhen zeigen die Truhenansicht.
   - **Türen zeigen eine Tür**, nie eine Truhe (P). Das normale Dreh-Minigame kommt nie (P).
   - Die nachgebaute Türansicht aus dem Spike war „sehr gut“ (P). Es fehlt nur noch das Boden-Decal.
9. **Bedienung:** A/D (Tastatur, P spielt mit Maus und Tastatur) und was das Code-Schloss auf dem Gamepad sonst nutzt. Esc bricht ab.

## Nicht-Ziele

- Kein neuer Skill und kein Training. Freischalten bleibt der Skill „Schlösser knacken“ (`ui_survival_06`).
- Keine Checkpoints.
- Schlösser, die einen Schlüssel brauchen (`KeyNeeded?`), und Schlösser, die schon im Original ein Code-Schloss sind (`isExtraLocked?` mit eigenem Code, z. B. Quest-Truhen), bleiben genau wie im Original (C).
- Kein Umbau der Blueprints per Pak, solange Lua reicht.

## Anti-Ziele

- Spielstände dürfen nicht kaputtgehen. Nach dem Deinstallieren müssen alle Schlösser wieder normal sein. Falls `isExtraLocked?`/`GSChestCode` in die Speicherdaten der Truhen (`ChestData`, `gs_pool_chestdata`) wandern, muss der Mod das verhindern oder es beim Laden rückgängig machen. Das ist ungeprüft.
- Keine Abstürze: Die UE4SS-Regeln aus `camp-everywhere/CLAUDE.md` gelten.
- Ein Schloss darf nie unöffenbar werden, auch nicht nach Strg+R mitten im Minigame.

## Was der Spike (2026-10-26, live an einer Tür) gezeigt hat

Spike-Code (Wegwerf): Scratchpad `spike_door.lua`. Gelaufen ist er über RekitBridge.

- `BP_Chest`/`BP_Door.PickLock` spawnt bei `isExtraLocked? = true` das Code-Schloss `LockPickExtraKey` und gibt `GS Chest Code` (4 Blöcke Richtung/Anzahl) mit. Sonst kommt das Dreh-Minigame `LockPickGrass`, das je nach `Door?` als Truhen- oder Türansicht erscheint.
- **Das Code-Schloss allein reicht nicht:** Index 0–3 ist hart verdrahtet (höchstens 3 Richtungswechsel). Fehler im ersten Block ignoriert es still. `Open` setzt nur `ChestOpen?` und öffnet deshalb keine Türen.
- **Was funktioniert hat:**
  - Den BP-Code auf 4× `TargetNumber = 99` setzen, damit das BP nie selbst öffnet oder scheitert.
  - Die Folge selbst führen per Hook auf `LockPickExtraKey_C:AddRotation` (post, Parameter 1: 0 = links, 1 = rechts, feuert genau einmal pro Druck).
  - Bei Fehler `TargetRotation.Roll` auf das nächste Vielfache von 360 setzen. Dann dreht das Schloss sichtbar zurück.
  - Bei Erfolg an der Tür `LockPickOpen = true` setzen und danach `ExtraKey:ExitPickLock()` aufrufen. Die Tür war offen (P).
  - **Für Truhen ungetestet:** vermutlich `Open` oder `ChestOpen?` plus `ExitPickLock`.
- **Türansicht:** Hook auf `BP_Door_C:PickLock` (post).
  - Am ExtraKey werden `SkeletalMesh`, `Ground`, `Bush*`, `Grass*`, `Floor*` ausgeblendet.
  - Daran hängen `StaticMeshActor`s, die Transformationen sind live aus `LockPickGrass` mit `Door?=true` gelesen:
    - Tür `m_gs_carpets_door_01`: rel(-6.1, -97.1, 74.1), Yaw 90
    - Wand `m_gs_village_01_wall_08`: rel(-6.1, -50.3, -92.3), Yaw 90, Scale X 1.115
    - 3× `m_gs_WoodPack_01_beam_02` (Werte im Spike-Code)
  - Es fehlt die Decal-Komponente `Decal` (Boden), rel(-6.1, 135.5, 13.1).
  - Aufräumen per Hook auf `StopPickLock`.
- Struct-Felder von `GS_Chest_Code` brauchen die GUID-Namen (`rekit --raw ue defaults BP_Chest`).
- Strg+R oder ein Deploy löscht den Lua-Zustand und die Hooks. Danach muss der Mod sich selbst wieder scharf schalten.

## Vom Builder zu klären bzw. zu entscheiden

- **Stabile ID pro Schloss** als Saat für die Folge. Laufzeit-Namen wie `BP_Door_C_2147372808` ändern sich nach einem Neustart. Kandidaten sind die gerundete Weltposition plus Klasse oder die Pool-ID der Truhen (`gs_pool_setuniqueid`).
- **Wann `isExtraLocked?` gesetzt wird:** Hooks laufen erst nach der Funktion, also muss es vor `PickLock` passieren. Die Truhen werden gepoolt (`gs_pool_*`, `ReInit`). Ein Spike-Ansatz war, alle 2 s im Spiel-Thread Schlösser in der Nähe umzustellen.
- Mögliche Truhenarten:
  - `BP_Chest`-Kinder: Digged, Bag, Quest-Truhen
  - `BP_CrystallLoot`
  - Tür-Kinder: `BP_Door_Child*`, `BP_CageDoor`

  Welche davon tatsächlich über `PickLock` laufen, ist zu ermitteln.
- DEX-Wertebereich (Stat-Byte 13, das Original nutzt DEX/25) für die Bruchformel.
- Fehlerton, Bruch-Rückmeldung (Ton `a_gs_Lockpick_Break_01`?), Form der Fortschrittsanzeige.
- Ob Truhen im Code-Schloss genau wie die Original-Truhenansicht aussehen (Wald- oder Haus-Hintergrund über `Forest?`/`ChestType`) oder auch einen Nachbau brauchen.

## Rahmen

- Eigenes Repo `ash-and-steel-mods/gothic-lockpicking` (Arbeitsname, C), Aufbau wie `fair-combat`: `main.lua` (Adapter), `policy.lua` (reine Logik, testbar mit `tests/run.sh`), `config.lua`.
- Release auf Nexus, englische Texte, Ablauf wie bei Camp Everywhere (C, Annahme nach Pascals bisherigen Mods).
