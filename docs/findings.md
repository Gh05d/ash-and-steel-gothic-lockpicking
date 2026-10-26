# Befunde (Task 2)

Stand 2026-10-26. Belege: rekit-Befehle (Arbeitsordner `..`) und RekitBridge-Ausgaben aus dem laufenden Spiel.

## Klassen

- Alle Truhen erben von `BP_Chest_C` (`/Game/RPG_InventorySystem/Classes/Interactable/BP_Chest.BP_Chest_C`), alle Türen von `BP_Door_C`.
  - Live gezählt: ~60 Truhenklassen (u. a. `BP_Chest_C` 249×, `BP_Chest_Bag_C` 129×, `BP_CrystallLoot_C` 77×, `BP_Chest_Digged_C` 46×, dazu Quest-Truhen und Leichen wie `03_DeadBody_C`).
  - ~50 Türklassen (`BP_Door_C` 222×, `BP_Door_Child*`, `BP_Door_Port_C`, viele Quest-Türen).
- `PickLock` wird nur in `BP_Chest`/`BP_Door` aufgerufen (`ue refs PickLock --kind call`). Die Kinder überschreiben es nicht. Hooks auf `BP_Chest_C:PickLock`/`BP_Door_C:PickLock` greifen deshalb für alle Kinder.
- `FindAllOf('BP_Chest_C')` liefert **nur** genau diese Klasse, keine Kinder. Erfassen über `a:IsA(StaticFindObject(<Klassenpfad>))` auf `FindAllOf('Actor')`. Das ist teuer: Die Liste wird selten neu aufgebaut, der 2-s-Takt prüft nur noch die Entfernung.

## Felder

| | Truhe (`BP_Chest_C`) | Tür (`BP_Door_C`) |
|---|---|---|
| offen | `ChestOpen?` (und `ChestData.LockpickOpen`) | `LockPickOpen` |
| Schlüssel nötig | `KeyNeeded?` | `KeyNeeded?` |
| Code-Schloss | `isExtraLocked?`, `GS Chest Code` | `isExtraLocked?`, `GS Chest Code` |
| Schwierigkeit | `LockPickDificulty` (0/1/2) | `LockPickDificulty` |

Struct-Felder von `GS_Chest_Code` stehen in der Spec.

## Speicherverhalten

- **Truhen: Risiko bestätigt (statisch).** `SetChestData` schreibt `ChestQuest.isExtraLocked? := isExtraLocked?` und `ChestQuest.GSChestCode := GS Chest Code` in die Pool-Daten der Truhe (`ue bp BP_Chest func SetChestData`). Aufrufer: `UpdatePool` und der Ubergraph (`ue refs SetChestData --kind call`). Wenn das in den Spielstand geht, bleibt eine umgestellte Truhe nach Deinstallation ein unknackbares Code-Schloss mit Code 99.
  → Gegenmaßnahme (Ruling, siehe Ledger): Truhen werden **nicht** im Voraus umgestellt.
- Türen: `isExtraLocked?` wird nur in `PickLock` gelesen (`ue refs 'isExtraLocked?'`). Ob ein generisches Speichersystem (`ActorSaved`/`ComponentsToSave`) es trotzdem mitnimmt, ist live noch offen.

## Eingabe, Bruch, Erfolg

- Hook `LockPickExtraKey_C:AddRotation` (post): Parameter 1 = Richtung (0 links / 1 rechts), genau einmal pro Druck (A/D).
- **Bruch des Spiels nicht benutzen:** `PickLockStatus = 0` + `CheckPickLockStatus()` zieht zwar einen Dietrich ab. Danach ist das Minigame aber angehalten (`LockPickStarted = false`), die Kamera zurückgesetzt und das Schloss nicht mehr zu sehen (Screenshot P).
- **Eigener Bruch funktioniert:** `inv['Remove Item Quantity'](inv, item, 1)` mit `inv = FindFirstOf('AC_PlayerInventory_C')` und `item` = Stapel mit `ID_71_… == 'item_lockpick'` aus `inv.InventoryP3`. Live 10 → 9, das Minigame läuft weiter. Menge im Feld `Quantity_76_AD4B883E4427C3E60B4B22B072F4E7C9`.
  - Bei 0 übrig: `ExitPickLock()`. Ob „Remove Item Quantity“ bei Menge 1 den Stapel ganz entfernt, ist noch zu prüfen.
- Das Original würfelt den Perk selbst: `QuestSystem_Checks.QS_CheckPerk("Perk_11_Picklocked", self)` → `SelectFloat(0.5, 1)` → `RandomBoolWithWeight`. Abfrage für den Mod: `StaticFindObject('/Game/DialogsAndQuests/Quests/BP/QuestSystem_Checks.Default__QuestSystem_Checks_C')`, Aufruf live noch prüfen.
- Erfolg Tür: `door.LockPickOpen = true; extraKey:ExitPickLock()` → Tür offen (live ✔).
- Erfolg Truhe: offen (live ausstehend). `ExtraKey.Open` setzt `Current Chest.ChestOpen? = true` und `KeyNeeded? = false` und entfernt das UI.

## DEX

- Stat-Enum `E_StatCategory`: 13 = DEX (12 STR, 14 EDR, 15 IST, 16 FRT).
- Lesen: `FindFirstOf('AC_Stats_C').Stats` (TMap Byte → Float), Schlüssel 13. Pascals Charakter: DEX 20.
- Das Original nutzt DEX/25 als Verschleißfaktor. Obergrenze unbekannt → `dexLow = 10`, `dexHigh = 100` (Ruling).

## Töne

- Passt: Klick `Correct_Angle/a_gs_correct_angle_01`, Öffnen `Open_Closed/a_gs_Lockpick_Open_01`, Bruch `Lockpick_Break/a_gs_Lockpick_Break_01`.
- Als Fehlerton verworfen (P):
  - `a_gs_wrong_angle` (zu leise)
  - `a_gs_Lockpick_Closed_01` („klingt als würde die Tür aufgehen“)
  - `Danger_Zone_04/07/08/final_mix` („alle schlecht“)
- Nächste Kandidaten (Fehlschlag aus dem Taschendiebstahl-Minigame passt thematisch):
  - `Interaction/PickPocket/Pocket_FailSlot_01/02`
  - `Pocket_FailSlot_Critic_01..03`
  - `UI/Pickpocket/FailSlot/a_gs_FailSlot_01..03/_final_mix`
  - `FX/Cinematic/Skills/a_gs_UI_Need_gold/_need_teacher`

## Türansicht

- Werte stehen in der Spec. Aufräumen nur über eine eigene Liste gespawnter Actors und beim Verlassen (`ExitPickLock`), **nicht** bei `StopPickLock`, denn das ruft das Spiel auch zwischendurch.
- **Nie** Actors per Mesh-Name suchen und löschen: Dieselben Meshes stehen fest im Level. Das hat das Spiel am 2026-10-26 abstürzen lassen.
- Liegengebliebene Tür-Teile eines früheren Versuchs verdecken das Schloss beim nächsten Versuch (Screenshot P).

## Offen (live)

- Stabile Schloss-ID über einen Neustart: Level-Truhen heißen stabil (`BP_Chest_Bag23_13`, `BP_CrystallLoot52_45`). Türen haben Laufzeitnamen (`BP_Door_C_2147372808`, ändern sich). Vergleich der Position nach dem Neustart steht aus.
- Speichern einer umgestellten Tür, Truhen-Erfolgspfad, Truhenansicht, Decal, Fehlerton.

## Zeitpunkt des Umstellens (Idee, live zu prüfen)

- `BP_Chest`-Ubergraph: Vor `PickLock` liegen `StartFade(GS_S_FadeOut)` + `HideUI` (Block 1347) bzw. ein `Delay 2 s` (Block 9549 → 1113). Wenn `Interaction` (post-Hook) messbar vor `PickLock` feuert, kann der Mod das Schloss **erst bei der Interaktion** umstellen und beim Verlassen zurücksetzen. Dann gibt es kein Voraus-Umstellen und keine Spur im Spielstand. Prüfen: Trace-Hooks auf `BP_Chest_C:Interaction`, `BP_Door_C:Interaction` und `…:PickLock`, Zeitstempel vergleichen.
- Fallback: nur das Schloss im Interaktionsfokus des Spielers umstellen (kleines Zeitfenster), beim Fokuswechsel zurücksetzen.
