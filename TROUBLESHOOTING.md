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
