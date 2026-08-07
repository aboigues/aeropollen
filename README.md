# AeroPollen

Deux champs de données Connect IQ pour cyclocomputeurs Garmin Edge, affichant la qualité de
l'air et les niveaux de pollens à la position courante, à partir de l'[Open-Meteo Air Quality
API](https://open-meteo.com/en/docs/air-quality-api) (gratuite, sans clé requise). Développé et
validé sur **Edge 530** ; voir [Appareils pris en charge](#appareils-pris-en-charge) pour le
détail par appareil.

[![Sécurité](https://github.com/aboigues/aeropollen/actions/workflows/security.yml/badge.svg)](https://github.com/aboigues/aeropollen/actions/workflows/security.yml)
[![Tests](https://github.com/aboigues/aeropollen/actions/workflows/tests.yml/badge.svg)](https://github.com/aboigues/aeropollen/actions/workflows/tests.yml)
[![Licence : GPL v3](https://img.shields.io/badge/Licence-GPLv3-blue.svg)](LICENSE)

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Interprétation des valeurs affichées](#interprétation-des-valeurs-affichées)
- [Appareils pris en charge](#appareils-pris-en-charge)
- [Structure du projet](#structure-du-projet)
- [Prérequis](#prérequis)
- [Compilation](#compilation)
- [Installation sur l'appareil](#installation-sur-lappareil)
- [Tests](#tests)
- [Documentation](#documentation)
- [Confidentialité](#confidentialité)
- [Sécurité](#sécurité)
- [Contribuer](#contribuer)
- [Licence](#licence)

## Fonctionnalités

- **Champ « Qualité Air »** : indice européen de qualité de l'air (European AQI) à la position
  GPS courante, affiché avec une catégorie A-F pour une lecture instantanée à vélo (ex. `34 B`).
- **Champ « Pollens »** : score de pollen global (bouleau, graminées, etc.) à la position GPS
  courante, affiché avec une catégorie A-F (ex. `7 B`).
- Rafraîchissement en arrière-plan (`Background.registerForTemporalEvent`), sans appel réseau
  dans le cycle de rendu (`compute()`/`onUpdate()`), conformément aux contraintes de la
  plateforme Connect IQ (voir `specs/001-pollen-air-datafield/research.md`) — voir
  [Fréquence de rafraîchissement](#fréquence-de-rafraîchissement) pour le détail des cadences.
- Chaque champ est une application Connect IQ **installable et testable indépendamment** de
  l'autre — un `manifest.xml` Connect IQ ne peut déclarer qu'un seul `<iq:application>`.

## Interprétation des valeurs affichées

Chaque champ affiche une valeur numérique brute suivie d'une lettre de catégorie (`A` = le
meilleur, `F` = le pire), pour une lecture instantanée sans avoir à interpréter le chiffre en
roulant.

### Fréquence de rafraîchissement

| Situation | Cadence |
|---|---|
| Premier relevé après installation | Quasi immédiat (`Time.now()`, une seule fois par installation) |
| Cycle normal | Toutes les **15 minutes** (`REFRESH_INTERVAL_SECONDS`) |
| Après une coupure Bluetooth transitoire (`-104`) | Nouvel essai après **5 minutes** (`RETRY_INTERVAL_SECONDS`), au lieu d'attendre le cycle normal |

5 minutes est le **minimum imposé par la plateforme Connect IQ** entre deux inscriptions
`Background.registerForTemporalEvent` — ce n'est pas configurable en dessous. La cadence normale de
15 minutes (au lieu du minimum technique de 5) est un choix délibéré, pas une limitation : la
qualité de l'air et les pollens évoluent lentement à l'échelle d'une sortie vélo (sauf changement
de zone marqué), et rafraîchir plus souvent coûterait de la batterie et solliciterait inutilement
l'API gratuite d'Open-Meteo sans bénéfice réel sur la donnée affichée. Voir FR-003/SC-002 dans
[`specs/001-pollen-air-datafield/`](specs/001-pollen-air-datafield/) pour l'exigence associée.

### Qualité de l'air

Le chiffre est l'**Indice Européen de Qualité de l'Air (EAQI)**, tel que défini par l'Agence
Européenne de l'Environnement et renvoyé directement par
[Open-Meteo](https://open-meteo.com/en/docs/air-quality-api). C'est une échelle **officielle et
normalisée**, pas une concentration brute d'un seul polluant — la lettre correspond directement à
ses 6 paliers officiels :

| Lettre | Plage EAQI | Signification officielle |
|---|---|---|
| A | 0-19 | Bon |
| B | 20-39 | Correct |
| C | 40-59 | Moyen |
| D | 60-79 | Mauvais |
| E | 80-99 | Très mauvais |
| F | 100+ | Extrêmement mauvais |

### Pollens

Le chiffre est la concentration **maximale** parmi les 6 types de pollen suivis (aulne, bouleau,
graminées, armoise, olivier, ambroisie), en grains/m³ — pas une moyenne : un seul type élevé fait
monter le score global même si les autres sont nuls.

**Contrairement à la qualité de l'air, il n'existe pas d'échelle européenne officielle unique pour
la concentration pollinique** : les seuils "élevé"/"faible" varient réellement selon le type de
pollen (une même concentration d'ambroisie, très allergisante, n'a pas le même impact qu'une
concentration équivalente de bouleau). La lettre affichée ici repose donc sur des **paliers
génériques approximatifs**, choisis volontairement bas pour ne pas sous-estimer les espèces les
plus allergisantes à faible seuil :

| Lettre | Plage (grains/m³) |
|---|---|
| A | 0 |
| B | 1-9 |
| C | 10-29 |
| D | 30-69 |
| E | 70-149 |
| F | 150+ |

### État « N/D »

Signifie qu'aucun relevé exploitable n'est disponible en cache — jamais une ancienne valeur
périmée ni un champ vide (voir [Confidentialité](#confidentialité)). Causes possibles : aucune
position GPS acquise, ou tentative réseau échouée. Les coupures Bluetooth transitoires entre
l'appareil et le téléphone (déclenchant l'échec de la requête même quand la connexion paraît
stable) sont la cause la plus fréquente en usage réel ; un nouvel essai automatique est programmé
5 minutes après un tel échec plutôt que d'attendre le cycle normal de 15 minutes.

## Appareils pris en charge

Les manifestes déclarent les appareils Edge suivants (mêmes exigences d'API minimale). Seul
**Edge 530** est réellement compilé, testé (45 tests `Toybox.Test`, voir [Tests](#tests)) et
validé par un sideload physique — les autres sont une extension raisonnable par famille de
produit, **non vérifiée** :

| Appareil | Statut |
|---|---|
| Edge 530 | ✅ Testé (simulateur + appareil physique) |
| Edge 540, 550 | ⚠️ Déclaré, non vérifié |
| Edge 830, 840, 850 | ⚠️ Déclaré, non vérifié |
| Edge 1030 Plus, 1040, 1050 | ⚠️ Déclaré, non vérifié |
| Edge Explore 2, Edge MTB | ⚠️ Déclaré, non vérifié |

Un retour d'expérience (issue GitHub) sur un appareil non vérifié est bienvenu — voir
[Contribuer](#contribuer).

## Structure du projet

Le dépôt regroupe trois projets Connect IQ distincts, partageant du code via un Monkey Barrel :

```
barrel/AeroPollenCore/          # Monkey Barrel : entités, cache, client réseau, code partagé
aeropollen-air-quality-field/   # Application #1 : champ "Qualité de l'Air" (European AQI)
aeropollen-pollen-field/        # Application #2 : champ "Pollens" (score global)
specs/001-pollen-air-datafield/ # Spécification, plan technique, contrats, tâches
.specify/                       # Constitution du projet et outillage Spec-Driven Development
```

Chaque application Garmin (`aeropollen-air-quality-field`, `aeropollen-pollen-field`) est
installée séparément sur l'appareil et déclare sa propre dépendance vers le barrel
`AeroPollenCore` via `base.barrelPath` dans son `monkey.jungle`.

## Prérequis

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (testé avec la
  9.2.0) — Windows, macOS ou Linux (voir [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) pour les
  limitations connues sous WSL).
- L'appareil `edge530` téléchargé via le SDK Manager.
- Une clé de signature développeur locale (jamais partagée, jamais commitée) :
  ```bash
  openssl genrsa -out developer_key.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
  ```
  Les deux fichiers sont exclus par `.gitignore` — ne jamais forcer leur ajout au dépôt.

## Compilation

Compiler chaque application avec `monkeyc` en pointant sur son `monkey.jungle` — celui-ci
référence automatiquement le barrel partagé via `base.barrelPath`, il n'y a rien à compiler
séparément pour `AeroPollenCore` :

```bash
monkeyc -f aeropollen-air-quality-field/monkey.jungle -d edge530 -o AirQuality.prg -y developer_key.der -w -r
monkeyc -f aeropollen-pollen-field/monkey.jungle -d edge530 -o Pollen.prg -y developer_key.der -w -r
```

(`-r` = build de production ; retirer `-r` et ajouter `-t` pour une build incluant les tests
`Toybox.Test`, utilisée par le simulateur.)

## Installation sur l'appareil

Deux méthodes :

1. **Simulateur Connect IQ** (`monkeydo`) — nécessite un environnement graphique fonctionnel.
2. **Sideload direct** sur un Edge 530 physique, en copiant le `.prg` compilé en mode
   production dans `Garmin/Apps/` sur l'appareil connecté en USB (mode stockage de masse), puis
   en l'ajoutant depuis Menu → Profils d'activité → Écrans de données → Ajouter un champ. Voir
   [`TROUBLESHOOTING.md` §8](TROUBLESHOOTING.md#8-alternative-validée--sideload-direct-sur-lappareil-physique-edge-530)
   pour la procédure détaillée (y compris depuis WSL).

## Tests

Chaque projet embarque ses tests d'intégration (`Toybox.Test`) dans son dossier `tests/`.
Exécution via le simulateur Connect IQ (`monkeydo -t`). Fonctionne nativement sur Windows/macOS ;
sous Linux/WSL, le simulateur a besoin d'un serveur X — utiliser **Xvfb** (framebuffer virtuel
logiciel, aucun GPU requis) plutôt que le display réel. Un script prêt à l'emploi automatise
toute la procédure (Docker + Xvfb + compilation + `monkeydo -t`) :

```bash
scripts/run-tests-wsl.sh                          # toutes les applications
scripts/run-tests-wsl.sh aeropollen-pollen-field   # une seule application
```

Voir
[`TROUBLESHOOTING.md` §9](TROUBLESHOOTING.md#9-résolution-du-5--xvfb-au-lieu-du-display-réel-wslg--exécution-réelle-des-tests-obtenue)
pour le détail de la découverte et le fonctionnement exact.

**CI** : `.github/workflows/tests.yml` exécute ce même script à chaque PR, mais en mode
informatif (`continue-on-error`) — le binaire `simulator` (propriétaire Garmin) crashe parfois de
façon non déterministe sous Docker+Xvfb, y compris sur un runner fraîchement provisionné (voir
[`TROUBLESHOOTING.md` §10](TROUBLESHOOTING.md#10-scriptsrun-tests-wslsh--le-simulateur-ne-répond-plus-pour-la-2e-application-testée)).
La garantie de non-régression réelle reste l'exécution en local (fiable) et la validation sur
appareil physique.

## Documentation

- [`specs/001-pollen-air-datafield/`](specs/001-pollen-air-datafield/) — spécification complète
  (exigences, plan technique, modèle de données, contrats d'API, découpage en tâches).
- [`.specify/memory/constitution.md`](.specify/memory/constitution.md) — principes du projet :
  langue française de la documentation, sécurité et fiabilité, dépendances à jour, Test-First,
  tests d'intégration exhaustifs, gouvernance des Pull Requests.
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — journal des problèmes d'environnement/outillage
  rencontrés et de leur résolution.

## Confidentialité

La position GPS courante de l'utilisateur est transmise, en HTTPS, à l'API publique
[Open-Meteo](https://open-meteo.com/) à chaque rafraîchissement en arrière-plan (au minimum
toutes les 15 minutes pendant une activité), uniquement pour obtenir la qualité de l'air et les
niveaux de pollens à cette position. Aucune clé d'API, aucun identifiant de compte, aucune
donnée personnelle autre que la position n'est transmis. Le dernier relevé est mis en cache
localement sur l'appareil (`Application.Storage`, propre à chaque application) et n'est jamais
transmis ailleurs. Voir [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md) pour le détail.

## Sécurité

Voir [`SECURITY.md`](SECURITY.md) pour la politique de signalement de vulnérabilités et
[`SECURITY_AUDIT.md`](SECURITY_AUDIT.md) pour le dernier audit de sécurité du projet. Le
pipeline d'intégration continue GitHub Actions (`.github/workflows/security.yml`) exécute des
vérifications de sécurité automatisées à chaque Pull Request.

## Contribuer

Ce projet suit un développement piloté par les spécifications (voir `specs/` et `.specify/`).
Avant toute contribution :

1. Lire la [constitution du projet](.specify/memory/constitution.md) — en particulier le
   principe Test-First (cycle Red-Green-Refactor obligatoire) et l'exigence de documentation en
   français.
2. Toute fonctionnalité doit être accompagnée de tests d'intégration.
3. **Aucune Pull Request n'est fusionnée par un agent IA** — la fusion reste une décision et une
   action humaines, quel que soit le niveau d'autonomie accordé pour le reste (rédaction,
   tests, revue).

## Licence

Distribué sous licence **GNU General Public License v3.0** — voir [`LICENSE`](LICENSE) pour le
texte complet.

```
AeroPollen — champs de données Connect IQ qualité de l'air et pollens
Copyright (C) 2026 Alexandre BOIGUES

Ce programme est un logiciel libre ; vous pouvez le redistribuer et/ou le modifier
selon les termes de la GNU General Public License telle que publiée par la Free
Software Foundation ; soit la version 3 de la licence, soit (à votre gré) toute
version ultérieure.
```
