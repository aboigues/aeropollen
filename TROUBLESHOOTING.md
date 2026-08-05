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

**Cause réelle identifiée** : le script relançait Xvfb + simulateur sur le **même numéro de
display** (`:99`) à chaque tentative, après avoir tué les process précédents via `pkill`. Si
Xvfb ne nettoie pas parfaitement son verrou/socket en mourant (`pkill` n'est pas un arrêt
propre), le Xvfb suivant sur le même display peut échouer à démarrer silencieusement, tandis que
le script croit qu'il est prêt car le fichier socket `/tmp/.X11-unix/X99` — en réalité périmé,
laissé par l'instance précédente — existe déjà. Le simulateur lancé ensuite ne peut alors pas se
connecter à un serveur X fonctionnel et n'ouvre jamais son port 1234. Cohérent avec le pattern
exact observé (1re application : display jamais utilisé auparavant, fonctionne toujours ; 2e
application : display réutilisé, échoue).

**Correction appliquée** : chaque tentative (toutes applications et essais confondus, au sein
d'un même run) utilise désormais un **numéro de display jamais réutilisé**
(`display_counter` incrémenté à chaque essai) — élimine la possibilité de collision avec un
socket/verrou périmé, sans dépendre d'un nettoyage parfait de l'instance précédente. Diagnostic
supplémentaire ajouté : en cas d'échec, le contenu de `xvfb-N.log` et `simulator-N.log` est
affiché, pour ne plus jamais avoir à re-deviner à l'aveugle si ça se reproduit.

**Statut** : correction basée sur une analyse du log CI réel (PR #8, 2026-08-05), pas encore
reconfirmée par un nouveau run CI au moment de la rédaction — à vérifier au prochain push. Non
revalidée en local (session WSL dans un état instable ce jour-là, indépendamment de ce bug —
voir les segfaults `dmesg` mentionnés plus haut, cause distincte non résolue).
