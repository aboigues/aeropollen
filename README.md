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
- [Appareils pris en charge](#appareils-pris-en-charge)
- [Structure du projet](#structure-du-projet)
- [Prérequis](#prérequis)
- [Compilation](#compilation)
- [Installation sur l'appareil](#installation-sur-lappareil)
- [Publication sur le Connect IQ Store](#publication-sur-le-connect-iq-store)
- [Tests](#tests)
- [Documentation](#documentation)
- [Confidentialité](#confidentialité)
- [Sécurité](#sécurité)
- [Contribuer](#contribuer)
- [Licence](#licence)

## Fonctionnalités

- **Champ « Qualité Air »** : indice européen de qualité de l'air (European AQI) à la position
  GPS courante.
- **Champ « Pollens »** : score de pollen global (bouleau, graminées, etc.) à la position GPS
  courante.
- Rafraîchissement en arrière-plan (`Background.registerForTemporalEvent`), sans appel réseau
  dans le cycle de rendu (`compute()`/`onUpdate()`), conformément aux contraintes de la
  plateforme Connect IQ (voir `specs/001-pollen-air-datafield/research.md`).
- Chaque champ est une application Connect IQ **installable et testable indépendamment** de
  l'autre — un `manifest.xml` Connect IQ ne peut déclarer qu'un seul `<iq:application>`.

## Appareils pris en charge

Les manifestes déclarent les appareils Edge suivants (mêmes exigences d'API minimale). Seul
**Edge 530** est réellement compilé, testé (41 tests `Toybox.Test`, voir [Tests](#tests)) et
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

## Publication sur le Connect IQ Store

Le Store attend un package `.iq` (pas `.prg`), qui bundle la compilation pour **tous** les
appareils déclarés dans le manifeste — équivalent du « Export Project » de l'extension VS Code
Monkey C. Un script génère les deux packages :

```bash
scripts/build-store-package.sh                          # les deux applications -> dist/*.iq
scripts/build-store-package.sh aeropollen-pollen-field   # une seule application
```

Chaque application (un seul `<iq:application>` par manifeste) nécessite sa **propre fiche
Store** — pas de soumission groupée possible. Étapes ensuite :

1. Créer un compte [Garmin Developer](https://developer.garmin.com/) (distinct du SDK).
2. Uploader chaque `.iq` sur le [portail de soumission](https://apps.garmin.com/en-US/developer/upload).
3. Renseigner description, captures d'écran et icône dédiée **500×500px sRGB** (différente de
   l'icône embarquée sur l'appareil, 35×35).
4. Attendre la revue Garmin (app invisible publiquement tant qu'elle est en attente).

Lire les [Developer Guidelines](https://developer.garmin.com/connect-iq/app-review-guidelines/)
avant soumission.

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
