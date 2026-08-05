# Recherche (Phase 0) : Champ de Données Environnementales Garmin

**Feature**: `001-pollen-air-datafield` | **Date** : 2026-08-04

Ce document consolide les inconnues techniques du contexte de planification et les décisions
prises pour les résoudre, avec leur justification et les alternatives écartées, conformément au
Principe III (Dépendances Récentes et Stables) de la constitution : chaque version citée a été
vérifiée activement le 2026-08-04 plutôt que déduite de connaissances mémorisées.

## 1. Plateforme cible et type d'application

**Decision**: Application Garmin Connect IQ de type **Data Field** (champ de données), ciblant
en priorité l'appareil de test **Garmin Edge 530**, qui supporte le **Connect IQ API Level 3.3**
(vérifié sur la page des appareils compatibles de developer.garmin.com).

**Rationale**: La spécification demande explicitement un « data field » affiché sur un
« compteur GPS » (Edge 530). Le type d'application « Data Field » est le seul type Connect IQ
conçu pour s'intégrer aux écrans d'activité existants d'un compteur GPS Garmin, ce qui
correspond directement à FR-006 (champs de données distincts sélectionnables par l'utilisateur
via la configuration standard du compteur).

**Alternatives considered**:
- *Widget* : rejeté — les widgets s'affichent hors activité, ce qui ne correspond pas à un
  usage « pendant une sortie » (User Stories 1-3).
- *Watch App autonome* : rejeté — nécessiterait une navigation manuelle hors des écrans
  d'activité standard, dégradant l'expérience de consultation rapide en selle (FR-008).

## 2. Langage et chaîne d'outils

**Decision**: **Monkey C**, compilé avec le **Connect IQ SDK 9.2.0** (version installée et
vérifiée localement le 2026-08-04 via `version.txt` du SDK — `connectiq-sdk-win-9.2.0-2026-06-09`,
plus récente que le 8.3.x initialement identifié par recherche web lors de `/speckit-plan`), en
ciblant un **minApiLevel 3.3.0** pour garantir la compatibilité avec l'Edge 530.

**Rationale**: Monkey C est l'unique langage supporté par le SDK Connect IQ pour produire des
applications exécutables sur un appareil Edge. Le SDK 9.2.0 reste rétrocompatible et capable de
compiler pour l'API Level 3.3 requis par l'Edge 530, tout en bénéficiant des correctifs de
sécurité et de stabilité les plus récents de la chaîne d'outils (Principe III). La vérification
directe de la version installée (plutôt que la recherche web antérieure) est la source de vérité
retenue, conformément à l'esprit du Principe III.

**Alternatives considered**: Aucune — il n'existe pas de langage alternatif supporté nativement
par le SDK Connect IQ pour ce type de déploiement.

## 3. Accès réseau depuis l'appareil

**Decision**: Les appels réseau vers la source de données externe sont effectués via
**`Toybox.Communications.makeWebRequest()`** en HTTPS, déclenchés depuis un **Background Service**
(`ServiceDelegate` avec `onTemporalEvent()`), et non depuis la méthode `compute()` de la vue du
champ de données elle-même.

**Rationale**: `compute()` est appelée à haute fréquence par le firmware et doit rester non
bloquante pour ne jamais dégrader l'enregistrement GPS (FR-007, SC-004). Un service en arrière-
plan déclenché à intervalle régulier (≥ 15 min, FR-003/SC-002) est le mécanisme recommandé par
Garmin pour effectuer des requêtes réseau sans impacter le rendu de l'écran d'activité. Le
résultat est ensuite persisté et simplement lu par `compute()`.

**Alternatives considered**:
- *Appel réseau direct dans `compute()`* : rejeté — bloquant et interdit par le modèle
  d'exécution Connect IQ, violerait directement FR-007.
- *Polling manuel déclenché par l'utilisateur* : rejeté — contraire à User Story 3 qui exige une
  actualisation automatique sans intervention utilisateur.

## 4. Source de données externe

**Decision**: **Open-Meteo Air Quality API** (`https://air-quality-api.open-meteo.com/v1/air-quality`),
interrogée avec la position géographique courante, en récupérant :
- l'**indice européen de qualité de l'air (European AQI)** pour la valeur « qualité de l'air » ;
- les six variables de pollen disponibles pour l'Europe : **aulne (alder), bouleau (birch),
  graminées (grass), armoise (mugwort), olivier (olive), ambroisie (ragweed)**, utilisées pour
  calculer un score global agrégé et exposer le détail par type (FR-002/FR-002a).

**Rationale**: Correspond explicitement à l'exemple cité dans la description de la
fonctionnalité (« une API externe comme open-meteo.com »). Aucune clé API n'est requise pour un
usage non commercial, ce qui réduit la surface d'exposition de secrets sur l'appareil
(Principe II). La résolution géographique (~11 km sur le domaine européen) est cohérente avec
l'hypothèse documentée dans la spécification.

**Alternatives considered**: Aucune autre source n'a été évaluée — le choix d'Open-Meteo est une
contrainte explicite de la description de la fonctionnalité, pas une décision d'architecture
libre.

**Limite connue** (documentée aussi dans les Assumptions du spec) : les données de pollen ne
sont disponibles que pour l'Europe et uniquement en saison pollinique ; hors de cette zone/
période, FR-005 impose l'état « indisponible » explicite.

## 5. Persistance locale sur l'appareil

**Decision**: Mise en cache du dernier relevé environnemental (valeurs + position + horodatage)
via **`Toybox.Application.Storage`** (magasin clé-valeur local de l'appareil), sans base de
données ni fichier structuré.

**Rationale**: Les appareils Connect IQ de la génération Edge 530 (API Level 3.3) exposent
`Application.Storage` comme mécanisme de persistance standard, suffisant pour stocker un seul
relevé courant. Cela permet au Background Service d'écrire le résultat et à la vue du champ de
données de le lire sans dépendance réseau synchrone.

**Alternatives considered**: Stockage de fichier brut via `Toybox.System.FileSystem` — rejeté,
inutilement complexe pour un unique enregistrement structuré simple.

## 6. Stratégie de test

**Decision**: Trois niveaux de test, alignés sur les Principes IV et V de la constitution :
1. **Tests unitaires** : framework natif **`Toybox.Test`** (fonctions annotées `(:test)`),
   exécutés via `monkeydo` en ligne de commande ou dans le simulateur Connect IQ, écrits avant le
   code correspondant (parsing des réponses Open-Meteo, calcul du score global, logique de
   fraîcheur/obsolescence).
2. **Tests d'intégration** : scénarios de bout en bout exécutés dans le **simulateur Connect
   IQ** (requête réseau simulée → cache → affichage), couvrant chaque partie du système
   (service réseau, cache de stockage, les deux vues de champ de données, gestion d'erreur),
   conformément au Principe V.
3. **Validation manuelle sur l'appareil physique de test** (Garmin Edge 530 réel), pour vérifier
   le rendu à l'écran et l'absence de dégradation de l'enregistrement GPS (FR-007, SC-004), en
   complément des tests automatisés — le SDK Connect IQ ne permet pas d'automatiser entièrement
   les tests sur matériel physique.

**Rationale**: Le SDK Connect IQ ne fournit pas de framework d'automatisation de bout en bout
sur device réel ; combiner tests unitaires automatisés, tests d'intégration en simulateur et
validation manuelle ciblée est la pratique reconnue par la documentation officielle Garmin pour
respecter l'exigence de test-first et de couverture d'intégration exhaustive sans dépendre d'un
outillage qui n'existe pas pour cette plateforme.

**Alternatives considered**: Tests uniquement manuels sur device — rejeté, incompatible avec le
Principe IV (Test-First) et le Principe V (tests d'intégration systématiques).

## 7. Gestion des erreurs réseau et de la disponibilité des données

**Decision**: Le Background Service interprète le code de réponse HTTP et les erreurs de
`makeWebRequest()` ; en cas d'échec, d'absence de téléphone apparié, ou d'absence de donnée pour
la zone/saison, le cache est marqué explicitement **« indisponible »** (et non silencieusement
laissé à son ancienne valeur), conformément à FR-005 tel que confirmé par l'utilisateur.

**Rationale**: Décision utilisateur explicite lors de la clarification de la spécification
(FR-005) : un état « indisponible » clair est préféré à l'affichage d'une ancienne valeur
potentiellement trompeuse.

**Alternatives considered**: Conserver la dernière valeur connue avec indicateur d'obsolescence
— explicitement écarté par l'utilisateur lors de `/speckit-specify`.

## 8. Sécurité (Principe II)

**Decision**: Toutes les communications utilisent HTTPS (imposé par `Communications.makeWebRequest`
et par l'endpoint Open-Meteo lui-même). Aucune clé API ni secret n'est stocké sur l'appareil
(usage non commercial). Les réponses JSON externes sont validées (présence des champs attendus,
types numériques) avant toute utilisation ; toute réponse malformée déclenche l'état
« indisponible » plutôt qu'un plantage ou une valeur incohérente affichée à l'utilisateur.

**Rationale**: Respecte directement le Principe II (prévention active des erreurs de traitement
d'entrées externes, absence d'exposition de données sensibles) sans complexité additionnelle,
puisque l'API cible ne requiert pas d'authentification en usage non commercial.

## 9. Architecture multi-applications et Barrel partagé (découvert à l'implémentation)

**Decision**: FR-006 (confirmé par l'utilisateur : « champs distincts sélectionnables ») exige
en réalité **deux applications Connect IQ séparées** — `aeropollen-air-quality-field` (type `datafield`) et
`aeropollen-pollen-field` (type `datafield`) —, chacune avec son propre `manifest.xml` et son propre
`<iq:application>`. La documentation officielle du SDK (`Manifest_and_Permissions.html`,
vérifiée le 2026-08-04 dans le SDK 9.2.0 installé localement) confirme qu'**un manifeste
Connect IQ ne peut déclarer qu'un seul `<iq:application>`** : le sélecteur de champs de Garmin
liste des applications installées, pas des vues internes à une même application. Le code commun
(entités, cache, client Open-Meteo, Background Service) est factorisé dans un **Monkey Barrel**
partagé nommé `AeroPollenCore`, référencé par les deux applications via `barrelPath` dans
leurs `monkey.jungle` respectifs et déclaré dans leurs `manifest.xml` via `<iq:barrels>`
(mécanisme officiel « Shareable Libraries », vérifié dans `Shareable_Libraries.html` et
`Jungle_Reference.html` du même SDK).

**Conséquence sur le cache** : `Application.Storage` est isolé par application installée (« This
data is only available to the application », `Persisting_Data.html`). Les deux applications ne
peuvent donc pas partager une seule instance de cache ni un seul appel réseau : **chacune exécute
son propre Background Service et son propre appel HTTPS vers Open-Meteo**, en utilisant le même
code de client (`OpenMeteoAirQualityClient` du Barrel), mais chacune n'exploite que le
sous-ensemble de la réponse qui la concerne (l'European AQI pour `aeropollen-air-quality-field`, les six
variables de pollen pour `aeropollen-pollen-field`). Ceci double le nombre d'appels réseau par rapport à
l'hypothèse initiale d'un cache unique partagé (research.md §3, version précédente), mais reste
conforme à FR-003/SC-002 (chaque application actualise indépendamment au moins toutes les 15
minutes) et à FR-007 (aucun appel réseau dans `compute()`/`onUpdate()`, toujours via Background
Service).

**Rationale**: C'est la seule architecture qui satisfait à la fois FR-006 (deux champs
installables et sélectionnables indépendamment, donc deux paquets d'application distincts) et le
Principe de simplicité/fiabilité (pas de mécanisme inter-applications fragile) : la duplication
du code est évitée par le Barrel, la duplication de l'appel réseau est une conséquence
architecturale du modèle de sécurité par sandbox de Connect IQ, pas un choix de conception.

**Alternatives considered**:
- *Une seule application avec un menu de réglage pour choisir la valeur affichée* : rejeté —
  ne correspond plus au choix explicite de l'utilisateur pour FR-006 (« champs distincts »
  plutôt que « champ unique combiné »).
- *Complications Connect IQ (API ≥ 4.0) pour partager la donnée entre les deux apps* : rejeté
  pour cette version — mécanisme conçu pour la diffusion vers des cadrans de montre, complexité
  et fragilité (dépendance à l'ordre d'installation/exécution des deux apps) disproportionnées
  par rapport au gain (éviter un doublon d'appel réseau à faible fréquence, ≤ toutes les 15 min).

## 10. Budget mémoire réel de l'Edge 530 (vérifié à l'implémentation)

**Decision**: Le fichier `compiler.json` de l'appareil `edge530` (SDK 9.2.0) confirme les
budgets mémoire suivants par type d'application : `datafield` = 131072 octets (128 Ko),
`background` = 32768 octets (32 Ko), `widget`/`watchApp` = 1048576 octets (1 Mo). Le service en
arrière-plan (`EnvironmentalBackgroundDelegate`, code annoté `(:background)`) doit donc rester
particulièrement compact (32 Ko), ce qui renforce le choix d'un client Open-Meteo minimaliste
sans dépendance tierce (research.md §2).

**Rationale**: Cette valeur, auparavant qualifiée d'« à confirmer au moment du build » (voir
Synthèse ci-dessous, version initiale), est désormais connue précisément et vérifiée
directement depuis le SDK installé plutôt que déduite.

## 11. Invocation du SDK depuis WSL (note d'implémentation)

**Decision**: Le SDK Connect IQ 9.2.0 étant installé côté Windows, les scripts `monkeyc`/
`barrelbuild` fournis (wrappers Bash à fins de ligne CRLF) sont invoqués directement via
`java -cp monkeybrains.jar com.garmin.monkeybrains.Monkeybrains` (compilation d'applications) ou
`com.garmin.monkeybrains.MonkeyBarrelEntry` (compilation de Barrels) depuis le JDK Linux de
l'environnement WSL. La résolution des appareils installés (`~/.Garmin/ConnectIQ/Devices/`)
nécessite une **copie réelle** des fichiers depuis
`/mnt/c/Users/PC/AppData/Roaming/Garmin/ConnectIQ/` — un lien symbolique Linux pointant vers ce
chemin `/mnt/c/...` n'est pas correctement résolu par la JVM Linux dans cet environnement WSL
(la commande `-d edge530` échoue avec « Invalid device id » via un lien, mais réussit avec une
copie). Une clé de développement locale (`developer_key.der`) est générée via OpenSSL pour la
signature des builds de test, conformément à la documentation officielle (`-y` du compilateur).

**Rationale**: Documenté pour la reproductibilité du build sans dépendre du simulateur GUI
Windows (`simulator.exe`, `shell.exe`) pour la simple vérification de compilation, qui reste
néanmoins nécessaire pour l'exécution réelle des tests `Toybox.Test` (Principe IV) — voir
quickstart.md pour la procédure de validation manuelle sur Windows/appareil physique.

**Piège rencontré — référence croisée Barrel/(:background)** : lorsqu'une application référence,
depuis sa classe `Application.AppBase`, à la fois une vue d'écran normale (ex.
`AirQualityFieldView`) et une classe annotée `(:background)` **provenant d'un Barrel**
(`AeroPollenCore.EnvironmentalBackgroundDelegate`), le compilateur 9.2.0 rejette la référence
à la vue avec l'erreur « Value 'X' not available in all function scopes », même si la classe
`AppBase` est elle-même annotée `(:background)` (pattern pourtant utilisé avec succès par
l'exemple officiel `samples/BackgroundTimer`, qui ne traverse pas de Barrel). Contournement
vérifié : annoter la méthode `getInitialView()` avec `(:typecheck(disableBackgroundCheck))`
(annotation vue dans `samples/BackgroundTimer/source/BackgroundTimerApp.mc` pour un cas
apparenté). Ce contournement est appliqué de façon identique dans les deux applications
(`aeropollen-air-quality-field`, `aeropollen-pollen-field`).

## 12. Déclenchement de l'actualisation (User Story 3) : limite de la plateforme

**Decision**: Le seul mécanisme de réveil en arrière-plan disponible dans Connect IQ est
`Background.registerForTemporalEvent()` (research.md §3), strictement **temporel** — il
n'existe aucun événement natif « déplacement significatif » ou « delta de distance » pour
réveiller un Background Service. `EnvironmentalBackgroundDelegate` déclenche donc une
actualisation à un intervalle fixe (900 s = 15 min, FR-003/SC-002), à chaque réveil,
inconditionnellement.

**Rationale**: Aux vitesses typiques d'une sortie vélo (15-30 km/h), 15 minutes correspondent
déjà à 4-8+ km parcourus : l'exigence de l'Acceptance Scenario 1 de User Story 3
(« le temps écoulé OU la distance parcourue dépasse le seuil ») est donc satisfaite en pratique
par le seul déclenchement temporel, sans mécanisme dédié au suivi de distance. Ajouter un tel
mécanisme nécessiterait soit un réveil bien plus fréquent que 15 minutes (contraire à FR-003 et
à la préservation de la batterie, Assumptions de spec.md), soit un relais depuis le premier
plan — impossible sans enfreindre FR-007 (aucun appel réseau dans `compute()`/`onUpdate()`).

**Alternatives considered**: Suivi de la distance parcourue dans la vue (foreground) avec
demande de réveil anticipé — rejeté, la plateforme ne propose pas d'API pour déclencher un
Background Service à la demande depuis une Vue de Data Field, seulement des évènements prédéfinis
(temporel, objectif, pas, etc., cf. `Backgrounding.html`).

## 13. SDK Connect IQ Linux natif installé (état final au 2026-08-04)

**Decision**: Le SDK Connect IQ **Linux natif** (`connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2`)
est désormais installé dans `~/.Garmin/ConnectIQ/Sdks/` (obtenu via le SDK Manager officiel de
Garmin — `https://developer.garmin.com/downloads/connect-iq/sdk-manager/connectiq-sdk-manager-linux.zip`
— exécuté dans un conteneur Docker `ubuntu:20.04` avec `libwebkit2gtk-4.0-37` système, DISPLAY
partagé avec WSLg ; la bibliothèque `libwebkit2gtk-4.0` n'est plus disponible dans les dépôts
Ubuntu 24.04, ce qui empêchait toute exécution directe sur l'hôte WSL). L'appareil `edge530` est
également installé. **La compilation (`monkeyc`, `barrelbuild`, `barreltest`) fonctionne
nativement en Bash pur depuis WSL, sans plus aucun contournement `java -cp`** (research.md §11,
devenu obsolète pour la compilation) :

```bash
SDK_LIN="$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2"
"$SDK_LIN/bin/monkeyc" -o app.prg -f monkey.jungle -d edge530 -y developer_key.der -t -l 3 -w
```

**Limite persistante — exécution réelle des tests non atteinte** : `bin/simulator` et `bin/shell`
sont bien des binaires ELF Linux natifs et établissent correctement une connexion TCP entre eux
(`127.0.0.1:1234`), mais le rendu visuel de l'écran d'appareil dans la fenêtre du simulateur ne
se termine jamais (bloqué après `Debug: SetLayout`, sans erreur), y compris depuis le même
conteneur Docker où `libwebkit2gtk-4.0` fonctionne. Cause probable : absence totale de device
GPU dans cet environnement WSL (`/dev/dri` inexistant, aucune accélération DRI3), la compilation
et le TCP fonctionnant indépendamment du rendu graphique alors que l'affichage de l'écran
simulé en dépend. `monkeydo -t` reste donc bloqué indéfiniment sans produire de résultat
PASS/FAIL. **Décision actée avec l'utilisateur** : ne pas investiguer davantage dans cet
environnement ; l'exécution réelle des tests `Toybox.Test` (Principe IV) se fera sur Windows,
où le simulateur fonctionne déjà normalement (SDK Windows déjà installé, cf. research.md §2).

**Piège rencontré (à retenir)** : les outils Garmin (`sdkmanager`, `simulator`) utilisent un
fichier verrou mono-instance (`~/garmin.connectiq.sdkmanager-<user>`, `/root/Sim-root`) créé
avec `O_CREAT|O_EXCL` ; un process tué sans un arrêt propre (`kill -9` sur le mauvais PID dans
une chaîne de wrappers Bash → binaire réel) laisse ce fichier orphelin, ce qui fait échouer
silencieusement (exit 255, aucune sortie) tout lancement suivant. Toujours supprimer ce fichier
avant de relancer après un `kill` forcé.

**Rationale**: Documenté pour que toute reprise future de ce sujet (sur cet environnement ou un
autre WSL similaire) parte de cet état précis plutôt que de refaire la même investigation.

## Synthèse des inconnues résolues

Toutes les inconnues marquées `NEEDS CLARIFICATION` dans le contexte technique initial sont
résolues par les décisions ci-dessus. Un seul point reste à confirmer au moment du build plutôt
qu'à la planification : le budget mémoire exact alloué par le firmware Edge 530 à une application
Data Field, qui est appliqué et vérifié automatiquement par le compilateur Connect IQ (erreur de
compilation en cas de dépassement) — il ne s'agit pas d'une inconnue bloquante pour la
conception, seulement d'une contrainte vérifiée à la compilation.
