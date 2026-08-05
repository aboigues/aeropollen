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

## 5. Simulateur bloqué indéfiniment après `Debug: SetLayout` — absence de GPU sous WSL

**Symptôme** : `bin/simulator` et `bin/shell` établissent correctement une connexion TCP
(`127.0.0.1:1234`), mais le rendu visuel de la fenêtre du simulateur ne se termine jamais
(bloqué après `Debug: SetLayout`, sans erreur). `monkeydo -t` reste donc bloqué indéfiniment
sans jamais produire de résultat PASS/FAIL pour les tests `Toybox.Test`.

**Cause confirmée (investiguée à deux reprises, sur deux versions de SDK, avec et sans
Docker)** : absence totale de périphérique GPU dans cet environnement WSL — `/dev/dri` et
`/dev/dxg` n'existent pas, ni sur l'hôte ni dans un conteneur Docker partageant le même display.
Le simulateur (binaire natif GTK/WebKit) dépend du rendu accéléré fourni normalement par WSLg
via Mesa/DirectX ; sans nœud de périphérique GPU, ce chemin de rendu est indisponible.

**Statut** : **non résolu sous WSL, considéré comme un mur dur.** Aucune version de SDK ni
configuration Docker ne contourne ce problème (voir §7 pour la piste écartée). L'exécution
réelle des tests `Toybox.Test` doit se faire sur Windows (simulateur natif fonctionnel) ou
directement sur l'appareil physique (voir §8).

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
mais ne fait **pas** tourner les assertions automatisées `Toybox.Test` (celles-ci nécessitent
toujours le simulateur — Windows ou un environnement WSL avec accès GPU).
