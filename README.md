# Nočná škola

Godot 4 first-person horor z trojposchodovej slovenskej školy. Hráč sa môže voľne pohybovať po prízemí a dvoch horných poschodiach, otvárať dvere, riešiť domáce úlohy a utekať pred učiteľom príslušného predmetu. Kabinet je iba pre učiteľov.

## Aktuálny obsah

- Slovenské hlavné menu, výber noci, načítanie, HUD, obrazovka úloh a dokončenie noci
- Tri plne priechodné podlažia: prízemie so siedmimi predmetovými učebňami a dve horné poschodia so 16 ďalšími miestnosťami
- Dve schodiskové veže na severnom a južnom konci chodieb so 104 normálne dimenzovanými stupňami, vodorovnými medzipodestami, kovovým zábradlím a navigačnými prepojeniami pre hráča aj učiteľov
- Knižnice, laboratóriá, študovne, polytechnická dielňa, hudobná učebňa, počítačové laboratórium, archív, telocvičňa a všeobecné učebne
- Prepracované interiéry 23 miestností a samostatná prízemná športová hala so športovou podlahou, dvomi basketbalovými košmi, futsalovými bránami, rebrinami a tribúnou
- Zamknutý kabinet s ôsmimi konfigurovateľnými učiteľmi a riaditeľkou Zuzanou Čižmárikovou; hráč ho neotvorí ani nevojde za nimi
- Osem dátovo riadených nocí a spoločný školský čas zobrazený v HUD
- Pohyb z prvej osoby, otáčanie myšou, šprint, výdrž, drep, skok a interakcia
- Baterka s 30-metrovým tieňovaným kužeľom, mäkkým dosvietením do 36 metrov a vyhladenými tieňmi
- Dvadsaťštyri presne osadených interiérových dverí — jedny v každej učebni a kabinete — a ranný východ na konci chodby
- Rámové okná medzi chodbou a triedami aj bežné vonkajšie okná so stenou, parapetom a nadpražím
- Štyri stropné svetlá v každej učebni a kabinete pre rovnomernejšie osvetlenie
- Trávnatý školský areál s chodníkmi a 18 stromami okolo budov
- Spoľahlivé osvetlenie v Compatibility rendereri vďaka lokálne deleným podlahám a rozpočtu 128 vykresľovaných svetiel
- Tri sady úloh v každej učebni, spolu 21 sád za noc
- Nesprávna odpoveď vypne školské svetlá, spustí naháňačku a zablokuje danú úlohu na 30 sekúnd
- Ostatní aktívni učitelia pri spozorovaní hráča potichu odovzdajú jeho polohu prenasledovateľovi
- Viacposchodový navigačný mesh školy, kolízny nábytok, hliadkovanie, prenasledovanie, hľadanie a únik
- Schovanie pod každou zo 42 žiackych lavíc; učiteľ hráča pod lavicou nevidí a začne prehľadávať školu
- Plnohodnotná pauza cez `Esc` s okamžitým nastavením jasu/gammy, pokračovaním a návratom do hlavného menu
- Nastavenia obrazu s uloženými voľbami 1280 × 720, 1920 × 1080, 2560 × 1440 a režimom v okne alebo na celej obrazovke
- Vymeniteľná hudba menu, školský ambient a priestorové kroky učiteľov s procedurálnymi náhradami
- Noc 1 trvá 10 reálnych minút; HUD ukazuje postup k ránu a ranné svetlo odomkne východ, ktorým sa dokončí level
- Verziovaný JSON save systém a odomykanie nocí
- Učiteľské modely, animácie a parametre sú v `TeacherData`; modely nie sú zakódované v AI
- 3D jumpscare s násilným otočením kamery na učiteľa, výpadom modelu, otrasom, zvukom a automatickým reštartom rovnakej noci

Zatiaľ nie sú hotové: finálny autorský zvukový obsah, chase hudba, úvodná detention sekvencia a ručne vytvorené 3D modely. Učitelia, hudba, ambient, kroky a jumpscare používajú v prípade nepriradeného súboru procedurálne náhrady.

## Štruktúra projektu

```text
res://
|- assets/                         importované modely, textúry a obrázky
|- audio/                          vlastná hudba a zvuky na import
|- characters/
|  |- clocks/                      voliteľné komponenty hodín (v učebniach nie sú osadené)
|  |- teachers/                    pohyblivý TeacherData-driven učiteľ
|  `- player.tscn                  FPS hráč, HUD a obrazovka úloh
|- data/
|  |- homework/                    7 predmetov, každý s 3 otázkami
|  |- nights/                      NightData pre noci 1 až 8
|  |- teachers/                    8 učiteľov a TeacherData riaditeľky
|  `- audio/                       centrálna GameAudioData konfigurácia
|- enemies/                        miesto pre zdedené scény importovaných postáv
|- levels/                         škola a opakovateľné objekty
|- scripts/
|  |- levels/classroom_decorator.gd  modulárne zariadenie všetkých učební
|  |- levels/school_visual_polish.gd jednotná paleta a detaily chodieb
|  `- ...                         level, UI a automatické validátory
|- systems/
|  |- audio/                       menu, ambient a náhradné kroky
|  |- night/                       NightData, SchoolTime a NightManager
|  |- save/                        SaveManager
|  |- homework/                    interaktívna stanica úloh
|  |- hiding/                      schovanie pod lavicami
|  `- school_game_manager.gd       úlohy, výpadok, naháňačka a hlásenia polohy
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
| Zapnúť alebo vypnúť baterku | `F` |
| Pozastaviť hru / zavrieť pauzu | `Esc` |
| Okamžite prepnúť na ráno (iba debug build) | `F10` alebo tlačidlo v pauze |

## Spustenie

```powershell
C:\Users\matej\Downloads\godot.exe --path . --editor
```

Stlač `F5`; projekt spustí `main.tscn`. Hlavná scéna aj autoloady `AudioManager`, `SaveManager`, `NightManager` a `SchoolGameManager` sú už nastavené.

### Zobrazenie školy v Godot 3D editore

Hlavná školská scéna je `res://levels/test_school.tscn`. Po jej otvorení sa pod uzlom `EditorPreview` automaticky vytvorí celý lokálny 3D náhľad budovy; hru netreba spúšťať. Ak bola scéna otvorená počas zmeny skriptu, zavri jej kartu bez uloženia a otvor ju znova. Náhľad možno obnoviť aj vypnutím a zapnutím vlastnosti `Show Editor Preview` na koreni `TestSchool`.

V náhľade sú v kabinete aj všetci ôsmi učitelia a riaditeľka, presne na miestach, odkiaľ štartujú v hre. Rozbaľ `EditorPreview > Kabinet` alebo sa v 3D pohľade presuň približne na `X 13, Y 1.7, Z 28.5`. Každá postava má menovku a načíta model zo svojho `TeacherData`; AI, fyzika a zvuky sú v editore vypnuté. Po úprave modelu obnov náhľad prepínačom `Show Editor Preview`.

Náhľad slúži na prezeranie a meranie. Generované deti sa zámerne neukladajú do `.tscn`, aby sa pri spustení nevytvorila škola dvakrát. Trvalé rozmery a rozloženie sú v `scripts/levels/test_school.gd`, zariadenie tried v `scripts/levels/classroom_decorator.gd` a materiály/dekorácie v `scripts/levels/school_visual_polish.gd`.

## Herný priebeh

### Rozloženie školy

- **Prízemie:** sedem predmetových učební, všetkých 21 sád domácich úloh, zamknutý kabinet, chodba do športového pavilónu a ranný východ v severnej schodiskovej veži.
- **1. poschodie:** osem miestností vrátane všeobecnej učebne F2-01, knižnice, laboratórií a študovne.
- **2. poschodie:** osem ďalších učební vrátane polytechnickej dielne, počítačového laboratória, hudobnej učebne a archívu.
- **Športový pavilón:** samostatná hala východne od školy (36 × 46 m, výška 9,5 m) je na prízemí napojená presklenou krytou chodbou z voľnej východnej strany severnej schodiskovej veže. Obsahuje drevené ihrisko, tribúnu, basketbalové koše, futsalové brány, rebriny, oceľové strešné väzníky a svetlá; vstup sa nekrižuje so schodmi.
- Schodiskové veže sú na oboch koncoch chodieb. Obe majú skutočne vyrezané podlahové otvory, takže cez schody neprechádza neviditeľná ani viditeľná podlaha.
- Učitelia sa pri štarte deterministicky rozdelia medzi podlažia v pomere 3/3/2, striedajú smer hliadky a rezervujú si rôzne ciele. Nezhromažďujú sa preto všetci v jednej triede a medzi poschodiami môžu použiť severné aj južné schodisko.

V každej učebni je na učiteľskom stole zošit. Interakcia otvorí nasledujúcu z troch sád daného predmetu. Správna odpoveď započíta postup aktuálne spustenej noci. Dokončenie všetkých 21 sád už noc neukončí predčasne.

Nesprávna odpoveď okamžite:

1. zavrie zošit a zhasne všetky školské svetlá,
2. bez textového oznamu aktivuje učiteľa daného predmetu v kabinete,
3. nastaví 30-sekundový cooldown pre ďalší pokus v rovnakom predmete,
4. umožní ostatným učiteľom potichu hlásiť polohu hráča prenasledovateľovi.

Po priamom kontakte učiteľ neustále aktualizuje cieľ. Po úniku sa už nevráti do kabinetu: zostane vypustený a striedavo prechádza chodbou aj všetkými predmetovými učebňami. Každé interiérové dvere majú obojsmerný navigačný prechod; učiteľ ich otvorí až vtedy, keď k nim príde. Pri odchode z kabinetu jeho dvere za sebou zavrie, keď je priechod voľný. Otvorené triedne dvere vypnú kolíziu krídla, takže hráč aj učiteľ spoľahlivo prejdú medzi učebňou a chodbou. Lavice, stoličky a učiteľské stoly majú kolíziu aj pre učiteľov.

Pod lavicu sa nelezie cez `E`. Podrž `C`, prikrč sa a fyzicky pod ňu vojdi. Hráč sa pod lavicou ďalej normálne pohybuje; skrytý je iba počas drepu v priestore priamo pod stolom. Keď učiteľ stratí dohľad, naháňačka sa neukončí: najprv ide na posledné miesto, kde hráča videl, vrátane inej triedy, a až potom prehľadáva školu. Pod lavicou hráča nevidí ani nechytí. Po vylezení ďalej roamuje, kým hráča znovu neuvidí, nedostane tiché hlásenie polohy od iného učiteľa alebo nepríde ráno. Počas jeho prehľadávania možno riešiť úlohy v iných triedach.

Dvere používajú fyzický lokálny pánt a 0,45-sekundovú sinusovú tween animáciu. Viditeľná sieť sa otáča spolu s pántom; po otvorení zostane krídlo mimo otvoru. Pevná interakčná zóna zostáva pri zárubni, preto rovnaké `E` dvere aj zatvorí. Kabinetové dvere môže otvoriť iba AI. Samostatná hráčska kolízna vrstva zostáva aktívna aj pri otvorených kabinetových dverách, takže hráč nemôže vojsť za učiteľom.

`Esc` úplne pozastaví SceneTree, školský čas, fyziku aj AI. Pauza ponúka posuvník jasu/gammy v rozsahu 50–150 %, tlačidlo pokračovania a bezpečný návrat do hlavného menu. Jas sa aplikuje na `WorldEnvironment` okamžite a ukladá sa do save súboru.

V hlavnom menu otvor **NASTAVENIA**. Rozlíšenie ponúka iba podporované voľby 720p, 1080p a 1440p. Režim obrazovky možno prepnúť medzi **V OKNE** a **CELÁ OBRAZOVKA**. Zmena sa použije okamžite a spolu s režimom sa uloží do `SaveManager`, takže platí aj po ďalšom spustení.

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
2. Nechaj Godot dokončiť import. Odporúčaný model má Y hore a prednú stranu pozdĺž lokálnej osi +Z, ale rozdielna mierka ani stredový pivot už nie sú problém.
3. Wrapper automaticky zmeria viditeľnú geometriu, nastaví ju na `model_height` (predvolene 2,3 m), vycentruje ju nad kolíziou a položí spodnú hranu na podlahu.
4. Otvor správny `data/teachers/teacher_<n>.tres`.
5. Pretiahni importovanú alebo zdedenú scénu do `model_scene`. `model_scale` slúži na dodatočné doladenie proporcií, `model_rotation_degrees` opraví orientáciu a `model_ground_offset` jemne posunie chodidlá.

Nemeň `teacher_scene` v `levels/test_school.tscn` a nemaž `characters/teachers/placeholder_teacher.tscn`. Tento wrapper obsahuje AI, kolíziu a navigáciu. Keď je `model_scene` prázdne, zobrazí sa hotový vstavaný placeholder učiteľa. Keď neskôr priradíš vlastný model, skryje sa iba placeholder vizuál a vlastný model automaticky používa rovnaké prenasledovanie.

Ak chceš upraviť existujúceho učiteľa, stačí zmeniť jeho `.tres` z tabuľky nižšie; jeho model aj štartovacia pozícia sa zobrazia v kabinete v editorovom náhľade. Pridanie úplne nového deviateho predmetového učiteľa nie je iba vloženie modelu: potrebuje nový `SubjectData`, tri sady úloh, `TeacherData`, učebňu, registráciu v `SchoolGameManager` a ID v požadovaných `NightData`. Bez týchto väzieb by sa síce model zobrazil, ale úloha ani naháňačka by nevedeli, koho aktivovať.

### Animácie

Animácia nie je povinná. Učiteľ sa ako celá postava posúva dopredu aj bez nej. Ak ju model obsahuje, `placeholder_teacher.gd` nájde prvý `AnimationPlayer`. Spoločná konvencia je `Walking` pre hliadku a hľadanie a `RunFast` pre naháňanie; oba klipy sa počas pohybu automaticky prehrávajú v slučke. Voliteľný pokojový klip nastav cez `idle_animation`. Názvy sú case-sensitive a dajú sa pre konkrétny model zmeniť cez `walk_animation` a `run_animation` v jeho `TeacherData`.

Model Jindry Kanyicskovej v `teacher_1.tres` už používa `Walking` a `RunFast`. Ostatní učitelia aj riaditeľka zdedia rovnaké názvy, takže po priradení modelu s týmito klipmi netreba meniť skript. Prázdne `model_scene` bezpečne zobrazí placeholder.

### Konfigurácia učiteľa

Každý `TeacherData` podporuje meno, predmet, model, automatické prispôsobenie výšky, mierku, rotáciu, odsadenie od podlahy, voliteľné názvy animácií, rýchlosť hliadky a naháňačky, sluch, dohľad, uhol videnia, aktívne noci, chase hudbu, jumpscare obrázok, jumpscare zvuk a špeciálne správanie. Aktuálna AI používa model, voliteľné animácie, rýchlosti, dohľad, uhol, aktívne noci a jumpscare médiá.

| Predmet | Učiteľ/ka | Konfigurácia vlastného modelu |
|---|---|---|
| Dejepis | Jindra Kanyicsková | `data/teachers/teacher_1.tres` |
| Matematika | Alžbeta Kéryová | `data/teachers/teacher_2.tres` |
| Slovenský jazyk | Miroslav Broniš | `data/teachers/teacher_3.tres` |
| Elektrotechnika | Mária Šumná | `data/teachers/teacher_4.tres` |
| Ekonomika | Marián Kováč | `data/teachers/teacher_5.tres` |
| Aplikovaná informatika | Miloš Palaj | `data/teachers/teacher_6.tres` |
| Anglický jazyk | Jana Palajová | `data/teachers/teacher_7.tres` |
| Telesná a športová výchova | Juraj Krajči | `data/teachers/teacher_8.tres` |
| Riaditeľka | Zuzana Čižmáriková | `data/teachers/headmistress.tres` |

Zuzana Čižmáriková sa objaví v 8. noci. Kým je aktívna, zvyšuje všetkým predmetovým učiteľom rýchlosť o 20 % a vzdialenosť dohľadu o 25 %. Používa rovnaký vymeniteľný `model_scene` ako ostatné postavy.

## Vlastná hudba, ambient a kroky

Godot podporuje najmä `.wav`, `.ogg` a `.mp3`. Súbory vlož do `res://audio/` a po importe otvor `data/audio/game_audio.tres`:

1. `menu_music` nahrádza hudbu hlavného menu,
2. `school_ambient` nahrádza slučku počas noci,
3. `default_teacher_footstep` nahrádza spoločný zvuk krokov,
4. hlasitosť upravíš v troch poliach `*_volume_db`.

Konkrétny učiteľ alebo riaditeľka môže mať vlastné kroky v poli `footstep_sound` svojho `TeacherData`. Prázdne audio polia sú bezpečné a použijú procedurálny placeholder. Podrobnosti sú aj v `audio/README.md`.

## 3D jumpscare, obrázky a zvuky

Po chytení sa hráčska kamera premiestni k tvári skutočného 3D modelu, učiteľ sa otočí na hráča a vrhne sa ku kamere. Nasleduje zmena FOV, červený záblesk, otras a zvuk. Model s kosťou, ktorej názov končí na `Head`, používa presnú polohu hlavy; model bez nej použije hornú časť svojich vizuálnych rozmerov.

Vlož voliteľné obrázky do `assets/images/jumpscares/` a zvuky do `audio/jumpscares/`, potom ich priraď k `jumpscare_image` a `jumpscare_sound` v príslušnom `TeacherData`. Obrázok sa zobrazí iba ako 0,055-sekundový glitch uprostred 3D sekvencie, nie ako hlavný jumpscare. Prázdny zvuk použije procedurálny výkrik. Po 2,4 sekundy sa tá istá noc načíta od začiatku s nulovým postupom úloh.

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
| 8 | všetkých 8 učiteľov | Zuzana Čižmáriková, aktívna |

Učitelia aktívni pre danú noc hliadkujú po chodbe aj učebniach a počas cudzej predmetovej naháňačky môžu potichu poslať prenasledovateľovi polohu hráča. Hráč nedostane textové ani zvukové upozornenie. Predmetový učiteľ sa po nesprávnej odpovedi aktivuje aj v noci, v ktorej normálne nehliadkuje, a do konca noci už zostane v škole namiesto návratu do kabinetu.

HUD a voliteľné komponenty hodín čítajú jediný zdroj `NightManager.current_in_game_time`; nemajú vlastné časovače, preto sa nerozchádzajú. V učebniach už nástenné hodiny nie sú osadené. Dĺžku noci mení `real_world_duration_seconds`, čas začiatku a konca polia `start_*` a `end_*`. Dosiahnutie koncového času vytvorí stav rána; samotné dokončenie nastane až pri školskom východe. V debug builde možno tento hrateľný ranný stav vyvolať klávesom `F10` alebo tlačidlom v pauze; ďalšia noc sa odomkne až po použití východu.

## Ukladanie

`SaveManager` zapisuje verziovaný JSON do `user://detention_save.json`. Ukladá odomknutú/poslednú noc, dokončenia, najlepšie časy, úmrtia, jas, rozlíšenie a režim obrazovky. Neplatný súbor obnoví zo zálohy alebo z bezpečných predvolených hodnôt.

Vývojový reset: zatvor hru, v Godot zvoľ **Project > Open User Data Folder** a odstráň `detention_save.json`, `.bak` a `.tmp`, alebo dočasne zavolaj `SaveManager.reset_progress()`.

## Validácia

Odporúčaný bezpečný príkaz, aj keď je Godot editor otvorený:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\validate_project.ps1
```

Skript spustí Phase 1 a Phase 3 postupne v izolovanom používateľskom priečinku, s vlastnými logmi, a po skončení dočasné dáta odstráni. Tým sa automatický test nebije s otvoreným editorom o `user://` save ani log súbory.

```powershell
C:\Users\matej\Downloads\godot.exe --headless --path . --log-file .godot/editor-headless.log --editor --quit
C:\Users\matej\Downloads\godot.exe --headless --path . --log-file .godot/phase1-headless.log res://scripts/validate_phase1.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . --log-file .godot/phase2-headless.log res://scripts/validate_phase2.tscn -- --phase2-test
C:\Users\matej\Downloads\godot.exe --headless --path . --log-file .godot/phase2-verify-headless.log res://scripts/validate_phase2.tscn -- --phase2-test --phase2-verify
C:\Users\matej\Downloads\godot.exe --headless --path . --log-file .godot/phase3-headless.log res://scripts/validate_phase3.tscn -- --phase2-test
```

Každý proces používa vlastný `--log-file`. Nespúšťaj prvý editor/import príkaz súčasne s otvoreným GUI editorom; testovacie scény môžu bežať popri ňom, ak majú samostatné logy a spúšťajú sa postupne.

Phase 1 navyše overuje tri podlažia, štyri schodiskové prechody v dvoch koncových vežiach, 104 viditeľných stupňov, otvory oboch schodísk, 24 dverí a navigačných prechodov, prízemný športový pavilón s neblokovaným vstupom, športové vybavenie, 18 športových svetiel, štyri hliadkové body, trávu, 18 stromov, 64 horných triednych svetiel, svetelný rozpočet, 16 horných miestností a 23 zariadených miestností. Phase 3 overuje viacposchodovú navigáciu, osem učiteľov vrátane Juraja Krajčiho, rozdelenie medzi podlažia, rozdielne rezervované ciele a reálny výstup učiteľa po schodoch. Zachované sú aj kontroly 7 predmetov, Zuzany Čižmárikovej a jej boostov, 21 otázok, cooldownu, dverí, fyzického drepu, výpadku, chytenia, jumpscare, ranného východu a resetu noci.

## Export pre Windows

1. V **Editor > Manage Export Templates** nainštaluj šablóny zhodné s verziou Godot.
2. V **Project > Export > Add...** pridaj `Windows Desktop`.
3. Nastav názov, ikonu, architektúru a výstup.
4. Exportovaný `.exe` otestuj mimo priečinka projektu.

Po vytvorení export presetu:

```powershell
C:\Users\matej\Downloads\godot.exe --headless --path . --export-release "Windows Desktop" build\NocnaSkola.exe
```
