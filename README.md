# Nočná škola

Godot 4 first-person horor zo slovenskej školy. Hráč sa môže voľne pohybovať medzi siedmimi predmetovými učebňami, otvárať dvere, riešiť domáce úlohy a utekať pred učiteľom príslušného predmetu. Kabinet je iba pre učiteľov.

## Aktuálny obsah

- Slovenské hlavné menu, výber noci, načítanie, HUD, obrazovka úloh a dokončenie noci
- Celá školská chodba so siedmimi učebňami: Dejepis, Matematika, Slovenský jazyk, Elektrotechnika, Ekonomika, Aplikovaná informatika a Anglický jazyk
- Zamknutý kabinet so siedmimi konfigurovateľnými učiteľmi a riaditeľkou Zuzanou Čižmárikovou; hráč ho neotvorí ani nevojde za nimi
- Osem dátovo riadených nocí, spoločný školský čas, analógové a digitálne hodiny
- Pohyb z prvej osoby, otáčanie myšou, šprint, výdrž, drep, skok a interakcia
- Osem presne osadených interiérových dverí a ranný východ na konci chodby
- Tri sady úloh v každej učebni, spolu 21 sád za noc
- Nesprávna odpoveď vypne školské svetlá, spustí naháňačku a zablokuje danú úlohu na 30 sekúnd
- Ostatní aktívni učitelia pri spozorovaní hráča spustia sirénu a odovzdajú jeho polohu prenasledovateľovi
- Navigačný mesh školy, kolízny nábytok, hliadkovanie, prenasledovanie, hľadanie a únik
- Schovanie pod každou zo 42 žiackych lavíc; učiteľ hráča pod lavicou nevidí a začne prehľadávať školu
- Plnohodnotná pauza cez `Esc` s okamžitým nastavením jasu/gammy, pokračovaním a návratom do hlavného menu
- Vymeniteľná hudba menu, školský ambient a priestorové kroky učiteľov s procedurálnymi náhradami
- Noc 1 trvá 10 reálnych minút; ráno sa odomkne východ, ktorým sa dokončí level
- Verziovaný JSON save systém a odomykanie nocí
- Učiteľské modely, animácie a parametre sú v `TeacherData`; modely nie sú zakódované v AI
- Celoplošný jumpscare s voliteľným obrázkom/zvukom učiteľa a automatickým reštartom rovnakej noci

Zatiaľ nie sú hotové: finálny autorský zvukový obsah, chase hudba, úvodná detention sekvencia a ručne vytvorené 3D modely. Učitelia, hudba, ambient, kroky a jumpscare používajú v prípade nepriradeného súboru procedurálne náhrady.

## Štruktúra projektu

```text
res://
|- assets/                         importované modely, textúry a obrázky
|- audio/                          vlastná hudba a zvuky na import
|- characters/
|  |- clocks/                      spoločné analógové a digitálne hodiny
|  |- teachers/                    pohyblivý TeacherData-driven učiteľ
|  `- player.tscn                  FPS hráč, HUD a obrazovka úloh
|- data/
|  |- homework/                    7 predmetov, každý s 3 otázkami
|  |- nights/                      NightData pre noci 1 až 8
|  |- teachers/                    7 učiteľov a TeacherData riaditeľky
|  `- audio/                       centrálna GameAudioData konfigurácia
|- enemies/                        miesto pre zdedené scény importovaných postáv
|- levels/                         škola a opakovateľné objekty
|- scripts/                        level, UI a automatické validátory
|- systems/
|  |- audio/                       menu, ambient a náhradné kroky
|  |- night/                       NightData, SchoolTime a NightManager
|  |- save/                        SaveManager
|  |- homework/                    interaktívna stanica úloh
|  |- hiding/                      schovanie pod lavicami
|  `- school_game_manager.gd       úlohy, výpadok, naháňačka a sirény
|- ui/                             všetky herné obrazovky
|- shaders/                        shader hlavného menu
|- main.tscn                       vstupná scéna
`- project.godot                   nastavenia, vstupy a autoloady
```

## Ovládanie

| Akcia | Kláves |
|---|---|
| Pohyb | `W`, `A`, `S`, `D` |
| Rozhliadanie a otáčanie | myš |
| Šprint | ľavý `Shift` |
| Drep / fyzické schovanie pod lavicu | podržať `C` a vojsť pod lavicu |
| Skok | `Space` |
| Otvoriť alebo zatvoriť dvere / domáca úloha | `E` |
| Pozastaviť hru / zavrieť pauzu | `Esc` |
| Dokončiť noc (iba debug build) | `F8` |

## Spustenie

```powershell
C:\Users\matej\Downloads\godot.exe --path . --editor
```

Stlač `F5`; projekt spustí `main.tscn`. Hlavná scéna aj autoloady `AudioManager`, `SaveManager`, `NightManager` a `SchoolGameManager` sú už nastavené.

## Herný priebeh

V každej učebni je na učiteľskom stole zošit. Interakcia otvorí nasledujúcu z troch sád daného predmetu. Správna odpoveď započíta postup aktuálne spustenej noci. Dokončenie všetkých 21 sád už noc neukončí predčasne.

Nesprávna odpoveď okamžite:

1. zavrie zošit a zhasne všetky školské svetlá,
2. bez textového oznamu aktivuje učiteľa daného predmetu v kabinete,
3. nastaví 30-sekundový cooldown pre ďalší pokus v rovnakom predmete,
4. umožní ostatným učiteľom hlásiť hráča hlasnou sirénou.

Po priamom kontakte učiteľ neustále aktualizuje cieľ. Po úniku sa už nevráti do kabinetu: zostane vypustený a striedavo prechádza chodbou aj všetkými predmetovými učebňami. Každé interiérové dvere majú obojsmerný navigačný prechod; učiteľ ich otvorí až vtedy, keď k nim príde. Pri odchode z kabinetu jeho dvere za sebou zavrie, keď je priechod voľný. Otvorené triedne dvere vypnú kolíziu krídla, takže hráč aj učiteľ spoľahlivo prejdú medzi učebňou a chodbou. Lavice, stoličky a učiteľské stoly majú kolíziu aj pre učiteľov.

Pod lavicu sa nelezie cez `E`. Podrž `C`, prikrč sa a fyzicky pod ňu vojdi. Hráč sa pod lavicou ďalej normálne pohybuje; skrytý je iba počas drepu v priestore priamo pod stolom. Prenasledovateľ ho tam nevidí ani nechytí a prepne sa do prehľadávania školy. Po vylezení ďalej roamuje, kým hráča znovu neuvidí, nedostane sirénové hlásenie alebo nepríde ráno. Počas jeho prehľadávania možno riešiť úlohy v iných triedach.

Dvere používajú fyzický lokálny pánt a 0,45-sekundovú sinusovú tween animáciu. Viditeľná sieť sa otáča spolu s pántom; po otvorení zostane krídlo mimo otvoru. Pevná interakčná zóna zostáva pri zárubni, preto rovnaké `E` dvere aj zatvorí. Kabinetové dvere môže otvoriť iba AI. Samostatná hráčska kolízna vrstva zostáva aktívna aj pri otvorených kabinetových dverách, takže hráč nemôže vojsť za učiteľom.

`Esc` úplne pozastaví SceneTree, školský čas, fyziku aj AI. Pauza ponúka posuvník jasu/gammy v rozsahu 50–150 %, tlačidlo pokračovania a bezpečný návrat do hlavného menu. Jas sa aplikuje na `WorldEnvironment` okamžite a ukladá sa do save súboru.

Noc 1 má `real_world_duration_seconds = 600.0`, teda presne 10 minút. Po dosiahnutí rána hra pokračuje: svetlá sa obnovia, naháňačka sa ukončí a HUD pošle hráča k dverám `VÝCHOD` na severnom konci chodby. Až interakcia s týmto východom dokončí noc a odomkne ďalšiu.

## Úlohy a predmety

Predmetové dáta sú v `data/homework/*.tres`. Každý `SubjectData` obsahuje identifikátor, slovenský názov, číslo učebne, učiteľa, farbu a pole `homework_sets`.

### Pridanie alebo zmena otázky

1. Otvor príslušný `.tres` súbor v Godot Inspectore.
2. V `homework_sets` uprav jeden z troch vnorených `HomeworkQuestion` resource objektov.
3. Nastav slovenské `prompt`, štyri položky `choices` a `correct_index` v rozsahu `0` až `3`.
4. Zachovaj presne tri sady na predmet; aktuálny postup a validátor s tým počítajú.

Ak chceš viac ako tri sady, zmeň aj `SchoolGameManager.SETS_PER_SUBJECT`, konfiguráciu nocí, texty HUD a validátor.

## Vlastné modely učiteľov

Godot môže importovať `.glb`, `.gltf` a `.fbx`; odporúčaný je binárny `.glb`.

1. Skopíruj model aj jeho textúry do `res://assets/models/teachers/<meno>/` (na disku `D:\skibidi\assets\models\teachers\<meno>\`).
2. Nechaj Godot dokončiť import. Model má byť v metroch, Y hore a jeho predná strana má smerovať pozdĺž lokálnej osi +Z.
3. Ak potrebuješ upraviť orientáciu alebo uzly, vytvor zdedenú scénu v `enemies/<meno>.tscn` a model otoč v nej.
4. Otvor správny `data/teachers/teacher_<n>.tres`.
5. Pretiahni importovanú alebo zdedenú scénu do `model_scene` a dolaď `model_scale`.

Nemeň `teacher_scene` v `levels/test_school.tscn` a nemaž `characters/teachers/placeholder_teacher.tscn`. Tento wrapper obsahuje AI, kolíziu a navigáciu. Keď je `model_scene` prázdne, zobrazí sa hotový vstavaný placeholder učiteľa. Keď neskôr priradíš vlastný model, skryje sa iba placeholder vizuál a vlastný model automaticky používa rovnaké prenasledovanie.

### Animácie

Animácia nie je povinná. Učiteľ sa ako celá postava posúva dopredu aj bez nej. Ak ju model obsahuje, `placeholder_teacher.gd` nájde prvý `AnimationPlayer`; v `TeacherData` potom môžeš nastaviť presné názvy `idle_animation` a `run_animation`. Neexistujúci alebo prázdny názov nijako nezastaví AI.

### Konfigurácia učiteľa

Každý `TeacherData` podporuje meno, predmet, model, mierku, voliteľné názvy animácií, rýchlosť hliadky a naháňačky, sluch, dohľad, uhol videnia, aktívne noci, chase hudbu, jumpscare obrázok, jumpscare zvuk a špeciálne správanie. Aktuálna AI používa model, voliteľné animácie, rýchlosti, dohľad, uhol, aktívne noci a jumpscare médiá.

| Predmet | Učiteľ/ka | Konfigurácia vlastného modelu |
|---|---|---|
| Dejepis | Jindra Kanyicsková | `data/teachers/teacher_1.tres` |
| Matematika | Alžbeta Kéryová | `data/teachers/teacher_2.tres` |
| Slovenský jazyk | Miroslav Broniš | `data/teachers/teacher_3.tres` |
| Elektrotechnika | Mária Šumná | `data/teachers/teacher_4.tres` |
| Ekonomika | Marián Kováč | `data/teachers/teacher_5.tres` |
| Aplikovaná informatika | Miloš Palaj | `data/teachers/teacher_6.tres` |
| Anglický jazyk | Jana Palajová | `data/teachers/teacher_7.tres` |
| Riaditeľka | Zuzana Čižmáriková | `data/teachers/headmistress.tres` |

Zuzana Čižmáriková sa objaví v 8. noci. Kým je aktívna, zvyšuje všetkým predmetovým učiteľom rýchlosť o 20 % a vzdialenosť dohľadu o 25 %. Používa rovnaký vymeniteľný `model_scene` ako ostatné postavy.

## Vlastná hudba, ambient a kroky

Godot podporuje najmä `.wav`, `.ogg` a `.mp3`. Súbory vlož do `res://audio/` a po importe otvor `data/audio/game_audio.tres`:

1. `menu_music` nahrádza hudbu hlavného menu,
2. `school_ambient` nahrádza slučku počas noci,
3. `default_teacher_footstep` nahrádza spoločný zvuk krokov,
4. hlasitosť upravíš v troch poliach `*_volume_db`.

Konkrétny učiteľ alebo riaditeľka môže mať vlastné kroky v poli `footstep_sound` svojho `TeacherData`. Prázdne audio polia sú bezpečné a použijú procedurálny placeholder. Podrobnosti sú aj v `audio/README.md`.

## Jumpscare obrázky a zvuky

Vlož obrázky do `assets/images/jumpscares/` a zvuky do `audio/jumpscares/`, potom ich priraď k `jumpscare_image` a `jumpscare_sound` v príslušnom `TeacherData`. Po chytení obrazovka použije tieto médiá; prázdne polia použijú procedurálnu tvár a zvuk. Po 2,4 sekundy sa tá istá noc načíta od začiatku s nulovým postupom úloh.

## Noci, čas a učitelia

`data/nights/night_1.tres` až `night_8.tres` určujú názov, začiatok/koniec školského času, reálne trvanie, 21 požadovaných sád, aktívne ID učiteľov, násobiče AI, riaditeľku a špeciálne udalosti. Čas zvláda prechod cez polnoc.

| Noc | Aktívni učitelia | Riaditeľka |
|---|---:|---|
| 1 | 0 | nie |
| 2 | 1 | nie |
| 3 | 2 | nie |
| 4 | 3 | nie |
| 5 | 4 | nie |
| 6 | 5 | nie |
| 7 | 6 | nie |
| 8 | všetkých 7 predmetových učiteľov | Zuzana Čižmáriková, aktívna |

Učitelia aktívni pre danú noc hliadkujú po chodbe aj učebniach a môžu spustiť sirénu počas cudzej predmetovej naháňačky. Predmetový učiteľ sa po nesprávnej odpovedi aktivuje aj v noci, v ktorej normálne nehliadkuje, a do konca noci už zostane v škole namiesto návratu do kabinetu.

Všetky hodiny a HUD čítajú jediný zdroj `NightManager.current_in_game_time`; nemajú vlastné časovače, preto sa nerozchádzajú. Dĺžku noci mení `real_world_duration_seconds`, čas začiatku a konca polia `start_*` a `end_*`. Dosiahnutie koncového času vytvorí stav rána; samotné dokončenie nastane až pri školskom východe.

## Ukladanie

`SaveManager` zapisuje verziovaný JSON do `user://detention_save.json`. Ukladá odomknutú/poslednú noc, dokončenia, najlepšie časy, úmrtia a nastavený jas. Neplatný súbor obnoví zo zálohy alebo z bezpečných predvolených hodnôt.

Vývojový reset: zatvor hru, v Godot zvoľ **Project > Open User Data Folder** a odstráň `detention_save.json`, `.bak` a `.tmp`, alebo dočasne zavolaj `SaveManager.reset_progress()`.

## Validácia

```powershell
C:\Users\matej\Downloads\godot.exe --headless --path . --editor --quit
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase1.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase2.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase2.tscn -- --phase2-test --phase2-verify
C:\Users\matej\Downloads\godot.exe --headless --path . res://scripts/validate_phase3.tscn -- --phase2-test
```

Phase 3 test overuje 7 predmetov, 7 učiteľov, Zuzanu Čižmárikovú a jej boosty, 21 otázok, 30-sekundový cooldown, vymeniteľnú audio konfiguráciu, roaming cez triedy, zatvorenie kabinetu, dvere, fyzický drep, pauzu, navigation mesh, výpadok, sirénu, chytenie, jumpscare, ranný východ a reset noci.

## Export pre Windows

1. V **Editor > Manage Export Templates** nainštaluj šablóny zhodné s verziou Godot.
2. V **Project > Export > Add...** pridaj `Windows Desktop`.
3. Nastav názov, ikonu, architektúru a výstup.
4. Exportovaný `.exe` otestuj mimo priečinka projektu.

Po vytvorení export presetu:

```powershell
C:\Users\matej\Downloads\godot.exe --headless --path . --export-release "Windows Desktop" build\NocnaSkola.exe
```
