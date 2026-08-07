# Journal des problèmes rencontrés

Ce document consigne, par ordre chronologique, tous les problèmes non triviaux rencontrés
pendant le développement d'AeroPollen, leur cause réelle et leur résolution (ou leur statut si
non résolus). Objectif : éviter de refaire les mêmes investigations et donner à tout
contributeur externe une vision honnête des limites connues de l'environnement de
développement.

**Convention** : chaque entrée est ajoutée dès qu'un problème non trivial est rencontré et
résolu (ou identifié comme bloquant), pas seulement a posteriori.

---

## 1. SDK Manager Linux : dépendance `libwebkit2gtk-4.0` absente sur Ubuntu 24.04

**Symptôme** : le SDK Manager Connect IQ officiel (`sdkmanager`) refuse de démarrer sous WSL
(Ubuntu 24.04), la bibliothèque `libwebkit2gtk-4.0` n'étant plus disponible dans les dépôts
APT de cette version (dépréciée au profit de `libwebkit2gtk-4.1`, incompatible en ABI).

**Cause** : le SDK Manager est une application Electron/GTK figée sur `webkit2gtk-4.0`, jamais
mise à jour par Garmin pour suivre l'évolution des distributions.

**Résolution** : exécuter le SDK Manager dans un conteneur Docker `ubuntu:20.04` (dépôts encore
compatibles), avec `libwebkit2gtk-4.0-37` installé via `apt`, `DISPLAY` partagé avec l'hôte
WSLg et `/tmp/.X11-unix` monté en volume. Permet de mener la connexion au compte Garmin et le
téléchargement du SDK jusqu'au bout.

---

## 2. Résolution des appareils (`-d edge530`) : lien symbolique non résolu par la JVM Linux

**Symptôme** : `monkeyc -d edge530` échoue avec `Invalid device id` alors que l'appareil
`edge530` est bien présent dans `~/.Garmin/ConnectIQ/Devices/`.

**Cause** : le répertoire des appareils était un lien symbolique Linux pointant vers
`/mnt/c/Users/PC/AppData/Roaming/Garmin/ConnectIQ/` (partage avec l'installation Windows). La
JVM Linux du SDK ne résout pas correctement ce lien pour lister les appareils installés.

**Résolution** : utiliser une **copie réelle** des fichiers d'appareil plutôt qu'un lien
symbolique.

---

## 3. Verrou mono-instance orphelin après un arrêt forcé

**Symptôme** : `sdkmanager` ou `simulator` échoue silencieusement au lancement suivant (code de
sortie 255, aucune sortie), après un `kill -9` sur le mauvais PID dans la chaîne de wrappers
Bash → binaire réel.

**Cause** : ces outils utilisent un fichier verrou mono-instance créé avec `O_CREAT|O_EXCL`
(`~/garmin.connectiq.sdkmanager-<user>`, `/root/Sim-root` dans le conteneur). Un process tué
sans arrêt propre laisse ce fichier orphelin, ce qui bloque tout lancement suivant.

**Résolution** : toujours supprimer ce fichier verrou après un `kill` forcé, avant de relancer.

---

## 4. Cross-référence Barrel + `(:background)` : erreur de type-checking

**Symptôme** : le compilateur 9.2.0 rejette la référence à la vue normale (`AirQualityFieldView`)
dans `getInitialView()` avec l'erreur « Value 'X' not available in all function scopes », dès
que l'`AppBase` référence aussi une classe annotée `(:background)` **provenant d'un Barrel**
(`AeroPollenCore.EnvironmentalBackgroundDelegate`) — alors que ce même pattern fonctionne dans
l'exemple officiel `samples/BackgroundTimer`, qui ne traverse pas de Barrel.

**Cause** : limitation du vérificateur de types du compilateur Monkey C avec les Barrels et les
fonctions annotées `(:background)`.

**Résolution** : annoter `getInitialView()` avec `(:typecheck(disableBackgroundCheck))` (pattern
trouvé dans `samples/BackgroundTimer/source/BackgroundTimerApp.mc` pour un cas apparenté).
Appliqué à l'identique dans `aeropollen-air-quality-field` et `aeropollen-pollen-field`.

**Référence** : `specs/001-pollen-air-datafield/research.md` §11.

---

## 5. Simulateur apparemment bloqué après `Debug: SetLayout` sous WSL — **faux mur, résolu (§9)**

**Symptôme** : `bin/simulator` et `bin/shell` établissent correctement une connexion TCP
(`127.0.0.1:1234`), le dernier message affiché par le simulateur est `Debug: SetLayout`, sans
erreur ni message suivant. En pointant `DISPLAY` vers le display réel partagé par WSLg
(`DISPLAY=:0`), `monkeydo -t` ne renvoyait jamais de résultat PASS/FAIL dans nos premiers essais.

**Hypothèse initiale (incorrecte, voir §9)** : absence totale de périphérique GPU dans cet
environnement WSL — `/dev/dri` et `/dev/dxg` n'existent bel et bien pas, ni sur l'hôte ni dans
un conteneur Docker partageant le display WSLg réel. Cette hypothèse a été investiguée à deux
reprises (SDK 9.2.0 et 8.2.3, avec et sans Docker) et semblait chaque fois se confirmer.

**Statut** : **résolu, voir §9** — `Debug: SetLayout` est en réalité le dernier message de log
normal du simulateur (il l'affiche aussi dans les cas qui fonctionnent), pas un indicateur de
blocage. Le vrai problème était de pointer `DISPLAY` vers le display WSLg réel (qui a besoin
d'accélération GPU) plutôt que vers un framebuffer virtuel logiciel (Xvfb), qui n'a besoin
d'aucun GPU. Cette entrée est conservée pour la traçabilité de l'investigation, mais la
conclusion « mur dur, aller sur Windows » qu'elle contenait à l'origine était fausse.

---

## 6. Erreur de compilation `libawt_xawt.so` — confondue à tort avec un problème de GPU

**Symptôme** : dans un conteneur Docker Ubuntu 20.04 neuf, `monkeyc` échoue dès l'étape de
rastérisation des icônes SVG avec `UnsatisfiedLinkError: Can't load library:
.../lib/libawt_xawt.so`, ressemblant à s'y méprendre à un problème d'environnement graphique
(cf. §5).

**Cause réelle** : le paquet APT `openjdk-11-jre-headless` (installé par erreur, par réflexe
« pas besoin d'interface graphique pour compiler ») ne fournit **que**
`libawt_headless.so`, jamais `libawt_xawt.so` (support X11). Ce n'est donc pas un problème de
GPU ni d'extensions X11 (XTEST/RENDER/GLX sont bien présentes, vérifié via `xdpyinfo`), mais un
paquet Java incomplet — le compilateur Monkey C utilise Java AWT/Apache Batik en interne pour
rastériser les ressources SVG, même en mode « headless » d'usage.

**Résolution** : installer le paquet **non-headless** `openjdk-11-jre` (au lieu de
`openjdk-11-jre-headless`). Confirmé avec un test minimal
(`java.awt.Toolkit.getDefaultToolkit()`) puis une compilation complète (`BUILD SUCCESSFUL`).
Sur l'hôte WSL directement (sans Docker), ce problème ne s'est jamais posé — l'installation Java
du système n'est pas en mode headless.

**Piège à retenir** : face à une erreur au premier abord identique à un problème déjà connu et
classé « mur dur », vérifier précisément la pile d'appel avant de l'écarter sans investigation —
ici `strace -f -e trace=openat` a permis de voir que le fichier `.so` était simplement absent du
disque (`ENOENT`), pas un problème de dépendances ou d'extensions manquantes.

---

## 7. Piste écartée : compiler avec une version de SDK antérieure (8.2.3) pour contourner le rendu

**Contexte** : hypothèse initiale (avant d'identifier §6) que le blocage du simulateur pouvait
être spécifique à la version 9.2.0 du SDK, et qu'une version antérieure utiliserait une
technologie de rendu différente, moins exigeante en GPU.

**Résultat** : le SDK 8.2.3 utilise la même pile GTK/WebKit que la 9.2.0 (mêmes bibliothèques
liées dynamiquement, `ldd` identique) — pas de technologie de rendu alternative. De plus, la
8.2.3 échoue à la compilation du projet actuel avec des erreurs de type-checking propres à
l'API `Toybox.Application.Storage` (signature différente de celle utilisée par le code, écrit
et vérifié contre la 9.2.0). **Piste abandonnée** : ni le contournement du rendu, ni une base
de compilation viable pour ce projet.

**Trace laissée** : le SDK 8.2.3 reste installé (root, via le conteneur Docker) dans
`~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-8.2.3-2025-08-11-cac5b3b21` — conservé à titre de
référence, non utilisé pour ce projet.

---

## 8. Alternative validée : sideload direct sur l'appareil physique (Edge 530)

**Contexte** : le simulateur étant bloqué sous WSL (§5), validation manuelle directement sur le
matériel plutôt que d'attendre un accès à un poste Windows.

**Procédure qui a fonctionné** :
1. Compiler une build **production** (sans `-t`, pour ne pas embarquer le code de test) :
   `monkeyc -o App.prg -f monkey.jungle -d edge530 -y developer_key.der -w -r`.
2. Connecter l'Edge 530 en USB — apparaît côté Windows comme un volume amovible (`GARMIN`).
3. Monter ce volume dans WSL : `sudo mount -t drvfs D: /mnt/d` (la lettre peut varier).
4. Copier le `.prg` dans `Garmin/Apps/` sur l'appareil (nom de fichier libre, l'ID d'application
   est lu depuis le binaire, pas depuis le nom de fichier).
5. `sync && sudo umount /mnt/d`, puis éjecter côté Windows.
6. Sur l'appareil : Menu → Profils d'activité → Écrans de données → Ajouter un champ → chercher
   le nom déclaré dans `Rez.Strings.AppName`.

**Limite** : valide le comportement réel de l'application (écran, mise à jour, permissions),
mais ne fait pas tourner les assertions automatisées `Toybox.Test` (celles-ci nécessitent le
simulateur — voir §9 pour la procédure qui fonctionne désormais aussi sous WSL).

---

## 9. Résolution du §5 : Xvfb au lieu du display réel WSLg — exécution réelle des tests obtenue

**Contexte** : en explorant si un émulateur/bouchon communautaire existait pour les appareils
Garmin (le projet ne peut pas être le seul à vouloir faire tourner des tests Connect IQ en CI),
découverte du dépôt public
[matco/connectiq-tester](https://github.com/matco/connectiq-tester) — image Docker qui exécute
les tests « Run No Evil » (= `monkeydo -t`, le nom donné à cette fonctionnalité depuis
l'ancien plugin Eclipse) en CI. Son `tester.sh` lance le simulateur sous **Xvfb**
(`Xvfb :1 -screen 0 1280x1024x24`) plutôt que sur un display réel — détail jamais testé dans nos
investigations précédentes (toujours `DISPLAY=:0`, le display WSLg réel).

**Test effectué** : conteneur Docker `ubuntu:20.04` identique aux essais précédents
(`libwebkit2gtk-4.0-37`, `openjdk-11-jre` non-headless — cf. §6), avec en plus `xvfb`. Simulateur
lancé avec `DISPLAY=:99` pointant vers `Xvfb :99 -screen 0 1280x1024x24`, **pas** vers le
display WSLg. `monkeydo bin/app.prg edge530 -t` exécuté ensuite normalement.

**Résultat** : succès complet, sur les deux applications —
`aeropollen-air-quality-field` : `PASSED (passed=20, failed=0, errors=0)`,
`aeropollen-pollen-field` : `PASSED (passed=21, failed=0, errors=0)`. Le simulateur affiche bien
`Debug: SetLayout` comme dernier message de log (ce n'était donc pas un indicateur de blocage,
juste le dernier log émis avant que le simulateur passe en écoute silencieuse), et répond
normalement aux requêtes TCP de `monkeydo`.

**Piège à noter** : `monkeydo` retourne toujours un code de sortie `1`, même quand tous les
tests passent (`PASSED`) — il faut donc parser la sortie standard (dernière ligne commençant par
`PASSED`/`FAILED`) plutôt que se fier au code de sortie du process. Documenté aussi dans le
`tester.sh` de `matco/connectiq-tester`.

**Conclusion** : le §5 (et la recommandation de `[[aeropollen-next-steps]]` d'attendre Windows)
sont **obsolètes**. L'exécution réelle des tests `Toybox.Test` fonctionne désormais sous WSL, à
condition d'utiliser Xvfb plutôt que le display WSLg réel. Automatisé depuis dans
`scripts/run-tests-wsl.sh` (voir §10 pour un flake occasionnel de ce script) et repris tel quel
en CI (`.github/workflows/tests.yml`).

---

## 10. `scripts/run-tests-wsl.sh` : le simulateur ne répond plus pour la 2e application testée

**Symptôme** : le script échoue de façon reproductible sur la **deuxième** application testée
dans un même run (la première réussit toujours) — `Simulateur non joignable sur
127.0.0.1:1234`, sans lancer aucun test pour cette application.

**Hypothèses écartées, dans l'ordre où elles ont été testées** :
1. *Délai fixe de 5 s insuffisant avant le premier `monkeydo`* — remplacé par une attente active
   (socket X11 puis port TCP en boucle), amélioration réelle mais qui n'a pas résolu le problème.
2. *Dégradation de la session WSL locale après plusieurs heures d'usage intensif* — hypothèse
   émise après avoir reproduit un échec quasi systématique en local (avec segfaults du binaire
   `simulator` visibles dans `dmesg`, signal 11) en fin de session. **Réfutée** : le même échec
   (2e application seulement) a été reproduit à l'identique sur un **runner GitHub Actions
   fraîchement provisionné** (VM jamais utilisée avant ce job) — donc pas un problème de session
   qui vieillit. Les segfaults observés en local restent d'origine incertaine (possiblement un
   problème distinct, propre à cette machine ce jour-là) mais n'expliquent pas le pattern observé
   en CI.
3. *Socket/verrou X11 périmé en réutilisant le même numéro de display (`:99`) entre tentatives* —
   corrigé en donnant un numéro de display jamais réutilisé à chaque tentative
   (`display_counter` incrémenté à chaque essai). **Amélioration réelle et conservée**, mais
   **pas la cause du blocage** : le run CI suivant a montré le même échec avec des displays bien
   distincts à chaque tentative (`:101`, `:102`, `:103`), donc ce n'était pas (ou pas seulement)
   un problème de collision de socket X11.

4. *`pkill` supprimé par erreur en corrigeant l'hypothèse 3* — en donnant un display unique par
   tentative, la ligne qui tuait explicitement les process `simulator`/`Xvfb` précédents a été
   supprimée sans être remplacée. Restaurée (`pkill -9`) au début de chaque tentative. **Bug réel
   et corrigé**, mais toujours pas la cause complète : le run CI suivant échouait encore.
5. *`pkill -f bin/simulator` ne correspond jamais au process réel* — confirmé via
   `/proc/<pid>/cmdline` : invoqué par résolution de `PATH`, l'argv du process est simplement
   `simulator`, sans aucun chemin. `pkill -f bin/simulator` ne l'a donc **jamais** tué, ici ni en
   CI, peu importe le nombre de fois où cette ligne s'exécutait. Corrigé avec `pkill -9 -x
   simulator` (correspondance exacte sur le nom du process). **Bug réel et corrigé.**
6. *Verrou mono-instance orphelin* — même correctement tué (hypothèse 5 corrigée), le simulateur
   laisse un fichier verrou mono-instance, `/root/Sim-root`, qui n'est nettoyé qu'à l'arrêt
   propre — jamais après un signal (`SIGKILL` ou `SIGTERM`). Sans le supprimer explicitement,
   toute nouvelle instance de `simulator` refuse de démarrer, silencieusement (aucune ligne de
   log, aucune erreur) — exactement le symptôme documenté au §3 pour `sdkmanager`, jamais
   rapproché du même problème pour `simulator` avant cette investigation. Corrigé par
   `rm -f /root/Sim-root` avant chaque relance. **Bug réel et corrigé**, confirmé par
   reproduction manuelle isolée (`docker exec` pas à pas, en dehors du script).

**Après les hypothèses 4 à 6, un dernier symptôme, plus profond, reste observé** (diagnostic
ajouté pour l'objectiver plutôt que continuer à deviner) : sur un run isolé et propre, la toute
première tentative voit le simulateur démarrer et devenir brièvement joignable (le check TCP
passe), puis **mourir avant que `monkeydo` ne puisse s'en servir** (`ps aux` juste après ne
montre plus aucun process `simulator`, sortie de `monkeydo` totalement vide). Sur les tentatives
suivantes, symptôme différent : le process reste vivant avec un log de démarrage identique à un
succès, mais son port ne s'ouvre jamais. Deux manifestations distinctes d'une même instabilité de
fond — cohérent avec le segfault (`signal 11`) confirmé très tôt dans cette investigation via
`dmesg`, qui n'avait pas disparu : il était seulement masqué par les bugs 4-6 ci-dessus (le
simulateur ne redémarrait jamais correctement de toute façon, donc son instabilité intrinsèque
n'était même pas ce qui bloquait le plus souvent).

**Décision actée avec l'utilisateur (2026-08-05)** : ne pas continuer à investiguer un crash
non-déterministe dans un binaire propriétaire sans code source disponible. Le job `tests.yml` est
passé en `continue-on-error: true` — il reste exécuté et son résultat visible à chaque PR, mais
ne bloque plus la fusion. La garantie de non-régression réelle du projet reste
`scripts/run-tests-wsl.sh` exécuté **en local** (fiable, y compris pour les régressions
applicatives : 43/43 tests systématiquement verts dès que le simulateur démarre correctement) et
la validation manuelle sur appareil physique (§8) — toutes deux déjà pratiquées pour ce projet
indépendamment de la CI.

**Statut final** : 3 bugs réels identifiés et corrigés (display réutilisé, pattern `pkill`
incorrect, verrou orphelin) — tous restent dans le script, ce sont de vraies améliorations. Le
job CI reste informatif mais non bloquant tant que l'instabilité intrinsèque du binaire
`simulator` sous Docker+Xvfb n'est pas mieux comprise.

**Leçon retenue** : lors d'une correction, ne pas supprimer un mécanisme existant (ici, un
`pkill`) sans avoir vérifié explicitement qu'il n'est plus nécessaire. Et surtout : ajouter le
diagnostic (contenu des logs, `ps aux`, état des fichiers verrou) **avant** de formuler une
nouvelle hypothèse, pas après plusieurs correctifs infructueux — chaque round de « ça ne marche
toujours pas » sans données nouvelles n'était qu'une supposition de plus, jusqu'à ce que le
`ps aux` et `/proc/<pid>/cmdline` réels tranchent la question sans ambiguïté.

---

## 11. Champs bloqués sur `N/D` en usage réel malgré 43/43 tests automatisés au vert

**Symptôme** : sur Edge 530 physique, les deux champs restent en permanence à `N/D`, y compris
après le correctif du premier relevé quasi immédiat (§ courant), malgré une suite de tests
`Toybox.Test` intégralement verte (couvrant la logique de compute/cache/parsing, mais ni la
connectivité réelle, ni le budget mémoire réel du Background Service — hors de portée du
simulateur/des tests unitaires).

**Démarche** : ajout d'un module `DebugStatus` (temporaire, voir commit dédié) qui mémorise le
code réel retourné à chaque étape (position GPS absente, ou code de réponse
`Communications.makeWebRequest`) et l'affiche **à la place de** `N/D`, pour obtenir un signal
exploitable directement sur l'appareil sans accès à un débogueur.

**Codes obtenus, dans l'ordre, en conditions réelles (2026-08-05)** :
1. `-999` (jamais exécuté) sur un champ jamais affiché à l'écran au moins une fois — confirmé
   sans lien avec un bug une fois l'écran effectivement consulté sur l'appareil.
2. `-104` (`Communications.BLE_CONNECTION_UNAVAILABLE`, doc `Toybox.Communications` : *"No BLE
   connection is available"*) — pas de connexion Bluetooth active entre l'Edge et le téléphone au
   moment de la tentative. Résolu côté utilisateur (reconnexion Bluetooth + ajout du WiFi direct
   en complément).
3. `-403` (`Communications.NETWORK_RESPONSE_OUT_OF_MEMORY`, doc `Toybox.Communications` : *"Ran
   out of memory processing network response"*) — **bug applicatif réel**, cf. ci-dessous.

**Cause du `-403`** : la requête envoyée à Open-Meteo ne limitait pas la période de prévision.
Sans paramètre `forecast_hours`/`forecast_days`, l'API renvoie par défaut **5 jours de données
horaires** (120 points × 7 variables `hourly`, vérifié par appel direct à l'API : 6247 octets
JSON bruts). Une fois parsé en objets Monkey C (Dictionary/Array/Number avec un surcoût mémoire
par objet bien supérieur à la taille JSON brute), cette réponse dépasse largement le budget
mémoire du Background Service (32 Ko, cf. `research.md` §10) — d'où
`NETWORK_RESPONSE_OUT_OF_MEMORY`. Le code applicatif n'exploite pourtant que l'entrée
correspondant à l'heure courante (`findCurrentHourIndex`) : tout le reste de la réponse était
inutilement téléchargé et parsé.

**Correction** : ajout du paramètre `forecast_hours=6` à la requête (voir
`OpenMeteoAirQualityClient.mc` et `contracts/open-meteo-air-quality.md`). Vérifié par appel
direct à l'API : 6 points horaires, 829 octets bruts au lieu de 120 points/6247 octets — largement
sous le budget mémoire, avec une marge de 6 h autour de l'heure courante (contre 1h de marge
stricte qui suffirait, mais fragile face à un léger retard réseau).

**Confirmation finale sur appareil (2026-08-05)** : après déploiement du correctif, les deux champs
affichent de façon stable `-104/F17 B18` — c'est-à-dire ~17-18 Ko de mémoire libre à chaque étape
(baseline et après réception), largement au-dessus du seuil qui déclenchait le `-403` avant
correctif. Le `-104` (Bluetooth) subsiste seul : il ne s'agit pas d'un défaut du code mais d'un
aléa de connectivité environnementale (Edge 530 ↔ téléphone), déjà documenté au point 2 ci-dessus.
Le module `DebugStatus` ayant rempli son rôle de diagnostic, il a été entièrement retiré une fois
la cause confirmée et corrigée ; seul le paramètre `forecast_hours=6` (correctif permanent) a été
conservé.

**Leçon retenue** : les tests automatisés (simulateur) ne peuvent pas détecter un dépassement du
budget mémoire réel du Background Service ni un problème de connectivité réelle — seule la
validation sur appareil physique (§8) l'a révélé. Un module de diagnostic temporaire affichant le
code d'erreur réel directement à l'écran (plutôt que le "N/D" générique) a permis d'isoler la
cause en quelques itérations plutôt que de deviner à l'aveugle, avant d'être retiré une fois son
rôle rempli.

## 12. Reprise du § 11 : N/D persistant malgré Bluetooth connecté — investigation interrompue, état à reprendre

**Contexte** : après le retrait du module `DebugStatus` (§11), nouveau signalement en conditions
réelles : "N/D" persistant malgré un téléphone connecté en Bluetooth avec Garmin Connect Mobile
actif en arrière-plan, cette fois **pendant une activité enregistrée** (donc GPS actif, `compute()`
bien appelé — écarte l'hypothèse d'un simple défaut de rafraîchissement de l'écran hors activité).

**Démarche reprise** : réintroduction de `DebugStatus` (même mécanisme qu'au §11 : code
label/value réparti pour éviter la troncature) + branchement dans `EnvironmentalBackgroundDelegate`
et `OpenMeteoAirQualityClient`.

**Étape 1 — code obtenu `-999` (jamais exécuté) sur les deux apps, y compris `F-1 B-1`** (aucune
valeur du tout en mémoire, donc `recordBaseline()` — première ligne de `onTemporalEvent()` —
n'avait **jamais tourné** depuis la réinstallation). Diagnostic : `onTemporalEvent()` du Background
Service ne s'est pas déclenché du tout depuis le sideload.

**Hypothèse retenue** : la garde `if (Background.getTemporalEventRegisteredTime() == null)` dans
`AirQualityFieldApp.initialize()`/`PollenFieldApp.initialize()` (ajoutée pour le correctif "premier
relevé immédiat", cf. commit dédié) ne se déclenche qu'à la **toute première** inscription d'un
événement temporel pour cet ID d'application. Or cette inscription est un état **système**,
indépendant du binaire `.PRG` : elle persiste à travers les réinstallations par sideload. Comme
l'app avait déjà été inscrite lors des sessions de test précédentes, la réinstallation ne redéclenche
plus le relevé immédiat — elle dépend de l'échéance déjà programmée par le tout premier lancement
(potentiellement très ancienne/passée pendant que l'appareil était éteint, avec un comportement de
rattrapage au redémarrage non garanti par la documentation `Toybox.Background`).

**Étape 2 — expérimentation** : `Background.registerForTemporalEvent(Time.now())` rendu
**inconditionnel** (à chaque `initialize()`, plutôt que seulement si aucun événement n'est déjà
enregistré) pour forcer un relevé immédiat à chaque réinstallation de debug. **Risque identifié a
posteriori** : la documentation `Toybox.Background` interdit plus d'un enregistrement par tranche de
5 minutes, sauf pour l'inscription réellement première — `initialize()` s'exécute à chaque
(re)chargement de l'app (pas seulement une fois par activité), donc cet appel inconditionnel peut
violer cette règle dès qu'il est ré-exécuté deux fois en moins de 5 minutes.

**Symptôme suivant** : après ce second déploiement, les deux champs affichent le **logo de
l'application à la place d'une valeur** — signe classique côté Garmin d'un champ de données qui n'a
pas pu se charger/s'est arrêté sur erreur. Un redémarrage complet de l'appareil (pas juste un
débranchement USB) puis un retrait/ré-ajout du champ sur l'écran de données n'ont **pas** résolu le
symptôme.

**Piste secondaire trouvée, non confirmée** : `Garmin/Debugging/Saved/err_log_101.txt` et
`err_log_102.txt` contiennent deux crashs firmware (`"error_cause":"RTL Trap"`) avec une signature
**identique** (mêmes adresses de fonction, même `RTL Error Number: 6E5D8024`), horodatés à quelques
minutes des deux derniers redéploiements (`19:25:29` et `19:59:21` le 2026-08-05). **Point notable** :
`"Task Name":"SYC main"` — la tâche système de synchronisation/stockage de masse, pas la tâche `IQ`
qui exécute les apps Connect IQ. Cela pourrait indiquer un accroc du firmware pendant le traitement
du transfert USB des `.PRG` plutôt qu'un crash de notre code Monkey C — mais la corrélation
temporelle avec nos deux changements de code (garde conditionnelle vs inconditionnelle sur
`registerForTemporalEvent`) est troublante et n'a pas été départagée. Les fichiers
`Garmin/Apps/Media/AeroPollenAir.PRG`/`AeroPollenPollen.PRG` montrent un traitement réussi peu après
chaque crash (nouveaux horodatages cohérents), ce qui suggère que l'app a bien fini par s'installer
malgré le crash `SYC`.

**État du code au moment de l'arrêt (2026-08-05, non commité sur `fix/immediate-first-refresh`)** :
- `barrel/AeroPollenCore/source/DebugStatus.mc` : **réintroduit** (nouveau fichier, non commité).
- `barrel/AeroPollenCore/source/EnvironmentalBackgroundDelegate.mc` : appelle
  `DebugStatus().recordBaseline()`/`.record(AeroPollenCore.DEBUG_NO_GPS_FIX)`.
- `barrel/AeroPollenCore/source/OpenMeteoAirQualityClient.mc` : appelle `DebugStatus().record(responseCode)`
  dans `onResponse()`, en plus du correctif permanent `forecast_hours=6` (à conserver).
- `aeropollen-air-quality-field/source/AirQualityFieldView.mc` et
  `aeropollen-pollen-field/source/PollenFieldView.mc` : `onUpdate()` affiche le code de debug
  (label/value) à la place de "N/D" quand `_reading.isUnavailable()`.
- `aeropollen-air-quality-field/source/AirQualityFieldApp.mc` et
  `aeropollen-pollen-field/source/PollenFieldApp.mc` : `Background.registerForTemporalEvent(Time.now())`
  **inconditionnel** (garde `if (getTemporalEventRegisteredTime() == null)` retirée) — **suspect
  principal pour le crash `SYC`, à revenir à la version gardée avant toute nouvelle investigation**.

**Pistes à explorer la prochaine fois, dans l'ordre suggéré** :
1. Revenir à la garde conditionnelle sur `registerForTemporalEvent` (annuler l'expérimentation de
   l'étape 2) avant de retester quoi que ce soit d'autre — c'est le changement le plus susceptible
   d'avoir causé une violation de la règle des 5 minutes.
2. Tester un déploiement qui **ne touche pas** au code de l'app (ex. copier un fichier bidon dans
   `Garmin/Apps/`) pour voir si un crash `SYC main` identique se reproduit uniquement à cause du
   transfert USB — isolerait le sideload lui-même comme cause, indépendamment de notre code.
3. Tester si le symptôme "logo à la place de la valeur" apparaît **même sans** `DebugStatus` (avec
   le build de production propre du §11) après une réinstallation — isolerait le code de debug
   réintroduit comme cause plutôt que le sideload en général.
4. Si le logo persiste même avec un build propre : envisager une désinstallation complète
   (retrait de l'app via le menu Garmin) suivie d'une réinstallation fraîche plutôt qu'un simple
   écrasement du `.PRG`, pour repartir d'un état système totalement vierge (aucun événement
   temporel déjà enregistré, aucun cache Storage résiduel).
5. Une fois le champ à nouveau fonctionnel (vraie valeur ou vrai "N/D" sans logo), reprendre le
   diagnostic du §11 : whether `-104` (Bluetooth) est toujours le code obtenu malgré un téléphone
   connecté — creuser alors spécifiquement pourquoi `Communications.makeWebRequest` échoue en BLE
   au moment précis du réveil programmé, malgré une connexion visiblement active côté téléphone
   (piste plausible, non vérifiée : le rayon Bluetooth de l'Edge peut être mis en veille par
   l'appareil entre les activités/déplacements, indépendamment de l'état affiché dans Garmin
   Connect Mobile).

**Reprise 2026-08-07 — étape 1 exécutée, hypothèse principale infirmée** : la garde conditionnelle
`if (Background.getTemporalEventRegisteredTime() == null)` a été restaurée dans les deux
`initialize()` (annulation de l'expérimentation `Time.now()` inconditionnelle), build recompilé et
redéployé. **Le logo persiste malgré tout**, à l'identique, dès ce premier redéploiement.

Vérification des `err_log_*.txt` : un nouveau crash firmware (`err_log_104.txt`, `2026-8-7 10:2:19`,
quelques minutes avant le traitement réussi de l'app à `10:09`) présente le **même
`RTL Error Number":"6E5D8024"`** que les deux crashs du 5 août (`err_log_101`/`102`), mais avec
`"Task Name":"CDP main"` cette fois (au lieu de `"SYC main"`) — tâche système différente à chaque
occurrence, backtrace (adresses de fonction) différent aussi. Un troisième fichier,
`err_log_103.txt` (`2026-8-5 20:18:14`), correspond très probablement au redémarrage manuel de
l'appareil effectué pendant la session précédente (`error_cause":"8"`, tous les registres à zéro —
signature d'un reset, pas d'un crash applicatif).

**Interprétation** : puisque la garde bloque très probablement le rappel de
`registerForTemporalEvent` sur cet appareil (l'inscription n'est plus `null` depuis les tests
précédents — cf. hypothèse de persistance système au §12), notre code n'a quasiment rien fait de
différent lors de ce redéploiement, et pourtant le crash `6E5D8024` s'est quand même produit. Ceci
**infirme l'hypothèse principale retenue à l'étape 2** (l'appel inconditionnel comme cause directe
du crash) — le crash semble plutôt corrélé au **processus de sideload/traitement USB du `.PRG`**
lui-même (tâches système `SYC`/`CDP`, jamais la tâche `IQ` qui exécute le code Monkey C), indépendamment
de notre code applicatif. Reste à déterminer si ce crash récurrent au sideload est lui-même la cause
du symptôme "logo", ou un phénomène parallèle sans rapport (le firmware semble de toute façon finir
par installer l'app malgré le crash, comme noté au paragraphe précédent).

**Étape 3 exécutée — deuxième hypothèse infirmée** : build de production reconstruit sans aucun
appel à `DebugStatus` (fichier conservé mais totalement déréférencé dans
`EnvironmentalBackgroundDelegate`, `OpenMeteoAirQualityClient`, `AirQualityFieldView`,
`PollenFieldView` — modifications non commitées, cf. état du code ci-dessous), redéployé. **Le logo
persiste identiquement.**

**Bilan à ce stade** : les deux causes candidates issues du code applicatif (registration
inconditionnelle, module de diagnostic) sont maintenant **toutes les deux écartées**. Le symptôme
"logo" se reproduit à l'identique sur trois variantes de code différentes (diagnostic complet,
diagnostic + garde restaurée, aucun diagnostic). Combiné à la récurrence du crash firmware
`6E5D8024` à chaque sideload (tâche système différente à chaque fois, jamais la tâche `IQ`), l'hypothèse
la plus probable est désormais que **le sideload/traitement USB du `.PRG` corrompt lui-même
l'installation** (Storage résiduel invalide, état système persistant incohérent, ou bug firmware du
traitement), indépendamment du contenu du code Monkey C déployé. Prochaine étape suggérée : étape 4
du plan (désinstallation complète via le menu Garmin, pas un simple écrasement du `.PRG`) pour
repartir d'un état système totalement vierge.

**Étape 4 exécutée — symptôme "logo" résolu**. Le menu Connect IQ de l'appareil ne liste pas les
apps sideloadées (pas de "Désinstaller" disponible depuis l'UI Garmin) : désinstallation faite
manuellement via USB, en supprimant `Garmin/Apps/Media/AeroPollen*.PRG` et
`Garmin/Apps/DATA/AeroPollen*.{DAT,IDX,IMT}`. En tentant en plus un "redémarrage complet" pour
repartir d'un état vraiment vierge, l'utilisateur a involontairement déclenché un **reset usine
complet** de l'appareil (incident collatéral, cf. paragraphe suivant). Sideload frais du build
propre sur cet état vierge : **le champ affiche "N/D" normalement, plus de logo.**

**Conclusion sur le symptôme "logo"** : c'était un problème d'**état système résiduel accumulé par
les écrasements successifs du `.PRG`** au fil des tests (Storage et/ou registration d'événement
temporel incohérents), pas un bug de code. Les deux hypothèses de code testées aux étapes 2 et 3
(registration inconditionnelle, module `DebugStatus`) étaient toutes les deux de fausses pistes —
seule une réinstallation complète (pas un simple écrasement) a résolu le symptôme. **Point important
pour la suite** : ne plus jamais se contenter d'écraser le `.PRG` pendant les prochaines
itérations de debug si le symptôme "logo" réapparaît — repartir d'une désinstallation complète
directement.

**Incident collatéral — reset usine accidentel** : le "redémarrage complet" demandé s'est avéré être
un reset usine, cassant le pairage Bluetooth (résolu en oubliant l'appareil côté Garmin Connect
Mobile *et* côté Bluetooth du téléphone, puis en le réappairant comme un appareil neuf — étape
souvent oubliée) et effaçant les profils d'activité personnalisés. Recherche confirmée : l'Edge 530
n'a **pas** de sauvegarde cloud des profils d'activité/écrans de données dans Garmin Connect
(contrairement à certaines montres Forerunner récentes qui ont un "Back Up & Restore" — absent du
menu GCM pour ce modèle, vérifié par l'utilisateur). Profils recréés manuellement sur l'appareil.

**Instrumentation `DebugStatus` étendue** : suite à une demande explicite de disposer de vraies
traces plutôt que de retester à l'aveugle, `DebugStatus` propose désormais `checkpoint(stage)` et
`recordException(stage, ex)` en plus de `record(code)`/`recordBaseline()` :
- Chaque étape du cycle de vie (`initialize`, `getInitialView`, `onLayout`, `compute`, `onUpdate`)
  est enveloppée dans un `try/catch` qui pose un checkpoint avant/après et capture le message de
  toute exception interceptée, via `Storage` (seul canal qui survit à un crash, écrit en
  synchrone).
- `onUpdate()` ne laisse plus jamais rien remonter jusqu'à l'OS : en cas d'exception, le champ
  affiche directement `checkpoint()`/message d'erreur au lieu de déclencher le logo —
  auto-diagnostic sans dépendre d'un outil externe.
- Recherché et confirmé écarté comme piste : l'ERA (Exception Reporting Tool) de Garmin ne couvre
  que les apps publiées sur le store, pas les apps sideloadées avec clé développeur. Les fichiers
  `Storage` bruts (`Garmin/Apps/DATA/<App>.DAT`) sont chiffrés/opaques (vérifié via `strings`/`xxd`
  sur l'appareil réel — aucun texte exploitable), illisibles depuis le PC. Aucune API Monkey C ne
  permet d'écrire dans un fichier de log arbitraire ni dans les `err_log_*.txt` firmware (ceux-ci
  sont générés par l'OS pour des crashs natifs, hors sandbox de l'app). La seule vraie fenêtre
  d'observation reste l'affichage sur le champ lui-même.
- Le code diagnostic du service en arrière-plan (`debug.readCode()`) est réaffiché dans le label
  quand `_reading.isUnavailable()`, sans casser l'affichage `N/D` réel exigé par FR-005 — répond
  maintenant au problème *original* du §11/§12 (le "N/D" persistant malgré Bluetooth connecté),
  maintenant que le logo n'y fait plus écran.

**Retour terrain post-logo — diagnostic complet obtenu** : une fois le logo résolu (§ précédent), le
champ a d'abord affiché `-999` (jamais exécuté, comme au tout début de ce §12) puis, après un
nouveau cycle, `400` avec un corps de réponse vide (`value -`) — première hypothèse ("reason" JSON
d'Open-Meteo) infirmée sur le terrain, remplacée par un dump générique type+contenu
(`describeResponseData`) dans `OpenMeteoAirQualityClient.onResponse()`, indépendant de toute
supposition sur la structure de la réponse. Requête elle-même revérifiée valide via `curl` direct
contre l'API avec des coordonnées Paris (200 OK), donc le `400` ponctuel n'était pas un défaut de
formatage de notre requête.

**Cycle suivant — retour au problème d'origine du §11** : les deux apps affichent maintenant
**`-104` (`BLE_CONNECTION_UNAVAILABLE`)**, avec un corps de réponse vide/absent (cohérent : la
requête échoue avant tout envoi HTTP réel). Confirme l'hypothèse retenue en fin de §12 : le
Bluetooth peut apparaître "connecté" côté Garmin Connect Mobile sans que le canal de données BLE
soit disponible à l'instant précis où `Background.onTemporalEvent()` se déclenche. Point
d'observation : le code obtenu **varie d'un cycle à l'autre** (`-999` → `400` → `-104`) sur la même
session de test, cohérent avec un phénomène transitoire côté BLE/négociation plutôt qu'une panne
permanente.

**`phoneConnected` confirme le diagnostic** : `System.getDeviceSettings().phoneConnected` capturé
juste avant chaque tentative réseau. Résultat terrain : `-104 P0` — le téléphone était bien vu comme
**déconnecté par la montre à l'instant précis** de la tentative (pas un canal BLE qui refuse les
données malgré un état "connecté"). Confirme une coupure BLE transitoire réelle, cohérente avec
l'alternance observée sur la session (`-999` → `400` → `-104` → **succès (`34`/`7`)** → `-104` à
nouveau) : le service fonctionne, la connectivité BLE fluctue.

**Premières vraies valeurs obtenues** : `34` (qualité de l'air) et `7` (pollen), confirmant que
toute la chaîne (registration, GPS, requête réseau, parsing, cache, rendu) fonctionne de bout en
bout une fois l'appareil dans un état sain.

**Correctif retry ajouté** : `OpenMeteoAirQualityClient.onResponse()` reprogramme le prochain
réveil dans `RETRY_INTERVAL_SECONDS` (5 min, le minimum documenté entre deux inscriptions
`Background.registerForTemporalEvent()`) plutôt que d'attendre le cycle normal de 15 min
(`REFRESH_INTERVAL_SECONDS`), spécifiquement sur `Communications.BLE_CONNECTION_UNAVAILABLE`
(-104) — remplace l'inscription déjà posée en tête d'`onTemporalEvent()`, la dernière avant
`Background.exit()` faisant foi. 22+23 tests toujours au vert après ce changement.

**Amélioration UX ajoutée (demande terrain 2026-08-07)** : les deux champs affichent désormais une
lettre de catégorie A-F à côté de la valeur numérique brute :
- Air : mappage direct sur les 6 paliers officiels EAQI (Agence Européenne de l'Environnement).
- Pollen : seuils génériques **approximatifs** assumés (aucune échelle officielle unique par type
  de pollen), volontairement bas pour ne pas sous-estimer les espèces très allergisantes à faible
  seuil (ambroisie, armoise) — `pollenScoreGlobal` étant déjà un maximum entre espèces, pas une
  moyenne.
Voir `contracts/garmin-datafields.md` (mis à jour) pour le détail des paliers.

**État à ce stade (2026-08-07, non commité)** : la chaîne complète fonctionne sur le terrain.
Reste ouvert : observer sur la durée si le retry à 5 min réduit effectivement la fréquence/durée
des `N/D` liés au `-104`, et si le retrait progressif du code de diagnostic (`DebugStatus` et ses
points d'appel) peut être planifié maintenant que le symptôme "logo" et le `-104` sont tous deux
expliqués.

**Rappel** : les deux PR (#8 et son équivalent pour le fix mémoire) restent **volontairement
ouvertes**, non mergées — investigation en cours, rien n'est prêt à merger tant que le symptôme
"logo" n'est pas résolu.
